# [태스크] 나만의 인터넷 옷장 개발

## 1단계: 프로젝트 환경 설정
- [x] 기본 디렉토리 구조 생성 (src, docs, data, hooks, skills)
- [x] Python 가상 환경(`uv`) 초기화 및 백엔드 의존성 설치
- [x] 초기 구현 계획서(`implementation_plan.md`) 및 태스크 리스트(`task.md`) 작성

## 2단계: Firebase 연동 및 설정
- [ ] Firebase 프로젝트 구성 로직 구현 (`src/firebase/config.js`)
- [ ] Firestore 데이터 모델링 및 Storage 버킷 연결
- [ ] `skills` 폴더에 Firebase CRUD 핵심 로직 작성

## 3단계: 핵심 기능 개발
- [ ] 카메라 연동 (Mobile Browser API) 기능 개발 (`src/hooks/useCamera.js`)
- [ ] 이미지 업로드 및 리사이징 스킬 개발 (`src/skills/imageProcessor.js`)
- [ ] 옷장 목록 그리드 뷰 구현 (`src/components/ClosetGrid.js`)

## 4단계: 디자인 및 폴리싱
- [ ] Vanilla CSS 기반 프리미엄 다크 모드 테마 적용
- [ ] 부드러운 애니메이션 및 트랜지션 추가
- [ ] 모바일 최적화 레이아웃 검증

## 5단계: 최종 배포 및 검증
- [ ] 전체 기능 테스트 (사진 촬영 -> 저장 -> 조회)
- [ ] 최종 결과물(`walkthrough.md`) 작성
