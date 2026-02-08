# Component Templates

**CRITICAL**: 모든 템플릿은 다음 규칙을 준수해야 합니다:
- `@plan-master/web-platform`에서 레이아웃 컴포넌트 import
- `@plan-master/web-platform/shadcn`에서 UI 컴포넌트 import
- React Hook Form, React Query, Zustand 등 필요한 라이브러리 자유롭게 사용

**CRITICAL**: 아래 4가지 일관성 규칙을 반드시 준수하세요.
> 상세 규칙은 `consistency-rules.md` 참조

| 규칙 | 올바른 패턴 | 잘못된 패턴 |
|------|------------|------------|
| 페이지 타이틀 | `PageTitle` 컴포넌트 + `py-6 space-y-6` | `<h1>` 직접 사용 |
| Sheet 패딩 | `FormSheet` 사용 또는 내부 `px-6 py-6` | 패딩 없이 SheetContent 사용 |
| 달력 컴포넌트 | `DateRangeFilter`/`DateRangePicker` | `<input type="date">` |
| 테이블 패딩 | `overflow-x-auto px-4 py-2` 래퍼 | 패딩 없이 Table 렌더링 |

## Vercel React Best Practices 필수 적용

```typescript
// ✅ DO: Direct imports (bundle-barrel-imports)
import { Button } from '@bitda/web-platform/shadcn/button';
import { Card } from '@bitda/web-platform/shadcn/card';

// ❌ DON'T: Barrel imports
import { Button, Card } from '@bitda/web-platform/shadcn';

// ✅ DO: Parallel data fetching (async-parallel)
const [users, products] = await Promise.all([
  fetchUsers(),
  fetchProducts()
]);

// ✅ DO: Dynamic imports for heavy components
const HeavyChart = dynamic(() => import('./HeavyChart'), {
  loading: () => <Skeleton />,
  ssr: false
});

// ✅ DO: Conditional rendering with ternary
{isOpen ? <Modal /> : null}

// ❌ DON'T: && operator for components
{isOpen && <Modal />}

// ✅ DO: Memoize expensive computations
const expensiveValue = useMemo(() => computeExpensive(data), [data]);
```

---

## List Screen (S) 패턴

```tsx
import { useState } from 'react';
import { PageTitle, DateRangeFilter } from '@plan-master/web-platform';
import {
  Card,
  CardContent,
  Button,
  Input,
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from '@plan-master/web-platform/shadcn';
import { Plus, Search } from 'lucide-react';

export default function FeaturePage() {
  const [data, setData] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const [startDate, setStartDate] = useState<string>();
  const [endDate, setEndDate] = useState<string>();

  return (
    {/* ✅ CRITICAL: py-6 space-y-6 컨테이너 패턴 */}
    <div className="container mx-auto py-6 space-y-6">
      {/* ✅ CRITICAL: 헤더 패턴 - PageTitle 사용 */}
      <div className="flex items-center justify-between">
        <div>
          <PageTitle>기능명</PageTitle>
          <p className="text-muted-foreground">
            기능 설명입니다.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button onClick={() => setIsSheetOpen(true)} className="bg-[#0560fd] hover:bg-[#0560fd]/90">
            <Plus className="mr-2 h-4 w-4" />
            등록
          </Button>
        </div>
      </div>

      {/* 필터 영역 */}
      <div className="flex items-center gap-2">
        {/* ✅ CRITICAL: 검색 Input 패턴 - Search 아이콘 + pl-9 */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="검색..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9 w-[250px]"
          />
        </div>

        {/* ✅ CRITICAL: 달력 컴포넌트 - DateRangeFilter 사용 */}
        <DateRangeFilter
          startDate={startDate}
          endDate={endDate}
          onChange={(start, end) => {
            setStartDate(start);
            setEndDate(end);
          }}
          placeholder="기간 선택"
          showPresets
        />
      </div>

      {/* 테이블 */}
      <Card>
        <CardContent className="p-0">
          {/* ✅ CRITICAL: 테이블 양끝 패딩 - px-4 py-2 */}
          <div className="overflow-x-auto px-4 py-2">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="whitespace-nowrap">컬럼1</TableHead>
                  <TableHead className="whitespace-nowrap">컬럼2</TableHead>
                  {/* ✅ 액션 컬럼 - text-center */}
                  <TableHead className="whitespace-nowrap text-center">액션</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.length === 0 ? (
                  {/* ✅ 빈 상태 패턴 - h-32 text-center */}
                  <TableRow>
                    <TableCell colSpan={3} className="h-32 text-center text-muted-foreground">
                      등록된 데이터가 없습니다.
                    </TableCell>
                  </TableRow>
                ) : (
                  data.map((item) => (
                    <TableRow key={item.id}>
                      <TableCell>{item.column1}</TableCell>
                      <TableCell>{item.column2}</TableCell>
                      <TableCell className="text-center">
                        {/* 액션 버튼/드롭다운 */}
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>

      {/* Sheet */}
      {/* <FeatureSheet open={isSheetOpen} onOpenChange={setIsSheetOpen} ... /> */}
    </div>
  );
}
```

---

## Form Sheet (F) 패턴

```tsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import {
  FormSheet,
  FormSheetFooter,
  Form,
  FormField,
  FormItem,
  FormLabel,
  FormControl,
  FormMessage,
  Button,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@plan-master/web-platform';

interface FeatureSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  editData?: FeatureData | null;
  onSubmit: (data: FeatureFormData) => void;
}

export function FeatureSheet({ open, onOpenChange, editData, onSubmit }: FeatureSheetProps) {
  const isEdit = !!editData;

  const form = useForm<FeatureFormData>({
    resolver: zodResolver(featureSchema),
    defaultValues: editData ?? { name: '', status: 'active' },
  });

  const handleSubmit = (data: FeatureFormData) => {
    onSubmit(data);
    onOpenChange(false);
  };

  return (
    {/* ✅ CRITICAL: FormSheet 사용 - 패딩 자동 적용 */}
    <FormSheet
      open={open}
      onOpenChange={onOpenChange}
      title={isEdit ? '수정' : '등록'}
      description={isEdit ? '정보를 수정합니다.' : '새 항목을 등록합니다.'}
      width="md"  {/* sm | md | lg | xl | 2xl */}
    >
      <Form {...form}>
        <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-5">
          <FormField
            control={form.control}
            name="name"
            render={({ field }) => (
              <FormItem>
                <FormLabel>이름 *</FormLabel>
                <FormControl>
                  <Input placeholder="이름을 입력하세요" className="h-10" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="status"
            render={({ field }) => (
              <FormItem>
                <FormLabel>상태 *</FormLabel>
                <Select onValueChange={field.onChange} defaultValue={field.value}>
                  <FormControl>
                    <SelectTrigger className="h-10">
                      <SelectValue placeholder="상태 선택" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    <SelectItem value="active">활성</SelectItem>
                    <SelectItem value="inactive">비활성</SelectItem>
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* ✅ CRITICAL: FormSheetFooter 사용 - 자동 스타일 적용 */}
          <FormSheetFooter>
            <Button
              type="button"
              variant="outline"
              className="px-6"
              onClick={() => onOpenChange(false)}
            >
              취소
            </Button>
            <Button type="submit" className="px-6 bg-[#0560fd] hover:bg-[#0560fd]/90">
              {isEdit ? '수정' : '등록'}
            </Button>
          </FormSheetFooter>
        </form>
      </Form>
    </FormSheet>
  );
}
```

---

## Delete Dialog (P) 패턴

```tsx
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel,
  AlertDialogContent, AlertDialogDescription,
  AlertDialogFooter, AlertDialogHeader, AlertDialogTitle,
} from '@plan-master/web-platform/shadcn';

interface DeleteDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onConfirm: () => Promise<void>;
  itemName?: string;
  isLoading?: boolean;
}

export function DeleteDialog({ open, onOpenChange, onConfirm, itemName, isLoading = false }: DeleteDialogProps) {
  const handleConfirm = async () => {
    await onConfirm();
    onOpenChange(false);
  };

  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>삭제 확인</AlertDialogTitle>
          <AlertDialogDescription>
            {itemName ? `"${itemName}"을(를) ` : ''}정말 삭제하시겠습니까?
            이 작업은 되돌릴 수 없습니다.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel disabled={isLoading}>취소</AlertDialogCancel>
          <AlertDialogAction
            onClick={handleConfirm}
            disabled={isLoading}
            className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
          >
            {isLoading ? '삭제 중...' : '삭제'}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
```

---

## Detail Dialog 패턴

```tsx
import {
  Dialog, DialogContent, DialogHeader,
  DialogTitle, DialogDescription, Button,
} from '@plan-master/web-platform/shadcn';

interface DetailDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  data: FeatureData | null;
  onEdit?: () => void;
}

export function DetailDialog({ open, onOpenChange, data, onEdit }: DetailDialogProps) {
  if (!data) return null;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle>상세 정보</DialogTitle>
          <DialogDescription>ID: {data.id}</DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-4">
          <div className="grid grid-cols-3 gap-4">
            <div className="text-sm font-medium text-muted-foreground">이름</div>
            <div className="col-span-2 text-sm">{data.name}</div>
          </div>
          <div className="grid grid-cols-3 gap-4">
            <div className="text-sm font-medium text-muted-foreground">상태</div>
            <div className="col-span-2 text-sm">{data.status}</div>
          </div>
        </div>

        {onEdit ? (
          <div className="flex justify-end">
            <Button onClick={onEdit}>수정</Button>
          </div>
        ) : null}
      </DialogContent>
    </Dialog>
  );
}
```

---

## Validation Schema 패턴

```tsx
// lib/validations/work-order.ts
import { z } from "zod";

export const workOrderSchema = z.object({
  productId: z.string().min(1, "제품을 선택해주세요"),
  quantity: z.number().min(1, "수량은 1 이상이어야 합니다"),
  dueDate: z.date({ required_error: "작업기한을 선택해주세요" }),
  assigneeId: z.string().optional(),
  notes: z.string().max(500, "메모는 500자 이내로 입력해주세요").optional(),
});

export type WorkOrderFormData = z.infer<typeof workOrderSchema>;
```
