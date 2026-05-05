# 디지털 옷장 (My Digital Closet) 작업지시서 v4.0

이 문서는 v3.2 작업지시서를 베이스로, **소셜 디스커버리 레이어 및 커뮤니티 기능**을 전면 도입하는 확장 버전 통합 작업지시서입니다. AI 어시스턴트가 이 문서 하나만 보고 v3.2의 모든 기존 기능과 v4.0의 신규 기능을 빠짐없이 구현할 수 있도록 작성되었습니다. 신규/변경 사항은 `[NEW]` 또는 `[UPDATED]`로 표시되며, 표기가 없는 항목은 기존 v3.2 베이스 사양입니다.

---

## 1. 프로젝트 개요 및 비전

### 1.1 앱 정보
- **앱 이름**: My Digital Closet (나만의 디지털 옷장)
- **목적**: 사용자가 자신의 옷 사진을 찍어 카테고리별로 관리하고, 옷장 아이템을 태깅하여 매일의 데일리룩(OOTD)을 기록하는 애플리케이션
- **플랫폼**: Flutter (Web, iOS, Android 지원 구조, 웹(Web) 최적화 설정 포함)

### 1.2 확장 비전 (v4.0) [NEW]
**3대 기둥(Three Pillars)**:
1. **My Closet (개인 관리)**: 내 옷을 체계적으로 관리 (v3.2의 핵심 그대로)
2. **Discover (영감과 발견)**: 다른 사람들의 잘 입은 코디를 핀터레스트형 그리드로 탐색
3. **Connect (관계와 소통)**: 좋아요/댓글/팔로우 기반의 양방향 스타일링 커뮤니티

**핵심 차별화 포인트**: 옷이 속성 단위(카테고리/색상/패턴/핏 등)로 정규화되어 있다는 강점을 활용해, 다른 사람의 OOTD를 **"내 옷장으로 재현 가능한가?"** 로 분석해 주는 매칭 기능을 도입. 일반 패션 SNS는 절대 못 하는 영역.

**포지셔닝**: 핀터레스트형 발견 엔진을 베이스로, 인스타그램형 사람-관계 레이어를 얹은 하이브리드. **무게중심은 발견(Discover) 쪽**.

---

## 2. 기술 스택 및 패키지

### 2.1 기존 (v3.2)
- **프레임워크**: Flutter
- **상태 관리**: 기본 `setState` 및 `StreamBuilder`
- **백엔드**: Firebase (Firestore, Storage) 및 Firebase Auth REST API 연동
- **주요 의존성 (pubspec.yaml)**:
  - `firebase_core`, `cloud_firestore`, `firebase_storage`
  - `http` (Auth REST API 호출용)
  - `shared_preferences` (세션 로컬 저장)
  - `image_picker` (이미지 선택)
  - `intl` (날짜 포맷팅)

### 2.2 신규 추가 [NEW]
- **Cloud Functions for Firebase**: 카운터 denormalization, 알림 트리거, 베스트 드레서 주기 산정
- **Firebase Cloud Messaging (FCM)**: 좋아요/댓글/팔로우 푸시 알림
- 추가 패키지:
  - `firebase_messaging` (푸시 알림)
  - `flutter_staggered_grid_view` (Discover 탭의 masonry 그리드)
  - `cached_network_image` (피드 이미지 캐싱 — 성능 필수)
  - `share_plus` (외부 소셜 공유 기능)

---

## 3. 디자인 시스템 및 에셋 설정

### 3.1 테마 색상 (v3.2 유지)
- **테마 밝기**: Light (인스타그램 스타일 화이트 미니멀리즘)
- **전체 배경색 (Scaffold)**: `#FFFFFF` (Colors.white)
- **주조색 (Primary Color)**: `#000000` (Colors.black)
- **보조색**: `#F5F5F5` (Colors.grey[100], 카드 및 컨테이너 배경)
- **AppBar Theme**: 배경 흰색(`Colors.white`), 그림자 제거(`elevation: 0`), 글자색 검정(`Colors.black`), 시스템 UI 오버레이 아이콘 다크(`SystemUiOverlayStyle.dark`)
- **글꼴**: 기본 시스템 폰트(Roboto 등) 기반, 깔끔하고 모던한 산세리프

### 3.2 커스텀 에셋
- `assets/icons/` 경로에 60개 이상의 옷 종류별 라인 아트(Line-art) 아이콘 이미지들(PNG)이 NFD/NFC 정규화 처리를 거쳐 저장되어 있음.
- `lib/utils/categories.dart` 내의 `CategoryData` 클래스에서 파일명을 매핑하여 UI 곳곳(업로드, 홈 상단 필터, 상세뷰 등)에 주입함.

### 3.3 이미지 표시 원칙 (v3.2 강조 유지)
- 모든 상세 화면 및 미리보기 화면에서 세로로 긴 옷/코디 사진이 잘리지 않도록 **`BoxFit.contain`** 사용.
- 여백이 생길 경우 회색 배경(`Colors.grey[100]`)으로 자연스럽게 표시.
- 적용 화면: `clothing_detail_screen`, `upload_screen`, `upload_ootd_screen`, `ootd_screen`, `ootd_detail_screen` 등.

### 3.4 인터랙션 색상 및 신규 아이콘 [NEW]
- **인터랙션 색상**:
  - 좋아요(활성): `#ED4956` / 좋아요(비활성): `Colors.black` outline
  - 저장(활성): `Colors.black` filled / 저장(비활성): outline
- **베스트 드레서 뱃지**: 미니멀 블랙 라운드 뱃지 또는 골드 그라데이션(`#FFD700`~`#FFA500`)
- **신규 아이콘**: 좋아요(`Icons.favorite_border`/`Icons.favorite`), 댓글(`Icons.chat_bubble_outline`), 저장(`Icons.bookmark_border`/`Icons.bookmark`), 공유(`Icons.send_outlined`), 알림(`Icons.notifications_outlined`)

---

## 4. 데이터베이스 구조 (Firebase)

### 4.1 기존 컬렉션 — `clothes` (내 옷장)
- `userId` (String): 문서를 생성한 사용자의 UID
- `imageUrl` (String): Storage에 업로드된 사진 URL
- `category` (String): 대분류 (상의, 원피스, 바지, 치마, 아우터, 신발, 가방, 모자, 악세서리, 기타)
- `subCategory` (String): 소분류 (예: 티셔츠, 청바지, 스니커즈 등)
- `tags` (String): 해시태그
- `brand`, `size`, `color`, `pattern`, `material`, `fit`, `length`, `memo` (String, Optional)
- `createdAt` (Timestamp): 생성 시간

#### `clothes` 신규 필드 [NEW]
- `visibility` (String): `"public"` | `"private"` (기본값: `"private"`)
- `_publicMeta` (Map, Optional): 외부 노출 시에만 사용할 필드 화이트리스트 (예: `{color, pattern, category}`만 포함하고 메모/사이즈는 제외). **개인정보 보호의 핵심.**

### 4.2 기존 컬렉션 — `ootds` (오늘의 착장 피드)
- `userId` (String): 작성자 UID
- `imageUrl` (String): OOTD 사진 URL
- `description` (String): 코멘트
- `taggedClothes` (List<Map<String, dynamic>>): 착장에 사용된 옷장 아이템들의 비정규화된 정보. `[{id: "docId", imageUrl: "url", title: "크림 카디건"}, ...]` 형태로 피드 로딩 성능 최적화.
- `createdAt` (Timestamp): 생성 시간

#### `ootds` 신규 필드 [NEW]
- `visibility` (String): `"public"` | `"followers"` | `"private"` (기본값: `"private"`)
- `likeCount` (int, default 0) — Cloud Functions로 자동 갱신
- `commentCount` (int, default 0)
- `saveCount` (int, default 0)
- `hashtags` (List<String>): 검색 및 트렌딩 산정용
- `requestFeedback` (bool): "스타일링 피드백 받기" 토글 활성화 여부
- `dominantColors` (List<String>, Optional): 매칭 알고리즘용

### 4.3 신규 컬렉션 [NEW]

```
users/{userId}
  - displayName, profileImageUrl, bio (max 150자)
  - email, createdAt
  - followerCount, followingCount, postCount   (Functions로 갱신)
  - totalLikesReceived (int)                    (베스트 드레서 산정용)
  - isPrivateAccount (bool, default false)
  - styleMentorBadge (bool, default false)
  - defaultOotdVisibility (String)              (사용자 기본 공개 범위)
  - fcmTokens (List<String>)

users/{userId}/followers/{followerId}
  - followedAt

users/{userId}/following/{followingId}
  - followedAt

ootds/{ootdId}/likes/{userId}
  - likedAt

ootds/{ootdId}/comments/{commentId}
  - userId, userName, userProfileImage (denormalized)
  - content, createdAt
  - isMentorFeedback (bool)                     (스타일 멘토 댓글 강조용)

saves/{userId}/items/{ootdId}
  - savedAt
  - collectionId (Optional, null이면 기본 보관함)

collections/{collectionId}                       (보드 / 무드보드)
  - userId, title, coverImageUrl, itemCount
  - isPublic (bool, default false)
  - createdAt

notifications/{userId}/items/{notifId}
  - type: "like" | "comment" | "follow" | "save" | "best_dresser"
  - actorId, actorName (denormalized)
  - targetType, targetId
  - createdAt, isRead

reports/{reportId}
  - reporterId, targetType, targetId
  - reason (enum), description
  - status: "pending" | "resolved"
  - createdAt

bestDressers/{periodId}                          (예: 2026-W18, 2026-05)
  - period: "weekly" | "monthly"
  - category: "전체" | "미니멀" | "스트릿" | "오피스" 등
  - winners: [{userId, userName, ootdId, score}]
  - generatedAt
```

---

## 5. 서비스 레이어

### 5.1 기존 서비스 (`lib/services/firebase_service.dart`)
모든 백엔드 통신은 싱글톤 패턴으로 구현합니다.
- **인증(Auth)**: `http` 패키지로 REST API 호출. `SharedPreferences`를 사용한 세션 유지.
- **clothes 연동**: `saveClothingData`, `getClothesStream`(userId 기준 필터링 및 createdAt 내림차순 정렬), `updateClothingData`, `deleteClothingData`.
- **ootds 연동**: `saveOOTDData`, `getOOTDStream`(userId 기준 필터링만 수행. 복합 인덱스 에러 방지를 위해 orderBy는 생략하고 UI에서 로컬 정렬 처리), `deleteOOTDData`.
- **이미지 업로드**: `uploadImage` 함수로 Storage에 이미지 저장 후 다운로드 URL 반환.

#### `firebase_service.dart` 확장 [UPDATED]
- 기존 `getOOTDStream()` 의 동작 분기:
  - `getMyOOTDStream()` (기존 동작 유지: 내 OOTD 전체)
  - `getDiscoverFeedStream()` (visibility=='public' 조건, 페이지네이션)
  - `getFollowingFeedStream(followingIds)` (`whereIn` + `orderBy createdAt`)

### 5.2 신규 서비스 [NEW]

#### `social_service.dart`
- `toggleLike(ootdId)`, `toggleSave(ootdId, collectionId?)`, `addComment(...)`, `deleteComment(...)`
- `followUser(userId)`, `unfollowUser(userId)`
- `reportContent(...)`, `blockUser(...)`

#### `feed_service.dart`
- `getDiscoverFeed({lastDoc, category, hashtag})`: 페이지네이션 (`startAfterDocument`)
- `getFollowingFeed(followingIds)`
- `getTrendingHashtags()` (인기 해시태그 상위 N개)

#### `matching_service.dart` [핵심 차별화 — 이 앱의 진짜 무기]
- `analyzeOotdAgainstMyCloset(ootdId)`:
  - OOTD의 `taggedClothes` 각각에 대해 내 옷장에서 매칭
  - **매칭 기준 (점수)**:
    - 같은 `subCategory` + 동일 `color` → **90점**
    - 같은 카테고리 + 다른 색 → **60점**
    - 카테고리만 같음 → **30점**
  - 반환: `{matchScore: 0~100, matchedItems: [...], missingItems: [...]}`
  - UI: "당신은 5개 중 3개의 비슷한 옷을 가지고 있어요!" + 매칭된 내 옷 카드 표시 + 비매칭 옷에 대한 대체 추천

#### `notification_service.dart`
- `getUnreadCount()`, `getNotificationStream()`, `markAsRead(notifId)`
- FCM 토큰 등록/관리

#### `best_dresser_service.dart` (Cloud Functions로 주기 실행)
- 매주/매월: 기간 내 OOTD를 카테고리별로 묶어 `likeCount * 1 + saveCount * 2` 가중 점수 계산
- 상위 N명을 `bestDressers` 컬렉션에 기록 → 선정자 알림 + 프로필 뱃지 표시

---

## 6. 화면별 상세 구현 요구사항

### 6.1 앱 진입 및 로그인 (`main.dart` & `login_screen.dart`)
- `AuthWrapper`를 통해 로그인 상태를 확인하고, `LoginScreen` 또는 `MainScreen`으로 분기합니다.
- `LoginScreen`은 미니멀한 화이트 테마의 이메일/비밀번호 폼으로 구성되며, 직접 작성한 Auth REST API를 호출합니다.

### 6.2 하단 네비게이션 메인 화면 (`lib/screens/main_screen.dart`) [UPDATED]

**기존 (v3.2)**: 옷장 / OOTD / + / 프로필 (4탭)

**신규 (v4.0)**: 5탭 구조

1. **[발견]** (`Icons.search` 기반) — `DiscoverScreen` (앱 시작 시 기본 탭)
2. **[옷장]** (`Icons.grid_view_rounded`) — `HomeScreen` (v3.2 그대로)
3. **[+ 추가]** (중앙, 원형 테두리 포인트) — Bottom Sheet 메뉴 팝업 (탭 이동 아님)
   - 메뉴 1: "옷장에 새 아이템 추가" (`UploadScreen` 호출)
   - 메뉴 2: "오늘의 OOTD 기록하기" (`UploadOotdScreen` 호출)
4. **[피드]** (`Icons.dynamic_feed_outlined`) — `FollowingFeedScreen` (팔로잉 사용자 OOTD 시간순)
5. **[프로필]** (`Icons.person_outline`) — `ProfileScreen` (개인 OOTD 피드는 여기로 통합)

> 기존 v3.2의 OOTD 탭(`Icons.crop_portrait_outlined`)에서 제공하던 "내 OOTD 시간순 보기" 기능은 **프로필 탭의 그리드/리스트 토글**로 이전됩니다.

### 6.3 내 옷장 (홈) 화면 (`lib/screens/home_screen.dart`)
- 인스타그램 스토리와 피드 형식을 차용한 의류 관리 화면.
- **상단 카테고리 필터**: 동그란 아바타 영역에 **대표 커스텀 라인 아트 아이콘**이 표시되는 가로 스크롤 위젯. 총 10개의 대분류 나열.
- **카운트 표시**: 선택된 카테고리명과 함께 아이템 개수(`N items`) 동적 노출.
- **피드 영역**: 3열 그리드(`SliverGrid`).
  - 옷 이미지 하단에 2줄의 텍스트 레이블 표시.
  - 1번 줄: "색상 + 패턴" (없을 경우 브랜드나 카테고리 대체)
  - 2번 줄: **"[대분류] · [소분류]"** (예: 아우터 · 트렌치코트)

### 6.4 발견 화면 (`discover_screen.dart`) [NEW]

**구조**:
- 상단 검색바 (해시태그 / 사용자 / 브랜드)
- 트렌딩 해시태그 가로 스크롤 (`#가을룩`, `#오피스` 등)
- "이번 주 베스트 드레서" 카드 영역 (가로 스크롤, 상위 5명)
- **Masonry 2-column 그리드** (`MasonryGridView` / `flutter_staggered_grid_view`)
  - OOTD 사진 비율 다양함 그대로 노출
  - 사진 위 오버레이: 사용자 아바타 + 좋아요 수 + 저장 아이콘 (탭 시 즉시 저장 모달)
  - `cached_network_image`를 통한 고성능 이미지 렌더링
- **무한 스크롤** (`startAfterDocument` 기반 lazy load)
- 정렬 알고리즘: MVP는 `createdAt desc` + `likeCount` 가중. 추후 사용자 카테고리 선호 기반 개인화로 확장

### 6.5 팔로잉 피드 화면 (`following_feed_screen.dart`) [NEW]

- 인스타그램 스타일 single column
- 게시물 구조: 헤더(아바타+사용자명+날짜) → 사진 → 액션 버튼(좋아요/댓글/저장/공유) → 카운트 → 본문 → 태그된 옷 가로 스크롤 → 댓글 미리보기 (상위 2개)
- 팔로잉 0명 상태(empty state): "팔로우할 사용자가 없어요. 발견 탭에서 다른 사람들의 코디를 둘러보세요" → Discover로 유도 CTA
- Pull-to-refresh 지원

### 6.6 OOTD 상세 화면 (`ootd_detail_screen.dart`) [NEW/UPDATED]

기존 v3.2의 `OotdScreen`(내 OOTD 피드, 헤더+사진+본문+태그 가로 스크롤) 게시물 구조를 베이스로, 단일 OOTD 풀스크린 뷰 + 소셜 인터랙션을 추가:
- 상단: 사진(`BoxFit.contain` 유지) → 본문 → 좋아요/댓글/저장/공유(`share_plus`) 액션 → 카운트 표시
- **태그된 옷 카드 가로 스크롤**: 각 옷 탭 시 → "이 옷이 등장한 다른 OOTD 보기" 화면으로 이동 (옷장 데이터 강점 활용)
- **"내 옷장으로 재현하기" 버튼** [핵심 차별화]:
  - 탭 시 `MatchingService.analyzeOotdAgainstMyCloset()` 호출
  - 결과 화면: 매칭 점수 + "당신은 5개 중 3개의 비슷한 옷을 가지고 있어요" + 매칭된 내 옷 카드 + 비매칭 옷에 대한 대체 추천
- 댓글 영역: 무한 스크롤, 본인 댓글만 삭제 가능
- 우상단 메뉴 (...): 신고하기 / 공유하기 / (본인) 수정·삭제

### 6.7 옷장 업로드 및 정보 관리 (`upload_screen.dart` / `clothing_detail_screen.dart`)
- **2-Depth 카테고리 선택**:
  - 업로드 시 `ChoiceChip`을 이용해 대분류 10개 중 하나를 고르면, 하단에 해당 대분류에 속하는 소분류들(커스텀 아이콘 포함)이 펼쳐짐.
  - 소분류가 존재하는 대분류인데 소분류를 선택하지 않으면 저장이 블록됨.
- **상세 정보 수정**:
  - `clothing_detail_screen.dart`에서 기존에 등록된 옷의 카테고리를 바꿀 때, **대분류 드롭다운**과 **소분류 드롭다운**이 연동되어 작동하며 리스트에 커스텀 옷 아이콘도 함께 노출됨.
- **이미지 미리보기 및 표시**:
  - 옷 상세, 옷/OOTD 업로드 미리보기 화면에서 원본 비율 이미지가 잘려보이지 않도록 `BoxFit.contain` 처리. 여백은 `Colors.grey[100]`.

### 6.8 OOTD 업로드 화면 (`upload_ootd_screen.dart`) [UPDATED]

기존 기능 + 추가 항목:
- **공개 범위 셀렉터** (필수): 공개 / 팔로워만 / 나만 보기
  - 디폴트는 사용자의 `defaultOotdVisibility` 설정값
- 해시태그 입력 (자동완성: 트렌딩 해시태그 추천)
- **"스타일링 피드백 받기" 토글**: 활성화 시 댓글 영역에 피드백 카테고리 템플릿 노출 ("핏 어때요?" / "색 조합 의견 주세요" 등). 양방향 소통을 자연스럽게 유도하는 장치
- 옷 태깅 시: 태그할 옷이 private이라도 OOTD를 public으로 올릴 수 있음. 단 옷의 `_publicMeta` 화이트리스트 필드만 외부 노출

### 6.9 사용자 프로필 화면 (`profile_screen.dart`) [UPDATED]

기존 v3.2(이메일+로그아웃)에서 대폭 확장:
- **헤더**:
  - 프로필 이미지 (탭 시 변경)
  - 이름 + bio (편집 가능)
  - 통계: 게시물 수 / 팔로워 / 팔로잉 (인스타 패턴, 탭 시 목록 모달)
  - **베스트 드레서 뱃지** / **스타일 멘토 뱃지** (해당 시)
  - 받은 좋아요 합계 표시
- **액션 영역**:
  - 본인: 프로필 편집 / 설정 / 로그아웃
  - 타인: 팔로우 버튼 / 메시지(추후) / 신고·차단
- **탭 토글**: [내 OOTD 그리드] / [저장한 컬렉션]
- **그리드**: 3열, 본인 화면이면 private 포함, 타인 화면이면 visibility에 따라 자동 필터링
- **컬렉션 탭**: 사용자가 만든 보드 목록 (커버 이미지 + 제목 + 아이템 수)

### 6.10 컬렉션(보드) 화면 [NEW]

- `collections_screen.dart`: 내 보드 목록 (그리드)
- `collection_detail_screen.dart`: 단일 보드 내 OOTD masonry 그리드
- 새 보드 만들기 / 이름 변경 / 공개 여부 설정
- 저장 시 보드 선택 모달: [기본 보관함] / [새 보드 만들기] / [기존 보드]

### 6.11 알림 화면 (`notifications_screen.dart`) [NEW]

- 시간순 정렬, 읽음/안 읽음 시각적 구분
- 그룹화: "OOO님 외 3명이 회원님의 OOTD를 좋아합니다"
- 탭 시 해당 OOTD/프로필로 이동

### 6.12 검색 화면 (`search_screen.dart`) [NEW]

- 탭: 사용자 / 해시태그 / 브랜드 (옷의 brand 필드 활용)
- MVP는 Firestore의 단순 prefix 쿼리로 시작, 추후 Algolia/Typesense 도입 검토

### 6.13 설정 / 운영 화면 [NEW]
- 차단한 사용자 목록 / 해제
- 기본 OOTD 공개 범위 설정
- 알림 설정 (좋아요/댓글/팔로우/저장 각각 on/off)
- 푸시 알림 권한 관리

---

## 7. 주요 구현 규칙 (바이브코딩 지침)

### 7.1 기존 v3.2 규칙 유지
- 모든 파일과 위젯은 **한국어**로 텍스트를 구성해야 합니다.
- 폰트 아이콘(Web)의 경우, 누락 방지를 위해 `--no-tree-shake-icons` 플래그로 빌드합니다.
- Firebase 쿼리문 작성 시 복합 인덱스(Composite Index)가 필요한 경우, 무리하게 `.orderBy()`를 쓰지 말고 Dart단에서 데이터를 받아온 후 `.sort()`로 처리하여 사용자가 콘솔 설정을 건드리는 일을 방지합니다.

### 7.2 마이그레이션 (필수, 절대 누락 금지) [NEW]
- v3.2 → v4.0 업데이트 시 **기존 모든 OOTD와 옷의 `visibility`는 `"private"`으로 강제 설정**
- 사용자가 명시적으로 공개 전환할 때까지 외부 노출 금지
- 앱 첫 실행 시 일회성 안내 모달:
  > "새로 추가된 소셜 기능이 도입되었습니다. 기존에 작성하신 모든 게시물은 비공개로 유지됩니다. 공개하고 싶은 게시물만 직접 공개로 변경하실 수 있습니다."

> **이 규칙은 신뢰의 핵심입니다. 한 명의 사용자라도 의도치 않게 옷장이 공개되면 앱 신뢰도는 즉시 무너집니다.**

### 7.3 카운터 denormalization [NEW]
- `likeCount`, `commentCount`, `saveCount` 등은 **Cloud Functions의 onCreate/onDelete 트리거로 자동 갱신**
- 클라이언트에서 직접 카운트 쓰기 금지 (보안 + 정합성)
- 알림(FCM) 역시 Cloud Functions의 Firestore Trigger를 통해 백그라운드에서 발송

### 7.4 피드 구현 전략 [NEW]
- **MVP**: Following 피드는 fan-in 방식 (`whereIn` 쿼리, 팔로잉 30명 한도)
- **확장 시**: hybrid (인플루언서급은 fan-in, 일반 사용자는 fan-out)

### 7.5 보안 규칙 (Security Rules) [NEW]
- `ootds` 읽기 권한:
  - `visibility=='public'` 또는
  - `userId==auth.uid` 또는
  - `visibility=='followers'` && requesting user is in followers
- 카운터 필드는 클라이언트에서 직접 수정 불가 (Functions만 가능)
- `clothes`의 `memo`, `size` 등 비공개 필드는 외부 사용자 쿼리 시 projection으로 제외

### 7.6 콘텐츠 안전 [NEW]
- 신고 5회 이상 누적된 OOTD는 자동 비공개 처리 + 어드민 검토 큐로 이동
- 차단한 사용자의 콘텐츠는 모든 피드(Discover/Following/Search)에서 자동 필터링

### 7.7 옷 메모 보호 (개인정보) [NEW]
- OOTD가 public이어도 태그된 옷의 `memo`(세탁법, 개인 메모 등) 필드는 **절대 외부 노출 금지**
- 옷 정보를 OOTD에 임베드 시 화이트리스트 필드만 복사

---

## 8. 단계별 구현 로드맵 [NEW]

거대한 확장이므로 한 번에 다 구현하지 말고 단계로 나눠 출시할 것을 강력 권장:

| Phase | 내용 | 비고 |
|-------|------|------|
| **Phase 1** | visibility 필드 추가 + 마이그레이션 + 보안 규칙 | 보안 인프라, 외부 변화 없음 |
| **Phase 2** | Discover 피드 (읽기 전용) + 사용자 프로필 페이지 | "관전 모드" — 공개된 OOTD 보기만 |
| **Phase 3** | Save / Collections (보드) | 핀터레스트형 핵심 가치 |
| **Phase 4** | Follow + Following 피드 | 관계 그래프 형성 시작 |
| **Phase 5** | 좋아요 + 댓글 + 알림 + FCM | 양방향 소통 본격화 |
| **Phase 6** | **옷장 매칭 (Matching Service)** | 이 앱의 진짜 차별화 무기 |
| **Phase 7** | 베스트 드레서 + 스타일 멘토 뱃지 | 커뮤니티 동기 부여 |
| **Phase 8** | 신고/차단/모더레이션 도구 | 운영 안정화 |

---

## 9. 배포 방식 (Firebase Hosting)

프로젝트 최상단 디렉토리에는 시스템 환경에 무관하게 돌아가는 자체 `firebase_bin` 바이너리가 있습니다.

### 9.1 프론트엔드 (웹 앱)
```bash
.fvm/flutter_sdk/bin/flutter build web --no-tree-shake-icons && ./firebase_bin deploy --only hosting
```

### 9.2 백엔드 (Cloud Functions, 보안 규칙) [NEW]
```bash
./firebase_bin deploy --only functions,firestore:rules
```

### 9.3 Firestore 인덱스 관리 [NEW]
- `firestore.indexes.json`로 관리
- 특히 다음 복합 인덱스 필요:
  - Discover 피드: `visibility + createdAt + likeCount`
  - Following 피드: `userId(in) + createdAt`
