#!/bin/bash
#
# install-claude-npm.sh
# =====================================================================
# 목적
#   Claude Code를 "npm 방식"으로 설치/업데이트한다.
#   (standalone 설치 방식 대신 npm 사용 — standalone은 버전 관리가
#    불투명해서 npm으로 통일했다.)
#   npm으로 설치되는 claude 바이너리는 standalone과 "동일한 네이티브
#   바이너리"이며, Node는 설치/업데이트 관리용으로만 필요하다.
#   (claude 실행 자체는 Node에 의존하지 않는다.)
#
# 지원 OS (둘 중 하나에서만 동작, 그 외는 즉시 종료)
#   - macOS  : Node를 Homebrew로 설치 (기준 머신 구조 참조)
#   - Ubuntu : Node를 nvm으로 설치 (sudo 불필요, 유저 로컬)
#
# 동작 (6단계)
#   1) OS 감지            : macOS / Ubuntu 판별, 그 외 거부
#   2) Node.js / npm 확보 : 없을 때만 설치 (mac=brew, ubuntu=nvm + curl)
#   3) Claude Code 설치   : npm install -g @anthropic-ai/claude-code@latest
#                          (sudo 사용 안 함 — 공식 권고)
#   4) standalone 정리    : 기존 standalone 설치가 있으면 제거
#                          (~/.local/bin/claude, ~/.local/share/claude/versions)
#                          없으면 스킵 → 신규 설치 / 마이그레이션 모두 커버
#   5) 쉘 프로필 설정     : npm global bin을 PATH에 추가(필요시, 마커 블록)
#                          ※ alias(cc/ca)는 bootstrap-claude-instance.sh가 관리
#   6) 검증              : claude 경로/버전 확인, standalone 경로가 아닌지 확인
#
# 멱등성 (여러 번 실행해도 안전)
#   - 재실행 시 Node / standalone / 프로필 단계는 이미 처리됐으면 스킵하고,
#     Claude Code는 매번 @latest로 갱신된다.
#   - 따라서 이 스크립트는 "설치 + 업데이트" 겸용으로 반복 실행해도 무방하다.
#
# 보존
#   - 설정 디렉터리(~/.claude)는 절대 건드리지 않는다.
#
# 사용법
#   chmod +x install-claude-npm.sh
#   ./install-claude-npm.sh
#   # 완료 후: 새 터미널을 열거나  source ~/.zshrc (또는 ~/.bashrc)
#
# 참고
#   - sudo npm install -g 는 쓰지 않는다 (권한/보안 문제, 공식 권고).
#   - PATH는 새 쉘/프로필 source 이후 적용. alias(cc/ca)는 bootstrap 스크립트 담당.
# =====================================================================

set -e

echo "================================================="
echo " Claude Code: npm 설치 (최신 버전)"
echo " 지원 OS: macOS / Ubuntu"
echo " standalone 설치가 있으면 자동으로 정리하고 npm으로 통일"
echo "================================================="
echo ""

# ---------------------------------------------------------------
# 1. OS 감지
# ---------------------------------------------------------------
echo "[1/6] OS 감지 중..."

case "$(uname -s)" in
    Darwin*)
        OS="macos"
        ;;
    Linux*)
        if command -v apt-get &>/dev/null; then
            OS="ubuntu"
        else
            echo "  ✗ apt 기반 Linux(Ubuntu)가 아닙니다."
            echo "    이 스크립트는 macOS 또는 Ubuntu에서만 동작합니다."
            exit 1
        fi
        ;;
    *)
        echo "  ✗ 지원하지 않는 OS: $(uname -s)"
        echo "    이 스크립트는 macOS 또는 Ubuntu에서만 동작합니다."
        exit 1
        ;;
esac
echo "  ✓ 감지된 OS: ${OS}"
echo ""

# ---------------------------------------------------------------
# 2. Node.js / npm 확인 및 설치
#    - macOS : Homebrew (이 머신 구조 참조)
#    - Ubuntu: nvm (sudo 불필요, 유저 로컬)
# ---------------------------------------------------------------
echo "[2/6] Node.js / npm 확인 중..."

if command -v node &>/dev/null && command -v npm &>/dev/null; then
    echo "  ✓ Node.js $(node --version) / npm $(npm --version) 감지"
else
    echo "  Node.js 또는 npm이 없습니다. 설치를 진행합니다..."

    if [ "$OS" = "macos" ]; then
        # macOS: 이 머신처럼 Homebrew로 Node 설치
        if command -v brew &>/dev/null; then
            echo "  Homebrew로 Node.js 설치 중..."
            brew install node
        else
            echo "  ✗ Homebrew가 없습니다. 먼저 Homebrew를 설치한 뒤 다시 실행하세요:"
            echo '    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            exit 1
        fi
    else
        # Ubuntu: nvm로 Node 설치 (curl 선행 필요)
        if ! command -v curl &>/dev/null; then
            echo "  curl이 없습니다. apt로 설치합니다..."
            if [ "$(id -u)" -eq 0 ]; then
                SUDO=""
            elif command -v sudo &>/dev/null; then
                SUDO="sudo"
            else
                echo "  ✗ curl 설치에 root 또는 sudo 권한이 필요합니다."
                exit 1
            fi
            $SUDO apt-get update -y
            $SUDO apt-get install -y curl
        fi

        export NVM_DIR="$HOME/.nvm"
        if [ ! -d "$NVM_DIR" ]; then
            echo "  nvm 설치 중..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        fi
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

        echo "  Node.js v20 LTS 설치 중..."
        nvm install 20
        nvm use 20
        nvm alias default 20
    fi

    echo "  ✓ Node.js $(node --version) / npm $(npm --version) 설치 완료"
fi

# Ubuntu에서 nvm로 설치했다면 현재 쉘에서도 node/npm 사용 가능하도록 로드
if [ "$OS" = "ubuntu" ]; then
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
fi
echo ""

# ---------------------------------------------------------------
# 3. npm으로 Claude Code 최신 버전 설치 (sudo 사용 안 함)
# ---------------------------------------------------------------
echo "[3/6] npm으로 Claude Code 최신 버전 설치 중..."
if command -v claude &>/dev/null; then
    echo "  이미 claude가 설치돼 있습니다 ($(claude --version 2>/dev/null || echo 'version unknown'))."
    echo "  최신 버전으로 업데이트합니다..."
fi
npm install -g @anthropic-ai/claude-code@latest
echo "  ✓ 설치 완료"
echo ""

# ---------------------------------------------------------------
# 4. 기존 standalone 설치 정리 (있으면 제거 — 없으면 스킵)
#    설정(~/.claude)은 절대 건드리지 않음
# ---------------------------------------------------------------
echo "[4/6] 기존 standalone 설치 정리 중..."

STANDALONE_LINK="$HOME/.local/bin/claude"
if [ -L "$STANDALONE_LINK" ] || [ -e "$STANDALONE_LINK" ]; then
    rm -f "$STANDALONE_LINK"
    echo "  ✓ standalone 링크/파일 제거: ${STANDALONE_LINK}"
else
    echo "  - standalone 링크 없음 (스킵)"
fi

STANDALONE_DIR="$HOME/.local/share/claude"
if [ -d "$STANDALONE_DIR/versions" ]; then
    VERSIONS=$(ls "$STANDALONE_DIR/versions/" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    echo "  삭제 대상 standalone 버전: ${VERSIONS}"
    rm -rf "$STANDALONE_DIR/versions"
    rmdir "$STANDALONE_DIR" 2>/dev/null \
        && echo "  ✓ standalone 디렉터리 제거: ${STANDALONE_DIR}" \
        || echo "  - ${STANDALONE_DIR}에 다른 파일이 있어 versions만 제거"
else
    echo "  - standalone 설치 파일 없음 (스킵)"
fi

# 명령어 해시 캐시 초기화 (이전 standalone 경로 캐시로 인한 오인식 방지)
hash -r 2>/dev/null || true
echo ""

# ---------------------------------------------------------------
# 5. 쉘 프로필 PATH 설정 (alias는 bootstrap-claude-instance.sh가 관리)
# ---------------------------------------------------------------
echo "[5/6] 쉘 프로필 PATH 설정..."
NPM_BIN_DIR="$(npm prefix -g)/bin"

# 쉘에 맞는 프로필 파일 결정 (SHELL 미설정 시 OS 기본값)
case "$(basename "${SHELL:-}")" in
    zsh)  PROFILE="$HOME/.zshrc" ;;
    bash) PROFILE="$HOME/.bashrc" ;;
    *)
        if [ "$OS" = "macos" ]; then
            PROFILE="$HOME/.zshrc"
        else
            PROFILE="$HOME/.bashrc"
        fi
        ;;
esac

if echo ":$PATH:" | grep -q ":${NPM_BIN_DIR}:"; then
    echo "  ✓ npm global bin이 이미 PATH에 있음: ${NPM_BIN_DIR}"
else
    MARKER_BEGIN="# >>> Claude Code PATH (install-claude-npm.sh) >>>"
    MARKER_END="# <<< Claude Code PATH (install-claude-npm.sh) <<<"
    if grep -qsF "$MARKER_BEGIN" "$PROFILE"; then
        echo "  - ${PROFILE}에 PATH 블록이 이미 있음 (스킵)"
    else
        {
            echo ""
            echo "$MARKER_BEGIN"
            echo "export PATH=\"${NPM_BIN_DIR}:\$PATH\""
            echo "$MARKER_END"
        } >> "$PROFILE"
        echo "  ✓ ${PROFILE}에 PATH 추가 완료"
    fi
    # 현재 실행 세션에도 즉시 반영
    export PATH="${NPM_BIN_DIR}:$PATH"
fi
echo ""

# ---------------------------------------------------------------
# 6. 검증
# ---------------------------------------------------------------
echo "[6/6] 설치 검증 중..."
hash -r 2>/dev/null || true

CLAUDE_PATH=$(command -v claude 2>/dev/null || true)
if [ -z "$CLAUDE_PATH" ]; then
    echo "  ✗ claude 명령어를 찾을 수 없습니다!"
    echo "    새 터미널을 열거나 아래를 실행한 뒤 다시 확인하세요:"
    echo "    export PATH=\"${NPM_BIN_DIR}:\$PATH\""
    exit 1
fi

# standalone 경로가 아닌지 확인
if echo "$CLAUDE_PATH" | grep -q "\.local/share/claude"; then
    echo "  ⚠ 경고: 아직 standalone 경로를 가리키고 있습니다!"
    echo "    새 터미널을 열거나 'hash -r' 실행 후 다시 확인하세요."
    exit 1
fi

echo "  ✓ claude 경로: ${CLAUDE_PATH}"
echo "  ✓ claude 버전: $(claude --version 2>/dev/null || echo 'version unknown')"
echo ""

echo "================================================="
echo " 설치 완료! (OS: ${OS})"
echo ""
echo " ※ PATH는 새 터미널을 열거나 아래 실행 후 적용됩니다:"
echo "   source ${PROFILE}"
echo ""
echo " (스킬/가이드/플러그인/alias는 bootstrap-claude-instance.sh로 설치)"
echo "================================================="
