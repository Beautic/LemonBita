# 디지털 옷장 (My Digital Closet) 작업지시서 v3.9 (Draft)

이 문서는 기존 개인용 디지털 옷장(v3.2)에 **OOTD 소셜 공유 기능**을 도입하기 위한 중간 단계(v3.9) 작업지시서 초안입니다. Claude가 제안한 v4.0 스펙을 바탕으로, 당장 구현 가능한 핵심 소셜 기능들을 우선적으로 추려내어 점진적 확장을 도모합니다.

## 1. 프로젝트 비전 및 목표 (v3.9)
기존의 개인 옷 관리 및 코디 기록 기능(My Closet)을 완벽하게 유지하면서, 사용자들이 원할 경우 자신의 OOTD를 다른 사용자들과 공유하고 영감을 얻을 수 있는 **'발견(Discover)'** 기능을 MVP(최소 기능 제품) 수준으로 도입합니다.

## 2. 주요 개선 사항 (v4.0 기반 축소/우선순위 적용)
v4.0의 방대한 8단계 로드맵 중, 당장 OOTD 공유 피드를 만드는 데 필수적인 **Phase 1 ~ Phase 2** (일부 Phase 5 포함) 기능에 집중합니다.

- **데이터 마이그레이션 및 프라이버시 (가장 중요)**: 기존 OOTD는 무조건 비공개 처리. 새로운 OOTD 작성 시 공개 여부 선택 기능 필수.
- **Discover 피드 추가**: 모두가 볼 수 있는 공개된 OOTD를 모아보는 피드.
- **기본적인 소셜 인터랙션**: 다른 사람의 OOTD 구경, 작성자 표기, 기본 좋아요(Like) 기능.

## 3. 데이터베이스 변경 사항

### 3.1 `ootds` 컬렉션 구조 업데이트
- `visibility` (String): `"public"` | `"private"` (기본값: `"private"`) 필드 추가
- `likeCount` (int): 좋아요 수 카운팅
- `userEmail` 또는 `userName` (String): 작성자 표시를 위한 닉네임
- **[주의]** 기존 OOTD 데이터는 스크립트나 코드 레벨에서 전부 `visibility: "private"`으로 간주되도록 쿼리 처리.

### 3.2 신규 컬렉션 추가
- `users/{userId}`: 작성자의 프로필 이미지, 닉네임 등 저장 (기존에는 Auth에만 의존했으나, 소셜 기능을 위해 DB에 유저 문서 필요)
- `ootds/{ootdId}/likes/{userId}`: 좋아요 중복 방지용 하위 컬렉션

## 4. UI 및 기능 상세 (v3.9 적용)

### 4.1 앱 하단 네비게이션 변경 (5탭 구조)
1. **[발견]** (`Icons.search` 또는 `Icons.explore`): 전체 공개된 OOTD 피드 화면 (앱 시작 기본 화면으로 고려)
2. **[옷장]** (`Icons.grid_view_rounded`): 내 옷장 (기존 유지)
3. **[+ 추가]**: 업로드 바텀시트 (기존 유지)
4. **[내 OOTD]** (`Icons.crop_portrait_outlined`): 내가 올린 OOTD만 보는 개인 피드 (기존 OOTD 탭 역할)
5. **[프로필]** (`Icons.person_outline`): 내 정보 설정 및 로그아웃

### 4.2 발견 (Discover) 피드 화면 (`discover_screen.dart` 신설)
- 모든 사용자의 `visibility: "public"`인 OOTD를 최신순으로 보여주는 그리드 또는 리스트 뷰.
- 핀터레스트 스타일로 이미지 썸네일과 작성자 아이디를 표시.
- 클릭 시 OOTD 상세 화면으로 이동.

### 4.3 OOTD 상세 화면 및 업로드 변경
- **상세 화면 (`ootd_detail_screen.dart`)**: 작성자 닉네임 표시, 좋아요 버튼 노출. 다른 사람의 글에는 삭제 버튼 미노출. 태그된 옷 클릭 시 확인 가능.
- **업로드 화면 (`upload_ootd_screen.dart`)**: '공개 범위 설정' 셀렉터 추가 (전체 공개 vs 나만 보기). 기존에 작성된 글들을 보호하기 위해 기본값은 '나만 보기'로 권장.

## 5. 구현 규칙 및 마이그레이션 지침
1. **프라이버시 최우선**: 사용자가 직접 명시적으로 '전체 공개'를 누르지 않는 이상 절대 다른 사용자에게 노출되지 않아야 합니다. (기존 데이터 완벽 보호)
2. **데이터 쿼리 분리**: Discover 피드에서는 `where('visibility', isEqualTo: 'public')` 필터링을 반드시 거치고, '내 OOTD' 피드에서는 기존처럼 `where('userId', isEqualTo: currentUserId)`를 유지합니다.
3. **사용자 DB 동기화**: 앱 로그인/회원가입 시 `users` 컬렉션에 사용자 문서(uid, 이메일 아이디 등)가 존재하는지 확인하고, 없으면 생성하는 로직을 추가합니다.

## 6. 배포 방식 (유지)
```bash
.fvm/flutter_sdk/bin/flutter build web --no-tree-shake-icons && ./firebase_bin deploy --only hosting
```
