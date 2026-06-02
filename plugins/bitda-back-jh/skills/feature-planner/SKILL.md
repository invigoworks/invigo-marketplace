---
name: feature-planner
description: "Creates phase-based feature plans with quality gates and incremental delivery structure. Use when planning features, organizing work, breaking down tasks, creating roadmaps, or structuring development strategy. Keywords: plan, planning, phases, breakdown, strategy, roadmap, organize, structure, outline."
---

# Feature Planner

## Purpose
Generate structured, phase-based plans where:
- Each phase delivers complete, runnable functionality
- Quality gates enforce validation before proceeding
- User approves plan before any work begins
- Progress tracked via markdown checkboxes
- Each phase is 1-4 hours maximum

## Planning Workflow

### Step 0: Load Project Context (MANDATORY)
**CRITICAL**: 플래닝 시작 전 반드시 CLAUDE.md를 읽어서 프로젝트 컨텍스트를 메모리에 로드한다.

1. **CLAUDE.md 읽기**: `CLAUDE.md` 파일을 Read 도구로 읽어서 전체 내용을 파악
2. **핵심 원칙 확인**: 아키텍처 핵심 원칙, 계층 구조, 네이밍 컨벤션 숙지
3. **관련 시행령 식별**: 기능과 관련된 시행령 문서(docs/standards/)가 있다면 함께 읽기
4. **E2E 테스트 헌법 확인**: 테스트 작성이 포함된 플랜이라면 §6.2 E2E 테스트 헌법 숙지

> ⚠️ 이 단계를 건너뛰면 프로젝트 아키텍처와 맞지 않는 플랜이 생성될 수 있습니다.

### Step 1: Requirements Analysis
1. Read relevant files to understand codebase architecture
2. Identify dependencies and integration points
3. Assess complexity and risks
4. Determine appropriate scope (small/medium/large)

### Step 2: Phase Breakdown with TDD Integration
Break feature into 3-7 phases where each phase:
- **Test-First**: Write tests BEFORE implementation
- Delivers working, testable functionality
- Takes 1-4 hours maximum
- Follows Red-Green-Refactor cycle
- Has measurable test coverage requirements
- Can be rolled back independently
- Has clear success criteria

**Phase Structure**:
- Phase Name: Clear deliverable
- Goal: What working functionality this produces
- **Test Strategy**: What test types, coverage target, test scenarios
- Tasks (ordered by TDD workflow):
  1. **RED Tasks**: Write failing tests first
  2. **GREEN Tasks**: Implement minimal code to make tests pass
  3. **REFACTOR Tasks**: Improve code quality while tests stay green
- Quality Gate: TDD compliance + validation criteria
- Dependencies: What must exist before starting
- **Coverage Target**: Specific percentage or checklist for this phase

### Step 2.5: Domain Classification & Naming Convention

플랜 파일은 도메인별 서브폴더 아래 `ready/` 디렉토리에 생성한다.

#### 파일명 형식

**필수 형식**: `PLAN_{domain}-{feature}.md` (kebab-case)

| 구성 요소 | 설명 | 예시 |
|-----------|------|------|
| `{domain}` | 기능이 속하는 도메인 (단수형) | `user`, `partner`, `subscription` |
| `{feature}` | 구현할 기능 (kebab-case) | `authentication`, `excel-export`, `net-growth-statistics` |

**올바른 예시**:
- `PLAN_user-authentication.md`
- `PLAN_partner-excel-export.md`
- `PLAN_subscription-net-growth-statistics.md`

**잘못된 예시**:
- `PLAN_authentication.md` (도메인 누락)
- `PLAN_user_authentication.md` (snake_case 사용)
- `PLAN_UserAuthentication.md` (PascalCase 사용)

#### 전체 경로 형식

**경로 형식**: `docs/plans/{domain}/ready/PLAN_{domain}-{feature}.md`

**도메인 결정 방법**:
1. 코드베이스의 도메인 패키지 구조를 확인한다 (`modules/domain/src/**/domain/*/`)
2. 기능이 속하는 도메인을 식별한다
3. 도메인을 명확히 결정할 수 없는 경우 AskUserQuestion으로 사용자에게 질문한다

**예시**:
```
docs/plans/
├── subscription/
│   └── ready/
│       └── PLAN_subscription-net-growth-statistics.md
├── user/
│   └── ready/
│       └── PLAN_user-authentication.md
└── warehouse/
    └── ready/
        └── PLAN_warehouse-inventory-sync.md
```

#### 연관 리소스 네이밍 (feature-impl, branch-review 연동)

플랜 파일명에서 `PLAN_` prefix와 `.md` suffix를 제거한 이름이 일관되게 사용된다:

| 리소스 | 네이밍 패턴 | 예시 |
|--------|------------|------|
| 플랜 파일 | `PLAN_{domain}-{feature}.md` | `PLAN_user-authentication.md` |
| 브랜치 | `feature/{domain}-{feature}` | `feature/user-authentication` |
| 워크트리 | `../worktrees/feature/{domain}-{feature}` | `../worktrees/feature/user-authentication` |
| 리뷰 파일 | `REVIEW_{domain}-{feature}.md` | `REVIEW_user-authentication.md` |

### Step 3: Plan Document Creation
Use plan-template.md to generate: `docs/plans/<domain>/ready/PLAN_<feature-name>.md`

Include:
- Overview and objectives
- Architecture decisions with rationale
- Complete phase breakdown with checkboxes
- Quality gate checklists
- Risk assessment table
- Rollback strategy per phase
- Progress tracking section
- Notes & learnings area

### Step 4: User Approval
**CRITICAL**: Use AskUserQuestion to get explicit approval before proceeding.

Ask:
- "Does this phase breakdown make sense for your project?"
- "Any concerns about the proposed approach?"
- "Should I proceed with creating the plan document?"

Only create plan document after user confirms approval.

### Step 5: Document Generation
1. Create `docs/plans/<domain>/ready/` directory if not exists
2. Generate plan document with all checkboxes unchecked
3. Add clear instructions in header about quality gates
4. Inform user of plan location and next steps

## Quality Gate Standards

Each phase MUST validate these items before proceeding to next phase:

**Build & Compilation**:
- [ ] Project builds/compiles without errors
- [ ] No syntax errors

**Test-Driven Development (TDD)**:
- [ ] Tests written BEFORE production code
- [ ] Red-Green-Refactor cycle followed
- [ ] Unit tests: ≥80% coverage for business logic
- [ ] Integration tests: Critical user flows validated
- [ ] Test suite runs in acceptable time (<5 minutes)

**Testing**:
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Test coverage maintained or improved

**Code Quality**:
- [ ] Linting passes with no errors
- [ ] Type checking passes (if applicable)
- [ ] Code formatting consistent

**Functionality**:
- [ ] Manual testing confirms feature works
- [ ] No regressions in existing functionality
- [ ] Edge cases tested

**Security & Performance**:
- [ ] No new security vulnerabilities
- [ ] No performance degradation
- [ ] Resource usage acceptable

**Documentation**:
- [ ] Code comments updated
- [ ] Documentation reflects changes

## Progress Tracking Protocol

Add this to plan document header:

```markdown
**CRITICAL INSTRUCTIONS**: After completing each phase:
1. ✅ Check off completed task checkboxes
2. 🧪 Run all quality gate validation commands
3. ⚠️ Verify ALL quality gate items pass
4. 📅 Update "Last Updated" date
5. 📝 Document learnings in Notes section
6. ➡️ Only then proceed to next phase

⛔ DO NOT skip quality gates or proceed with failing checks
```

## Phase Sizing Guidelines

**Small Scope** (2-3 phases, 3-6 hours total):
- Single component or simple feature
- Minimal dependencies
- Clear requirements
- Example: Add dark mode toggle, create new form component

**Medium Scope** (4-5 phases, 8-15 hours total):
- Multiple components or moderate feature
- Some integration complexity
- Database changes or API work
- Example: User authentication system, search functionality

**Large Scope** (6-7 phases, 15-25 hours total):
- Complex feature spanning multiple areas
- Significant architectural impact
- Multiple integrations
- Example: AI-powered search with embeddings, real-time collaboration

## Risk Assessment

Identify and document:
- **Technical Risks**: API changes, performance issues, data migration
- **Dependency Risks**: External library updates, third-party service availability
- **Timeline Risks**: Complexity unknowns, blocking dependencies
- **Quality Risks**: Test coverage gaps, regression potential

For each risk, specify:
- Probability: Low/Medium/High
- Impact: Low/Medium/High
- Mitigation Strategy: Specific action steps

## Rollback Strategy

For each phase, document how to revert changes if issues arise.
Consider:
- What code changes need to be undone
- Database migrations to reverse (if applicable)
- Configuration changes to restore
- Dependencies to remove

## Test Specification Guidelines

### Test-First Development Workflow

**For Each Feature Component**:
1. **Specify Test Cases** (before writing ANY code)
   - What inputs will be tested?
   - What outputs are expected?
   - What edge cases must be handled?
   - What error conditions should be tested?

2. **Write Tests** (Red Phase)
   - Write tests that WILL fail
   - Verify tests fail for the right reason
   - Run tests to confirm failure
   - Commit failing tests to track TDD compliance

3. **Implement Code** (Green Phase)
   - Write minimal code to make tests pass
   - Run tests frequently (every 2-5 minutes)
   - Stop when all tests pass
   - No additional functionality beyond tests

4. **Refactor** (Blue Phase)
   - Improve code quality while tests remain green
   - Extract duplicated logic
   - Improve naming and structure
   - Run tests after each refactoring step
   - Commit when refactoring complete

### Test Types

**Unit Tests**:
- **Target**: Individual functions, methods, classes
- **Dependencies**: None or mocked/stubbed
- **Speed**: Fast (<100ms per test)
- **Isolation**: Complete isolation from external systems
- **Coverage**: ≥80% of business logic

**Integration Tests**:
- **Target**: Interaction between components/modules
- **Dependencies**: May use real dependencies
- **Speed**: Moderate (<1s per test)
- **Isolation**: Tests component boundaries
- **Coverage**: Critical integration points

**End-to-End (E2E) Tests**:
- **Target**: Complete user workflows
- **Dependencies**: Real or near-real environment
- **Speed**: Slow (seconds to minutes)
- **Isolation**: Full system integration
- **Coverage**: Critical user journeys

### Test Coverage Calculation

**Coverage Thresholds** (adjust for your project):
- **Business Logic**: ≥90% (critical code paths)
- **Data Access Layer**: ≥80% (repositories, DAOs)
- **API/Controller Layer**: ≥70% (endpoints)
- **UI/Presentation**: Integration tests preferred over coverage

**Coverage Commands by Ecosystem**:
```bash
# JavaScript/TypeScript
jest --coverage
nyc report --reporter=html

# Python
pytest --cov=src --cov-report=html
coverage report

# Java
mvn jacoco:report
gradle jacocoTestReport

# Go
go test -cover ./...
go tool cover -html=coverage.out

# .NET
dotnet test /p:CollectCoverage=true /p:CoverageReporter=html
reportgenerator -reports:coverage.xml -targetdir:coverage

# Ruby
bundle exec rspec --coverage
open coverage/index.html

# PHP
phpunit --coverage-html coverage
```

### Common Test Patterns

**Arrange-Act-Assert (AAA) Pattern**:
```
test 'description of behavior':
  // Arrange: Set up test data and dependencies
  input = createTestData()

  // Act: Execute the behavior being tested
  result = systemUnderTest.method(input)

  // Assert: Verify expected outcome
  assert result == expectedOutput
```

**Given-When-Then (BDD Style)**:
```
test 'feature should behave in specific way':
  // Given: Initial context/state
  given userIsLoggedIn()

  // When: Action occurs
  when userClicksButton()

  // Then: Observable outcome
  then shouldSeeConfirmation()
```

**Mocking/Stubbing Dependencies**:
```
test 'component should call dependency':
  // Create mock/stub
  mockService = createMock(ExternalService)
  component = new Component(mockService)

  // Configure mock behavior
  when(mockService.method()).thenReturn(expectedData)

  // Execute and verify
  component.execute()
  verify(mockService.method()).calledOnce()
```

### Test Documentation in Plan

**In each phase, specify**:
1. **Test File Location**: Exact path where tests will be written
2. **Test Scenarios**: List of specific test cases
3. **Expected Failures**: What error should tests show initially?
4. **Coverage Target**: Percentage for this phase
5. **Dependencies to Mock**: What needs mocking/stubbing?
6. **Test Data**: What fixtures/factories are needed?

## Supporting Files Reference
- [plan-template.md](plan-template.md) - Complete plan document template


# Implementation Plan: [Feature Name]

**Status**: 🔄 In Progress
**Started**: YYYY-MM-DD
**Last Updated**: YYYY-MM-DD
**Estimated Completion**: YYYY-MM-DD

---

**⚠️ CRITICAL INSTRUCTIONS**: After completing each phase:
1. ✅ Check off completed task checkboxes
2. 🧪 Run all quality gate validation commands
3. ⚠️ Verify ALL quality gate items pass
4. 📅 Update "Last Updated" date above
5. 📝 Document learnings in Notes section
6. ➡️ Only then proceed to next phase

⛔ **DO NOT skip quality gates or proceed with failing checks**

---

## 📋 Overview

### Feature Description
[What this feature does and why it's needed]

### Success Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

### User Impact
[How this benefits users or improves the product]

---

## 🏗️ Architecture Decisions

| Decision | Rationale | Trade-offs |
|----------|-----------|------------|
| [Decision 1] | [Why this approach] | [What we're giving up] |
| [Decision 2] | [Why this approach] | [What we're giving up] |

---

## 📦 Dependencies

### Required Before Starting
- [ ] Dependency 1: [Description]
- [ ] Dependency 2: [Description]

### External Dependencies
- Package/Library 1: version X.Y.Z
- Package/Library 2: version X.Y.Z

---

## 🧪 Test Strategy

### Testing Approach
**TDD Principle**: Write tests FIRST, then implement to make them pass

### Test Pyramid for This Feature
| Test Type | Coverage Target | Purpose |
|-----------|-----------------|---------|
| **Unit Tests** | ≥80% | Business logic, models, core algorithms |
| **Integration Tests** | Critical paths | Component interactions, data flow |
| **E2E Tests** | Key user flows | Full system behavior validation |

### Test File Organization
```
test/
├── unit/
│   ├── [domain/business_logic]/
│   └── [data/models]/
├── integration/
│   └── [feature_name]/
└── e2e/
    └── [user_flows]/
```

### Coverage Requirements by Phase
- **Phase 1 (Foundation)**: Unit tests for core models/entities (≥80%)
- **Phase 2 (Business Logic)**: Logic + repository tests (≥80%)
- **Phase 3 (Integration)**: Component integration tests (≥70%)
- **Phase 4 (E2E)**: End-to-end user flow test (1+ critical path)

### Test Naming Convention
Follow your project's testing framework conventions:
```
// Example structure (adapt to your framework):
describe/group: Feature or component name
  test/it: Specific behavior being tested
    // Arrange → Act → Assert pattern
```

---

## 🚀 Implementation Phases

### Phase 1: [Foundation Phase Name]
**Goal**: [Specific working functionality this phase delivers]
**Estimated Time**: X hours
**Status**: ⏳ Pending | 🔄 In Progress | ✅ Complete

#### Tasks

**🔴 RED: Write Failing Tests First**
- [ ] **Test 1.1**: Write unit tests for [specific functionality]
  - File(s): `test/unit/[feature]/[component]_test.*`
  - Expected: Tests FAIL (red) because feature doesn't exist yet
  - Details: Test cases covering:
    - Happy path scenarios
    - Edge cases
    - Error conditions

- [ ] **Test 1.2**: Write integration tests for [component interaction]
  - File(s): `test/integration/[feature]_test.*`
  - Expected: Tests FAIL (red) because integration doesn't exist yet
  - Details: Test interaction between [list components]

**🟢 GREEN: Implement to Make Tests Pass**
- [ ] **Task 1.3**: Implement [component/module]
  - File(s): `src/[layer]/[component].*`
  - Goal: Make Test 1.1 pass with minimal code
  - Details: [Implementation notes]

- [ ] **Task 1.4**: Implement [integration/glue code]
  - File(s): `src/[layer]/[integration].*`
  - Goal: Make Test 1.2 pass
  - Details: [Implementation notes]

**🔵 REFACTOR: Clean Up Code**
- [ ] **Task 1.5**: Refactor for code quality
  - Files: Review all new code in this phase
  - Goal: Improve design without breaking tests
  - Checklist:
    - [ ] Remove duplication (DRY principle)
    - [ ] Improve naming clarity
    - [ ] Extract reusable components
    - [ ] Add inline documentation
    - [ ] Optimize performance if needed

#### Quality Gate ✋

**⚠️ STOP: Do NOT proceed to Phase 2 until ALL checks pass**

**TDD Compliance** (CRITICAL):
- [ ] **Red Phase**: Tests were written FIRST and initially failed
- [ ] **Green Phase**: Production code written to make tests pass
- [ ] **Refactor Phase**: Code improved while tests still pass
- [ ] **Coverage Check**: Test coverage meets requirements
  ```bash
  # Example commands (adapt to your testing framework):
  # npm test -- --coverage
  # pytest --cov=src --cov-report=html
  # dotnet test /p:CollectCoverage=true
  # go test -cover ./...

  [Your project's coverage command here]
  ```

**Build & Tests**:
- [ ] **Build**: Project builds/compiles without errors
- [ ] **All Tests Pass**: 100% of tests passing (no skipped tests)
- [ ] **Test Performance**: Test suite completes in acceptable time
- [ ] **No Flaky Tests**: Tests pass consistently (run 3+ times)

**Code Quality**:
- [ ] **Linting**: No linting errors or warnings
- [ ] **Formatting**: Code formatted per project standards
- [ ] **Type Safety**: Type checker passes (if applicable)
- [ ] **Static Analysis**: No critical issues from static analysis tools

**Security & Performance**:
- [ ] **Dependencies**: No known security vulnerabilities
- [ ] **Performance**: No performance regressions
- [ ] **Memory**: No memory leaks or resource issues
- [ ] **Error Handling**: Proper error handling implemented

**Documentation**:
- [ ] **Code Comments**: Complex logic documented
- [ ] **API Docs**: Public interfaces documented
- [ ] **README**: Usage instructions updated if needed

**Manual Testing**:
- [ ] **Functionality**: Feature works as expected
- [ ] **Edge Cases**: Boundary conditions tested
- [ ] **Error States**: Error handling verified

**Validation Commands** (customize for your project):
```bash
# Test Commands
[your test runner command]

# Coverage Check
[your coverage command]

# Code Quality
[your linter command]
[your formatter check command]
[your type checker command]

# Build Verification
[your build command]

# Security Audit
[your dependency audit command]

# Example for different ecosystems:
# JavaScript/TypeScript: npm test && npm run lint && npm run type-check
# Python: pytest && black --check . && mypy .
# Java: mvn test && mvn checkstyle:check
# Go: go test ./... && golangci-lint run
# .NET: dotnet test && dotnet format --verify-no-changes
# Ruby: bundle exec rspec && rubocop
# Rust: cargo test && cargo clippy
```

**Manual Test Checklist**:
- [ ] Test case 1: [Specific scenario to verify]
- [ ] Test case 2: [Edge case to verify]
- [ ] Test case 3: [Error handling to verify]

---

### Phase 2: [Core Feature Phase Name]
**Goal**: [Specific deliverable]
**Estimated Time**: X hours
**Status**: ⏳ Pending | 🔄 In Progress | ✅ Complete

#### Tasks

**🔴 RED: Write Failing Tests First**
- [ ] **Test 2.1**: Write unit tests for [specific functionality]
  - File(s): `test/unit/[feature]/[component]_test.*`
  - Expected: Tests FAIL (red) because feature doesn't exist yet
  - Details: Test cases covering:
    - Happy path scenarios
    - Edge cases
    - Error conditions

- [ ] **Test 2.2**: Write integration tests for [component interaction]
  - File(s): `test/integration/[feature]_test.*`
  - Expected: Tests FAIL (red) because integration doesn't exist yet
  - Details: Test interaction between [list components]

**🟢 GREEN: Implement to Make Tests Pass**
- [ ] **Task 2.3**: Implement [component/module]
  - File(s): `src/[layer]/[component].*`
  - Goal: Make Test 2.1 pass with minimal code
  - Details: [Implementation notes]

- [ ] **Task 2.4**: Implement [integration/glue code]
  - File(s): `src/[layer]/[integration].*`
  - Goal: Make Test 2.2 pass
  - Details: [Implementation notes]

**🔵 REFACTOR: Clean Up Code**
- [ ] **Task 2.5**: Refactor for code quality
  - Files: Review all new code in this phase
  - Goal: Improve design without breaking tests
  - Checklist:
    - [ ] Remove duplication (DRY principle)
    - [ ] Improve naming clarity
    - [ ] Extract reusable components
    - [ ] Add inline documentation
    - [ ] Optimize performance if needed

#### Quality Gate ✋

**⚠️ STOP: Do NOT proceed to Phase 3 until ALL checks pass**

**TDD Compliance** (CRITICAL):
- [ ] **Red Phase**: Tests were written FIRST and initially failed
- [ ] **Green Phase**: Production code written to make tests pass
- [ ] **Refactor Phase**: Code improved while tests still pass
- [ ] **Coverage Check**: Test coverage meets requirements

**Build & Tests**:
- [ ] **Build**: Project builds/compiles without errors
- [ ] **All Tests Pass**: 100% of tests passing (no skipped tests)
- [ ] **Test Performance**: Test suite completes in acceptable time
- [ ] **No Flaky Tests**: Tests pass consistently (run 3+ times)

**Code Quality**:
- [ ] **Linting**: No linting errors or warnings
- [ ] **Formatting**: Code formatted per project standards
- [ ] **Type Safety**: Type checker passes (if applicable)
- [ ] **Static Analysis**: No critical issues from static analysis tools

**Security & Performance**:
- [ ] **Dependencies**: No known security vulnerabilities
- [ ] **Performance**: No performance regressions
- [ ] **Memory**: No memory leaks or resource issues
- [ ] **Error Handling**: Proper error handling implemented

**Documentation**:
- [ ] **Code Comments**: Complex logic documented
- [ ] **API Docs**: Public interfaces documented
- [ ] **README**: Usage instructions updated if needed

**Manual Testing**:
- [ ] **Functionality**: Feature works as expected
- [ ] **Edge Cases**: Boundary conditions tested
- [ ] **Error States**: Error handling verified

**Validation Commands**:
```bash
[Same as Phase 1 - customize for your project]
```

**Manual Test Checklist**:
- [ ] Test case 1: [Specific scenario to verify]
- [ ] Test case 2: [Edge case to verify]
- [ ] Test case 3: [Error handling to verify]

---

### Phase 3: [Enhancement Phase Name]
**Goal**: [Specific deliverable]
**Estimated Time**: X hours
**Status**: ⏳ Pending | 🔄 In Progress | ✅ Complete

#### Tasks

**🔴 RED: Write Failing Tests First**
- [ ] **Test 3.1**: Write unit tests for [specific functionality]
  - File(s): `test/unit/[feature]/[component]_test.*`
  - Expected: Tests FAIL (red) because feature doesn't exist yet
  - Details: Test cases covering:
    - Happy path scenarios
    - Edge cases
    - Error conditions

- [ ] **Test 3.2**: Write integration tests for [component interaction]
  - File(s): `test/integration/[feature]_test.*`
  - Expected: Tests FAIL (red) because integration doesn't exist yet
  - Details: Test interaction between [list components]

**🟢 GREEN: Implement to Make Tests Pass**
- [ ] **Task 3.3**: Implement [component/module]
  - File(s): `src/[layer]/[component].*`
  - Goal: Make Test 3.1 pass with minimal code
  - Details: [Implementation notes]

- [ ] **Task 3.4**: Implement [integration/glue code]
  - File(s): `src/[layer]/[integration].*`
  - Goal: Make Test 3.2 pass
  - Details: [Implementation notes]

**🔵 REFACTOR: Clean Up Code**
- [ ] **Task 3.5**: Refactor for code quality
  - Files: Review all new code in this phase
  - Goal: Improve design without breaking tests
  - Checklist:
    - [ ] Remove duplication (DRY principle)
    - [ ] Improve naming clarity
    - [ ] Extract reusable components
    - [ ] Add inline documentation
    - [ ] Optimize performance if needed

#### Quality Gate ✋

**⚠️ STOP: Do NOT proceed until ALL checks pass**

**TDD Compliance** (CRITICAL):
- [ ] **Red Phase**: Tests were written FIRST and initially failed
- [ ] **Green Phase**: Production code written to make tests pass
- [ ] **Refactor Phase**: Code improved while tests still pass
- [ ] **Coverage Check**: Test coverage meets requirements

**Build & Tests**:
- [ ] **Build**: Project builds/compiles without errors
- [ ] **All Tests Pass**: 100% of tests passing (no skipped tests)
- [ ] **Test Performance**: Test suite completes in acceptable time
- [ ] **No Flaky Tests**: Tests pass consistently (run 3+ times)

**Code Quality**:
- [ ] **Linting**: No linting errors or warnings
- [ ] **Formatting**: Code formatted per project standards
- [ ] **Type Safety**: Type checker passes (if applicable)
- [ ] **Static Analysis**: No critical issues from static analysis tools

**Security & Performance**:
- [ ] **Dependencies**: No known security vulnerabilities
- [ ] **Performance**: No performance regressions
- [ ] **Memory**: No memory leaks or resource issues
- [ ] **Error Handling**: Proper error handling implemented

**Documentation**:
- [ ] **Code Comments**: Complex logic documented
- [ ] **API Docs**: Public interfaces documented
- [ ] **README**: Usage instructions updated if needed

**Manual Testing**:
- [ ] **Functionality**: Feature works as expected
- [ ] **Edge Cases**: Boundary conditions tested
- [ ] **Error States**: Error handling verified

**Validation Commands**:
```bash
[Same as previous phases - customize for your project]
```

**Manual Test Checklist**:
- [ ] Test case 1: [Specific scenario to verify]
- [ ] Test case 2: [Edge case to verify]
- [ ] Test case 3: [Error handling to verify]

---

## ⚠️ Risk Assessment

| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|---------------------|
| [Risk 1: e.g., API changes break integration] | Low/Med/High | Low/Med/High | [Specific mitigation steps] |
| [Risk 2: e.g., Performance degradation] | Low/Med/High | Low/Med/High | [Specific mitigation steps] |
| [Risk 3: e.g., Database migration issues] | Low/Med/High | Low/Med/High | [Specific mitigation steps] |

---

## 🔄 Rollback Strategy

### If Phase 1 Fails
**Steps to revert**:
- Undo code changes in: [list files]
- Restore configuration: [specific settings]
- Remove dependencies: [if any were added]

### If Phase 2 Fails
**Steps to revert**:
- Restore to Phase 1 complete state
- Undo changes in: [list files]
- Database rollback: [if applicable]

### If Phase 3 Fails
**Steps to revert**:
- Restore to Phase 2 complete state
- [Additional cleanup steps]

---

## 📊 Progress Tracking

### Completion Status
- **Phase 1**: ⏳ 0% | 🔄 50% | ✅ 100%
- **Phase 2**: ⏳ 0% | 🔄 50% | ✅ 100%
- **Phase 3**: ⏳ 0% | 🔄 50% | ✅ 100%

**Overall Progress**: X% complete

### Time Tracking
| Phase | Estimated | Actual | Variance |
|-------|-----------|--------|----------|
| Phase 1 | X hours | Y hours | +/- Z hours |
| Phase 2 | X hours | - | - |
| Phase 3 | X hours | - | - |
| **Total** | X hours | Y hours | +/- Z hours |

---

## 📝 Notes & Learnings

### Implementation Notes
- [Add insights discovered during implementation]
- [Document decisions that deviate from original plan]
- [Record helpful debugging discoveries]

### Blockers Encountered
- **Blocker 1**: [Description] → [Resolution]
- **Blocker 2**: [Description] → [Resolution]

### Improvements for Future Plans
- [What would you do differently next time?]
- [What worked particularly well?]

---

## 📚 References

### Documentation
- [Link to relevant docs]
- [Link to API references]
- [Link to design mockups]

### Related Issues
- Issue #X: [Description]
- PR #Y: [Description]

---

## ✅ Final Checklist

**Before marking plan as COMPLETE**:
- [ ] All phases completed with quality gates passed
- [ ] Full integration testing performed
- [ ] Documentation updated
- [ ] Performance benchmarks meet targets
- [ ] Security review completed
- [ ] Accessibility requirements met (if UI feature)
- [ ] All stakeholders notified
- [ ] Plan document archived for future reference

---

## 📖 TDD Example Workflow

### Example: Adding User Authentication Feature

**Phase 1: RED (Write Failing Tests)**

```
# Pseudocode - adapt to your testing framework

test "should validate user credentials":
  // Arrange
  authService = new AuthService(mockDatabase)
  validCredentials = {username: "user", password: "pass"}

  // Act
  result = authService.authenticate(validCredentials)

  // Assert
  expect(result.isSuccess).toBe(true)
  expect(result.user).toBeDefined()
  // TEST FAILS - AuthService doesn't exist yet
```

**Phase 2: GREEN (Minimal Implementation)**

```
class AuthService:
  function authenticate(credentials):
    // Minimal code to make test pass
    user = database.findUser(credentials.username)
    if user AND user.password == credentials.password:
      return Success(user)
    return Failure("Invalid credentials")
    // TEST PASSES - minimal functionality works
```

**Phase 3: REFACTOR (Improve Design)**

```
class AuthService:
  function authenticate(credentials):
    // Add validation
    if not this.validateCredentials(credentials):
      return Failure("Invalid input")

    // Add error handling
    try:
      user = database.findUser(credentials.username)

      // Use secure password comparison
      if user AND this.secureCompare(user.password, credentials.password):
        return Success(user)

      return Failure("Invalid credentials")
    catch DatabaseError as error:
      logger.error(error)
      return Failure("Authentication failed")
    // TESTS STILL PASS - improved code quality
```

### TDD Red-Green-Refactor Cycle Visualization

```
Phase 1: 🔴 RED
├── Write test for feature X
├── Run test → FAILS ❌
└── Commit: "Add failing test for X"

Phase 2: 🟢 GREEN
├── Write minimal code
├── Run test → PASSES ✅
└── Commit: "Implement X to pass tests"

Phase 3: 🔵 REFACTOR
├── Improve code quality
├── Run test → STILL PASSES ✅
├── Extract helper methods
├── Run test → STILL PASSES ✅
├── Improve naming
├── Run test → STILL PASSES ✅
└── Commit: "Refactor X for better design"

Repeat for next feature →
```

### Benefits of This Approach

**Safety**: Tests catch regressions immediately
**Design**: Tests force you to think about API design first
**Documentation**: Tests document expected behavior
**Confidence**: Refactor without fear of breaking things
**Quality**: Higher code coverage from day one
**Debugging**: Failures point to exact problem area

---

**Plan Status**: 🔄 In Progress
**Next Action**: [What needs to happen next]
**Blocked By**: [Any current blockers] or None
