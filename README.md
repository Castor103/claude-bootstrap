# claude-bootstrap

Claude Code 인스턴스 부트스트랩. 원격 서버(Ubuntu), 로컬(macOS), Windows에서 Claude Code 설치부터 스킬/가이드/설정까지 원클릭으로 셋업한다.

## 왜 만들었나

Claude Code는 설치 직후 빈 상태다. 스킬, 가이드, 전역 설정, 플러그인 선언을 매번 수동으로 세팅하는 건 번거롭고, 팀원마다 환경이 달라진다. 이 bootstrap은:

- **원클릭 환경 통일**: 새 머신, 원격 서버, 팀원 온보딩 시 동일한 Claude Code 환경을 즉시 구성
- **네트워크 독립**: 설치할 콘텐츠(스킬/가이드/설정)를 스크립트 끝에 base64(tar.gz)로 임베드. GitHub 인증이나 추가 다운로드 없이 단일 파일로 동작
- **멱등성**: 여러 번 실행해도 안전. 기존 설정은 `.bak`으로 백업

스킬과 가이드는 실무에서 Claude Code를 쓰면서 반복된 시행착오를 구조화한 것이다. AI가 설계 없이 코드부터 짜는 문제(→ SDD), 세션 간 컨텍스트 유실(→ handoff/resume), 원인 분석 없이 코드를 고치는 습관(→ debug) 등을 해결하기 위해 하나씩 만들었다.

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

모두 직접 제작한 커스텀 스킬이다. Claude Code에는 공식 스킬이 없으므로, 반복되는 워크플로우를 프롬프트 엔지니어링으로 구조화해서 만들었다. `/스킬명`으로 호출한다.

#### 세션 관리

| 스킬 | 설명 | 제작 동기 |
|------|------|-----------|
| `handoff` | 세션 인수인계 & 컨텍스트 체크포인트. 현재 작업 상태를 `.claude/handoff.md`에 저장 | Claude Code 세션이 길어지면 컨텍스트가 유실됨. 다음 세션에 이어하기 위한 체크포인트 |
| `resume` | 이전 세션 이어하기. `handoff.md`를 읽고 작업 복원 | `handoff`와 쌍으로 사용. 세션 연속성 확보 |
| `session-continuity` | 세션 연속성 오케스트레이터. handoff/resume을 자동 판단해서 실행 | handoff/resume을 매번 수동 호출하는 번거로움 해소 |

#### 개발 워크플로우

| 스킬 | 설명 | 제작 동기 |
|------|------|-----------|
| `sdd` | Specification-Driven Development 오케스트레이터. 아래 4단계를 순서대로 실행 | AI에게 "만들어줘"만 하면 설계 없이 코드부터 생성함. 설계→구현 순서를 강제하기 위해 |
| `sdd-specify` | 1단계: 요구사항 정의. PRD/기능 명세를 구조화 | |
| `sdd-plan` | 2단계: 기술 설계. 아키텍처, 데이터 모델, API 설계 | |
| `sdd-tasks` | 3단계: 작업 분해. 구현 태스크를 우선순위와 의존성 포함해서 분리 | |
| `sdd-implement` | 4단계: 태스크 단위 구현. 분해된 작업을 하나씩 구현 | |
| `tdd-sprint` | 자율 테스트 주도 스프린트. 테스트 먼저 작성 → 구현 → 리팩토링 사이클 | TDD를 AI가 자율적으로 반복하게 해서 품질 확보 |

#### 코드 품질

| 스킬 | 설명 | 제작 동기 |
|------|------|-----------|
| `debug` | 디버깅 전문가. 에러 분석 → 원인 추론 → 수정 제안 순서로 진행 | AI가 에러를 보면 바로 코드를 고치려 함. 원인 분석을 먼저 하도록 강제 |
| `refactor` | 리팩토링 전문가. 영향 범위 파악 → 계획 → 단계별 수정 | 무분별한 리팩토링 방지. 기존 인터페이스 보존하면서 내부만 개선 |
| `review` | 코드 리뷰. diff 기반으로 버그, 보안, 성능 이슈 검출 | |

#### 산출물

| 스킬 | 설명 | 제작 동기 |
|------|------|-----------|
| `html-ppt` | HTML 프레젠테이션/슬라이드 생성. CSS scroll-snap 기반, 키보드/터치 네비게이션, 발표자 모드 | 팀 공유용 산출물을 외부 도구 없이 단일 HTML로 생성하기 위해 |
| `html-base` | html-* 스킬 공통 디자인 시스템. 직접 호출하지 않음, html-ppt 등이 내부 참조 | 여러 html 스킬 간 디자인 일관성 유지 |

#### 정리

| 스킬 | 설명 | 제작 동기 |
|------|------|-----------|
| `tidy` | 세션 마무리 정리. 작업 내용 문서화(capture) + 문서 위치 컨벤션 검사(lint) | 세션 끝날 때 결정 사항이 휘발되지 않도록 |

### 가이드 (21개) → `~/.claude/guides/`

AI가 매 세션에서 참조하는 운영 지침서. Claude Code의 `CLAUDE.md`가 "무엇을 할지"를 정하면, 가이드는 "어떻게 할지"를 상세히 안내한다. 실무에서 반복된 시행착오를 정리한 것이다.

#### 프로젝트 운영

| 가이드 | 설명 |
|--------|------|
| `context-strategy` | 컨텍스트 관리 3-tier 전략. CLAUDE.md / rules / skills를 언제 어디에 쓸지 분류 기준 |
| `doc-structure` | 프로젝트 문서 구조 컨벤션. `.claude/`(AI 운영) vs `docs/`(영속 지식) 배치 기준 |
| `getting-started` | `.claude/` 디렉토리 배치 가이드. 새 환경 세팅 시 참조 |
| `project-bootstrap` | 새 프로젝트 시작 시 AI 개발 가이드. 제품 정의 → 기술 스택 → 첫 구현까지 |
| `claude-md-template` | `.claude/CLAUDE.md` 템플릿. 새 프로젝트의 CLAUDE.md 초안 작성용 |

#### 개발 패턴

| 가이드 | 설명 |
|--------|------|
| `prompt-patterns` | AI에게 효과적으로 지시하는 패턴 모음. 명확한 지시 → 좋은 결과 |
| `anti-patterns` | "A 고치면 B 깨지는" 문제의 원인과 해결. AI 코딩의 흔한 실수 패턴 |
| `skill-design-principles` | 스킬 설계 원칙. 새 스킬을 만들 때 따를 구조와 컨벤션 |
| `skill-workflows` | 스킬 워크플로우 치트시트. 어떤 상황에 어떤 스킬을 쓸지 |
| `workflow-combinations` | 워크플로우 조합 가이드. 여러 스킬을 연결해서 쓰는 패턴 |

#### 기술 참조

| 가이드 | 설명 |
|--------|------|
| `shadcn-guide` | shadcn/ui 종합 가이드. AI 주도 프론트엔드 개발에서 컴포넌트 사용법 참조 |
| `mcp-guide` | MCP(Model Context Protocol) 활용 가이드. 외부 도구 연동 방법 |
| `release-notes-convention` | 릴리즈 노트 컨벤션. Conventional Changelog 기반 |
| `html-artifact-analysis` | AI + HTML 아티팩트 분석 보고서. html-ppt 등 산출물 품질 기준 |

#### 운영/인프라

| 가이드 | 설명 |
|--------|------|
| `multi-llm-cli-auth` | 멀티 LLM CLI OAuth 인증 가이드. Claude + Codex 등 여러 AI CLI 동시 사용 시 |
| `claude-codex-headless` | Claude Main + Codex Headless 오케스트레이션. 두 AI를 조합해서 쓰는 패턴 |
| `subagents-vs-teams` | Subagents vs Agent Teams. 언제 서브에이전트를, 언제 팀을 쓸지 판단 기준 |
| `token-optimization` | 토큰 최적화 가이드. 컨텍스트 윈도우를 효율적으로 사용하는 방법 |
| `incident-response` | 인시던트 대응 플레이북. 장애 발생 시 AI 활용 디버깅 절차 |

#### 디자인/UI

| 가이드 | 설명 |
|--------|------|
| `design-process` | 초기 설계 프로세스. 와이어프레임 → 디자인 → 구현 흐름 |
| `pencil-workflow` | Pencil.dev를 활용한 UI 소통 워크플로우. 디자인 도구 연동 |

### 설정

| 항목 | 설명 |
|------|------|
| `CLAUDE.md` | 전역 AI 개발 원칙. 역할 분담, 코드 수정 규칙, 디버깅 절차 등을 정의 (기존은 `.bak` 백업) |
| `settings.json` | permissions, env, plugins, statusLine 병합 (bash=jq, PowerShell=네이티브 JSON. 기존 설정 보존) |
| HUD config | `~/.claude/plugins/claude-hud/config.json` |
| alias | `cc` (skip-permissions), `ca` (claude agents) |

### 플러그인 (3개) — `settings.json`의 `enabledPlugins`에 선언

Claude Code 첫 실행 시 공개 마켓에서 자동 설치된다. 이 bootstrap은 플러그인 코드를 포함하지 않고, "이 플러그인을 사용하겠다"는 선언만 한다.

| 플러그인 | 출처 | 설명 |
|----------|------|------|
| [superpowers](https://github.com/anthropics/claude-code-plugins) | 커뮤니티 (오픈소스) | 브레인스토밍, 코드리뷰, TDD, 플랜 작성 등 14개 범용 워크플로우 스킬 |
| [oh-my-claudecode](https://github.com/nicobailon/oh-my-claudecode) | 커뮤니티 (오픈소스) | 40+ 스킬 (analyst, architect, debugger, designer 등 전문가 서브에이전트) + LSP/AST 도구 |
| [claude-hud](https://github.com/hugodutka/claude-hud) | 커뮤니티 (오픈소스) | 터미널 상단에 토큰 사용량, 세션 시간, 비용 등을 표시하는 HUD |

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
