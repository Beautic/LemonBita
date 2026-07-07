#!/usr/bin/env bash
# 운영계(prod) 배포 스크립트
set -euo pipefail

echo "⚠️  운영계(PROD)로 배포합니다. 계속하려면 Enter, 취소는 Ctrl+C"
read -r

echo "🏗  Building web (ENV=prod)..."
/Users/a421104/fvm/versions/3.16.9/bin/flutter build web --release --web-renderer canvaskit --dart-define=ENV=prod

echo "🚀 Deploying to PROD hosting..."
npx -y firebase-tools deploy --only hosting -P prod

echo "✅ 운영계 배포 완료: https://digital-closet-32c43.web.app"
