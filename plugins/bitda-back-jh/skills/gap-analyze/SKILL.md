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

> "FE 화면이 굴러가지 않는다"는 사례를 카테고리별로 망라.
> Agent C는 BE 분석 시 아래 항목 전부를 도메인별로 점검하고,
> Agent D는 시나리오 시뮬레이션 시 누락된 항목을 갭으로 보고한다.

**A~H 상세 항목(38개)은 `references/fe-perspective-checklist.md`에 분리.** Agent C/D는 해당 파일을 Read하여 도메인별 ✅/❌/N/A 표로 점검. 카테고리 요약:

- **A. Response 필드 누락(조회/표시)** — isActive/colorId/sortOrder/FK이름/하위집계/감사필드/soft삭제정보/version/status요약 (A1~A10)
- **B. 마스터 데이터 조회(드롭다운)** — GET목록/활성필터/keyword/상위ID필터/옵션마스터/색상팔레트 (B1~B6)
- **C. 목록 부가** — 페이지네이션/정렬/날짜범위/다중상태/완료상태필터/응답메타 (C1~C6)
- **D. 액션/상태전이** — 활성토글/Reorder/취소복원/벌크삭제/벌크상태/삭제사전체크 (D1~D6)
- **E. 에러 응답** — ErrorCode/메시지/필드검증구조/참조무결성에러 (E1~E4)
- **F. 정합성** — 시간형식/소수정밀도/단위일관성/soft삭제필터/테넌트격리 (F1~F5)
- **G. 첨부/메모/이력** — 메모/변경이력/첨부파일 (G1~G3)
- **H. Export/Import** — Export 컬럼 일치/Import 행별 검증 (H1~H2)

> 📖 각 항목 상세 설명: `references/fe-perspective-checklist.md`

### I. CRUD 라운드트립 (Prepub CRUD 검증 대응)

> **2026-06 피드백**: "Prepub 기준 CRUD를 돌려보니 빈틈 많고, 완전 상이한 게 많다."
> 기존 점검이 Create 위주여서 R/U/D 왕복과 구조 불일치를 놓침. 아래는 필수 점검.

- [ ] **I1. CRUD 4종 완주**: 각 엔티티에 C(POST) / R-목록(GET) / R-단건(GET /{id}) / U(PATCH) / D(DELETE) 전부 점검
- [ ] **I2. 단건 상세 조회**: 수정 폼 초기값을 채우는 `GET /xxx/{id}` 존재 (목록 Response만으론 폼 못 채울 때 필수, 흔한 누락)
- [ ] **I3. 구조 정합성(완전 상이)**: FE 타입 ↔ BE Response의 nested/배열/enum값/응답래퍼/날짜·숫자 타입 일치 (200 응답이어도 파싱 실패 = 버그성 갭)

> 📖 상세 매트릭스 + 탐지 명령어: `references/crud-roundtrip-matrix.md` (Agent C/D 실행 시 Read)

### J. Production PR 학습 갭 (production/BOM 도메인 한정)

> **출처**: 머지된 production/BOM PR 82개 마이닝(2026-06). 사후 수정된 갭을 사전 탐지 규칙화.
> production·BOM·생산계획·공정현황 도메인 분석 시 **반드시** `references/production-pr-lessons.md`를 Read하여 아래를 추가 점검.

- [ ] **J1. 참조 무결성**(RI): 삭제·생성 검증 쿼리의 soft-delete(`deletedAt`)/organizationId 필터, orphan FK cascade, cross-material 오염 — #1927/#1924/#1939
- [ ] **J2. DB 제약**(DB): Flyway 버전 중복, enum 값 변경↔CHECK 제약 동기화, FK ON DELETE 정책 — #1857/#1901/#1902
- [ ] **J3. API 계약/직렬화**(API): 409 매핑, 제한검증 BusinessException, `@JsonProperty` 키 일치, summary 필터 반영, 비상관 JOIN 중복 — #1855/#1835/#1914/#1957/#1917
- [ ] **J4. 필드 전파**(FP): Request→Command→Service→Response 전파 끊김(write 미연결), `@Schema`, enum 크기 하드코딩 — #1954/#1891/#1735
- [ ] **J5. Cutover**(CUT): JSONB↔테이블 dual-write 트랜잭션 원자성, cutover Phase 단계 추적 — #1926/#1930

> 📖 각 규칙의 grep 명령어 + 예외 정책 + 근거 PR: `references/production-pr-lessons.md`

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

### Step 1: A/B/C 에이전트 병렬 디스패치

다음 3개 에이전트를 **동시에** 실행한다.

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

⚠️ **[필수] CRUD 라운드트립 매트릭스 작성**: `references/crud-roundtrip-matrix.md`를 Read하여
도메인의 **각 엔티티마다 C/R-목록/R-단건/U/D 4종 매트릭스**를 ✅/⚠️/❌/N/A로 채운다.
특히 **단건 상세 조회(`GET /{id}`)** 누락과 **FE 타입↔BE Response 구조 불일치(nested/배열/enum값)**를 점검.

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
- ⚠️ **[필수] CRUD 라운드트립 완주**: Agent C의 CRUD 매트릭스(`references/crud-roundtrip-matrix.md`)를 입력으로, 각 엔티티가 C→R-목록→R-단건→U→D 전체를 완주하는지 + 구조 정합성(S1~S8) 검증. 구조 불일치는 200 응답이어도 **버그성 갭(High)**으로 승격

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

### Step 3: 갭 통합 분류

A~D 결과를 수집하여 갭을 분류하고 사용자에게 제시:

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
| **CRUD 누락 (단건 조회)** | 수정 폼용 `GET /xxx/{id}` 없어 수정 진입 불가 | High |
| **구조 불일치 (완전 상이)** | FE 타입↔BE Response의 nested/배열/enum값/래퍼 불일치 (200이어도 파싱 실패) | High |
| **필드 누락 (생성/수정)** | Request/Response DTO 필드 + JpaAdapter SELECT + DB 컬럼 모두 확인 후 없음 | High |
| **필드 누락 (폼 드롭다운)** | 마스터 데이터 목록 조회 Response에 FE 표시용 필드(name/colorId/isActive 등) 없음 | High |
| **form-data API 누락** | 폼 드롭다운 3개+ 독립 마스터 데이터 조회 시 통합 `GET /xxx/form-data` API 없음 → waterfall 발생 | Medium |
| **참조 무결성 결함** | soft-delete/organizationId 필터 누락, orphan FK, cross-material 오염 (J1) | High |
| **DB 제약 불일치** | Flyway 버전 충돌, enum↔CHECK 미동기화 (J2) | High |
| **API 계약/직렬화 결함** | 잘못된 상태코드, require()→500, JSON 키 불일치, 비상관 JOIN 중복 (J3) | High |
| **필드 전파 끊김** | Request 필드가 Command/Service/Response 어딘가서 누락 (write 미연결) (J4) | High |
| **Cutover 안전성** | JSONB↔테이블 dual-write 비원자성 (J5) | High |
| **비즈니스 규칙 미구현** | 기획서 invariant가 Domain에 없음 | Medium |
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
- CRUD 누락 (단건 조회) → `feature`, `api-change`
- 구조 불일치 (완전 상이) → `bug`, `api-change`
- 필드 누락 (생성/수정) + Flyway → `feature`, `api-change`
- 필드 누락 (폼 드롭다운) → `feature`, `api-change`
- 참조 무결성 결함 (J1) → `bug`, `data-consistency`
- DB 제약 불일치 (J2) → `bug`, `db-migration`
- API 계약/직렬화 결함 (J3) → `bug`, `api-change`
- 필드 전파 끊김 (J4) → `bug`, `api-change`
- Cutover 안전성 (J5) → `bug`, `cutover`
- 비즈니스 규칙 → `feature`
- 정책 미결 → `feature`, `priority:medium`
- 크기 자동 추정: small(1-2h) / medium(3-8h) / large(1-3d)

---

## 유용한 탐색 명령어

FE API 호출 패턴 찾기:
```bash
grep -r "useRepository\|fetch(\|axios\.\|\.get(\|\.post(\|\.patch(\|\.delete(" \
  /Users/gimjinhyeog/Desktop/coding/plan-master/apps/liquor/src/{domain} \
  --include="*.ts" --include="*.tsx" -n
```

FE 드롭다운 데이터 조회 패턴 찾기 (마스터 데이터):
```bash
grep -r "useRepository\|useFetch\|useQuery" \
  /Users/gimjinhyeog/Desktop/coding/plan-master/apps/liquor/src/{domain} \
  --include="*.ts" --include="*.tsx" -n \
  | grep -v "POST\|PATCH\|PUT\|DELETE"
```

기획서 파일 목록:
```bash
find /Users/gimjinhyeog/Desktop/coding/plan-master/docs/specs/liquor \
  -name "*.md" | sort
```

BE Controller 목록:
```bash
find /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/api/src \
  -name "*Controller.kt" | sort
```

Flyway 마이그레이션 목록:
```bash
find /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/infrastructure/src \
  -name "V*.sql" | sort | tail -20
```

Domain 모델 필드 확인:
```bash
grep -r "val \|var " \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/domain/src \
  --include="*.kt" -n | grep -v "//\|test\|Test"
```

마스터 데이터 조회 Result 클래스 필드 확인:
```bash
grep -r "data class\|val " \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/core/src \
  --include="*Result.kt" -n | grep -v "test\|Test"
```

form-data 통합 API 존재 여부 확인 (없으면 form-data API 누락 갭):
```bash
# 도메인별 form-data 엔드포인트 확인
grep -r "form-data\|formData\|FormData" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/api/src \
  --include="*.kt" -n | grep -i "GetMapping\|RequestMapping"
# 결과 없으면 → 해당 도메인 form-data API 갭 판정
```

---

## 📊 J. Production PR 특화 갭 탐지 (신규, 2026-06)

> **출처**: Production/BOM cutover PR 학습 규칙 (§production-pr-lessons.md)
> Agent C는 아래 체크리스트를 도메인별로 점검하고, Agent D는 구조 불일치를 버그성으로 승격.

### J1. Soft-Delete & Referential Integrity

- [ ] **F1. soft-delete 필터 누락**: 참조검증 쿼리(`existsBy`, `countBy`)에서 `deletedAt IS NULL` 조건
  - 탐지: `grep -r 'existsBy.*Equipment' ... | grep -v 'deletedAt'`
  - 예외: `reconstitute()` 패턴, test fixture, native SQL `@Query`
  - 근거: #1927, #1803 (High)

- [ ] **F2. organizationId 필터 누락**: 삭제 전 참조검증 시 테넌트 격리 부재
  - 탐지: `grep -r 'existsBy.*Port' ... -A2 | grep -E 'fun.*existsBy'` → organizationId 확인
  - 예외: 내부 도메인 간 참조, 시스템 관리자 권한
  - 근거: #1924 (High)

- [ ] **F3. FK 제약 정책 미정의**: Flyway 마이그레이션의 `ON DELETE RESTRICT/CASCADE/SET NULL`
  - 탐지: `grep -r 'FOREIGN KEY' ... | grep -v 'ON DELETE'`
  - 예외: 다대다 교차테이블(CASCADE 기본), soft-delete 엔티티
  - 근거: #1902 (Medium)

- [ ] **F4. Cascade fallback 필터 누락**: 마스터 삭제 시 parent aggregate 기준 필터 부재
  - 탐지: `grep -r 'DeleteMaterial.*Service' ... | grep -v 'where.*materialId'`
  - 예외: 전체 조직 일괄 정책(ADR 문서화), 테스트
  - 근거: #1939 (High)

- [ ] **F5. Flyway 버전 정합성**: V*.sql 버전 번호 중복/누락 검사
  - 탐지: `find ... -name 'V*.sql' | sort | uniq -d`
  - 근거: #1857 (High)

### J2. API Response & Error Handling

- [ ] **E1. DataIntegrityViolation 상태 코드**: 409(CONFLICT) 여부 (422 아님)
  - 탐지: GlobalExceptionHandler에서 `UNPROCESSABLE_ENTITY` 사용 여부
  - 근거: #1855 (Medium)

- [ ] **E2. 제한 검증 예외 타입**: 비즈니스 제한은 `BusinessException` 사용 (require() 아님)
  - 탐지: `grep -r 'require.*>' ... | grep -v 'BusinessException'`
  - 예외: Domain 모델의 `require()`는 도메인 불변식 (500 허용)
  - 근거: #1835 (High)

- [ ] **H1. Import 행별 FK 검증**: Excel/CSV 각 행의 외래키 존재성 확인
  - 탐지: `grep -r 'ImportProductionPlanService' ... | grep -E 'warehouseRepository|itemRepository'`
  - 예외: create-if-not-exists 정책, 읽기 전용 import
  - 근거: #1859 (High)

### J3. API Documentation & Field Propagation

- [ ] **J1. @Schema 표준화**: Request/Response DTO의 모든 필드에 `@Schema(description)` 적용
  - 탐지: `find .../api/src -name '*Response.kt' | xargs grep -L '@Schema'`
  - 예외: 내부 DTO(Command/Query/Result), 상속 필드, deprecated DTO
  - 근거: #1891, #1882 (Medium)

- [ ] **J2. 용어 일관성**: Swagger description의 도메인 용어(재료/원재료) 혼용 검사
  - 탐지: `grep -r '@Parameter.*description' ... | grep -i '재료'`
  - 예외: 기술 용어, 외부 API 용어, 버전 마이그레이션 기간
  - 근거: #1761 (Low)

- [ ] **J3. Summary 필터 격리**: 목록 API와 summary API가 동일 WHERE 절 사용
  - 탐지: `grep -r 'summarizeBy' ... | grep -v 'buildWhere'`
  - 예외: 조직 단위 dashboard, 시스템 관리, 캐시된 summary
  - 근거: #1957 (Medium)

- [ ] **J4. 엔드포인트 중복/혼동**: 동일 리소스의 다중 경로 의도 문서화
  - 탐지: 같은 리소스를 조회하는 다중 경로 확인
  - 근거: #1887 (Low)

- [ ] **J5. Dual-Write 안전성**: cutover JSONB↔table 동시 쓰기의 원자성 보장
  - 탐지: `grep -r 'repository.save' ... -B2 -A2` → 트랜잭션 경계 확인
  - 예외: eventually-consistent cutover(outbox), feature flag, 테스트
  - 근거: #1926 (High)

- [ ] **J6. Cutover 진행 추적**: Phase별 JSONB→table 단계 문서화
  - 탐지: `grep -r 'Phase.*1\|Phase.*2\|cutover.*write'`
  - 근거: #1930 (Medium)

📖 **상세 탐지 명령어 및 예외**: `references/production-pr-lessons.md` 참조
