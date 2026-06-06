# 설계 적합성 (L4) — enum 경직 vs 동적화 필요 탐지

> **목적**: L1(계약 diff)·L2(소스 추론)·L3(동적 실호출)이 모두 탐지하지 못하는
> **"계약은 맞는데 설계가 경직"** 갭을 잡는다.
>
> 전형적 증상: FE TagInput 자유입력이 있는데 BE enum이 고정값 목록만 제공 → 신규 값
> 추가 불가, 사용자가 "기타"로 회피. #2029 EquipmentType/VesselMaterial이 known positive.
>
> 산출물도 **후보** — Stage 2 직렬 verifier 3관문을 통과해야 CONFIRMED.

---

## L4 탐지 규칙

### DF1. 업무 분류 enum + FE 자유입력 불일치 (High)

**조건**: 아래 두 가지를 **동시에** 만족

1. BE `domain.shared` 패키지에 enum이 있고, 값 집합이 업무 도메인 분류(설비 종류·재질·단위·사유 등)
2. FE에서 해당 필드가 `TagInput`/`allowCreate`/`creatable` 옵션이 있는 자유입력 컴포넌트로 렌더링

**의미**: FE는 사용자가 새 값을 추가할 수 있다고 가정하는데 BE는 enum 고정 집합만 수용.
→ tag 동적화 후보.

탐지 grep:
```bash
BACK=/Users/gimjinhyeog/Desktop/coding/bitda-back
FE=/Users/gimjinhyeog/Desktop/coding/plan-master

# 1) domain.shared enum 전체 → 본질-고정만 제외 (업무분류 후보 풀)
#    🚨 "Type$"로 거르지 말 것 — EquipmentType/VesselMaterial(앵커 #2029)이 누락된다.
#    제외 대상은 역할이 시스템/상태/정렬인 것만: Status / SortField / Sort* / Action / Role / Direction / Cycle / Quarter / ChartColor
grep -rn "^enum class " "$BACK/modules/domain/src/main/kotlin/com/invigoworks/bitda/domain/shared/" \
  --include="*.kt" \
  | grep -ivE "Status|SortField|Sort[A-Z]|Action|Role|Direction|Cycle|Quarter|ChartColor"
# → 남은 목록을 verifier가 "업무 분류값인가?"로 선별. EquipmentType·VesselMaterial·ItemUnit이 반드시 살아남아야 정상.
# grep#1은 후보 풀만 만든다(과다포함 OK). 확정 변별은 ②(FE TagInput) + 관문3.

# 2) FE TagInput 자유입력 컴포넌트 탐지
grep -rn "TagInput\|allowCreate\|creatable\|onCreate\|onCreateOption" \
  "$FE/apps/liquor/src" --include="*.tsx" --include="*.ts" -l

# 3) 특정 enum을 참조하는 FE 필드 (예: EquipmentType)
grep -rn "EquipmentType\|VesselMaterial\|ItemUnit\|equipment.*type\|vessel.*material" \
  "$FE/apps/liquor/src" --include="*.tsx" --include="*.ts" | grep -i "TagInput\|allowCreate\|creatable"
```

**기준 앵커 (#2029)**: `EquipmentType`(7종) — FE가 `TagInput allowCreate`로 자유입력을 지원하나
BE는 7개 고정 enum만 수용. `VesselMaterial`(5종) — FE 기본값에 '유리'·'나무통'이 있으나
BE enum에 해당 값 없음. 두 건 모두 CONFIRMED.

---

### DF2. TagCategory 동적분류 존재 + 유사 enum 고정 (Medium)

**조건**: `TagCategory` enum에 `ITEM_UNIT`/`WAREHOUSE_LOCATION` 등 동적 분류가 이미 존재하는데,
같은 개념의 유사 enum이 `domain.shared` 또는 다른 패키지에 **고정 enum으로도** 남아 있음.

**의미**: 한 분류체계에서 일부는 동적화됐고 일부는 고정으로 병존 → 일관성 갭.

탐지 grep:
```bash
BACK=/Users/gimjinhyeog/Desktop/coding/bitda-back

# TagCategory 현재 값 목록
grep -A 20 "^enum class TagCategory" \
  "$BACK/modules/domain/src/main/kotlin/com/invigoworks/bitda/domain/shared/TagCategory.kt"

# domain.shared enum 중 TagCategory와 의미적으로 겹치는 후보
# (단위·위치·부서·유형·재질 키워드)
grep -rn "^enum class " \
  "$BACK/modules/domain/src/main/kotlin/com/invigoworks/bitda/domain/shared/" \
  --include="*.kt" | grep -iE "Unit|Location|Department|Type|Material"
```

**예시**: `TagCategory.ITEM_UNIT`이 동적화됐는데 구 `ItemUnit` enum이 잔존하면 → 정리 대상 후보.
`TagCategory.EQUIPMENT_TYPE`/`VESSEL_MATERIAL`이 미존재이면 → DF1 연계 전환 후보.

---

### DF3. `OTHER` 값 + 자유 입력 욕구 신호 (Low — 보조 지표)

단독으로 갭을 판정하지 않는다. DF1/DF2의 **강화 근거**로만 사용.

```bash
BACK=/Users/gimjinhyeog/Desktop/coding/bitda-back

# "OTHER" 값을 포함하는 domain.shared enum
grep -rn '"OTHER"\|OTHER(' \
  "$BACK/modules/domain/src/main/kotlin/com/invigoworks/bitda/domain/shared/" \
  --include="*.kt" | grep -v "//\|test"
```

`OTHER` 존재는 "분류 불완전 인정"의 신호이지만, FE 자유입력 증거(DF1)가 없으면 동적화 근거 불충분.

---

## 본질 고정 enum — L4 검사 제외 목록 (오탐 방지 필수)

아래 유형에 해당하면 **즉시 N/A**. DF1~DF3 체크 금지.

| 제외 유형 | 식별 패턴 | 예시 |
|----------|----------|------|
| **상태 머신** | `*Status`, `*State`, 상태 전이 로직 `when(status)` 분기 | `WorkOrderStatus`, `LotStatus`, `SubscriptionStatus` |
| **세금·법적 코드** | 세율·신고·주류세 관련, 국세청 고시 기준 | `LiquorCategory`, `ClassificationCode`, `TaxType`, `OutboundType` |
| **비트마스크·권한** | `AppAction`, `UserRole`, 권한 분기 로직 | `AppAction`, `UserRole`, `ResourceType` |
| **시스템 타입 분기** | `ItemType`, `ProductionType` 등 내부 로직 분기의 키 | `ItemCategory`, `ItemType`, `MaterialType`, `SkuType` |
| **정렬·방향 파라미터** | `*SortField`, `SortDirection`, 쿼리 파라미터 | `SortDirection`, `InventoryViewMode`, 17개 SortField 류 |
| **채번·날짜 포맷** | 채번 로직 파싱에 쓰이는 enum | `CounterResetPolicy`, `DateSegmentFormat`, `Delimiter` |
| **색상 팔레트** | 코드 렌더링 고정값 | `ChartColor` |
| **외부 연동 채널** | 외부 서비스 식별자 | `ChannelProvider`, `NotificationChannel` |
| **이진 on/off** | 값이 2종이고 영구 고정인 on/off | `BillingType`, `LotNumbering`, `ReturnDisposalType` |

> **판단 원칙**: `when(enumValue) { ... }` 분기가 프로덕션 코드에 1건이라도 있으면
> 동적화 불가 — 로직이 enum 값에 결합돼 있으므로 태그로 전환 시 컴파일 타임 안전망 소실.

---

## L4 직렬 verifier 3관문

Stage 2 직렬 verifier는 DF1/DF2 후보마다 아래 3관문을 순서대로 통과시킨다.
하나라도 막히면 즉시 **REFUTED + 사유 기록**.

### 관문 1 — 업무 분류 적합성

이 enum이 업무 도메인 분류값인가?
- 상태 전이·권한·세금·시스템 타입이면 → **REFUTED (본질 고정)**
- 설비 종류·재질·단위·사유·목적 등 업무 레이블이면 → PASS

```bash
# 프로덕션 코드에 when 분기 있는지 확인 (1건이라도 있으면 REFUTED)
grep -rn "when.*EquipmentType\|EquipmentType\." \
  "$BACK/modules" --include="*.kt" | grep -v "test\|Test\|//\|seed"
```

### 관문 2 — HEAD 실측 (현재 고정 여부 확인)

BE HEAD에서 직접 확인:
- 해당 enum 파일을 Read → 값 목록 실측
- `TagCategory`에 대응 카테고리가 **없음** 확인
- FE 소스에서 해당 필드 렌더링 컴포넌트 Read → `TagInput`/`allowCreate` 실재 확인

```bash
# enum 파일 직접 확인 (예)
find "$BACK/modules/domain/src" -name "EquipmentType.kt" | xargs cat

# TagCategory에 EQUIPMENT_TYPE 없는지 확인
grep "EQUIPMENT_TYPE\|VESSEL_MATERIAL" \
  "$BACK/modules/domain/src/main/kotlin/com/invigoworks/bitda/domain/shared/TagCategory.kt"
# 출력 없으면 미전환 확인 → PASS
```

### 관문 3 — 전환 타당성 (운영 압박 실재)

동적화가 실제 필요한가?
- FE 자유입력(TagInput/allowCreate) 증거가 FE 소스에 실재 → PASS
- 또는 FE 기본값 목록에 BE enum에 없는 값 포함 → PASS (DF1 강화)
- FE가 dropdown 고정 선택이고 `OTHER` catch-all이 충분하면 → **REFUTED (동적화 욕구 미확인)**

```bash
# FE 해당 필드 렌더링 컴포넌트에서 자유입력 여부 확인
grep -rn "allowCreate\|creatable\|onCreateOption" \
  "$FE/apps/liquor/src" --include="*.tsx" | grep -i "equipment\|vessel\|material"
```

---

## L4 출력 형식

verifier는 아래 표로 출력한다.

```
## L4 설계 적합성 검증 결과 (후보)

| # | enum | 값 수 | FE 입력 방식 | 동적화 신호 | 관문1 분류 | 관문2 HEAD | 관문3 전환타당 | 판정 | 근거 |
|---|------|-------|------------|-----------|-----------|-----------|--------------|------|------|
| 1 | EquipmentType | 7 | TagInput allowCreate | OTHER 존재, FE 자유입력 | PASS | PASS — TagCategory에 EQUIPMENT_TYPE 미존재 | PASS — TagInput allowCreate 실재 | CONFIRMED | #2029 앵커 |
| 2 | VesselMaterial | 5 | TagInput allowCreate | FE 기본값에 BE enum 없는 값('유리','나무통') | PASS | PASS — 미전환 확인 | PASS — 기본값 불일치 직접 확인 | CONFIRMED | FE 기본값과 BE 불일치 |
| 3 | MiscInboundType | 3 | dropdown 고정 | OTHER 존재 | PASS | PASS | FAIL — dropdown 고정, OTHER catch-all 충분 | REFUTED | 관문3: 동적화 욕구 UI 근거 없음 |
```

> REFUTED 건은 표에 남기되 Stage 3 사람 게이트에는 **CONFIRMED만** 올린다.

---

## Stage 3 갭 유형표 행 (SKILL.md 통합용)

L4에서 CONFIRMED된 갭은 Step 3 갭 목록에 아래 유형으로 분류한다:

| 갭 유형 | 설명 | 기본 우선순위 |
|--------|------|------------|
| **설계 적합성 — enum 동적화 (L4)** | 계약은 일치하나 enum 고정 집합이 FE 자유입력·운영 확장성과 충돌. tag 동적화 전환 필요. BE 미전환 확인 + FE 자유입력 실재 + 운영 압박 3관문 통과 후보만 | High |

**라벨**: `feature`, `api-change`, `design-fitness`

---

## SKILL.md 삽입 위치 안내

### 1. Step 0.5 파이프라인 다이어그램 (Stage 1 병렬그물 앞)

현재 다이어그램:
```
Stage 0.5 (정적 그물) → Stage 1 (병렬 그물) → Stage 2.3 (동적 표적) → Stage 2 (직렬 확정) → Stage 3
```

L4는 **Stage 1 병렬 그물과 동시** 또는 **Stage 2 직렬 확정 직전**에 삽입:
```
Stage 0.5 (L1 정적 그물)   Swagger↔FE types.ts jq diff
Stage 1   (L2 병렬 그물)   Agent A∥B∥C∥D — FE코드·기획서·BE현황·시나리오
Stage 1.5 (L4 설계적합성)  DF1·DF2 enum 동적화 후보 — 본 파일 참조
Stage 2.3 (L3 동적 표적)   E2E 실호출 silent mismatch
Stage 2   (직렬 확정)      단일 verifier 3관문 (L1+L2+L3+L4 통합)
Stage 3   (사람 게이트)    CONFIRMED만 제시
```

### 2. Step 1 Agent C 디스패치 프롬프트 Read 지시 추가

Agent C 디스패치 시 아래 줄을 추가:
```
- 모든 도메인: `.claude/skills/gap-analyze/references/design-fitness-l4.md`
  (L4 DF1/DF2 enum 동적화 후보 탐지 — DF1 grep 3종 실행 후 후보 목록 산출)
```

### 3. Step 3 갭 유형표

`| **비즈니스 규칙 미구현** | ...` 행 **위**에 아래 행 삽입:

```
| **설계 적합성 — enum 동적화 (L4)** | 계약 일치하나 enum 고정 집합이 FE 자유입력과 충돌. tag 동적화 필요. 3관문 CONFIRMED만. | High |
```
