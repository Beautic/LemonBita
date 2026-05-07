# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [v3.5] - 2026-05-08

### Added
- **OOTD 타임머신 (과거 날짜 등록)**: 새로운 OOTD 등록 시 갤러리 사진의 메타데이터(수정일)를 추출하여 기본 날짜로 제공 및 원하는 과거 날짜를 임의로 지정할 수 있는 DatePicker UI 추가.
- **OOTD 날짜 수정 기능**: 피드 및 달력 화면에서 기존 등록된 OOTD 게시물의 날짜를 언제든 수정할 수 있는 기능(`updateOOTDDate`) 추가.
- **상세 작업지시서**: `docs/specifications/project_spec_v3.5.md` 추가.

### Changed
- **인증 시스템 전면 개편**: 기존 임시 REST API 기반 인증 통신 로직을 모두 제거하고, 안정적이고 공식적인 `firebase_auth` SDK로 전면 교체.
- **보안 강화**: 공식 Auth SDK 연동을 통해 Firestore 및 Storage의 보안 규칙(`request.auth != null`)이 클라이언트 요청과 완벽하게 호환되도록 구성.
- **아이콘 호환성 개선**: 일부 웹 환경에서 렌더링 누락 문제가 있던 `edit_calendar` 아이콘을 호환성이 보장된 `calendar_month` 아이콘으로 대체.
