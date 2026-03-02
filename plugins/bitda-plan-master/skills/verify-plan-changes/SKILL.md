---
name: verify-plan-changes
description: 기획문서 변경사항이 구현 코드에 동기화되었는지 검증합니다. 기획 업데이트 후 사용.
argument-hint: "[기획문서 경로] [변경 내용 또는 '자동감지']"
---

# 기획 변경-코드 동기화 검증

## Purpose

기획문서가 업데이트될 때 변경된 항목이 구현 코드에 정확히 반영되었는지 검증합니다:

1. **공식/계산 변경** — 세율, 계산식, 반올림 방식 등의 변경이 hooks/utils에 반영되었는지
2. **필드 추가/삭제/이름 변경** — 타입 정의, 폼, 테이블 컬럼, Zod 스키마, mock 데이터 전파 확인
3. **조건 분기 추가/변경** — 새로운 조건(전통주 여부 등)이 관련 로직 전체에 반영되었는지
4. **값 연동 규칙 변경** — 필드 간 동기화, 자동 계산 의존성 변경이 코드에 반영되었는지
5. **상수/세율 업데이트** — 세율 테이블, 옵션 목록, 기준값 등의 변경이 코드에 반영되었는지

## When to Run

- 기획문서를 수정/업데이트한 후 코드에 반영했을 때
- 고객사 자료 검증 후 계산 공식을 변경했을 때
- 법령/세율 변경으로 상수를 업데이트했을 때
- 기획 검토(plan-review-team) 후 수정사항을 반영했을 때
- `/verify-implementation` 통합 검증의 일부로 실행 시

## 변경 유형별 전파 체크리스트

기획 변경은 코드의 여러 레이어에 동시에 영향을 줍니다. 아래는 변경 유형별로 반드시 확인해야 할 파일/레이어입니다.

### 유형 1: 필드명 변경 (rename)

**예시:** `laborCost` → `packagingCost`, `노무비` → `포장비`

| # | 전파 대상 | 파일 패턴 | 검증 방법 |
|---|----------|----------|----------|
| 1 | 타입 정의 | `packages/core/*/src/*/types.ts` | 이전 필드명 0건 + 새 필드명 존재 |
| 2 | Mock 데이터 | `packages/core/*/src/*/mock.ts` | 이전 필드명 0건 + 새 필드명 존재 |
| 3 | Zod 스키마 | `*Sheet.tsx` 내 `z.object` | 이전 필드명 0건 + 새 필드명 존재 |
| 4 | 폼 필드 | `*Form.tsx`, `*Sheet.tsx` | `FormField name=` 및 `form.watch` 참조 |
| 5 | 비즈니스 로직 | `hooks/*.ts`, `utils/*.ts` | 이전 필드명 0건 |
| 6 | 테이블 컬럼 | `columns.tsx` | `accessorKey` 또는 `header` |
| 7 | UI 라벨 | `FormLabel`, 텍스트 리터럴 | 한글 라벨 변경 |

**검증 명령:**
```bash
# 이전 필드명이 완전히 제거되었는지 (0건이어야 PASS)
grep -rn "<old_field_name>" <module-path>/ --include="*.ts" --include="*.tsx"

# 새 필드명이 올바르게 존재하는지
grep -rn "<new_field_name>" <module-path>/ --include="*.ts" --include="*.tsx"
```

### 유형 2: 계산 공식 변경

**예시:** `taxBase / (1 - ratio)` → `taxBase * (1 - ratio)`, 포장비 차감 조건 추가

| # | 전파 대상 | 파일 패턴 | 검증 방법 |
|---|----------|----------|----------|
| 1 | 계산 hook/util | `hooks/*.ts`, `utils/*.ts` | 새 공식의 핵심 연산자/패턴 존재 |
| 2 | 의존 파라미터 | hook의 params 인터페이스 | 새 파라미터 추가 여부 |
| 3 | 호출부 | hook을 호출하는 모든 컴포넌트 | 새 파라미터 전달 여부 |
| 4 | UI 표시 | 계산 결과를 표시하는 컴포넌트 | 새 표시 항목 반영 여부 |
| 5 | 기획문서 | Notion 또는 로컬 기획서 | 공식 설명이 코드와 일치 |

**검증 명령:**
```bash
# 새 파라미터가 hook 인터페이스에 추가되었는지
grep -n "interface.*Params" <hook-file>

# 모든 호출부에서 새 파라미터를 전달하는지
grep -rn "usePriceCalculation\|useCalculation" <module-path>/ --include="*.tsx" -A 5
```

### 유형 3: 조건 분기 추가

**예시:** `isTraditional === "yes"` 조건에 따른 포장비 과세표준 차감

| # | 전파 대상 | 파일 패턴 | 검증 방법 |
|---|----------|----------|----------|
| 1 | 비즈니스 로직 | `hooks/*.ts` | 조건 분기 코드 존재 |
| 2 | 파라미터 전달 | hook params | 조건 판단용 파라미터 존재 |
| 3 | 호출부 전파 | 모든 호출 컴포넌트 | 조건값 watch + 전달 |
| 4 | UI 안내 | 조건 활성화 시 안내 텍스트 | 조건부 렌더링 존재 |
| 5 | 연관 필드 연동 | 조건에 영향받는 다른 필드 | 값 동기화 로직 |

### 유형 4: 상수/세율 업데이트

**예시:** 기준판매비율 22% → 23.2% (2026년 변경)

| # | 전파 대상 | 파일 패턴 | 검증 방법 |
|---|----------|----------|----------|
| 1 | 상수 맵 | hooks/ 또는 constants/ 내 세율 테이블 | 값 직접 비교 |
| 2 | 기초자료 | 기초자료설정 관련 데이터 | 값 직접 비교 |
| 3 | 기획문서 | Notion 기획서 내 세율 테이블 | 코드와 일치 여부 |

### 유형 5: 필드 간 연동 규칙 변경

**예시:** packagingPrice ↔ priceDeclaration.packagingCost 양방향 연동

| # | 전파 대상 | 파일 패턴 | 검증 방법 |
|---|----------|----------|----------|
| 1 | 연동 useEffect | Sheet/Form 컴포넌트 | useEffect 내 setValue 호출 |
| 2 | 순환 방지 | 같은 useEffect | 값 비교 가드 존재 |
| 3 | 조건부 표시 | 연동 시 필드 숨김/표시 | 조건부 렌더링 로직 |
| 4 | 초기값 동기화 | editData 리셋 시 | form.reset 내 두 필드 일관성 |

## 워크플로우

### Step 0: 변경사항 식별

**입력에 따라 분기:**

| 입력 | 변경사항 식별 방법 |
|------|------------------|
| 명시적 변경 내용 전달 | 사용자가 알려준 변경 항목을 기준으로 검증 |
| 기획문서 경로 | 기획문서를 읽고 세션 컨텍스트에서 변경 이력 추출 |
| `자동감지` | `git diff`로 코드 변경사항 분석 → 변경 유형 자동 분류 |

**자동감지 모드:**
```bash
# 최근 변경된 파일 목록
git diff HEAD --name-only

# 변경 내용에서 패턴 추출
git diff HEAD -- "*.ts" "*.tsx" | head -200
```

변경 내용에서 다음 패턴을 감지합니다:
- 필드명 변경: `-laborCost` / `+packagingCost` 패턴
- 공식 변경: 수학 연산자 변경 (`/` → `*`, `+` → `-`)
- 조건 추가: 새로운 `if` / 삼항 연산자 추가
- 상수 변경: 숫자 리터럴 변경
- 연동 추가: 새로운 `useEffect` + `setValue`

### Step 1: 변경 유형 분류

감지된 변경을 위의 5가지 유형으로 분류하고 각 유형의 체크리스트를 활성화합니다.

```markdown
## 감지된 변경사항

| # | 유형 | 변경 내용 | 체크 항목 수 |
|---|------|----------|------------|
| 1 | 필드명 변경 | laborCost → packagingCost | 7 |
| 2 | 공식 변경 | 과세표준 전통주 차감 추가 | 5 |
| 3 | 연동 추가 | packagingPrice ↔ packagingCost | 4 |
```

### Step 2: 전파 검증 실행

각 변경 유형의 체크리스트를 순서대로 실행합니다.

**핵심 원칙:** 하나의 변경은 여러 파일에 전파되어야 합니다. **하나라도 누락되면 FAIL.**

검증 순서:
1. **타입 레이어** (`packages/core/`) — 가장 기본. 여기서 틀리면 전체가 틀림
2. **로직 레이어** (`hooks/`, `utils/`) — 비즈니스 규칙 반영
3. **UI 레이어** (`*Sheet.tsx`, `*Form.tsx`) — 폼/테이블 반영
4. **스키마 레이어** (Zod `z.object`) — 유효성 검증 반영
5. **데이터 레이어** (`mock.ts`) — 테스트 데이터 일관성
6. **표시 레이어** (라벨, 안내 텍스트) — 사용자 대면 텍스트

### Step 3: 잔여 이전 참조 검색

변경된 항목의 이전 값이 코드베이스에 남아있지 않은지 최종 확인합니다.

```bash
# 필드명 변경의 경우: 이전 필드명 잔존 확인
grep -rn "<old_value>" apps/ packages/ --include="*.ts" --include="*.tsx"

# 공식 변경의 경우: 이전 공식 패턴 잔존 확인
grep -rn "<old_formula_pattern>" apps/ packages/ --include="*.ts"
```

**PASS:** 이전 값/패턴이 0건
**FAIL:** 이전 값이 남아있는 파일 발견 → 전파 누락

## Output Format

```markdown
# 기획 변경-코드 동기화 검증 보고서

## 변경사항 요약
| # | 유형 | 변경 내용 | 전파 대상 | 상태 |
|---|------|----------|----------|------|
| 1 | 필드명 변경 | laborCost → packagingCost | 7개 파일 | PASS/FAIL |
| 2 | 공식 변경 | 과세표준 전통주 차감 | 5개 파일 | PASS/FAIL |

## 전파 검증 상세

### 변경 1: laborCost → packagingCost (필드명 변경)

| # | 레이어 | 파일 | 상태 | 상세 |
|---|--------|------|------|------|
| 1 | 타입 | core/liquor/types.ts | PASS | packagingCost 존재, laborCost 0건 |
| 2 | Mock | core/liquor/mock.ts | PASS | packagingCost 존재, laborCost 0건 |
| 3 | Zod | ProductSheet.tsx | PASS | packagingCost 스키마 존재 |
| 4 | 폼 | PriceDeclarationForm.tsx | PASS | FormField name 변경 완료 |
| 5 | Hook | usePriceCalculation.ts | PASS | packagingCost 참조 |
| 6 | 라벨 | PriceDeclarationForm.tsx | PASS | "포장비" 라벨 |
| 7 | 잔존 | 전체 검색 | PASS | laborCost 0건 |

### 잔여 이전 참조
| 검색어 | 결과 | 파일 |
|--------|------|------|
| laborCost | 0건 | - |
| 노무비 | 0건 | - |

## 최종 결과
- **PASS**: 모든 변경사항이 코드 전체에 동기화됨
- **FAIL**: N건의 전파 누락 발견
```

## Exceptions

1. **주석/문서 내 이전 값** — 코드 주석이나 CHANGELOG에 이전 값이 역사적 기록으로 남아있는 것은 FAIL 아님
2. **테스트 파일** — 테스트 케이스에서 이전 값을 "before" 시나리오로 사용하는 것은 허용
3. **기획문서 변경이력** — 기획서의 "변경 이력" 섹션에 이전 값이 기록된 것은 FAIL 아님
4. **다른 모듈의 동명 필드** — 변경 대상이 아닌 다른 모듈에 우연히 같은 필드명이 있는 경우 제외
5. **상수 업데이트의 시행일** — 세율 변경 등의 경우, 시행일 이전 데이터용 이전 값 병존은 허용

## Related Files

| File | Purpose |
|------|---------|
| `packages/core/*/src/*/types.ts` | 도메인 타입 정의 (전파 시작점) |
| `packages/core/*/src/*/mock.ts` | Mock 데이터 (타입과 일관성) |
| `apps/*/src/**/hooks/*.ts` | 비즈니스 로직 (공식/조건 변경) |
| `apps/*/src/**/components/*Sheet.tsx` | 폼 + Zod 스키마 (필드/검증 변경) |
| `apps/*/src/**/components/*Form.tsx` | 폼 컴포넌트 (필드/라벨 변경) |
| `apps/*/src/**/components/columns.tsx` | 테이블 컬럼 (필드/표시 변경) |
| `.claude/shared-references/notion-manifest.md` | 기획문서 추적 |
