---
name: verify-plan-implementation
description: 기획문서의 요구사항이 실제 구현 코드에 반영되었는지 검증합니다. 기능 구현 후, PR 전 사용.
argument-hint: "[기획문서 경로 또는 Notion Page ID]"
---

# 기획-구현 검증

## Purpose

기획문서(PART 1/2/3 구조)에 명시된 요구사항이 실제 코드에 올바르게 반영되었는지 검증합니다:

1. **비즈니스 규칙 반영** — 기획서의 계산 공식, 조건 분기, 상태 전이가 코드에 구현되었는지
2. **데이터 필드 매핑** — 기획서에 정의된 입력 필드가 폼/테이블에 모두 존재하는지
3. **유효성 검증** — 기획서의 validation 규칙이 Zod 스키마/폼에 반영되었는지
4. **컴포넌트 스펙 준수** — 기획서에 명시된 shadcn 컴포넌트가 실제 사용되었는지
5. **AC 조건 충족** — Given-When-Then 인수 조건의 핵심 동작이 구현되었는지
6. **에러 처리** — 기획서의 HTTP 코드별 UI 처리가 코드에 반영되었는지

## When to Run

- 기획문서 기반으로 기능을 구현한 후
- PR 전 기획 대비 누락 사항 확인 시
- 기획 변경 후 코드 반영 여부 확인 시
- `/verify-implementation` 통합 검증의 일부로 실행 시

## 워크플로우

### Step 0: 기획문서 확보

**입력 방식에 따라 분기:**

| 입력 | 방법 |
|------|------|
| 로컬 파일 경로 | `Read` 도구로 직접 읽기 |
| Notion Page ID | `.claude/shared-references/notion-manifest.md`에서 확인 → `notion-fetch({ id })` |
| 인수 없음 | 현재 세션 컨텍스트에서 기획 대상 추론 → 사용자에게 확인 |

기획문서 확보 후, 다음 핵심 섹션을 파싱합니다:
- **대상 모듈 경로** (예: `apps/liquor/src/settings/master-data/products/`)
- **비즈니스 규칙** (계산 공식, 조건 분기)
- **데이터 필드 목록** (입력 필드, 테이블 컬럼)
- **유효성 검증 규칙** (필수, 형식, 범위)
- **AC 조건** (Given-When-Then)
- **컴포넌트 스펙** (shadcn 컴포넌트 매핑)

### Step 1: 대상 구현 파일 탐색

기획문서의 대상 모듈 경로에서 구현 파일을 탐색합니다:

```bash
# 대상 모듈의 모든 tsx/ts 파일 확인
ls -R <module-path>/
```

**주요 파일 매핑:**

| 기획 영역 | 대상 파일 패턴 |
|----------|--------------|
| 테이블 컬럼 | `components/columns.tsx` 또는 `page.tsx` 내 테이블 정의 |
| 폼 필드 | `components/*Sheet.tsx`, `components/*Form.tsx` |
| 비즈니스 로직 | `hooks/*.ts`, `utils/*.ts` |
| 유효성 검증 | Zod 스키마 (Sheet/Form 파일 내 `z.object`) |
| 타입 정의 | `packages/core/*/src/*/types.ts` |
| Mock 데이터 | `packages/core/*/src/*/mock.ts` |

### Step 2: 비즈니스 규칙 검증

기획문서에 명시된 각 비즈니스 규칙을 코드에서 찾아 대조합니다.

**검증 방법:**

1. 기획서에서 계산 공식/조건 분기 추출
2. hooks/ 또는 utils/ 파일에서 해당 로직 검색 (Grep)
3. 공식의 핵심 연산자/상수가 코드에 존재하는지 확인

**예시:**
```
기획: "과세표준 = 제조원가계 + 제조이윤 (전통주: 포장비 차감)"
검증: hooks/usePriceCalculation.ts에서
  - manufacturingCostTotal + manufacturingProfit 존재 ✓
  - isTraditional === "yes" 조건 분기 존재 ✓
  - packagingCost 차감 로직 존재 ✓
```

**PASS:** 기획서의 모든 비즈니스 규칙이 코드에 매핑됨
**FAIL:** 기획서에 있지만 코드에 없는 규칙 발견

### Step 3: 데이터 필드 매핑 검증

기획서에 정의된 모든 입력 필드/테이블 컬럼이 구현에 존재하는지 확인합니다.

**검증 방법:**

1. 기획서의 데이터 필드 테이블에서 한글 필드명 목록 추출
2. 타입 정의(types.ts)에서 대응하는 인터페이스 필드 확인
3. 폼 컴포넌트에서 `FormField name=` 또는 `form.watch` 패턴으로 구현 확인
4. 테이블 컬럼 정의에서 `accessorKey` 또는 `header` 매핑 확인

**대조 체크리스트:**
```
기획 필드 "원료비" → types.ts: rawMaterialCost ✓ → Form: FormField name="...rawMaterialCost" ✓
기획 필드 "포장비" → types.ts: packagingCost ✓ → Form: FormField name="...packagingCost" ✓
기획 필드 "경비"   → types.ts: otherExpenses ✓ → Form: FormField name="...otherExpenses" ✓
```

**PASS:** 모든 기획 필드가 타입 + UI에 매핑됨
**FAIL:** 기획서에 있으나 타입 또는 UI에 누락된 필드 발견

### Step 4: 유효성 검증 규칙 검증

기획서의 validation 규칙이 Zod 스키마에 반영되었는지 확인합니다.

**검증 방법:**

1. 기획서의 유효성 검증 테이블 추출 (필수, 형식, 범위, 에러 메시지)
2. 폼 파일에서 Zod 스키마(`z.object`, `z.string().min()` 등) 검색
3. 각 규칙별 대조:

| 기획 규칙 | Zod 대응 | 검증 |
|----------|---------|------|
| 필수 | `z.string().min(1, "...")` | 에러 메시지까지 일치 여부 |
| 형식 | `z.string().regex(...)` | 정규식 패턴 확인 |
| 범위 | `z.number().min(0)` | 경계값 확인 |
| 선택 | `.optional()` | optional 처리 여부 |

**PASS:** 모든 validation 규칙이 Zod 스키마에 반영됨
**FAIL:** 기획서에 명시된 규칙이 스키마에 누락됨

### Step 5: AC 조건 핵심 동작 검증

기획서의 Given-When-Then 인수 조건에서 **핵심 동작**(Then절)이 구현되었는지 확인합니다.

**검증 방법:**

1. 기획서에서 AC 조건 추출
2. Then절의 핵심 동작을 코드에서 검색:
   - "Toast 표시" → `toast.success` / `toast.error` 호출 존재 확인
   - "목록 갱신" → `queryClient.invalidateQueries` 또는 state 업데이트 확인
   - "Sheet 닫힘" → `onOpenChange(false)` 호출 확인
   - "탭 전환" → `setActiveTab` 호출 확인
   - "자동 계산" → 계산 함수/hook 호출 확인
   - "단가 동기화" → setValue 또는 sync 로직 확인

**PASS:** 모든 AC의 Then절 핵심 동작이 코드에 존재
**FAIL:** Then절에 명시된 동작이 코드에 없음

### Step 6: 컴포넌트 스펙 검증

기획서에 명시된 shadcn 컴포넌트가 실제 사용되었는지 확인합니다.

**검증 방법:**

1. 기획서 컴포넌트 명세 테이블 추출
2. 각 컴포넌트의 import 존재 여부 확인 (Grep)

```
기획: "등록/수정 → FormSheet + Form"
검증: Grep "FormSheet" <target-files> → 존재 여부
```

**PASS:** 기획서 컴포넌트가 모두 import/사용됨
**FAIL:** 기획서에 명시되었으나 사용되지 않은 컴포넌트 존재

### Step 7: 에러/상태 처리 검증

기획서의 상태별 UI 및 에러 처리가 구현되었는지 확인합니다.

**검증 항목:**

| 기획 항목 | 코드 검증 |
|----------|----------|
| Loading 상태 | `isLoading` / `isPending` / Skeleton 컴포넌트 사용 |
| Empty 상태 | 데이터 0건 시 EmptyState 또는 안내 메시지 |
| Error 상태 | `isError` / error boundary / Toast 에러 표시 |
| 비활성화 조건 | `disabled` prop 또는 조건부 렌더링 |

**PASS:** 기획서의 상태별 UI가 모두 구현됨
**FAIL:** 기획서에 명시된 상태 처리가 누락됨

## Output Format

```markdown
# 기획-구현 검증 보고서

## 기획문서
- 제목: [기획서 제목]
- 경로: [파일 경로 또는 Notion Page ID]
- 대상 모듈: [모듈 경로]

## 검증 요약

| # | 검증 항목 | 상태 | 기획 항목 수 | 구현 확인 | 누락 |
|---|----------|------|------------|----------|------|
| 1 | 비즈니스 규칙 | PASS/FAIL | N | N | 0 |
| 2 | 데이터 필드 | PASS/FAIL | N | N | 0 |
| 3 | 유효성 검증 | PASS/FAIL | N | N | 0 |
| 4 | AC 조건 | PASS/FAIL | N | N | 0 |
| 5 | 컴포넌트 스펙 | PASS/FAIL | N | N | 0 |
| 6 | 에러/상태 처리 | PASS/FAIL | N | N | 0 |

## 누락 상세 (FAIL 항목만)

| # | 검증 항목 | 기획 내용 | 기대 코드 | 실제 | 수정 제안 |
|---|----------|----------|----------|------|----------|
| 1 | 비즈니스 규칙 | "전통주 포장비 차감" | isTraditional 분기 | 미구현 | hooks/에 조건 추가 |

## 최종 결과
- **PASS**: 기획문서의 모든 요구사항이 구현에 반영됨
- **FAIL**: N건의 누락 발견 — 수정 필요
```

## Exceptions

1. **API 엔드포인트 상세** — Mock 기반 구현에서는 실제 API 경로 검증 불필요 (PART 3 API 맵핑은 백엔드 연동 시 검증)
2. **정확한 에러 메시지 문구** — 한글 에러 메시지의 경미한 표현 차이는 FAIL이 아닌 INFO로 처리
3. **자동 계산 필드** — 기획서에서 "자동계산"으로 표시된 필드는 UI에 없어도 hook/util에서 계산되면 PASS
4. **레이아웃 ASCII 다이어그램** — 기획서의 레이아웃 다이어그램은 방향성 참고용이므로 정확한 픽셀 검증 불필요
5. **권한/접근 제어** — RBAC 구현은 별도 미들웨어 영역이므로 프론트엔드 코드에서 role 체크가 없어도 FAIL 아님

## Related Files

| File | Purpose |
|------|---------|
| `.claude/shared-references/notion-manifest.md` | 기획문서 Page ID 조회 |
| `.claude/skills/plan-developer/SKILL.md` | 기획문서 구조 (PART 1/2/3) 참조 |
| `packages/core/*/src/*/types.ts` | 도메인 타입 정의 |
| `apps/*/src/**/components/*Sheet.tsx` | 폼 컴포넌트 (Zod 스키마 포함) |
| `apps/*/src/**/hooks/*.ts` | 비즈니스 로직 훅 |
| `apps/*/src/**/components/columns.tsx` | 테이블 컬럼 정의 |
