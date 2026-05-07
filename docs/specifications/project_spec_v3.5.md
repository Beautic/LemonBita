# 디지털 옷장 (My 기Digital Closet) 작업지시서 v3.5

이 문서는 다른 바이브 코딩 플랫폼이 본 문서만으로 현재 동작 중인 Flutter 웹 앱을 **구조·동작·UI 디테일까지 거의 동일하게** 재구현할 수 있도록, 화면별 위젯 트리·상수 값·서비스 시그니처·필터링 로직·예외 케이스를 모두 명시합니다.

(v3.5 변경점: ① 기존 REST API 수동 인증을 제거하고 공식 `firebase_auth` SDK 도입. ② `SharedPreferences` 토큰 관리 제거 및 `authStateChanges()` 스트림 활용. ③ SDK 전환으로 인해 `request.auth != null` 기반 보안 규칙 완벽 대응. ④ OOTD 작성 시 **과거 날짜 선택 기능** 추가(사진의 `lastModified` 우선 반영). ⑤ 기존 OOTD 게시물 **날짜 수정 기능** 추가 (`updateOOTDDate`). ⑥ 웹 환경 호환성을 위해 `Icons.edit_calendar` 대신 `Icons.calendar_month` 사용.)

---

## 1. 프로젝트 개요
- **앱 이름**: My Digital Closet (나만의 디지털 옷장)
- **목적**: 사용자가 자신의 옷 사진을 찍어 카테고리별로 관리하고, 옷장 아이템을 태깅하여 매일의 데일리룩(OOTD)을 기록·검색·달력으로 회고하는 애플리케이션
- **플랫폼**: Flutter (Web 우선, iOS/Android 호환 구조)
- **주요 기능**: `firebase_auth` 기반 이메일 회원가입/로그인, 옷 사진 업로드(카메라/갤러리), 대분류·소분류 2단계 카테고리, 커스텀 라인아트 아이콘, 상세 메타데이터 관리, 4탭 하단 네비게이션, **OOTD 작성(과거 날짜 선택)/무한 스크롤 피드/태그 수정/달력 회고(날짜 수정)**, 옷장 다중 조건 검색, **옷 활용 통계(어떤 OOTD에 몇 번 사용됐는지)**

---

## 2. 기술 스택 및 패키지 (`pubspec.yaml`)

```yaml
environment:
  sdk: '>=3.2.6 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons:    ^1.0.2
  firebase_core:      '>=2.27.0 <2.31.0'
  firebase_auth:      ^4.17.4     # v3.5 신규: 공식 Auth SDK
  cloud_firestore:    '>=4.15.8 <4.18.0'
  firebase_storage:   '>=11.6.9 <11.8.0'
  image_picker:       ^1.0.8
  http:               ^1.2.0      # 잔여 기능용 유지
  shared_preferences: ^2.2.3      # 기타 설정 유지
  intl:               ^0.19.0
  table_calendar:     ^3.1.3      

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints:        ^2.0.0
  mockito:              ^5.4.4
  build_runner:         ^2.4.8
  fake_cloud_firestore: ^2.4.8

flutter:
  uses-material-design: true
  assets:
    - assets/icons/
```

- **상태 관리**: `setState` + `StreamBuilder` 만 사용 (Provider/Riverpod/Bloc 등 도입하지 않음)
- **백엔드**: Firebase (Firestore, Storage, Auth). 인증은 공식 **Firebase Auth SDK** 사용.
- **세션**: SDK 내부 관리 (`SharedPreferences` 수동 토큰 관리 제거)

---

## 3. 디자인 시스템

### 3.1 테마 (lib/main.dart의 `ThemeData`)
- `brightness: Brightness.light`
- `scaffoldBackgroundColor`: `Colors.white` (`#FFFFFF`)
- `primaryColor`: `Colors.black` (`#000000`)
- `colorScheme`: `ColorScheme.light(primary: Colors.black, secondary: Colors.grey, surface: Colors.white)`
- `appBarTheme`:
  - `backgroundColor: Colors.white`
  - `foregroundColor: Colors.black`
  - `elevation: 0`
  - `centerTitle: true`
  - `systemOverlayStyle: SystemUiOverlayStyle.dark`
- `fontFamily: 'Roboto'`
- `MaterialApp.debugShowCheckedModeBanner: false`

### 3.2 자주 사용하는 디자인 토큰
- 보조 배경 / 비어있는 이미지 박스: `Colors.grey[100]` (`#F5F5F5`)
- 외곽선/세컨더리 텍스트: `Colors.grey[300]` ~ `Colors.grey[600]`
- 구분선 (피드 사이 두꺼운 분리): `Color(0xFFEEEEEE)` 또는 `Color(0xFFF5F5F5)` 8px Divider
- 카드/버튼 둥근 모서리: `BorderRadius.circular(8 ~ 28)` (위치별 상이, 본문 참조)
- 선택된 칩/버튼: 배경 `Colors.black`, 라벨 `Colors.white`
- 비선택 칩 배경: `Colors.grey[200]`
- 에러 색: `Colors.redAccent`

### 3.3 커스텀 에셋
- `assets/icons/` 디렉토리에 60+ 라인아트 PNG 아이콘 (옷 종류별).
- **파일명 규칙**: 한글 NFD/NFC 정규화. 슬래시(`/`)와 공백(` `)은 제거 또는 `_` 변환.
  - 예: `'로퍼/블로퍼'` → `로퍼_블로퍼.png`, `'캐미솔/탱크탑'` → `캐미솔_탱크탑.png`
- 매핑은 `lib/utils/categories.dart`의 `CategoryData` 클래스에서 처리 (§5.3 참조).

---

## 4. 데이터베이스 구조 (Firebase)

### 4.1 Firestore 컬렉션: `clothes` (내 옷장)
| 필드 | 타입 | 설명 |
|---|---|---|
| `userId` | String | 작성자 UID |
| `imageUrl` | String | Storage 다운로드 URL |
| `category` | String | 대분류 (10개 중 하나) |
| `subCategory` | String | 소분류 (대분류별 정해진 목록 중 하나, 없으면 `''`) |
| `tags` | String | 해시태그 문자열. 업로드 시 `'#대분류'` 자동 입력 |
| `brand` | String? | 선택. 상세 화면에서 입력 |
| `size` | String? | 선택 (예: L, 100, 270) |
| `color` | String? | 선택 (예: 크림 베이지) |
| `pattern` | String? | 선택 (예: 케이블 니트) |
| `material` | String? | 선택 (예: 울 혼방) |
| `fit` | String? | 선택 (예: 오버사이즈) |
| `length` | String? | 선택 (예: 130cm) |
| `memo` | String? | 선택. 자유 메모 5줄 입력 영역 |
| `createdAt` | Timestamp | `FieldValue.serverTimestamp()` |

### 4.2 Firestore 컬렉션: `ootds`
| 필드 | 타입 | 설명 |
|---|---|---|
| `userId` | String | 작성자 UID |
| `imageUrl` | String | OOTD 사진 URL |
| `description` | String | 자유 코멘트 |
| `taggedClothes` | List&lt;Map&gt; | 태그된 옷의 비정규화 정보. 항목당 `{id: String, imageUrl: String, title: String}`. 피드 로딩 시 옷 컬렉션 추가 조회 없이 표시 |
| `taggedClothesIds` | List&lt;String&gt; | `taggedClothes`의 `id`만 뽑은 평면 리스트. HomeScreen 옷 카드 OOTD 사용 횟수 카운트와 옷 상세 활용 통계용 (배열 contains 검색 효율화) |
| `createdAt` | Timestamp | **v3.5 변경**: 사용자가 지정한 과거 날짜(`Timestamp.fromDate(date)`) 또는 `FieldValue.serverTimestamp()` |

`taggedClothes[i].title` 생성 규칙: `'${color} ${pattern}'.trim()` 우선, 비면 `brand`, 그래도 비면 `category`, 마지막 폴백 `'옷 정보 없음'`. (구현: `upload_ootd_screen.dart`, `home_screen.dart`, `search_clothes_screen.dart`의 선택 모드 모두 동일 로직)

> **이전 데이터 호환**: `taggedClothesIds`가 누락된 과거 문서가 존재할 수 있음. HomeScreen·옷 상세에서 카운트할 때 `taggedClothesIds`가 비어있으면 `taggedClothes` 배열을 순회해 `id`를 추출해서 폴백 카운트.

### 4.3 Storage 경로
- 모든 사진(옷·OOTD 공용): `clothes/{millisecondsSinceEpoch}.{ext}`
- 컨텐트 타입: `image/{ext}` (`SettableMetadata`)

### 4.4 Firestore / Storage 보안 규칙 (v3.5 완벽 적용)

**`firestore.rules`**:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**`storage.rules`**:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

> v3.5부터 공식 `firebase_auth` SDK를 사용하므로, 클라이언트 요청 시 자동으로 `request.auth` 컨텍스트가 부여되어 보안 규칙이 안정적으로 동작합니다.

### 4.5 `firestore.indexes.json`
```json
{
  "indexes": [
    {
      "collectionGroup": "clothes",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId",    "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "ootds",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId",    "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```
> `getOOTDPage`(무한 스크롤)와 `getOOTDsByMonth`(달력) 모두 `userId + createdAt` 복합 인덱스가 필요.

---

## 5. 코드 구조

```
lib/
├── main.dart                       # 진입점, 테마, AuthWrapper
├── services/
│   └── firebase_service.dart       # 싱글톤 백엔드 서비스
├── utils/
│   └── categories.dart             # 카테고리 데이터 + 아이콘 매핑
└── screens/
    ├── login_screen.dart
    ├── main_screen.dart
    ├── home_screen.dart
    ├── ootd_screen.dart
    ├── ootd_calendar_screen.dart
    ├── upload_screen.dart
    ├── upload_ootd_screen.dart     # v3.5 과거 날짜 지정 추가
    ├── clothing_detail_screen.dart
    ├── search_clothes_screen.dart
    └── profile_screen.dart
```

### 5.1 `lib/services/firebase_service.dart`

#### 5.1.1 `AuthUser` 모델
```dart
class AuthUser {
  final String uid;
  final String email;
  final String idToken; // SDK 사용으로 빈 문자열 유지
  final String refreshToken; // SDK 사용으로 빈 문자열 유지
}
```

#### 5.1.2 `FirebaseService` 정적 상태
- 정적 멤버: `_currentUser`, `_authStateController` (`StreamController<AuthUser?>.broadcast()`).
- FirebaseWeb 초기화 시 `auth.FirebaseAuth.instance.authStateChanges()` 스트림을 구독하여 `_currentUser` 및 `_authStateController` 상태를 최신화.

#### 5.1.3 메서드 시그니처

```dart
// 초기화 / 인증 (v3.5 Auth SDK 활용)
static Future<void> initialize();
Stream<AuthUser?> get authStateChanges;
String? get currentUserId;
AuthUser? get currentUser;

Future<AuthUser> signUpWithEmail(String email, String password); // SDK createUserWithEmailAndPassword
Future<AuthUser> loginWithEmail(String email, String password);  // SDK signInWithEmailAndPassword
Future<void> logout();                                           // SDK signOut

// 이미지
Future<String> uploadImage(Uint8List bytes, String extension);

// 옷장
Future<void> saveClothingData({
  required String imageUrl,
  required String category,
  required String subCategory,
  required String tags,
});
Stream<QuerySnapshot> getClothesStream();
Future<void> updateClothingData({required String docId, required Map<String,dynamic> updatedData});
Future<void> deleteClothingData(String docId);

// OOTD (저장/스트림/삭제)
Future<void> saveOOTDData({
  required String imageUrl,
  required String description,
  required List<Map<String, dynamic>> taggedClothes,
  DateTime? date, // v3.5 신규: 과거 날짜 지원
});
Future<void> updateOOTDDate(String docId, DateTime newDate);     // v3.5 신규: 기존 OOTD 날짜 단독 수정
Future<void> updateOOTDTags(String docId, List<Map<String, dynamic>> newTaggedClothes);
Stream<QuerySnapshot> getOOTDStream();                           
Future<void> deleteOOTDData(String docId);

// OOTD 최적화 조회
Future<List<QueryDocumentSnapshot>> getOOTDPage({DocumentSnapshot? lastDoc, int limit = 10});
Future<List<QueryDocumentSnapshot>> getOOTDsByMonth(int year, int month);
```

#### 5.1.4 Auth SDK 에러 메시지 매핑 (한국어)
| `e.code` | 사용자 메시지 |
|---|---|
| `email-already-in-use` | `이미 등록된 이메일입니다.` |
| `invalid-email` | `유효하지 않은 이메일 형식입니다.` |
| `weak-password` | `비밀번호가 너무 약합니다. (6자 이상)` |
| `user-not-found` / `wrong-password` / `invalid-credential` | `이메일 또는 비밀번호가 올바르지 않습니다.` |
| `user-disabled` | `비활성화된 계정입니다.` |
| `too-many-requests` | `너무 많은 시도. 잠시 후 다시 시도하세요.` |
| 그 외 | `인증 오류: ${e.message}` |

#### 5.1.5 동작 규칙
- `saveOOTDData`는 `taggedClothes`에서 `id`만 뽑아 `taggedClothesIds`도 동시 저장. `date` 값이 들어오면 해당 값으로 `createdAt` 덮어쓰기.
- `updateOOTDDate`는 기존 문서의 `createdAt` 필드만 새 날짜로 덮어씀.
- `getOOTDPage`: `where(userId) + orderBy(createdAt desc) + limit(limit)`. `lastDoc`이 있으면 `startAfterDocument` 적용.
- `getOOTDsByMonth(year, month)`: `startOfMonth`와 `startOfNextMonth`를 계산하여 범위 조건으로 가져옴. **orderBy 없음**.

### 5.2 `lib/main.dart`
- `main()`은 try/catch 감싸서 에러 시 SelectableText로 출력하는 폴백 `MaterialApp` 표시.
- `WidgetsFlutterBinding.ensureInitialized()` → `FirebaseService.initialize()` → `runApp(const DigitalClosetApp())`.
- `DigitalClosetApp.home`은 `AuthWrapper`.
- `AuthWrapper`는 `StreamBuilder<AuthUser?>(stream: authStateChanges, initialData: currentUser)`. snapshot.hasData면 `MainScreen`, 아니면 `LoginScreen`.

### 5.3 `lib/utils/categories.dart`

```dart
class CategoryData {
  static const Map<String, List<String>> categories = { ... };
  static List<String> get mainCategories;                       // categories.keys.toList()
  static List<String> getSubCategories(String mainCategory);    // categories[main] ?? []
  static String getIconPath(String subCategory);                // 'assets/icons/{정규화된 파일명}.png'
}
```

#### 5.3.1 카테고리 트리 (정확한 순서 — UI 노출 순서이기도 함)
| 대분류 | 소분류 |
|---|---|
| **상의** | 티셔츠, 긴팔 티, 민소매 티, 카라 티, 캐미솔/탱크탑, 크롭탑, 블라우스, 셔츠, 맨투맨, 후드, 니트, 니트조끼, 스포츠 상의, 바디수트 |
| **원피스** | 캐주얼 원피스, 티셔츠 원피스, 셔츠 원피스, 맨투맨/후드원피스, 니트 원피스, 자켓 원피스, 멜빵 원피스, 점프수트, 파티/이브닝 원피스, 미니원피스 |
| **바지** | 청바지, 긴바지, 정장바지, 운동복, 레깅스, 반바지 |
| **치마** | 미니스커트, 미디스커트, 롱스커트 |
| **아우터** | 코트, 트렌치, 털코트, 무스탕, 블레이저, 자켓, 블루종, 야구잠바, 트러커, 라이더 자켓, 가디건, 집업, 야상, 스포츠 아우터, 후리스, 파카, 경량 패딩, 패딩, 조끼 |
| **신발** | 스니커즈, 슬립온, 운동화, 등산화, 부츠, 워커, 어그부츠, 로퍼/블로퍼, 보트/모카슈즈, 플랫슈즈, 힐, 샌들, 샌들힐, 슬리퍼, 뮬 힐 |
| **가방** | 토트백, 숄더백, 크로스백, 웨이스트백, 에코백, 백팩, 보스턴백, 클러치백, 서류가방, 짐색, 캐리어 |
| **모자** | 캡, 햇, 비니, 베레모, 페도라, 썬햇 |
| **악세서리** | (소분류 없음) |
| **기타** | (소분류 없음) |

#### 5.3.2 `getIconPath` 정규화
```dart
final fileName = subCategory.replaceAll('/', '_').replaceAll(' ', '');
return 'assets/icons/$fileName.png';
```
> 파일이 없는 경우 호출부에서 `Image.asset(..., errorBuilder: ...)` 으로 `Icons.checkroom` 등 대체 표시.

---

## 6. 화면별 상세 구현

### 6.1 로그인 (`login_screen.dart`)
- StatefulWidget. 컨트롤러: `_emailController`, `_passwordController`. 플래그: `_isLoginMode = true`, `_isLoading = false`.
- 레이아웃: `Scaffold > Center > SingleChildScrollView(padding 24) > Column(stretch)`
  1. `Icon(Icons.inventory_2_rounded, size 80, primary)`
  2. SizedBox 16 → `Text('나만의 디지털 옷장', 28 bold, center)`
  3. SizedBox 8 → `Text('어디서든 내 옷을 관리하세요', 16 grey[600], center)`
  4. SizedBox 48 → 이메일 `TextField` (`prefixIcon Icons.email_outlined`, OutlineInputBorder 12, focused border `Colors.black`)
  5. SizedBox 16 → 비밀번호 `TextField` (`obscureText: true`, `prefixIcon Icons.lock_outline`, 동일 스타일)
  6. SizedBox 24 → `_isLoading ? CircularProgressIndicator : FilledButton(black, padding vertical 16, radius 12, label '로그인'/'회원가입' 18 bold white)`
  7. SizedBox 16 → 모드 전환 `TextButton`: `'계정이 없으신가요? 새로 가입하기'` ↔ `'이미 계정이 있으신가요? 로그인하기'`. `foregroundColor: Colors.grey[800]`, bold.
- `_submit()`:
  - 이메일/비밀번호 trim 후 비어있으면 SnackBar `'이메일과 비밀번호를 모두 입력해주세요.'`.
  - try: `_isLoginMode ? loginWithEmail : signUpWithEmail`. 성공 시 화면 전환은 AuthWrapper가 처리.
  - catch: SnackBar `오류 발생: $e` (배경 `Theme.of(context).colorScheme.error`).
  - finally: `_isLoading = false`.

### 6.2 메인 네비게이션 (`main_screen.dart`)
- 4탭 `BottomNavigationBar` (`type: fixed`, `elevation: 0`, `backgroundColor: white`, `showSelectedLabels: false`, `showUnselectedLabels: false`).
- `_pages` 배열 (인덱스 2는 placeholder):
  - 0: `HomeScreen`
  - 1: `OotdScreen`
  - 2: `SizedBox.shrink()` (탭 시 BottomSheet)
  - 3: `ProfileScreen`
- `onTap`: 인덱스 2면 `_showUploadBottomSheet`, 그 외엔 `setState(_currentIndex = i)`.
- 아이콘 (선택 시 black, 비선택 시 `Colors.grey[400]`):
  - 0: `Icons.grid_view_rounded` size 28, label `'옷장'`
  - 1: 사각형 컨테이너(width 26, height 30, border 2px, radius 4) + 내부 `Icons.person` 18px → "전신거울 + 인물" 모티프, label `'OOTD'`
  - 2: 원형 컨테이너(28×28, border 2px black) + 중앙 `'+'` 18 bold black height 1.1, label `'추가'` (선택 색 무관 항상 black)
  - 3: `Icons.person_outline` size 30, label `'프로필'`
- **추가 BottomSheet** (`_showUploadBottomSheet`):
  - `RoundedRectangleBorder(top radius 20)`, `SafeArea > Padding(vertical 24) > Column(min)`
  - 제목 `Text('무엇을 추가할까요?', 18 bold)` + SizedBox 24
  - 항목 1: `ListTile(leading: CircleAvatar(black, Icons.checkroom white), title: '옷장에 새 아이템 추가' w600)` → `Navigator.pop` 후 `UploadScreen` (`fullscreenDialog: true`)
  - 항목 2: `ListTile(leading: CircleAvatar(black, Icons.camera_alt_outlined white), title: '오늘의 OOTD 기록하기' w600)` → `UploadOotdScreen` (`fullscreenDialog: true`)

### 6.3 옷장 홈 (`home_screen.dart`)
- 상단 AppBar:
  - 제목 `'MY CLOSET'` (bold, letterSpacing 1.2, black).
  - **`actions: [IconButton(Icons.search, color: Colors.black, onPressed: → SearchClothesScreen 푸시)]`**
- `initState`에서 두 스트림 1회 캐시:
  - `_clothesStream = _firebaseService.getClothesStream()`
  - `_ootdStream = _firebaseService.getOOTDStream()` ← OOTD 사용 횟수 카운트용
- 카테고리 정의 (총 11개, 첫 항목은 `'ALL'`):
  ```
  ALL          → Icons.all_inclusive_rounded
  상의          → assets/icons/티셔츠.png
  ...
  ```
  > 카테고리 객체에 `imageAsset` 키가 있으면 `Image.asset(...)` (size 32, color 분기), 없으면 `icon` 키의 IconData 사용.
- **이중 StreamBuilder 구조**:
  1. **외부 StreamBuilder**: `_ootdStream`. OOTD 문서들을 순회하며 `tagCounts: Map<String,int>`를 만든다.
     - 각 OOTD에서 `taggedClothesIds`(List)를 우선 사용. 비어있으면 `taggedClothes` 배열에서 `id`를 추출(이전 데이터 호환).
     - 각 ID마다 `tagCounts[id]++`.
  2. **내부 StreamBuilder**: `_clothesStream`.
     - `waiting` → 중앙 `CircularProgressIndicator(black)`
     - 정상: `clothes = snapshot.data?.docs ?? []`
     - 클라이언트 사이드 필터링: `_selectedCategory == 'ALL'` ? 전체 : `data['category'] == _selectedCategory`.
- 본문 Column 구조:
  1. **상단 카운트 줄** `Padding(left/right 16, top 16, bottom 4)`: 좌측 선택 카테고리명, 우측 건수.
  2. `_buildStoryCategories()`: height 100, horizontal `ListView.builder` 11 items. 원형 컨테이너 안에 아이콘/이미지.
  3. `Divider(height 1, thickness 1, Color(0xFFEEEEEE))`
  4. **그리드 영역 (`Expanded`)**:
     - `GridView.builder(BouncingScrollPhysics, padding 16/8)` 3열, crossAxisSpacing 12, mainAxisSpacing 16, childAspectRatio 0.6.
     - 아이템: `GestureDetector(onTap → ClothingDetailScreen)` > Column > `Expanded` 안에 `Image.network(imageUrl, fit: cover)`
     - **OOTD 사용 횟수 뱃지** (`tagCount > 0`일 때만): `Positioned(top: 6, right: 6) > Container > Icon(Icons.bookmark)` + `'$tagCount'`
     - 하단 타이틀/서브타이틀: `'$color $pattern'.trim()` 등 조합.

### 6.4 옷장 검색 (`search_clothes_screen.dart`) — 선택 모드 포함
- `isSelectionMode = false`, `Set<String>? initialSelectedIds`
- OOTD 태그 수정 진입 시 `isSelectionMode = true`로 활성화됨. 선택 모드 종료 시 선택된 옷 정보 List 반환.
- 클라이언트 AND 필터 적용 (4단계 필터링: 대분류, 소분류, 색상, 키워드).
- 일반 모드: 탭 시 상세 화면 푸시.
- 선택 모드: 탭 시 `_selectedIds` 토글. 이미지 컨테이너에 `Border.all(black, width 3)`과 우상단 `Icons.check` 표시.

### 6.5 OOTD 피드 (`ootd_screen.dart`) — 무한 스크롤 및 **수정 기능**
- 상태: `_scrollController`, `_ootds`(누적 로딩 결과), `_isLoading=false`, `_hasMore=true`, `_lastDocument: DocumentSnapshot?`
- `_loadOotds(refresh: false)`: `getOOTDPage(lastDoc, limit 10)`로 추가 로딩. `_scrollController`의 끝단 200px 이전 도달 시 호출됨.
- AppBar: `title: 'OOTD'`, `actions: [IconButton(Icons.calendar_month, onPressed: OotdCalendarScreen 푸시)]`
- **게시물 위젯 (`_buildOotdPost`)**:
  - **헤더 영역**:
    - 날짜 `Text(intl.DateFormat('yyyy년 MM월 dd일').format(timestamp))` 옆에 2개의 `IconButton`을 나란히 배치:
    - **1) 날짜 수정 버튼 (v3.5 신규)**: `IconButton(icon: Icon(Icons.calendar_month, size 20, color Colors.black54), padding zero, constraints BoxConstraints())`. 누르면 `showDatePicker` 팝업을 띄우고(과거 날짜 한정), 새 날짜 선택 시 `updateOOTDDate` 호출 후 `_loadOotds(refresh: true)` + SnackBar 노출.
    - **2) 태그 수정 버튼**: `IconButton(icon: Icon(Icons.edit, size 20, color Colors.black54), ...)`. 누르면 `SearchClothesScreen` 호출하여 태그 목록 변경 후 `updateOOTDTags` 호출.
  - **이미지 영역**: `Image.network(imageUrl, BoxFit.contain)` (높이 400 고정, 배경 grey[100]).
  - **코멘트 및 태그된 옷 가로 리스트** 하단 렌더링.

### 6.6 OOTD 캘린더 (`ootd_calendar_screen.dart`) — **수정 기능 포함**
- `table_calendar` 라이브러리 사용.
- `onPageChanged`에서 `getOOTDsByMonth`를 호출하여 매 월 단위 데이터만 가져옴. (`_ootdEvents` 맵핑)
- **TableCalendar 설정**: `markerBuilder`에서 이미지 마커 커스텀(흰 테두리 원형, 겹칠 경우 숫자 뱃지 표시).
- **결과 리스트 영역**: 선택된 날짜(`_selectedDay`)의 OOTD 리스트 렌더링.
  - 각 카드 우측에 **날짜 수정 버튼 (v3.5 신규)** 추가: `IconButton(icon: Icon(Icons.calendar_month, size: 18, color Colors.grey))`. 클릭 시 `showDatePicker` 팝업 호출, 새 날짜 선택 시 `updateOOTDDate` 실행 및 해당 월 다시 로드(`_loadEventsForMonth`).

### 6.7 옷 추가 (`upload_screen.dart`)
- 사진 박스(최상단)와 앨범 열기 버튼.
- 대분류 `ChoiceChip`, 소분류 `ChoiceChip` 선택.
- 최종 업로드 버튼 누르면 `.jpg`로 변환하여 Firebase Storage에 업로드 및 Firestore에 데이터 추가.

### 6.8 옷 상세 (`clothing_detail_screen.dart`)
- **OOTD 활용 통계 섹션**: `getOOTDStream`을 클라이언트단에서 순회하며 현재 옷(`docId`)이 `taggedClothesIds`에 포함된 OOTD 게시물들의 썸네일을 가로 스크롤로 나열 표시. `이 옷을 활용한 OOTD: N번` 문구 표출.
- 기본 정보 및 메모 폼 렌더링. 대분류/소분류 DropdownButtonFormField 사용. 수정 저장 및 삭제 지원.

### 6.9 OOTD 작성 (`upload_ootd_screen.dart`) — **과거 날짜 선택 기능**
- 상태: `DateTime _selectedDate = DateTime.now();`, `_descController`, 사진 바이트, `_selectedClothesIds` 등.
- 갤러리 이미지 선택(`_pickImage`) 시 `await image.lastModified()`를 시도하여 사진의 메타데이터 날짜로 `_selectedDate` 상태 갱신. (가져올 수 없는 경우 기본값 유지).
- **날짜 선택 UI (v3.5 신규)**: 코멘트 입력창 윗부분에 캘린더 Row 삽입:
  ```dart
  Row(
    children: [
      Icon(Icons.calendar_today),
      Text('날짜'),
      Spacer(),
      TextButton(
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (picked != null) setState(() => _selectedDate = picked);
        },
        child: Text('${_selectedDate.year}년 ... 일'),
      ),
    ]
  )
  ```
- **태그 옷 선택 UI**: 하단에 옷장 이미지 가로 스크롤 나열 후 탭하여 다중 선택 가능.
- 업로드 버튼 누를 시 `saveOOTDData(date: _selectedDate)`로 명시적 과거 날짜 적용.

### 6.10 프로필 (`profile_screen.dart`)
- 유저 이메일 표시, 둥근 외곽선 로그아웃 버튼 배치 (`firebaseService.logout()` 후 자동 AuthWrapper에 의해 Login 화면 복귀).

---

## 7. 주요 구현 규칙 (바이브코딩 지침)

1. **모든 사용자향 텍스트는 한국어**.
2. **웹 빌드 시 아이콘 누락 방지**: `--no-tree-shake-icons` 플래그 필수. 또한 v3.5부터 웹에서 호환성 문제가 생길 수 있는 `Icons.edit_calendar` 대신 검증된 `Icons.calendar_month` 아이콘을 사용하여 날짜 수정 버튼을 렌더링한다.
3. **복합 인덱스는 의도적으로만 사용**:
   - `clothes`: `userId + createdAt desc` 인덱스 사용.
   - `ootds`: `userId + createdAt desc` 및 `userId + createdAt asc` 복합 인덱스 필수 세팅.
4. **이미지 표시 원칙**: 옷 상세, 업로드 미리보기, OOTD 사진은 모두 `BoxFit.contain` + 회색 배경 (`Colors.grey[100]`)으로 잘림 방지. 옷 그리드 썸네일과 캘린더 마커만 `BoxFit.cover`.
5. **싱글톤 컨벤션**: `FirebaseService()`로 어디서든 인스턴스화하되, 상태관리는 정적(static) 멤버나 스트림으로 유지.
6. **`pickImage` 옵션 표준화**: maxWidth/maxHeight 1080, imageQuality 70.
7. **에러 표면화**: 네트워크/저장 실패는 SnackBar로 사용자에게 보이고, finally에서 로딩 상태 해제.
8. **카테고리 변경 시 항상 소분류 리셋**: 업로드/상세/검색 모두 동일 규칙.
9. **`taggedClothesIds` 동시 갱신**: OOTD 저장·태그 수정 모든 경로에서 `taggedClothes`와 `taggedClothesIds`를 함께 업데이트. 카운트/검색 효율을 위함이며, 이전 데이터 호환을 위해 읽기 측에서는 폴백 로직을 둔다.
10. **달력 월 단위 로딩**: 전체를 로딩하지 않고 월 단위로 끊어서 페칭.

---

## 8. 빌드 및 배포 (Firebase Hosting)

프로젝트 최상단에 자체 `firebase_bin` 바이너리 존재.

```bash
fvm flutter build web --no-tree-shake-icons \
  && ./firebase_bin deploy --only hosting
```

배포 산출물 경로: `build/web`. `firebase.json`의 `hosting.rewrites`를 통해 모든 경로를 `/index.html`로 보내어 SPA 라우팅 호환을 맞춤.

---

## 9. 알려진 제약 / 고려사항

- **확장자 처리**: `upload_screen.dart`은 모든 사진을 `.jpg`로 변환/저장 (image_quality 70 압축). `upload_ootd_screen.dart`는 사진의 원본 확장자 유지.
- **달력 화면의 `memo` 표시**: 현재 `saveOOTDData`는 `memo` 필드를 저장하지 않으므로(코멘트는 `description`에 저장) 캘린더 카드에서 `memo`를 호출하는 기존 디자인 잔재가 비어있게 표시됨. (필요 시 description 표시로 UI 개선 고려).
- **인덱스**: `firestore.indexes.json` 적용을 위해 `firebase deploy --only firestore:indexes`를 수행하여 Firebase 콘솔에 인덱스를 명확히 올려두어야 페이징과 달력 조회 쿼리가 올바르게 동작함.
- **스트림 + 페이지네이션 혼용의 한계**: HomeScreen은 OOTD를 스트림(카운트용)으로, OotdScreen은 페이지네이션(피드용)으로 둘 다 사용 중이므로 새 OOTD 등록 시 카운트는 즉시 오르나 피드는 새로고침(RefreshIndicator) 전까지 반영 안 될 수 있음.
