# 디지털 옷장 (My Digital Closet) 작업지시서 v4.1

본 문서는 **v4.0 작업지시서** 위에서 추가로 설계 및 구현된 **코디 캔버스 UI/UX 고도화 및 누끼 이미지 최적화** 내역을 세세하게 기록합니다. 

프라이빗 소셜 기능을 갖춘 후, 사용자가 더욱 편리하고 직관적으로 코디를 구성할 수 있도록 조작성과 시각적 품질을 극대화했습니다.

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
- **성능 최적화**: `FirebaseService.getFriendsOotdFeed` 함수에서 `orderBy('createdAt', descending: true)`와 `.limit(20)` 쿼리를 조합하여, 서버 단에서 최신 게시물 20개만 선별해 내려오도록 렌더링 비용 극강 최적화.

### 3.3 코디 아이디어 (Planned OOTD) 소셜 연동
- 친구가 내 옷장으로 만들어 준 코디가 저장되면 하단에 `💡 by {친구닉네임}` 배지가 오버레이로 노출.
- 하단에 `OotdInteractionBar` 위젯을 재활용하여 코디 아이디어에 대해서도 좋아요와 댓글/대댓글을 남길 수 있도록 완벽 호환 구현.

### 3.4 대댓글 시스템 및 알림 라우팅
- **대댓글 구조**: `CommentsSheet` 위젯 내에 `parentId`를 도입. 부모 댓글 ID를 기준으로 루트 댓글 아래에 대댓글(Reply)들을 들여쓰기하여 렌더링.
- **알림 라우팅**: 알림 클릭 시 `targetId` 필드를 감지하여 해당 OOTD 또는 코디 화면으로 바로 점프.

---

## 4. UI/UX 고도화 상세 (v4.1 신규)

### 4.1 누끼 이미지 여백 자동 제거 (Auto-Cropping)
- **목적**: 멀리서 촬영한 옷 사진의 배경을 제거할 때, 투명해진 거대한 빈 여백 때문에 옷이 캔버스 상에서 너무 작게 표시되는 문제 해결.
- **구현 로직**: `web/bg_removal.js` 내에 픽셀 알파 채널(투명도) 스캔 로직을 추가하여, 옷이 존재하는 영역(Bounding Box)을 계산한 뒤 여백을 빈틈없이 잘라낸 PNG 이미지로 변환 및 저장.

### 4.2 옷 비율(Aspect Ratio) 동적 대응 컨테이너
- **목적**: 코디 캔버스에 등록된 옷의 핏이나 길이(원피스, 긴바지 등)에 상관없이 테두리(Border)가 옷의 모양에 딱 맞게 그려지도록 개선.
- **구현 로직**: 캔버스 내 아이템 컨테이너의 크기를 고정 정사각형(120x120)에서 `BoxConstraints(maxWidth: 150, maxHeight: 150)` 기반의 동적 레이아웃으로 변경. 원본 이미지 비율을 그대로 유지.

### 4.3 캔버스 글로벌 제스처 히트박스 (UX 혁신)
- **목적**: 모바일 환경의 좁은 화면에서 크기가 작은 옷 이미지를 두 손가락으로 핀치 줌 하거나 드래그하기 어려운 UX 병목 현상 타개.
- **구현 로직**: 
  - 아이템 터치(`onTapDown`) 시 즉시 선택 상태(활성화)로 변경.
  - 아이템 이동, 확대, 회전을 제어하는 제스처(`onScaleStart`, `onScaleUpdate`)를 개별 아이템에서 **캔버스 배경(격자) 전체 영역**으로 위임.
  - 사용자는 옷을 한 번 누른 뒤, 화면 내 텅 빈 격자 어디에서든 꼬집거나 끌어서(Global Hitbox) 해당 옷을 조작할 수 있음.

---

## 5. 빌드 및 배포 주의사항
- **웹 렌더러 (CanvasKit 강제)**: 캔버스 캡처 기능이 있으므로 `--web-renderer canvaskit` 필수.
- **트리 쉐이킹 방지**: 구글 머티리얼 아이콘 노출 버그를 막기 위해 `--no-tree-shake-icons` 필수.
