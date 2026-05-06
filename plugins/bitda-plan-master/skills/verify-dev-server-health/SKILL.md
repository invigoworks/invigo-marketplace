---
name: verify-dev-server-health
description: Dev 서버 / HMR 관련 런타임 에러를 진단합니다. "Failed to fetch dynamically imported module", "@fs/" 404, 포트 충돌, stale HMR runtime 등을 자동 분류하고 해결책을 제시합니다.
---

# Dev Server 헬스 & HMR 에러 진단

## Purpose

브라우저에서 다음 류의 런타임 에러가 발생했을 때 원인을 자동 진단:

- `Failed to fetch dynamically imported module: http://localhost:<PORT>/@fs/...`
- `Unexpected Application Error!` + lazy chunk 로드 실패
- `TypeError: Failed to fetch dynamically imported module`
- 페이지가 갑자기 빈 화면 / 에러 바운더리로 떨어짐
- 파일은 디스크에 분명 존재하는데 브라우저가 404

이런 증상은 **코드 버그가 아니라 dev 서버/HMR/포트 혼선** 인 경우가 대부분입니다. 이 skill은 빠르게 판별해서 잘못된 코드 수정 시도를 방지합니다.

## When to Run

- 사용자가 브라우저 에러 스크린샷·메시지를 붙여넣을 때, 메시지에 `@fs/`, `Failed to fetch dynamically imported module`, `localhost:<포트>` 등이 포함되면 **코드를 고치기 전에 먼저 이 skill 실행**
- `agent-browser open` 실패 + 응답 404 일 때
- `pnpm dev:*` 재시작 후 기존 브라우저 탭이 동작 이상할 때
- 여러 앱(Vite + Next.js 등)을 동시에 돌린 적이 있는 세션에서 포트 충돌 의심 시

## Known Root Causes (우선 순위)

| # | 원인 | 징후 |
|---|---|---|
| 1 | **Dev 서버 재기동 후 브라우저 탭 stale** (가장 흔함) | 탭 오래 열림 + 서버 PID 최근 변경 (`ps -p <PID> -o lstart`). 이전 서버가 발급한 module ID/`@fs/` URL 이 새 서버 graph 에 없어서 404. 하드 리로드로 해결. |
| 2 | **포트에 다른 프레임워크** (Vite 기대 포트에 Next.js 등) | `@fs/` 경로 404 + `curl /` 응답 HTML 에 `/@vite/client` 없음. 다른 `<title>` |
| 3 | **Dev 서버 죽음** (pkill / crash / port 해제) | LISTEN 프로세스 자체가 없음. `curl` connection refused |
| 4 | **HMR websocket 끊김** (장시간 sleep, VPN 전환) | 탭은 살아있지만 websocket 재연결 실패. 콘솔에 `[vite] server connection lost` |
| 5 | **Vite dependency optimization 재실행 중** (대량 파일 수정 직후) | 수십 파일 동시 변경 → Vite 가 deps 재빌드 중 일시적 404. 수 초 후 안정화 |
| 6 | **vite cache 손상** (node_modules/.vite) | 특정 모듈만 계속 404. 다른 파일은 정상. 지속적 |
| 7 | **최근 파일 이동/rename** | Git 에서 최근에 해당 파일이 moved 되었고 브라우저는 구 경로 캐시 |
| 8 | **`server.fs.allow` 경계 위반** | 워크스페이스 밖 파일 접근 시도 → Vite 가 의도적으로 403/404 반환 |
| 9 | **SPA fallback이 정적 파일을 가로챔** | `public/` 디렉토리의 `.xlsx`, `.ttf` 등 비-HTML 파일을 fetch하면 `index.html`(641 bytes, text/html)이 반환됨. preview 앱(3000)은 SPA 라우터가 모든 경로를 가로채서 public 파일 서빙 안 됨. `src/assets/`로 이동 후 Vite `?url` import로 해결 |

## Workflow

### Step 1 — 에러 메시지 파싱

사용자가 붙여넣은 에러에서 다음 값을 추출:

- **HOST**: `http://localhost:<PORT>` 에서 포트 번호
- **PATH**: `@fs/...` 또는 `/src/...` 뒤의 절대 경로
- **SCHEME**: `@fs/` (Vite fs 직접 접근), `/@id/` (Vite 가상 모듈), `/_next/` (Next.js)

패턴 예:
```
Failed to fetch dynamically imported module: http://localhost:3000/@fs/Users/.../MaterialTable.tsx
→ PORT=3000, PATH=/Users/.../MaterialTable.tsx, SCHEME=@fs/
```

### Step 2 — 파일 디스크 존재 확인

```bash
ls -la <PATH>
```

- **존재함** → 코드 문제 아님 → Step 3 로
- **없음** → 사용자가 파일 삭제/rename 했거나 git stash/checkout 결과. `git log --diff-filter=D -- <PATH>` 로 최근 삭제 확인, 브랜치 상황 안내

### Step 3 — 포트 LISTEN 프로세스 확인

```bash
lsof -iTCP:<PORT> -sTCP:LISTEN
ps aux | grep <PID> | grep -v grep
```

결과 분류:

**(a) LISTEN 없음**
→ Dev 서버 죽음. 원인 #3.
→ 해결: `pnpm dev:<app>` 재시작. 재시작 후 브라우저 하드 리로드.

**(b) LISTEN 있음, COMMAND가 `node` + `vite`**
→ Vite 서버 살아있음. 원인 #2, #4, #5 중 하나.
→ 확인: `curl http://localhost:<PORT>/` 200 확인, `curl http://localhost:<PORT>/<PATH>` 로 파일 직접 접근 시도.
→ 200 이면 원인 #2 (stale tab). 해결: **하드 리로드** (Cmd+Shift+R 또는 DevTools → Network → "Disable cache").
→ 여전히 404 면 원인 #5 (vite cache). 해결: `rm -rf node_modules/.vite && pnpm dev:<app>` 재시작.

**(c) LISTEN 있음, COMMAND가 `next-server` / `next dev` / 기타 non-vite**
→ **포트 충돌**. 원인 #1.
→ plan-master 의 기대 포트(아래 REFERENCE 참고)와 실제 응답 포트가 다름.
→ 해결: (1) 올바른 포트로 재접속, (2) 또는 non-vite 서버를 종료하고 Vite 재시작.

### Step 4 — 최근 git 변화 확인 (원인 #6 의심 시)

```bash
git log --since="1 hour ago" --name-status -- apps/liquor/src/settings/master-data/
git diff HEAD~5 --stat -- <PATH>
```

최근 이동/rename 있었다면 → 브라우저 탭에 구 경로 캐시. 해결: 탭 하드 리로드.

### Step 5 — 진단 리포트

다음 형식으로 사용자에게 출력:

```
## Dev Server 진단

**에러**: [원본 에러 메시지 요약]
**포트**: <PORT>
**파일**: <PATH> (디스크 존재: yes/no)
**LISTEN 프로세스**: <COMMAND> (PID <PID>)

**원인**: 원인 #<N> — <이름>
**설명**: [2-3 문장 분석]

**해결책**:
1. [즉시 조치]
2. [예방 조치]

**코드 문제 아님 확인**: [tsc/test green 여부 보고]
```

### Step 6 — 코드 수정 방지 가드

원인이 #1~4 (서버/브라우저/포트) 인 경우:

- **절대 코드를 수정하지 않음**
- 사용자에게 "위 해결책 수행 후 다시 확인해주세요" 안내
- 사용자가 해결 후에도 동일 에러면 그때 코드 조사 시작

## Reference — 이 프로젝트의 포트 맵

| 앱 | 포트 | 시작 명령 | 비고 |
|---|---|---|---|
| `@plan-master/preview` | **3000** | `pnpm dev:preview` | Vite. `workspace:*` 로 liquor/manufacturing/admin/tax-office 소스 직접 참조. `/liquor/...`, `/manufacturing/...` 경로로 각 앱 surface 통합 렌더 |
| `@plan-master/liquor` | **3002** | `pnpm dev:liquor` | Vite, 단독 실행 |
| `@plan-master/manufacturing` | 3003 (추정) | `pnpm dev:manufacturing` | Vite |
| `@plan-master/admin` | 3004 (추정) | `pnpm dev:admin` | Vite |

> 실제 포트는 각 앱 `vite.config.ts` 의 `server.port` 에서 확인. **`dev:preview` 가 3000 을 사용한다는 점이 중요** — 많은 다른 Node 프로젝트도 3000 을 쓰므로 dual-stack 포트 공존이 흔함.

### Dual-stack 함정 (macOS)

`lsof -iTCP:3000 -sTCP:LISTEN` 이 **두 프로세스** 를 동시에 보여줄 수 있음:

```
node       46975  IPv6 localhost:3000 (LISTEN)   ← Vite preview
next-server 81039 IPv4 *:3000       (LISTEN)   ← 무관한 Node 앱
```

macOS 는 IPv6/IPv4 를 분리 바인딩 허용. **`localhost`** 로 접속 시 IPv6 우선 → Vite 가 응답. `curl -6 http://localhost:3000/` vs `curl -4 http://localhost:3000/` 로 응답 주체를 분리 확인.

**진단 할 때 `lsof` 결과만 보고 COMMAND 판단하지 말고, 반드시 `curl http://localhost:<PORT>/` 로 HTML `<title>` 을 확인할 것.** Vite 는 응답에 `/@vite/client` 스크립트 포함.

## Related Commands

```bash
# 전체 포트 스캔
lsof -iTCP -sTCP:LISTEN -P | grep -E "300[0-9]"

# Vite 프로세스만 식별
ps aux | grep -i "vite\|node" | grep -v grep

# Vite cache 리셋 (원인 #5)
find . -type d -name ".vite" -not -path "*/node_modules/.pnpm/*" -prune -exec rm -rf {} \;
pnpm dev:liquor

# 안전한 dev 서버 종료 (port 지정)
lsof -iTCP:3002 -sTCP:LISTEN -t | xargs kill
```

### Step 7 — SPA fallback 진단 (원인 #9)

`fetch('/templates/xxx.xlsx')` 결과가 `text/html`이고 641 bytes인 경우:

```bash
# 1. 응답 content-type 확인
curl -s -o /dev/null -w "type: %{content_type}, size: %{size_download}" "http://localhost:3000/templates/tax-base-form.xlsx"
# text/html + 641 bytes → SPA fallback이 index.html 반환

# 2. 올바른 포트(Vite 단독 서버)에서 확인
curl -s -o /dev/null -w "type: %{content_type}, size: %{size_download}" "http://localhost:3002/templates/tax-base-form.xlsx"
# application/octet-stream + 20182 bytes → 정상

# 3. 해결: src/assets/로 이동 + Vite ?url import 사용
# import templateUrl from "../assets/templates/file.xlsx?url";
# fetch(templateUrl) → Vite가 빌드 시 올바른 URL 생성
```

**코드 수정 필요**: `public/` 경로를 하드코딩한 `fetch("/templates/...")` → `import ... from "...?url"` + `fetch(importedUrl)` 로 전환.

## Anti-patterns — 이 에러에서 하지 말아야 할 것

- ❌ **`pkill -f "vite"` 절대 금지** — pattern match 는 `node_modules/.bin/vite`, `apps/preview/node_modules/.../vite/bin/vite.js` 등 워크스페이스 내 모든 Vite 프로세스를 한꺼번에 죽임. 사용자가 `dev:preview`, `dev:liquor` 등 여러 개 띄운 경우 전부 영향. 세션 도중 사용자 dev 서버 파괴 사고 실제 발생(2026-04-12).
  - **대체**: 포트 지정으로만 종료 → `lsof -iTCP:<PORT> -sTCP:LISTEN -t | xargs kill` (단일 PID).
  - **더 안전**: 내가 띄운 서버는 PID 기억했다가 그 PID만 `kill`.
- ❌ **`lsof` COMMAND 만 보고 판단** — dual-stack 환경에서 IPv4/IPv6에 서로 다른 프로세스 동시 LISTEN 가능. 반드시 `curl http://localhost:<PORT>/` 로 HTML `<title>` 확인할 것. Vite 응답에는 `/@vite/client` script 포함.
- ❌ 코드 수정 먼저 시도 (원인 파악 없이). `@fs/` 404 는 대부분 환경 문제.
- ❌ `rm -rf node_modules` — 오버킬. 먼저 `.vite` 캐시만 지우기.
- ❌ 브라우저 새로고침만 반복 — **하드 리로드**(Cmd+Shift+R)가 필요한 경우 많음 (stale HMR runtime 제거).
- ❌ 포트 번호 확인 없이 "HMR 버그" 로 단정.
- ❌ 사용자가 어느 앱을 띄웠는지 묻지 않고 가정. `@plan-master/preview`(3000), `liquor`(3002), `manufacturing`(3003) 등 구분 필요.
- ❌ 사용자의 브라우저 탭을 외부에서 해결 시도. 하드 리로드는 사용자만 가능.

## Success Criteria

- [ ] 에러 메시지 파싱으로 PORT/PATH/SCHEME 추출
- [ ] 파일 디스크 존재 확인
- [ ] LISTEN 프로세스 COMMAND 판별 (vite vs non-vite)
- [ ] 6 원인 중 하나로 분류
- [ ] 원인별 해결책 1-2개 구체 제시
- [ ] 코드 수정 시도 방지 (원인 파악 전)

## Notes

- 이 skill은 **read-only 진단**. 사용자 확인 없이 dev 서버 재시작/프로세스 kill 금지.
- 포트 3000 은 Node 생태계에서 가장 혼잡. plan-master 는 3002 부터 사용하지만 기존 Next.js 등 다른 프로젝트가 먼저 선점한 경우 많음. 이 skill 을 실행할 때 3000 발견하면 우선 "non-vite 의심" 플래그.
