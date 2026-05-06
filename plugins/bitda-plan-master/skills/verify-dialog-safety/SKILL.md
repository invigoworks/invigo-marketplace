---
name: verify-dialog-safety
description: Dialog/Sheet 상호작용 안전성, state 초기화, UX 일관성을 검증합니다. Sheet/Dialog 관련 변경 후 사용.
---

# Dialog & Sheet 안전성 검증

## Purpose

### A. FormSheet + AlertDialog 상호작용 (기존)
1. **Sibling Dialog 가드 누락 탐지** — FormSheet과 동일 레벨(sibling)로 렌더링되는 AlertDialog가 있을 때, `handleOpenChange`에서 내부 다이얼로그 상태를 체크하는 가드가 있는지 검증
2. **isDirty 가드 연쇄 트리거 방지** — `form.formState.isDirty` 체크가 있는 Sheet에서 sibling AlertDialog 열림/닫힘 시 의도치 않은 dirty 다이얼로그 트리거 방지
3. **새 AlertDialog 추가 시 가드 누락 탐지** — 기존 FormSheet 컴포넌트에 새로운 sibling AlertDialog가 추가되었지만 handleOpenChange 가드에 반영되지 않은 경우

### B. Dialog state 초기화 (신규)
4. **Dialog 닫힐 때 state 리셋 누락 탐지** — Dialog/Sheet가 닫힐 때 내부 state(선택된 파일, 검색어, 임시 데이터)가 초기화되지 않아 재오픈 시 이전 state가 남는 문제
5. **DialogDescription 누락 탐지** — Dialog에 `DialogDescription`이 없어 접근성 경고 발생 및 사용자에게 맥락 설명 부재
6. **위험 액션 버튼 variant 검증** — 삭제/폐기 등 비가역적 액션의 버튼이 `variant="destructive"` 미적용

### C. ScrollArea flex 컨테이너 충돌 (신규)
7. **ScrollArea + flex-1/min-h-0 사용 탐지** — Radix ScrollArea의 내부 Viewport가 `height: 100%`를 사용하므로, flex 컨테이너(flex-1, min-h-0)에서 높이가 올바르게 계산되지 않아 후속 요소(DialogFooter 등)가 가려지는 레이아웃 버그 탐지
8. **Dialog/Sheet 내 ScrollArea 고정 높이 미사용 탐지** — ScrollArea는 반드시 고정 높이(h-[Npx], max-h-[Npx])와 함께 사용해야 하며, flex 기반 높이와 함께 사용 시 overflow-y-auto div로 교체 필요

### D. 수정불가 상태 readOnly 처리 (신규)
9. **수정불가 상태에서 Dialog readOnly 미처리** — 상세 페이지에서 `isEditable()`/`canEdit` 등 편집 가능 여부 플래그가 있을 때, 해당 페이지의 편집용 Dialog에 readOnly prop이 전달되지 않아 수정불가 상태에서도 편집 UI가 노출되는 문제

### E. Radix Trigger asChild + Slot 중첩 오류 (신규)
10. **PopoverTrigger asChild + FormControl 이중 Slot 체인 탐지** — `<PopoverTrigger asChild><FormControl><Button>...</Button></FormControl></PopoverTrigger>` 패턴은 `PopoverTrigger`(Radix Slot) → `FormControl`(shadcn Slot) → `Button` 이중 Slot 체인을 만들어, Radix가 trigger의 ref 를 실제 Button 이 아닌 중간 Slot 에 고정합니다. 결과: Popover 가 잘못된 reference element 의 bounding rect 를 측정해 좌표 `(0, -592)` 등 **off-screen 으로 렌더링**되어 사용자에게 "클릭 안됨" 으로 보이는 버그. `DropdownMenuTrigger`/`HoverCardTrigger`/`TooltipTrigger`/`SelectTrigger` + `FormControl` 조합도 동일 위험.

## Background

Radix UI에서 FormSheet(Sheet)과 AlertDialog가 sibling으로 렌더링될 때, AlertDialog가 열리면 Sheet의 포커스가 이탈하면서 `onOpenChange(false)`가 호출될 수 있습니다. 이때 isDirty 체크가 있으면 "변경사항이 있습니다" 다이얼로그가 의도치 않게 나타나는 버그가 발생합니다.

**참조 구현 (올바른 패턴):**

```tsx
// ProductSheet.tsx — handleOpenChange 가드 패턴
const handleOpenChange = useCallback((open: boolean) => {
  // 내부 다이얼로그가 열린 상태면 Sheet 닫힘 무시
  if (!open && (showDeclarationChangeDialog || showPriceSyncDialog)) return;
  if (!open && form.formState.isDirty) {
    setShowDirtyDialog(true);
    return;
  }
  onOpenChange(open);
}, [form.formState.isDirty, onOpenChange, showDeclarationChangeDialog, showPriceSyncDialog]);
```

## When to Run

- FormSheet 컴포넌트에 새 AlertDialog를 추가한 후
- `handleOpenChange` 또는 `onOpenChange` 로직을 수정한 후
- `isDirty` 체크가 있는 Sheet 컴포넌트를 변경한 후
- 새로운 FormSheet 컴포넌트를 생성한 후
- Dialog/Sheet 컴포넌트를 새로 생성하거나 수정한 후
- 삭제/폐기 등 위험 액션 버튼을 추가한 후

## Related Files

| File | Purpose |
|------|---------|
| `apps/liquor/src/settings/master-data/products/components/ProductSheet.tsx` | 참조 구현 (3개 sibling AlertDialog + 가드) |
| `apps/liquor/src/settings/master-data/warehouses/components/WarehouseSheet.tsx` | 내부 AlertDialog 포함, 가드 없음 |
| `apps/liquor/src/settings/master-data/warehouses/page.tsx` | WarehouseSheet + sibling AlertDialog, 가드 없음 |
| `apps/liquor/src/document/health-cert/page.tsx` | HealthCertFormSheet + sibling AlertDialog, 가드 없음 |
| `packages/web-platform/src/components/FormSheet.tsx` | FormSheet 래퍼 컴포넌트 |

## Workflow

### Step 1: Sibling AlertDialog가 있는 FormSheet 탐지

FormSheet을 사용하는 모든 파일에서, 같은 컴포넌트 내에 FormSheet과 AlertDialog가 모두 존재하는 파일을 찾습니다.

**탐지:**

```bash
# FormSheet을 사용하는 파일 목록
grep -rl "FormSheet" apps/liquor/src/ --include="*.tsx"
```

각 파일에 대해:

```bash
# 같은 파일에 AlertDialog도 있는지 확인
grep -l "AlertDialog" <file>
```

**PASS:** FormSheet만 있고 AlertDialog는 없는 파일 → 검사 불필요
**CHECK:** FormSheet + AlertDialog 모두 있는 파일 → Step 2로 진행

### Step 2: Sibling 관계 확인

Step 1에서 검출된 각 파일에서, AlertDialog가 FormSheet의 sibling인지 child인지 확인합니다.

**탐지 패턴 (sibling):**
```
</FormSheet>
...
<AlertDialog
```

또는 page 레벨에서:
```
<SomeSheet ... />
...
<AlertDialog
```

**PASS:** AlertDialog가 FormSheet 내부(child)에만 있는 경우 → 낮은 위험 (단, Step 3 검사는 권장)
**CHECK:** AlertDialog가 FormSheet과 sibling인 경우 → Step 3으로 진행

### Step 3: handleOpenChange 가드 검증

sibling AlertDialog가 있는 FormSheet에서 `handleOpenChange` (또는 `onOpenChange` 핸들러)에 내부 다이얼로그 상태 가드가 있는지 확인합니다.

**탐지:**

```bash
# handleOpenChange 정의를 찾아 내부 dialog 상태 체크가 있는지 확인
grep -A 5 "handleOpenChange" <file> | grep -E "show.*Dialog|is.*Open|is.*Dialog"
```

**PASS 기준:**
- `handleOpenChange` 내에서 `!open && (showXxxDialog || showYyyDialog)` 형태의 가드가 존재
- 가드에 해당 컴포넌트의 모든 sibling AlertDialog 상태가 포함되어 있음

**FAIL 기준:**
- `handleOpenChange`가 없고 `onOpenChange`를 직접 전달 (raw passthrough)
- `handleOpenChange`는 있지만 sibling dialog 상태 가드가 누락
- 가드는 있지만 일부 sibling AlertDialog 상태가 누락 (새로 추가된 AlertDialog 등)

### Step 4: isDirty 가드와 Dialog 가드 순서 검증

isDirty 체크가 있는 컴포넌트에서 dialog 가드가 isDirty 체크 **앞에** 위치하는지 확인합니다.

**탐지:**

```bash
# handleOpenChange 블록 내 가드 순서 확인
grep -A 10 "handleOpenChange" <file>
```

**PASS 기준:**
```tsx
// 올바른 순서: dialog 가드 → isDirty 체크
if (!open && (showXxxDialog || showYyyDialog)) return;  // 먼저
if (!open && form.formState.isDirty) { ... }             // 나중
```

**FAIL 기준:**
```tsx
// 잘못된 순서: isDirty 체크가 먼저
if (!open && form.formState.isDirty) { ... }             // 먼저 → dirty dialog 트리거
if (!open && (showXxxDialog || showYyyDialog)) return;   // 여기까지 안 옴
```

### Step 5: 새 AlertDialog 추가 시 가드 동기화 검증

git diff에서 새로 추가된 AlertDialog의 open 상태 변수가 handleOpenChange 가드에도 반영되었는지 확인합니다.

**탐지:**

```bash
# 변경된 파일에서 새로 추가된 AlertDialog의 open state 확인
git diff HEAD -- <file> | grep -E "^\+.*<AlertDialog.*open=\{" | grep -oE "open=\{[^}]+"
```

```bash
# 해당 state 변수가 handleOpenChange 가드에 포함되어 있는지
grep "handleOpenChange" <file> | grep "<state_variable_name>"
```

**PASS:** 새로 추가된 AlertDialog의 open 상태가 가드에 포함됨
**FAIL:** 새로 추가된 AlertDialog의 open 상태가 가드에 누락됨

### Step 6: Dialog/Sheet 닫힐 때 state 리셋 검증

Dialog/Sheet가 닫힐 때 내부 state가 초기화되는지 확인합니다. 초기화 누락 시 재오픈 시 이전 state가 잔존합니다.

**탐지:**

```bash
# Dialog/Sheet 컴포넌트에서 useState를 사용하는 파일 탐지
grep -rl "Dialog\|Sheet" apps/*/src/ --include="*.tsx" | xargs grep -l "useState"
```

각 파일에서 `onOpenChange` 또는 `handleOpenChange` 핸들러 내부에 state 리셋 코드가 있는지 확인:

```bash
# onOpenChange 핸들러에서 set* 호출이 있는지 확인
grep -A 10 "onOpenChange\|handleOpenChange" <file> | grep -E "set[A-Z].*\(.*\)|reset\(\)|form\.reset"
```

**PASS 기준:**
- Dialog/Sheet `onOpenChange(!open)` 또는 닫힘 시 내부 useState 값들을 초기값으로 리셋
- `form.reset()` 호출로 폼 state 초기화
- 예시:
```tsx
const handleOpenChange = (open: boolean) => {
  if (!open) {
    setSelectedFiles([]);
    setSearchTerm('');
    form.reset();
  }
  onOpenChange(open);
};
```

**FAIL 기준:**
- `onOpenChange`를 그대로 전달하면서 내부 useState가 2개 이상 존재 (리셋 누락 가능성)
- Dialog 내부에 검색어, 선택 항목, 임시 파일 등 state가 있으나 닫힘 시 리셋 코드 없음

### Step 7: DialogDescription 존재 검증

모든 Dialog/AlertDialog에 `DialogDescription` (또는 `AlertDialogDescription`)이 포함되어 있는지 확인합니다.

**탐지:**

```bash
# DialogTitle이 있지만 DialogDescription이 없는 파일 탐지
grep -rl "DialogTitle\|AlertDialogTitle" apps/*/src/ --include="*.tsx" | while read f; do
  if ! grep -q "DialogDescription\|AlertDialogDescription" "$f"; then
    echo "$f"
  fi
done
```

**PASS 기준:**
- `DialogTitle`이 있는 모든 Dialog에 `DialogDescription`도 존재
- `AlertDialogTitle`이 있는 모든 AlertDialog에 `AlertDialogDescription`도 존재
- 시각적으로 숨겨야 하는 경우 `<DialogDescription className="sr-only">` 사용 가능

**FAIL 기준:**
- `DialogTitle`은 있으나 `DialogDescription`이 없는 Dialog
- Radix UI 접근성 경고: "Missing `Description`..." 발생 가능

**수정:**
```tsx
// Before (누락)
<DialogHeader>
  <DialogTitle>일괄 등록</DialogTitle>
</DialogHeader>

// After (추가)
<DialogHeader>
  <DialogTitle>일괄 등록</DialogTitle>
  <DialogDescription>CSV 파일을 업로드하여 데이터를 일괄 등록합니다.</DialogDescription>
</DialogHeader>
```

### Step 8: 위험 액션 버튼 variant 검증

삭제, 폐기 등 비가역적 액션의 버튼이 `variant="destructive"`를 사용하는지 확인합니다.

**탐지:**

```bash
# 삭제/폐기 관련 버튼에서 destructive variant 누락 확인
grep -rn "삭제\|폐기\|제거\|초기화" apps/*/src/ --include="*.tsx" | grep -i "button\|Button" | grep -v "destructive"
```

```bash
# AlertDialog 내부 액션 버튼 확인 (AlertDialogAction은 기본적으로 destructive 필요)
grep -B 2 -A 2 "AlertDialogAction" apps/*/src/ --include="*.tsx" | grep -v "destructive"
```

**PASS 기준:**
- 삭제/폐기/제거 액션의 `<Button>`에 `variant="destructive"` 적용
- `AlertDialogAction`에서 삭제 확인 시 `className="bg-destructive..."` 또는 `variant="destructive"` 적용

**FAIL 기준:**
- 삭제/폐기 버튼이 기본 variant(default/outline)로 렌더링
- 비가역적 액션임에도 시각적 경고가 없음

**수정:**
```tsx
// Before
<Button onClick={handleDelete}>삭제</Button>

// After
<Button variant="destructive" onClick={handleDelete}>삭제</Button>
```

### Step 9: ScrollArea + flex 컨테이너 충돌 탐지

Dialog/Sheet 내부에서 ScrollArea가 flex-1 또는 min-h-0과 함께 사용되는지 확인합니다. Radix ScrollArea의 내부 Viewport는 `height: 100%`를 사용하므로, flex 기반 높이에서 정상 계산되지 않아 후속 요소(DialogFooter 등)가 가려집니다.

**탐지:**

```bash
# ScrollArea를 사용하는 Dialog/Sheet 파일 찾기
grep -rl "ScrollArea" apps/*/src/ --include="*Dialog.tsx" --include="*Sheet.tsx"
```

각 파일에서 ScrollArea의 부모/조상에 flex-1 또는 min-h-0이 있는지 확인:

```bash
# ScrollArea와 같은 파일에서 flex-1 또는 min-h-0 사용 확인
grep -n "ScrollArea\|flex-1\|min-h-0" <file>
```

**PASS 기준:**
- ScrollArea가 고정 높이(`h-[Npx]`, `max-h-[Npx]`, `h-[calc(...)]`)와 함께 사용됨
- ScrollArea가 flex 컨테이너 외부에서 사용됨

**FAIL 기준:**
- ScrollArea가 `flex-1`, `min-h-0`, `flex-grow` 등 flex 기반 높이와 함께 사용됨
- ScrollArea 부모에 고정 높이가 없고 flex 레이아웃에 의존하여 높이가 결정됨

**수정:**
```tsx
// Before (flex 기반 — DialogFooter 가려짐)
<div className="flex-1 min-h-0">
  <ScrollArea>
    {content}
  </ScrollArea>
</div>

// After — 방법 1: 고정 높이 사용
<ScrollArea className="h-[400px]">
  {content}
</ScrollArea>

// After — 방법 2: overflow-y-auto div로 교체 (flex 기반 높이 필요 시)
<div className="flex-1 min-h-0 overflow-y-auto">
  {content}
</div>
```

### Step 10: Dialog/Sheet 내 ScrollArea 고정 높이 미사용 탐지

모든 Dialog/Sheet 내 ScrollArea에 고정 높이가 적용되었는지 확인합니다.

**탐지:**

```bash
# ScrollArea가 있는 Dialog/Sheet 파일에서 className 확인
grep -B 1 -A 3 "ScrollArea" <file> | grep -E "h-\[|max-h-\[|h-[0-9]"
```

**PASS 기준:**
- ScrollArea className에 `h-[Npx]`, `max-h-[Npx]`, `h-[calc(...)]` 등 고정/최대 높이가 있음
- 코드베이스의 기존 올바른 패턴 예시: `h-[160px]`, `h-[200px]`, `h-[240px]`, `h-[280px]`, `h-[300px]`, `max-h-[400px]`, `h-[calc(100vh-100px)]`

**FAIL 기준:**
- ScrollArea에 고정 높이 없이 사용됨 (부모 flex에 의존)
- `className`에 높이 관련 클래스가 없고 `flex-1` 또는 `min-h-0`만 있음

## Output Format

### A. FormSheet + AlertDialog 상호작용

```markdown
| # | 파일 | FormSheet | Sibling AlertDialog | 가드 | 상태 |
|---|------|-----------|---------------------|------|------|
| 1 | ProductSheet.tsx | ✓ | 3개 (price, dirty, declaration) | ✓ (2개 가드) | PASS |
| 2 | WarehouseSheet.tsx | ✓ | 1개 (location limit) | ✗ 없음 | FAIL |
| 3 | warehouses/page.tsx | via WarehouseSheet | 2개 (bulk, limit) | ✗ 없음 | FAIL |
```

### B. Dialog state 초기화 & UX

```markdown
| # | 파일 | 검사 | 상태 | 상세 |
|---|------|------|------|------|
| 1 | BulkImportDialog.tsx | State 리셋 | PASS/FAIL | useState 3개, 리셋 코드 유/무 |
| 2 | SalesOrderSearchDialog.tsx | DialogDescription | PASS/FAIL | 누락/존재 |
| 3 | DeleteDialog.tsx | Destructive variant | PASS/FAIL | variant 미적용 |
```

### C. ScrollArea flex 컨테이너 충돌

```markdown
| # | 파일 | ScrollArea | 높이 지정 | flex 컨텍스트 | 상태 |
|---|------|-----------|----------|--------------|------|
| 1 | BulkDeleteWarningDialog.tsx | ✓ | h-[160px] | N/A | PASS |
| 2 | WorkCompletionDialog.tsx | ✓ | h-[240px] | N/A | PASS |
| 3 | SomeDialog.tsx | ✓ | 없음 | flex-1 min-h-0 | FAIL |
```

### Step 11: 수정불가 상태에서 Dialog/Modal readOnly 미처리 탐지

상세 페이지 등에서 `isEditable()` 또는 `canEdit` 같은 편집 가능 여부 플래그가 존재할 때, 해당 페이지에서 열리는 Dialog/Modal에 `readOnly` prop이 전달되는지 확인합니다.

**배경:** 수정불가 상태(예: 세무 전송 완료)에서 증빙 등록 모달 등이 편집 모드로 열리면 사용자가 저장 시도 후 오류를 겪습니다.

**탐지:**

```bash
# isEditable, canEdit 등 편집 가능 여부 변수가 있는 detail-page 찾기
grep -rn "isEditable\|canEdit\|isReadOnly\|editable" apps/*/src/**/*detail*.tsx apps/*/src/**/*detail*page*.tsx --include="*.tsx"
```

해당 파일에서 Dialog/Sheet를 열 때 readOnly prop 전달 여부 확인:

```bash
# Dialog/Sheet 컴포넌트 호출에서 readOnly prop 존재 여부
grep -A 5 "Dialog\|Sheet" <file> | grep -E "readOnly|read-only|readonly"
```

**PASS 기준:**
- `canEdit`/`isEditable` 변수가 있는 페이지에서 열리는 모든 편집용 Dialog/Modal에 `readOnly={!canEdit}` 또는 동등한 prop 전달
- Dialog 컴포넌트가 `readOnly` prop을 받아 내부 인터랙션(파일 업로드, 버튼, 입력 등) 비활성화

**FAIL 기준:**
- `canEdit` 변수가 있지만 Dialog에 readOnly prop이 전달되지 않음
- Dialog 컴포넌트 자체에 `readOnly` prop 인터페이스가 없음 (편집 기능이 있는 Dialog인 경우)

**수정:**
```tsx
// Before (readOnly 미처리)
<ItemEvidenceCarouselDialog
  open={evidenceDialogOpen}
  onOpenChange={setEvidenceDialogOpen}
  items={itemEvidenceData}
  onSave={handleSaveEvidence}
/>

// After (readOnly 전달)
<ItemEvidenceCarouselDialog
  open={evidenceDialogOpen}
  onOpenChange={setEvidenceDialogOpen}
  items={itemEvidenceData}
  onSave={handleSaveEvidence}
  readOnly={!canEdit}
/>
```

### Step 12: Radix Trigger asChild + FormControl 이중 Slot 체인 탐지

**배경:** Radix Popover/DropdownMenu/HoverCard/Tooltip/Select 의 Trigger 에 `asChild` 를 사용할 때, 직접 child 로 `FormControl` (shadcn 의 Slot 래퍼) 을 넣으면 이중 Slot 체인이 발생합니다.

```
PopoverTrigger(Radix Slot) → FormControl(shadcn Slot) → Button
```

Radix 는 trigger 의 ref 를 실제 Button 이 아닌 중간 FormControl 의 Slot 에 고정하므로, floating position 계산 시 잘못된 reference element 의 bounding rect 를 측정합니다. 결과: Popover 가 **좌표 `(0, -592)` 등 뷰포트 밖으로 렌더링**되어 사용자에게 "드롭다운 클릭 안 됨" 으로 보입니다.

**증상 체크:** `getBoundingClientRect()` 로 popover content 좌표가 음수 y 또는 `(0, 0)` 근처로 렌더되면 이 버그.

**탐지 명령:**

```bash
# PopoverTrigger asChild 직후 FormControl 사용 탐지
grep -rn -A2 "PopoverTrigger asChild" apps/*/src --include="*.tsx" | grep -B1 "FormControl"

# 모든 Radix Trigger asChild + FormControl 조합 탐지 (Popover/DropdownMenu/HoverCard/Tooltip/Select)
for trigger in PopoverTrigger DropdownMenuTrigger HoverCardTrigger TooltipTrigger SelectTrigger; do
  grep -rn -A2 "${trigger} asChild" apps/*/src --include="*.tsx" 2>/dev/null | grep -B1 "<FormControl>"
done
```

**PASS 기준:**
- `PopoverTrigger asChild` 직후 `<Button>` 이 직접 child (FormControl wrapping 없음)
- 또는 FormField 의 render prop 안에서 FormControl 을 쓰되 Button 을 직접 PopoverTrigger asChild 의 child 로 배치
- 결과: Popover 가 트리거 버튼 바로 아래에 정상 위치로 렌더

**FAIL 기준:**
- `<PopoverTrigger asChild><FormControl><Button>...</Button></FormControl></PopoverTrigger>` 패턴 존재
- `DropdownMenuTrigger`/`HoverCardTrigger`/`TooltipTrigger`/`SelectTrigger` + `FormControl` 동일 패턴

**수정:**

```tsx
// ❌ Before — 이중 Slot 체인 (Popover off-screen 버그)
<FormField
  name="productDeclarationId"
  render={() => (
    <FormItem>
      <FormLabel>상표신고</FormLabel>
      <Popover>
        <PopoverTrigger asChild>
          <FormControl>
            <Button type="button" variant="outline">...</Button>
          </FormControl>
        </PopoverTrigger>
        <PopoverContent>...</PopoverContent>
      </Popover>
    </FormItem>
  )}
/>

// ✅ After — FormControl 제거, Button 이 PopoverTrigger 의 직접 child
<FormField
  name="productDeclarationId"
  render={() => (
    <FormItem>
      <FormLabel>상표신고</FormLabel>
      <Popover modal={false}>
        <PopoverTrigger asChild>
          <Button type="button" variant="outline">...</Button>
        </PopoverTrigger>
        <PopoverContent
          side="bottom"
          sideOffset={4}
          collisionPadding={8}
          avoidCollisions
        >
          ...
        </PopoverContent>
      </Popover>
    </FormItem>
  )}
/>
```

**추가 권장 사항** (Sheet/Dialog 내부의 Popover 인 경우):
- `Popover modal={false}` — Sheet/Dialog 내 중첩 modal focus 충돌 방지
- `sideOffset` / `collisionPadding` 명시 — 위치 계산 안정화

## Exceptions

다음은 **위반이 아닙니다**:

1. **AlertDialog가 FormSheet 내부(child)에만 있는 경우** — Radix 포커스 컨텍스트가 Sheet 내부에서 유지되므로 Sheet의 `onOpenChange`를 트리거하지 않을 가능성이 높음. 단, 보고는 하되 WARN으로 표시.
2. **isDirty 체크가 없는 단순 passthrough** — `onOpenChange`를 직접 전달하고 isDirty 체크가 없는 경우, sibling AlertDialog가 Sheet를 닫더라도 dirty 경고 없이 그냥 닫힘. 데이터 손실 위험은 있지만 "의도치 않은 다이얼로그 트리거" 버그는 아님. INFO로 표시.
3. **DeleteDialog, BulkDeleteDialog 등 래퍼 컴포넌트** — 내부적으로 AlertDialog를 사용하지만 page 레벨에서 Sheet와 분리된 흐름(삭제 → Sheet 닫힘 → 삭제 다이얼로그)으로 사용되는 경우는 동시에 열리지 않으므로 안전.
4. **ConfirmActionDialog** — 일반적으로 Sheet 내부 액션에서 열리며, Sheet를 닫지 않는 독립 흐름이면 안전.
5. **State가 없는 단순 확인 Dialog** — useState 없이 props만으로 동작하는 단순 확인/취소 Dialog는 리셋 대상 없음. SKIP.
6. **FormControl 이 Input/Textarea/Select 래핑** — FormControl + `<Input>` 같이 Radix Trigger asChild 와 무관한 일반 입력 필드는 FormControl wrapping 이 올바른 패턴. FAIL 기준은 **오직** `*Trigger asChild` 하위에 FormControl 이 있는 경우에만 적용.
7. **SelectTrigger 는 자체 asChild 기본 동작** — shadcn Select 의 `<SelectTrigger>` 는 이미 Radix 래퍼이므로 `asChild` 없이 FormControl 안에 배치하는 표준 패턴은 안전. 탐지 대상은 `asChild` 를 명시적으로 쓴 경우에 한정.
6. **sr-only DialogDescription** — 시각적으로 설명이 불필요하지만 접근성을 위해 `className="sr-only"`로 숨긴 경우는 PASS.
7. **ConfirmActionDialog의 확인 버튼** — 비파괴적 확인 액션(예: "전송", "승인")은 destructive variant 불필요.
8. **고정 높이 ScrollArea** — `h-[Npx]`, `max-h-[Npx]`, `h-[calc(...)]` 등 고정 높이가 지정된 ScrollArea는 flex 컨테이너와 무관하게 정상 동작. PASS.
9. **Sheet 내부 ScrollArea** — Sheet은 기본적으로 고정 높이(`h-[calc(100vh-...)]`)로 사용되므로, Sheet 내부 ScrollArea가 고정 높이를 가지면 안전. 단, Sheet 자체가 flex 레이아웃이면 Step 9 적용.
