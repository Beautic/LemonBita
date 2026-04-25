# 디지털 옷장 (My Digital Closet) 작업지시서 v3.0

이 문서는 AI 어시스턴트가 이 문서만을 보고 현재와 완벽하게 동일한 '나만의 디지털 옷장' Flutter 애플리케이션을 구현할 수 있도록 작성된 상세 작업지시서입니다. (v3.0: 인스타그램 스타일 UI 리뉴얼, OOTD 및 옷장 연동 태깅 기능 추가 반영)

## 1. 프로젝트 개요
- **앱 이름**: My Digital Closet (나만의 디지털 옷장)
- **목적**: 사용자가 자신의 옷 사진을 찍어 카테고리별로 관리하고, 옷장 아이템을 태깅하여 매일의 데일리룩(OOTD)을 기록하는 애플리케이션
- **플랫폼**: Flutter (Web, iOS, Android 지원 구조, 웹(Web) 최적화 설정 포함)
- **주요 기능**: 이메일 로그인, 옷 사진 갤러리 업로드, 카테고리 필터링(가로 스크롤), 상세 정보 관리, 하단 4탭 네비게이션, **옷장 연동 OOTD 피드 작성 및 태깅**

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

## 3. 디자인 시스템 및 테마 설정 (`main.dart`)
- **테마 밝기**: Light (인스타그램 스타일 화이트 미니멀리즘)
- **전체 배경색 (Scaffold)**: `#FFFFFF` (Colors.white)
- **주조색 (Primary Color)**: `#000000` (Colors.black)
- **보조색**: `#F5F5F5` (Colors.grey[100], 카드 및 컨테이너 배경)
- **AppBar Theme**: 배경 흰색(`Colors.white`), 그림자 제거(`elevation: 0`), 글자색 검정(`Colors.black`), 시스템 UI 오버레이 아이콘 다크(`SystemUiOverlayStyle.dark`)
- **글꼴**: 기본 시스템 폰트(Roboto 등) 기반, 깔끔하고 모던한 산세리프

## 4. 데이터베이스 구조 (Firebase)

### Firestore 컬렉션: `clothes` (내 옷장)
- `userId` (String): 문서를 생성한 사용자의 UID
- `imageUrl` (String): Storage에 업로드된 사진 URL
- `category` (String): 옷의 카테고리 (상의, 하의, 아우터, 신발, 액세서리, 기타)
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
2. **[OOTD] (`Icons.crop_portrait_outlined`)**: `OotdScreen` 렌더링. 아이콘 트러블 방지를 위해 전신거울을 연상시키는 사각형 라인 아이콘 사용.
3. **[+ 추가] (`Icons.add`)**: 원형 테두리 포인트가 들어간 아이콘. 탭 이동이 아닌 **Bottom Sheet** 메뉴 팝업 역할.
   - 메뉴 1: "옷장에 새 아이템 추가" (`UploadScreen` 호출)
   - 메뉴 2: "오늘의 OOTD 기록하기" (`UploadOotdScreen` 호출)
4. **[프로필] (`Icons.person_outline`)**: `ProfileScreen` 렌더링

### 6.3. 내 옷장 (홈) 화면 (`lib/screens/home_screen.dart`)
- 인스타그램 스토리와 피드 형식을 차용한 의류 관리 화면.
- **상단 카테고리 필터**: 동그란 아바타 아이콘 기반의 가로 스크롤 위젯 (인스타그램 스토리 스타일). [ALL, 아우터, 상의, 하의...] 순으로 나열.
- **카운트 표시**: 선택된 카테고리명과 함께 아이템 개수(`N items`) 동적 노출.
- **피드 영역**: 3열 그리드(`SliverGrid`).
  - 옷 이미지 하단에 2줄의 텍스트 레이블 표시.
  - 1번 줄: "색상 + 패턴" (없을 경우 브랜드나 카테고리 대체)
  - 2번 줄: "카테고리 · 핏" 조합.

### 6.4. OOTD 피드 화면 (`lib/screens/ootd_screen.dart`)
- 내가 작성한 착장샷들을 세로로 스크롤하며 보는 인스타그램 스타일 피드 화면.
- `StreamBuilder`로 OOTD 데이터를 불러온 뒤, Firestore Index 에러 우회를 위해 Dart 코드로 `createdAt` 기준 로컬 내림차순 정렬.
- **게시물 구조**:
  - 헤더: 아바타 아이콘과 작성일자(`yyyy년 MM월 dd일`).
  - 사진: 가로 꽉 찬 형태의 뷰.
  - 본문: 사용자 작성 텍스트(`description`).
  - 태그 영역: "이 OOTD에 입은 옷" 타이틀 아래, 태그된 옷들의 동그란 썸네일과 이름(title)이 가로로 스크롤되는 리스트업.

### 6.5. OOTD 업로드 화면 (`lib/screens/upload_ootd_screen.dart`)
- 사진 선택 영역, 짧은 코멘트 텍스트 필드.
- **핵심 기능 (옷장 태깅)**: `clothes` 컬렉션의 내 옷들을 1회 Fetch하여 가로 스크롤 썸네일로 나열.
  - 썸네일을 터치하면 검정 테두리와 체크(✓) 아이콘이 생기며 다중 선택 가능.
  - 업로드 시 선택된 옷들의 최소 정보(id, imageUrl, title)를 모아 OOTD 데이터와 함께 저장.

### 6.6. 프로필 화면 (`lib/screens/profile_screen.dart`)
- 현재 로그인한 이메일 계정을 표시.
- 로그아웃 버튼 배치 (`FirebaseService.logout()` 호출 시 `AuthWrapper`가 자동으로 `LoginScreen` 반환).

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
