---
name: verify-production
description: 생산관리 모듈의 구조적 일관성을 검증합니다. 생산관리 기능 변경 후 사용.
---

# 생산관리 모듈 검증

## Purpose

생산관리(production) 모듈의 코드 구조와 타입 일관성을 검증합니다:

1. **Barrel Export 누락** — components/index.ts에서 모든 컴포넌트가 export 되는지
2. **타입 정의 일관성** — types.ts에 필요한 타입이 정의되어 있고 mock-data.ts와 일치하는지
3. **컴포넌트 명명 규칙** — Sheet/Dialog/Badge 등 명명 규칙 준수 여부
4. **Screen Code Prefix** — 생산관리 모듈에서 LQ- 접두사 사용 여부
5. **라우터 등록** — 새 페이지가 router.tsx에 등록되어 있는지

## When to Run

- 생산관리 모듈(production/)에 새 파일을 추가한 후
- 생산관리 컴포넌트를 생성하거나 이름을 변경한 후
- 생산관리 타입 정의를 수정한 후
- PR 전 생산관리 모듈 일관성 확인 시

## Related Files

| File | Purpose |
|------|---------|
| `apps/liquor/src/production/components/index.ts` | 공통 컴포넌트 barrel export |
| `apps/liquor/src/production/plan/components/index.ts` | 생산계획 컴포넌트 barrel export |
| `apps/liquor/src/production/plan/types.ts` | 생산계획 타입 정의 |
| `apps/liquor/src/production/plan/mock-data.ts` | 생산계획 목 데이터 |
| `apps/liquor/src/production/plan/detail/page.tsx` | 생산계획 등록/수정 페이지 |
| `apps/liquor/src/production/plan/page.tsx` | 생산계획 목록 페이지 |
| `apps/liquor/src/production/schedule/types.ts` | 생산지시 타입 정의 |
| `apps/liquor/src/production/schedule/mock-data.ts` | 생산지시 목 데이터 |
| `apps/liquor/src/production/schedule/page.tsx` | 생산지시 페이지 |
| `apps/liquor/src/production/process/types.ts` | 공정현황 타입 정의 |
| `apps/liquor/src/production/process/mock-data.ts` | 공정현황 목 데이터 |
| `apps/liquor/src/production/process/page.tsx` | 공정현황 페이지 |
| `apps/liquor/src/production/process/components/index.ts` | 공정현황 컴포넌트 barrel export |
| `apps/liquor/src/production/work-status/components/index.ts` | 작업현황 컴포넌트 barrel export |
| `apps/liquor/src/production/work-status/detail/page.tsx` | 작업현황 상세 페이지 |
| `apps/liquor/src/production/settings/factory/page.tsx` | 공장 설정 페이지 |
| `apps/liquor/src/production/settings/factory/types.ts` | 공장 설정 타입 |
| `apps/liquor/src/production/settings/process/page.tsx` | 공정 설정 페이지 |
| `apps/liquor/src/production/settings/process/types.ts` | 공정 설정 타입 |
| `apps/liquor/src/router.tsx` | 라우트 정의 |

## Workflow

### Step 1: Barrel Export 누락 검증

**검사:** 각 components/ 디렉토리에 있는 .tsx 파일이 해당 index.ts에서 export 되고 있는지 확인합니다.

대상 index.ts 파일:
- `apps/liquor/src/production/components/index.ts`
- `apps/liquor/src/production/plan/components/index.ts`
- `apps/liquor/src/production/process/components/index.ts`
- `apps/liquor/src/production/work-status/components/index.ts`

각 디렉토리에 대해:

```bash
# 디렉토리의 .tsx 파일 목록
ls apps/liquor/src/production/components/*.tsx | xargs -I {} basename {} .tsx

# index.ts의 export 목록
grep "export" apps/liquor/src/production/components/index.ts
```

**PASS:** 모든 .tsx 파일이 index.ts에서 export됨
**FAIL:** .tsx 파일은 있으나 index.ts에서 export되지 않는 컴포넌트 존재

**수정:** 누락된 컴포넌트를 index.ts에 `export { ComponentName } from './ComponentName';` 추가

### Step 2: 타입-MockData 일치 검증

**검사:** types.ts에 정의된 주요 타입의 필드가 mock-data.ts의 데이터 객체와 일치하는지 확인합니다.

대상 모듈:
- plan: `types.ts` ↔ `mock-data.ts`
- schedule: `types.ts` ↔ `mock-data.ts`
- process: `types.ts` ↔ `mock-data.ts`

```bash
# types.ts에서 interface/type 이름 추출
grep -n "export interface\|export type" apps/liquor/src/production/plan/types.ts
```

```bash
# mock-data.ts에서 사용하는 타입 import 확인
grep -n "import.*from.*types" apps/liquor/src/production/plan/mock-data.ts
```

**PASS:** mock-data에서 import하는 타입이 types.ts에 정의되어 있고, 필드가 일치
**FAIL:** 타입 정의와 목 데이터 간 불일치 존재

### Step 3: 컴포넌트 명명 규칙 검증

**검사:** 생산관리 모듈의 컴포넌트가 프로젝트 명명 규칙을 따르는지 확인합니다.

규칙:
- Sheet 컴포넌트: `[Feature]Sheet.tsx`
- Dialog 컴포넌트: `[Feature]Dialog.tsx`
- Table 컴포넌트: `[Feature]Table.tsx`
- Badge 컴포넌트: `[Feature]Badge.tsx` 또는 `[Feature]StatusBadge.tsx`

```bash
ls apps/liquor/src/production/**/components/*.tsx 2>/dev/null
```

**PASS:** 모든 컴포넌트가 명명 규칙 준수
**FAIL:** 규칙에 맞지 않는 이름 존재 (예: `sheet.tsx` 소문자, `MyComp.tsx` 접미사 누락)

### Step 4: Screen Code Prefix 검증

**검사:** 생산관리 모듈에서 screenCode가 `LQ-` 접두사를 사용하는지 확인합니다.

```bash
grep -rn "screenCode\|CM-" apps/liquor/src/production/ --include="*.tsx" --include="*.ts"
```

**PASS:** 모든 screenCode가 `LQ-` 접두사 사용
**FAIL:** `CM-` 접두사가 liquor 앱의 production 모듈에서 발견됨

### Step 5: 라우터 등록 검증

**검사:** production/ 디렉토리의 page.tsx 파일이 router.tsx에 등록되어 있는지 확인합니다.

```bash
# 모든 page.tsx 파일
find apps/liquor/src/production -name "page.tsx" -not -path "*/components/*"

# router.tsx에서 production 관련 라우트
grep "production" apps/liquor/src/router.tsx
```

**PASS:** 모든 page.tsx가 router.tsx에 라우트로 등록됨
**FAIL:** page.tsx는 있으나 router.tsx에 등록되지 않은 페이지 존재

**수정:** router.tsx에 누락된 라우트 추가

## Output Format

```markdown
| # | 검사 | 모듈 | 상태 | 상세 |
|---|------|------|------|------|
| 1 | Barrel Export | components/ | PASS/FAIL | 누락 파일... |
| 2 | 타입-MockData | plan/ | PASS/FAIL | 불일치 필드... |
| 3 | 명명 규칙 | production/ | PASS/FAIL | 위반 파일... |
| 4 | Screen Code | production/ | PASS/FAIL | 잘못된 접두사... |
| 5 | 라우터 등록 | production/ | PASS/FAIL | 미등록 페이지... |
```

## Exceptions

1. **settings 하위 모듈** — `production/settings/factory/` 및 `production/settings/process/`는 별도 barrel export 없이 직접 import 허용
2. **공통 컴포넌트(production/components/)** — 여러 하위 모듈에서 공유하므로 하위 모듈 명명 규칙을 강제하지 않음 (예: `ProductionGanttChart.tsx`는 Feature 접미사 패턴에서 제외)
3. **mock-data의 추가 필드** — mock-data가 타입보다 더 많은 필드를 가진 경우 (테스트용 추가 데이터) 위반이 아님