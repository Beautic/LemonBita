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

## 2026-05-23 (v3.5)

### 1. 마이크로 소셜 기능 (친구 및 공유) 추가
**수정 내용**:
- `lib/screens/friends_screen.dart`: 친구 검색 및 친구 맺기 시스템 추가 (최대 10명 제한).
- `lib/screens/notification_screen.dart`: 상단 앱바 종 모양 아이콘 추가, 친구 요청 및 OOTD 좋아요/댓글 알림 모아보기.
- `lib/screens/friend_closet_screen.dart`: 친구의 옷장을 구경하고 친구 옷으로 코디를 만들어주는 기능 추가.
- `lib/screens/friends_ootd_feed_screen.dart`: 친구들의 OOTD를 인스타그램처럼 세로 피드로 모아보고 좋아요/댓글을 남길 수 있도록 OotdScreen 탭 분리.
**이유**: 지인 10명 한정 폐쇄형 소셜 네트워크 트렌드를 반영한 마이크로 소셜 기획안 적용.
**추가 보완**: 프로필 변경 시 발생한 문제 해결 (미등록 계정의 `update` 에러를 `set(merge:true)`로 방어, iOS 렌더링 호환성 개선).

## 2026-05-23 (v3.6)

### 1. 소셜 기능 사용성 개선 및 대댓글 도입
**문제**: 
1) iOS Safari에서 일부 외곽선 아이콘(`notifications_none`)이 렌더링되지 않음.
2) 알림 화면에서 추천 코디 알림을 눌러도 해당 코디로 이동하지 않음.
3) 친구 피드에서 남긴 댓글/좋아요가 내 OOTD 화면에서는 보이지 않아 확인 불가.
4) 피드 밖에서 댓글 수를 확인할 수 없음.
5) 친구 피드에 달린 특정 댓글에 답글을 달 수 없음(단방향 소통 한계).
**수정 내용**:
- **아이콘 수정**: 호환성 높은 채워진 아이콘(`Icons.notifications`, `Icons.check`)으로 변경.
- **알림 라우팅 추가**: 알림 데이터에 `targetId`를 포함시키고, `PlannedOotdDetailScreen` 및 `SingleOotdScreen`을 구현하여 알림 클릭 시 해당 상세 화면으로 바로 이동.
- **댓글/좋아요 동기화**: `OotdPostWidget`을 공통화하여 '내 OOTD' 탭에서도 피드 화면과 동일하게 좋아요와 댓글 UI를 출력.
- **댓글 수 표시**: Firestore `ootds` 스키마에 `commentCount`를 추가하고, 댓글 작성/삭제 시 증감시켜 피드 메인에 표시.
- **대댓글 기능 구현**: 댓글 구조에 `parentId`를 도입하고, UI에서 들여쓰기 처리 및 [답글 달기] 모드를 추가하여 특정 댓글 하위에 대댓글 작성 기능 추가.
**이유**: 사용자 피드백(iOS 오류, 알림 이동 불편, 소통 확장 필요성)을 전폭적으로 반영하여 완성도 높은 마이크로 소셜 앱 구축.

## 2026-05-23 (v3.7)

### 1. OOTD 3열 그리드 뷰 및 코디 아이디어 소셜 기능 추가
**문제**:
1) OOTD 피드가 리스트 형태로 나열되어 과거 기록들을 한눈에 썸네일로 훑어보기 어려움 (인스타그램 프로필과 같은 형태 선호).
2) 코디 아이디어(Planned OOTD) 화면에서는 단순히 추천받은 옷만 확인할 수 있어 피드백(좋아요/댓글)을 남기기 어려움.

**수정 내용**:
- **Firebase 백엔드 함수 범용화**: 기존에 `ootds` 컬렉션에만 종속되어 있던 좋아요 및 댓글 함수(`toggleOotdLike`, `addOotdComment`)를 `toggleLike`, `addComment`로 통합하고, 파라미터로 `collectionName`을 받도록 수정하여 `planned_ootds` 컬렉션 등 모든 컬렉션에서 재사용할 수 있도록 개편 (`firebase_service.dart`).
- **소셜 위젯 범용화**: 댓글/좋아요 바 및 바텀시트에서 대상 컬렉션을 동적으로 처리할 수 있도록 속성 추가 (`ootd_interaction_bar.dart`, `ootd_post_widget.dart`).
- **내 OOTD 탭 바둑판 배열로 개편**: 기존의 `ListView.separated`로 나열되던 본인 OOTD 피드를 `GridView.builder` (3열, 1:1 비율) 썸네일 형태로 전환. 썸네일 클릭 시 상세 화면인 `MyOotdDetailScreen`으로 이동하여, 상세 내용과 날짜수정/태그수정/삭제 및 좋아요, 댓글을 확인할 수 있도록 분리 (`ootd_screen.dart`, `my_ootd_detail_screen.dart`).
- **코디 아이디어 화면 소셜 기능 연동**: 이미지 하단에 코디 추천인(`suggestedBy`) 텍스트를 노출하고, 하단에 좋아요/댓글 기능 바를 활성화하여 추천받은 코디 아이디어에도 반응할 수 있도록 개선 (`planned_ootd_detail_screen.dart`).

**이유**: 사용자 피드백을 반영하여 지난 기록들을 보기 쉽게 시각적으로 개선하고, 코디 아이디어 공간까지 마이크로 소셜 경험을 확장함.
