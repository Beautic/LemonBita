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
