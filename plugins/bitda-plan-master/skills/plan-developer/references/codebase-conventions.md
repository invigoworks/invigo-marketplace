# Pre-Publishing Codebase Conventions

이 문서는 B&Bitda Admin 시스템(pre-publishing 저장소)의 코드 구조와 컨벤션을 정의합니다.
재설계 개발 시 이 패턴들을 준수하여 일관성 있는 코드를 생성해야 합니다.

---

## 1. Technology Stack

| Category | Technology | Version |
|----------|------------|---------|
| Framework | Vite + React | 6.3.5 / 18.3.1 |
| Language | TypeScript | Strict mode |
| Styling | Tailwind CSS | v4 |
| UI Library | shadcn/ui | new-york style |
| Form | React Hook Form + Zod | - |
| Table | TanStack React Table | v8.21.3 |
| Icons | Lucide React | - |
| Animation | Motion | - |
| Charts | Recharts | - |

---

## 2. Project Structure

```
/src
├── app/                              # Feature modules
│   ├── App.tsx                       # Main router
│   ├── shared/                       # Shared components
│   │   ├── StatusBadge.tsx
│   │   ├── DeleteDialog.tsx
│   │   ├── FormSheet.tsx
│   │   └── index.ts                 # Barrel export
│   ├── components/
│   │   └── admin/
│   │       └── AdminLayout.tsx      # Main layout
│   ├── [feature]/                   # Feature folder pattern
│   │   ├── page.tsx                 # Main page component
│   │   ├── types.ts                 # Interfaces + mock data
│   │   └── components/
│   │       ├── [Feature]Table.tsx   # Table component
│   │       ├── [Feature]Sheet.tsx   # Form sheet
│   │       ├── columns.tsx          # Table column definitions
│   │       └── index.ts             # Barrel export
│   └── data/
│       └── roles.ts                 # Global data + helpers
├── components/
│   └── ui/                          # shadcn/ui components
├── lib/
│   └── utils.ts                     # cn() utility
├── styles/
│   ├── tailwind.css
│   ├── theme.css                    # Design tokens
│   └── index.css
└── main.tsx                         # Entry point
```

---

## 3. Feature Folder Pattern

모든 기능은 `/src/app/[feature]/` 구조를 따릅니다:

### 3.1 page.tsx (Main Page Component)

```typescript
"use client";

import { useState, useMemo } from "react";
import { Button } from "@/components/ui/button";
import { Plus } from "lucide-react";
import { FeatureTable, FeatureSheet } from "./components";
import { DeleteDialog } from "@/app/shared";
import { Feature, mockFeatures, type FeatureFormData } from "./types";

export default function FeaturePage() {
  // 1. State definitions
  const [data, setData] = useState<Feature[]>(mockFeatures);
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const [isDeleteOpen, setIsDeleteOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<Feature | null>(null);
  const [deletingItem, setDeletingItem] = useState<Feature | null>(null);

  // 2. Event handlers
  const handleOpenSheet = (item?: Feature) => {
    setEditingItem(item || null);
    setIsSheetOpen(true);
  };

  const handleOpenDeleteDialog = (item: Feature) => {
    setDeletingItem(item);
    setIsDeleteOpen(true);
  };

  const handleSubmit = (formData: FeatureFormData) => {
    if (editingItem) {
      // Update logic
      setData(prev => prev.map(item =>
        item.id === editingItem.id ? { ...item, ...formData } : item
      ));
    } else {
      // Create logic
      const newItem: Feature = {
        id: generateId(),
        ...formData,
        createdAt: new Date().toISOString(),
      };
      setData(prev => [...prev, newItem]);
    }
    setIsSheetOpen(false);
    setEditingItem(null);
  };

  const handleDelete = () => {
    if (deletingItem) {
      setData(prev => prev.filter(item => item.id !== deletingItem.id));
    }
    setIsDeleteOpen(false);
    setDeletingItem(null);
  };

  // 3. Render
  return (
    <div className="container mx-auto py-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">기능명</h1>
          <p className="text-muted-foreground">기능 설명</p>
        </div>
        <Button onClick={() => handleOpenSheet()}>
          <Plus className="mr-2 h-4 w-4" />
          등록
        </Button>
      </div>

      {/* Table */}
      <FeatureTable
        data={data}
        onEdit={handleOpenSheet}
        onDelete={handleOpenDeleteDialog}
      />

      {/* Sheet */}
      <FeatureSheet
        open={isSheetOpen}
        onOpenChange={setIsSheetOpen}
        editData={editingItem}
        onSubmit={handleSubmit}
      />

      {/* Delete Dialog */}
      <DeleteDialog
        open={isDeleteOpen}
        onOpenChange={setIsDeleteOpen}
        onConfirm={handleDelete}
        title="삭제 확인"
        itemName={deletingItem?.name}
      />
    </div>
  );
}
```

### 3.2 types.ts (Type Definitions + Mock Data)

```typescript
// Interface for the data model
export interface Feature {
  id: string;
  name: string;
  status: "active" | "inactive" | "pending";
  createdAt: string;
  updatedAt?: string;
}

// Interface for form data (may differ from model)
export interface FeatureFormData {
  name: string;
  status: "active" | "inactive" | "pending";
}

// Mock data for development
export const mockFeatures: Feature[] = [
  {
    id: "FEAT25010001",
    name: "샘플 데이터 1",
    status: "active",
    createdAt: "2025-01-01T00:00:00Z",
  },
  // ... more mock data
];

// Select options (if needed)
export const statusOptions = [
  { value: "active", label: "활성" },
  { value: "inactive", label: "비활성" },
  { value: "pending", label: "대기" },
];
```

### 3.3 components/[Feature]Table.tsx

```typescript
"use client";

import {
  useReactTable,
  getCoreRowModel,
  getPaginationRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  type SortingState,
  type ColumnFiltersState,
} from "@tanstack/react-table";
import { useState } from "react";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { createColumns, type ColumnActions } from "./columns";
import { type Feature } from "../types";

interface FeatureTableProps {
  data: Feature[];
  onEdit: (item: Feature) => void;
  onDelete: (item: Feature) => void;
}

export function FeatureTable({ data, onEdit, onDelete }: FeatureTableProps) {
  const [sorting, setSorting] = useState<SortingState>([]);
  const [columnFilters, setColumnFilters] = useState<ColumnFiltersState>([]);
  const [rowSelection, setRowSelection] = useState({});

  const actions: ColumnActions = { onEdit, onDelete };
  const columns = createColumns(actions);

  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getSortedRowModel: getSortedRowModel(),
    onSortingChange: setSorting,
    onColumnFiltersChange: setColumnFilters,
    onRowSelectionChange: setRowSelection,
    state: { sorting, columnFilters, rowSelection },
  });

  return (
    <div className="space-y-4">
      {/* Search/Filter */}
      <div className="flex items-center gap-2">
        <Input
          placeholder="검색..."
          value={(table.getColumn("name")?.getFilterValue() as string) ?? ""}
          onChange={(e) =>
            table.getColumn("name")?.setFilterValue(e.target.value)
          }
          className="max-w-sm"
        />
      </div>

      {/* Table */}
      <div className="rounded-md border">
        <Table>
          <TableHeader>
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id}>
                {headerGroup.headers.map((header) => (
                  <TableHead key={header.id}>
                    {/* Header content */}
                  </TableHead>
                ))}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {table.getRowModel().rows?.length ? (
              table.getRowModel().rows.map((row) => (
                <TableRow key={row.id}>
                  {row.getVisibleCells().map((cell) => (
                    <TableCell key={cell.id}>
                      {/* Cell content */}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={columns.length} className="h-24 text-center">
                  데이터가 없습니다.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      {/* Pagination */}
      <div className="flex items-center justify-between">
        <span className="text-sm text-muted-foreground">
          {table.getFilteredSelectedRowModel().rows.length} / {" "}
          {table.getFilteredRowModel().rows.length} 선택
        </span>
        {/* Pagination buttons */}
      </div>
    </div>
  );
}
```

### 3.4 components/columns.tsx

```typescript
import { type ColumnDef } from "@tanstack/react-table";
import { Checkbox } from "@/components/ui/checkbox";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { MoreHorizontal, Pencil, Trash2 } from "lucide-react";
import { StatusBadge } from "@/app/shared";
import { type Feature } from "../types";

export interface ColumnActions {
  onEdit: (item: Feature) => void;
  onDelete: (item: Feature) => void;
}

export const createColumns = (actions: ColumnActions): ColumnDef<Feature>[] => [
  {
    id: "select",
    header: ({ table }) => (
      <Checkbox
        checked={table.getIsAllPageRowsSelected()}
        onCheckedChange={(value) => table.toggleAllPageRowsSelected(!!value)}
        aria-label="전체 선택"
      />
    ),
    cell: ({ row }) => (
      <Checkbox
        checked={row.getIsSelected()}
        onCheckedChange={(value) => row.toggleSelected(!!value)}
        aria-label="행 선택"
      />
    ),
  },
  {
    accessorKey: "name",
    header: "이름",
    cell: ({ row }) => <span>{row.getValue("name")}</span>,
  },
  {
    accessorKey: "status",
    header: "상태",
    cell: ({ row }) => (
      <StatusBadge status={row.getValue("status")} />
    ),
  },
  {
    id: "actions",
    cell: ({ row }) => {
      const item = row.original;
      return (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon">
              <MoreHorizontal className="h-4 w-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onClick={() => actions.onEdit(item)}>
              <Pencil className="mr-2 h-4 w-4" />
              수정
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={() => actions.onDelete(item)}
              className="text-destructive"
            >
              <Trash2 className="mr-2 h-4 w-4" />
              삭제
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      );
    },
  },
];
```

### 3.4 개발 작업 규칙 (협업 모드)

> **참고**: 기획자와 프론트엔드 개발자가 동일한 코드베이스에서 자유롭게 협업합니다.

#### 3.4.1 목적

- UI/UX 검증과 실제 개발을 통합하여 효율적인 협업
- 모든 개발 리소스에 자유롭게 접근하여 완성도 높은 기능 구현
- 개발-기획 간 빠른 피드백 루프 형성

#### 3.4.2 작업 가능 범위

✅ **자유롭게 가능한 작업:**

- `pages/` 폴더에서 UI 컴포넌트 작성 및 수정
- `router.tsx` 직접 수정 및 라우트 추가
- `services/` 서비스 레이어 수정
- `packages/core/` 직접 수정
- React Query, Zustand 등 상태 관리 라이브러리 자유롭게 사용
- 실제 API 호출 코드 작성
- `store/` 폴더 수정
- `@bitda/web-platform/shadcn`에서 UI 컴포넌트 import
- `PageLayout` 등 레이아웃 컴포넌트 사용
- 화면 간 네비게이션 플로우 정의

#### 3.4.3 개발 시 권장 사항

- 변경 사항에 대한 명확한 커밋 메시지 작성
- 복잡한 비즈니스 로직은 주석으로 설명 추가
- 공유 컴포넌트 수정 시 영향 범위 확인

#### 3.4.4 비즈니스 로직 문서화 방법

```typescript
/**
 * 작업지시 목록 조회
 *
 * API: GET /production/orders
 * Response: WorkOrder[]
 */
const { data: orders, isLoading } = useQuery({
  queryKey: ['work-orders'],
  queryFn: () => api.getWorkOrders(),
});

/**
 * 작업지시 생성
 *
 * API: POST /production/orders
 * Request: { productId, quantity, lineId, scheduledDate }
 * Response: WorkOrder
 */
const mutation = useMutation({
  mutationFn: (data: CreateOrderDto) => api.createWorkOrder(data),
  onSuccess: () => {
    queryClient.invalidateQueries(['work-orders']);
    toast.success('작업지시가 등록되었습니다.');
  },
});

/**
 * 유효성 검사
 * - 수량: 양수만 허용
 * - 날짜: 오늘 이후만 선택 가능
 */
const schema = z.object({
  quantity: z.number().positive('1 이상의 숫자를 입력하세요'),
  scheduledDate: z.date().min(new Date(), '오늘 이후 날짜만 선택 가능합니다'),
});
```

#### 3.4.5 폴더 구조

```
apps/[app-name]/src/
├── pages/                  # 페이지 컴포넌트
│   ├── index.ts            # Barrel export
│   ├── DashboardPage.tsx   # 대시보드
│   ├── production/         # 생산 도메인
│   │   ├── index.ts
│   │   ├── PlanPage.tsx    # 생산계획
│   │   ├── OrderPage.tsx   # 작업지시
│   │   └── ResultPage.tsx  # 생산실적
│   ├── quality/            # 품질 도메인
│   │   ├── index.ts
│   │   ├── InspectionPage.tsx
│   │   └── DefectPage.tsx
│   └── inventory/          # 재고 도메인
│       ├── index.ts
│       └── StockPage.tsx
├── router.tsx              # 라우터 설정
├── services/               # 서비스 레이어
├── store/                  # 상태 관리 (Zustand)
└── hooks/                  # 커스텀 훅 (React Query 등)
```

#### 3.4.6 router.tsx 작성 패턴

```typescript
/**
 * App Router
 *
 * 모든 페이지 라우트를 정의합니다.
 */
import type { RouteObject } from 'react-router-dom';
import { DashboardPage } from './pages/DashboardPage';
import { PlanPage, OrderPage, ResultPage } from './pages/production';
import { InspectionPage, DefectPage } from './pages/quality';

export const routes: RouteObject[] = [
  { index: true, element: <DashboardPage /> },
  { path: 'production/plan', element: <PlanPage /> },
  { path: 'production/order', element: <OrderPage /> },
  { path: 'production/result', element: <ResultPage /> },
  { path: 'quality/inspection', element: <InspectionPage /> },
  { path: 'quality/defect', element: <DefectPage /> },
];
```

#### 3.4.7 페이지 컴포넌트 작성 패턴

```typescript
/**
 * [화면명] 페이지
 *
 * 기능:
 * - 목록 조회 및 검색
 * - 신규 등록/수정/삭제
 * - 상태 필터링
 */
import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { PageLayout } from '@bitda/web-platform';
import {
  Card, CardContent, CardHeader, CardTitle,
  Button, Input, Select
} from '@bitda/web-platform/shadcn';
import { api } from '@/services';
import { useStore } from '@/store';

export function FeaturePage() {
  const queryClient = useQueryClient();
  const { filters, setFilters } = useStore();

  // 데이터 조회
  const { data, isLoading } = useQuery({
    queryKey: ['features', filters],
    queryFn: () => api.getFeatures(filters),
  });

  // 생성 mutation
  const createMutation = useMutation({
    mutationFn: api.createFeature,
    onSuccess: () => {
      queryClient.invalidateQueries(['features']);
      toast.success('등록되었습니다.');
    },
  });

  return (
    <PageLayout title="화면명" description="화면 설명">
      {/* UI 구현 */}
    </PageLayout>
  );
}
```

#### 3.4.8 워크플로우

```
[개발 프로세스]
1. pages/ 폴더에 UI 컴포넌트 작성
2. router.tsx에 라우트 추가
3. services/ 및 hooks/에 API 연동 코드 작성
4. store/에 필요한 전역 상태 추가
5. preview 앱에서 테스트 (pnpm dev:preview)
6. PR 생성 및 리뷰
7. 머지
```

### 3.5 components/[Feature]Sheet.tsx

```typescript
"use client";

import { useEffect } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { FormSheet } from "@/app/shared";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { type Feature, type FeatureFormData, statusOptions } from "../types";

const schema = z.object({
  name: z.string().min(1, "필수 항목입니다").max(100, "최대 100자"),
  status: z.enum(["active", "inactive", "pending"]),
});

interface FeatureSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  editData: Feature | null;
  onSubmit: (data: FeatureFormData) => void;
}

export function FeatureSheet({
  open,
  onOpenChange,
  editData,
  onSubmit,
}: FeatureSheetProps) {
  const form = useForm<FeatureFormData>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: "",
      status: "active",
    },
  });

  useEffect(() => {
    if (editData) {
      form.reset({
        name: editData.name,
        status: editData.status,
      });
    } else {
      form.reset({
        name: "",
        status: "active",
      });
    }
  }, [editData, form]);

  const handleSubmit = (data: FeatureFormData) => {
    onSubmit(data);
    form.reset();
  };

  return (
    <FormSheet
      open={open}
      onOpenChange={onOpenChange}
      title={editData ? "수정" : "등록"}
      description={editData ? "정보를 수정합니다." : "새 항목을 등록합니다."}
    >
      <Form {...form}>
        <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4">
          <FormField
            control={form.control}
            name="name"
            render={({ field }) => (
              <FormItem>
                <FormLabel>이름</FormLabel>
                <FormControl>
                  <Input placeholder="이름 입력" {...field} />
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
                <FormLabel>상태</FormLabel>
                <Select
                  onValueChange={field.onChange}
                  defaultValue={field.value}
                >
                  <FormControl>
                    <SelectTrigger>
                      <SelectValue placeholder="상태 선택" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {statusOptions.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )}
          />

          <div className="flex justify-end gap-2 pt-4">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
            >
              취소
            </Button>
            <Button type="submit">
              {editData ? "수정" : "등록"}
            </Button>
          </div>
        </form>
      </Form>
    </FormSheet>
  );
}
```

---

## 4. Shared Components

### 4.1 StatusBadge

```typescript
import { Badge } from "@/components/ui/badge";

interface StatusBadgeProps {
  status: "active" | "inactive" | "pending";
  labels?: {
    active?: string;
    inactive?: string;
    pending?: string;
  };
}

const defaultLabels = {
  active: "활성",
  inactive: "비활성",
  pending: "대기",
};

const variantMap = {
  active: "default",
  inactive: "secondary",
  pending: "outline",
} as const;

export function StatusBadge({ status, labels = defaultLabels }: StatusBadgeProps) {
  return (
    <Badge variant={variantMap[status]}>
      {labels[status]}
    </Badge>
  );
}
```

### 4.2 DeleteDialog

```typescript
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { AlertTriangle } from "lucide-react";

interface DeleteDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onConfirm: () => void;
  title?: string;
  itemName?: string;
  description?: string;
}

export function DeleteDialog({
  open,
  onOpenChange,
  onConfirm,
  title = "삭제 확인",
  itemName,
  description,
}: DeleteDialogProps) {
  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle className="flex items-center gap-2">
            <AlertTriangle className="h-5 w-5 text-destructive" />
            {title}
          </AlertDialogTitle>
          <AlertDialogDescription>
            {description || (
              <>
                {itemName && <strong>'{itemName}'</strong>}을(를) 삭제하시겠습니까?
                <br />
                이 작업은 되돌릴 수 없습니다.
              </>
            )}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>취소</AlertDialogCancel>
          <AlertDialogAction onClick={onConfirm} className="bg-destructive">
            삭제
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
```

### 4.3 FormSheet

```typescript
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { ScrollArea } from "@/components/ui/scroll-area";

interface FormSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description?: string;
  children: React.ReactNode;
  width?: "sm" | "md" | "lg";
}

const widthMap = {
  sm: "w-[400px] sm:w-[450px]",
  md: "w-[500px] sm:w-[600px]",
  lg: "w-[600px] sm:w-[800px]",
};

export function FormSheet({
  open,
  onOpenChange,
  title,
  description,
  children,
  width = "md",
}: FormSheetProps) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className={widthMap[width]}>
        <SheetHeader>
          <SheetTitle>{title}</SheetTitle>
          {description && <SheetDescription>{description}</SheetDescription>}
        </SheetHeader>
        <ScrollArea className="h-[calc(100vh-8rem)] pr-4">
          <div className="py-4">{children}</div>
        </ScrollArea>
      </SheetContent>
    </Sheet>
  );
}
```

---

## 5. Naming Conventions

### 5.1 Files & Directories

| Type | Convention | Example |
|------|------------|---------|
| Components | PascalCase | `UserTable.tsx`, `CompanySheet.tsx` |
| Utilities | camelCase | `utils.ts`, `roles.ts` |
| Feature dirs | kebab-case | `user-management/`, `work-orders/` |
| Type files | camelCase | `types.ts` |

### 5.2 ID Generation

```typescript
// Pattern: {PREFIX}{YY}{MM}{SEQ:4}
// Examples:
// - Users: USR25010001, USR25010002
// - Companies: COM25010001
// - Features: [PREFIX]25010001

function generateId(prefix: string): string {
  const now = new Date();
  const yy = now.getFullYear().toString().slice(-2);
  const mm = (now.getMonth() + 1).toString().padStart(2, '0');
  const seq = Math.floor(Math.random() * 9999).toString().padStart(4, '0');
  return `${prefix}${yy}${mm}${seq}`;
}
```

### 5.3 Component Props Interface

```typescript
// Always suffix with Props
interface FeatureTableProps {
  data: Feature[];
  onEdit: (item: Feature) => void;
  onDelete: (item: Feature) => void;
}

// Event handlers: on[Action]
// Callbacks: handle[Action]
```

---

## 6. Styling Guide

### 6.1 Tailwind Classes

```typescript
// Layout
<div className="container mx-auto py-6 space-y-6">

// Card/Panel
<div className="rounded-md border p-4">

// Flex layouts
<div className="flex items-center justify-between gap-2">

// Grid layouts (forms)
<div className="grid grid-cols-2 gap-4">

// Text styles
<h1 className="text-2xl font-bold">
<p className="text-muted-foreground">
<span className="text-sm">
```

### 6.2 Design Tokens

Primary color: `#0560fd`

CSS Variables (defined in theme.css):
```css
--primary: #0560fd;
--background: #ecf5fc;
--border: #e5eaef;
--foreground: #000000;
--muted: #f1f5f9;
--muted-foreground: #64748b;
```

---

## 7. Import Patterns

```typescript
// UI Components (from shadcn/ui)
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Dialog, DialogContent, DialogHeader } from "@/components/ui/dialog";

// Form libraries
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

// Table library
import { useReactTable, getCoreRowModel } from "@tanstack/react-table";
import type { ColumnDef } from "@tanstack/react-table";

// Shared components
import { StatusBadge, DeleteDialog, FormSheet } from "@/app/shared";

// Icons
import { Plus, Trash2, Pencil, MoreHorizontal, Search } from "lucide-react";

// Utilities
import { cn } from "@/lib/utils";
```

---

## 8. Form Validation Patterns

### 8.1 Common Zod Schemas

```typescript
// Required string
z.string().min(1, "필수 항목입니다")

// Optional string
z.string().optional()

// Email
z.string().email("유효한 이메일을 입력하세요")

// Phone (Korean format)
z.string().regex(/^\d{2,3}-\d{3,4}-\d{4}$/, "올바른 전화번호 형식")

// Business number (사업자등록번호)
z.string().regex(/^\d{3}-\d{2}-\d{5}$/, "000-00-00000 형식")

// Number
z.coerce.number().min(0, "0 이상의 숫자")

// Status enum
z.enum(["active", "inactive", "pending"])

// Date
z.string().datetime()

// Optional email (empty string allowed)
z.string().email().optional().or(z.literal(""))
```

### 8.2 Form Error Messages (Korean)

```typescript
const errorMessages = {
  required: "필수 항목입니다",
  email: "유효한 이메일을 입력하세요",
  min: (n: number) => `최소 ${n}자 이상`,
  max: (n: number) => `최대 ${n}자 이하`,
  pattern: "올바른 형식이 아닙니다",
};
```

---

## 9. API Integration Pattern (Future)

현재는 mock data를 사용하지만, 향후 API 연동 시 다음 패턴 적용:

```typescript
// hooks/use[Feature].ts
export function useFeatures() {
  const [data, setData] = useState<Feature[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchFeatures = async () => {
    try {
      setIsLoading(true);
      const response = await api.get('/features');
      setData(response.data);
    } catch (err) {
      setError(err as Error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchFeatures();
  }, []);

  return { data, isLoading, error, refetch: fetchFeatures };
}
```

---

## 10. Checklist for New Features

새 기능 개발 시 다음 항목 확인:

### 파일 구조
- [ ] `/src/app/[feature]/page.tsx` 생성
- [ ] `/src/app/[feature]/types.ts` 생성
- [ ] `/src/app/[feature]/components/` 디렉토리 생성
- [ ] `[Feature]Table.tsx` 생성
- [ ] `[Feature]Sheet.tsx` 생성
- [ ] `columns.tsx` 생성
- [ ] `index.ts` (barrel export) 생성

### 컴포넌트 체크
- [ ] StatusBadge 활용 (상태 표시 시)
- [ ] DeleteDialog 활용 (삭제 기능 시)
- [ ] FormSheet 활용 (폼 시트 시)
- [ ] 한글 UI 텍스트 적용

### 폼 체크
- [ ] Zod 스키마 정의
- [ ] React Hook Form 적용
- [ ] 에러 메시지 한글화
- [ ] 필수/선택 필드 명시

### 테이블 체크
- [ ] TanStack React Table 적용
- [ ] 선택(Checkbox) 컬럼
- [ ] 검색/필터 기능
- [ ] 페이지네이션
- [ ] 액션 드롭다운 메뉴
