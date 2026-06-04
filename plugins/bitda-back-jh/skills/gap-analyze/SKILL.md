---
name: gap-analyze
description: plan-master(기획용 FE 코드 + docs/specs 기획서)와 bitda-back(구현된 BE 코드) 사이의 갭을 분석하여 누락된 기능·API·정책을 GitHub 이슈로 자동 생성하는 스킬입니다. 기획서→이슈 전달 과정에서 발생하는 누락을 방지하기 위해 FE 코드를 1차 소스로 사용합니다. "/gap-analyze", "/gap-analyze BOM", "/gap-analyze production" 등을 요청할 때 사용됩니다.
---

# Gap Analyze

## Purpose

plan-master FE 코드(기획용 구현체) + docs/specs 기획서를 1차 소스로,
bitda-back BE 구현 상태를 대조하여 **누락된 갭을 발굴하고 GitHub 이슈로 생성**한다.

기존 파이프라인의 누락 경로:
```
FE 코드 → 기획서(누락1) → issue-create(누락2) → issue-plan(누락3) → 구현
```

이 스킬은 FE 코드를 직접 읽어 누락1~3을 한 번에 탐지한다.

### 반복 탐지 실패 패턴 (학습된 놓침 사례)

> **생산계획 등록 사례 (2026-05)**: 생성 Request DTO 필드는 모두 구현됐으나,
> 폼 렌더링 시 드롭다운(공장/설비/공정 등)이 `id`만 반환하고 `name`/`colorId`/`isActive`를
> 반환하지 않아 FE가 폼 자체를 렌더링할 수 없었음.
>
> **근본 원인**: Agent C가 생성/수정 API의 Request 필드만 검증하고,
> **폼 드롭다운을 채우는 마스터 데이터 목록 조회 API의 Response 필드**를 확인하지 않았음.

> **form-data waterfall 사례 (2026-05)**: 생산계획 등록 폼 진입 시 FE가
> factories/warehouses/processes/items 등 독립 마스터 데이터를 개별 API로 각각 호출.
> `GET /api/v1/production-plans/form-data` 통합 API가 없어 waterfall 발생.
>
> **근본 원인**: 갭 분석 시 개별 API 존재 여부만 확인하고,
> **폼 초기 렌더링에 필요한 독립 마스터 데이터를 단일 API로 묶었는지** 확인하지 않았음.
> 탐지 방법: `grep -r "form-data" modules/application/api/src` 결과가 없으면 갭.

---

## 🎯 FE 관점 체크리스트 (Agent C/D 필수 점검 항목)

> "FE 화면이 굴러가지 않는다"는 사례를 카테고리별로 망라한 A~H 체크리스트는
> **`references/fe-perspective-checklist.md`로 분리**했다 (본문 중복 제거).
> Agent C/D는 디스패치 프롬프트에서 그 파일을 Read하라는 지시를 포함한다 (Step 1 참조).
>
> 요약 — A. Response 필드 누락 / B. 마스터 드롭다운 조회 / C. 목록 부가기능
> / D. 액션·상태전이 / E. 에러 응답 / F. 데이터 정합성 / G. 첨부·메모·이력 / H. Export·Import.
> CRUD 라운드트립(C/R/U/D·구조불일치)은 `references/crud-roundtrip-matrix.md`,
> production/BOM 특화 규칙은 `references/production-pr-lessons.md`.

---

### 도메인별 점검 매트릭스 적용 방법

Agent C 실행 시 분석 대상 도메인에 대해 위 A~H 체크리스트를 **표로 작성**하고
각 항목별로 ✅(있음) / ❌(없음) / N/A(불필요) 마킹.
Agent D는 ❌ 표시된 항목 중 FE 시나리오에서 실제로 필요한 것만 갭으로 승격.

---

## Configuration

```
plan-master 경로: /Users/gimjinhyeog/Desktop/coding/plan-master
  - FE 코드:  apps/liquor/src/
  - 기획서:   docs/specs/liquor/

bitda-back 경로: /Users/gimjinhyeog/Desktop/coding/bitda-back
  - API:    modules/application/api/src/
  - Core:   modules/application/core/src/
  - Domain: modules/domain/src/
  - Infra:  modules/infrastructure/src/
```

---

## Workflow

### Step 0: 분석 범위 결정

인자가 전달된 경우 해당 도메인만 분석한다.
- `/gap-analyze BOM` → BOM 관련 파일만
- `/gap-analyze production` → production 관련 파일만
- `/gap-analyze` (인자 없음) → 전체 스펙 파일 목록 나열 후 선택 요청

인자 없이 실행 시:
```bash
find /Users/gimjinhyeog/Desktop/coding/plan-master/docs/specs -name "*.md" \
  | grep -v README | grep -v _templates | grep -v _golden | grep -v _schema
```
목록을 보여주고 어떤 스펙을 분석할지 확인한 뒤 진행한다.

---

### Step 1 (Stage 1 — 병렬 발굴 그물): A/B/C 에이전트 병렬 디스패치

> **파이프라인 구조 (2단 직렬 게이트)**
> ```
> Stage 1 (병렬 그물)   Agent A∥B∥C∥D → 갭 "후보" 목록(raw, 미확정)
>         ↓ 배리어: 후보 전부 수집
> Stage 2 (직렬 확정)   단일 verifier가 후보를 1건씩 순차 검증 → CONFIRMED / REFUTED
>         ↓
> Stage 3 (사람 게이트) CONFIRMED만 사람에게 제시 → 이슈화
> ```
> Stage 1의 출력은 **전부 "후보"일 뿐 확정 갭이 아니다.** 병렬 에이전트는
> 넓게 빠르게 긁는 그물 역할만 한다. 확정은 Stage 2 직렬 검증(Step 2.5)에서만 일어난다.
> 병렬 에이전트가 `isReal=true`/`갭 확정`이라 적어도 그것은 후보 표시일 뿐이다.

다음 3개 에이전트를 **동시에** 실행한다.

> ⚠️ **[필수] Agent C/D는 디스패치 프롬프트에 아래 references를 Read하라는 지시를 반드시 포함한다.**
> 이 파일들은 머지된 PR에서 역추출한 탐지 규칙·CRUD 매트릭스다. Read 지시 없으면 병렬 에이전트는 읽지 않는다.
> - 모든 도메인: `.claude/skills/gap-analyze/references/crud-roundtrip-matrix.md` (C/R/U/D 4종 + S1~S8 구조불일치)
> - 모든 도메인: `.claude/skills/gap-analyze/references/fe-perspective-checklist.md` (A~H 화면 동작 체크리스트)
> - production/BOM/생산계획/공정현황 도메인이면 추가: `.claude/skills/gap-analyze/references/production-pr-lessons.md` (J-RI/DB/API/FIELD/CUT 규칙 + grep + 오탐완화)

#### Agent A — FE 코드 분석 (`code-explorer`)

**목적**: plan-master FE 구현에서 BE 호출 패턴, 데이터 모델, API 엔드포인트 추출

분석 항목:
- `useRepository`, `fetch(`, `axios.`, Repository 인터페이스 패턴
- 폼 필드 → 요청 body 매핑 (submit handler)
- 상태 전이 액션 (버튼 onClick → API 호출)
- FE 타입 정의 (`type`, `interface`)
- ⚠️ **[필수] 폼 렌더링용 마스터 데이터 조회 패턴**
  - 드롭다운/셀렉트 옵션을 채우는 목록 조회 API 호출 전부 추출
  - 각 조회 API에서 FE가 **실제로 사용하는 필드** 목록 파악 (표시명, 코드, 색상, 활성상태 등)
  - FE 타입에서 ID 필드 옆에 표시명 필드(`name`, `label`, `code`, `colorId` 등)가 함께 있는 패턴 탐지
  - 예: `factoryId` + `factoryName`, `processId` + `processName`, `equipmentId` + `facilityName`

출력 형식:
```
## FE API 요구사항 (생성/수정)
- POST /api/v1/xxx          → 생성, body: {field1, field2}
- PATCH /api/v1/xxx/{id}    → 수정, body: {field1}
## FE 마스터 데이터 조회 API (폼 드롭다운용)
- GET /api/v1/factories     → FE 사용 필드: id, name, colorId, isActive
- GET /api/v1/equipments    → FE 사용 필드: id, name, factoryId, isActive
- GET /api/v1/processes     → FE 사용 필드: id, name, colorId, isActive
## FE 데이터 모델
- XxxType { field1: string, factoryId: UUID, factoryName: string }
```

#### Agent B — 기획서 분석 (`Explore`)

**목적**: docs/specs 기획서에서 API 명세, 비즈니스 규칙, 정책 추출

분석 항목:
- API 엔드포인트 명세 (PART 3 또는 API 섹션)
- 비즈니스 규칙·invariant
- 상태 전이 정책
- Open Questions / 미결 정책

출력 형식:
```
## 기획서 API 명세
- 명시: GET /api/v1/xxx
- 미명시(FE에 있으나 기획서에 없음): DELETE /api/v1/xxx/{id}
## 비즈니스 규칙
- 규칙1: displayUnit + conversionRate 동시 null 또는 동시 non-null
## Open Questions
- 커스텀 단위 삭제 시 BOM displayUnit 정합성 정책 미결
```

#### Agent C — BE 현황 분석 (`code-explorer`)

**목적**: bitda-back 현재 구현 상태 파악

분석 항목:
- 구현된 Controller 엔드포인트 (경로 + HTTP 메서드)
- UseCase 인터페이스 + 서비스 구현체 유무
- Domain 모델 필드
- **Response DTO 실제 필드 목록** (XXXResponse, XXXResult 클래스의 val 필드 전체)
- Flyway 마이그레이션 컬럼 현황
- **QueryDSL/JpaAdapter에서 실제 SELECT하는 컬럼 목록**
- ⚠️ **[필수] 폼 렌더링용 마스터 데이터 조회 API Response 필드 검증**
  - FE 폼에서 드롭다운/셀렉트로 선택하는 **모든 참조 엔티티**(factory, equipment, process, task, warehouse, item, user, department 등)에 대해:
  - 해당 목록 조회 API(GET /api/v1/xxx)의 **Response DTO가 FE 표시에 필요한 필드**(name, code, colorId, isActive 등)를 실제로 포함하는지 확인
  - ID만 있고 표시명/코드/상태 필드가 없으면 → **갭 판정**
  - 예: 생산계획 등록 폼에서 공장 드롭다운은 `id`뿐 아니라 `name`, `colorId`, `isActive` 필요

> ⚠️ **필드 누락 판단 시 반드시 Response DTO를 직접 확인한다.**
> FE가 로컬에서 데이터를 조인/가공하는 코드가 있더라도,
> BE Response에 해당 필드가 이미 존재하면 갭이 아니다.

출력 형식:
```
## 구현된 API
- GET  /api/v1/xxx ✅
- POST /api/v1/xxx ✅
## Response DTO 필드 현황 (생성/수정 API)
- XxxResponse: { field1, field2, colorId ✅ }
## 마스터 데이터 조회 Response 필드 현황 (폼 드롭다운용)
- GET /api/v1/factories     → FactoryResult:   { id ✅, name ✅, colorId ❌ }
- GET /api/v1/equipments    → EquipmentResult: { id ✅, name ✅, factoryId ✅ }
- GET /api/v1/processes     → ProcessResult:   { id ✅, name ✅, colorId ❌ }
## 미구현 / 부분 구현
- DELETE /api/v1/xxx/{id} ❌ (Controller 없음)
- display_unit 컬럼       ❌ (Flyway 없음)
- conversionRate 필드     ❌ (Domain 모델 없음, Response DTO 없음, JpaAdapter SELECT 없음)
- factories colorId       ❌ (FactoryResult에 없음 → FE 드롭다운 색상 표시 불가)
```

---

### Step 2: Agent D — 사이클 시뮬레이션 (A/B/C 완료 후)

Agent A~C 결과를 입력으로 `invigo-agents:architect-reviewer`를 실행한다.

**목적**: FE→BE→DB 전체 사이클이 현재 구현으로 완주 가능한지 시뮬레이션

> ⚠️ **필드 정합성 판단 시 반드시 Agent C의 Response DTO 필드 목록을 기준으로 한다.**
> FE 로컬 처리 코드(`.find()`, `.map()` 등)는 BE 필드 누락의 증거가 아니다.
> "BE API: 필드 없음 ❌" 판정 전 Agent C에서 Response DTO를 실제 확인했는지 검증한다.

분석 항목: 기획서 핵심 사용자 시나리오(§1.3) 각각에 대해:
- API 존재 여부
- 요청/응답 필드 정합성 (**Response DTO 실제 필드 기준**)
- DB 스키마 충족 여부
- 누락 시 어느 계층에서 막히는지
- ⚠️ **[필수] 폼 렌더링 사이클**: 등록/수정 폼이 실제로 열리기 위해 필요한 마스터 데이터 조회 API들이 FE가 표시에 필요한 필드를 모두 반환하는지

출력 형식:
```
## 시나리오 사이클 분석
### 시나리오: "BOM 행에 displayUnit 선택"
- FE: displayUnit + conversionRate 전송          ✅
- BE API: PATCH /bom-templates/items → 필드 없음  ❌
- DB: display_unit 컬럼 없음                      ❌
- 결론: BLOCKED at BE API (Domain → Flyway 모두 누락)

### 시나리오: "생산계획 등록 폼 열기 → 공장 드롭다운 렌더링"
- FE: GET /api/v1/factories 호출 후 name+colorId로 옵션 렌더링
- BE Response: FactoryResult에 colorId 없음          ❌
- 결론: BLOCKED at 마스터 데이터 조회 Response (폼 자체 렌더링 불가)
```

---

### Step 2.5 (Stage 2 — 직렬 확정 게이트): 단일 verifier 순차 검증 ⚖️ CRITICAL

> **이 단계가 오탐 차단의 핵심이다.** 병렬 그물(Stage 1)이 긁은 후보를
> **하나의 직렬 컨텍스트**에서 한 건씩 검증한다. 병렬 adversarial이
> evidenceAgainst를 적고도 `isReal=true`로 올리던 오판(생산관리 감사 #4)을
> 구조적으로 차단한다 — verifier는 한 관문이라도 막히면 REFUTED로 떨어뜨리지,
> 승격하지 못한다.

Stage 1의 갭 후보 전부를 입력으로 **단일 에이전트**(`code-explorer`, 직렬)를 디스패치한다.
**병렬 금지** — 한 컨텍스트에서 후보를 순번대로 처리해야 누적 판정 일관성이 유지된다.

verifier는 각 후보에 대해 **3관문을 순서대로** 통과시킨다. 하나라도 막히면 즉시 REFUTED + 사유 기록, 다음 후보로.

#### 관문 1 — 소스 진위 (Source Authenticity)
후보의 FE 근거가 **plan-master 라우터 경로**(목업)인가, **실제 HTTP 경로**인가?
- plan-master `apps/liquor`의 `page.tsx`/`useRepository('x')` 경로는 **FE 라우터 경로**이지 REST API가 아니다. `SimpleLocalStorageRepo` 기반 localStorage 목업이다.
- 실제 FE HTTP 경로는 `plan-master/data/bitda-front/packages/services/.../endpoints.ts`에 있다.
- **검증**: 후보의 경로를 endpoints.ts에서 직접 grep. endpoints.ts에 없고 apps/liquor 라우터에만 있으면 → **REFUTED (목업 라우터 경로, REST API 아님)**.
```bash
grep -rn "<후보 경로>" /Users/gimjinhyeog/Desktop/coding/plan-master/data/bitda-front/packages/services --include="*.ts"
```
> "경로 불일치/API경로불일치" 유형 후보는 이 관문에서 대량 REFUTED된다 (2026-06-03 P4/B1/B2/B3/M3 전례).

#### 관문 2 — 현 HEAD 실측 (Current State Truth)
후보가 가리킨 BE 파일을 **현재 HEAD에서 직접 Read**한다. PR 제목·커밋 메시지 신뢰 금지.
- 필드 누락 후보 → 해당 `*Response.kt`/`*Result.kt` + JpaAdapter SELECT + Flyway 컬럼 **셋을 직접 Read**. 하나라도 있으면 갭 아님 → REFUTED.
- API 누락 후보 → 해당 `*Controller.kt` 직접 Read (`@GetMapping`/`@PostMapping` 등 grep).
- production 도메인 후보 → `production-pr-lessons.md`의 해당 규칙 grep + **오탐완화 예외 해당 여부** 직접 확인.
> 인접 PR 함정: 최근 PR이 인접 필드만 채우고 정확히 그 갭은 비켜간 경우가 흔하다(#1986: BomTemplateItemRef 추가하며 materialName 누락). **현 HEAD 파일을 열어 그 필드 1개를 눈으로 확인**하기 전엔 확정/기각 금지.

#### 관문 3 — 영향 실재 (Impact Reality)
이 갭이 FE 시나리오에서 **실제로 막히는가**? FE가 로컬에서 `.find()`/`.map()`으로 가공 가능하면, 또는 FE가 그 경로를 실제 호출하지 않으면 → REFUTED (오탐).

#### verifier 출력 형식 (반드시 이 표로)
```
## Stage 2 직렬 검증 결과

| # | 후보 | 관문1 소스 | 관문2 HEAD | 관문3 영향 | 판정 | 사유/근거(file:line) |
|---|------|-----------|-----------|-----------|------|---------------------|
| 1 | FactoryResult colorId 누락 | ✅ endpoints.ts 존재 | ✅ FactoryResult.kt:23 colorId 없음 | ✅ 드롭다운 색상 표시 불가 | **CONFIRMED** | FactoryResult.kt:23 |
| 2 | /bom/{id} 경로 불일치 | ❌ apps/liquor 라우터 경로 | — | — | **REFUTED** | endpoints.ts에 /bom/{id} 없음, 목업 라우터 |
| 3 | materialName 누락 | ✅ | ✅ BomTemplateItemRef.kt:15 materialId만 | ✅ | **CONFIRMED** | #1986이 인접만 채움 |
```
> REFUTED 건은 표에 남기되 Stage 3 사람 게이트에는 **CONFIRMED만** 올린다.
> verifier가 3관문 중 하나라도 `—`/`❌`면 CONFIRMED 불가. 이 규칙은 강제다.

---

### Step 3 (Stage 3 — 사람 게이트): 갭 통합 분류

> Stage 2에서 **CONFIRMED 판정된 후보만** 여기로 올라온다. REFUTED는 제외.
> 사람은 CONFIRMED 표만 검토하면 된다 (REFUTED 전수 검토 불필요).

Stage 2 verifier의 CONFIRMED 갭을 분류하여 사용자에게 제시:

> ⚠️ **오탐 방지 규칙 (CRITICAL)**
>
> 다음 패턴은 **갭이 아니다**. 이슈 생성 금지:
> - FE가 로컬에서 `array.find()`, `map()` 등으로 데이터를 가공하더라도 BE Response에 해당 필드가 존재하면 → **갭 아님**
> - FE 타입 정의에 필드가 없더라도 BE Response에 존재하면 → **갭 아님**
> - Agent C가 Response DTO에서 필드를 확인하지 않은 채 "누락" 판정 → **판정 보류, 직접 확인 필수**
>
> 갭 판정 기준: **BE Response DTO + JpaAdapter SELECT + Flyway 컬럼** 셋 중 하나라도 없을 때만 갭.

| 갭 유형 | 설명 | 기본 우선순위 |
|--------|------|------------|
| **API 누락** | FE가 호출하는 엔드포인트가 BE에 없음 | High |
| **필드 누락 (생성/수정)** | Request/Response DTO 필드 + JpaAdapter SELECT + DB 컬럼 모두 확인 후 없음 | High |
| **필드 누락 (폼 드롭다운)** | 마스터 데이터 목록 조회 Response에 FE 표시용 필드(name/colorId/isActive 등) 없음 | High |
| **form-data API 누락** | 폼 드롭다운 3개+ 독립 마스터 데이터 조회 시 통합 `GET /xxx/form-data` API 없음 → waterfall 발생 | Medium |
| **비즈니스 규칙 미구현** | 기획서 invariant가 Domain에 없음 | Medium |
| **Swagger 한글 설명 누락** | Request/Response DTO `@Schema(description=...)`가 없거나 빈 값이거나 한글 아님 → Swagger·노션 문서 설명 비어 무용 (전 도메인 공통, 상세 production-pr-lessons.md FP2b) | Medium |
| **정책 미결** | Open Question으로 남은 정책 | Medium |
| **기획서 누락** | FE에 구현됐으나 기획서에 미명시 | Low |

갭 목록 테이블 제시:
```
## 발견된 갭 목록

| # | 유형 | 설명 | 영향 범위 | 예상 크기 |
|---|------|------|---------|---------|
| 1 | API 누락 | DELETE /bom-items/{id} 없음 | BOM 편집 | small |
| 2 | 필드 누락 (생성) | BomTemplateItem.displayUnit/conversionRate | 단위 변환 | medium |
| 3 | 필드 누락 (드롭다운) | FactoryResult에 colorId 없음 → 공장 드롭다운 렌더링 불가 | 생산계획 폼 | small |
| 4 | 비즈니스 규칙 | displayUnit+conversionRate 결합 invariant | Domain | small |
```

---

### Step 4: 이슈 생성 확인 후 실행

> CONFIRMED 갭만 대상. Stage 2에서 REFUTED된 후보는 이슈화 금지.

갭 목록 제시 후 사용자에게 확인:
```
위 [N]개 갭을 발견했습니다.

이슈 생성 방식:
1. 전체 이슈 생성 (N개)
2. 선택 생성 (번호 지정: "1,3,5")
3. 관련 갭 묶어 하나의 이슈로
4. 보고서만 출력 (이슈 생성 없음)
```

승인된 갭에 대해 `issue-create` 스킬 패턴으로 이슈 생성:

```markdown
## 개요
[갭 유형]: [갭 설명]

## 배경
- plan-master FE 코드 근거: [파일경로:라인]
- 기획서 근거: [스펙파일명 §섹션]
- 현재 BE 상태: [있음/없음/부분구현]

## 상세 요구사항
- [ ] [구체적 구현 항목 1]
- [ ] [구체적 구현 항목 2]

## 기술적 고려사항
- CLAUDE.md 적용 원칙: [해당 원칙]
- 선행 이슈: [있으면 명시]

## 완료 기준
- [ ] [검증 가능한 완료 조건]
- [ ] ktlintCheck 통과
```

**라벨 자동 부착 규칙**:
- API 누락 → `feature`, `api-change`
- 필드 누락 (생성/수정) + Flyway → `feature`, `api-change`
- 필드 누락 (폼 드롭다운) → `feature`, `api-change`
- 비즈니스 규칙 → `feature`
- Swagger 한글 설명 누락 → `documentation`, `priority:low`
- 정책 미결 → `feature`, `priority:medium`
- 크기 자동 추정: small(1-2h) / medium(3-8h) / large(1-3d)

---

## 유용한 탐색 명령어

> 전체 탐색 명령어(FE 호출패턴·드롭다운·기획서·Controller·Flyway·Domain·Result·form-data)는
> **`references/search-commands.md`** 참조. 각 Agent는 필요 시 그 파일을 Read한다.
