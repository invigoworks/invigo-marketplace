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

### A. Response 필드 누락 (조회/표시)

- [ ] **A1. isActive 플래그**: 마스터 엔티티 Response에 `isActive` 포함 (FE에서 비활성 항목 회색 처리 필요)
- [ ] **A2. colorId**: 색상 구분 가능한 엔티티(factory, equipment, process)에 `colorId` 포함
- [ ] **A3. sortOrder**: DnD 정렬 지원 엔티티에 `sortOrder` 포함
- [ ] **A4. description**: hover tooltip / 상세 설명 필드
- [ ] **A5. FK 이름 함께 반환**: factoryId 옆에 factoryName, processId 옆에 processName 등 (목록/상세에서 FE 추가 fetch 없이 표시 가능해야)
- [ ] **A6. 하위 집계 (count)**: 마스터-디테일 관계(Factory→Equipment, Process→Task)에서 `equipmentCount`, `taskCount` 등 응답
- [ ] **A7. 감사 필드**: 상세 조회 Response에 `createdAt`, `updatedAt`, `createdBy`, `updatedBy` 포함
- [ ] **A8. 소프트 삭제 정보**: `deletedAt`, `deletedBy` (휴지통 / 복원 UI 사용 시)
- [ ] **A9. version**: 낙관적 락 충돌 알림 UI 필요 시 `version` 응답
- [ ] **A10. status 요약**: 목록에서 상태 분포(완료/미완료 count) 미리보기 필요 시

### B. 마스터 데이터 조회 (드롭다운 / 자동완성)

- [ ] **B1. 단순 GET 목록 API**: 폼 드롭다운에 쓰일 모든 참조 엔티티의 GET /api/v1/xxx 존재
- [ ] **B2. 활성만 필터**: `?isActive=true` 또는 `?includeInactive=false` 파라미터 지원 (등록 폼에서 비활성 항목 숨김)
- [ ] **B3. keyword 검색**: 자동완성용 `?keyword=` 파라미터 지원
- [ ] **B4. 상위 ID 필터**: 종속 드롭다운(공장 선택 → 설비 필터) 위한 `?factoryId=` 등 파라미터
- [ ] **B5. 옵션 마스터 API**: enum 대체 옵션(EquipmentType, VesselMaterial, Unit) 조회 API 또는 정적 enum 노출 방식 확정
- [ ] **B6. 색상 팔레트 API**: colorId 후보값 BE 노출 또는 FE 하드코딩 정책 명시

### C. 목록 조회 부가 기능

- [ ] **C1. 페이지네이션**: 100건 이상 가능한 목록은 page/size 또는 limit/offset 지원
- [ ] **C2. 정렬**: FE 컬럼 헤더 정렬 → BE `sortBy`, `sortOrder` 파라미터 모두 지원
- [ ] **C3. 날짜 범위 필터**: `from`, `to` 파라미터 (생산계획, 입출고 등 시계열 데이터)
- [ ] **C4. 다중 상태 필터**: status 다중 선택 `?status=A&status=B` 지원
- [ ] **C5. 완료 상태 필터**: `completionStatus` (ALL/COMPLETED/INCOMPLETE) 등 비즈니스 상태 필터
- [ ] **C6. 응답 메타**: `{ data, totalCount, page, size }` 페이지네이션 메타데이터 구조

### D. 액션 / 상태 전이

- [ ] **D1. 활성/비활성 토글**: `PATCH /xxx/{id}/active` 같은 토글 API
- [ ] **D2. DnD 순서 변경**: `PATCH /xxx/reorder` (Factory/Equipment 외 도메인도 점검)
- [ ] **D3. 취소/복원**: 소프트 삭제 후 복원 액션 API
- [ ] **D4. 벌크 삭제**: 다중 선택 일괄 삭제 API (`DELETE /xxx?ids=...` 또는 body)
- [ ] **D5. 벌크 상태 변경**: 다중 선택 일괄 활성/비활성/취소
- [ ] **D6. 삭제 가능 여부 사전 체크**: 삭제 전 사용중 여부 조회 API 또는 삭제 실패 응답에 사용처 정보 포함

### E. 에러 응답

- [ ] **E1. ErrorCode 표준**: ApiResponse.error에 enum.name 일관성
- [ ] **E2. 사람 읽을 메시지**: ApiResponse.message에 사용자 노출 가능한 한국어 메시지
- [ ] **E3. 필드 검증 에러 구조**: `@Valid` 실패 시 필드별 에러 배열 반환
- [ ] **E4. 참조 무결성 에러**: 삭제 시 "등록된 X가 N건 있어 삭제 불가" 같은 구체 메시지

### F. 데이터 정합성

- [ ] **F1. 시간 형식**: 시각은 `Instant` (ISO-8601 Z), 날짜는 `LocalDate` (YYYY-MM-DD), 시간은 `LocalTime` (HH:mm)
- [ ] **F2. 소수 정밀도**: 수량/금액은 BigDecimal, FE에서 표시 자릿수 정책 일치
- [ ] **F3. 단위 일관성**: Quantity의 unit 필드 형식 (kg/L/EA 등) FE 표시 매핑 가능
- [ ] **F4. 소프트 삭제 필터**: 목록 조회 시 기본 `deletedAt IS NULL` 자동 필터링
- [ ] **F5. 테넌트 격리**: organizationId 자동 주입 + 다른 조직 데이터 노출 차단 확인

### G. 첨부 / 메모 / 이력

- [ ] **G1. 메모 필드**: 등록/수정 시 memo Request/Response 양방향
- [ ] **G2. 변경 이력 조회**: 수정 히스토리 조회 API 필요 도메인 식별
- [ ] **G3. 첨부파일**: 업로드/다운로드/삭제 API + Response에 attachment list

### H. Export / Import

- [ ] **H1. Excel Export 응답 필드**: FE 표시 컬럼과 Export 컬럼 일치 (displayUnit/conversionRate 등 누락 여부)
- [ ] **H2. Import 검증 응답**: 행별 에러 위치/메시지 반환 구조

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
| **필드 누락 (생성/수정)** | Request/Response DTO 필드 + JpaAdapter SELECT + DB 컬럼 모두 확인 후 없음 | High |
| **필드 누락 (폼 드롭다운)** | 마스터 데이터 목록 조회 Response에 FE 표시용 필드(name/colorId/isActive 등) 없음 | High |
| **form-data API 누락** | 폼 드롭다운 3개+ 독립 마스터 데이터 조회 시 통합 `GET /xxx/form-data` API 없음 → waterfall 발생 | Medium |
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
- 필드 누락 (생성/수정) + Flyway → `feature`, `api-change`
- 필드 누락 (폼 드롭다운) → `feature`, `api-change`
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
