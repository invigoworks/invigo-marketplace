---
name: verify-badge-consistency
description: StatusBadge 사용 일관성 및 뱃지 색상 타입 안전성을 검증합니다. 뱃지/상태 표시 변경 후 사용.
---

# 뱃지 일관성 검증

## Purpose

프로젝트 전체에서 상태 뱃지 사용 패턴의 일관성과 타입 안전성을 검증합니다:

1. **StatusBadge 사용 강제** — raw `<span>` 또는 `<Badge>`로 상태 표시 금지, 플랫폼 `StatusBadge` 사용 필수
2. **BadgeColor 타입 안전성** — 뱃지 색상 상수가 `Record<DomainType, BadgeColor>`로 정확히 타이핑되었는지 확인
3. **인라인 설정 중복 방지** — StatusBadge의 labels/colors가 공유 상수로 추출되어 있는지 확인 (2회 이상 사용 시)

## When to Run

- 새로운 상태/유형 뱃지를 추가한 후
- 기존 뱃지 컴포넌트를 수정한 후
- 새 도메인 타입(status enum 등)을 추가한 후
- PR 전 뱃지 일관성 확인 시

## Related Files

| File | Purpose |
|------|---------|
| `packages/web-platform/src/components/StatusBadge.tsx` | 플랫폼 StatusBadge 컴포넌트 |
| `packages/web-platform/src/types/badge.ts` | BadgeColor 타입 정의 |
| `apps/*/src/**/types.ts` | 도메인 타입 및 labels Record |
| `apps/*/src/**/constants.ts` | 뱃지 색상 상수 (colors Record) |

## Workflow

### Step 1: Raw 뱃지 사용 감지

**검사:** `StatusBadge`가 아닌 raw `<span>` 또는 `<Badge>`로 상태/유형을 표시하는 패턴을 감지합니다.

**감지 패턴 A: className에 색상 하드코딩된 span/Badge**
```bash
grep -rn "className=.*bg-\(green\|red\|yellow\|blue\|amber\|gray\|orange\)-\(50\|100\).*text-\(green\|red\|yellow\|blue\|amber\|gray\|orange\)-" apps/*/src/ --include="*.tsx"
```

위 결과에서 `StatusBadge` import가 없는 파일을 필터링합니다.

**감지 패턴 B: 조건부 색상 분기 (switch/if)**
```bash
grep -rn "case.*:.*return.*bg-\|case.*:.*className.*bg-" apps/*/src/ --include="*.tsx"
```

상태값에 따른 색상 분기 로직이 있다면 StatusBadge로 교체 대상입니다.

**PASS:** StatusBadge 미사용 raw 뱃지가 0건
**FAIL:** raw span/Badge로 상태를 표시하는 파일 존재

**수정:**
```tsx
// Before (raw span)
<span className={cn("px-2 py-0.5 rounded-full text-xs", colorMap[status])}>
  {labelMap[status]}
</span>

// After (StatusBadge)
<StatusBadge status={status} labels={LABELS} colors={COLORS} />
```

### Step 2: BadgeColor 타입 안전성 검증

**검사:** 뱃지 색상 상수가 `Record<string, string>` 대신 정확한 도메인 타입으로 정의되어 있는지 확인합니다.

```bash
grep -rn "Record<string.*string>.*=" apps/*/src/**/constants.ts --include="*.ts" | grep -i "color\|badge"
```

**PASS:** 뱃지 색상 관련 상수가 모두 `Record<DomainType, BadgeColor>`로 타이핑
**FAIL:** `Record<string, string>` 또는 `Record<string, BadgeColor>` 사용

**수정:**
```typescript
// Before (unsafe)
export const STATUS_COLORS: Record<string, string> = { ... };

// After (type-safe)
import type { BadgeColor } from '@plan-master/web-platform';
import type { MyStatus } from './types';
export const STATUS_COLORS: Record<MyStatus, BadgeColor> = { ... };
```

### Step 3: 인라인 labels/colors 중복 검증

**검사:** 동일한 StatusBadge labels/colors 설정이 2곳 이상에서 인라인으로 반복되는지 확인합니다.

```bash
grep -rn "labels={{" apps/*/src/ --include="*.tsx"
grep -rn "colors={{" apps/*/src/ --include="*.tsx"
```

인라인 객체 `{{ ... }}`가 2회 이상 동일한 키 구조로 나타나면 공유 상수로 추출해야 합니다.

**PASS:** StatusBadge labels/colors가 공유 상수 참조 또는 1회만 사용
**FAIL:** 동일 구조의 labels/colors가 2곳 이상에서 인라인 정의

**수정:**
```typescript
// constants.ts에 추출
export const MY_STATUS_COLORS: Record<MyStatus, BadgeColor> = { ... };

// types.ts에 labels 추출
export const MY_STATUS_LABELS: Record<MyStatus, string> = { ... };

// 사용처에서 import
<StatusBadge status={status} labels={MY_STATUS_LABELS} colors={MY_STATUS_COLORS} />
```

### Step 4: labels/colors 분리 규칙 검증

**검사:** labels는 `types.ts`에, colors는 `constants.ts`에 위치하는 분리 규칙을 준수하는지 확인합니다.

```bash
grep -rn "LABELS.*Record.*string>.*=" apps/*/src/**/constants.ts --include="*.ts"
```

constants.ts에 `*_LABELS` 상수가 있으면 위반입니다. Labels는 도메인 타입과 함께 `types.ts`에 위치해야 합니다.

```bash
grep -rn "COLORS.*Record.*BadgeColor>.*=" apps/*/src/**/types.ts --include="*.ts"
```

types.ts에 `*_COLORS` 상수가 있으면 위반입니다. Colors는 `constants.ts`에 위치해야 합니다.

**PASS:** labels → types.ts, colors → constants.ts 분리 준수
**FAIL:** labels/colors가 잘못된 파일에 위치

### Step 5: StatusBadge labels fallback 누락 검증

**검사:** StatusBadge에 커스텀 `labels` prop을 전달하는 경우, labels에 누락된 상태값이 있으면 영어 raw 값이 표시됨.
특히 상태 용어 변경(예: CONFIRMED→APPROVED) 후 localStorage에 잔존하는 이전 값에 대한 fallback이 필요.

**배경:** StatusBadge는 `labels?.[status] ?? presetConfig?.labels[status] ?? status`로 라벨을 결정함.
labels prop이 주어지면 preset을 사용하지 않고, labels에 없는 키는 raw status 그대로 표시.

**감지 방법:**
```bash
# StatusBadge에 커스텀 labels를 전달하는 곳 찾기
grep -rn "StatusBadge" apps/*/src/ --include="*.tsx" -A3 | grep "labels="
```

발견된 각 사용처에서:
1. labels Record의 키 목록 확인
2. 해당 도메인의 이전 상태값(레거시 마이그레이션)이 포함되어 있는지 확인
3. 특히 최근 rename된 상태값 (CONFIRMED→APPROVED, TRANSMITTED→SUBMITTED, UPDATE→DRAFT)

**PASS:** 커스텀 labels가 이전 상태값 fallback을 포함하거나, preset만 사용
**FAIL:** 커스텀 labels에 이전 상태값이 누락되어 영어 raw 값 표시 가능성 있음

**수정 예시:**
```typescript
// Before (fallback 없음)
const LABELS: Record<DeclarationStatus, string> = {
  DRAFT: "작성중", SUBMITTED: "제출완료", APPROVED: "승인", REJECTED: "반려",
};

// After (이전 상태값 fallback 포함)
const LABELS: Record<string, string> = {
  DRAFT: "작성중", SUBMITTED: "제출완료", APPROVED: "승인", REJECTED: "반려",
  // 이전 상태값 fallback (localStorage 잔존 데이터)
  UPDATE: "작성중", TRANSMITTED: "제출완료", CONFIRMED: "승인",
};
```

## Output Format

```markdown
| # | 검사 | 파일 | 상태 | 상세 |
|---|------|------|------|------|
| 1 | Raw 뱃지 감지 | file.tsx | PASS/FAIL | 상세... |
| 2 | BadgeColor 타입 | file.ts | PASS/FAIL | 상세... |
| 3 | 인라인 중복 | file.tsx | PASS/FAIL | 상세... |
| 4 | labels/colors 분리 | file.ts | PASS/FAIL | 상세... |
```

## Exceptions

1. **web-platform 내부의 StatusBadge 구현** — `packages/web-platform/src/components/StatusBadge.tsx` 자체는 raw span을 사용해도 됨 (플랫폼 컴포넌트이므로)
2. **Badge variant 사용** — StatusBadge가 아닌 순수 UI 장식용 `Badge` (예: "전통주", "NEW" 등 단일 고정 텍스트)는 raw Badge 허용
3. **preview 앱** — `apps/preview/`는 프리뷰 전용이므로 검증 대상 제외
4. **LiquorTypeBadge** — 주종 뱃지는 전용 컴포넌트(`LiquorTypeBadge`)를 사용하는 것이 올바른 패턴이므로 StatusBadge로 교체 불필요
