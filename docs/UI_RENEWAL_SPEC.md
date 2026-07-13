# Myventory UI 리뉴얼 — 개발 지시서

> 이 문서를 그대로 개발 에이전트에 전달하세요.
> 시각 목업: `app_icons/myventory/ui_mockup/*.png` (먼저 열어볼 것)

---

## 0. 배경 (반드시 먼저 읽을 것)

이 앱은 **옷장 앱에서 "내 아이템 인벤토리" 앱으로 확장**합니다.

- **앱 이름**: `dress` → **`Myventory`** (한글: 마이벤토리)
- **담는 것**: 옷 · 피규어 · 말랑이 · 향수 · LP — **아이템 종류를 가리지 않음**
- **핵심 메타포**: **게임 인벤토리** — 격자 슬롯에 아이템이 담긴다
- **앱 아이콘**: "픽셀 M" (5×5 슬롯 격자에 M이 박힘) — **이미 적용 완료**

### 리뉴얼의 명제
> **아이콘 = 슬롯 격자 + 강조된 한 칸. 홈 화면도 정확히 그래야 한다.**
> 지금 홈 화면은 흰 배경에 누끼 이미지가 둥둥 떠 있어 아이콘과 아무 관계가 없다.

| 게임 인벤토리 | → Myventory |
|---|---|
| 격자 슬롯 | 아이템 그리드 (3열 **정사각**) |
| 가방·파우치 탭 | 폴더 (옷장 / 헌터×헌터 / 말랑이) |
| 장착 (Equip) | OOTD |
| 희귀도 (Rarity) | 즐겨찾기 — 슬롯 모서리 붉은 삼각 |
| 빈 슬롯 | 아이템 추가 — "아직 자리가 남았다" |

---

## 🚫 절대 규칙

1. **번들 ID `com.antigravity.dress` 를 바꾸지 말 것.** 바꾸면 기존 사용자가 전부 날아갑니다. 표시 이름만 교체.
2. **앱 아이콘 작업은 이미 끝났습니다.** `pubspec.yaml`의 `flutter_launcher_icons` 설정, `assets/icon/*.png`, iOS/Android/web 아이콘 파일 — **건드리지 마세요.**
3. **코디 아이디어(매거진 룩북) 화면은 건드리지 말 것.** `coordination_canvas_screen.dart` / `planned_ootd_detail_screen.dart`. 이 앱에서 완성도가 가장 높습니다.
4. **기능은 아이템 타입을 따라간다.** OOTD · 코디 캔버스 · 세탁 주기 · 날씨 추천은 **옷 전용 기능**입니다. 지우지 말고 **의류 카테고리·폴더에서만 노출**되도록 조건부로 감싸세요. 피규어 폴더를 보는데 "오늘 뭐 입지"가 뜰 이유가 없습니다.

---

## 작업 순서 (위에서부터)

---

### TASK 0 — `lib/theme/` 신설 ⚠️ 선행 필수

**문제**: 현재 테마는 `main.dart` 32~55행 20줄이 전부고, 색은 13,000줄에 하드코딩돼 있습니다. 이걸 먼저 안 하면 아래 작업에서 슬롯 색을 또 하드코딩하게 됩니다.

`lib/theme/app_theme.dart` 를 새로 만들고 아래 토큰을 정의하세요.

```dart
class AppColors {
  static const surface = Color(0xFFFFFFFF);  // 카드 · 시트
  static const ground  = Color(0xFFF7F6F3);  // 배경 (순백 아님 — 따뜻한 중성색)
  static const slot    = Color(0xFFEFEDE6);  // 슬롯 채움  ★ 신규
  static const line    = Color(0xFFE1DED5);  // 테두리 · 구분선
  static const muted   = Color(0xFF8B887F);  // 보조 텍스트
  static const ink     = Color(0xFF121213);  // 본문 · Primary
  static const accent  = Color(0xFFDE3B26);  // 즐겨찾기 · 삭제 · 알림  ← 이 3곳만!
}

class AppRadius {
  static const slot   = 6.0;
  static const card   = 10.0;
  static const button = 12.0;
  static const sheet  = 20.0;
}
```

**규칙:**
- **액센트(붉은색)는 즐겨찾기 · 삭제 · 알림 딱 3곳에만.** 현재 `Colors.blueAccent`로 칠해진 "세탁 필요" 배지의 파랑은 **제거**합니다. 액센트가 둘이면 어느 쪽도 눈에 안 들어옵니다.
- **수치(개수 · 날짜 · 착용 횟수)는 전부 모노스페이스 + `tabular-nums`.** 인벤토리 톤을 만드는 건 색이 아니라 이 서체입니다.
- 기존 `Colors.white` / `Colors.black` 하드코딩은 점진적으로 위 토큰으로 교체.

---

### TASK 1 — OOTD 그리드 정렬 버그 🔴 최우선 (한 단어)

**파일**: `lib/screens/ootd_screen.dart:286`

**문제**: 셀은 정사각(`childAspectRatio: 1.0`)인데 이미지가 `BoxFit.contain`입니다. 레터박스 여백이 생기고 배경·테두리가 없어서 사진이 허공에 뜹니다. 가로 사진은 짧고 넓게, 세로 사진은 길게 → **정렬이 완전히 무너집니다.**

```dart
// AS-IS (ootd_screen.dart:284-288)
Image.network(
  item['imageUrl'] ?? '',
  fit: BoxFit.contain,   // ← 버그
  ...
)

// TO-BE — 인스타식 정사각 크롭
ClipRRect(
  borderRadius: BorderRadius.zero,   // 피드는 각지게. 여백 2px 유지.
  child: Image.network(
    item['imageUrl'] ?? '',
    fit: BoxFit.cover,   // ← 이 한 단어
    ...
  ),
)
```

**같은 수정을 `lib/widgets/ootd_post_widget.dart:108` 에도 적용** (친구 피드도 동일 문제).

#### ⚠️ 두 그리드는 정반대 원리입니다 — 혼동 금지
| 화면 | 이미지 | fit | 왜 |
|---|---|---|---|
| **옷장** (TASK 2) | 누끼 **투명 PNG** | **`contain`** + 슬롯 배경 | 옷이 잘리면 안 됨. 여백을 **만든다** |
| **OOTD** (TASK 1) | 인물 **사진** | **`cover`** 정사각 크롭 | 피드는 잘려도 됨. 여백을 **없앤다** |

**옷장에 `cover`를 쓰면 안 됩니다.** 옷이 잘립니다.

---

### TASK 2 — 옷장 그리드를 "슬롯"으로 🔴 임팩트 최대

**파일**: `lib/screens/home_screen.dart` · `_buildClothingGridItem` (약 710행) 및 `GridView.builder`의 delegate

#### 바뀌는 값

| 항목 | AS-IS | TO-BE | 이유 |
|---|---|---|---|
| `childAspectRatio` | `0.6` | **`1.0`** | 세로형은 **옷 전용 비율**. 정사각이라야 피규어·향수·LP가 자연스럽다 |
| `crossAxisSpacing` | `12` | **`7`** | 슬롯끼리 붙어야 "격자"로 읽힌다 |
| `mainAxisSpacing` | `16` | **`7`** | 위와 동일 |
| 셀 배경 | **없음** | **`AppColors.slot`** | ★ **가장 중요.** 지금은 누끼가 흰 바탕에 떠 있다 |
| 셀 radius | `8` | **`6`** | 아이콘 셀의 곡률과 맞춤 |
| 이미지 padding | `0` | **`10`** | 슬롯 안에서 숨 쉴 공간 |
| 셀 하단 텍스트 | 2줄 (제목+분류) | **제거** | 그리드는 훑는 곳. 이름은 상세에서 |
| 세탁 배지 | 파란 알약 `🧼 세탁 필요` | **좌하단 붉은 점 6×6** | 파랑은 팔레트에 없는 색 |
| 착용 횟수 | 알약 배지 | **우하단 모노스페이스** (0이면 숨김) | 인벤토리 톤 |
| 즐겨찾기 | **없음** | **우상단 붉은 삼각** (신규) | 아이콘의 빨간 칸과 대응 |
| 마지막 셀 | 없음 | **점선 슬롯 + `+`** (신규) | "아직 자리가 남았다" |

#### 구현 골자

```dart
// 1) delegate
SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  crossAxisSpacing: 7,
  mainAxisSpacing: 7,
  childAspectRatio: 1.0,          // was 0.6
)

// 2) 마지막에 빈 슬롯 한 칸 추가
itemCount: docs.length + 1,
itemBuilder: (context, i) => i == docs.length
    ? const _EmptySlot()          // 점선 + "+" → UploadScreen 이동
    : _SlotTile(doc: docs[i]),

// 3) 슬롯 타일 — 배경 있는 정사각 셀. 셀 하단 텍스트는 제거.
Container(
  decoration: BoxDecoration(
    color: AppColors.slot,                       // ★ 누끼가 뜨지 않게 받쳐준다
    borderRadius: BorderRadius.circular(AppRadius.slot),
    border: Border.all(color: AppColors.line),
  ),
  clipBehavior: Clip.antiAlias,
  child: Stack(children: [
    Padding(
      padding: const EdgeInsets.all(10),
      child: Hero(tag: docId,
        child: Image.network(imageUrl, fit: BoxFit.contain)),   // contain 유지!
    ),
    // 즐겨찾기 — 우상단 붉은 삼각 (모서리를 잘라낸 형태라 이미지를 안 가림)
    if (isFavorite)
      Positioned(top: 0, right: 0,
        child: CustomPaint(size: const Size(12, 12), painter: CornerNotch())),
    // 세탁 필요 — 좌하단 점 하나 (기존 파란 알약 대체)
    if (isWashRequired)
      Positioned(bottom: 5, left: 5, child: Container(
        width: 6, height: 6,
        decoration: const BoxDecoration(
          color: AppColors.accent, shape: BoxShape.circle))),
    // 착용 횟수 — 모노스페이스, 0이면 숨김
    if (wearCount > 0)
      Positioned(bottom: 3, right: 5,
        child: Text('$wearCount', style: AppText.mono.copyWith(fontSize: 9))),
  ]),
)
```

#### 즐겨찾기는 신규 필드입니다
`clothes` 문서에 `isFavorite: bool` 을 추가하세요.
기존 문서엔 없으므로 **`(item['isFavorite'] as bool?) ?? false`** 로 안전하게 읽으면 **마이그레이션 없이** 바로 붙습니다.
`clothing_detail_screen.dart` 에 즐겨찾기 토글 버튼도 추가.

#### ✅ 슬롯 배경이 안전한 이유 (검증 완료)
저장 이미지는 **투명 PNG**입니다. 확인함:
- `bg_removal_service.dart` → `img.Image(..., numChannels: 4)` + `img.encodePng()`
- `upload_screen.dart:578` → `uploadImage(bytes, 'png')`, contentType `image/png`

→ 슬롯 배경이 사진 뒤로 **정상적으로 비칩니다.** 흰 박스가 뜨지 않습니다.

---

### TASK 3 — 홈 헤더 다이어트

**문제**: 그리드 위에 4개 층이 쌓여 **화면의 29%** 를 먹습니다. 스크롤 없이 아이템이 **5.5개**밖에 안 보입니다.

현재: `날씨 카드(70px)` + `폴더 바(40px)` + `All Items (16) 줄(30px)` + `원형 카테고리 칩(65px)`

| 항목 | AS-IS | TO-BE |
|---|---|---|
| 날씨 카드 | 70px 2줄 | **42px 1줄**. `26.0°(mono) · 더운 날 · 얇게 입으세요` + `스마트 추천` 버튼. **의류 카테고리에서만 노출** |
| 폴더 바 + 카테고리 칩 | **2줄로 분리** | **1줄로 통합**. 필터 축이 둘로 쌓여 있어 뭘 눌러야 할지 헷갈립니다 |
| 원형 스토리 칩 | `CircleAvatar` 56×56 | **사각 칩** `radius: 4`. 원형은 인스타의 "사람" 언어 — 사각 슬롯 아이덴티티와 충돌합니다 |
| `All Items (16)` | 큰 텍스트 줄 | **`16 ITEMS`** 모노스페이스 10px로 축소 |

**결과: 스크롤 없이 보이는 아이템 5.5개 → 12개 (2.2배).**

---

### TASK 4 — 프로필 → 대시보드

**파일**: `lib/screens/profile_screen.dart` (229줄) ← `lib/screens/closet_analytics_screen.dart` (496줄)

**문제**: 프로필 화면의 **60%가 빈 여백**입니다. 그리고 **인벤토리 앱의 핵심 가치인 "내가 뭘 얼마나 갖고 있나"(`closet_analytics_screen.dart`, 496줄이 이미 다 구현돼 있음)가 버튼 하나 뒤에 숨어 있습니다.**

`closet_analytics_screen.dart` 의 내용을 **프로필 화면에 직접 전개**하세요. 새로 만들 필요 없습니다 — 이미 다 있습니다.

구성 (위→아래):
1. **아바타 + 닉네임 — 작게, 한 줄로** (기존은 화면 중앙에 크게). *프로필 사진은 이 앱의 주인공이 아닙니다. 컬렉션이 주인공입니다.*
2. **통계 4칸**: `182 아이템` / `5 폴더` / `24 이번 달 착용` / **`31 안 입은 옷`** ← **이것만 붉게.** 행동을 유도하는 숫자에만 액센트를 줍니다.
3. **카테고리 분포** — 100% 스택 막대 (흑백 그라데이션)
4. **가장 많이 입은 TOP 3** — 썸네일 + 이름 + `24회`(mono)
5. **"6개월 넘게 안 입은 옷이 31개"** 붉은 배너 → 탭하면 해당 목록으로
6. **친구 관리 / 알림 설정 / 로그아웃** — 단순 리스트로

---

### TASK 5 — 카피 중립화

"옷"을 걷어내고 "아이템"으로. 확장 컨셉의 핵심입니다.

| 위치 | AS-IS | TO-BE |
|---|---|---|
| `home_screen.dart:138` | `MY CLOSET` | `MYVENTORY` |
| `login_screen.dart:63` | `나만의 디지털 옷장` | `내 아이템 인벤토리` |
| `home_screen.dart` | `옷 정보 없음` | `정보 없음` |
| `home_screen.dart` | `옷 다중 선택` | `다중 선택` |
| `upload_screen.dart` | `옷장에 추가하기` | `인벤토리에 추가` |
| `clothing_detail_screen.dart` | `옷 정보 정리` | `아이템 정보` |
| 하단 탭 | `옷장` | `인벤토리` |
| `profile_screen.dart` | `옷장 통계 분석 📊` | (대시보드로 흡수 — 버튼 제거) |

---

### TASK 6 — 앱 표시 이름 교체 (8개 파일)

| 파일 | AS-IS | TO-BE |
|---|---|---|
| `pubspec.yaml:2` | `description: "A new Flutter project."` | `내 아이템 인벤토리` |
| `lib/main.dart:33` | `title: 'My Digital Closet'` | `'Myventory'` |
| `android/app/src/main/AndroidManifest.xml:3` | `android:label="dress"` | `"Myventory"` |
| `ios/Runner/Info.plist:8` | `CFBundleDisplayName: Dress` | `Myventory` |
| `macos/.../AppInfo.xcconfig:8` | `PRODUCT_NAME = dress` | `Myventory` |
| `web/manifest.json` | `name/short_name: dress` | `Myventory` / desc 교체 |
| `web/index.html:26,40` | `<title>dress</title>` | `Myventory` |
| `web/manifest.json` | `theme_color: #0175C2` (Flutter 기본 파랑!) | `#121213` |

⚠️ **`applicationId` / `bundle id`(`com.antigravity.dress`)는 절대 바꾸지 마세요.**

---

## 카테고리 taxonomy 확장 (TASK 2 이후, 별도 작업 가능)

**파일**: `lib/utils/categories.dart`

현재 최상위 카테고리가 **옷 10종으로 고정**(상의/원피스/바지/치마/아우터/신발/가방/모자/악세서리/기타)이고, `assets/icons/*.png` 85개가 전부 옷 전용입니다.

**최상위에 "아이템 타입" 레이어를 추가**하세요:

```
아이템 타입 (신규 최상위)
├── 의류        → 기존 옷 10종 카테고리를 여기 하위로
├── 피규어      → 시리즈명 (헌터×헌터, 원피스…)
├── 인형/말랑이
├── 향수
└── 기타
```

`closet_folders` 는 **이미 다중 배정을 지원**하므로(`firebase_service.dart:992-1065`) 폴더 시스템은 그대로 쓰면 됩니다.

---

## 검증

1. `flutter analyze` 통과
2. **앱을 실제로 켜서** 홈 · OOTD · 프로필 세 화면을 눈으로 확인
   - OOTD 그리드가 **정사각으로 정렬**되는가
   - 옷장 슬롯에 **누끼 이미지가 잘리지 않고** 슬롯 배경 위에 놓이는가 (**흰 박스가 뜨면 안 됨**)
   - 즐겨찾기 토글 → 붉은 삼각이 뜨는가
   - 기존 아이템(`isFavorite` 필드 없는 문서)이 **에러 없이** 로드되는가
3. 다크모드는 이번 범위 밖 — **라이트만** 맞추면 됩니다

---

## 참고 자료

`app_icons/myventory/ui_mockup/` — **작업 전에 반드시 열어볼 것**

| 파일 | 내용 |
|---|---|
| `before-after-real.png` | 홈 — 실제 캡처 vs 제안 |
| `before-after-ootd.png` | OOTD — 정렬 버그 vs 수정 |
| `before-after-profile.png` | 프로필 — 빈 화면 vs 대시보드 |
| `slot-anatomy.png` | 슬롯 1칸 해부도 (수치 주석) |
| `theme-tokens.png` | 색 · 타이포 · radius · 그리드 규격 |
| `home-slot-light.png` | 홈 전체 (라이트) |

`assets/before_image/` — 실제 앱 캡처 4장 (main / ootd / codi_rec / my_status)
