#!/usr/bin/env bash
# 개발계(dev) 배포 스크립트
set -euo pipefail

echo "🏗  Building web (ENV=dev)..."
flutter build web --release --dart-define=ENV=dev

echo "🚀 Deploying to DEV hosting..."
npx -y firebase-tools deploy --only hosting -P dev

echo "✅ 개발계 배포 완료"
