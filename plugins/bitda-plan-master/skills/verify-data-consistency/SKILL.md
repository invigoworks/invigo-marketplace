---
name: verify-data-consistency
description: 타입-스키마 동기화, mock 데이터 비즈니스 규칙 준수, 레코드/품목 레벨 속성 정합성을 검증합니다. 타입/스키마/mock 데이터 변경 후 사용.
---

# 데이터 정합성 검증

## Purpose

코드 내 데이터 정의와 비즈니스 규칙 간의 정합성을 검증합니다:

1. **Zod 스키마 - TypeScript 타입 동기화** — types.ts에 정의된 union/enum 값이 Zod 스키마의 z.enum()에 모두 포함되는지 검증
2. **Mock 데이터 - 비즈니스 규칙 정합성** — mock 데이터의 값이 비즈니스 규칙(예: DIRECT_DISPOSAL → 세액=0)과 일치하는지 검증
3. **레코드 레벨 vs 품목 레벨 속성 배치** — 품목별로 다를 수 있는 속성(처리유형, 폐기사유 등)이 레코드 레벨 UI(기본정보)에 잘못 배치되지 않았는지 검증

## When to Run

- types.ts에 새 타입/enum을 추가하거나 수정한 후
- Zod validation 스키마를 변경한 후
- mock 데이터를 생성하거나 수정한 후
- 상세 페이지 기본정보 섹션을 수정한 후
- 비즈니스 규칙이 변경된 후

## Related Files

| File | Purpose |
|------|---------|
| `apps/liquor/src/inventory/return-disposal/types.ts` | 환입/폐기 타입 정의 |
| `apps/liquor/src/inventory/return-disposal/utils/validation.ts` | Zod 유효성 검증 스키마 |
| `apps/liquor/src/inventory/return-disposal/utils/tax-calculation.ts` | 세액 계산 비즈니스 규칙 |
| `apps/liquor/src/inventory/return-disposal/mock-data/return-disposal-records.ts` | 레코드 목 데이터 |
| `apps/liquor/src/inventory/return-disposal/mock-data/detail-items.ts` | 품목 목 데이터 |
| `apps/liquor/src/inventory/return-disposal/detail-page.tsx` | 상세 페이지 (기본정보 레이아웃) |

## Workflow

### Step 1: Zod 스키마 - types.ts 동기화 검증

**검사:** types.ts에 정의된 `type Xxx = 'A' | 'B' | 'C'` 형태의 union 타입이 해당 모듈의 Zod 스키마에서 `z.enum(['A', 'B', 'C'])`와 동일한 값을 가지는지 확인합니다.

**탐지:**

```bash
# types.ts에서 union 타입 추출
grep -n "export type.*=" apps/*/src/**/types.ts | grep "|"
```

```bash
# validation.ts에서 z.enum 추출
grep -n "z.enum" apps/*/src/**/validation.ts
```

각 union 타입의 값 목록과 대응하는 z.enum의 값 목록을 비교합니다.

**PASS 기준:**
- types.ts의 모든 union 값이 z.enum에 포함됨
- z.enum에 types.ts에 없는 값이 없음

**FAIL 기준:**
- types.ts에 `'MIXED'`가 있지만 z.enum에 누락
- z.enum에 값이 추가되었지만 types.ts에 반영되지 않음

**수정:**
```typescript
// types.ts
export type IncidentType = 'FACTORY_RETURN' | 'TRANSIT_LOSS' | 'DIRECT_DISPOSAL' | 'MIXED';

// validation.ts - 반드시 동기화
incidentType: z.enum(['FACTORY_RETURN', 'TRANSIT_LOSS', 'DIRECT_DISPOSAL', 'MIXED']),
```

### Step 2: Mock 데이터 - 비즈니스 규칙 정합성 검증

**검사:** mock 데이터의 값이 비즈니스 규칙과 일치하는지 확인합니다.

**주요 비즈니스 규칙:**
- `DIRECT_DISPOSAL` (직접폐기) → `liquorTax: 0`, `educationTax: 0`, `traditionalExemption: 0`
- `RESTOCK` (재보관) → `liquorTax: 0`, `educationTax: 0` (세액 환급 대상 아님)
- `evidenceRequiredCount`: RESTOCK이면 0 (증빙 면제), 그 외는 1 이상

**탐지:**

```bash
# DIRECT_DISPOSAL 레코드에서 세액이 0이 아닌 것 찾기
grep -A 15 "DIRECT_DISPOSAL" apps/*/src/**/mock-data/*.ts | grep -E "liquorTax:|educationTax:" | grep -v ": 0"
```

```bash
# RESTOCK 품목에서 세액이 0이 아닌 것 찾기
grep -B 5 -A 10 "RESTOCK" apps/*/src/**/mock-data/detail-items.ts | grep -E "liquorTax:|educationTax:" | grep -v ": 0"
```

```bash
# RESTOCK 품목에서 evidenceRequiredCount가 0이 아닌 것 찾기
grep -B 5 -A 15 "RESTOCK" apps/*/src/**/mock-data/detail-items.ts | grep "evidenceRequiredCount" | grep -v ": 0"
```

**PASS 기준:**
- DIRECT_DISPOSAL 레코드/품목의 모든 세액 필드가 0
- RESTOCK 품목의 모든 세액 필드가 0
- RESTOCK 품목의 evidenceRequiredCount가 0

**FAIL 기준:**
- DIRECT_DISPOSAL인데 세액이 0이 아님
- RESTOCK인데 세액이 0이 아니거나 증빙이 필요하다고 표시됨

### Step 3: 레코드 vs 품목 레벨 속성 배치 검증

**검사:** 상세 페이지(detail-page.tsx)의 기본정보 섹션에 품목별로 달라질 수 있는 속성이 잘못 표시되지 않는지 확인합니다.

**품목 레벨 속성 (기본정보에 있으면 안 됨):**
- `incidentType` (처리유형) — MIXED 레코드에서는 품목별로 다름
- `disposalReason` (폐기사유) — 품목별로 다를 수 있음
- `postReturnAction` (환입 후 처리) — 품목별로 다를 수 있음

**탐지:**

```bash
# detail-page.tsx 기본정보 섹션에서 품목 레벨 속성 표시 여부
grep -n "incidentType\|disposalReason\|postReturnAction" apps/*/src/**/*detail-page*.tsx
```

해당 라인이 기본정보 그리드(`grid grid-cols`) 내부인지, 품목 테이블 내부인지 확인합니다.

**PASS 기준:**
- 품목 레벨 속성은 품목 테이블 컬럼에서만 표시
- 기본정보에는 레코드 레벨 속성만 표시 (관리번호, 요청일, 창고, 담당자, 증빙현황, 세무상태 등)

**FAIL 기준:**
- 기본정보 그리드에서 `record.incidentType`, `record.disposalReason` 등이 직접 렌더링됨
- MIXED 타입 레코드에서 기본정보의 처리유형이 단일 값으로 표시됨

### Step 4: 레코드 목 데이터 - 품목 목 데이터 존재 검증

**검사:** 레코드 목록에 있는 모든 레코드 ID에 대해 품목(detail-items) 데이터가 존재하는지 확인합니다.

**탐지:**

```bash
# 레코드 목록의 ID 추출
grep "id:" apps/*/src/**/mock-data/return-disposal-records.ts | grep -oP "'[^']+'"
```

```bash
# 품목 데이터의 레코드 ID 키 추출
grep -oP "^\s+[A-Z]+\d+:" apps/*/src/**/mock-data/detail-items.ts
```

두 목록을 비교하여 품목 데이터가 누락된 레코드를 찾습니다.

**PASS:** 모든 레코드 ID에 대해 품목 데이터 존재
**FAIL:** 레코드는 있지만 품목 데이터가 없는 ID 존재

## Output Format

```markdown
| # | 검사 | 파일 | 상태 | 상세 |
|---|------|------|------|------|
| 1 | Zod-types 동기화 | validation.ts | PASS/FAIL | 누락된 enum 값 |
| 2 | Mock 비즈니스 규칙 | records.ts | PASS/FAIL | 규칙 위반 레코드 |
| 3 | 속성 레벨 배치 | detail-page.tsx | PASS/FAIL | 잘못 배치된 속성 |
| 4 | 레코드-품목 매핑 | detail-items.ts | PASS/FAIL | 누락된 품목 데이터 |
```

## Exceptions

다음은 **위반이 아닙니다**:

1. **의도적 0 세액** — 전통주 감면으로 인해 세액이 0인 경우는 DIRECT_DISPOSAL/RESTOCK이 아니어도 정상
2. **MIXED 레코드의 대표값** — 목록 페이지에서 MIXED 레코드가 대표 처리유형을 표시하는 것은 허용 (기본정보가 아닌 목록 테이블)
3. **개발 중 임시 mock 데이터** — 아직 구현 중인 기능의 mock 데이터는 불완전할 수 있음 (완성 후 검증)
4. **테스트용 극단값** — 테스트 목적으로 의도적으로 규칙에 어긋나는 데이터를 넣은 경우 (주석으로 표시되어야 함)
