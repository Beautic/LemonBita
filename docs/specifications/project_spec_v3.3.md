# 디지털 옷장 (My Digital Closet) 작업지시서 v3.3

이 문서는 AI 어시스턴트가 이 문서만을 보고 현재와 완벽하게 동일한 '나만의 디지털 옷장' Flutter 애플리케이션을 구현할 수 있도록 작성된 상세 작업지시서입니다. (v3.3: Hugging Face 기반 자체 무료 누끼따기(배경 제거) 서버 구축 및 앱 연동 명세 추가)

## 1. 프로젝트 개요
- **앱 이름**: My Digital Closet (나만의 디지털 옷장)
- **목적**: 사용자가 자신의 옷 사진을 찍어 카테고리별로 관리하고, 옷장 아이템을 태깅하여 매일의 데일리룩(OOTD)을 기록하는 애플리케이션
- **플랫폼**: Flutter (Web, iOS, Android 지원 구조, 웹(Web) 최적화 설정 포함)
- **주요 기능**: 이메일 로그인, 옷 사진 갤러리 업로드, 대분류/소분류 체계적 필터링, 커스텀 아이콘 지원, 상세 정보 관리, 하단 4탭 네비게이션, 옷장 연동 OOTD 피드 작성 및 태깅, 옷장 다중 조건 검색, **AI 기반 자동 배경 제거(누끼따기)**

## 2. 기술 스택 및 패키지
- **프레임워크**: Flutter
- **상태 관리**: 기본 `setState` 및 `StreamBuilder` 사용
- **앱 백엔드**: Firebase (Firestore, Storage) 및 Firebase Auth REST API 연동
- **AI 백엔드 (누끼 전용)**: Python (FastAPI, `rembg`), Hugging Face Spaces 무료 호스팅
- **주요 의존성 (pubspec.yaml)**:
  - `firebase_core`, `cloud_firestore`, `firebase_storage`
  - `http` (Auth REST API 및 AI 서버 호출용)
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

## 4. 데이터베이스 구조 (Firebase)

### Firestore 컬렉션: `clothes` (내 옷장)
- `userId` (String): 문서를 생성한 사용자의 UID
- `imageUrl` (String): Storage에 업로드된 사진 URL (누끼 처리된 투명 PNG 권장)
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

## 5. 서비스 레이어 (`lib/services/`)
모든 통신은 전담 서비스 클래스 패턴으로 구현합니다.
- **`firebase_service.dart`**: 인증(REST API), Firestore CRUD, Storage 이미지 업로드(`png` 확장자 우선 저장 로직 포함)
- **`bg_remove_service.dart` [v3.3 추가 예정]**: Hugging Face에 배포된 파이썬 API 서버와 통신하여, 원본 이미지를 전송(`multipart/form-data`)하고 배경이 제거된 투명 PNG 바이트를 반환받음.

## 6. AI 누끼따기 서버 아키텍처 (Python) [v3.3 추가]
- **환경**: Hugging Face Spaces (CPU Basic - Free Tier)
- **구조**: `FastAPI` 기반 웹 서버 구축
- **핵심 라이브러리**: `rembg` (내부적으로 U^2-Net 등의 ONNX 모델 사용)
- **엔드포인트**: `POST /remove-bg`
- **동작**: 클라이언트가 전송한 이미지를 받아 `rembg.remove()` 함수를 통과시킨 후, 배경이 제거된 이미지를 클라이언트에게 반환함. 외부 API 키 없이 자체적으로 모델을 서빙하여 비용을 0원으로 유지함.

## 7. 화면별 상세 구현 요구사항

### 7.1. 옷장 업로드 및 정보 관리 화면 (`upload_screen.dart` / `clothing_detail_screen.dart`)
- **[v3.3 추가] 자동 누끼따기 기능**: 
  - 사진 선택 직후 미리보기 영역 하단에 **"✨ 배경 지우기(AI)"** 버튼 노출.
  - 버튼 클릭 시 로딩 스피너 표시 후, `BgRemoveService`를 호출하여 이미지를 파이썬 서버로 전송.
  - 투명한 배경이 적용된 깔끔한 이미지로 미리보기 자동 갱신.
  - 해당 투명 이미지가 Firebase Storage에 그대로 보존되도록 업로드.
- **2-Depth 카테고리 선택**: `ChoiceChip`을 이용해 대분류 선택 시 해당 소분류들(커스텀 아이콘 포함)이 펼쳐짐.
- **상세 정보 수정**: 카테고리 변경 시 대분류/소분류 드롭다운이 연동되어 작동.

### 7.2. 내 옷장 (홈) 화면 (`lib/screens/home_screen.dart`)
- 인스타그램 스토리 형식의 상단 카테고리 필터.
- **상단 AppBar 액션**: 우측 상단 돋보기(`Icons.search`) 버튼 클릭 시 `SearchClothesScreen`으로 이동.
- **피드 영역**: 3열 그리드(`SliverGrid`). 배경이 제거된 투명 PNG 옷 이미지가 깔끔하게 나타남.

### 7.3. 옷장 검색 화면 (`lib/screens/search_clothes_screen.dart`)
- **Client-side Filtering 방식 적용**: Firestore의 한계를 극복하기 위해 사용자 옷 데이터를 한 번 불러온 뒤 메모리 상에서 실시간 조합 필터링 수행.
- **상단 검색바 (자유 텍스트)**: 브랜드, 패턴, 태그, 카테고리 등 옷의 모든 메타데이터와 부분 일치하는 텍스트 검색 지원.
- **다중 조건 필터링 (Filter Chips)**: 대분류, 소분류, 주요 색상을 칩 형태로 다중 선택(AND 교집합) 가능.

### 7.4. 하단 네비게이션 메인 화면 (`lib/screens/main_screen.dart`)
- 4탭 구조의 `BottomNavigationBar` (옷장, OOTD, +추가 팝업, 프로필).

### 7.5. OOTD 피드 화면 (`lib/screens/ootd_screen.dart`)
- `createdAt` 기준 로컬 내림차순 정렬된 인스타그램 스타일 착장 피드.

## 8. 주요 구현 규칙 (바이브코딩 지침)
- 모든 파일과 위젯은 **한국어**로 텍스트를 구성해야 합니다.
- 폰트 아이콘(Web)의 경우, 누락 방지를 위해 `--no-tree-shake-icons` 플래그로 빌드합니다.
- Firebase 쿼리문 작성 시 복합 인덱스(Composite Index)가 필요한 경우, 무리하게 `.orderBy()`를 쓰지 말고 Dart단에서 데이터를 받아온 후 `.sort()`로 처리하여 사용자가 콘솔 설정을 건드리는 일을 방지합니다.

## 9. 배포 방식 (Firebase Hosting)
현재 프로젝트 최상단 디렉토리에는 시스템 환경에 무관하게 돌아가는 자체 `firebase_bin` 바이너리가 있습니다.
빌드 및 배포는 오직 다음 명령어를 연속 실행하여 진행합니다:
```bash
fvm flutter build web --no-tree-shake-icons && ./firebase_bin deploy --only hosting
```
