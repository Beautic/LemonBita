# Antigravity 수정 로그

사용자 요청 및 Claude의 피드백을 반영하여 수정된 내용을 기록합니다.

---

## 2026-04-08

### 1. `web/index.html` — Firebase HTML 기반 강제 초기화
**문제**: 플러터 웹 초기화 시 `firebase_auth/channel-error`가 지속적으로 발생함.
**수정 내용**: 
- 플러터 엔진이 로드되기 전, `<head>` 태그 내에서 JS SDK를 사용하여 Firebase를 먼저 초기화하도록 스크립트 추가.
- 사용자로부터 전달받은 최신 `firebaseConfig`를 직접 주입.
**이유**: 브라우저 환경에서 플러터 엔진보다 Firebase 엔진을 먼저 준비시켜 통신 채널 오류를 방지함.

### 2. `lib/services/firebase_service.dart` — 웹 초기화 방어 로직
**문제**: HTML에서 이미 초기화된 경우 플러터에서 다시 초기화하면 중복 오류가 발생할 수 있음.
**수정 내용**: 
- `Firebase.apps.isEmpty`를 체크하여 초기화가 필요한 경우에만 실행하도록 보강.
**이유**: 중복 초기화 방지 및 안정성 확보.

## 2026-05-05 (v3.2)

### 1. 사진 잘림 현상 수정 (UI 개선)
**문제**: MY CLOSET을 제외한 다른 페이지(옷 상세, OOTD, 업로드 화면)에서 옷이나 코디 사진이 비율에 맞춰 잘려서(Cropped) 보이는 현상 발생.
**수정 내용**: 
- `lib/screens/clothing_detail_screen.dart`
- `lib/screens/ootd_screen.dart`
- `lib/screens/upload_screen.dart`
- `lib/screens/upload_ootd_screen.dart`
- 위 4개 파일에서 이미지를 표시하는 `BoxFit.cover` 속성을 모두 `BoxFit.contain`으로 변경하여 원본 사진의 비율을 유지하도록 수정.
- `clothing_detail_screen.dart`의 이미지 컨테이너 높이를 400으로 키우고 빈 공간이 어색하지 않게 배경색(`Colors.grey[100]`) 추가.
**이유**: 세로로 긴 옷 사진이 잘림 없이 온전히 보이도록 하기 위함.

## 2026-05-23 (v3.3)

### 1. 옷 상세 페이지 내 이미지 수정 기능 추가
**문제**: 이미 등록된 옷의 이미지를 수정할 수 없는 문제.
**수정 내용**:
- `lib/screens/clothing_detail_screen.dart`
- 옷장 상세 페이지 내에 이미지 수정 버튼(연필 아이콘 플로팅 버튼) 추가.
- `image_picker`를 활용하여 카메라 촬영 및 앨범 선택 기능 연동.
- 변경된 사진에 대해서도 누끼 제거/복원 로직이 정상적으로 동작하도록 로직 개선 (단, 최종 변경 사항은 '정보 저장하기' 버튼을 눌러야 클라우드에 반영됨).
**이유**: 사용자 피드백(옷장 상세 페이지에서 이미지 변경 불가)을 반영하여 옷장 관리의 편의성 향상.

## 2026-05-23 (v3.4)

### 1. 가상 코디 캔버스 (코디 아이디어) 기능 추가
**수정 내용**:
- `lib/screens/coordination_canvas_screen.dart` 신규 생성. 옷장 내 이미지들을 불러와 드래그, 회전, 크기 조절 등을 통해 자유롭게 배치하는 캔버스 구현.
- `lib/screens/ootd_screen.dart` 상단에 TabBar (`내 OOTD`, `코디 아이디어`)를 추가하여, 저장한 예비 코디를 모아볼 수 있도록 개선.
- `lib/screens/upload_ootd_screen.dart`와 연동하여 예비 코디를 실제 OOTD로 즉시 업로드할 수 있게 반영.
**이유**: 사용자 피드백을 반영하여 업로드 전 코디를 미리 맞춰보고 아이디어 리스트로 저장해둘 수 있는 기능 제공.
