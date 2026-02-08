# Specialized Agent Integration for UI Designer

This skill leverages invigo-agents for production-quality code generation.

## CRITICAL: Vercel React Best Practices Integration

**모든 코드 생성 시 `/vercel-react-best-practices` 스킬을 반드시 적용해야 합니다.**

| Priority | Category | Key Rules |
|----------|----------|-----------|
| 1 | Eliminating Waterfalls | `async-parallel`, `async-suspense-boundaries` |
| 2 | Bundle Size | `bundle-barrel-imports`, `bundle-dynamic-imports` |
| 3 | Server-Side | `server-cache-react`, `server-serialization` |
| 4 | Client-Side | `client-swr-dedup` |
| 5 | Re-render | `rerender-memo`, `rerender-derived-state` |
| 6 | Rendering | `rendering-conditional-render`, `rendering-hoist-jsx` |

**적용 방법:**
```typescript
// 코드 생성 전 반드시 Skill 호출
Skill({ skill: "vercel-react-best-practices" })

// 또는 에이전트 프롬프트에 포함
Task({
  subagent_type: "invigo-agents:frontend-developer",
  prompt: `Generate component following vercel-react-best-practices:
    - Use Promise.all() for parallel fetches (async-parallel)
    - Import directly, avoid barrel files (bundle-barrel-imports)
    - Use dynamic imports for heavy components (bundle-dynamic-imports)
    - Minimize data passed to client (server-serialization)`
})
```

## Recommended Agents by Task

| Task | Agent | Purpose |
|------|-------|---------|
| Frontend Development | `invigo-agents:frontend-developer` | React components, state management |
| TypeScript | `invigo-agents:typescript-pro` | Advanced types, strict typing |
| Code Review | `invigo-agents:code-reviewer` | Quality, security review |
| Testing | `invigo-agents:test-engineer` | Test strategy, automation |
| JavaScript | `invigo-agents:javascript-pro` | ES6+, async patterns |

## Agent Invocation Strategy

### During Code Generation:

1. **Frontend Development** - For complex components:
   ```
   Task(subagent_type="invigo-agents:frontend-developer")
   Prompt: "Generate React component for [화면명] with shadcn/ui.
   Include state management, performance optimization, and accessibility."
   ```

2. **TypeScript Enhancement** - For type safety:
   ```
   Task(subagent_type="invigo-agents:typescript-pro")
   Prompt: "Add strict TypeScript types for [컴포넌트명].
   Use generic constraints and conditional types where beneficial."
   ```

3. **Code Review** - Before deployment:
   ```
   Task(subagent_type="invigo-agents:code-reviewer")
   Prompt: "Review generated code for [기능명].
   Check for bugs, security issues, and code quality."
   ```

## Parallel Agent Execution

For multi-screen features, generate components in parallel:

```typescript
const parallelGeneration = [
  Task({
    subagent_type: "invigo-agents:frontend-developer",
    prompt: "Generate DataTable component for list screen"
  }),
  Task({
    subagent_type: "invigo-agents:frontend-developer",
    prompt: "Generate Sheet form component for registration"
  }),
  Task({
    subagent_type: "invigo-agents:frontend-developer",
    prompt: "Generate Dialog component for confirmation"
  })
];
```

## Post-Generation Quality Check

After code generation, invoke review agents with Vercel Best Practices verification:

```typescript
const qualityCheck = Task({
  subagent_type: "invigo-agents:code-reviewer",
  prompt: `Review all generated components for:
    1. Quality and security
    2. Vercel React Best Practices compliance:
       - No request waterfalls (async-parallel)
       - Proper bundle optimization (bundle-barrel-imports)
       - Correct memoization usage (rerender-memo)
       - Efficient rendering (rendering-conditional-render)`
});
```

## Test Generation Strategy

Invoke test-engineer for comprehensive testing:

```typescript
const testGeneration = [
  Task({
    subagent_type: "invigo-agents:test-engineer",
    prompt: "Generate unit tests for form validation logic"
  }),
  Task({
    subagent_type: "invigo-agents:test-engineer",
    prompt: "Generate integration tests for API interactions"
  }),
  Task({
    subagent_type: "invigo-agents:test-engineer",
    prompt: "Generate E2E tests for critical user flows"
  })
];
```

## UI Consistency Check (CRITICAL - Phase 9)

**코드 생성 완료 후 반드시 `ui-supervisor` 에이전트를 실행하여 일관성을 검증합니다.**

### ui-supervisor 에이전트 역할

| 역할 | 설명 |
|------|------|
| 일관성 검증 | 새 UI와 기존 페이지 간 레이아웃/스타일 비교 |
| 컴포넌트 재사용 감지 | 재사용 가능한 공유 컴포넌트 식별 |
| 패턴 준수 확인 | DataTable, Form, Dialog 등 표준 패턴 준수 여부 |
| 개선 명령 생성 | `/ui-improver` 실행을 위한 구체적 명령어 제공 |

### 자동 실행 방법

```typescript
// 코드 생성 완료 후 Phase 9 자동 실행
const consistencyCheck = Task({
  subagent_type: "ui-supervisor",
  prompt: `UI 일관성 검사 수행:

    대상 파일:
    - apps/liquor/src/production/order/page.tsx
    - apps/liquor/src/production/order/components/OrderSheet.tsx

    검사 항목:
    1. 동일 도메인(production) 내 기존 페이지와 비교
       - PlanPage.tsx의 레이아웃 패턴
       - InventoryPage.tsx의 테이블 패턴
    2. 공유 컴포넌트 재사용 확인
       - StatusBadge, ConfirmDialog, SearchableSelect 등
    3. 스타일 일관성 (spacing, colors, typography)

    출력:
    - 일관성 이슈 리포트
    - /ui-improver 명령어 목록`
});
```

### 자동 개선 프로세스

```typescript
// ui-supervisor 결과를 기반으로 자동 개선
const supervisorResult = await consistencyCheck;

if (supervisorResult.criticalIssues.length > 0) {
  console.log("Critical 이슈 발견 - 자동 수정 진행");

  for (const issue of supervisorResult.criticalIssues) {
    await Skill({
      skill: "ui-improver",
      args: `${issue.file} ${issue.fixDescription}`
    });
  }
}

if (supervisorResult.majorIssues.length > 0) {
  // 사용자에게 수정 여부 확인
  const response = await AskUserQuestion({
    questions: [{
      question: `${supervisorResult.majorIssues.length}개의 Major 이슈가 발견되었습니다. 자동 수정하시겠습니까?`,
      header: "UI 개선",
      options: [
        { label: "전체 수정", description: "모든 이슈를 자동으로 수정합니다" },
        { label: "선택적 수정", description: "이슈를 확인 후 선택적으로 수정합니다" },
        { label: "건너뛰기", description: "이슈를 기록만 하고 진행합니다" }
      ],
      multiSelect: false
    }]
  });
}
```

### 검사 항목 상세

#### Layout Patterns
```typescript
// 비교 대상 찾기
const siblingPages = await Glob({ pattern: `apps/${app}/src/${domain}/**/*Page.tsx` });

// 레이아웃 패턴 추출
for (const page of siblingPages) {
  // PageLayout 사용 여부
  // Header 컴포넌트 패턴
  // Card/Section 구조
  // Action button 위치
}
```

#### Component Reuse
```typescript
// 재사용 가능한 컴포넌트 목록
const sharedComponents = [
  { name: 'StatusBadge', location: 'packages/ui', usage: '상태 표시' },
  { name: 'ConfirmDialog', location: 'packages/ui', usage: '삭제/승인 확인' },
  { name: 'SearchableSelect', location: 'packages/ui', usage: '마스터 데이터 선택' },
  { name: 'DateRangePicker', location: 'packages/ui', usage: '기간 필터' },
  { name: 'EmptyState', location: 'packages/ui', usage: '데이터 없음 표시' },
  { name: 'DataTable', location: 'packages/ui', usage: '목록 테이블' },
];

// 새 코드에서 재사용 여부 확인
for (const component of sharedComponents) {
  const isUsed = codeIncludes(component.name);
  const shouldBeUsed = detectPattern(component.usage);

  if (shouldBeUsed && !isUsed) {
    report.addIssue({
      type: 'component-reuse',
      severity: 'major',
      message: `${component.name} 컴포넌트를 재사용해야 합니다`,
      fix: `/ui-improver ${file} ${component.name} 컴포넌트로 교체`
    });
  }
}
```

### 결과 리포트 형식

```markdown
## UI Supervisor Report

### Summary
- Files Analyzed: 3
- Critical Issues: 2
- Major Issues: 4
- Minor Issues: 6

### Critical Issues (즉시 수정 필요)
1. **OrderPage.tsx:45** - 인라인 테이블 사용
   - 기존 패턴: DataTable 컴포넌트 사용
   - 수정 명령: `/ui-improver OrderPage.tsx DataTable 패턴으로 변경`

2. **OrderSheet.tsx:78** - 커스텀 상태 배지
   - 기존 패턴: StatusBadge 컴포넌트 사용
   - 수정 명령: `/ui-improver OrderSheet.tsx StatusBadge 재사용`

### /ui-improver 실행 명령어
```bash
/ui-improver apps/liquor/src/production/order/page.tsx DataTable 패턴으로 변경
/ui-improver apps/liquor/src/production/order/components/OrderSheet.tsx StatusBadge 재사용
```
```
```
