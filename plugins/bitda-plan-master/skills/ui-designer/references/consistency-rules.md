# UI Consistency Rules

**CRITICAL**: 이 문서는 ui-designer가 코드 생성 시, ui-supervisor가 검사 시 반드시 참조해야 하는 UI 일관성 규칙입니다.

---

## 핵심 일관성 체크 항목

### 1. 페이지 타이틀 패턴 (CRITICAL)

**올바른 패턴:**
```tsx
<div className="container mx-auto py-6 space-y-6">
  {/* 헤더 */}
  <div className="flex items-center justify-between">
    <div>
      <PageTitle>페이지 타이틀</PageTitle>
      <p className="text-muted-foreground">
        페이지 설명 텍스트입니다.
      </p>
    </div>
    <div className="flex items-center gap-2">
      {/* 액션 버튼들 */}
    </div>
  </div>
  {/* 컨텐츠 */}
</div>
```

**체크 포인트:**
| 항목 | 규칙 |
|------|------|
| PageTitle 컴포넌트 | 반드시 `@plan-master/web-platform`의 `PageTitle` 사용 |
| 타이틀 스타일 | `text-2xl font-semibold tracking-tight` (PageTitle 내장) |
| 설명 텍스트 | `<p className="text-muted-foreground">` 사용 |
| 컨테이너 패딩 | `py-6` (상하 24px) |
| 섹션 간격 | `space-y-6` (24px) |
| Divider | 타이틀 아래 divider 선 **사용하지 않음** |

**잘못된 패턴 (절대 금지):**
```tsx
// ❌ h1 태그 직접 사용
<h1 className="text-xl font-bold">타이틀</h1>

// ❌ 다른 크기의 타이틀
<PageTitle className="text-3xl">타이틀</PageTitle>

// ❌ divider 추가
<PageTitle>타이틀</PageTitle>
<Separator className="my-4" />  // ❌

// ❌ 다른 패딩 값
<div className="container mx-auto py-4">  // ❌ py-4 아닌 py-6
```

---

### 2. Sheet/Dialog 패딩 패턴 (CRITICAL)

**올바른 패턴 - FormSheet 사용:**
```tsx
import { FormSheet, FormSheetFooter } from "@plan-master/web-platform";

<FormSheet
  open={open}
  onOpenChange={onOpenChange}
  title="시트 타이틀"
  description="시트 설명"
  width="md"  // sm | md | lg | xl | 2xl
>
  <Form {...form}>
    <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-5">
      {/* 폼 필드들 */}

      <FormSheetFooter>
        <Button variant="outline" onClick={() => onOpenChange(false)}>
          취소
        </Button>
        <Button type="submit">저장</Button>
      </FormSheetFooter>
    </form>
  </Form>
</FormSheet>
```

**FormSheet 자동 패딩:**
- Header: `px-6 py-5 border-b bg-muted/30`
- Content: `px-6 py-6` (자동 적용)
- Footer: `px-6 py-4 border-t bg-muted/30`

**체크 포인트:**
| 항목 | 규칙 |
|------|------|
| Sheet 컴포넌트 | `FormSheet` 사용 권장 |
| 콘텐츠 패딩 | FormSheet 사용 시 자동 적용됨 |
| 수동 Sheet 사용 시 | `SheetContent` 내부에 `p-6` 또는 `px-6 py-6` 필수 |
| Footer | `FormSheetFooter` 또는 `border-t` 구분선 필수 |

**잘못된 패턴 (절대 금지):**
```tsx
// ❌ 패딩 없이 SheetContent 사용
<SheetContent className="w-[400px]">
  <SheetHeader>
    <SheetTitle>타이틀</SheetTitle>
  </SheetHeader>
  <form>  // 패딩 없음 ❌
    {/* ... */}
  </form>
</SheetContent>

// ❌ p-0만 주고 내부에 패딩 안넣음
<SheetContent className="p-0">
  {/* 내부에 패딩 없음 ❌ */}
</SheetContent>
```

---

### 3. 달력/날짜 선택 컴포넌트 (CRITICAL)

**반드시 사용해야 하는 컴포넌트:**

```tsx
// 날짜 범위 필터
import { DateRangeFilter } from "@plan-master/web-platform";

<DateRangeFilter
  startDate={startDate}
  endDate={endDate}
  onChange={(start, end) => {
    setStartDate(start);
    setEndDate(end);
  }}
  placeholder="기간 선택"
  showPresets  // 프리셋 표시 (이번달, 지난달 등)
  pickerClassName="w-[240px]"
/>

// 단일 날짜 선택 (Form 내부)
import { DateRangePicker, Calendar } from "@plan-master/web-platform/shadcn";
```

**체크 포인트:**
| 항목 | 규칙 |
|------|------|
| 기간 필터 | `DateRangeFilter` 컴포넌트 사용 필수 |
| 날짜 피커 | `DateRangePicker` 또는 `Calendar` 사용 |
| 커스텀 구현 금지 | `<input type="date">` 직접 사용 금지 |
| Popover 패턴 | shadcn Calendar + Popover 조합 가능 |

**잘못된 패턴 (절대 금지):**
```tsx
// ❌ HTML 기본 date input
<input type="date" value={date} onChange={...} />

// ❌ 직접 만든 달력 컴포넌트
<CustomCalendar />

// ❌ 외부 라이브러리 직접 사용
import DatePicker from "react-datepicker";
```

---

### 4. 테이블 양끝 패딩 (CRITICAL)

**올바른 패턴:**
```tsx
<Card>
  <CardContent className="p-0">
    <div className="overflow-x-auto px-4 py-2">  {/* ← 양끝 패딩 필수 */}
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="whitespace-nowrap">컬럼1</TableHead>
            {/* ... */}
          </TableRow>
        </TableHeader>
        <TableBody>
          {/* ... */}
        </TableBody>
      </Table>
    </div>
  </CardContent>
</Card>
```

**체크 포인트:**
| 항목 | 규칙 |
|------|------|
| 테이블 래퍼 | `<div className="overflow-x-auto px-4 py-2">` 필수 |
| 양끝 패딩 | `px-4` (16px) 이상 |
| Card 내부 | `CardContent className="p-0"` 후 내부에 패딩 적용 |
| 테이블 직접 렌더 | Card 없이 테이블만 있을 경우에도 래퍼 패딩 적용 |

**잘못된 패턴 (절대 금지):**
```tsx
// ❌ 패딩 없이 테이블 바로 렌더링
<Card>
  <CardContent className="p-0">
    <Table>  {/* 테이블이 Card 가장자리에 붙음 ❌ */}
      {/* ... */}
    </Table>
  </CardContent>
</Card>

// ❌ overflow만 있고 패딩 없음
<div className="overflow-x-auto">  {/* px 패딩 없음 ❌ */}
  <Table>...</Table>
</div>
```

---

## 추가 일관성 규칙

### 5. 액션 컬럼 정렬

```tsx
// 테이블 헤더
<TableHead className="whitespace-nowrap text-center">액션</TableHead>

// 테이블 셀
<TableCell className="text-center">
  <DropdownMenu>
    {/* ... */}
  </DropdownMenu>
</TableCell>
```

### 6. Badge 컴포넌트 사용

```tsx
// 상태 표시 - StatusBadge 또는 Badge 사용
import { Badge } from "@plan-master/web-platform/shadcn";

<Badge variant="secondary" className={statusColors[status]}>
  {statusLabels[status]}
</Badge>
```

### 7. 빈 상태 표시

```tsx
// 데이터 없을 때
<TableRow>
  <TableCell colSpan={columnCount} className="h-32 text-center text-muted-foreground">
    등록된 데이터가 없습니다.
  </TableCell>
</TableRow>
```

### 8. 검색 Input 패턴 (CRITICAL)

**반드시 `SearchInput` 컴포넌트를 사용:**
```tsx
import { SearchInput } from "@plan-master/web-platform";

<SearchInput
  value={searchKeyword}
  onChange={setSearchKeyword}
  placeholder="검색어를 입력하세요"
/>
```

**잘못된 패턴 (절대 금지):**
```tsx
// ❌ Search 아이콘 + Input 직접 조합
<div className="relative">
  <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
  <Input placeholder="검색어를 입력하세요" className="pl-9 w-[250px]" />
</div>
```

### 9. 버튼 색상 일관성

```tsx
// 주요 액션 버튼
<Button className="bg-[#0560fd] hover:bg-[#0560fd]/90">
  <Plus className="w-4 h-4 mr-2" />
  등록
</Button>

// 삭제/위험 버튼
<Button variant="outline" className="text-destructive hover:text-destructive">
  <Trash2 className="mr-2 h-4 w-4" />
  삭제
</Button>

// 보조 버튼
<Button variant="outline">
  {/* ... */}
</Button>
```

### 10. React 코드 품질 규칙 (CRITICAL)

**Fragment key**: `.map()` 내에서 다중 요소를 반환할 때 `Fragment`에 `key` 필수:
```tsx
// ✅ 올바른 패턴
import { Fragment } from "react";

{items.map((item) => (
  <Fragment key={item.id}>
    <TableRow>...</TableRow>
    {expanded && <TableRow>...</TableRow>}
  </Fragment>
))}

// ❌ 잘못된 패턴 - key 없는 Fragment
{items.map((item) => (
  <>
    <TableRow>...</TableRow>
    {expanded && <TableRow>...</TableRow>}
  </>
))}
```

**useMemo**: 필터링/정렬 등 파생 데이터는 반드시 `useMemo`로 감싸기:
```tsx
// ✅ 올바른 패턴
const filteredItems = useMemo(
  () => items.filter((item) => item.name.includes(search)),
  [items, search]
);

// ❌ 잘못된 패턴 - 렌더링마다 재계산
const filteredItems = items.filter((item) => item.name.includes(search));
```

**console.log 금지**: 디버깅용 `console.log`는 커밋 전 반드시 제거.

---

## ui-supervisor 검사 스크립트

### Grep 패턴으로 검사

```bash
# 1. PageTitle 사용 여부 확인
grep -r "PageTitle" apps/*/src/**/*.tsx
# ❌ 감지: <h1 또는 text-xl font-bold

# 2. Sheet 패딩 확인
grep -r "SheetContent" apps/*/src/**/*.tsx
# ❌ 감지: SheetContent 내부에 p-0만 있고 내부 래퍼에 패딩 없음

# 3. 달력 컴포넌트 확인
grep -r 'type="date"' apps/*/src/**/*.tsx
# ❌ 감지: input type="date"

# 4. 테이블 패딩 확인
grep -r "overflow-x-auto" apps/*/src/**/*.tsx
# ❌ 감지: overflow-x-auto 있는데 px- 패딩 없음
```

---

## 심각도 분류

| 심각도 | 항목 | 예시 |
|--------|------|------|
| **Critical** | PageTitle 미사용 | h1 직접 사용 |
| **Critical** | Sheet 패딩 누락 | FormSheet 미사용 + 패딩 없음 |
| **Critical** | 달력 컴포넌트 미사용 | input type="date" |
| **Critical** | 테이블 양끝 패딩 누락 | overflow 래퍼에 px 없음 |
| **Major** | 버튼 색상 불일치 | 다른 파란색 사용 |
| **Major** | 검색 Input 패턴 불일치 | Search 아이콘 위치 다름 |
| **Minor** | 빈 상태 메시지 스타일 | 다른 높이값 사용 |
| **Minor** | Badge 스타일 불일치 | 인라인 스타일 사용 |

---

## 체크리스트

### 코드 생성 시 (ui-designer)

- [ ] `PageTitle` 컴포넌트 import 및 사용
- [ ] `py-6 space-y-6` 컨테이너 패턴 적용
- [ ] Sheet 사용 시 `FormSheet` 컴포넌트 사용
- [ ] 날짜 선택 시 `DateRangeFilter` 또는 `DateRangePicker` 사용
- [ ] 테이블 래퍼에 `px-4 py-2` 패딩 적용
- [ ] 액션 컬럼 `text-center` 정렬
- [ ] 검색 입력은 `SearchInput` 컴포넌트 사용
- [ ] `.map()` 내 다중 요소 반환 시 `Fragment key` 적용
- [ ] 필터링/정렬 파생 데이터는 `useMemo` 사용
- [ ] `console.log` 디버그 코드 미포함 확인

### 코드 검사 시 (ui-supervisor)

- [ ] `<h1` 태그 직접 사용 여부 검사
- [ ] `SheetContent` 내부 패딩 여부 검사
- [ ] `type="date"` 사용 여부 검사
- [ ] 테이블 `overflow-x-auto` 래퍼의 `px-` 패딩 여부 검사
- [ ] 기존 동일 도메인 페이지와 패턴 비교
- [ ] `Search` 아이콘 + `Input` 직접 조합 대신 `SearchInput` 사용 여부
- [ ] `.map()` 내 `<>` (short Fragment) 대신 `<Fragment key>` 사용 여부
- [ ] 필터링/정렬 로직이 `useMemo`로 감싸져 있는지
- [ ] `console.log` 잔류 여부
