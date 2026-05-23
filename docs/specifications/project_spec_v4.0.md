# 디지털 옷장 (My Digital Closet) 작업지시서 v4.0

본 문서는 **v3.9 작업지시서** 위에서 추가로 설계 및 구현된 **프라이빗 마이크로 소셜(Private Micro-Social)** 기능의 아키텍처, 데이터 스키마, 기능 상세, 그리고 성능 최적화 내역을 세세하게 기록합니다. 

단순 개인용 유틸리티 앱에서 탈피하여 찐친(최대 10명 제한)들과 코디를 공유하고 상호작용하는 구조로 확장되었습니다.

---

## 1. 프라이빗 마이크로 소셜 기획 의도 및 정책

### 1.1 배경 및 목적
개방형 SNS의 피로도를 피하기 위해 최근 트렌드에 맞춰 '진짜 친한 친구'만 등록할 수 있는 폐쇄형(프라이빗) 소셜 기능을 도입했습니다. 
- **친구 등록 제한**: 1인당 최대 10명까지만 친구를 등록할 수 있습니다.
- **친구 코디 도와주기**: 내 친구의 옷장을 열람하고, 친구의 옷으로 가상 코디를 만들어 제안할 수 있습니다.
- **상호작용**: 친구들의 OOTD 피드를 모아보고, 좋아요/댓글/대댓글을 통해 소통합니다.

### 1.2 피드 노출 알고리즘 (팔로잉 로직)
- **독립적 피드 모델**: 인스타그램과 동일한 구조로, '나'의 피드에는 오로지 `나`와 `내가 친구로 추가한 10명`의 게시물만 노출됩니다.
- 내 친구 A가 B와 친구라고 하더라도, 나와 B가 친구가 아니라면 B의 게시물은 내 피드에 절대 노출되지 않습니다.

---

## 2. 데이터 모델 및 스키마 변경

소셜 기능을 지원하기 위해 사용자, OOTD, Planned OOTD, 알림 컬렉션에 대대적인 스키마 확장이 이루어졌습니다.

### 2.1 Users 컬렉션 확장
```javascript
users/{uid} {
  nickname: string,
  profileImageUrl: string,
  friends: [string],          // 내가 추가한 친구 UID 배열 (최대 10명 제한)
  friendRequests: [string],   // 나에게 들어온 친구 요청 UID 배열
  contactInfo: string         // 이메일, 전화번호 등 식별 키
}
```

### 2.2 OOTD 및 Planned OOTD 공통 소셜 스키마
기존 `ootds` 컬렉션에만 있던 소셜 필드를 `planned_ootds` 컬렉션에도 동일하게 확장 적용했습니다.
```javascript
ootds/{docId} OR planned_ootds/{docId} {
  // ... 기존 필드 (imageUrl, taggedClothes 등)
  likedBy: [string],          // 좋아요를 누른 사용자 UID 배열
  commentCount: number,       // 댓글 수 (피드 밖에서 노출하기 위한 역정규화 필드)
  suggestedBy: string,        // (planned_ootds 전용) 코디를 추천해준 친구 닉네임
}

// 하위 서브 컬렉션 (Sub-collections)
{collection}/{docId}/comments/{commentId} {
  userId: string,
  nickname: string,
  profileImageUrl: string,
  text: string,
  createdAt: timestamp,
  parentId: string // (옵션) 대댓글일 경우 원본 댓글의 ID. 루트 댓글이면 null.
}
```

### 2.3 알림 (Notifications) 스키마 추가
```javascript
users/{uid}/notifications/{notiId} {
  type: string,          // 'friend_request', 'like', 'comment', 'planned_ootd_suggest'
  fromUserId: string,    // 알림 발생자
  fromNickname: string,  
  targetId: string,      // 클릭 시 이동할 타겟 문서 ID (ootdId 또는 plannedOotdId)
  message: string,       // 노출할 메시지
  isRead: boolean,
  createdAt: timestamp
}
```

---

## 3. 핵심 화면 및 컴포넌트 구현 상세

### 3.1 내 OOTD 모아보기 (바둑판 3열 레이아웃)
- **개편 사항**: 기존 세로 리스트뷰로 나열되던 내 OOTD 기록을 인스타그램 프로필처럼 `GridView.builder` (3열, 1:1 비율)로 전면 개편.
- **라우팅 분리**: 썸네일을 클릭하면 상세 내용을 볼 수 있는 `MyOotdDetailScreen`으로 이동. 해당 화면에서만 날짜/태그 수정 및 게시물 삭제가 가능하도록 분리.

### 3.2 친구 피드 최적화 (Pagination & Limit)
- **문제점**: 친구가 늘어날수록 `whereIn` 쿼리로 친구들의 모든 OOTD를 한 번에 불러오면 이미지 렌더링 폭탄(메모리 누수 및 버벅임)이 발생.
- **성능 최적화**: `FirebaseService.getFriendsOotdFeed` 함수에서 `orderBy('createdAt', descending: true)`와 `.limit(20)` 쿼리를 조합하여, 서버 단에서 최신 게시물 20개만 선별해 내려오도록 트래픽 및 렌더링 비용 극강 최적화.

### 3.3 코디 아이디어 (Planned OOTD) 소셜 연동
- 친구가 내 옷장으로 만들어 준 코디가 저장되면 하단에 `💡 by {친구닉네임}` 배지가 오버레이로 노출.
- 해당 코디 아이디어의 썸네일을 터치 시 팝업(Dialog)이 아닌 `PlannedOotdDetailScreen`으로 네비게이션.
- 화면 하단에 `OotdInteractionBar` 위젯을 재활용하여 코디 아이디어에 대해서도 좋아요와 댓글/대댓글을 남길 수 있도록 완벽 호환 구현.

### 3.4 대댓글 시스템 및 알림 라우팅
- **대댓글 구조**: `CommentsSheet` 위젯 내에 `parentId`를 도입. 부모 댓글 ID를 기준으로 Map을 생성하여 루트 댓글 아래에 대댓글(Reply)들을 들여쓰기하여 렌더링.
- **알림 라우팅**: 알림 화면에서 `targetId` 필드를 감지하여, "코디를 추천했습니다!" 알림을 누르면 해당 코디 화면(`PlannedOotdDetailScreen`)으로 바로 점프, 댓글/좋아요 알림을 누르면 해당 OOTD(`SingleOotdScreen`)로 바로 점프하도록 네비게이션 플로우 연결.

---

## 4. 빌드 및 배포 주의사항 (유지)
- **웹 렌더러 (CanvasKit 강제)**: 캔버스 캡처 기능이 있으므로 `--web-renderer canvaskit` 필수.
- **트리 쉐이킹 방지**: 구글 머티리얼 아이콘 노출 버그를 막기 위해 `--no-tree-shake-icons` 필수.
