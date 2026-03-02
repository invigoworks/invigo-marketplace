---
name: verify-routing
description: 라우팅 및 네비게이션 일관성을 검증합니다. 페이지 추가/경로 변경 후 사용.
---

# 라우팅 검증

## Purpose

라우터 설정과 네비게이션 경로의 일관성을 검증합니다:

1. **라우트-페이지 매핑** — router.tsx에 등록된 라우트가 실제 page.tsx와 일치하는지
2. **경로 접두사** — liquor 앱에서 /liquor 접두사, manufacturing 앱에서 /manufacturing 접두사 올바른 사용
3. **Screen Code 혼용 방지** — LQ-(liquor)와 CM-(manufacturing) 접두사가 올바른 앱에서 사용되는지
4. **Import 경로 유효성** — router.tsx의 import 경로가 실제 파일과 일치하는지

## When to Run

- 새 페이지(page.tsx)를 추가한 후
- router.tsx를 수정한 후
- 네비게이션 링크를 추가하거나 변경한 후
- sidebar 관련 코드를 수정한 후

## Related Files

| File | Purpose |
|------|---------|
| `apps/liquor/src/router.tsx` | 주류 ERP 라우트 정의 |
| `apps/liquor/src/components/layout/MainLayout.tsx` | 주류 ERP 레이아웃 (사이드바 포함) |

## Workflow

### Step 1: 라우트-페이지 매핑 검증

**검사:** router.tsx에서 import하는 페이지 컴포넌트의 파일 경로가 실제로 존재하는지 확인합니다.

```bash
# router.tsx에서 import 경로 추출
grep "^import.*from '\./\|^import.*from '\.\.\/" apps/liquor/src/router.tsx
```

각 import 경로에 대해 파일 존재 여부 확인:

```bash
ls apps/liquor/src/<extracted-path>.tsx 2>/dev/null || echo "MISSING"
```

**PASS:** 모든 import 경로의 파일이 존재
**FAIL:** import 경로가 가리키는 파일이 존재하지 않음

**수정:** 올바른 경로로 import 수정 또는 누락된 page.tsx 생성

### Step 2: 미등록 페이지 검증

**검사:** page.tsx 파일이 존재하지만 router.tsx에 라우트로 등록되지 않은 페이지가 있는지 확인합니다.

```bash
# 모든 page.tsx 파일 (components 디렉토리 제외)
find apps/liquor/src -name "page.tsx" -not -path "*/components/*" -not -path "*/node_modules/*"
```

```bash
# router.tsx에 등록된 모든 element
grep "element:" apps/liquor/src/router.tsx
```

**PASS:** 모든 page.tsx가 router.tsx에 등록됨
**FAIL:** page.tsx는 있으나 라우트 미등록

### Step 3: Screen Code 앱 혼용 검증

**검사:** liquor 앱에서 CM- 접두사가 사용되거나, manufacturing 앱에서 LQ- 접두사가 사용되는지 확인합니다.

```bash
# liquor 앱에서 CM- 사용 검사
grep -rn "CM-" apps/liquor/src/ --include="*.tsx" --include="*.ts" | grep -v "node_modules" | grep -v "comment"

# manufacturing 앱에서 LQ- 사용 검사
grep -rn "LQ-" apps/manufacturing/src/ --include="*.tsx" --include="*.ts" | grep -v "node_modules" | grep -v "comment"
```

**PASS:** 각 앱에서 올바른 접두사만 사용
**FAIL:** 잘못된 접두사 사용 발견

**수정:** 올바른 앱의 접두사로 교체 (liquor → LQ-, manufacturing → CM-)

### Step 4: 네비게이션 링크 경로 검증

**검사:** 코드 내의 `navigate()`, `<Link to=`, `useNavigate` 호출에서 경로가 router.tsx에 등록된 패턴과 일치하는지 확인합니다.

```bash
# navigate 호출에서 경로 추출
grep -rn "navigate(\|to=\"\|to={\|href=" apps/liquor/src/production/ --include="*.tsx" | grep -v "node_modules"
```

추출된 경로가 router.tsx의 path 패턴과 일치하는지 대조합니다.

**PASS:** 모든 네비게이션 경로가 유효한 라우트를 가리킴
**FAIL:** 존재하지 않는 라우트로 네비게이션하는 코드 존재

## Output Format

```markdown
| # | 검사 | 앱 | 상태 | 상세 |
|---|------|-----|------|------|
| 1 | 라우트-페이지 매핑 | liquor | PASS/FAIL | 누락 파일... |
| 2 | 미등록 페이지 | liquor | PASS/FAIL | 미등록 페이지... |
| 3 | Screen Code 혼용 | all | PASS/FAIL | 잘못된 접두사... |
| 4 | 네비게이션 링크 | liquor | PASS/FAIL | 잘못된 경로... |
```

## Exceptions

1. **동적 라우트 파라미터** — `/:id`, `/:date` 등 동적 세그먼트가 포함된 경로는 정확한 매칭이 불가능하므로 패턴 수준에서만 검증
2. **외부 링크** — `https://`로 시작하는 외부 URL은 라우트 검증 대상에서 제외
3. **조건부 라우트** — 요금제(FeatureGate)에 의해 조건부로 표시되는 라우트는 router.tsx에 등록되어 있으면 PASS