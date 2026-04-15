# [프로젝트] 플러터 기반 인터넷 옷장 (Flutter Digital Closet)

핸드폰으로 촬영한 옷 사진을 Firebase에 저장하고 언제 어디서든 확인할 수 있는 앱스토어 및 웹 호환 디지털 옷장 서비스입니다. 이전의 프론트엔드 웹 전용 구상을 발전시켜, 보다 네이티브한 카메라 경험과 장기적인 앱스토어 출시를 목표로 구글의 **Flutter** 프레임워크로 기술 스택을 전환했습니다.

## 📂 개발 규칙 및 비용 관리 (New)
> [!CAUTION]
> **비용 발생 제로 정책**: 모든 테스트는 Firebase 무료 사용량 범위 내에서 수행합니다. 에이전트는 불필요한 실시간 연동 테스트를 지양하고, 코드 무결성 검증 위주로 작업하며 실시간 데이터 전송은 최소한으로 유지합니다. 상세 규칙은 이 폴더의 `.cursorrules` 파일을 따릅니다.

## 핵심 기능
- **사진 촬영 및 갤러리 업로드**: 기기의 기본 카메라를 이용해 옷 사진을 즉시 촬영하고 업로드
- **카테고리 분류**: 상의, 하의, 아우터, 신발 등 카테고리별 데이터 관리
- **클라우드 저장소**: Firebase Storage(이미지) 및 Firestore(데이터 속성) 실시간 동기화
- **디지털 갤러리 뷰**: 저장된 옷들을 플랫폼 구분 없이(Web/iOS/Android) 일관되게 볼 수 있는 반응형 그리드 UI

---

## 최신 환경 구성 (macOS 13 지원 모드)
현재 시스템(macOS 13.7)과 최신 Flutter SDK 간의 호환성 문제를 해결하기 위해, `FVM(Flutter Version Management)`을 도입하여 안정화된 개발 환경을 구축했습니다.

- **Flutter 버전**: `3.16.9` (macOS 13에서 가장 안정적으로 구동되는 버전 사용)
- **앱 기본 플랫폼**: iOS, Android, Web 동시 지원
- **주요 패키지**: `firebase_core`, `cloud_firestore`, `firebase_storage`, `image_picker`

---

## 🏗️ 향후 구현 계획 목록

### 1단계: Firebase 구성 (진행 필요 단계)
FlutterFire CLI를 통해 로컬 프로젝트와 클라우드 데이터베이스를 결합합니다.
- 사용자의 Google Firebase Console을 통한 새 프로젝트 생성 필요
- Firestore 데이터베이스 및 Storage 버킷 생성 및 권한 설정
- 프로젝트 내 Firebase 초기화 코드 작성 (`firebase_options.dart` 생성)

### 2단계: 핵심 화면(UI) 구성
`lib/` 디렉토리를 기반으로 다음의 UI 컴포넌트를 설계합니다.
- **`lib/screens/home_screen.dart`**: 내 옷을 모아보는 메인 그리드 뷰 화면
- **`lib/screens/upload_screen.dart`**: 사진 촬영, 이미지 크롭 및 카테고리 태깅 화면

### 3단계: 상태 관리 및 비즈니스 로직 연동
로컬 파일 스토리지 모듈과 클라우드 백엔드를 연동합니다.
- **`lib/services/firebase_service.dart`**: Firestore 데이터 작성 및 읽기 서비스 분리 구현
- **`lib/services/image_service.dart`**: `image_picker`를 활용한 기기 카메라 접근 권한 관리

### 4단계: 디자인 고도화
- 모바일(터치) 친화적이고 직관적인 하단 네비게이션 바(BottomNavigationBar) 구축
- 다크모드 및 프리미엄(Glassmorphism) 스타일 기반의 테마 커스텀 적용

---

## 🛠️ 사용자 검토 및 행동 필요
> [!IMPORTANT]
> **Firebase 프로젝트 생성 필요**
> 코드로 데이터베이스를 호출하기 위해, 사용자님께서 [Firebase Console](https://console.firebase.google.com/)에서 직접 **비어있는 새 프로젝트**를 생성해주셔야 합니다. 
> 프로젝트를 만드신 후 **Firestore Database**와 **Storage** 메뉴에 들어가서 '시작하기'를 눌러만 두시면, 나머지 연동(flutterfire CLI)은 에이전트가 자동화하여 진행합니다.

---
