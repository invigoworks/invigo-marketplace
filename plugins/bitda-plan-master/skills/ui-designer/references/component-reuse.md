# Component Reuse Guide

## 기존 컴포넌트 재사용 분석

### 탐색 순서

1. **공통 컴포넌트 패키지 탐색**
   ```bash
   Glob: packages/web-platform/src/components/**/*.tsx
   Grep: "export.*function|export.*const" in packages/web-platform
   ```

2. **도메인별 공유 컴포넌트 탐색**
   ```bash
   Glob: apps/[앱명]/src/components/**/*.tsx
   Glob: apps/[앱명]/src/**/components/shared/**/*.tsx
   ```

3. **유사 기능 페이지의 컴포넌트 탐색**
   ```bash
   Glob: apps/[앱명]/src/[도메인]/**/components/*.tsx
   ```

### 필수 탐색 대상

| UI 요소 | 탐색 키워드 | 일반적 위치 |
|---------|-------------|-------------|
| 시간 입력 | `TimeInput`, `TimePicker` | `web-platform/components` |
| 날짜 선택 | `DateRangePicker`, `DateRangeFilter` | `web-platform/components` |
| 검색 선택 | `SearchableSelect`, `ComboBox` | `web-platform/components` |
| 검색 입력 | `SearchInput` | `web-platform/components` |
| 상태 배지 | `StatusBadge`, `Badge` | `web-platform/shadcn` |
| 확인 다이얼로그 | `ConfirmDialog`, `AlertDialog` | `web-platform/components` |
| 다중 선택 다이얼로그 | `MultiItemSelectDialog` | `web-platform/components` |
| 폼 시트 | `FormSheet`, `FormSheetFooter` | `web-platform/components` |
| 데이터 테이블 | `DataTable`, `Table` | `web-platform/shadcn` |

### 탐색 결과 문서화 템플릿

```markdown
## 컴포넌트 재사용 분석 결과

### 발견된 재사용 가능 컴포넌트
| 필요 UI | 기존 컴포넌트 | 위치 | 재사용 결정 |
|---------|--------------|------|-------------|
| 시간 입력 | TimeInput | `@bitda/web-platform` | ✅ 재사용 |
| 거래처 선택 | PartnerSearchSelect | `apps/liquor/components` | ✅ 재사용 |
| 상태 표시 | (없음) | - | 🆕 신규 생성 |

### 신규 생성 필요 컴포넌트
| 컴포넌트 | 사유 | 예상 재사용 횟수 |
|----------|------|-----------------|
| OrderStatusBadge | 기존 없음, 3회 이상 사용 예상 | 5회 |
```

---

## 반복 UI 패턴 컴포넌트화

### 반복 패턴 식별 기준

| 반복 횟수 | 조치 | 예시 |
|----------|------|------|
| 1-2회 | 인라인 또는 로컬 구현 허용 | 특정 페이지 전용 버튼 |
| **3회 이상** | **반드시 컴포넌트화** | 상태 배지, 검색 셀렉트 |
| 앱 간 공유 | `@bitda/web-platform`에 추가 | 공통 폼 요소 |

### 분석 체크리스트 템플릿

```markdown
## 반복 UI 패턴 분석

### 현재 기획서에서 반복되는 UI 패턴
| 패턴 | 발견 위치 | 반복 횟수 | 컴포넌트화 여부 |
|------|----------|----------|----------------|
| 작업 상태 뱃지 | 목록, 상세, 폼 | 4회 | ✅ 필요 |
| 시간 입력 필드 | 시작시간, 종료시간, 휴식시간 | 3회 | ⚠️ 기존 확인 필요 |
| 수량+단위 입력 | 원재료, 생산량, 손실량 | 5회 | ✅ 필요 |

### 기존 유사 컴포넌트 존재 여부
| 신규 필요 패턴 | 유사 기존 컴포넌트 | 결정 |
|---------------|-------------------|------|
| 작업 상태 뱃지 | `StatusBadge` | 확장하여 사용 |
| 수량+단위 입력 | (없음) | `QuantityUnitInput` 신규 생성 |
```

### 컴포넌트화 결정 흐름

```
반복 UI 발견 → 기존 컴포넌트 탐색 → [있음] 재사용 / [없음] 반복 횟수 확인
                                              ↓
                                   [3회 이상] 컴포넌트 신규 생성
                                   [2회 이하] 인라인 구현 허용
```

### 컴포넌트 배치 기준

| 사용 범위 | 배치 위치 | 예시 |
|----------|----------|------|
| 단일 페이지 | `pages/[도메인]/[기능]/components/` | `OrderItemRow.tsx` |
| 도메인 공유 | `apps/[앱]/src/components/` | `ProductionStatusBadge.tsx` |
| 앱 간 공유 | `@bitda/web-platform/components/` | `TimeInput.tsx` |

---

## 하드코딩 방지 규칙

### ❌ BAD: 하드코딩된 반복 패턴
```tsx
<Badge variant={status === 'completed' ? 'success' : status === 'pending' ? 'warning' : 'default'}>
  {status === 'completed' ? '완료' : status === 'pending' ? '대기' : '진행중'}
</Badge>
// 이 코드가 3곳 이상에서 반복
```

### ✅ GOOD: 컴포넌트화
```tsx
<OrderStatusBadge status={status} />

// OrderStatusBadge.tsx
const statusConfig = {
  completed: { variant: 'success', label: '완료' },
  pending: { variant: 'warning', label: '대기' },
  in_progress: { variant: 'default', label: '진행중' },
};
```

### ❌ BAD: 반복되는 입력 패턴
```tsx
<div className="flex gap-2">
  <Input type="number" value={quantity} onChange={...} />
  <Select value={unit} onValueChange={...}>
    <SelectItem value="kg">kg</SelectItem>
    <SelectItem value="L">L</SelectItem>
  </Select>
</div>
// 이 패턴이 5곳에서 반복
```

### ✅ GOOD: 컴포넌트화
```tsx
<QuantityUnitInput
  quantity={quantity}
  unit={unit}
  onQuantityChange={setQuantity}
  onUnitChange={setUnit}
  unitOptions={['kg', 'L', 'EA']}
/>
```

---

## 기존 컴포넌트 교체 대상

| 현재 구현 | 교체 대상 | Import |
|----------|----------|--------|
| `<input type="time">` | `TimeInput` | `@bitda/web-platform` |
| `<input type="date">` | `DateRangePicker` | `@bitda/web-platform` |
| `Sheet` + 수동 패딩 | `FormSheet` | `@bitda/web-platform` |
| 직접 구현 검색 선택 | `SearchableSelect` | `@bitda/web-platform` |
| `<h1>` 페이지 타이틀 | `PageTitle` | `@bitda/web-platform` |
| `Search` 아이콘 + `Input` 조합 | `SearchInput` | `@bitda/web-platform` |
| 커스텀 다중선택 Popover | `MultiItemSelectDialog` | `@bitda/web-platform` |

---

## 컴포넌트 재사용 실패 방지 (기획봇 인사이트 #85)

> 기획봇 에스컬레이션에서 반복 발견된 컴포넌트 재사용 누락 패턴.

### 체크리스트

- [ ] **DownloadButton 재사용**: 다운로드/내보내기 버튼 구현 시 `@bitda/web-platform`의 `DownloadButton`을 먼저 확인했는가? 커스텀 구현 전 기존 컴포넌트의 prop API를 확인할 것.
- [ ] **모드별 필드 동작 분기**: 동일 폼에서 신규/수정 모드에 따라 필드 활성화/비활성화가 달라지는 경우, 모드별 disabled 조건을 컴포넌트 prop으로 분리했는가? (인라인 삼항 반복 방지)
- [ ] **유사 페이지 컴포넌트 참조**: 새 페이지 생성 시 동일 도메인의 유사 페이지에서 이미 사용 중인 컴포넌트 목록을 확인했는가?

### 근거 사례
- 재고 조정/이동 페이지에서 DownloadButton 대신 커스텀 버튼 구현 → 스타일 불일치 (인사이트 #85)
- 신규/수정 모드 필드 동작 차이를 인라인으로 반복 구현 → 동일 로직 3곳 이상 중복
