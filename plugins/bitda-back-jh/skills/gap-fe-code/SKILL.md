---
name: gap-fe-code
description: plan-master FE 코드만을 유일한 1차 소스로(기획서 .md 배제) 멀티팀 에이전트가 BE가 보장해야 할 비즈니스 로직과 FE 작업에 필요한 API 항목을 도출하고, 총괄 에이전트가 bitda-back BE 구현과 실측 대조하여 누락 갭을 발굴, 직렬 verifier로 확정한 뒤 GitHub 이슈로 생성하는 스킬입니다. gap-analyze의 변종으로, 기획서가 구현완료를 선언해 갭을 가리는 오염을 제거하기 위해 기획서를 의도적으로 보지 않습니다. /gap-fe-code 생산현황, 기획서 빼고 FE 코드로 갭 분석, FE 코드만 보고 누락 API 이슈 만들어 등을 요청할 때 사용됩니다.
---

# Gap Analyze (FE-Code-Only / 멀티팀)

## Purpose

plan-master FE 코드를 **유일한 1차 소스**로 삼아(docs/specs 기획서 `.md`는 **읽지 않음**),
멀티팀 에이전트가 BE 갭을 발굴하고 GitHub 이슈로 생성한다.

### 기존 gap-analyze와의 차이 (존재 이유)

기획서를 함께 보면 다음 오염이 발생한다 (실제 사례, 2026-06):

> work-status 기획서 §5.1이 "✅ bitda-back 구현 완료 — 8 엔드포인트 확인됨"을 선언했다.
> 이 선언이 §2.1 상태배지(집계 API)·§5.6 재고검증 누락을 **가렸고**, 기획서를 본 2라운드
> 분석이 상세화면 편집 갭을 **0건** 발굴했다. 기획서를 배제하고 FE 코드만 멀티팀으로 본
> 3라운드에서 신규 7건(작업시간 조정/통 추가/초안 저장/실감량 판정 등)을 발굴했다.

**핵심 원칙: 기획서는 BE 구현 상태를 미리 단정해 분석을 오염시킬 수 있다. FE 코드는
화면이 실제로 무엇을 요구하는지 거짓말하지 않는다. 따라서 FE 코드만 본다.**

## When to use

- 기획서 기반 gap-analyze가 "다 구현됐다"고 했는데 화면이 비어 보이거나 동작이 막힐 때
- 상세화면의 편집/액션/집계처럼 기획서가 표면적으로만 다루는 영역을 깊이 파야 할 때
- 사용자가 "기획서 빼고", "FE 코드만 보고", "멀티팀으로 갭 도출" 등을 명시할 때

## Configuration

```
plan-master FE 코드: /Users/gimjinhyeog/Desktop/coding/plan-master/apps/liquor/src
  ※ docs/specs/**/*.md (기획서)는 절대 읽지 않는다.
bitda-back BE:        /Users/gimjinhyeog/Desktop/coding/bitda-back/modules
  - API:    application/api/src    - Core: application/core/src
  - Domain: domain/src             - Infra: infrastructure/src
실 운영 FE(보조):     /Users/gimjinhyeog/Desktop/coding/bitda-front
  ※ 화면이 PRO 목업/미구현인지 판별할 때만 참조. 1차 소스는 plan-master.
```

## Workflow

### Step 0: 범위 결정 + FE 코드 존재 확인

인자로 받은 도메인(예: "생산현황 및 내역")의 FE 코드 디렉토리를 먼저 찾는다.

```bash
find /Users/gimjinhyeog/Desktop/coding/plan-master/apps/liquor/src -type d -path "*{domain}*"
```

FE 코드가 없으면 이 방법론은 성립하지 않는다(1차 소스 부재) — 사용자에게 알린다.
실 운영 FE(bitda-front)에서 해당 화면이 PRO 목업/미구현인지도 함께 확인해 둔다.

### Step 1: 멀티팀 워크플로우 실행

`references/workflow-template.js`의 워크플로우를 도메인 경로만 바꿔 실행한다.
구조는 다음과 같다(Workflow 도구 사용):

- **팀1 — 비즈니스 로직 도출관**: FE 코드에서 BE가 보장/검증해야 할 규칙을 역도출
  (상태 전이 조건, submit 전 검증, 계산/파생식, 멱등/동시성, 집계 의미). 기획서 인용 금지.
- **팀2 — API 항목 추출관**: FE가 BE 연동으로 작업하려면 필요한 API 전부 추출
  (목록/필터/정렬/페이지/검색, 집계/요약, 상세 필드, 상태 전이, 편집 페이로드, 인쇄 데이터).
  plan-master는 localStorage 목업이므로 **repository 인터페이스 메서드 시그니처 = API 명세**로 환산.
- **총괄 — BE 대조관** (`invigo-agents:architect-reviewer`): 팀1·팀2 결과를 BE 구현과
  직접 grep/read로 대조해 갭 후보를 구조화. 이미 생성된 이슈와 중복은 배제.
- **직렬 verifier**: 각 갭 후보를 BE 코드 직접 실측으로 확정(오탐 차단). `pipeline`으로 처리.

### Step 2: 메인 직접 재판정 (필수)

> ⚠️ 워크플로우의 `confirmed`도 오탐 경향이 있다. **메인 컨텍스트가 직접 grep/read로 재판정**한다.

각 confirmed 갭에 대해:
1. BE Response DTO / Result / JpaAdapter SELECT / Flyway 컬럼 / Domain·Service 로직을 직접 확인
2. `references/false-positive-rules.md`의 오탐 패턴에 해당하면 기각
3. **목업 패러다임 함정 판별**: plan-master가 localStorage로 자유 CRUD 하는 화면을 BE가
   "종속 자동생성 + 상태전이"로 설계했다면, 그 편집 API들이 진짜 제품 요구인지 목업
   아티팩트인지 **사람(사용자)에게 확인**한다(추측 금지). 화면 성격이 갭 다수의 운명을 가른다.

### Step 3: 갭 목록 제시 + 이슈 생성

확정 갭을 표로 제시하고 이슈화 방식을 사용자에게 확인한다(전체/선택/Epic묶음/보고서만).
강결합 갭(동일 Aggregate·Controller 동시 수정)은 Epic 1개 + Sub로 묶고, 독립 갭은 개별 이슈로.

- 보고서를 `docs/spec-review/gap-fe-code_{domain}_{YYYYMMDD}.md`에 박제한다.
- `issue-create` 패턴으로 이슈 생성. 라벨: API/필드 누락→`feature,api-change`,
  검증/비즈니스규칙→`feature`, 크기 small/medium/large 추정.

## 오탐 방지 (CRITICAL)

갭 판정 기준 = **BE Response DTO + JpaAdapter SELECT + Flyway 컬럼 + Domain/Service 로직**
중 하나라도 실제로 없을 때만. 자세한 기각 규칙은 `references/false-positive-rules.md` 참조.

## 학습된 함정

- **기획서 "구현완료" 선언** = 갭을 가린다 → 이 스킬은 기획서를 안 본다.
- **목업 패러다임 차이** = plan-master 자유편집 CRUD vs BE 종속 자동생성. 경로불일치가 아니라
  설계 가정 차이 → 사람 확인 필요.
- **WF confirmed 과신** = 메인 재판정 필수. (직전 실측: 18후보 중 11이 "BE에 이미 있음" 오탐)
