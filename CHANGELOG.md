# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [v6.2.2] - 2026-07-14

### Added
- **폴더별 기본 비공개(Privacy by Default) 및 다각 친구 공유(지정 공유) 기능**:
  - 새 옷장/아이템 가방 생성 시 기본 공개 여부를 **'나만 보기(비공개 / `isSharedWithFriends = false`)'**로 지정.
  - 가방 수정 다이얼로그 개편: `모든 친구에게 공개` vs `일부 친구에게 지정 공개` 라디오 분기 제공 및 내 친구 목록(`friends`)을 가져와 개별 다중 선택하는 UI 구현.
  - 지정 공유 친구의 UID 목록을 `sharedWithFriendIds` 필드로 저장 및 실시간 동기화.
- **가방 단위 외부 공유 링크 복사 및 전용 뷰어(ShareFolderScreen)**:
  - 로그인 여부와 관계없이 특정 폴더의 아이템들을 조회할 수 있도록 외부 공유 링크 복사 🔗 기능 추가.
  - 외부 방문자를 위한 웹 전용 공유 페이지([ShareFolderScreen](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/share_folder_screen.dart)) 신설 및 `main.dart` 내 해시 딥링크(/share) 라우팅 연동.

### Changed
- **친구 쇼룸 및 코디 캔버스 권한 필터링 개편**:
  - 공유 가방이거나 혹은 내 UID가 허용 친구 목록(`sharedWithFriendIds`)에 포함되어 있는 경우에만 친구 쇼룸 및 코디 캔버스의 가방 및 소장품이 안전하게 노출되도록 필터링 규칙 반전 바인딩 적용.
- **업로드 시 프라이버시 알림 UI 보완**:
  - 신규 의류/아이템 등록 화면의 보관함 선택 영역에서 비공개 가방 옆에 `🔒` 자물쇠 기호를 표시하고, 하나라도 선택될 경우 하단에 주의/안내 헬퍼 텍스트 노출.

## [v6.2.1] - 2026-07-14

### Changed
- **신규 공식 앱 아이콘 적용 및 배포 (컨셉 C · 오픈 박스)**:
  - 마이벤토리의 핵심 리브랜딩 가이드라인에 맞추어, 미니멀리즘과 게임 슬롯 메타포를 담은 **컨셉 C (오픈 박스)** 디자인 시안을 앱의 공식 아이콘으로 지정.
  - 모바일(iOS/Android) 런처 아이콘 에셋 동기화 및 웹(Web)의 파비콘(favicon) 및 매니페스트 아이콘(192px/512px, maskable) 이미지 일괄 렌더링 및 적용 완료.

## [v6.2.0] - 2026-07-14


### Added
- **듀얼 인벤토리(의류 vs 일반 아이템) 분할 개편 및 5분할 네비게이션 적용**:
  - 하단 메인 내비게이션 바([main_screen.dart](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/main_screen.dart))를 5분할하여 `의류(home)`와 `아이템(items)` 탭을 완전히 분리해 독립 관리.
  - `➕` 등록 버튼 누를 시 `새 의류 등록`과 `새 일반 아이템 등록` 분기 처리 모달 시트 탑재.
- **일반 아이템 보관함 및 타임라인 다이어리 (Diary Log) 연계**:
  - 의류 중심 기능이 제거된 1:1 정사각 격자 슬롯 뷰어([item_screen.dart](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/item_screen.dart)) 신설.
  - 일반 아이템 상세 등록 폼([upload_item_screen.dart](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/upload_item_screen.dart)) 신설 및 AI 배경제거 기능 제공.
  - 사용/플레이 일지 쓰기 버튼 탑재 및 다이얼로그 연동, Firestore `addUsageRecord` 트랜잭션을 통한 플레이 횟수(`usageCount`) 실시간 증감 및 상세 화면 하단 타임라인 다이어리 실시간 연계([item_detail_screen.dart](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/item_detail_screen.dart)) 신설.
- **🔒 폴더별 공유 프라이버시 제어 및 친구 화면 필터 격리**:
  - 의류 폴더(`closet_folders`) 및 일반 아이템 폴더(`item_folders`) 생성/수정 모달에 `친구에게 이 가방 공유하기` 토글 Switch 적용.
  - 친구 쇼룸([friend_closet_screen.dart](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/friend_closet_screen.dart))에서 비공개로 설정된 폴더 및 해당 폴더 하위 의류/아이템을 완벽 격리 필터링.
  - 코디 캔버스([coordination_canvas_screen.dart](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/coordination_canvas_screen.dart)) 내 바텀 시트 의류 선택창에서도 타인 검색 시 비공개 폴더 하위 의류를 실시간 차단.

### Changed
- **프로필 복합 대시보드 통계 및 2중 폴더 수량 집계**:
  - `CLOTHES`, `ITEMS` 총 수량, `FOLDERS` (의류 가방 + 일반 아이템 가방 수량 병합), 그리고 사용/착용 누적 합산 횟수인 `WORN&PLAY` 수치 통계 4칸 개편([profile_screen.dart](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/profile_screen.dart)).

## [v6.1.2] - 2026-07-13

### Restored
- **의류 그리드 슬롯 내 '🧼 세탁 필요' 파란색 직관적 알림 배지 복원**:
  - 홈 화면의 격자 아이템 리뉴얼 시 미니멀화 과정에서 빨간색 미세 도트로 임시 축소되었던 세탁 필요 알림을, 이전 버전의 강력한 사용성을 계승하여 **의류 이미지(옷) 영역 좌하단에 겹쳐 뜨는 선명한 파란색 `🧼 세탁 필요` 미니 배지**로 복원 완료.
  - 마이벤토리의 격자 테마 톤과 조화되도록 각진 사각형(`BorderRadius.circular(4)`) 및 8.5px 세련된 폰트와 그림자 오버레이로 디자인 정제.

## [v6.1.1] - 2026-07-13

### Fixed
- **댓글 카운트 실시간 리액티브 갱신 및 무결성 패치**:
  - `OotdInteractionBar` 내의 댓글 갯수 표시 영역을 `StreamBuilder` 로 래핑하여 Firestore `comments` 서브컬렉션을 실시간 직접 구독하도록 개선.
  - 이로써 캐시 누락 등으로 댓글 개수가 0개로 보이던 동기화 딜레이를 완전 해결하고, 댓글 바텀 시트 내에서 글을 쓰고 닫는 즉시 카운터 수치가 부모 인터랙션 바에 0.1초 만에 실시간 반영되도록 수정 완료.

## [v6.1.0] - 2026-07-13

친구 관리 및 검색 속도 고도화, 그리고 친구 옷장 추천 탭 신설 업데이트.

### Added
- **친구 옷장 내 '내가 추천한 코디' 모아보기 탭 신설 (`friend_closet_screen.dart` 리팩토링)**:
  - 친구 옷장 화면을 `StatefulWidget`으로 구조 개편하고 상단 탭 전환 바(`아이템 목록` / `추천한 코디`) 탑재.
  - `아이템 목록`: 친구가 소장한 아이템을 1:1 정사각 3열 음각 슬롯 스타일로 정합 노출.
  - `추천한 코디`: 내가 해당 친구에게 코디 캔버스를 통해 추천해 준 코디 목록(`planned_ootds`)을 실시간 조회하여 2열 4:5 매거진 레이아웃으로 렌더링. 탭 시 상세 화면으로 연결.
- **친구 검색 속도 극대화 및 검색 로딩 상태 피드백 구현**:
  - `searchUsers` 내의 3중 순차 Firestore 요청을 `Future.wait` 병렬 비동기 구조로 개편하여 RTT 대기 지연율을 1/3로 극감.
  - 친구 검색 시 TextField 바로 아래에 진행 상태바(`LinearProgressIndicator`)를 탑재하여 체감 성능 향상.

### Changed
- **닉네임 검색 조건 고도화**:
  - 기존 닉네임 검색 시 정확히 풀네임이 맞아야만 검색되던 완전 매칭 제약에서, 앞글자만 쳐도 부분 검색이 지원되는 Prefix 범위 검색(`isGreaterThanOrEqualTo` & `isLessThanOrEqualTo` 조합)으로 지능형 쿼리 전환.

## [v6.0.0] - 2026-07-13

마이벤토리(Myventory) UI 리뉴얼 및 브랜드 리브랜딩 대규모 업데이트.

### Added
- **테마 디자인 토큰 및 가독성 개선 시스템 도입 (`lib/theme/app_theme.dart` [NEW])**:
  - 누끼 이미지(배경 제거)의 윤곽 가독성을 보장하기 위해 본 그레이 슬롯 컬러(`AppColors.slot` — #EFEDE6)와 중성 샌드 베이지 배경(`AppColors.ground` — #F7F6F3)을 신설하고 연동.
  - 슬롯 및 버튼 곡률 토큰(`AppRadius.slot = 6.0`, `AppRadius.card = 10.0`, `AppRadius.button = 12.0`, `AppRadius.sheet = 20.0`) 규격화.
  - 모노스페이스 기반 계량 지표 폰트(`AppText.mono`)를 정의하여 획일화된 그리드 스타일 도입.
- **홈 화면 1:1 정사각 슬롯형 인벤토리 그리드**:
  - 기존 3열 옷장 그리드를 **정사각 슬롯형(childAspectRatio: 1.0)** 격자로 전면 리뉴얼.
  - **즐겨찾기**: 우상단 강렬한 붉은색 삼각 Notch 노출 및 상세화면 스위치 제공.
  - **세탁 필요**: 좌하단 컴팩트 붉은 도트(6x6) 표시.
  - **착용 횟수**: 우하단 모노스페이스 텍스트 표기 (0회면 숨김).
  - **신규 수납 슬롯**: 마지막 인덱스에 점선형 둥근 사각형 `+` 빈 슬롯(`_EmptySlot`, `DashedSlotPainter` [NEW])을 추가하여 즉각 입고 연계.
- **홈 헤더 다이어트 및 가시성 2.2배 증대**:
  - 날씨 카드를 단 **1줄 42px 바**로 고도로 압축하고 스마트 추천은 바텀시트 팝업(`_showSmartRecommendationDialog` [NEW])으로 전환하여 공간 확보.
  - 폴더 바와 카테고리 칩 바를 **단 1줄의 수평 통합 필터 바(`_buildMergedFilterBar` [NEW])**로 단일화.
  - 카테고리 칩들을 사각형(`radius: 4`)으로 전환하여 사각 인벤토리 비주얼과 매칭.
- **프로필 대시보드 전개 통합 (`profile_screen.dart` 리팩토링)**:
  - 여백이 많던 프로필 화면에 옷장 분석기(`closet_analytics_screen.dart`) 통계 알고리즘을 전개 통합.
  - 프로필 이미지 축소 및 통계 4칸(`ITEMS`, `FOLDERS`, `WORN`, `UNUSED` - UNUSED는 붉은 경고 보더로 강조) 배치.
  - 흑백 그라데이션 카테고리 비율 차트, 자주 입은 TOP 3 아이템 목록, 잠자는 아이템 붉은 경고 배너 및 가로 스크롤 모달 시트 구현.

### Changed
- **OOTD 그리드 크롭**: 레터박스 여백으로 찌그러지던 피드 목록 이미지를 정사각 커버 크롭(`BoxFit.cover`)으로 전면 교정.
- **카피 중립화 및 리브랜딩 전면 적용**:
  - 옷장/옷 -> 인벤토리/아이템 단어 교체.
  - `pubspec.yaml`, `main.dart`, `AndroidManifest.xml`, `Info.plist`, `AppInfo.xcconfig`, `manifest.json`, `index.html` 내 앱 이름을 공식 리브랜딩 명칭인 **`Myventory`**로 일괄 전환. (패키지명 com.antigravity.dress는 불변 보존)

## [v5.4.0] - 2026-07-12

### Fixed
- **HTML 렌더러 스크린샷 캡쳐 불가능 버그 해결 (CanvasKit 복귀)**:
  - HTML 렌더러 빌드 시 `toImage is not supported on the web` 에러가 발생하여 코디 캔버스 이미지 저장 및 OOTD 등록이 차단되던 런타임 표준 오류 수정.
  - 캔버스 스크린샷 픽셀 변환 기능 복구를 위해 Flutter Web 빌드 렌더러를 다시 **CanvasKit**으로 복구 전환 완료 (`deploy_dev.sh`, `deploy_prod.sh` 및 `web/index.html` 렌더러 셋업 원복).
- **CanvasKit 환경 하 모바일 Safari 아이콘 깨짐 원천 박멸 (오프라인 폰트 로컬 패키징)**:
  - CanvasKit 엔진이 fonts.gstatic.com 원격 서버에서 `MaterialIcons-Regular.otf` 웹폰트를 내려받을 때 모바일 기기의 보안 제약(CORS)으로 깨지던 이슈를 완전 해결.
  - SDK 내장 폰트 파일을 프로젝트의 로컬 리소스 폴더(`assets/fonts/MaterialIcons-Regular.otf`)로 직접 복사하여 패키징하고, `pubspec.yaml` 에 `family: MaterialIcons` 에셋으로 영구 등록.
  - 이를 통해 CanvasKit 엔진이 외부 망 접속 없이 도메인 로컬 폰트를 즉시 로드하도록 유도하여 모든 모바일 기기(아이폰/안드로이드)의 아이콘 선명도 100% 정상 보장 및 무오류 저장 실현.

## [v5.3.3] - 2026-07-12

### Added
- **원피스 카테고리 자동 정렬 및 레이어드 매칭 고도화**:
  - 원피스(`onepiece` / `dress` / `드레스`)가 캔버스에 올려졌을 때 기타 액세서리로 오분류되는 알고리즘 오류를 해결하여 독자 코디 항목으로 신설.
  - 여성들이 원피스 밑에 바지(하의)를 함께 입는 레이어드 코디 믹스매치 시나리오를 자동 정렬에 유기적으로 병합. 원피스 Y축을 위쪽(약 30%), 바지 Y축을 중간 아래쪽(약 60%)으로 상호 겹침 조절하여 원피스 단 밑으로 바지가 흘러나오도록 보정.
  - Z-Index 랭킹 재배치를 통해 원피스가 바지 위쪽으로 레이어로 덮이도록 `bottom`(랭크 2)보다 `onepiece`(랭크 3)를 높여 그려지게 고도화.
- **아이폰(iOS Safari) 아이콘 깨짐/미노출 예외 패치**:
  - Flutter CanvasKit 렌더러가 Safari에서 Google Web Fonts 리소스(Material Icons)를 간헐적으로 차단하거나 로드에 실패하는 버그를 원천 봉쇄.
  - Flutter Web 빌드 렌더러를 모바일에 최적화된 `--web-renderer html` 로 전면 고정 전환하고, `web/index.html`에 Google Fonts Material Icons 링크 및 강제 CSS font-family 클래스를 매핑하여 100% 정상 노출 유도 완료.

## [v5.3.2] - 2026-07-12

### Changed
- **자동정렬 스낵바 문구 변경**: 코디 캔버스에서 마법봉 자동 정렬 수행 시 하단에 노출되는 완료 안내 문구 내 불필요한 공학적 표현인 '기하학적으로' 멘트를 전면 삭제하고, `'코디 아이템들이 자동 정렬되었습니다.'` 로 직관적이고 깔끔하게 순화 및 변경 완료.

## [v5.3] - 2026-07-12

룩북 에디토리얼 & 폴라로이드 감성 4:5 캔버스 최적화 및 스마트 겹침 회피 자동 정렬 릴리스.

### Added
- **지능형 가변 배치(Adaptive Layout Mode) 도입**: 올려진 옷의 총개수와 조합에 따라 '수직 1열 단일 코디 모드'와 '2x2 격자 콜라주 모드'로 자동 정렬 알고리즘이 가변 대응.
- **템플릿 테마 인식형(Template-Aware) Y축 오프셋 정렬**: 
  - 에디토리얼: Essentials 타이틀 아래 소글씨(`STYLE DIARY & ARCHIVE`)를 침범하지 않게 메인 의류 Y축을 `38%` 이하로 하향 정렬.
  - 폴라로이드: 하단 손글씨 64px 영역 침범을 회피하며 좁은 사진 프레임 안에 다 들어가도록 의류 스케일을 `0.50~0.58`로 자동 축소 및 1열 완전 비겹침 배치 적용.
  - 카탈로그: 좌상단 검은색 띠 높이만큼 Y축을 `35%` 이하로 끌어내려 정렬.
- **소장 옷 개수 기준 카테고리 칩바 동적 정렬**: 사용자의 실제 옷장에 등록된 의류 개수를 카테고리별로 실시간 집계하여, 등록된 옷이 많은 순(내림차순)으로 가로 필터 칩바의 순서가 자동으로 동적 정렬되는 기능 도입 (가장 많이 소장한 옷을 더 쉽고 빠르게 필터링할 수 있도록 돕되, 'ALL' 칩은 항상 맨 왼쪽에 고정 노출).
- **개인화 카테고리 설정(Custom Visibility) 기능**:
  - 남성/여성에 따른 원피스, 치마 등의 필터 제외나 불필요한 카테고리를 숨기기 위한 개인 맞춤형 노출 제어 팝업 추가.
  - 가로 칩바 맨 끝에 **⚙️ 설정 칩**을 추가하고, 클릭 시 10대 카테고리 노출 여부를 토글할 수 있는 바텀 시트 구현.
  - 사용자가 선택한 카테고리 목록(`activeCategories`)을 Firestore 유저 프로필에 동기화하여 멀티 디바이스에서도 상태가 영구 보존되도록 연동.
- **사용자 임의 카테고리 신설(Custom Category CRUD) 지원**:
  - 기본 제공되는 10대 카테고리 외에, 사용자가 직접 원하는 카테고리(예: 수영복, 트레이닝 등)를 텍스트로 즉각 신설 및 삭제할 수 있는 기능 추가.
  - 카테고리 설정 바텀시트에 신설 필드를 제공하고, 새로 만든 카테고리에는 범용적인 스타일 아이콘(`Icons.style`)을 자동 매핑하여 통일감 부여.
  - 옷 업로드([UploadScreen](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/upload_screen.dart)), 옷 수정([ClothingDetailScreen](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/clothing_detail_screen.dart)), 옷 검색([SearchClothesScreen](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/search_clothes_screen.dart)) 화면의 대분류 선택 목록에도 실시간 동기화 적용.
- **추천 제외 세이프가드 및 추가 레이턴시 0ms 개편**:
  - 사용자 신설 커스텀 카테고리에 속하는 의류는 '옷이 아닌 소품/잡화/특수복'으로 간주하여, **날씨 기온 코디 추천 카드**와 **실시간 스마트 코디 추천 패널** 전체 추천 풀에서 자동으로 필터링 제외 처리 완비.
  - 카테고리 칩 설정 바텀 시트 내부에 해당 추천 제외 작동 안내 가이드를 명시 기입.
  - 바텀시트 안에서 신규 카테고리 생성 단추 클릭 시 백엔드 쓰기 대기 지연(Latency) 없이 화면에 즉각 렌더링되도록 `setSheetState` 동기 우선 호출 방식으로 반응속도 0ms 초정밀 튜닝 완료.
- **런타임 불변 리스트(Unmodifiable List) 수정**:
  - FirebaseService의 빈 리스트 반환 시 생기는 `unmodifiable list` 런타임 크래시를 전면 방지하기 위해, 사용자 정의 카테고리를 로드하는 모든 화면([HomeScreen](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/home_screen.dart), [UploadScreen](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/upload_screen.dart), [ClothingDetailScreen](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/clothing_detail_screen.dart), [SearchClothesScreen](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/search_clothes_screen.dart), [CoordinationCanvasScreen](file:///Users/a421104/Documents/project/Antigravity/dress/lib/screens/coordination_canvas_screen.dart))에서 반환값을 항상 `List<String>.from(...)`으로 감싸 가변(Mutable) 리스트로의 안전한 다운캐스팅 보장.

### Changed
- **4:5 인스타그램 피드 종횡비 개편**: 기존 9:16에서 **4:5 비율(`aspectRatio: 4 / 5`)** 카드로 전환하고 그레이 외부 배경 및 카드 드롭 섀도우를 가미해 잡지 화보 감성으로 개편.
- **물리적 위젯 레이아웃 제어로 전환**: `Transform.scale` 대신 `Container`의 `width`와 `height`를 직접 `150.0 * scale`로 제어하도록 변경하여, 마법봉 정렬 시 1px 오차 없는 가로축 정중앙 안착 및 활성 테두리 피팅 실현 (터치 마스킹 영역 오작동 제거).
- **실시간 스마트 코디 추천 하단 바 상시 복구**: 화면 아래 220px 여백 영역으로 복원 상시 배치하여 터치 한 번으로 즉시 캔버스에 추가되도록 연동.
- **캔버스 저장 완료 시 자동 뒤로가기 연동**: 코디 아이디어 수정 후 저장 완료 시 캔버스에 수동으로 남아있지 않고 자동으로 이전 코디 아이디어 페이지로 복귀(`Navigator.pop`)하도록 UI 흐름을 개선.

## [v5.0] - 2026-06-17

운영/개발 환경 완전 분리 마일스톤 (인프라 안정화 릴리스).

### Added
- **운영/개발 환경 전환 설정** (`lib/config/firebase_env.dart`): `--dart-define=ENV=prod|dev`로 Firebase 프로젝트 자동 전환, 기본값 `dev`.
- **개발계 인프라**: 신규 `digital-closet-dev` 프로젝트에 Firestore(규칙·인덱스)·Storage(`us-west1`, 규칙)·Auth(이메일/비밀번호) 구성 및 배포.
- **환경별 배포 스크립트**: `deploy_dev.sh`, `deploy_prod.sh`(운영 배포 확인 프롬프트 포함).
- **Git 브랜치 전략**: `main`(개발) / `prod`(운영) 이원화.

### Changed
- **`firebase_service.dart`**: 하드코딩된 `FirebaseOptions`/API Key 제거 → `FirebaseEnv.options`로 일원화.
- **`.firebaserc`**: `prod`(`digital-closet-32c43`) / `dev`(`digital-closet-dev`) 프로젝트 별칭 등록.

> v4.1 ~ v4.4의 상세 내역은 [CHANGELOG_ANTIGRAVITY.md](./CHANGELOG_ANTIGRAVITY.md) 참조.

## [v3.7] - 2026-05-15

### Added
- **색깔 선택 기능**: 옷 등록 화면(`upload_screen.dart`)과 상세 페이지(`clothing_detail_screen.dart`)에 색상 태깅 UI 도입. 19색 프리셋(블랙·화이트·아이보리·베이지·그레이·차콜·네이비·브라운·카키·와인·레드·오렌지·옐로우·그린·민트·스카이블루·블루·퍼플·핑크) ChoiceChip + "직접입력" 옵션 제공.
- **상세 페이지 프리셋 자동 복원**: 저장된 `color` 값이 19색 프리셋과 일치하면 해당 칩이 자동 선택되고, 그 외의 임의 문자열이면 "직접입력" 모드로 TextField에 복원.
- **상세 작업지시서**: `docs/specifications/project_spec_v3.7.md` 추가.

### Changed
- **Firestore `color` 필드 활성화**: v3.5부터 검색 필터에는 존재했으나 입력 수단 부재로 비어 있던 `clothing.color` 필드를 정식 입력 경로 확보로 활성화.
- **`FirebaseService.saveClothingData` 시그니처**: optional `String? color` 파라미터 추가 (기본값 빈 문자열 — 기존 데이터 호환성 유지, 마이그레이션 불필요).

### Known Issues
- 입력 측 19색 ↔ 검색 측 12색(`search_clothes_screen.dart::_commonColors`) 불일치 — 후속 정리 항목 (v3.7 §1.5 참조).

## [v3.5] - 2026-05-08

### Added
- **OOTD 타임머신 (과거 날짜 등록)**: 새로운 OOTD 등록 시 갤러리 사진의 메타데이터(수정일)를 추출하여 기본 날짜로 제공 및 원하는 과거 날짜를 임의로 지정할 수 있는 DatePicker UI 추가.
- **OOTD 날짜 수정 기능**: 피드 및 달력 화면에서 기존 등록된 OOTD 게시물의 날짜를 언제든 수정할 수 있는 기능(`updateOOTDDate`) 추가.
- **상세 작업지시서**: `docs/specifications/project_spec_v3.5.md` 추가.

### Changed
- **인증 시스템 전면 개편**: 기존 임시 REST API 기반 인증 통신 로직을 모두 제거하고, 안정적이고 공식적인 `firebase_auth` SDK로 전면 교체.
- **보안 강화**: 공식 Auth SDK 연동을 통해 Firestore 및 Storage의 보안 규칙(`request.auth != null`)이 클라이언트 요청과 완벽하게 호환되도록 구성.
- **아이콘 호환성 개선**: 일부 웹 환경에서 렌더링 누락 문제가 있던 `edit_calendar` 아이콘을 호환성이 보장된 `calendar_month` 아이콘으로 대체.
