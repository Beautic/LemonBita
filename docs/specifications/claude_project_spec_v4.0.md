# 디지털 옷장 (My Digital Closet) 작업지시서 v4.0

이 문서는 v3.1 작업지시서의 후속 버전으로, **소셜 디스커버리 레이어**가 추가된 확장 버전입니다. 기존 v3.1의 모든 기능은 그대로 유지되며, 신규/변경 사항은 `[NEW]` 또는 `[UPDATED]`로 표시되었습니다.

(v4.0: 핀터레스트형 발견 피드 + 인스타그램형 소셜 관계 레이어 도입. "내 옷장 매칭" 기능을 핵심 차별화 요소로 추가)

## 1. 프로젝트 개요 및 비전

### 1.1 기존 (v3.1)
사용자가 자신의 옷을 체계적으로 관리하고 OOTD를 기록하는 개인용 디지털 옷장.

### 1.2 확장 비전 (v4.0) [NEW]
**3대 기둥(Three Pillars)**:
1. **My Closet (개인 관리)**: 내 옷을 체계적으로 관리 (v3.1의 핵심 그대로)
2. **Discover (영감과 발견)**: 다른 사람들의 잘 입은 코디를 핀터레스트형 그리드로 탐색
3. **Connect (관계와 소통)**: 좋아요/댓글/팔로우 기반의 양방향 스타일링 커뮤니티

**핵심 차별화 포인트**: 옷이 속성 단위(카테고리/색상/패턴/핏 등)로 정규화되어 있다는 강점을 활용해, 다른 사람의 OOTD를 **"내 옷장으로 재현 가능한가?"** 로 분석해 주는 매칭 기능을 도입. 일반 패션 SNS는 절대 못 하는 영역.

**포지셔닝**: 핀터레스트형 발견 엔진을 베이스로, 인스타그램형 사람-관계 레이어를 얹은 하이브리드. **무게중심은 발견(Discover) 쪽**.

## 2. 기술 스택 (v3.1 + 확장)

### 2.1 기존 유지
Flutter, Firebase (Firestore, Storage, Auth REST), 기존 패키지들.

### 2.2 신규 추가 [NEW]
- **Cloud Functions for Firebase**: 카운터 denormalization, 알림 트리거, 베스트 드레서 주기 산정
- **Firebase Cloud Messaging (FCM)**: 좋아요/댓글/팔로우 푸시 알림
- 추가 패키지:
  - `firebase_messaging` (푸시 알림)
  - `flutter_staggered_grid_view` (Discover 탭의 masonry 그리드)
  - `cached_network_image` (피드 이미지 캐싱 — 성능 필수)
  - `share_plus` (공유 기능)

## 3. 디자인 시스템 추가 사항 [NEW]

기존 v3.1의 화이트 미니멀 톤은 그대로 유지하되, 소셜 인터랙션을 위한 요소만 추가:

- **인터랙션 색상**:
  - 좋아요(활성): `#ED4956` / 좋아요(비활성): `Colors.black` outline
  - 저장(활성): `Colors.black` filled / 저장(비활성): outline
- **베스트 드레서 뱃지**: 미니멀 블랙 라운드 뱃지 또는 골드 그라데이션(`#FFD700`~`#FFA500`)
- **신규 아이콘**: 좋아요(`Icons.favorite_border`/`Icons.favorite`), 댓글(`Icons.chat_bubble_outline`), 저장(`Icons.bookmark_border`/`Icons.bookmark`), 공유(`Icons.send_outlined`), 알림(`Icons.notifications_outlined`)

## 4. 데이터베이스 구조 (v3.1 확장)

### 4.1 기존 컬렉션 변경 사항 [UPDATED]

#### `clothes` 컬렉션
기존 필드 그대로 유지 + 신규 필드:
- `visibility` (String): `"public"` | `"private"` (기본값: `"private"`)
- `_publicMeta` (Map, Optional): 외부 노출 시에만 사용할 필드 화이트리스트 (예: `{color, pattern, category}`만 포함하고 메모/사이즈는 제외). **개인정보 보호의 핵심.**

#### `ootds` 컬렉션
기존 필드 그대로 유지 + 신규 필드:
- `visibility` (String): `"public"` | `"followers"` | `"private"` (기본값: `"private"`)
- `likeCount` (int, default 0) — Cloud Functions로 자동 갱신
- `commentCount` (int, default 0)
- `saveCount` (int, default 0)
- `hashtags` (List<String>): 검색 및 트렌딩 산정용
- `requestFeedback` (bool): "스타일링 피드백 받기" 토글 활성화 여부
- `dominantColors` (List<String>, Optional): 매칭 알고리즘용

### 4.2 신규 컬렉션 [NEW]

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

## 5. 서비스 레이어 확장

### 5.1 기존 서비스 (`firebase_service.dart`) 확장 [UPDATED]
- `getOOTDStream()` 의 동작 분기:
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
  - 매칭 기준 (점수): 같은 `subCategory` + 동일 `color` → 90점 / 같은 카테고리 + 다른 색 → 60점 / 카테고리만 같음 → 30점
  - 반환: `{matchScore: 0~100, matchedItems: [...], missingItems: [...]}`
  - UI: "당신은 5개 중 3개의 비슷한 옷을 가지고 있어요!" + 매칭된 내 옷 카드 표시

#### `notification_service.dart`
- `getUnreadCount()`, `getNotificationStream()`, `markAsRead(notifId)`
- FCM 토큰 등록/관리

#### `best_dresser_service.dart` (Cloud Functions로 주기 실행)
- 매주/매월: 기간 내 OOTD를 카테고리별로 묶어 `likeCount * 1 + saveCount * 2` 가중 점수 계산
- 상위 N명을 `bestDressers` 컬렉션에 기록 → 선정자 알림 + 프로필 뱃지 표시

## 6. 화면별 상세 구현 요구사항

### 6.1 하단 네비게이션 재구성 [UPDATED]

**기존 (v3.1)**: 옷장 / OOTD / + / 프로필 (4탭)

**신규 (v4.0)**: 5탭 구조

1. **[발견]** (`Icons.search` 기반) — `DiscoverScreen` (앱 시작 시 기본 탭으로 변경)
2. **[옷장]** (`Icons.grid_view_rounded`) — `HomeScreen` (v3.1 그대로)
3. **[+ 추가]** (중앙) — Bottom Sheet (v3.1 그대로)
4. **[피드]** (`Icons.dynamic_feed_outlined`) — `FollowingFeedScreen` (팔로잉 사용자 OOTD 시간순)
5. **[프로필]** (`Icons.person_outline`) — `ProfileScreen` (개인 OOTD 피드는 여기로 통합)

> 기존 OOTD 탭의 "내 OOTD 시간순 보기" 기능은 **프로필 탭의 그리드/리스트 토글**로 이전됩니다.

### 6.2 발견 화면 (`discover_screen.dart`) [NEW]

**구조**:
- 상단 검색바 (해시태그 / 사용자 / 브랜드)
- 트렌딩 해시태그 가로 스크롤 (`#가을룩`, `#오피스` 등)
- "이번 주 베스트 드레서" 카드 영역 (가로 스크롤, 상위 5명)
- **Masonry 2-column 그리드** (`MasonryGridView`)
  - OOTD 사진 비율 다양함 그대로 노출
  - 사진 위 오버레이: 사용자 아바타 + 좋아요 수 + 저장 아이콘 (탭 시 즉시 저장 모달)
- **무한 스크롤** (`startAfterDocument` 기반 lazy load)
- 정렬 알고리즘: MVP는 `createdAt desc` + `likeCount` 가중. 추후 사용자 카테고리 선호 기반 개인화로 확장

### 6.3 팔로잉 피드 화면 (`following_feed_screen.dart`) [NEW]

- 인스타그램 스타일 single column
- 게시물 구조: 헤더(아바타+사용자명+날짜) → 사진 → 액션 버튼(좋아요/댓글/저장/공유) → 카운트 → 본문 → 태그된 옷 가로 스크롤 → 댓글 미리보기 (상위 2개)
- 팔로잉 0명 상태(empty state): "팔로우할 사용자가 없어요. 발견 탭에서 다른 사람들의 코디를 둘러보세요" → Discover로 유도 CTA
- Pull-to-refresh 지원

### 6.4 OOTD 상세 화면 (`ootd_detail_screen.dart`) [NEW]

- 단일 OOTD 풀스크린 뷰
- 상단: 사진 → 본문 → 좋아요/댓글/저장 액션 → 카운트 표시
- **태그된 옷 카드 가로 스크롤**: 각 옷 탭 시 → "이 옷이 등장한 다른 OOTD 보기" 화면으로 이동 (옷장 데이터 강점 활용)
- **"내 옷장으로 재현하기" 버튼** [핵심 차별화]:
  - 탭 시 `MatchingService.analyzeOotdAgainstMyCloset()` 호출
  - 결과 화면: 매칭 점수 + "당신은 5개 중 3개의 비슷한 옷을 가지고 있어요" + 매칭된 내 옷 카드 + 비매칭 옷에 대한 대체 추천
- 댓글 영역: 무한 스크롤, 본인 댓글만 삭제 가능
- 우상단 메뉴 (...): 신고하기 / 공유하기 / (본인) 수정·삭제

### 6.5 사용자 프로필 화면 (`profile_screen.dart`) [UPDATED]

기존(이메일+로그아웃)에서 대폭 확장:
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

### 6.6 OOTD 업로드 화면 (`upload_ootd_screen.dart`) [UPDATED]

기존 기능 + 추가 항목:
- **공개 범위 셀렉터** (필수): 공개 / 팔로워만 / 나만 보기
  - 디폴트는 사용자의 `defaultOotdVisibility` 설정값
- 해시태그 입력 (자동완성: 트렌딩 해시태그 추천)
- **"스타일링 피드백 받기" 토글**: 활성화 시 댓글 영역에 피드백 카테고리 템플릿 노출 ("핏 어때요?" / "색 조합 의견 주세요" 등). 양방향 소통을 자연스럽게 유도하는 장치
- 옷 태깅 시: 태그할 옷이 private이라도 OOTD를 public으로 올릴 수 있음. 단 옷의 `_publicMeta` 화이트리스트 필드만 외부 노출

### 6.7 컬렉션(보드) 화면 [NEW]

- `collections_screen.dart`: 내 보드 목록 (그리드)
- `collection_detail_screen.dart`: 단일 보드 내 OOTD masonry 그리드
- 새 보드 만들기 / 이름 변경 / 공개 여부 설정
- 저장 시 보드 선택 모달: [기본 보관함] / [새 보드 만들기] / [기존 보드]

### 6.8 알림 화면 (`notifications_screen.dart`) [NEW]

- 시간순 정렬, 읽음/안 읽음 시각적 구분
- 그룹화: "OOO님 외 3명이 회원님의 OOTD를 좋아합니다"
- 탭 시 해당 OOTD/프로필로 이동

### 6.9 검색 화면 (`search_screen.dart`) [NEW]

- 탭: 사용자 / 해시태그 / 브랜드 (옷의 brand 필드 활용)
- MVP는 Firestore의 단순 prefix 쿼리로 시작, 추후 Algolia/Typesense 도입 검토

### 6.10 설정 / 운영 화면 [NEW]
- 차단한 사용자 목록 / 해제
- 기본 OOTD 공개 범위 설정
- 알림 설정 (좋아요/댓글/팔로우/저장 각각 on/off)
- 푸시 알림 권한 관리

## 7. 주요 구현 규칙

### 7.1 기존 v3.1 규칙 유지
한국어 텍스트, `--no-tree-shake-icons`, Dart단 정렬.

### 7.2 신규 규칙 [NEW]

#### 7.2.1 마이그레이션 (필수, 절대 누락 금지)
- v3.1 → v4.0 업데이트 시 **기존 모든 OOTD와 옷의 `visibility`는 `"private"`으로 강제 설정**
- 사용자가 명시적으로 공개 전환할 때까지 외부 노출 금지
- 앱 첫 실행 시 일회성 안내 모달:
  > "새로 추가된 소셜 기능이 도입되었습니다. 기존에 작성하신 모든 게시물은 비공개로 유지됩니다. 공개하고 싶은 게시물만 직접 공개로 변경하실 수 있습니다."

> **이 규칙은 신뢰의 핵심입니다. 한 명의 사용자라도 의도치 않게 옷장이 공개되면 앱 신뢰도는 즉시 무너집니다.**

#### 7.2.2 카운터 denormalization
- `likeCount`, `commentCount`, `saveCount` 등은 **Cloud Functions의 onCreate/onDelete 트리거로 자동 갱신**
- 클라이언트에서 직접 카운트 쓰기 금지 (보안 + 정합성)

#### 7.2.3 피드 구현 전략
- **MVP**: Following 피드는 fan-in 방식 (`whereIn` 쿼리, 팔로잉 30명 한도)
- **확장 시**: hybrid (인플루언서급은 fan-in, 일반 사용자는 fan-out)

#### 7.2.4 보안 규칙 (Security Rules)
- `ootds` 읽기 권한:
  - `visibility=='public'` 또는
  - `userId==auth.uid` 또는
  - `visibility=='followers'` && requesting user is in followers
- 카운터 필드는 클라이언트에서 직접 수정 불가 (Functions만 가능)
- `clothes`의 `memo`, `size` 등 비공개 필드는 외부 사용자 쿼리 시 projection으로 제외

#### 7.2.5 콘텐츠 안전
- 신고 5회 이상 누적된 OOTD는 자동 비공개 처리 + 어드민 검토 큐로 이동
- 차단한 사용자의 콘텐츠는 모든 피드(Discover/Following/Search)에서 자동 필터링

#### 7.2.6 옷 메모 보호 (개인정보)
- OOTD가 public이어도 태그된 옷의 `memo`(세탁법, 개인 메모 등) 필드는 **절대 외부 노출 금지**
- 옷 정보를 OOTD에 임베드 시 화이트리스트 필드만 복사

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

## 9. 배포

### 9.1 기존 (v3.1과 동일)
```bash
fvm flutter build web --no-tree-shake-icons && ./firebase_bin deploy --only hosting
```

### 9.2 신규 [NEW]
- Cloud Functions 추가 시:
  ```bash
  ./firebase_bin deploy --only functions
  ```
- Firestore 인덱스 추가 관리: `firestore.indexes.json`
  - 특히 Discover 피드의 `visibility + createdAt + likeCount` 복합 인덱스 필요
  - Following 피드의 `userId(in) + createdAt` 인덱스 필요
