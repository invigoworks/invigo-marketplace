---
name: ui-improver
description: |
  This skill analyzes UI elements and automatically improves them using invigo-agents.
  Use this skill when:
  - User explicitly requests UI analysis with `/ui-improve [target]` command
  - User mentions UI issues like spacing, alignment, visual inconsistency
  - User asks to improve, enhance, or fix UI/UX elements
  - During code review when UI patterns could be optimized

  The skill performs comprehensive analysis covering UI/UX, code quality, and component architecture,
  then automatically applies improvements using specialized agents.
---

# UI Improver

## Overview

UI 분석 및 자동 개선 워크플로우:

1. **Component Reuse Analysis** - 기존 컴포넌트 재사용 기회 분석
2. **Multi-Agent Analysis** - invigo-agents로 종합 리뷰
3. **Plan Generation** - 구조화된 개선 계획
4. **Auto-Application** - 전문 에이전트로 변경 적용
5. **Verification** - TypeScript 체크 + agent-browser 검증
6. **UI Supervisor Review** (MANDATORY) - 최종 일관성 검수

## Reference Files

| 파일 | 용도 |
|------|------|
| `references/component-reuse-analysis.md` | **CRITICAL** 컴포넌트 재사용 분석 |
| `references/visual-verification.md` | agent-browser 검증 가이드 |
| `references/analysis-checklist.md` | 분석 체크리스트 |

## Trigger Methods

### Explicit Command
```
/ui-improve [target]
```
예: `/ui-improve ServiceSettings.tsx 테이블`, `/ui-improve Sidebar 메뉴 간격`

### Auto-Detection Keywords
"UI 개선", "UI 분석", "간격이 이상", "정렬 문제", "디자인 개선"

---

## Phase 0: Component Reuse Analysis (MANDATORY)

> **상세: `references/component-reuse-analysis.md`**

### 필수 수행

1. **기존 컴포넌트 탐색** - `feature-dev:code-explorer`
2. **반복 패턴 식별** - 3회 이상 반복되는 UI 패턴 확인
3. **결과 문서화** - 재사용 기회 및 우선순위 정리

### 개선 우선순위

1. **[CRITICAL]** 기존 컴포넌트로 교체 가능한 항목
2. **[HIGH]** 3회 이상 반복 → 컴포넌트화 필요
3. **[MEDIUM]** 기타 UI/UX 개선

---

## Phase 1: Target Identification

1. Parse target from command or context
2. Locate files using Glob/Grep
3. Read target code
4. **Cross-reference with Phase 0 results**

---

## Phase 2: Multi-Agent Analysis

### Parallel Analysis

```typescript
const parallelAnalysis = [
  Task({ subagent_type: "invigo-agents:ui-ux-designer", prompt: "UI/UX 분석" }),
  Task({ subagent_type: "invigo-agents:architect-reviewer", prompt: "아키텍처 리뷰" }),
  Task({ subagent_type: "invigo-agents:code-reviewer", prompt: "코드 품질 + Component Reuse + Vercel Best Practices" })
];
```

### Code Review 검사 항목

**Component Reuse Issues (CRITICAL)**
- 기존 컴포넌트 미사용 (TimeInput, FormSheet, SearchableSelect 등)
- 3회 이상 반복 패턴 컴포넌트화 필요
- 하드코딩된 값 추출 필요

**Vercel Best Practices (CRITICAL)**
- `async-parallel`: 순차 await → Promise.all()
- `bundle-barrel-imports`: barrel import 금지
- `bundle-dynamic-imports`: 무거운 컴포넌트 동적 import

---

## Phase 3: Improvement Plan

### 계획 구조

```markdown
## UI 개선 계획

### 🔴 컴포넌트 재사용 이슈 (HIGHEST PRIORITY)
| 현재 구현 | 재사용할 컴포넌트 | 영향 범위 |
|----------|------------------|----------|

### 🟠 반복 패턴 컴포넌트화 필요
| 패턴 | 반복 횟수 | 생성할 컴포넌트 |
|------|----------|----------------|

### UI/UX 이슈
| 우선순위 | 이슈 | 개선안 |
|----------|------|--------|

### 적용 순서 (Component Reuse First)
1. [REUSE] 기존 컴포넌트로 교체
2. [CREATE] 반복 패턴 컴포넌트 생성
3. [REPLACE] 하드코딩 교체
4. [Other improvements]
```

---

## Phase 4: Auto-Application

```typescript
function selectAgent(changeType: string): string {
  switch (changeType) {
    case 'ui-styling':
    case 'component-structure':
      return 'invigo-agents:frontend-developer';
    case 'typescript':
      return 'invigo-agents:typescript-pro';
    case 'refactoring':
      return 'invigo-agents:code-reviewer';
    default:
      return 'invigo-agents:frontend-developer';
  }
}
```

---

## Phase 5: Verification

1. **TypeScript 체크** - 타입 에러 없음 확인
2. **Visual Verification** - `/agent-browser` **스킬**로 UI 검증 (⚠️ 에이전트 아님)
3. **UI Supervisor Review** (MANDATORY)

> **Visual Verification 상세: `references/visual-verification.md`**

**호출 방법:**
```typescript
// ✅ 올바른 호출 (스킬)
Skill({ skill: "agent-browser", args: "http://localhost:3000/..." })

// ❌ 잘못된 호출 (에이전트로 오인)
// Task({ subagent_type: "agent-browser", ... })
```

> **서버 확인**: `lsof -i :3000`으로 확인 후, 없으면 `pnpm dev:preview` 실행

---

## Phase 6: UI Supervisor Review (MANDATORY)

### 실행

```typescript
await Task({
  subagent_type: "ui-supervisor",
  prompt: `UI Consistency Review:
    Modified files: ${modifiedFiles}
    1. 4대 필수 패턴 확인 (PageTitle, Sheet, Date, Table 패딩)
    2. 컴포넌트 재사용 기회 확인
    3. 동일 도메인 페이지와 일관성 확인`
});
```

### 검수 기준

| 항목 | 확인 내용 |
|------|----------|
| PageTitle | `PageTitle` 컴포넌트 사용 |
| Sheet 패딩 | `FormSheet` 또는 내부 패딩 |
| 날짜 컴포넌트 | `DateRangeFilter/DateRangePicker` |
| 테이블 패딩 | `overflow-x-auto px-4 py-2` 래퍼 |

### 결과 처리

- **Critical/Major 발견**: 즉시 수정 → 재검수
- **Minor만**: 권장사항 안내
- **이슈 없음**: 완료

### 완료 조건

- ✅ TypeScript 타입 체크 통과
- ✅ Visual Verification 통과
- ✅ **UI Supervisor Review 통과** (Critical/Major 0개)

---

## Agent Matrix

| Type | Agent | Purpose |
|------|-------|---------|
| UI/UX | `invigo-agents:ui-ux-designer` | Visual design, accessibility |
| Architecture | `invigo-agents:architect-reviewer` | Component patterns, SOLID |
| Code Quality | `invigo-agents:code-reviewer` | Bugs, security |
| Implementation | `invigo-agents:frontend-developer` | React components |
| TypeScript | `invigo-agents:typescript-pro` | Type safety |

---

## Vercel Best Practices Checklist

### CRITICAL
- [ ] `async-parallel`: 독립적 await → Promise.all()
- [ ] `bundle-barrel-imports`: 직접 import 사용
- [ ] `bundle-dynamic-imports`: 무거운 컴포넌트 동적 import

### MEDIUM
- [ ] `rerender-memo`: 비용 큰 계산 useMemo
- [ ] `rendering-conditional-render`: && 대신 삼항 연산자

---

## Output Format

```markdown
## UI 개선 완료

### 컴포넌트 재사용 적용
| 변경 유형 | 이전 | 이후 |
|----------|------|------|
| 기존 컴포넌트 교체 | `<input type="time">` | `TimeInput` |
| 반복 패턴 컴포넌트화 | 인라인 뱃지 5회 | `OrderStatusBadge` 생성 |

### 적용된 변경사항
1. ✅ [Component reuse changes first]
2. ✅ [Other changes]

### 검증 결과
- ✅ TypeScript 타입 체크 통과
- ✅ Visual Verification 통과
- ✅ UI Supervisor Review 통과

**검수 결과**: PASS (Critical: 0, Major: 0)
```

---

## Root Cause Feedback (Shift Left)

> **목적**: ui-improver에서 발견된 이슈의 **근본 원인**을 분류하여, 어느 상류 스킬이 강화되어야 하는지 피드백

### 이슈 원인 분류 체계

개선 완료 후, 발견된 각 이슈를 다음 원인으로 분류:

| 원인 분류 | 설명 | 개선 대상 스킬 |
|----------|------|---------------|
| **기획 누락** | 기획서에 UI 규칙/컴포넌트가 명시되지 않음 | plan-developer |
| **기획 과다** | 불필요한 UI 요소가 기획됨 (요약카드, 과다 필터 등) | plan-developer |
| **검토 미발견** | plan-review에서 잡아야 할 UI 일관성 이슈 | plan-reviewer, plan-review-team |
| **코드생성 실수** | ui-designer가 기존 컴포넌트를 미사용 | ui-designer |
| **도메인 불일치** | 동일 도메인 페이지와 스타일 상이 | ui-designer |
| **신규 이슈** | 상류에서 예방 불가한 새로운 유형 | ui-improver 자체 보강 |

### 출력 형식 (Output에 추가)

```markdown
### 근본 원인 분석 (Shift Left Feedback)
| # | 이슈 | 원인 분류 | 상류 스킬 개선 제안 |
|---|------|----------|-------------------|
| 1 | LiquorTypeBadge 미사용 | 코드생성 실수 | ui-designer Phase 0 강화 |
| 2 | 불필요한 요약카드 4개 | 기획 과다 | plan-developer 2.2b 활용 |
| 3 | border-r 패턴 누락 | 도메인 불일치 | ui-designer 동일도메인 참조 |

**통계**: 기획 누락 N건 / 기획 과다 N건 / 검토 미발견 N건 / 코드생성 N건 / 도메인 불일치 N건
```

> 이 피드백은 스킬 개선의 데이터 소스로 활용됩니다.

---

## Error Handling

| Situation | Action |
|-----------|--------|
| Target file not found | Glob으로 검색, 불명확시 사용자 질문 |
| Analysis conflict | UI/UX 권장사항 우선 |
| Apply fails | 롤백 후 에러 보고 |
| Typecheck fails | 타입 에러 먼저 수정 |
