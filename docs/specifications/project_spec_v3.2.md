# 디지털 옷장 (My Digital Closet) 작업지시서 v3.2

이 문서는 AI 어시스턴트가 이 문서만을 보고 현재와 완벽하게 동일한 '나만의 디지털 옷장' Flutter 애플리케이션을 구현할 수 있도록 작성된 상세 작업지시서입니다. (v3.2: 옷장 맞춤형 다중 조건 검색 기능 추가 반영)

## 1. 프로젝트 개요
- **앱 이름**: My Digital Closet (나만의 디지털 옷장)
- **목적**: 사용자가 자신의 옷 사진을 찍어 카테고리별로 관리하고, 옷장 아이템을 태깅하여 매일의 데일리룩(OOTD)을 기록하는 애플리케이션
- **플랫폼**: Flutter (Web, iOS, Android 지원 구조, 웹(Web) 최적화 설정 포함)
- **주요 기능**: 이메일 로그인, 옷 사진 갤러리 업로드, 대분류/소분류 체계적 필터링, 커스텀 아이콘 지원, 상세 정보 관리, 하단 4탭 네비게이션, 옷장 연동 OOTD 피드 작성 및 태깅, **옷장 다중 조건 검색(텍스트/카테고리/색상)**

## 2. 기술 스택 및 패키지
- **프레임워크**: Flutter
- **상태 관리**: 기본 `setState` 및 `StreamBuilder` 사용
- **백엔드**: Firebase (Firestore, Storage) 및 Firebase Auth REST API 연동
- **주요 의존성 (pubspec.yaml)**:
  - `firebase_core`, `cloud_firestore`, `firebase_storage`
  - `http` (Auth REST API 호출용)
  - `shared_preferences` (세션 로컬 저장)
  - `image_picker` (이미지 선택)
  - `intl` (날짜 포맷팅)

## 3. 디자인 시스템 및 에셋 설정
- **테마 밝기**: Light (인스타그램 스타일 화이트 미니멀리즘)
- **전체 배경색 (Scaffold)**: `#FFFFFF` (Colors.white)
- **주조색 (Primary Color)**: `#000000` (Colors.black)
- **보조색**: `#F5F5F5` (Colors.grey[100], 카드 및 컨테이너 배경)
- **AppBar Theme**: 배경 흰색(`Colors.white`), 그림자 제거(`elevation: 0`), 글자색 검정(`Colors.black`), 시스템 UI 오버레이 아이콘 다크(`SystemUiOverlayStyle.dark`)
- **글꼴**: 기본 시스템 폰트(Roboto 등) 기반, 깔끔하고 모던한 산세리프
- **커스텀 에셋 (Custom Assets)**: 
  - `assets/icons/` 경로에 60개 이상의 옷 종류별 라인 아트(Line-art) 아이콘 이미지들(PNG)이 NFD/NFC 정규화 처리를 거쳐 저장되어 있음.
  - `lib/utils/categories.dart` 내의 `CategoryData` 클래스에서 파일명을 매핑하여 UI 곳곳(업로드, 홈 상단 필터, 상세뷰 등)에 주입함.

## 4. 데이터베이스 구조 (Firebase)

### Firestore 컬렉션: `clothes` (내 옷장)
- `userId` (String): 문서를 생성한 사용자의 UID
- `imageUrl` (String): Storage에 업로드된 사진 URL
- `category` (String): 대분류 (상의, 원피스, 바지, 치마, 아우터, 신발, 가방, 모자, 악세서리, 기타)
- `subCategory` (String): 소분류 (예: 티셔츠, 청바지, 스니커즈 등)
- `tags` (String): 해시태그
- `brand`, `size`, `color`, `pattern`, `material`, `fit`, `length`, `memo` (String, Optional)
- `createdAt` (Timestamp): 생성 시간

### Firestore 컬렉션: `ootds` (오늘의 착장 피드)
- `userId` (String): 작성자 UID
- `imageUrl` (String): OOTD 사진 URL
- `description` (String): 코멘트
- `taggedClothes` (List<Map<String, dynamic>>): 착장에 사용된 옷장 아이템들의 비정규화된 정보. `[{id: "docId", imageUrl: "url", title: "크림 카디건"}, ...]` 형태로 피드 로딩 성능 최적화.
- `createdAt` (Timestamp): 생성 시간

## 5. 서비스 레이어 (`lib/services/firebase_service.dart`)
모든 백엔드 통신은 싱글톤 패턴으로 구현합니다.
- **인증(Auth)**: `http` 패키지로 REST API 호출. `SharedPreferences`를 사용한 세션 유지.
- **clothes 연동**: `saveClothingData`, `getClothesStream`(userId 기준 필터링 및 createdAt 내림차순 정렬), `updateClothingData`, `deleteClothingData`. 
- **ootds 연동**: `saveOOTDData`, `getOOTDStream`(userId 기준 필터링만 수행. 복합 인덱스 에러 방지를 위해 orderBy는 생략하고 UI에서 로컬 정렬 처리), `deleteOOTDData`.
- **이미지 업로드**: `uploadImage` 함수로 Storage에 이미지 저장 후 다운로드 URL 반환.

## 6. 화면별 상세 구현 요구사항

### 6.1. 앱 진입 및 로그인 (`main.dart` & `login_screen.dart`)
- `AuthWrapper`를 통해 로그인 상태를 확인하고, `LoginScreen` 또는 `MainScreen`으로 분기합니다.
- `LoginScreen`은 미니멀한 화이트 테마의 이메일/비밀번호 폼으로 구성되며, 직접 작성한 Auth REST API를 호출합니다.

### 6.2. 하단 네비게이션 메인 화면 (`lib/screens/main_screen.dart`)
앱 전체를 감싸는 4탭 구조의 `BottomNavigationBar`입니다.
1. **[옷장] (`Icons.grid_view_rounded`)**: `HomeScreen` 렌더링
2. **[OOTD] (`Icons.crop_portrait_outlined`)**: `OotdScreen` 렌더링. 전신거울을 연상시키는 사각형 라인 아이콘 사용.
3. **[+ 추가] (`Icons.add`)**: 원형 테두리 포인트가 들어간 아이콘. 탭 이동이 아닌 **Bottom Sheet** 메뉴 팝업 역할.
   - 메뉴 1: "옷장에 새 아이템 추가" (`UploadScreen` 호출)
   - 메뉴 2: "오늘의 OOTD 기록하기" (`UploadOotdScreen` 호출)
4. **[프로필] (`Icons.person_outline`)**: `ProfileScreen` 렌더링

### 6.3. 내 옷장 (홈) 화면 (`lib/screens/home_screen.dart`)
- 인스타그램 스토리와 피드 형식을 차용한 의류 관리 화면.
- **상단 카테고리 필터**: 동그란 아바타 영역에 **대표 커스텀 라인 아트 아이콘**이 표시되는 가로 스크롤 위젯. 총 10개의 대분류 나열.
- **상단 AppBar 액션**: 우측 상단 돋보기(`Icons.search`) 버튼 클릭 시 `SearchClothesScreen`으로 이동.
- **카운트 표시**: 선택된 카테고리명과 함께 아이템 개수(`N items`) 동적 노출.
- **피드 영역**: 3열 그리드(`SliverGrid`).

### 6.4. 옷장 검색 화면 (`lib/screens/search_clothes_screen.dart`) [v3.2 추가]
- **Client-side Filtering 방식 적용**: Firestore의 한계를 극복하기 위해 사용자 옷 데이터를 한 번 불러온 뒤 메모리 상에서 실시간 조합 필터링 수행.
- **상단 검색바 (자유 텍스트)**: 브랜드, 패턴, 태그, 카테고리 등 옷의 모든 메타데이터와 부분 일치하는 텍스트 검색 지원.
- **다중 조건 필터링 (Filter Chips)**:
  - 대분류 선택 칩 (상의, 하의 등)
  - 소분류 선택 칩 (대분류 선택 시 하위에 동적으로 노출)
  - 주요 색상 선택 칩
- 위 조건들이 **AND 교집합**으로 묶여 즉각적으로 하단 3열 그리드에 결과가 렌더링됨.

### 6.5. OOTD 피드 화면 (`lib/screens/ootd_screen.dart`)
- 내가 작성한 착장샷들을 세로로 스크롤하며 보는 인스타그램 스타일 피드 화면.
- `StreamBuilder`로 OOTD 데이터를 불러온 뒤, Dart 코드로 `createdAt` 기준 로컬 내림차순 정렬.
- **게시물 구조**: 헤더, 사진, 코멘트, 태그된 옷 리스트 노출.

### 6.6. 옷장 업로드 및 정보 관리 화면 (`upload_screen.dart` / `clothing_detail_screen.dart`)
- **2-Depth 카테고리 선택**: `ChoiceChip`을 이용해 대분류 선택 시 해당 소분류들(커스텀 아이콘 포함)이 펼쳐짐.
- **상세 정보 수정**: 카테고리 변경 시 대분류/소분류 드롭다운이 연동되어 작동.

### 6.7. 프로필 화면 (`lib/screens/profile_screen.dart`)
- 현재 로그인한 이메일 계정을 표시하고 로그아웃 기능 지원.

## 7. 주요 구현 규칙 (바이브코딩 지침)
- 모든 파일과 위젯은 **한국어**로 텍스트를 구성해야 합니다.
- 폰트 아이콘(Web)의 경우, 누락 방지를 위해 `--no-tree-shake-icons` 플래그로 빌드합니다.
- Firebase 쿼리문 작성 시 복합 인덱스(Composite Index)가 필요한 경우, 무리하게 `.orderBy()`를 쓰지 말고 Dart단에서 데이터를 받아온 후 `.sort()`로 처리하여 사용자가 콘솔 설정을 건드리는 일을 방지합니다.

## 8. 배포 방식 (Firebase Hosting)
현재 프로젝트 최상단 디렉토리에는 시스템 환경에 무관하게 돌아가는 자체 `firebase_bin` 바이너리가 있습니다.
빌드 및 배포는 오직 다음 명령어를 연속 실행하여 진행합니다:
```bash
fvm flutter build web --no-tree-shake-icons && ./firebase_bin deploy --only hosting
```
