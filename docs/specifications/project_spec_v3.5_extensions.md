# 디지털 옷장 (My Digital Closet) 작업지시서 v3.5 — 확장 기능 명세

본 문서는 **v3.4(`project_spec_v3.4.md`) 위에 얹는 확장 기능 작업지시서**입니다. v3.4의 모든 구조·디자인·서비스 시그니처는 그대로 유지하고, 다음 4개 신규 기능을 추가합니다.

| 코드 | 기능 | 핵심 인프라 |
|---|---|---|
| **F1** | AI 누끼따기 (배경 제거) | Hugging Face Spaces (FastAPI + rembg) → 추후 `@imgly/background-removal` 마이그레이션 |
| **F2** | 날씨 연동 | OpenWeatherMap API |
| **F3** | AI 코디 추천 | Cloud Functions for Firebase + Anthropic Claude Haiku 4.5 (룰 필터 → LLM 하이브리드) |
| **F4** | 친구 / 공유 레이어 | Firestore `users`, `friendships` 컬렉션 신규 + 가시성(visibility) 필드 |

다른 바이브 코딩 플랫폼이 본 문서만으로 구현할 수 있도록, 데이터 모델·서비스 시그니처·UI 진입점·에러 케이스를 모두 명시합니다.

---

## 1. 추가 의존성 (`pubspec.yaml`)

```yaml
dependencies:
  # 기존 v3.4 의존성 유지
  geolocator:    ^11.0.0   # F2 — 사용자 위치 기반 날씨
  cached_network_image: ^3.3.1  # F4 — 친구 옷장 그리드 캐싱
```

> 누끼·코디 추천은 모두 HTTP 호출이라 추가 패키지 없이 기존 `http`로 처리.

### 1.1 환경 변수 / 빌드 정의

`--dart-define` 또는 `lib/config/env.dart` 한 파일에 모음:

```dart
class Env {
  static const String hfBaseUrl = String.fromEnvironment(
    'HF_BASE_URL',
    defaultValue: 'https://<HF_USERNAME>-digital-closet-bg.hf.space',
  );
  static const String openWeatherKey = String.fromEnvironment('OWM_KEY');
  static const String functionsBaseUrl = String.fromEnvironment(
    'FUNCTIONS_BASE_URL',
    defaultValue: 'https://us-central1-digital-closet-32c43.cloudfunctions.net',
  );
}
```

빌드 시:
```bash
fvm flutter build web --no-tree-shake-icons \
  --dart-define=HF_BASE_URL=... \
  --dart-define=OWM_KEY=... \
  --dart-define=FUNCTIONS_BASE_URL=...
```

> **Anthropic API Key는 절대 클라이언트에 두지 않는다.** Cloud Functions에 Secret으로 보관 (§7).

---

## 2. 데이터 모델 추가 / 변경

### 2.1 `clothes` 컬렉션 (필드 추가)
| 필드 | 타입 | 설명 |
|---|---|---|
| `bgRemoved` | bool | 누끼 처리 완료 여부 (UI 배지용) |
| `season` | List&lt;String&gt; | `['봄','여름','가을','겨울']` 부분집합. 자동 추정 또는 사용자 직접 토글 |
| `visibility` | String | `'private' \| 'friends' \| 'public'` 기본 `'private'` |

### 2.2 `ootds` 컬렉션 (필드 추가)
| 필드 | 타입 | 설명 |
|---|---|---|
| `weather` | Map | `{ temp: 18.4, condition: 'Clear', city: 'Seoul', icon: '01d' }` 작성 시점 스냅샷 |
| `visibility` | String | `'private' \| 'friends' \| 'public'` 기본 `'private'` |
| `likes` | List&lt;String&gt; | 좋아요 누른 userId 배열 (F4) |
| `likeCount` | int | 비정규화 카운트 |

### 2.3 `users` 컬렉션 (신규)
문서 ID = `userId`(Auth `localId`)
| 필드 | 타입 | 설명 |
|---|---|---|
| `email` | String | |
| `displayName` | String | 닉네임 (검색 키) |
| `displayNameLower` | String | 검색용 소문자 정규화 |
| `photoUrl` | String? | 프로필 사진 |
| `bio` | String? | 한줄 소개 |
| `createdAt` | Timestamp | |

회원가입(`signUpWithEmail`) 성공 직후 이 문서를 **반드시 생성**한다.

### 2.4 `friendships` 컬렉션 (신규)
양방향 친구 관계를 한 문서로 표현. 문서 ID = `min(uidA, uidB) + '_' + max(uidA, uidB)` (정렬된 페어).

| 필드 | 타입 | 설명 |
|---|---|---|
| `users` | List&lt;String&gt; | 정확히 2개 UID. `array-contains` 쿼리용 |
| `status` | String | `'pending' \| 'accepted' \| 'blocked'` |
| `requestedBy` | String | 요청 보낸 UID |
| `createdAt` | Timestamp | |
| `acceptedAt` | Timestamp? | accepted 시점 |

### 2.5 인덱스 추가 (`firestore.indexes.json`)
```json
{
  "collectionGroup": "ootds",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId",     "order": "ASCENDING" },
    { "fieldPath": "visibility", "order": "ASCENDING" },
    { "fieldPath": "createdAt",  "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "friendships",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "users",  "arrayConfig": "CONTAINS" },
    { "fieldPath": "status", "order": "ASCENDING" }
  ]
}
```

### 2.6 보안 규칙 강화 (`firestore.rules`)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function isAuth() { return request.auth != null; }
    function isOwner(uid) { return isAuth() && request.auth.uid == uid; }
    function isFriend(otherUid) {
      let pairId = request.auth.uid < otherUid
        ? request.auth.uid + '_' + otherUid
        : otherUid + '_' + request.auth.uid;
      return exists(/databases/$(db)/documents/friendships/$(pairId))
          && get(/databases/$(db)/documents/friendships/$(pairId)).data.status == 'accepted';
    }

    match /users/{uid} {
      allow read: if isAuth();
      allow write: if isOwner(uid);
    }

    match /clothes/{docId} {
      allow read: if isOwner(resource.data.userId)
        || (resource.data.visibility == 'public' && isAuth())
        || (resource.data.visibility == 'friends' && isFriend(resource.data.userId));
      allow create: if isAuth() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isOwner(resource.data.userId);
    }

    match /ootds/{docId} {
      // 동일 패턴 + likes 필드는 본인 토글만 허용
      allow read: if isOwner(resource.data.userId)
        || (resource.data.visibility == 'public' && isAuth())
        || (resource.data.visibility == 'friends' && isFriend(resource.data.userId));
      allow create: if isAuth() && request.resource.data.userId == request.auth.uid;
      allow update: if isOwner(resource.data.userId)
        || (isAuth()
            && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['likes','likeCount']));
      allow delete: if isOwner(resource.data.userId);
    }

    match /friendships/{pairId} {
      allow read:   if isAuth() && request.auth.uid in resource.data.users;
      allow create: if isAuth() && request.auth.uid in request.resource.data.users
                                && request.resource.data.status == 'pending';
      allow update, delete: if isAuth() && request.auth.uid in resource.data.users;
    }
  }
}
```

> **전제**: F4 도입 시 `firebase_auth` SDK를 함께 도입하거나 Custom Token 발급 Cloud Function이 필요하다. REST 인증만으로는 `request.auth.uid`가 채워지지 않는다.

---

## 3. F1 — AI 누끼따기

### 3.1 1단계: Hugging Face Spaces (즉시 도입)

#### 3.1.1 서버 (Python, FastAPI + rembg)
**리포 구조** (`<HF_USERNAME>/digital-closet-bg` Space, SDK = Docker 또는 `gradio`+FastAPI 마운트):

```
Dockerfile          # python:3.11-slim 베이스
requirements.txt    # fastapi, uvicorn, rembg, python-multipart, onnxruntime
app.py
```

```python
# app.py
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from rembg import remove, new_session
import io
from PIL import Image

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://digital-closet-32c43.web.app", "http://localhost:*"],
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)
session = new_session("u2net")  # 모델 1회 로드 후 재사용

@app.get("/health")
def health(): return {"ok": True}

@app.post("/remove-bg")
async def remove_bg(file: UploadFile = File(...)):
    if file.size and file.size > 6 * 1024 * 1024:
        raise HTTPException(413, "파일 크기 6MB 초과")
    raw = await file.read()
    try:
        out = remove(raw, session=session)  # 투명 PNG 바이트
    except Exception as e:
        raise HTTPException(500, f"누끼 처리 실패: {e}")
    return Response(content=out, media_type="image/png")
```

- **호스팅**: HF Spaces CPU Basic (무료). 15분 idle 후 슬립 → 첫 호출 30~60초 콜드스타트.
- **엔드포인트**: `POST {HF_BASE_URL}/remove-bg` (multipart, 필드명 `file`)
- **응답**: `image/png` 바이너리. 투명 배경 적용된 PNG.

#### 3.1.2 클라이언트 (`lib/services/bg_remove_service.dart` 신규)
```dart
class BgRemoveService {
  final _client = http.Client();

  /// 원본 바이트를 받아 누끼 처리된 PNG 바이트를 반환.
  /// 실패 시 원본 바이트를 그대로 반환하지 않고 throw 한다 (호출부가 fallback 결정).
  Future<Uint8List> removeBackground(Uint8List bytes, {String filename = 'image.jpg'}) async {
    final uri = Uri.parse('${Env.hfBaseUrl}/remove-bg');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send().timeout(const Duration(seconds: 90));
    if (streamed.statusCode != 200) {
      throw Exception('누끼 처리 실패 (${streamed.statusCode})');
    }
    return await streamed.stream.toBytes();
  }
}
```

#### 3.1.3 UI 통합 — `upload_screen.dart` 수정
사진 박스 바로 아래(앨범 가져오기 TextButton과 같은 줄)에 **"✨ 배경 지우기 (AI)"** 버튼 추가.

```
[ 사진 미리보기 박스 ]
[ ✨ 배경 지우기 (AI) ]   [ 앨범에서 가져오기 ]
```

- 버튼 비활성화 조건: `_imageFile == null || _isBgProcessing`
- 처리 흐름:
  1. `_isBgProcessing = true` → 미리보기 박스 위에 반투명 오버레이 + `CircularProgressIndicator(white)` + 텍스트 `'AI가 배경을 지우는 중... (최초 30초)'`
  2. `bytes = await _imageFile!.readAsBytes()`
  3. `result = await bgRemoveService.removeBackground(bytes)` (try/catch, 실패 시 SnackBar `'누끼 처리 실패: $e. 원본 사진으로 진행됩니다.'`)
  4. 성공 시 `setState`로 `_processedBytes = result`. 미리보기는 `_processedBytes ?? originalBytes` 우선 표시.
  5. 저장 시 `uploadImage(_processedBytes ?? originalBytes, _processedBytes != null ? 'png' : 'jpg')` + `bgRemoved: _processedBytes != null` 필드도 함께 저장.

#### 3.1.4 옷장 그리드 표시
- HomeScreen 옷 카드의 좌상단에 `bgRemoved == true`이면 `Icons.auto_awesome` (12px, white on black 50% 원형 배지) 추가. (선택 사항)

### 3.2 2단계: `@imgly/background-removal` 마이그레이션 (선택)

PoC가 검증되면 클라이언트 100% 처리로 이전 → 콜드스타트·서버 의존 제거.

- `web/index.html`에 모듈 로드:
  ```html
  <script type="module">
    import { removeBackground } from 'https://cdn.jsdelivr.net/npm/@imgly/background-removal@1.5.5/+esm';
    window.imglyRemoveBg = async (bytes) => {
      const blob = new Blob([bytes], { type: 'image/jpeg' });
      const result = await removeBackground(blob);
      return new Uint8Array(await result.arrayBuffer());
    };
  </script>
  ```
- Flutter 측 `dart:js_interop`으로 `imglyRemoveBg` 호출, 같은 시그니처로 `BgRemoveService` 내부만 교체.
- 첫 1회 모델(~50MB) 다운로드 후 IndexedDB 캐시 → 이후 1~3초.

---

## 4. F2 — 날씨 연동

### 4.1 서비스 (`lib/services/weather_service.dart` 신규)
```dart
class WeatherSnapshot {
  final double temp;        // 섭씨
  final String condition;   // 'Clear' | 'Clouds' | 'Rain' | 'Snow' | ...
  final String city;
  final String icon;        // OWM 아이콘 코드
  // toMap() / fromMap() 포함
}

class WeatherService {
  Future<WeatherSnapshot> getCurrent({double? lat, double? lon, String? city}) async {
    final base = 'https://api.openweathermap.org/data/2.5/weather';
    final qp = lat != null && lon != null
      ? 'lat=$lat&lon=$lon'
      : 'q=${city ?? "Seoul"}';
    final uri = Uri.parse('$base?$qp&units=metric&lang=kr&appid=${Env.openWeatherKey}');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('날씨 조회 실패');
    final j = jsonDecode(res.body);
    return WeatherSnapshot(
      temp: (j['main']['temp'] as num).toDouble(),
      condition: j['weather'][0]['main'],
      city: j['name'],
      icon: j['weather'][0]['icon'],
    );
  }
}
```

### 4.2 위치 권한
- `geolocator`로 `Geolocator.getCurrentPosition()` (web에선 브라우저 권한 프롬프트)
- 거부/실패 시 사용자가 도시명 직접 입력하는 다이얼로그 폴백

### 4.3 UI 진입점
- **HomeScreen 상단**(카운트 줄 위)에 **날씨 위젯** 한 줄 추가:
  - `Row`: `Image.network(OWM_ICON_URL)` 32×32 + `Text('Seoul · 18°C 맑음', 13 grey[700])` + Spacer + `TextButton('오늘 코디 추천 →', black bold)` (탭 시 §5 코디 추천 시트 열림)
- **upload_ootd_screen.dart**: 업로드 시 백그라운드로 날씨 스냅샷 1회 호출 → `saveOOTDData` 시 `weather` 필드 동시 저장.
- **OotdScreen 게시물**: `weather`가 있으면 헤더 날짜 옆에 `'· 18°C ☀'` 작게 표시.

---

## 5. F3 — AI 코디 추천 (Cloud Functions + Claude Haiku)

### 5.1 백엔드 — Cloud Functions for Firebase

#### 5.1.1 프로젝트 구조
```
functions/
  package.json          # firebase-functions ^5, firebase-admin ^12, @anthropic-ai/sdk ^0.30+
  src/
    index.ts            # exports
    recommend.ts        # 코디 추천 핸들러
    middleware.ts       # ID 토큰 검증
```

#### 5.1.2 `recommend.ts`
```typescript
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import Anthropic from '@anthropic-ai/sdk';
import * as admin from 'firebase-admin';

admin.initializeApp();
const anthropicKey = defineSecret('ANTHROPIC_API_KEY');

export const recommendOutfit = onCall(
  { secrets: [anthropicKey], region: 'us-central1', timeoutSeconds: 30 },
  async (req) => {
    if (!req.auth) throw new HttpsError('unauthenticated', '로그인 필요');
    const uid = req.auth.uid;

    const { weather, occasion } = req.data as {
      weather: { temp: number; condition: string };
      occasion?: string;
    };

    // 1) 옷장 로드
    const snap = await admin.firestore()
      .collection('clothes').where('userId', '==', uid).get();
    const all = snap.docs.map(d => ({ id: d.id, ...d.data() }));

    // 2) 룰 기반 후보 좁히기 (기온 → 카테고리 화이트리스트)
    const allowed = pickAllowedCategories(weather.temp, weather.condition);
    const candidates = all
      .filter(c => allowed.includes(c.category))
      .slice(0, 40);                                // 토큰 가드

    // 3) Claude Haiku 호출 (프롬프트 캐싱)
    const client = new Anthropic({ apiKey: anthropicKey.value() });
    const resp = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 1024,
      system: [
        { type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } },
      ],
      messages: [{
        role: 'user',
        content: JSON.stringify({ weather, occasion, candidates }),
      }],
    });

    return parseOutfits(resp); // { outfits: [{ items:[id,...], reasoning, vibe }, ...] }
  }
);
```

#### 5.1.3 룰 테이블 (`pickAllowedCategories`)
```
temp ≤ 4   → ['아우터','상의','바지','신발'] + sub 화이트리스트(패딩/코트/니트/긴바지)
5~9        → 위와 동일하되 패딩 제외, 트렌치/자켓 포함
10~16      → ['아우터','상의','바지','치마','신발'] (가디건/블레이저/맨투맨)
17~22      → ['상의','바지','치마','원피스','신발']
23~27      → 반바지/미니스커트/원피스/티셔츠
≥ 28       → 민소매/반바지/원피스
condition == 'Rain'/'Snow' → 신발에서 부츠/방수 우선
```

#### 5.1.4 시스템 프롬프트 (개요)
```
당신은 한국 패션 스타일리스트입니다.
- 입력: 사용자 옷장 후보 목록(JSON), 날씨, 상황
- 출력: 후보 ID만 사용하여 3개의 코디 세트 제안
- 각 세트: 상의/하의(or 원피스)/아우터(필요시)/신발 + 선택적 가방/모자
- 같은 카테고리 중복 금지, 색상 조화/대비 고려, 한국어 reasoning 1~2문장
- 반드시 다음 JSON 스키마로만 응답:
  { "outfits": [ { "items": ["id", ...], "reasoning": "...", "vibe": "..." } ] }
```

#### 5.1.5 비용 가드
- 옷장 항목 40개 초과 시 룰로 절단
- 호출당 입력 ~2K + 출력 ~500 토큰 → Haiku 4.5 약 $0.001~0.002
- 사용자별 일일 호출 횟수 제한 (예: 10회) → Firestore `users/{uid}/quota` 카운터

### 5.2 클라이언트 (`lib/services/recommend_service.dart` 신규)
```dart
class OutfitSuggestion {
  final List<String> itemIds;
  final String reasoning;
  final String vibe;
}

class RecommendService {
  Future<List<OutfitSuggestion>> recommend({
    required WeatherSnapshot weather,
    String? occasion,
  }) async {
    final user = FirebaseService().currentUser;
    if (user == null) throw Exception('로그인 필요');

    final res = await http.post(
      Uri.parse('${Env.functionsBaseUrl}/recommendOutfit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${user.idToken}',
      },
      body: jsonEncode({
        'data': { 'weather': weather.toMap(), 'occasion': occasion },
      }),
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) throw Exception('추천 실패');
    final j = jsonDecode(res.body)['result'];
    return (j['outfits'] as List).map(OutfitSuggestion.fromJson).toList();
  }
}
```

### 5.3 UI — `lib/screens/recommend_sheet.dart` 신규
- HomeScreen 날씨 위젯의 `'오늘 코디 추천 →'` 버튼 또는 BottomSheet의 "오늘 OOTD 기록" 위 `'AI 코디 추천'` 항목으로 진입
- `showModalBottomSheet`(높이 80%) > Column:
  1. 헤더: 날씨 요약 + 상황 선택 칩 (`'데일리','데이트','출근','운동','특별한 날'`)
  2. `[추천 받기]` 버튼
  3. 결과 영역: `PageView`로 3개 세트를 좌우 스와이프
     - 각 세트 카드: 아이템 이미지 그리드 (2~4장) + reasoning 텍스트 + vibe 칩
     - 하단 `[이 코디로 OOTD 작성]` 버튼 → `UploadOotdScreen`으로 이동, `_selectedClothesIds`를 prefill
- 로딩/에러 처리: 30초 타임아웃, 실패 시 SnackBar + 룰 기반 결과로 폴백 (선택사항)

---

## 6. F4 — 친구 / 공유 레이어

### 6.1 사전 작업: firebase_auth 도입
보안 규칙 §2.6이 `request.auth.uid`를 요구. 두 가지 옵션 중 하나:
- **(권장)** `firebase_auth: ^4.x` 추가 → REST 호출과 병행 또는 SDK로 전면 교체
- 또는 Cloud Function `exchangeIdToken`을 만들어 REST `idToken` → Custom Token 발급 → SDK `signInWithCustomToken`

### 6.2 친구 검색 / 요청

#### 6.2.1 서비스 메서드 추가 (`firebase_service.dart`)
```dart
Future<List<UserProfile>> searchUsers(String query);          // displayNameLower 부분일치
Future<void> sendFriendRequest(String otherUid);              // friendships create (status='pending')
Future<void> acceptFriendRequest(String pairId);              // status='accepted', acceptedAt
Future<void> rejectFriendRequest(String pairId);              // delete
Future<void> removeFriend(String otherUid);                   // delete
Stream<List<Friendship>> getIncomingRequests();               // status='pending', requestedBy != me
Stream<List<UserProfile>> getFriends();                       // status='accepted'
```

`pairId` 규칙: `[uidA, uidB].sorted().join('_')`. 중복 요청 방지용 결정적 ID.

### 6.3 화면 추가

#### 6.3.1 `lib/screens/friends_screen.dart`
- 진입점: ProfileScreen에 `OutlinedButton.icon(Icons.people_outline, '친구')` 추가 → 푸시
- 탭 3개 (`TabBar`):
  1. **친구 목록** — `getFriends()` 결과를 ListTile로 (프로필 사진/닉네임/이메일, tap → `FriendClosetScreen`)
  2. **요청 받음** — `getIncomingRequests()` (수락/거절 버튼)
  3. **검색** — TextField + 결과 ListTile (탭 시 요청 보내기 다이얼로그)

#### 6.3.2 `lib/screens/friend_closet_screen.dart`
- 인자: `final String uid; final String displayName;`
- AppBar 제목 `"$displayName의 옷장"`.
- 탭 2개: **옷장 (clothes)**, **OOTD (ootds)**
- 쿼리: `where('userId', '==', uid).where('visibility', 'in', ['public', 'friends']).orderBy('createdAt', desc)`
- 그리드/피드 레이아웃은 HomeScreen / OotdScreen 재사용. **수정/삭제 버튼은 모두 비표시.**

#### 6.3.3 OOTD 좋아요
- OotdScreen 게시물에 `Icons.favorite_outline / Icons.favorite (red)` 토글 버튼 추가
- 트랜잭션으로 `likes` 배열 토글 + `likeCount` 증감
- 본인 OOTD 게시물에는 좋아요 카운트만 표시(자기 자신은 좋아요 불가)

### 6.4 가시성(visibility) 토글 UI
- `clothing_detail_screen.dart` / `upload_ootd_screen.dart` 에 라디오 칩 3개 추가:
  - 🔒 비공개(기본) · 👥 친구 공개 · 🌍 전체 공개
- 옷 업로드 시 기본 `'private'`. 상세 화면에서 변경 가능.

### 6.5 친구 OOTD 피드 (선택, P2 단계)
- OotdScreen 상단 탭 추가: `[내 피드 | 친구 피드]`
- 친구 피드는 `getFriends()` 로 친구 UID 목록을 받아 `where('userId', 'in', friendUids).where('visibility', 'in', ['public', 'friends'])` (Firestore `in` 최대 30개 제약 → 친구 30명 초과 시 분할 쿼리 + 클라이언트 머지)

---

## 7. 인프라 / 배포

### 7.1 Firebase 플랜
- **Spark(무료)는 외부 네트워크 호출 불가** → Cloud Functions에서 Anthropic·OWM 호출 안 됨.
- **Blaze(종량) 전환 필수.** 예상 비용: 사용자 수백 명 규모에서 월 $5 미만 (Functions 호출 $0.40/백만 + 외부 API).

### 7.2 Secrets
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
```

### 7.3 배포 명령어
```bash
# 함수 배포
cd functions && npm run build && firebase deploy --only functions

# 규칙/인덱스
firebase deploy --only firestore:rules,firestore:indexes,storage

# 웹 호스팅 (env 정의 포함)
fvm flutter build web --no-tree-shake-icons \
  --dart-define=HF_BASE_URL=https://<HF>.hf.space \
  --dart-define=OWM_KEY=$OWM_KEY \
  --dart-define=FUNCTIONS_BASE_URL=https://us-central1-digital-closet-32c43.cloudfunctions.net \
  && ./firebase_bin deploy --only hosting
```

---

## 8. 단계적 도입 로드맵

| 단계 | 범위 | 산출물 | 예상 소요 |
|---|---|---|---|
| **P1** | F1 (HF 누끼 서버) + 업로드 화면 통합 | HF Space, `bg_remove_service.dart`, upload_screen.dart 수정 | 2일 |
| **P2** | F2 (날씨 위젯) + OOTD weather 스냅샷 저장 | `weather_service.dart`, HomeScreen 위젯, OOTD 카드 표시 | 2일 |
| **P3** | F3 (Cloud Functions + Haiku 코디 추천) | `functions/`, `recommend_sheet.dart` | 3일 |
| **P4** | F4 (firebase_auth 마이그 + 친구 검색/요청/목록) | `users` 컬렉션 마이그, `friends_screen.dart` | 5일 |
| **P5** | F4 후속 (visibility 토글, 친구 옷장 보기, 좋아요) | 보안 규칙 §2.6, `friend_closet_screen.dart` | 3일 |
| **P6** | F1 imgly 마이그레이션 (선택) | `web/index.html` 수정, `BgRemoveService` 교체 | 2일 |

각 단계는 독립적으로 배포 가능하며, 이전 단계 없이도 동작한다(F4만 firebase_auth 선결).

---

## 9. 알려진 제약 / 주의사항

- **HF Spaces 콜드스타트**: 첫 호출 30~60초. 사용자에게 명시적 로딩 메시지 노출 필수.
- **Anthropic API 비용**: 사용자별 일일 호출 제한 + 프롬프트 캐싱 적용 권장.
- **`request.auth` 컨텍스트**: F4는 firebase_auth 또는 Custom Token 도입이 사실상 강제 조건. 기존 REST 인증만으로는 보안 규칙이 작동하지 않는다.
- **CORS**: HF Spaces·Cloud Functions·OWM 모두 `https://digital-closet-32c43.web.app` origin 허용 필요.
- **이미지 확장자**: 누끼 처리된 옷은 `.png`(투명)으로 저장하므로 `uploadImage(bytes, 'png')`로 분기. v3.4 §6.7에서 `.jpg` 고정이었던 것을 누끼 통과 시에만 `.png`로 변경.
- **친구 30명 제한**: Firestore `in` 쿼리 한계. 30명 초과 시 청크 분할 쿼리 + 클라이언트 머지/정렬.
- **이전 데이터 호환**: 기존 문서엔 `visibility`, `bgRemoved`, `weather`, `season` 필드가 없음. 읽기 측에서 모두 null-safe 처리 필요. 백필 마이그레이션 스크립트는 선택사항.
