#!/usr/bin/env bash
# 핵심 기능 회귀 감시 스크립트
# Antigravity(또는 다른 AI/사람)가 코드를 수정한 후 핵심 기능이 깨지지 않았는지 확인.
# git pre-commit hook으로 자동 실행되며, 실패 시 commit이 차단됨.
#
# 수동 실행: ./scripts/check_critical_features.sh

set -u

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RESET=$'\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

PASS_COUNT=0
FAIL_COUNT=0
FAILURES=()

check() {
  local name="$1"
  local result="$2"
  local detail="${3:-}"
  if [ "$result" = "true" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  ${GREEN}✓${RESET} %s\n" "$name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAILURES+=("$name${detail:+ — $detail}")
    printf "  ${RED}✗${RESET} %s\n" "$name"
    if [ -n "$detail" ]; then
      printf "    ${YELLOW}→ %s${RESET}\n" "$detail"
    fi
  fi
}

file_exists() {
  if [ -f "$1" ]; then echo "true"; else echo "false"; fi
}

# grep 정규식 검사 (파일이 없거나 패턴이 없으면 false)
has_pattern() {
  local file="$1"
  local pattern="$2"
  if [ -f "$file" ] && grep -qE "$pattern" "$file" 2>/dev/null; then
    echo "true"
  else
    echo "false"
  fi
}

# 함수 블록 내부에 특정 키워드가 있는지
# 함수 시작 라인부터 정확히 "  }" (인덴트 2칸 + 닫는 중괄호만) 끝나는 라인까지.
# "  }) async {" 같은 시그니처 줄은 종료로 매칭되지 않음.
has_in_function() {
  local file="$1"
  local func_pattern="$2"
  local keyword="$3"
  if [ ! -f "$file" ]; then echo "false"; return; fi
  if awk "/${func_pattern}/,/^  \\}[[:space:]]*$/" "$file" 2>/dev/null | grep -qF "$keyword"; then
    echo "true"
  else
    echo "false"
  fi
}

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Digital Closet 핵심 기능 회귀 검사"
echo "════════════════════════════════════════════════════════════"

# ─── 1. 인증 영속화 ───────────────────────────────────────────
echo ""
echo "[1/8] 인증 영속화 (SharedPreferences)"

FBS="lib/services/firebase_service.dart"
check "firebase_service.dart 존재" "$(file_exists $FBS)"
check "shared_preferences import" "$(has_pattern $FBS 'shared_preferences')"
check "_persistSession 메서드 존재" "$(has_pattern $FBS '_persistSession')"
check "_restoreSession 메서드 존재" "$(has_pattern $FBS '_restoreSession')"
check "_clearSession 메서드 존재" "$(has_pattern $FBS '_clearSession')"
check "initialize에서 세션 복원 호출" "$(has_pattern $FBS 'await _restoreSession')"
check "signUpWithEmail에서 세션 저장" "$(has_in_function $FBS 'signUpWithEmail' '_persistSession')" "회원가입 후 토큰을 디스크에 저장해야 함"
check "loginWithEmail에서 세션 저장" "$(has_in_function $FBS 'loginWithEmail' '_persistSession')" "로그인 후 토큰을 디스크에 저장해야 함"
check "logout에서 세션 삭제" "$(has_in_function $FBS 'Future<void> logout' '_clearSession')" "로그아웃 시 디스크 토큰을 삭제해야 함"

# ─── 2. 이미지 다운사이즈 ─────────────────────────────────────
echo ""
echo "[2/8] 이미지 다운사이즈 (Firebase 용량 절약)"

UPL="lib/screens/upload_screen.dart"
check "upload_screen.dart 존재" "$(file_exists $UPL)"
check "maxWidth 옵션 사용" "$(has_pattern $UPL 'maxWidth:')" "image_picker에서 리사이즈 옵션이 빠지면 원본 풀사이즈가 업로드됨"
check "maxHeight 옵션 사용" "$(has_pattern $UPL 'maxHeight:')"
check "imageQuality 옵션 사용" "$(has_pattern $UPL 'imageQuality:')"

# ─── 3. Firestore 쿼리 ───────────────────────────────────────
echo ""
echo "[3/8] Firestore 옷 조회 쿼리"

check "getClothesStream 메서드 존재" "$(has_pattern $FBS 'getClothesStream')"
check "userId 필터 (where)" "$(has_pattern $FBS 'where.*userId')" "이걸 빼면 모든 사용자의 옷이 섞여 보임"
check "createdAt 정렬 (orderBy)" "$(has_pattern $FBS 'orderBy.*createdAt')" "이걸 빼면 최신순 정렬이 깨짐"
check "saveClothingData 메서드 존재" "$(has_pattern $FBS 'saveClothingData')"
check "저장 시 userId 포함" "$(has_in_function $FBS 'saveClothingData' 'userId')"
check "저장 시 createdAt 포함" "$(has_in_function $FBS 'saveClothingData' 'createdAt')"

# ─── 4. HomeScreen StreamBuilder ───────────────────────────
echo ""
echo "[4/8] HomeScreen StreamBuilder 안정성"

HOME="lib/screens/home_screen.dart"
check "home_screen.dart 존재" "$(file_exists $HOME)"
check "snapshot.hasError 체크" "$(has_pattern $HOME 'snapshot\.hasError')" "이게 없으면 Firestore 에러가 빈 화면으로 표시됨"
check "스트림 캐싱 (late final Stream)" "$(has_pattern $HOME 'late final Stream')" "이게 없으면 build()마다 새 스트림 생성됨"
check "initState에서 스트림 초기화" "$(has_in_function $HOME 'void initState' 'getClothesStream')"

# ─── 5. Firestore 복합 인덱스 ─────────────────────────────────
echo ""
echo "[5/8] Firestore 복합 인덱스 정의"

IDX="firestore.indexes.json"
check "firestore.indexes.json 존재" "$(file_exists $IDX)"
check "clothes 컬렉션 인덱스" "$(has_pattern $IDX 'clothes')"
check "userId 필드" "$(has_pattern $IDX 'userId')"
check "createdAt 필드" "$(has_pattern $IDX 'createdAt')"
check "ASCENDING 방향" "$(has_pattern $IDX 'ASCENDING')"
check "DESCENDING 방향" "$(has_pattern $IDX 'DESCENDING')"

# ─── 6. firebase.json (Hosting 최적화) ────────────────────────
echo ""
echo "[6/8] firebase.json 설정"

FBJ="firebase.json"
check "firebase.json 존재" "$(file_exists $FBJ)"
check "firestore indexes 참조" "$(has_pattern $FBJ 'firestore.indexes.json')"
check "hosting Cache-Control 헤더" "$(has_pattern $FBJ 'Cache-Control')" "이게 없으면 재방문 시에도 풀 다운로드 발생"
check "canvaskit ignore" "$(has_pattern $FBJ 'canvaskit')" "canvaskit이 deploy되면 호스팅 용량 15MB 추가됨"

# ─── 7. HTML 렌더러 강제 ───────────────────────────────────────
echo ""
echo "[7/8] Flutter 웹 HTML 렌더러"

WEB_INDEX="web/index.html"
check "web/index.html 존재" "$(file_exists $WEB_INDEX)"
check "renderer: html 명시" "$(has_pattern $WEB_INDEX 'renderer.*html')" "이게 없으면 데스크톱 브라우저는 canvaskit(15MB)을 다운로드함"

# ─── 8. pubspec 의존성 ────────────────────────────────────────
echo ""
echo "[8/8] pubspec.yaml 의존성"

PUB="pubspec.yaml"
check "pubspec.yaml 존재" "$(file_exists $PUB)"
check "shared_preferences 의존성" "$(has_pattern $PUB 'shared_preferences')"
check "image_picker 의존성" "$(has_pattern $PUB 'image_picker')"
check "cloud_firestore 의존성" "$(has_pattern $PUB 'cloud_firestore')"
check "firebase_storage 의존성" "$(has_pattern $PUB 'firebase_storage')"

# ─── 결과 요약 ──────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "$FAIL_COUNT" -eq 0 ]; then
  printf "  ${GREEN}✓ 통과: %d/%d${RESET}\n" "$PASS_COUNT" "$TOTAL"
  echo "  핵심 기능 모두 정상."
  echo "════════════════════════════════════════════════════════════"
  exit 0
else
  printf "  ${RED}✗ 실패: %d/%d${RESET}\n" "$FAIL_COUNT" "$TOTAL"
  echo ""
  echo "  깨진 기능:"
  for f in "${FAILURES[@]}"; do
    printf "    ${RED}•${RESET} %s\n" "$f"
  done
  echo "════════════════════════════════════════════════════════════"
  exit 1
fi
