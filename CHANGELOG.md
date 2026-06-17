# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
