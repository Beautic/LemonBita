# My Digital Closet (Antigravity)

이 프로젝트는 나만의 디지털 옷장을 구축하고, 친구들과 코디 아이디어를 주고받을 수 있는 마이크로 소셜 네트워크 앱입니다. 

## 프로젝트 특징
- **옷장 관리**: 옷 사진을 올리면 자동으로 배경(누끼)을 제거하고 정사각형으로 깔끔하게 저장합니다.
- **OOTD 기록**: 오늘의 착장(OOTD)을 달력과 피드로 관리할 수 있습니다.
- **코디 캔버스**: 등록된 옷들을 자유롭게 배치하여 코디 아이디어를 만들어보고 공유할 수 있습니다.
- **마이크로 소셜**: 친구들과 옷장과 코디 피드를 공유하고 좋아요, 대댓글을 통해 소통할 수 있습니다.

## 업데이트 히스토리 (작업지시서 내역)
자세한 변경 내역과 버전 별 상세 작업 내용은 [CHANGELOG_ANTIGRAVITY.md](./CHANGELOG_ANTIGRAVITY.md) 파일에서 확인하실 수 있습니다.

## 최신 업데이트 (v5.0) — 운영/개발 환경 분리 🚀
이번 버전은 기능 추가가 아닌 **인프라 안정화 마일스톤**입니다. 운영 서비스와 개발/테스트를 데이터까지 완전히 분리하여, 이제 안심하고 개발·테스트할 수 있는 기반을 마련했습니다.

- **운영(prod) / 개발(dev) Firebase 프로젝트 완전 분리**: `--dart-define=ENV=prod|dev` 한 줄로 접속 프로젝트가 자동 전환됩니다. 기본값은 `dev`라서 로컬 `flutter run` 시 실수로 운영 데이터를 건드릴 일이 없습니다. (`lib/config/firebase_env.dart`)
- **개발 전용 인프라 신설**: 신규 `digital-closet-dev` 프로젝트에 Firestore·Storage·Authentication(이메일/비밀번호)을 별도로 구성하고 보안 규칙·인덱스를 배포했습니다. 개발 데이터가 운영에 전혀 닿지 않습니다.
- **환경별 배포 스크립트**: `deploy_dev.sh` / `deploy_prod.sh`로 빌드부터 배포까지 한 번에 처리합니다. (운영 배포는 실수 방지용 확인 프롬프트 포함)
- **민감 설정 정리**: `firebase_service.dart`에 하드코딩돼 있던 Firebase 옵션을 제거하고 환경 설정(`FirebaseEnv`)으로 일원화했습니다.

## 환경 및 배포
| 환경 | 브랜치 | Firebase 프로젝트 | 접속 링크 |
|---|---|---|---|
| 🟢 개발(dev) | `main` | `digital-closet-dev` | https://digital-closet-dev.web.app |
| 🔴 운영(prod) | `prod` | `digital-closet-32c43` | https://digital-closet-32c43.web.app |

### 🔑 개발계 테스트용 공용 계정
개발(dev) 환경 검증을 위한 공용 테스트 계정 정보입니다.
* **이메일**: `test@gmail.com`
* **비밀번호**: `test123`


```bash
# 개발: main 브랜치에서 작업 → 커밋 → 개발계 배포 후 dev 링크에서 검증
./deploy_dev.sh

# 운영 반영: 검증이 끝나면 main → prod 머지 후 운영 배포
git checkout prod && git merge main && git push
./deploy_prod.sh
```

> 직전 버전(v4.4) 이하의 상세 변경 내역은 [CHANGELOG_ANTIGRAVITY.md](./CHANGELOG_ANTIGRAVITY.md)를 참고하세요.

