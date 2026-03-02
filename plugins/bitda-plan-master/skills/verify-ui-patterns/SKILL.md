---
name: verify-ui-patterns
description: UI 컴포넌트 사용 일관성 검증 (toast, TableWrapper, SortableHeader, import 순서, 숫자 컬럼 정렬, 상세 기본정보 그리드, FK 링크, 그리드 컬럼 적합성, 마이그레이션 기능 소실)
---

# UI 패턴 검증

## Purpose

프로젝트 전체에서 UI 컴포넌트 사용 패턴의 일관성을 검증합니다:

1. **Toast 라이브러리** — sonner 사용 강제, useToast(shadcn) 사용 금지
2. **공통 컴포넌트 재사용** — TableWrapper, SortableHeader, BulkDeleteButton 등 web-platform 컴포넌트 사용 여부
3. **테이블 정렬 설정** — select/action/icon 컬럼에 enableSorting: false 적용 여부
4. **Import 순서** — React/External → Internal packages → Local 순서 준수

## When to Run

- UI 컴포넌트를 추가하거나 수정한 후
- 새로운 페이지나 테이블을 생성한 후
- PR 전 UI 일관성 확인 시
- web-platform 패키지 컴포넌트를 변경한 후

## Related Files

| File | Purpose |
|------|---------|
| `packages/web-platform/src/components/TableWrapper.tsx` | 테이블 래핑 공통 컴포넌트 |
| `packages/web-platform/src/components/SortableHeader.tsx` | 정렬 가능 테이블 헤더 |
| `packages/web-platform/src/components/BulkDeleteButton.tsx` | 벌크 삭제 버튼 |
| `packages/web-platform/src/components/SearchInput.tsx` | 검색 입력 컴포넌트 |
| `packages/web-platform/src/components/ConfirmActionDialog.tsx` | 확인 다이얼로그 |
| `packages/web-platform/src/components/DownloadButton.tsx` | 다운로드 버튼 |
| `packages/web-platform/src/components/StatusBadge.tsx` | 상태 뱃지 |
| `packages/web-platform/src/components/CRUDPageLayout.tsx` | CRUD 페이지 레이아웃 |
| `packages/web-platform/src/components/index.ts` | web-platform 컴포넌트 barrel export |

## Workflow

### Step 1: Toast 라이브러리 검증

**검사:** `useToast`가 앱 코드에서 사용되고 있는지 확인합니다. sonner의 `toast`만 허용됩니다.

```bash
grep -rn "useToast" apps/liquor/src/ apps/manufacturing/src/ --include="*.tsx" --include="*.ts"
```

**PASS:** `useToast` 사용이 0건
**FAIL:** `useToast`를 import하거나 호출하는 파일이 존재

**수정:** `useToast` → `import { toast } from 'sonner'` 로 교체

### Step 2: TableWrapper 사용 검증

**검사:** `<Table>` 컴포넌트를 사용하는 페이지에서 `TableWrapper`로 감싸고 있는지 확인합니다.

```bash
grep -rn "<Table " apps/liquor/src/ --include="*.tsx" -l
```

위 파일 목록에서 `TableWrapper` import가 있는지 대조합니다:

```bash
grep -rn "TableWrapper" apps/liquor/src/ --include="*.tsx" -l
```

**PASS:** `<Table>` 사용 파일과 `TableWrapper` 사용 파일이 일치
**FAIL:** `<Table>`을 사용하면서 `TableWrapper`가 없는 파일 존재

**수정:** `<Table>` 을 `<TableWrapper><Table>...</Table></TableWrapper>`로 감싸기

### Step 3: SortableHeader 및 enableSorting 검증

**검사:** 테이블 컬럼 정의에서 select/action/icon 컬럼에 `enableSorting: false`가 적용되어 있는지 확인합니다.

```bash
grep -rn "accessorKey.*select\|accessorKey.*action\|id.*select\|id.*action" apps/liquor/src/ --include="*.tsx" --include="*.ts"
```

해당 컬럼 정의 근처에 `enableSorting: false`가 있는지 확인합니다.

**PASS:** select/action/icon 컬럼에 모두 `enableSorting: false` 적용
**FAIL:** select/action 컬럼에 `enableSorting` 미설정

### Step 4: Import 순서 검증

**검사:** 변경된 파일에서 import 순서가 규칙을 따르는지 확인합니다.

규칙:
1. React/External (`react`, `@tanstack`, `sonner`, `zod` 등)
2. Internal packages (`@bitda/web-platform`, `@bitda/core` 등)
3. Local (`./`, `../` 등)

```bash
grep -n "^import" <changed-file> | head -20
```

각 그룹 사이에 빈 줄이 있어야 합니다.

**PASS:** import 그룹이 올바른 순서이고 그룹 사이에 빈 줄 존재
**FAIL:** import 순서가 뒤섞이거나 그룹 구분이 없음

### Step 5: 공통 컴포넌트 중복 생성 검증

**검사:** 앱 레벨에서 web-platform에 이미 존재하는 컴포넌트와 유사한 이름의 컴포넌트가 새로 생성되었는지 확인합니다.

```bash
ls packages/web-platform/src/components/ | sed 's/.tsx//'
```

위 목록과 새로 생성된 컴포넌트 이름을 대조합니다.

**PASS:** 중복 없음
**FAIL:** web-platform에 이미 존재하는 컴포넌트와 유사한 이름의 로컬 컴포넌트 존재

### Step 6: 숫자 컬럼 정렬 검증

**검사:** 테이블에서 숫자 데이터를 표시하는 컬럼(수량, 금액, 세액 등)에 `text-right`과 `tabular-nums`가 적용되어 있는지 확인합니다.

**헤더 정렬 검사:**
```bash
# 숫자성 헤더 키워드가 있는 TableHead에서 text-right 누락 확인
grep -n "TableHead.*수량\|TableHead.*금액\|TableHead.*세\|TableHead.*price\|TableHead.*amount\|TableHead.*quantity\|TableHead.*total" apps/liquor/src/ -r --include="*.tsx"
```

해당 라인에 `text-right` 클래스가 포함되어 있는지 확인합니다. SortableHeader를 사용하는 경우 `<div className="flex justify-end">` 래퍼로 우측 정렬합니다.

**셀 정렬 검사:**
숫자 데이터를 포맷(formatNumber, formatLiter, formatCurrency 등)하는 TableCell에 `text-right tabular-nums`가 포함되어야 합니다.

```bash
grep -n "formatNumber\|formatLiter\|formatCurrency\|formatPrice" apps/liquor/src/ -r --include="*.tsx"
```

**PASS:** 숫자 컬럼의 헤더와 셀에 모두 우측 정렬 + `tabular-nums` 적용
**FAIL:** 숫자 데이터가 좌측 정렬이거나 `tabular-nums` 누락

**수정:**
- 헤더: `<TableHead className="text-right">` 또는 SortableHeader 래핑 `<div className="flex justify-end"><SortableHeader .../></div>`
- 셀: `<TableCell className="text-sm text-right tabular-nums">`

### Step 7: EmptyTableRow 사용 검증

**검사:** 테이블의 빈 상태(데이터 0건)에서 커스텀 empty state 대신 플랫폼 `EmptyTableRow`를 사용하는지 확인합니다.

**감지 패턴: 인라인 empty state**
```bash
grep -rn "colSpan.*데이터.*없\|colSpan.*항목.*없\|colSpan.*결과.*없" apps/*/src/ --include="*.tsx"
```

위 결과에서 `EmptyTableRow` import 없이 직접 `<TableRow><TableCell colSpan=...>` 패턴을 사용하는 파일을 찾습니다.

```bash
grep -rn "EmptyTableRow" apps/*/src/ --include="*.tsx" -l
```

**PASS:** 모든 테이블의 빈 상태가 `EmptyTableRow` 사용
**FAIL:** 커스텀 `<TableRow><TableCell colSpan>텍스트</TableCell></TableRow>` 패턴 존재

**수정:**
```tsx
// Before (커스텀)
{rows.length === 0 && (
  <TableRow>
    <TableCell colSpan={columns.length} className="text-center py-8 text-muted-foreground">
      데이터가 없습니다.
    </TableCell>
  </TableRow>
)}

// After (플랫폼)
{rows.length === 0 && (
  <EmptyTableRow colSpan={columns.length} message="데이터가 없습니다." />
)}
```

### Step 8: 플랫폼 이관 후 로컬 dead code 검증

**검사:** `@plan-master/web-platform`에서 import하면서 동일 이름의 로컬 컴포넌트가 남아있는지, barrel export(index.ts)에 삭제된 컴포넌트가 남아있는지 확인합니다.

**감지 패턴 A: 플랫폼 import와 동일 이름의 로컬 파일**
```bash
# 플랫폼에서 import하는 컴포넌트 이름 추출
grep -roh "import.*from '@plan-master/web-platform'" apps/*/src/ --include="*.tsx" | grep -oP '\b[A-Z][a-zA-Z]+\b' | sort -u
```

해당 이름의 로컬 파일이 같은 모듈의 `components/` 디렉토리에 존재하는지 확인합니다.

**감지 패턴 B: barrel export에서 존재하지 않는 파일 참조**
```bash
# 각 components/index.ts에서 export하는 파일이 실제 존재하는지 확인
grep -rn "export.*from" apps/*/src/**/components/index.ts --include="*.ts"
```

**PASS:** 로컬 dead code 0건, barrel export 정리 완료
**FAIL:** 플랫폼으로 이관했으나 로컬 사본이 남아있거나, 삭제된 파일의 barrel export가 남아있음

**수정:**
1. 로컬 사본 삭제 (`rm components/DeleteDialog.tsx`)
2. barrel export에서 해당 라인 제거 (`index.ts`)
3. import 경로를 플랫폼으로 변경

### Step 9: 상세 페이지 기본 정보 컴팩트 그리드 검증

**검사:** `detail-page.tsx` 파일의 기본 정보 섹션이 컴팩트 그리드 패턴을 따르는지 확인합니다.

**표준 패턴:**
```tsx
<Card>
  <CardContent className="px-4 py-3">
    <h3 className="font-semibold text-sm mb-2">기본 정보</h3>
    <div className="grid grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-x-6 gap-y-1.5 text-sm">
      <div>
        <span className="text-muted-foreground text-xs">라벨</span>
        <div>값</div>
      </div>
      ...
    </div>
  </CardContent>
</Card>
```

**필수 규칙:**
- **그리드 컬럼**: `lg:grid-cols-6` 이상으로 lg 화면에서 2줄 이내 표현
- **셀 구조**: 세로 배치 (위: 라벨 `text-xs text-muted-foreground`, 아래: 값)
- **카드 패딩**: `px-4 py-3` (p-6, p-8 등 넓은 패딩 금지)
- **행 간격**: `gap-y-1.5` (gap-y-3 이상 금지)

**감지 패턴:**
```bash
# detail-page.tsx에서 기본 정보 섹션 찾기
grep -rn "기본 정보" apps/*/src/**/detail-page.tsx --include="*.tsx"
```

해당 라인 근처에서 다음을 확인:
1. `lg:grid-cols-6` (또는 5 이상) 존재 여부
2. `text-xs` 라벨 패턴 사용 여부
3. `gap-y-1.5` 적용 여부
4. `flex flex-wrap` (인라인 나열) 패턴 사용 금지

**금지 패턴:**
```tsx
// ❌ flex-wrap 인라인 나열 (규격 없음)
<div className="flex flex-wrap items-center gap-x-4 gap-y-2">
  <span className="text-muted-foreground">라벨:</span> <span>값</span>
</div>

// ❌ 좌우 justify-between 2컬럼 (공간 낭비)
<div className="grid grid-cols-2 gap-y-3 gap-x-8">
  <div className="flex justify-between">
    <span>라벨</span><span>값</span>
  </div>
</div>

// ❌ 넓은 패딩 + 넓은 간격
<CardContent className="p-6">
  <div className="grid ... gap-6">
```

**PASS:** 모든 detail-page.tsx의 기본 정보가 컴팩트 그리드 패턴 준수
**FAIL:** 비표준 레이아웃 (flex-wrap, justify-between, 넓은 패딩/간격)

**수정:** 표준 패턴으로 교체 — 세로 라벨-값 그리드, lg:grid-cols-6, px-4 py-3

### Step 10: FK 참조 네비게이션 링크 검증

**검사:** 상세 페이지(detail-page.tsx)의 기본 정보에서 다른 엔티티를 참조하는 필드(판매서번호, 거래처, 발주번호 등)에 클릭 시 해당 상세 페이지로 이동하는 링크가 있는지 확인합니다.

**배경:** FK 참조 필드가 단순 텍스트로만 표시되면 사용자가 관련 데이터를 확인하기 위해 별도로 검색해야 합니다.

**탐지:**

```bash
# 상세 페이지에서 Number/Id 필드가 있지만 navigate/Link가 없는 패턴
grep -rn "OrderNumber\|orderNumber\|salesOrderNumber\|purchaseOrderNumber" apps/*/src/**/*detail*.tsx --include="*.tsx"
```

해당 라인 근처에서 `navigate`, `Link`, `onClick`, `href` 등의 네비게이션 코드 존재 여부:

```bash
grep -B 2 -A 5 "salesOrderNumber\|purchaseOrderNumber\|relatedOrderNumber" <file> | grep -E "navigate|Link|onClick|href"
```

**PASS 기준:**
- FK 참조 필드(xxNumber, xxId를 표시하는 항목)에 클릭 가능한 링크 또는 버튼 존재
- `text-primary hover:underline cursor-pointer` 등 시각적 구분 존재

**FAIL 기준:**
- FK 참조 필드가 단순 `<div>` 또는 `<span>`으로만 렌더링
- 관련 엔티티 상세 페이지가 있지만 링크가 없음

**수정:**
```tsx
// Before (단순 텍스트)
<div>{record.salesOrderNumber}</div>

// After (클릭 가능 링크)
<button
  type="button"
  onClick={() => navigate(`/path/to/${record.salesOrderId}/edit`)}
  className="text-primary hover:underline cursor-pointer"
>
  {record.salesOrderNumber}
</button>
```

### Step 11: 상세 기본정보 그리드 컬럼 수 적합성 검증

**검사:** detail-page.tsx의 기본 정보 그리드에서 `lg:grid-cols-N`의 N이 실제 표시되는 항목 수와 적합한지 확인합니다.

**배경:** 필드를 추가/제거한 후 그리드 컬럼 수를 조정하지 않으면 불균형한 레이아웃이 됩니다.

**탐지:**

```bash
# 기본 정보 그리드에서 grid-cols 설정과 실제 child 개수 비교
grep -A 30 "기본 정보" apps/*/src/**/*detail*.tsx --include="*.tsx"
```

위 결과에서:
1. `lg:grid-cols-N`에서 N 값 추출
2. 해당 grid div 내부의 직계 `<div>` (항목) 개수 카운트
3. 항목 수가 N의 2배 이상이면 행이 너무 많아짐 → N을 올려야 함
4. 항목 수가 N 이하이면 빈 공간이 많음 → N을 내려야 함

**판단 기준:**
- 항목 수 1~4개: `lg:grid-cols-4` 이하
- 항목 수 5~8개: `lg:grid-cols-4` ~ `lg:grid-cols-6`
- 항목 수 9개 이상: `lg:grid-cols-6` 이상

**PASS:** 항목 수 대비 적절한 grid-cols 설정
**FAIL:** 항목 수 변경 후 grid-cols 미조정 (빈 공간 과다 또는 행 과다)

### Step 12: 컴포넌트 마이그레이션 기능 소실 검증

**검사:** 컴포넌트를 교체/마이그레이션할 때, 기존 컴포넌트의 주요 기능이 새 컴포넌트에도 존재하는지 확인합니다.

**배경:** SalesOrderSearchDialog 등을 재작성할 때 기존의 필터, 페이지네이션, 정렬 등 기능이 누락되는 사례 반복.

**탐지:**

```bash
# 삭제된 파일의 기능 키워드 목록 확인 (git diff에서)
git diff HEAD -- <deleted-file> | grep "^-" | grep -E "filter|search|pagination|sort|Select|DateRange"
```

새 파일에서 동일 기능 키워드 존재 확인:

```bash
grep -n "filter\|search\|pagination\|sort\|Select\|DateRange" <new-file>
```

**PASS:** 삭제된 컴포넌트의 주요 기능(필터, 검색, 페이지네이션, 정렬)이 새 컴포넌트에 존재
**FAIL:** 기존 기능 중 일부가 새 컴포넌트에서 누락

> 이 검사는 수동 확인이 필요하며, 자동화보다는 코드 리뷰 체크리스트로 활용됩니다.

## Output Format

```markdown
| # | 검사 | 파일 | 상태 | 상세 |
|---|------|------|------|------|
| 1 | Toast 라이브러리 | - | PASS/FAIL | - |
| 2 | TableWrapper | file.tsx | PASS/FAIL | 상세... |
| 3 | enableSorting | file.tsx | PASS/FAIL | 상세... |
| 4 | Import 순서 | file.tsx | PASS/FAIL | 상세... |
| 5 | 컴포넌트 중복 | file.tsx | PASS/FAIL | 상세... |
| 6 | 숫자 컬럼 정렬 | file.tsx | PASS/FAIL | 상세... |
| 7 | EmptyTableRow | file.tsx | PASS/FAIL | 상세... |
| 8 | 로컬 dead code | file.tsx | PASS/FAIL | 상세... |
| 9 | 상세 기본정보 그리드 | file.tsx | PASS/FAIL | 상세... |
```

## Exceptions

1. **production 모듈의 인라인 테이블** — InlineEditableRow를 사용하는 테이블은 TableWrapper 없이 직접 구현할 수 있음
2. **Sheet/Dialog 내부의 간단한 테이블** — FormSheet 내부의 소형 테이블은 TableWrapper 불필요
3. **preview 앱** — `apps/preview/` 는 프리뷰 전용이므로 UI 패턴 검증 대상에서 제외