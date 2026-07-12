# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
