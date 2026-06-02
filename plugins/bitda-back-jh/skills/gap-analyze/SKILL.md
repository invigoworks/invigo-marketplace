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
> → Agent C가 마스터 데이터 목록 조회 API의 Response 필드를 확인하지 않은 것이 원인.

> **form-data waterfall 사례 (2026-05)**: 폼 진입 시 독립 마스터 데이터를 개별 API로 각각 호출.
> `GET /api/v1/production-plans/form-data` 통합 API가 없어 waterfall 발생.
> → 개별 API 존재 여부만 확인하고 통합 API 유무를 확인하지 않은 것이 원인.

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

탐색 명령어 전체 목록: `references/search-commands.md`를 Read 도구로 로드.

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
  - FE 타입에서 ID 필드 옆에 표시명 필드(`name`, `label`, `code`, `colorId` 등) 함께 있는 패턴 탐지

출력 형식:
```
## FE API 요구사항 (생성/수정)
- POST /api/v1/xxx          → 생성, body: {field1, field2}
- PATCH /api/v1/xxx/{id}    → 수정, body: {field1}
## FE 마스터 데이터 조회 API (폼 드롭다운용)
- GET /api/v1/factories     → FE 사용 필드: id, name, colorId, isActive
- GET /api/v1/equipments    → FE 사용 필드: id, name, factoryId, isActive
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

체크리스트: `references/fe-perspective-checklist.md`를 Read 도구로 로드하여 **A~H 항목 전체**를 도메인별 표로 점검.

분석 항목:
- 구현된 Controller 엔드포인트 (경로 + HTTP 메서드)
- UseCase 인터페이스 + 서비스 구현체 유무
- Domain 모델 필드
- **Response DTO 실제 필드 목록** (XXXResponse, XXXResult 클래스의 val 필드 전체)
- Flyway 마이그레이션 컬럼 현황
- **QueryDSL/JpaAdapter에서 실제 SELECT하는 컬럼 목록**
- ⚠️ **[필수] 폼 드롭다운 마스터 데이터 조회 API Response 필드 검증**
  - FE 폼에서 드롭다운으로 선택하는 모든 참조 엔티티의 Response DTO가 FE 표시 필드(name, code, colorId, isActive 등)를 실제 포함하는지 확인
  - ID만 있고 표시명/코드/상태 필드가 없으면 → **갭 판정**

> ⚠️ **필드 누락 판단 시 반드시 Response DTO를 직접 확인한다.**
> FE가 로컬에서 데이터를 조인/가공하더라도 BE Response에 필드가 존재하면 갭이 아니다.

출력 형식:
```
## 구현된 API
- GET  /api/v1/xxx ✅
- POST /api/v1/xxx ✅
## 체크리스트 매트릭스 (A~H)
| 항목 | 점검 내용 | 결과 | 근거 |
|------|---------|------|------|
| A1   | isActive 포함 여부 | ✅ | XxxResult.isActive 확인 |
| A2   | colorId 포함 여부  | ❌ | XxxResult에 없음 |
## 마스터 데이터 조회 Response 필드 현황
- GET /api/v1/factories     → FactoryResult:   { id ✅, name ✅, colorId ❌ }
## 미구현 / 부분 구현
- DELETE /api/v1/xxx/{id} ❌ (Controller 없음)
- factories colorId       ❌ (FactoryResult에 없음)
```

---

### Step 2: Agent D — 사이클 시뮬레이션 (A/B/C 완료 후)

Agent A~C 결과를 입력으로 `invigo-agents:architect-reviewer`를 실행한다.

**목적**: FE→BE→DB 전체 사이클이 현재 구현으로 완주 가능한지 시뮬레이션

> ⚠️ **필드 정합성 판단 시 반드시 Agent C의 Response DTO 필드 목록을 기준으로 한다.**
> FE 로컬 처리 코드(`.find()`, `.map()` 등)는 BE 필드 누락의 증거가 아니다.

분석 항목: 기획서 핵심 사용자 시나리오 각각에 대해:
- API 존재 여부
- 요청/응답 필드 정합성 (Response DTO 실제 필드 기준)
- DB 스키마 충족 여부
- 누락 시 어느 계층에서 막히는지
- ⚠️ **[필수] 폼 렌더링 사이클**: 등록/수정 폼이 열리기 위한 마스터 데이터 조회 API가 FE 표시 필드를 모두 반환하는지

출력 형식:
```
## 시나리오 사이클 분석
### 시나리오: "BOM 행에 displayUnit 선택"
- FE: displayUnit + conversionRate 전송          ✅
- BE API: PATCH /bom-templates/items → 필드 없음  ❌
- DB: display_unit 컬럼 없음                      ❌
- 결론: BLOCKED at BE API
```

---

### Step 3: Agent E — 체크리스트 검증 (C 완료 후)

Agent C 결과를 입력으로 `caveman:cavecrew-reviewer`를 실행한다.

**목적**: Agent C가 `fe-perspective-checklist.md`의 A~H 항목을 실제 grep으로 확인했는지 검증.
단순 "확인했다"는 서술이 아니라 **실제 코드 파일 경로와 라인 번호**가 근거로 제시된 항목만 ✅ 처리.

검증 기준:
- ✅ 허용: Agent C 출력에 `파일경로:라인번호` 또는 grep 명령어 결과가 포함된 항목
- ❌ 기각: "없는 것으로 보임", "확인 필요" 등 추정성 서술만 있는 항목 → **보류(HOLD)** 처리
- ❌ 기각: Response DTO가 아닌 Request DTO / Entity / DB 컬럼만 확인한 항목 → **재확인 요청**

> `references/fe-perspective-checklist.md`와 `references/search-commands.md`를 Read 도구로 로드하여
> 항목별 검증 grep 명령어를 실행하고 결과를 직접 확인한다.

출력 형식:
```
## 체크리스트 검증 결과
| 항목 | Agent C 근거 | 검증 결과 | 비고 |
|------|------------|---------|------|
| A1 isActive | XxxResult.kt:23 val isActive 확인 | ✅ PASS | |
| A2 colorId  | "없는 것으로 보임" | ❌ HOLD | grep 직접 실행 필요 |
| B2 isActive 필터 | Controller grep 결과 없음 확인 | ✅ PASS (❌ 갭) | |

## HOLD 항목 직접 검증
(grep 명령어 실행 후 결과 기록)
- A2: grep -r "colorId" .../core/src --include="*Result.kt" → 결과 없음 → ❌ 갭 확정
```

HOLD 항목은 Agent E가 직접 grep 실행 후 ✅(존재)/❌(갭) 로 확정한다.
기각된 항목은 갭 목록에서 제외하거나 "미검증" 태그를 붙여 Step 3에 전달한다.

---

### Step 4: 갭 통합 분류

A~E 결과를 수집하여 갭을 분류하고 사용자에게 제시:

> ⚠️ **오탐 방지 규칙 (CRITICAL)**
> - FE 로컬 가공 코드가 있어도 BE Response에 필드 존재하면 → **갭 아님**
> - FE 타입에 필드 없어도 BE Response에 존재하면 → **갭 아님**
> - Agent E가 HOLD 처리한 항목은 직접 grep 결과로만 갭 판정
>
> 갭 판정 기준: **BE Response DTO + JpaAdapter SELECT + Flyway 컬럼** 셋 중 하나라도 없을 때만 갭.

| 갭 유형 | 설명 | 기본 우선순위 |
|--------|------|------------|
| **API 누락** | FE가 호출하는 엔드포인트가 BE에 없음 | High |
| **필드 누락 (생성/수정)** | Request/Response DTO 필드 + JpaAdapter SELECT + DB 컬럼 모두 없음 | High |
| **필드 누락 (폼 드롭다운)** | 마스터 데이터 목록 조회 Response에 FE 표시용 필드 없음 | High |
| **form-data API 누락** | 폼 드롭다운 3개+ 독립 마스터 조회 시 통합 API 없음 → waterfall | Medium |
| **비즈니스 규칙 미구현** | 기획서 invariant가 Domain에 없음 | Medium |
| **정책 미결** | Open Question으로 남은 정책 | Medium |
| **기획서 누락** | FE에 구현됐으나 기획서에 미명시 | Low |

갭 목록 테이블:
```
## 발견된 갭 목록

| # | 유형 | 설명 | 영향 범위 | 예상 크기 |
|---|------|------|---------|---------|
| 1 | API 누락 | DELETE /bom-items/{id} 없음 | BOM 편집 | small |
| 2 | 필드 누락 (생성) | BomTemplateItem.displayUnit/conversionRate | 단위 변환 | medium |
| 3 | 필드 누락 (드롭다운) | FactoryResult에 colorId 없음 | 생산계획 폼 | small |
```

---

### Step 5: 이슈 생성 확인 후 실행

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
- 정책 미결 → `feature`, `priority:medium`
- 크기 자동 추정: small(1-2h) / medium(3-8h) / large(1-3d)
