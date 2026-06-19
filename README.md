# claude-bootstrap

Claude Code 인스턴스 부트스트랩. 원격 서버(Ubuntu), 로컬(macOS), Windows에서 Claude Code 설치부터 스킬/가이드/설정까지 원클릭으로 셋업한다.

## 구성

| 스크립트 | OS | 역할 |
|----------|----|------|
| `install-claude-npm.sh` | macOS / Ubuntu | Claude Code를 npm으로 설치/업데이트. Node.js 없으면 자동 설치 (macOS=Homebrew, Ubuntu=nvm). 기존 standalone 설치가 있으면 정리. |
| `bootstrap-claude-instance.sh` | macOS / Ubuntu | 스킬/가이드/전역설정/플러그인/alias를 `~/.claude/`에 설치. 설치할 콘텐츠는 스크립트 끝에 base64(tar.gz)로 임베드되어 있어 추가 네트워크/GitHub 인증 불필요. |
| `install-claude-npm.ps1` | Windows | 위 install 스크립트의 PowerShell 포팅. Node.js를 winget/fnm/직접 다운로드로 설치. |
| `bootstrap-claude-instance.ps1` | Windows | 위 bootstrap 스크립트의 PowerShell 포팅. jq 대신 PowerShell 네이티브 JSON 처리. 동일한 payload 임베드. |

## 사용법

### macOS / Ubuntu (bash)

```bash
# 1. Claude Code 설치 (Node.js 없으면 자동 설치)
chmod +x install-claude-npm.sh
./install-claude-npm.sh

# 2. OAuth 인증 (별도 — 브라우저가 없는 서버는 device code flow)
claude login

# 3. 부트스트랩 (스킬/가이드/설정 설치)
chmod +x bootstrap-claude-instance.sh
./bootstrap-claude-instance.sh

# 4. 새 터미널 열기 (또는 source ~/.bashrc / ~/.zshrc)
```

### Windows (PowerShell)

```powershell
# 0. 실행 정책 설정 (최초 1회)
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# 1. Claude Code 설치 (Node.js 없으면 winget/fnm/직접 다운로드)
.\install-claude-npm.ps1

# 2. OAuth 인증
claude login

# 3. 부트스트랩 (스킬/가이드/설정 설치)
.\bootstrap-claude-instance.ps1

# 4. 새 PowerShell 창 열기 (또는 . $PROFILE)
```

## 부트스트랩 설치 항목

### 스킬 (15개) → `~/.claude/skills/`

| 분류 | 스킬 |
|------|------|
| 세션 관리 | handoff, resume, session-continuity |
| 개발 워크플로우 | sdd, sdd-specify, sdd-plan, sdd-tasks, sdd-implement, tdd-sprint |
| 코드 품질 | debug, refactor, review |
| 산출물 | html-ppt, html-base |
| 정리 | tidy |

### 가이드 (20개) → `~/.claude/guides/`

context-strategy, design-process, doc-structure, getting-started, incident-response, mcp-guide, multi-llm-cli-auth, pencil-workflow, project-bootstrap, prompt-patterns, release-notes-convention, shadcn-guide, skill-design-principles, skill-workflows, subagents-vs-teams, token-optimization, workflow-combinations, anti-patterns, claude-codex-headless, claude-md-template, html-artifact-analysis

### 설정

| 항목 | 설명 |
|------|------|
| `CLAUDE.md` | 전역 AI 개발 원칙 (기존은 `.bak` 백업) |
| `settings.json` | permissions, env, plugins, statusLine 병합 (bash=jq, PowerShell=네이티브 JSON. 기존 설정 보존) |
| HUD config | `~/.claude/plugins/claude-hud/config.json` |
| 플러그인 선언 | superpowers, oh-my-claudecode, claude-hud (Claude Code 첫 실행 시 마켓에서 자동 설치) |
| alias | `cc` (skip-permissions), `ca` (claude agents) |

## 주의사항

- `cc` alias는 `--dangerously-skip-permissions`를 사용합니다. **격리된 sandbox/개발 인스턴스 전용**이며, 프로덕션 접근이 가능한 환경에서는 사용하지 마세요.
- 두 스크립트 모두 **멱등성**이 있어 여러 번 실행해도 안전합니다.
- `install-claude-npm.sh`는 `~/.claude/` 설정을 건드리지 않습니다.
- `bootstrap-claude-instance.sh`는 기존 `CLAUDE.md`, `settings.json`을 `.bak`으로 백업한 뒤 덮어씁니다.

## 커스터마이징

- 불필요한 스킬은 설치 후 `~/.claude/skills/`에서 삭제하면 됩니다.
- 가이드도 마찬가지로 `~/.claude/guides/`에서 개별 관리 가능합니다.
- 전역 `CLAUDE.md`는 설치 후 자유롭게 수정하세요.

## Windows 관련 주의사항

- **Windows 10 build 17063+** 필요 (내장 `tar.exe` 의존). 이전 빌드에서는 별도 tar 설치 필요.
- Node.js MSI 직접 설치 경로는 **관리자 권한(UAC)** 이 필요합니다. winget은 대부분 비관리자로 동작합니다.
- `AllSigned` 실행 정책이 GPO로 강제된 환경에서는 스크립트에 서명이 필요하거나, `powershell -ExecutionPolicy Bypass -File .\script.ps1`로 실행하세요.
- `$PROFILE`에 등록되는 `cc`/`ca` alias는 **현재 PowerShell 호스트 전용**입니다. VS Code 터미널, pwsh, Windows PowerShell은 각각 다른 profile 파일을 사용하므로, 다른 호스트에서도 쓰려면 해당 profile에 수동 복사하세요.

## 지원 OS

- macOS (Homebrew 기반) — `.sh`
- Ubuntu (apt + nvm 기반) — `.sh`
- Windows 10 build 17063+ (winget / fnm / 직접 다운로드) — `.ps1`
