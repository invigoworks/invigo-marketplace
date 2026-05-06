---
name: verify-runtime-data
description: 런타임 데이터 불일치 버그 패턴 10가지를 자동 검증하는 스킬. availableQty/currentQty 불일치, stocks 빈 배열, formatDate NaN, purchaseDate 접근, entity 필수 필드 누락, refId UUID 노출, currentStock 하드코딩, defaultWarehouseId 미전달, evidence count NaN, 컬럼-셀 순서 불일치 등을 grep 기반으로 전수 검사.
---

# Runtime Data Inconsistency Verifier

이 스킬은 plan-master 레포에서 반복 발생한 런타임 데이터 불일치 버그 패턴 6가지를 자동으로 검증한다.
Wave 4+5 구현 과정에서 발견된 패턴들이며, 새 코드 작성 시 동일 패턴이 재발하지 않도록 사전 검증한다.

## 실행 조건

- `/verify-implementation` 실행 시 자동 호출
- 재고관리 모듈(`apps/liquor/src/inventory/`) 또는 core repo(`packages/core/base/src/repository/`) 변경 후
- "런타임 데이터 검증", "데이터 불일치 검사" 요청 시

## 검증 패턴 6가지

### 패턴 1: `availableQty` without `currentQty` fallback

**문제**: LotEntity에는 `currentQty`만 존재하지만, UI 레이어의 ShipmentLot 등에서 `availableQty`를 사용. LotEntity가 직접 전달되면 `undefined > 0 === false` → 빈 목록.

**검증 명령**:
```bash
grep -rn "\.availableQty" apps/liquor/src/inventory/ --include="*.tsx" --include="*.ts" \
  | grep -v "node_modules\|seed-data\|mock-data\|types\.ts\|interface \|export \|\.d\.ts" \
  | grep -v "?? .*currentQty"
```

**판정**: 결과가 있으면 ❌ — `(lot.availableQty ?? lot.currentQty ?? 0)` fallback 필요.

---

### 패턴 2: `stocks: []` 하드코딩

**문제**: 품목 데이터 구성 시 `stocks: []`로 하드코딩하면 창고 선택 목록과 재고 수량이 비어있음.

**검증 명령**:
```bash
grep -rn "stocks: \[\]" apps/liquor/src/inventory/ --include="*.tsx" --include="*.ts" \
  | grep -v "node_modules\|seed-data\|mock-data\|\.test\.\|__tests__"
```

**판정**: 결과가 있으면 ⚠️ — Lot 기반으로 재고 데이터를 조회하는지 확인 필요. `useLotQuery`의 `getProductLotsByWarehouse` 등을 사용해야 함.

---

### 패턴 3: `formatDate` NaN

**문제**: `formatDate(undefined)` 또는 `new Date(undefined).getTime()` → NaN 표시.

**검증 명령**:
```bash
# formatDate에 undefined 가능 필드를 직접 전달하는 곳
grep -rn "formatDate(lot\.\|formatDate(item\.\|formatDate(entry\." apps/liquor/src/inventory/ --include="*.tsx" --include="*.ts" \
  | grep -v "node_modules\|seed-data\|mock-data" \
  | grep -v "|| ''" | grep -v "|| lot\." | grep -v "?? "

# new Date()에 undefined 가능 필드를 직접 전달하는 곳
grep -rn "new Date(.*\.purchaseDate)" apps/liquor/src/inventory/ --include="*.tsx" --include="*.ts" \
  | grep -v "node_modules\|seed-data\|mock-data" \
  | grep -v "|| .*createdAt\||| 0\||| ''"
```

**판정**: 결과가 있으면 ❌ — `formatDate(lot.purchaseDate || lot.createdAt || '')` 같은 fallback 필요.

---

### 패턴 4: `purchaseDate` 접근 on LotEntity

**문제**: `LotEntity`에는 `purchaseDate` 필드가 없고 `createdAt`만 있음. UI mock 타입(`ShipmentLot`, `LotItem`)에는 있지만, 실제 LotEntity가 전달되면 undefined.

**검증 명령**:
```bash
grep -rn "\.purchaseDate" apps/liquor/src/inventory/ --include="*.tsx" --include="*.ts" \
  | grep -v "node_modules\|seed-data\|mock-data\|types\.ts\|interface \|export \|\.d\.ts\|// \|/\*" \
  | grep -v "|| .*createdAt\|?? .*createdAt\|purchaseDateFilter"
```

**판정**: 결과가 있으면 ⚠️ — `lot.purchaseDate || lot.createdAt || ''` fallback 확인 필요.

---

### 패턴 5: Entity 생성 시 필수 필드 누락

**문제**: 폼에서 entity 생성 시 `remainingQuantity`, `receivedQuantity`, `purchaseOrderId` 등 repo가 기대하는 필수 필드를 누락하면 필터링에서 제외되거나 throw 발생.

**검증 명령**:
```bash
# 구매 발주서 items에 remainingQuantity 누락 확인
grep -rn "items:.*map.*item.*=>" apps/liquor/src/inventory/purchase/form-page.tsx --include="*.tsx" \
  | head -5

# 판매주문 items에 lotId 빈 문자열 확인 — onAfterUpdate에서 빈 lotId 차감 시도 방지
grep -rn "lotId:.*item\." apps/liquor/src/inventory/sales/page.tsx --include="*.tsx" \
  | grep -v "&&.*item\.lotId"
```

**판정**: 수동 확인 필요 — 각 폼의 submit에서 생성하는 DTO가 repo의 entity 타입과 일치하는지 대조.

---

### 패턴 6: `refId` UUID가 UI에 그대로 노출

**문제**: ledger entry의 `refId`(entity ID, UUID)가 Lot 이력 등에서 사람이 읽을 수 없는 형태로 표시.

**검증 명령**:
```bash
# referenceId에 e.refId를 직접 사용하는 곳
grep -rn "referenceId.*refId\|refId.*referenceId" apps/liquor/src/inventory/ --include="*.tsx" --include="*.ts" \
  | grep -v "reason\|e\.reason"

# ledger append에서 reason 필드에 사람이 읽을 수 있는 문자열이 들어가는지
grep -rn "reason:" packages/core/base/src/repository/ --include="*.ts" \
  | grep "ledgerRepo\|\.append" \
  | grep -v "test\|__tests__\|entity\.reason\|entity\.memo\|line\.reason\|data\.reason\|판매출고\|구매입고\|생산입고"
```

**판정**: `referenceId: e.refId` 직접 사용 시 ❌ — `referenceId: e.reason || e.refId` 로 변경 필요.

---

### 패턴 7: `currentStock: 0` 하드코딩 (Lot 미집계)

**문제**: 폼 페이지에서 품목 목록 생성 시 `currentStock: 0`으로 하드코딩하여 현재고가 표시되지 않음. Lot repo에서 품목별 currentQty 합계를 계산해야 함.

**검증 명령**:
```bash
grep -rn "currentStock: 0" apps/liquor/src/inventory/ --include="*.tsx" --include="*.ts" \
  | grep -v "node_modules\|seed-data\|mock-data\|createEmpty\|default"
```

**판정**: products/allProducts 배열 초기화에서 `currentStock: 0`이 있으면 ❌ — `stockByItemId.get(id) ?? 0` 기반 집계 필요.

---

### 패턴 8: `defaultWarehouseId` 미전달 (품목 선택 시 창고 미로드)

**문제**: 품목 선택 핸들러에서 `warehouseId: ""` 또는 `warehouseId: ''`로 하드코딩하여 제품의 기본 지정 창고를 불러오지 않음.

**검증 명령**:
```bash
# 품목 선택 핸들러에서 warehouseId를 빈 문자열로 설정하는 곳
grep -rn "warehouseId: ['\"]'*['\"]" apps/liquor/src/inventory/ --include="*.tsx" --include="*.ts" \
  | grep -v "node_modules\|seed-data\|mock-data\|createEmpty\|default\|push(\|빈 행"
```

**판정**: handleProductSelect/handleItemSelect 내에서 `warehouseId: ""` 또는 `warehouseId: ''`가 있으면 ❌ — `product.defaultWarehouseId || ""` 사용 필요.

예외: createEmptyItem()의 초기값, 빈 행 추가, movement(폼 레벨 창고), adjustment(폼 레벨 창고)는 제외.

---

### 패턴 9: `evidenceRegisteredCount`/`evidenceRequiredCount` undefined (NaN 표시)

**문제**: repo 엔티티에 evidence 카운트 필드가 없어 view hook에서 합산 시 `undefined + undefined = NaN` → UI에 "NaN/NaN" 표시.

**검증 명령**:
```bash
# evidenceRegisteredCount/RequiredCount를 합산하는데 ?? 0 fallback이 없는 곳
grep -rn "\.evidenceRegisteredCount\|\.evidenceRequiredCount" apps/liquor/src/ --include="*.tsx" --include="*.ts" \
  | grep "reduce\|sum\|+=" \
  | grep -v "?? 0"
```

**판정**: reduce/합산에서 `?? 0` fallback이 없으면 ❌.

---

### 패턴 10: 테이블 컬럼-셀 순서 불일치

**문제**: TableHead 순서를 변경했지만 TableBody의 TableCell 순서를 동기화하지 않아 데이터가 잘못된 컬럼에 표시됨.

**검증 방법**: 수동 확인 필요. 자동화 어려움.
- 각 form-page의 `<TableHeader>` 내 `<TableHead>` 순서와 `<TableBody>` 내 `<TableCell>` 순서가 일치하는지 확인.
- 특히 컬럼 재배치 후 셀 순서를 동기화하지 않은 경우 발생.

**판정**: ⚠️ 수동 확인 — 컬럼 재배치 작업 후 반드시 헤더-셀 순서 대조.

---

## 실행 절차

1. 위 10개 패턴의 grep 명령을 순서대로 실행
2. 각 패턴별 결과를 ✅(잔존 없음) / ❌(잔존 발견) / ⚠️(수동 확인 필요)로 분류
3. 결과 테이블 출력:

```
## 런타임 데이터 불일치 검증 결과

| # | 패턴 | 상태 | 잔존 건수 | 파일 |
|---|------|------|---------|------|
| 1 | availableQty fallback | ✅/❌ | N | ... |
| 2 | stocks: [] 하드코딩 | ✅/❌ | N | ... |
| 3 | formatDate NaN | ✅/❌ | N | ... |
| 4 | purchaseDate 접근 | ✅/❌ | N | ... |
| 5 | entity 필수 필드 | ✅/⚠️ | N | ... |
| 6 | refId UUID 노출 | ✅/❌ | N | ... |
| 7 | currentStock: 0 하드코딩 | ✅/❌ | N | ... |
| 8 | defaultWarehouseId 미전달 | ✅/❌ | N | ... |
| 9 | evidence count NaN | ✅/❌ | N | ... |
| 10 | 컬럼-셀 순서 불일치 | ✅/⚠️ | N | ... |
```

4. ❌ 항목이 있으면 해당 파일:라인과 수정 방법 제안
5. 전체 ✅이면 "런타임 데이터 정합성 검증 통과" 출력

## 관련 히스토리

- Wave 4 (2026-04-12): 패턴 1~6 최초 발견 및 수정
- 패턴 1: ShipmentSheet, LotSelectDialog (sales) — availableQty → currentQty fallback
- 패턴 2: misc-outgoing/form-page.tsx — stocks:[] → allLots 기반 조회
- 패턴 3: 4개 types.ts + FIFOLotSelectDialog + StandardLotSelectDialog 등 — formatDate 방어
- 패턴 4: LotEntity.purchaseDate 부재 → createdAt fallback
- 패턴 5: purchase/form-page.tsx — remainingQuantity/receivedQuantity 누락
- 패턴 6: purchase.repo.ts + status/page.tsx — refId UUID → reason 사용
- Wave 6 (2026-04-13): 패턴 7~10 추가
- 패턴 7: misc-incoming/form/page.tsx — currentStock: 0 하드코딩 → Lot 집계
- 패턴 8: sales/form-page.tsx, misc-outgoing/form-page.tsx — defaultWarehouseId 미전달
- 패턴 9: return-disposal/hooks/useReturnDisposalView.ts — evidenceCount NaN
- 패턴 10: purchase/form-page.tsx, sales/form-page.tsx — 컬럼 재배치 후 셀 순서 미동기화
