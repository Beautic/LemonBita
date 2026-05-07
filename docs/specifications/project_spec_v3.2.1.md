# 디지털 옷장 (My Digital Closet) 작업지시서 v3.2.1

이 문서는 v3.2의 상세 보강판입니다. AI 어시스턴트가 이 문서만으로 현재 동작 중인 Flutter 웹 앱을 구조·동작·UI 디테일까지 거의 동일하게 재구현할 수 있도록, 화면별 위젯 트리·상수 값·서비스 시그니처·필터링 로직·예외 케이스를 모두 명시합니다. (v3.2.1: 바이브 코딩용 상세 사양 보강. 기능 동등.)

---

## 1. 프로젝트 개요
- **앱 이름**: My Digital Closet (나만의 디지털 옷장)
- **목적**: 사용자가 자신의 옷 사진을 찍어 카테고리별로 관리하고, 옷장 아이템을 태깅하여 매일의 데일리룩(OOTD)을 기록·검색하는 애플리케이션
- **플랫폼**: Flutter (Web 우선, iOS/Android 호환 구조)
- **주요 기능**: 이메일 회원가입/로그인(REST), 옷 사진 업로드(카메라/갤러리), 대분류·소분류 2단계 카테고리, 커스텀 라인아트 아이콘, 상세 메타데이터 관리, 4탭 하단 네비게이션, OOTD 작성 및 옷 태깅, 옷장 다중 조건 검색(자유 텍스트 + 대분류/소분류/색상)

---

## 2. 기술 스택 및 패키지 (`pubspec.yaml`)

```yaml
environment:
  sdk: '>=3.2.6 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2
  firebase_core:    '>=2.27.0 <2.31.0'
  cloud_firestore:  '>=4.15.8 <4.18.0'
  firebase_storage: '>=11.6.9 <11.8.0'
  image_picker:     ^1.0.8
  http:             ^1.2.0
  shared_preferences: ^2.2.3
  intl:             ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints:    ^2.0.0
  mockito:          ^5.4.4
  build_runner:     ^2.4.8
  fake_cloud_firestore: ^2.4.8

flutter:
  uses-material-design: true
  assets:
    - assets/icons/
```

- **상태 관리**: `setState` + `StreamBuilder` 만 사용 (Provider/Riverpod/Bloc 등 도입하지 않음)
- **백엔드**: Firebase (Firestore, Storage). 인증은 **Firebase Auth REST API 직접 호출** (firebase_auth SDK 미사용)
- **세션**: `SharedPreferences`에 `uid/email/idToken/refreshToken` 저장

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
| `userId` | String | 작성자 UID (Auth REST의 `localId`) |
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
| `taggedClothes` | List<Map> | 태그된 옷의 비정규화 정보. 항목당 `{id: String, imageUrl: String, title: String}`. 피드 로딩 시 옷 컬렉션 추가 조회 없이 표시 |
| `createdAt` | Timestamp | `FieldValue.serverTimestamp()` |

`taggedClothes[i].title` 생성 규칙: `'${color} ${pattern}'.trim()` 우선, 비면 `brand`, 그래도 비면 `category`, 마지막 폴백 `'옷 정보 없음'`. (구현: `upload_ootd_screen.dart` 95~98행, `home_screen.dart` 203~207행 동일 로직)

### 4.3 Storage 경로
- 모든 사진(옷·OOTD 공용): `clothes/{millisecondsSinceEpoch}.{ext}`
- 컨텐트 타입: `image/{ext}` (`SettableMetadata`)

### 4.4 Firestore 보안 규칙 (현재)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```
> 현 단계는 **개발·시연 단계 완전 오픈 규칙**. 운영 전환 시 `userId` 기준 read/write 규칙으로 전환 예정.

---

## 5. 코드 구조

```
lib/
├── main.dart                     # 진입점, 테마, AuthWrapper
├── services/
│   └── firebase_service.dart     # 싱글톤 백엔드 서비스
├── utils/
│   └── categories.dart           # 카테고리 데이터 + 아이콘 매핑
└── screens/
    ├── login_screen.dart
    ├── main_screen.dart
    ├── home_screen.dart
    ├── ootd_screen.dart
    ├── upload_screen.dart
    ├── upload_ootd_screen.dart
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
  final String idToken;
  final String refreshToken;
}
```

#### 5.1.2 `FirebaseService` (인스턴스화 가능, 정적 상태 공유)
- 정적 멤버: `_currentUser`, `_authStateController` (`StreamController<AuthUser?>.broadcast()`).
- SharedPreferences 키: `auth_uid`, `auth_email`, `auth_idToken`, `auth_refreshToken`.
- Firebase Web API Key (예시): `AIzaSyA53XksiSaTI_S7TjENSv1J_slbSOWTwPg` (소스 상수)
- Firebase 옵션 (Web):
  ```
  appId:             "1:891078999530:web:12ba98b8ab107e5ef24693"
  messagingSenderId: "891078999530"
  projectId:         "digital-closet-32c43"
  storageBucket:     "digital-closet-32c43.firebasestorage.app"
  authDomain:        "digital-closet-32c43.web.app"
  ```

#### 5.1.3 메서드 시그니처
```dart
static Future<void> initialize();                                    // Firebase.initializeApp + 세션 복원 + 초기 emit
Stream<AuthUser?> get authStateChanges;
String? get currentUserId;
AuthUser? get currentUser;

Future<AuthUser> signUpWithEmail(String email, String password);    // identitytoolkit:signUp
Future<AuthUser> loginWithEmail(String email, String password);     // identitytoolkit:signInWithPassword
Future<void> logout();                                               // _currentUser = null + clearSession + emit null

Future<String> uploadImage(Uint8List bytes, String extension);

Future<void> saveClothingData({                                      // clothes.add
  required String imageUrl,
  required String category,
  required String subCategory,
  required String tags,
});
Stream<QuerySnapshot> getClothesStream();                            // where(userId) + orderBy(createdAt desc) + snapshots
Future<void> updateClothingData({required String docId, required Map<String,dynamic> updatedData});
Future<void> deleteClothingData(String docId);

Future<void> saveOOTDData({                                          // ootds.add
  required String imageUrl,
  required String description,
  required List<Map<String, dynamic>> taggedClothes,
});
Stream<QuerySnapshot> getOOTDStream();                               // where(userId) + snapshots (orderBy 없음 — UI에서 로컬 정렬)
Future<void> deleteOOTDData(String docId);
```

#### 5.1.4 Auth REST 에러 메시지 매핑 (한국어)
| REST `error.message` | 사용자 메시지 |
|---|---|
| `EMAIL_EXISTS` | `이미 등록된 이메일입니다.` |
| `INVALID_EMAIL` | `유효하지 않은 이메일 형식입니다.` |
| `WEAK_PASSWORD` | `비밀번호가 너무 약합니다. (6자 이상)` |
| `EMAIL_NOT_FOUND` / `INVALID_PASSWORD` / `INVALID_LOGIN_CREDENTIALS` | `이메일 또는 비밀번호가 올바르지 않습니다.` |
| `USER_DISABLED` | `비활성화된 계정입니다.` |
| `TOO_MANY_ATTEMPTS_TRY_LATER` | `너무 많은 시도. 잠시 후 다시 시도하세요.` |
| 그 외 | `인증 오류: {원문 메시지}` |

#### 5.1.5 동작 규칙
- `currentUserId == null`일 때 `getClothesStream()`/`getOOTDStream()`는 `Stream.empty()` 반환.
- `currentUserId == null`일 때 모든 write 메서드는 `Exception("로그인이 필요합니다.")` throw.
- `saveClothingData`는 이미지 업로드 후 따로 호출되어 URL을 인자로 받음.
- 카테고리/태그 외 추가 메타데이터(brand, color 등)는 **저장 시 생략**되고 상세 화면에서 별도 update로 채워짐.

### 5.2 `lib/main.dart`
- `main()`은 try/catch 감싸서 에러 시 SelectableText로 출력하는 폴백 `MaterialApp` 표시.
- `WidgetsFlutterBinding.ensureInitialized()` → `FirebaseService.initialize()` → `runApp(const DigitalClosetApp())`.
- `DigitalClosetApp.home`은 `AuthWrapper`.
- `AuthWrapper`는 `StreamBuilder<AuthUser?>(stream: authStateChanges, initialData: currentUser)`. snapshot.hasData면 `MainScreen`, 아니면 `LoginScreen`.

### 5.3 `lib/utils/categories.dart`

```dart
class CategoryData {
  static const Map<String, List<String>> categories = { ... };  // 아래 표 참조
  static List<String> get mainCategories;                        // categories.keys.toList()
  static List<String> getSubCategories(String mainCategory);     // categories[main] ?? []
  static String getIconPath(String subCategory);                 // 'assets/icons/{정규화된 파일명}.png'
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
  - try: `_isLoginMode ? loginWithEmail : signUpWithEmail`. 성공 시 화면 전환은 AuthWrapper가 알아서 처리 (별도 `Navigator.push` 없음).
  - catch: SnackBar `오류 발생: $e` (배경 `Theme.of(context).colorScheme.error`).
  - finally: `_isLoading = false`.

### 6.2 메인 네비게이션 (`main_screen.dart`)
- 4탭 `BottomNavigationBar` (`type: fixed`, `elevation: 0`, `backgroundColor: white`, `showSelectedLabels: false`, `showUnselectedLabels: false`).
- `_pages` 배열 (인덱스 2는 `SizedBox.shrink()` placeholder):
  - 0: `HomeScreen`
  - 1: `OotdScreen`
  - 2: 자리만 차지 (탭 시 BottomSheet)
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
- 상단 AppBar: 제목 `'MY CLOSET'` (bold, letterSpacing 1.2, black).
- `initState`에서 `_clothesStream = _firebaseService.getClothesStream()` 1회 캐시.
- `StreamBuilder<QuerySnapshot>`:
  - `connectionState == waiting` → 중앙 `CircularProgressIndicator(color: black)`
  - `hasError` → `_buildErrorState(error)`: 가운데 정렬, `Icon(Icons.error_outline, 64, redAccent)` + `'데이터를 불러오지 못했습니다.\n{error}'` (black54, center)
  - 정상: `clothes = snapshot.data?.docs ?? []`
- 카테고리 필터 정의 (인스타 스토리 행, 총 11개 — `'ALL'` 포함):
  ```
  ALL          → Icons.all_inclusive_rounded
  상의          → assets/icons/티셔츠.png
  원피스        → assets/icons/캐주얼원피스.png
  바지          → assets/icons/청바지.png
  치마          → assets/icons/미니스커트.png
  아우터        → assets/icons/자켓.png
  신발          → assets/icons/스니커즈.png
  가방          → assets/icons/에코백.png
  모자          → assets/icons/캡.png
  악세서리      → Icons.watch_rounded
  기타          → Icons.more_horiz_rounded
  ```
  > 카테고리 객체에 `imageAsset` 키가 있으면 `Image.asset(...)` (size 32, color 분기), 없으면 `icon` 키의 IconData 사용.
- 클라이언트 사이드 필터링: `_selectedCategory == 'ALL'` ? 전체 : `data['category'] == _selectedCategory`.
- 본문 Column 구조:
  1. **상단 카운트 줄** `Padding(left/right 16, top 16, bottom 4)`:
     - 좌: `_selectedCategory == 'ALL' ? 'All Items' : _selectedCategory` (15 bold)
     - 우: ALL이면 `'{N} items · 10 categories'` / 아니면 `'{filtered} items'` (12, grey[600])
  2. `_buildStoryCategories()`: height 100, vertical padding 12, horizontal `ListView.builder` 11 items
     - 각 아이템: 우측 16 padding, 가운데 정렬 Column
       - 56×56 원형 컨테이너 (`shape: circle`, `Border` 2.5/black or 1.0/grey[300], 흰 배경, 내부 32×32 이미지 또는 24 아이콘. color 분기: 선택 black, 비선택 grey[600])
       - SizedBox 6
       - 라벨 11px (선택 black bold, 비선택 grey[600] normal)
  3. `Divider(height 1, thickness 1, Color(0xFFEEEEEE))`
  4. **그리드 영역 (`Expanded`)**:
     - filteredClothes 비어있으면 가운데 `Icon(Icons.inventory_2_outlined, 64, grey[300])` + SizedBox 16 + `'이 카테고리에는\n등록된 옷이 없습니다.'` (grey[500], center).
     - 그렇지 않으면 `GridView.builder(BouncingScrollPhysics, padding 16/8)` 3열, crossAxisSpacing 12, mainAxisSpacing 16, childAspectRatio 0.6.
     - 아이템 `_buildClothingGridItem(docId, item)`: `GestureDetector(onTap → ClothingDetailScreen)` >
       Column(crossAxisStart):
       - `Expanded > ClipRRect(radius 8) > Hero(tag: docId) > Image.network(imageUrl, fit: cover, errorBuilder → grey[100] + Icons.image_not_supported)`
       - SizedBox 6
       - **타이틀** (1줄, ellipsis, 12 bold black87): `'$color $pattern'.trim()` 우선 → 비면 `brand` → 비면 `category` → 폴백 `'옷 정보 없음'`.
       - SizedBox 2
       - **서브타이틀** (1줄, ellipsis, 11 grey[600]): `subCategory` 있으면 `'$category · $subCategory'`, 없으면 `category`.

### 6.4 옷장 검색 (`search_clothes_screen.dart`) — v3.2 추가, **Client-side AND 필터**
- 진입 경로: 현재 코드는 자동 진입이 아닌 별도 진입점 필요 (HomeScreen AppBar 우측 돋보기 버튼 추가 가능). 화면 자체는 독립 페이지.
- 상태:
  - `_searchController`, `_allClothes`, `_filteredClothes`, `_isLoading=true`
  - `_selectedMajorCategory`, `_selectedSubCategory`, `_selectedColor` (모두 nullable)
  - `_commonColors = ['블랙','화이트','그레이','네이비','블루','레드','핑크','그린','옐로우','베이지','브라운','기타']` (12개, 정확한 순서)
- `initState`:
  - `_fetchAllClothes()`: `FirebaseFirestore.instance.collection('clothes').where('userId', isEqualTo: currentUserId).orderBy('createdAt', descending: true).get()` → setState로 `_allClothes` 채움 + `_filteredClothes = _allClothes`. 실패 시 `debugPrint`만 하고 `_isLoading=false`.
  - `_searchController.addListener(_applyFilters)` (텍스트 변경 시 즉시 필터)
- AppBar:
  - title: `TextField(autofocus: true, hintText: '브랜드, 태그, 패턴 등으로 검색', hintStyle grey[400], border: InputBorder.none, suffixIcon: 텍스트 비어있으면 null else IconButton(Icons.clear grey, onPressed → clear+applyFilters), style 16)`
  - bottom: `PreferredSize(height: 130) > Column`:
    1. `Divider(height 1)`
    2. **대분류 행** `SingleChildScrollView(horizontal, padding 16/8)`:
       - 첫 칩: `FilterChip('초기화', backgroundColor grey[200], radius 20, onSelected: _resetFilters)`
       - 이후: `CategoryData.mainCategories` 순서대로 `FilterChip(cat, selected: _selectedMajorCategory == cat, selectedColor black, label color: 선택 white/비선택 black, onSelected: 토글 시 _selectedSubCategory도 null, radius 20)`
    3. **소분류 행** (대분류 선택 + 소분류 존재할 때만): `SingleChildScrollView(horizontal, padding 16/0)` → `ChoiceChip(subCat, selectedColor grey[800], 선택 white/비선택 black87, radius 20)`
    4. SizedBox 8 (대분류 선택 시에만)
    5. **색상 행** `SingleChildScrollView(horizontal, padding 16/8)`: `_commonColors`를 `ChoiceChip(color, selectedColor grey[800], 선택 white/비선택 black87, radius 20)`로 나열
- `_applyFilters()` (Client-side AND 필터링, 4단계):
  1. `_selectedMajorCategory != null && data['category'] != _selectedMajorCategory` → 제외
  2. `_selectedSubCategory != null && data['subCategory'] != _selectedSubCategory` → 제외
  3. `_selectedColor != null && !(data['color'] ?? '').toLowerCase().contains(_selectedColor!.toLowerCase())` → 제외 (부분일치)
  4. `query` 비어있지 않으면 `[category, subCategory, color, brand, pattern, tags, memo].join(' ').toLowerCase()`이 query를 contains하지 않으면 제외
- `_resetFilters()`: 컨트롤러 clear + 3 필터 null + `_applyFilters()`.
- 본문:
  - `_isLoading` → 가운데 `CircularProgressIndicator(black)`
  - 결과 비어있음 → `_buildEmptyState`: `Icon(Icons.search_off_rounded, 64, grey[300])` + SizedBox 16 + `'조건에 맞는 옷이 없습니다.'` (grey[500], 16)
  - 그 외 GridView 3열 (HomeScreen과 동일 디자인 토큰: spacing 12/16, ratio 0.6, padding 16/16). 아이템 탭 시 `ClothingDetailScreen` 이동, 돌아온 뒤 `_fetchAllClothes()` 재호출 (수정 반영).

### 6.5 OOTD 피드 (`ootd_screen.dart`)
- AppBar 제목 `'OOTD'` (bold, letterSpacing 1.2, black).
- `initState`에서 `_ootdStream = _firebaseService.getOOTDStream()` 캐시.
- `StreamBuilder<QuerySnapshot>`:
  - `waiting` → 중앙 CircularProgressIndicator(black)
  - `hasError` → `Center(Text('에러가 발생했습니다: ${snapshot.error}'))`
  - **로컬 정렬 (Firestore 복합 인덱스 회피)**: `ootds.sort((a,b) => bTime.compareTo(aTime))`. 둘 다 null=0, a만 null=1, b만 null=-1.
  - 비었음 → `Icon(Icons.camera_alt_outlined, 64, grey[300])` + SizedBox 16 + `'첫 번째 OOTD를 기록해보세요!'` (grey[500])
  - `ListView.separated(BouncingScrollPhysics)` separator: `Divider(height 32, thickness 8, Color(0xFFF5F5F5))`
- **게시물 위젯 `_buildOotdPost(docId, item)`** (Column crossAxisStart):
  1. **헤더** `Padding(horizontal 16, vertical 12) > Row`: `CircleAvatar(radius 16, black, Icons.person 20 white)` + SizedBox 10 + `'My Daily Look'` (14 bold) + Spacer + 날짜 (grey[500], 12). 날짜 포맷 `intl`의 `DateFormat('yyyy년 MM월 dd일').format(timestamp.toDate())`.
  2. **이미지** `Container(double.infinity, height 400, color grey[100]) > Image.network(imageUrl, BoxFit.contain, errorBuilder → Icons.image_not_supported grey)`.
  3. **코멘트** `description` 있을 때만 `Padding(LTRB 16 12 16 8) > Text(14, height 1.4)`.
  4. **태그된 옷 영역** `taggedClothes` 있을 때만 `Padding(LTRB 16 4 16 12) > Column(start)`:
     - 헤더 Row: `Icon(Icons.sell, 14, grey[600])` + SizedBox 4 + `Text('이 OOTD에 입은 옷', 12 bold grey[700])`
     - SizedBox 8
     - `SizedBox(height 60) > ListView.builder(horizontal, BouncingScrollPhysics)`. 항목: `Container(margin right 12, padding 4, border grey[300], radius 30) > Row(min)`: `CircleAvatar(radius 24, NetworkImage(cloth.imageUrl), backgroundColor grey[200])` + SizedBox 8 + `Padding(right 12) > Text(cloth.title, 12 w500)`.

### 6.6 옷 추가 (`upload_screen.dart`)
- AppBar 제목 `'옷장에 추가하기'` (w600).
- 상태: `_imageFile (XFile?)`, `_picker = ImagePicker()`, `_selectedCategory = '상의'`, `_selectedSubCategory = ''`, `_isLoading=false`.
- 본문 `SingleChildScrollView(padding horizontal 24, vertical 16) > Column(stretch)`:
  1. **사진 박스** `GestureDetector(onTap: _takePhoto) > Container(height 380, color surface, radius 28, border 2px primary 50% (또는 사진 있으면 transparent))`. 내부:
     - `_imageFile != null` → `ClipRRect(radius 26) > FutureBuilder<Uint8List>(_imageFile!.readAsBytes()) > Image.memory(BoxFit.contain)` (snapshot.hasData 가드, 로딩 중 CircularProgressIndicator)
     - else → 가운데 정렬 Column: `Container(padding 20, primary 10% 원형) > Icon(Icons.camera_alt_rounded, 48, primary)` + SizedBox 16 + `Text('터치해서 사진 찍기', 16 w600)`
  2. SizedBox 16 → 우측 정렬 `TextButton.icon(Icons.photo_library_rounded, '앨범에서 가져오기', onPressed: _pickFromGallery)`
  3. SizedBox 24 → `Text('대분류 선택', 18 bold)`
  4. SizedBox 16 → `Wrap(spacing 8, runSpacing 8, ChoiceChip)` — `CategoryData.mainCategories` 전체, `selectedColor: black`, label color 분기. 변경 시 `_selectedSubCategory = ''`로 리셋.
  5. SizedBox 24 → 소분류가 존재하는 대분류일 때만 `'소분류 선택'(18 bold)` + SizedBox 16 + Wrap. 각 ChoiceChip은 `avatar: Image.asset(getIconPath(sub), 24×24, color 선택 white/비선택 black87, errorBuilder → Icon(Icons.checkroom 16))`, `selectedColor grey[800]`, `backgroundColor grey[200]`, label 13.
  6. SizedBox 48 → `_isLoading ? CircularProgressIndicator : FilledButton(black, padding vertical 18) > Text('옷장에 넣기', 18 bold white)`
- 카메라/갤러리 옵션: `pickImage(source: camera|gallery, maxWidth 1080, maxHeight 1080, imageQuality 70)`. 결과 `XFile`을 그대로 보관.
- 저장 흐름:
  1. `_imageFile == null` → SnackBar `'옷 사진을 먼저 촬영해주세요!'`
  2. 소분류 존재 카테고리인데 미선택 → SnackBar `'소분류를 선택해주세요!'`
  3. `_isLoading=true` → `bytes = readAsBytes()` → `uploadImage(bytes, 'jpg')` → `saveClothingData(imageUrl, category, subCategory, tags: '#$_selectedCategory')` → `Navigator.pop`
  4. 실패 시 SnackBar `'오류 발생: $e'`. finally에서 `_isLoading=false`.
- **확장자 고정**: 현재 구현은 항상 `'jpg'`로 저장 (image_quality 70). 다른 포맷 자동 인식 없음.

### 6.7 옷 상세 (`clothing_detail_screen.dart`)
- 인자: `final String docId`, `final Map<String, dynamic> item`.
- AppBar 제목 `'옷 정보 정리'` (bold), 우측 `IconButton(Icons.delete_outline_rounded, redAccent, onPressed: _deleteItem)`.
- `initState`에서 9개 컨트롤러 초기화 (`brand, size, tags, memo, color, pattern, material, fit, length`) + `_selectedCategory`/`_selectedSubCategory` 초기화. 잘못된 값(현재 카테고리 트리에 없는)은 첫 대분류 또는 빈 문자열로 정정.
- `dispose`에서 9개 컨트롤러 dispose.
- 본문 `_isLoading ? CircularProgressIndicator : SingleChildScrollView(padding 24)`:
  1. **이미지 프리뷰** `Hero(tag: docId) > Container(height 400, grey[100], radius 28, boxShadow black 30% blur 15 offset (0,10), DecorationImage(NetworkImage, BoxFit.contain))`
  2. SizedBox 32 → `_buildSectionTitle('기본 정보')` (`Text 18 bold`)
  3. SizedBox 16 → `DropdownButtonFormField<String>` (대분류). `_inputDecoration('대분류 선택')`. 변경 시 소분류 ''로 초기화.
  4. SizedBox 16 → 해당 대분류에 소분류 있을 때만 `DropdownButtonFormField<String>` (소분류). 항목: `Row(Image.asset(iconPath 24×24 black87, errorBuilder Icons.checkroom 20) + SizedBox 12 + Text(c))`.
  5. SizedBox 16 사이사이로 `TextField(_colorController, '색상 (예: 크림 베이지)')`, pattern, material, fit, length, brand, size, tags
  6. SizedBox 24 → `_buildSectionTitle('나만의 메모')`
  7. SizedBox 16 → `TextField(_memoController, maxLines 5, '이 옷에 대한 특징이나 스타일링 팁을 적어보세요.')`
  8. SizedBox 40 → `FilledButton(black, padding vertical 20, radius 20) > Text('정보 저장하기', 18 bold white)`
  9. SizedBox 60 (스크롤 여백)
- `_inputDecoration(label)`: `filled true, fillColor grey[100], OutlineInputBorder(radius 16, none), contentPadding 20/16`.
- `_updateInfo()`: 12개 필드 update + SnackBar `'정보가 성공적으로 저장되었습니다.'` 후 pop. 실패 시 `'저장 실패: $e'`.
- `_deleteItem()`: `AlertDialog(title '옷 삭제', content '정말로 이 옷을 옷장에서 삭제하시겠습니까?', 취소/삭제(redAccent))`. 확인 시 `deleteClothingData` → pop. 실패 시 SnackBar `'삭제 실패: $e'`.

### 6.8 OOTD 작성 (`upload_ootd_screen.dart`)
- AppBar 제목 `'새로운 OOTD'` (bold). 우측 액션: `_isUploading` 일 때 작은 CircularProgressIndicator(2px black) / 평소 `TextButton('공유', black bold 16)` (onPressed: `_uploadOOTD`).
- 상태: `_descController`, `_imageBytes`, `_imageExtension`, `_isUploading=false`, `_selectedClothesIds: Set<String>`, `_allClothes: List<QueryDocumentSnapshot>`, `_isLoadingClothes=true`.
- `initState`에서 `_fetchClothes`: 옷장 전체 `where(userId).orderBy(createdAt desc).get()`.
- 본문 `SingleChildScrollView > Column(start)`:
  1. **이미지 영역** `GestureDetector(onTap: _pickImage) > Container(width double.infinity, height 350, grey[100])`:
     - `_imageBytes` 있으면 `Image.memory(BoxFit.contain)`
     - 없으면 가운데 Column: `Icon(Icons.add_a_photo_outlined 48 grey[400])` + SizedBox 12 + `'OOTD 사진 선택'` (grey[600] w600)
  2. **코멘트 입력** `Padding(16) > TextField(_descController, maxLines 3, hint '오늘의 코디에 대해 이야기해주세요...', hintStyle grey[400], border none)`
  3. `Divider(height 1, thickness 1, Color(0xFFEEEEEE))`
  4. **태그 헤더** `Padding(horizontal 16, vertical 16) > Row`: `Icon(Icons.sell_outlined 20)` + SizedBox 8 + `'이 코디에 쓰인 옷 태그하기'` (16 bold) + Spacer + `'{N}개 선택됨'` (grey[600] 13)
  5. **옷 목록 가로 스크롤**:
     - 로딩 중 → 가운데 패딩 32, CircularProgressIndicator(black)
     - 비어있음 → `Padding(horizontal 16) > Text('옷장에 등록된 옷이 없습니다.', grey[500])`
     - 그 외 → `SizedBox(height 120) > ListView.builder(horizontal, BouncingScrollPhysics, padding horizontal 12)`:
       - 아이템 width 90, margin horizontal 4. Stack:
         - 90×90 사각 컨테이너(radius 8, border 3px black or transparent, NetworkImage cover)
         - 선택 시 우상단 4/4 패딩, 검정 원, `Icon(Icons.check, 16, white)`
       - SizedBox 4 → `Text(category, 1줄 ellipsis, 11)`
  6. SizedBox 40 (스크롤 여백)
- 갤러리만 사용 (카메라 옵션 없음). `pickImage(gallery, maxWidth 1080, maxHeight 1080, imageQuality 70)`. 확장자 = 파일명 마지막 `.` 이후 (`image.name.split('.').last`). bytes로 읽어서 `_imageBytes` 갱신.
- `_uploadOOTD`:
  1. 이미지 없으면 SnackBar `'OOTD 사진을 선택해주세요.'`
  2. `_isUploading=true` → `uploadImage(bytes, ext ?? 'jpg')`
  3. `taggedClothes` 구성: `_selectedClothesIds` 포함된 옷만 모아 `{id, imageUrl, title}` 형태. title은 §4.2 규칙.
  4. `saveOOTDData(imageUrl, description.trim(), taggedClothes)` → `Navigator.pop` + SnackBar `'OOTD가 성공적으로 업로드되었습니다!'`.
  5. 실패 시 SnackBar `'업로드 실패: $e'`. finally `_isUploading=false`.

### 6.9 프로필 (`profile_screen.dart`)
- AppBar 제목 `'PROFILE'` (bold, letterSpacing 1.2, black).
- 본문 `Center > Column(center)`:
  1. 100×100 원형 회색 컨테이너(grey[200]) + `Icon(Icons.person, 60, grey)`
  2. SizedBox 24 → `Text(user?.email ?? '사용자', 18 bold)`
  3. SizedBox 48 → `OutlinedButton.icon(Icons.logout_rounded black, '로그아웃' black, padding 32/12, side black, radius 20)` → `await firebaseService.logout()` (라우팅은 AuthWrapper 자동 처리).

---

## 7. 주요 구현 규칙 (바이브코딩 지침)

1. **모든 사용자향 텍스트는 한국어**.
2. **웹 빌드 시 아이콘 누락 방지**: `--no-tree-shake-icons` 플래그 필수.
3. **복합 인덱스 회피**: `where + orderBy` 조합으로 인덱스가 필요해지는 쿼리는 만들지 말 것. 대신 `where`만 쓰고 `Dart`에서 `sort()`. 현재 `getOOTDStream`이 이 규칙을 따름. (`getClothesStream`은 `userId + createdAt desc` 인덱스가 콘솔에 자동 생성되어 있어 사용 가능 — `firestore.indexes.json`에 정의됨.)
4. **이미지 표시 원칙**: 옷 상세, 업로드 미리보기, OOTD 사진은 모두 `BoxFit.contain` + 회색 배경 (`Colors.grey[100]`)으로 잘림 방지. 옷 그리드 썸네일만 `BoxFit.cover`.
5. **싱글톤 컨벤션**: `FirebaseService()`로 어디서든 인스턴스화하되, `_currentUser`/`_authStateController`는 정적이라 상태 공유. (Dart의 `factory` 미사용 — 매번 new 해도 동일 효과)
6. **`pickImage` 옵션 표준화**: maxWidth/maxHeight 1080, imageQuality 70.
7. **에러 표면화**: 네트워크/저장 실패는 SnackBar로 사용자에게 보이고, finally에서 로딩 상태 해제.
8. **카테고리 변경 시 항상 소분류 리셋**: 업로드/상세/검색 모두 동일 규칙.
9. **`taggedClothes`의 title 규칙**(§4.2)을 OOTD 저장과 옷장 그리드 양쪽에서 동일하게 적용.

---

## 8. 빌드 및 배포 (Firebase Hosting)

프로젝트 최상단에 시스템 환경 무관한 자체 `firebase_bin` 바이너리가 존재.

```bash
.fvm/flutter_sdk/bin/flutter build web --no-tree-shake-icons \
  && ./firebase_bin deploy --only hosting
```

배포 산출물 경로: `build/web` (firebase.json `hosting.public`).

### 8.1 Firebase 프로젝트 메타
- 프로젝트 ID: `digital-closet-32c43`
- Hosting URL: `https://digital-closet-32c43.web.app`
- Storage 버킷: `digital-closet-32c43.firebasestorage.app`

### 8.2 `firebase.json` (요지)
```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**", "canvaskit/**"],
    "rewrites": [{"source": "**", "destination": "/index.html"}],
    "headers": [
      {"source": "**/*.@(js|wasm|woff2|otf|ttf|png|jpg|jpeg|svg|ico)",
       "headers": [{"key": "Cache-Control", "value": "public, max-age=31536000, immutable"}]},
      {"source": "/index.html", "headers": [{"key":"Cache-Control","value":"no-cache"}]},
      {"source": "/flutter_service_worker.js", "headers": [{"key":"Cache-Control","value":"no-cache"}]}
    ]
  }
}
```

### 8.3 `firestore.indexes.json`
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
    }
  ]
}
```

### 8.4 `web/index.html` 특이사항
- `<base href="$FLUTTER_BASE_HREF">` 그대로 유지 (Flutter가 빌드 시 치환).
- 화이트 스크린 시 에러 표시용 inline `window.onerror` 핸들러가 들어 있음 (보라색 `#8B5CF6` 로딩 텍스트 + 빨간색 에러 박스).
- `_flutter.loader.loadEntrypoint`로 부트, `renderer: "html"`로 초기화.
- Firebase JS SDK는 별도 로드하지 않음 (Flutter 플러그인이 자체 번들).

---

## 9. 알려진 제약 / TODO 후보

- **검색 화면 진입점 미배선**: `search_clothes_screen.dart`는 구현되어 있으나, `home_screen.dart` AppBar에 진입 버튼이 아직 없음. 진입을 원하면 AppBar `actions: [IconButton(Icons.search, onPressed → push SearchClothesScreen)]` 추가.
- **인증은 REST API**: `firebase_auth` SDK를 도입하지 않음. 따라서 `cloud_firestore`의 `request.auth`는 항상 null. 보안 규칙은 현재 완전 오픈(§4.4) — 운영 전환 시 firebase_auth 도입 또는 Functions/CustomToken 기반 보호 필요.
- **확장자 처리**: `upload_screen.dart`은 모든 사진을 `.jpg`로 저장. 갤러리 PNG/HEIC 등도 `.jpg`로 통일됨 (image_quality 70 압축). `upload_ootd_screen.dart`만 원본 확장자 유지.
- **로컬 정렬 비용**: OOTD 데이터가 매우 많아지면 클라이언트 정렬이 느려질 수 있음. `firestore.indexes.json`에 `ootds: userId + createdAt desc` 인덱스를 추가하고 `getOOTDStream`에 `orderBy` 붙이는 것이 향후 개선책.
