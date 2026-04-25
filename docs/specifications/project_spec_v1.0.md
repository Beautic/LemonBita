# 디지털 옷장 (My Digital Closet) 작업지시서

이 문서는 AI 어시스턴트(바이브코딩)가 이 문서만을 보고 현재와 완벽하게 동일한 '나만의 디지털 옷장' Flutter 애플리케이션을 구현할 수 있도록 작성된 상세 작업지시서입니다.

## 1. 프로젝트 개요
- **앱 이름**: My Digital Closet (나만의 디지털 옷장)
- **목적**: 사용자가 자신의 옷 사진을 찍어 카테고리별로 분류하고 관리할 수 있는 디지털 옷장 애플리케이션
- **플랫폼**: Flutter (Web, iOS, Android 지원 구조, 웹(Web) 최적화 설정 포함)
- **주요 기능**: 이메일 회원가입/로그인, 옷 사진 촬영/갤러리 업로드, 카테고리별 분류, 상세 정보(브랜드, 사이즈, 메모 등) 수정 및 삭제

## 2. 기술 스택 및 패키지
- **프레임워크**: Flutter
- **상태 관리**: 기본 `setState` 및 `StreamBuilder` 사용
- **백엔드**: Firebase (Firestore, Storage) 및 Firebase Auth REST API 연동
- **주요 의존성 (pubspec.yaml 필요 패키지)**:
  - `firebase_core`: Firebase 앱 초기화
  - `cloud_firestore`: 데이터베이스 (CRUD 로직 처리)
  - `firebase_storage`: 옷 이미지 파일 업로드
  - `http`: Firebase Auth REST API 호출용 (Identity Toolkit)
  - `shared_preferences`: 로그인 세션(UID, 토큰 등) 기기 로컬 저장용
  - `image_picker`: 카메라 촬영 및 기기 갤러리 이미지 선택용

## 3. 디자인 시스템 및 테마 설정 (`main.dart`)
- **테마 밝기 (Brightness)**: Dark (`Brightness.dark`)
- **전체 배경색 (Scaffold)**: `#101014` (Hex: `0xFF101014`)
- **주조색 (Primary Color)**: `#8B5CF6` (Hex: `0xFF8B5CF6`) - 보라색 계열
- **보조색 (Secondary Color)**: `#10B981` (Hex: `0xFF10B981`) - 에메랄드/그린 계열
- **표면색 (Surface Color)**: `#1F1F28` (Hex: `0xFF1F1F28`) - 카드 및 입력 폼 배경
- **AppBar Theme**: 배경 투명 (`Colors.transparent`), 그림자 제거 (Elevation 0), 타이틀 중앙 정렬
- **글꼴 (Font Family)**: Roboto

## 4. 데이터베이스 구조 (Firebase)
### Firestore 컬렉션: `clothes`
사용자가 등록한 옷 데이터는 모두 이 컬렉션에 문서 형태로 저장됩니다.
- `userId` (String): 문서를 생성한 사용자의 UID (Firebase Auth localId)
- `imageUrl` (String): Firebase Storage에 업로드된 후 반환받은 다운로드 URL
- `category` (String): 옷의 카테고리 (상의, 하의, 아우터, 신발, 액세서리, 기타)
- `tags` (String): 해시태그 형식의 짧은 설명 (예: #상의, #데일리)
- `brand` (String, Optional): 사용자가 기입한 브랜드명
- `size` (String, Optional): 사용자가 기입한 사이즈 (L, 100, 270 등)
- `memo` (String, Optional): 옷에 대한 개인적인 메모 내용
- `createdAt` (Timestamp): 문서 최초 생성 시간 (`FieldValue.serverTimestamp()`)

### Firebase Storage
- **업로드 경로**: `clothes/` 디렉토리 하위에 저장
- **파일명 명명 규칙**: `[현재시간(millisecondsSinceEpoch)].[확장자]` (예: `1691234567890.jpg`)

## 5. 서비스 레이어 (`lib/services/firebase_service.dart`)
모든 Firebase API 통신 및 인증 관련 로직은 이 싱글톤/서비스 클래스로 분리하여 관리합니다.
- **인증(Auth) 로직**: `firebase_auth` 패키지를 쓰지 않고 `http` 패키지로 Firebase Identity Toolkit REST API(`accounts:signUp`, `accounts:signInWithPassword`)를 직접 호출하여 구현합니다.
  - 로그인/회원가입 완료 시 `uid`, `email`, `idToken`, `refreshToken`을 담은 `AuthUser` 모델 객체를 생성.
  - `SharedPreferences`를 사용해 로그인 세션을 디스크에 저장(persist)하고, 앱 시작 시 복원(restore)합니다.
  - 상태 변경(로그인/로그아웃)을 UI에 알리기 위해 `StreamController<AuthUser?>.broadcast()`를 사용.
- **초기화**: `kIsWeb` 상수를 확인하여 웹 환경일 경우 프로젝트의 하드코딩된 `FirebaseOptions` 값으로 초기화, 그 외 플랫폼은 기본값으로 초기화합니다.
- **데이터 CRUD 메서드**:
  - `saveClothingData()`: Firestore에 새로운 옷 문서 추가.
  - `getClothesStream()`: 현재 로그인한 사용자의 UID(`userId`)와 일치하는 문서만 `createdAt` 필드 기준 내림차순으로 가져오는 `Stream`을 반환.
  - `updateClothingData()`: 특정 문서 ID(`docId`)의 데이터(브랜드, 사이즈, 메모 등) 업데이트.
  - `deleteClothingData()`: 특정 문서 ID로 삭제 요청.
  - `uploadImage()`: `Uint8List` 형식의 이미지를 Storage에 업로드하고 다운로드 URL을 반환.

## 6. 화면별 상세 구현 요구사항

### 6.1. 앱 진입점 및 라우팅 (`lib/main.dart`)
- `main()` 함수에서 `WidgetsFlutterBinding.ensureInitialized()` 호출 후 `FirebaseService.initialize()`를 비동기로 대기(await)합니다.
- 초기화 중 치명적 오류 발생 시 `Scaffold` 중앙에 `SelectableText`로 에러 메시지를 띄우는 예외 처리를 구성합니다.
- `AuthWrapper` 위젯을 최상단 뷰로 사용하여 `FirebaseService().authStateChanges` 스트림의 상태를 관찰(`StreamBuilder`)합니다. 데이터가 존재하면 `HomeScreen`, 없으면 `LoginScreen`으로 즉시 라우팅합니다.

### 6.2. 로그인 화면 (`lib/screens/login_screen.dart`)
- **상태 변수**: 이메일 및 비밀번호 `TextEditingController`, 로딩 상태(`_isLoading`), 로그인/회원가입 모드 상태(`_isLoginMode`).
- **UI 구성**:
  - 화면 정중앙에 큰 아이콘(`Icons.inventory_2_rounded`, 크기 80, Primary Color).
  - 헤드라인 텍스트: "나만의 디지털 옷장" (크기 28, Bold). 서브 텍스트: "어디서든 내 옷을 관리하세요".
  - 이메일 입력 필드: Prefix 아이콘 `email_outlined`.
  - 비밀번호 입력 필드: Prefix 아이콘 `lock_outline`, 마스킹 처리(`obscureText: true`).
  - 입력 필드 데코레이션: 곡률이 12인 `OutlineInputBorder`.
  - 액션 버튼: `FilledButton` 스타일 적용, 터치 시 `_submit` 메서드 실행. 모드에 따라 텍스트가 '로그인' 또는 '회원가입'으로 변경.
  - 모드 전환 버튼: 하단 `TextButton` 터치 시 `_isLoginMode` 값을 토글.
- **동작**: 필드 빈값 검사 후 `FirebaseService`의 회원가입 또는 로그인 API 호출. 예외 발생 시 `SnackBar`로 오류 메시지를 띄우고, 성공하면 스트림 변경을 통해 자동으로 홈 화면으로 넘어갑니다.

### 6.3. 홈 화면 (`lib/screens/home_screen.dart`)
- **구조**: `_selectedCategory` 상태값에 따라 대시보드 모드(null)와 특정 카테고리의 옷장 뷰(not null)로 나뉩니다.
- **AppBar**: 타이틀(카테고리가 선택되었으면 카테고리명, 아니면 '나만의 디지털 옷장'), 뒤로가기 버튼(카테고리 선택 시에만 표시), 로그아웃(`logout_rounded`) 아이콘 버튼 배치.
- **FAB (Floating Action Button)**: "옷 추가하기" 버튼 (`FloatingActionButton.extended` 사용, 하단 중앙(`centerFloat`) 위치, 아이콘: 카메라, 클릭 시 `UploadScreen`으로 라우팅).
- **1) 대시보드 모드 (`_selectedCategory == null`)**:
  - 상단 텍스트: "무엇을 입으시겠어요?", "총 N개의 아이템이 보관되어 있습니다." (전체 옷 개수 반영).
  - 2열 그리드 뷰(`GridView.builder`): 아우터, 상의, 하의, 신발, 액세서리, 기타 총 6개의 카테고리 카드 표시.
  - 카테고리 카드 UI: 아이콘, 고유 색상, 카테고리명, 해당 카테고리에 속한 옷 개수(`count`). 외곽선과 둥근 모서리(`Radius 28`), 옅은 그라데이션 배경 적용. 카드를 누르면 `_selectedCategory` 상태가 업데이트됩니다.
- **2) 특정 카테고리 옷장 모드 (`_selectedCategory != null`)**:
  - 해당 카테고리(`category` 필드) 문자열과 일치하는 옷 데이터만 리스트에서 필터링하여 노출.
  - 상단 내비게이션 바 영역: 좌측에 큰 글씨로 현재 카테고리명 표시, 우측에 '전체 옷장'으로 돌아가는 `TextButton` 배치.
  - 데이터가 없을 경우: 중앙에 `inventory_2_outlined` 아이콘과 "등록된 옷이 없습니다" 메시지 표시.
  - 옷 리스트 (2열 그리드):
    - 모서리가 둥근 컨테이너, 그림자 효과.
    - 꽉 차게 렌더링된 사진 (`Image.network`, `BoxFit.cover`).
    - 부드러운 화면 전환을 위해 `Hero` 위젯을 사용하고 `tag`로 Firestore 문서 ID를 지정.
    - 하단 그라데이션 오버레이 위로 해시태그(`tags` 필드) 문자열 표시 (`Positioned` 활용).
    - 아이템 터치 시 `ClothingDetailScreen`으로 문서 ID와 데이터를 넘기며 이동.

### 6.4. 업로드 화면 (`lib/screens/upload_screen.dart`)
- **기능**: 카메라/앨범 연동 및 신규 데이터 업로드.
- **UI 구성 요소**:
  - 상단 뷰: 높이 380의 메인 이미지 컨테이너. 이미지가 없을 때는 중앙에 둥근 아이콘 컨테이너와 "터치해서 사진 찍기" 텍스트. 탭 시 `ImagePicker`의 `ImageSource.camera` 동작.
  - 갤러리 버튼: 우측 정렬된 "앨범에서 가져오기" `TextButton`.
  - 카테고리 선택 뷰: 6개 카테고리를 `ChoiceChip` 위젯과 `Wrap` 위젯 조합으로 나열 (기본 선택값: '상의').
  - 저장 버튼: `FilledButton`, "옷장에 넣기" 라벨.
- **동작**:
  - 카메라 및 갤러리 호출 시 `maxHeight/maxWidth: 1080`, `imageQuality: 70`으로 제한하여 최적화.
  - 저장 시 `XFile` 객체를 `readAsBytes()`로 변환하여 Firebase Storage에 업로드 (이미지 URL 획득).
  - 획득한 URL과 선택된 카테고리 등을 Firestore에 `saveClothingData` 메서드로 저장.
  - 로딩 중에는 버튼 대신 `CircularProgressIndicator` 노출. 처리가 끝나면 화면을 닫습니다.

### 6.5. 상세 및 수정 화면 (`lib/screens/clothing_detail_screen.dart`)
- **기능**: 등록된 옷을 크게 보고 정보 수정 및 삭제 처리.
- **UI 구성 요소**:
  - AppBar: "옷 정보 정리" 타이틀 표기, 우측 `actions`에 삭제용 빨간색 휴지통 아이콘 버튼 배치.
  - 메인 이미지: 상단 높이 300 영역, 홈 화면과 연결되는 `Hero` 위젯(`tag`: 문서 ID). 이미지 둥근 모서리와 깊은 하단 그림자(`BoxShadow`) 적용.
  - 정보 폼 영역 (스크롤 가능):
    - 카테고리 선택: `DropdownButtonFormField` 사용.
    - 기본 텍스트 필드(`TextField`): 브랜드, 사이즈, 태그 용도 3개.
    - 메모 필드: `maxLines: 5`의 다중 라인 `TextField`.
    - 모든 입력폼 디자인: 라벨 표기, 옅은 흰색 배경(`Colors.white.withOpacity(0.05)`), `BorderSide.none`의 모서리가 둥근 컨테이너 테마 통일.
  - 메인 액션 버튼: 최하단 "정보 저장하기" 버튼.
- **동작**:
  - 화면 진입 즉시 이전 화면에서 전달받은 `Map<String, dynamic> item` 데이터로 모든 `TextEditingController`의 초기 텍스트 세팅.
  - '정보 저장하기' 클릭 시 `updateClothingData` API에 변경된 값들을 Map 형태로 전달. 스낵바 알림 후 뒤로 가기.
  - 휴지통 아이콘 클릭 시 `AlertDialog` 팝업을 띄워 진짜 삭제할지 2차 확인 후, 수락 시 `deleteClothingData` 호출 및 화면 닫기.

## 7. 구현 시 주요 요구사항 (바이브코딩 지침)
- 애플리케이션 내의 모든 사용자 노출 텍스트, 주석, 에러 문구는 **한국어**로 작성해야 합니다.
- 색상 코드(Primary, Background 등) 및 UI 요소의 모서리 곡률(Radius) 등은 본 문서에 명시된 테마와 디자인 시스템 수치를 한 치의 오차 없이 똑같이 따라야 합니다.
- **주의점**: Firebase 인증은 일반적으로 사용하는 `firebase_auth` 패키지 대신 `http` 패키지를 사용한 REST API (Identity Toolkit) 방식으로 구현되어 있습니다. 이 점을 혼동하지 말고 제공된 명세(5. 서비스 레이어)대로 정확히 구현해야 합니다.
- UI 구성 시 파일별/위젯별 분리와 모듈화를 신경 쓰고, 필요 이상의 전체 화면 리빌드(rebuild)가 발생하지 않도록 상태 관리에 유의하여 코드를 작성하세요.

## 8. 배포 방식 (Firebase Hosting)
현재 앱의 배포는 사용자의 로컬 환경에 별도로 Firebase CLI를 설치하는 번거로움을 피하기 위해 다음과 같은 맞춤형 방식으로 진행됩니다.

1. **자동 도구 준비**: 프로젝트 폴더에 `firebase_bin`이라는 이름으로 Firebase 공식 실행 파일이 직접 포함되어 있습니다. (따로 설치할 필요가 없습니다.)
2. **배포 명령어**: 빌드가 완료될 때마다 터미널에서 다음 명령어를 실행하여 구글 클라우드 서버로 파일을 전송합니다.
   ```bash
   ./firebase_bin deploy --only hosting
   ```
이 방식은 Firebase 공식 배포 방식 중 가장 정확하고 안정적입니다.
