# Component Reuse Analysis Guide

## Phase 0: 기존 컴포넌트 탐색

대상 코드 분석 전에 프로젝트 내 재사용 가능한 컴포넌트를 탐색합니다.

### 탐색 에이전트 호출

```typescript
await Task({
  subagent_type: "feature-dev:code-explorer",
  prompt: `Analyze reusable components in the project:

    Search locations (in priority order):
    1. packages/web-platform/src/components/ - 공통 컴포넌트
    2. apps/[앱명]/src/components/ - 앱 레벨 공유 컴포넌트
    3. apps/[앱명]/src/[도메인]/components/shared/ - 도메인 공유

    Find components for common UI patterns:
    - Time input (TimeInput, TimePicker)
    - Date selection (DateRangePicker, DateRangeFilter)
    - Search/Select (SearchableSelect, ComboBox)
    - Status indicators (StatusBadge, Badge)
    - Dialogs (ConfirmDialog, AlertDialog, FormSheet)
    - Data display (DataTable, Table)

    Output: List of available components with their import paths`
});
```

---

## 반복 패턴 식별

대상 파일과 관련 파일들에서 3회 이상 반복되는 UI 패턴을 식별합니다.

### 반복 패턴 분석 에이전트

```typescript
await Task({
  subagent_type: "invigo-agents:code-reviewer",
  prompt: `Identify repeated UI patterns in [target] and related files:

    Criteria:
    - Pattern appears 3+ times in the codebase
    - Pattern involves multiple elements (not single primitives)
    - Pattern has configurable aspects (status, type, options)

    Check for:
    - Status badge patterns (different variants, colors by status)
    - Input groups (quantity + unit, date + time)
    - Filter sections (date range + search + status filter)
    - Action button groups (edit, delete, view)
    - Card layouts with similar structure

    Output:
    | Pattern | Occurrences | Current Implementation | Recommendation |
    |---------|-------------|----------------------|----------------|
    | Status badge | 5 files | Inline Badge with ternary | Create StatusBadge component |
    | Qty + Unit | 4 files | Flex with Input + Select | Create QuantityUnitInput |`
});
```

---

## 분석 결과 문서화 템플릿

```markdown
## Phase 0: Component Reuse Analysis

### 기존 재사용 가능 컴포넌트
| UI 요소 | 기존 컴포넌트 | Import 경로 | 대상 파일에서 사용 여부 |
|---------|--------------|-------------|----------------------|
| 시간 입력 | TimeInput | `@bitda/web-platform` | ❌ 미사용 (개선 필요) |
| 날짜 선택 | DateRangeFilter | `@bitda/web-platform` | ✅ 사용 중 |

### 발견된 반복 패턴 (3회 이상)
| 패턴 | 반복 횟수 | 현재 상태 | 권장 조치 |
|------|----------|----------|----------|
| 작업 상태 뱃지 | 4회 | 인라인 구현 | 컴포넌트화 필요 |
| 수량+단위 입력 | 5회 | 하드코딩 | QuantityUnitInput 생성 |

### 개선 우선순위
1. **[CRITICAL]** 기존 컴포넌트로 교체 가능한 항목
2. **[HIGH]** 3회 이상 반복되어 컴포넌트화 필요한 항목
3. **[MEDIUM]** 기타 UI/UX 개선 항목
```

---

## Code Review에 포함할 Component Reuse 검사 항목

### CRITICAL: Unused Existing Components
- TimeInput exists but `<input type="time">` is used
- DateRangeFilter exists but custom date inputs are used
- FormSheet exists but raw Sheet with manual padding is used
- SearchableSelect exists but custom search+select is implemented

### HIGH: Repeated Patterns Needing Componentization
- Same status badge logic appears 3+ times
- Same input group pattern (qty+unit, date+time) repeated
- Same filter section structure in multiple pages
- Same action button group in multiple tables

### MEDIUM: Hardcoded Values That Should Be Extracted
- Status color mappings repeated inline
- Unit options duplicated across files
- Similar validation patterns not shared

---

## Component Reuse Checklist

### 기존 컴포넌트 교체 대상

| 현재 구현 | 교체 대상 | Import |
|----------|----------|--------|
| `<input type="time">` | `TimeInput` | `@bitda/web-platform` |
| `<input type="date">` | `DateRangePicker` | `@bitda/web-platform` |
| `Sheet` + 수동 패딩 | `FormSheet` | `@bitda/web-platform` |
| 직접 구현 검색 선택 | `SearchableSelect` | `@bitda/web-platform` |
| `<h1>` 페이지 타이틀 | `PageTitle` | `@bitda/web-platform` |

### 반복 패턴 컴포넌트화 기준

| 반복 횟수 | 조치 |
|----------|------|
| 1-2회 | 허용 (로컬 구현) |
| **3회 이상** | **반드시 컴포넌트화** |
| 앱 간 공유 | `@bitda/web-platform`에 추가 |

---

## 하드코딩 금지 패턴

### ❌ NEVER: 반복되는 조건부 스타일링
```tsx
{status === 'completed' ? 'bg-green-100' : status === 'pending' ? 'bg-yellow-100' : 'bg-gray-100'}
```

### ✅ ALWAYS: 컴포넌트 또는 유틸리티 사용
```tsx
<StatusBadge status={status} />
// 또는
const statusStyles = getStatusStyles(status);
```

### ❌ NEVER: 반복되는 입력 그룹
```tsx
<div className="flex gap-2">
  <Input type="number" />
  <Select>...</Select>
</div>
```

### ✅ ALWAYS: 컴포넌트화
```tsx
<QuantityUnitInput quantity={qty} unit={unit} onChange={...} />
```
