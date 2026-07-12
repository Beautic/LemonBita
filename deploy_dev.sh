#!/usr/bin/env bash
# 개발계(dev) 배포 스크립트
set -euo pipefail

echo "🏗  Building web (ENV=dev)..."
/Users/a421104/fvm/versions/3.16.9/bin/flutter build web --release --web-renderer canvaskit --dart-define=ENV=dev --no-tree-shake-icons

echo "🚀 Deploying to DEV hosting..."
npx -y firebase-tools deploy --only hosting,firestore,storage -P dev

echo "✅ 개발계 배포 완료"
