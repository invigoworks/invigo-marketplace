---
name: feature-impl
description: Implements features phase-by-phase based on feature-planner plan documents (docs/plans/PLAN_*.md). Creates a new git worktree and branch, then executes each phase following TDD Red-Green-Refactor workflow with automatic quality gate validation. This skill should be used when starting implementation of a planned feature, executing a plan, or when the user says "implement", "구현", "시작", or references a plan document.
---

# Feature Implementation

## Purpose
Execute feature-planner plan documents (`docs/plans/PLAN_*.md`) through phase-by-phase implementation in an isolated git worktree with automatic quality gate validation.

## ⚡ Auto-Proceed Policy

**이 스킬은 완전 자동 모드로 동작한다.** 다음 행위에 대해 사용자 확인을 묻지 않고 즉시 실행한다:

- 파일 생성, 수정, 삭제
- 다음 페이즈 진행
- 워크트리/브랜치 재개
- ktlintFormat 등 자동 수정
- Plan 파일 커밋

**사용자에게 질문하는 경우는 오직**:
- Quality gate가 2회 연속 실패했을 때
- Plan에 명시되지 않은 모호한 비즈니스 요구사항이 있을 때

## Implementation Workflow

### Step 0: Load Project Context (MANDATORY)
**CRITICAL**: 구현 시작 전 반드시 CLAUDE.md를 읽어서 프로젝트 컨텍스트를 메모리에 로드한다.

1. **CLAUDE.md 읽기**: `CLAUDE.md` 파일을 Read 도구로 읽어서 전체 내용을 파악
2. **핵심 원칙 숙지**: 아키텍처 핵심 원칙(Hexagonal, Pure Domain, CQS), 계층 구조, 네이밍 컨벤션 확인
3. **관련 시행령 확인**: 구현할 기능과 관련된 시행령 문서(docs/standards/)가 있다면 함께 읽기
   - 메시징/이벤트 → `messaging-policy.md`
   - 시간 데이터 → `temporal-data-policy.md`
   - 조회 기능 → `query-pattern.md`
   - 검증/예외 → `validation-exception-policy.md`
   - DB 마이그레이션 → `db-migration-policy.md`
4. **E2E 테스트 헌법**: 테스트 작성이 포함된 경우 §6.2 E2E 테스트 헌법 숙지
   - Track A/B/C 결정 기준
   - `E2ETestSupport` 또는 `SecurityE2ESupport` 상속 필수

> ⚠️ 이 단계를 건너뛰면 프로젝트 아키텍처 규칙을 위반하는 코드가 생성될 수 있습니다.

### Step 1: Plan Selection

1. List available plan documents in `docs/plans/PLAN_*.md`
2. If multiple plans exist, ask the user which plan to implement
3. Read the selected plan document fully to understand all phases, tasks, and quality gates
4. Identify the current progress — find the first phase with unchecked tasks

### Step 2: Worktree & Branch Setup

플랜 파일명에서 이름을 추출하여 브랜치와 워크트리를 생성한다.

#### 네이밍 규칙

플랜 파일명의 `PLAN_` prefix와 `.md` suffix를 제거한 이름을 그대로 사용한다.

```
Plan file: docs/plans/user/ready/PLAN_user-authentication.md
           └─────────────────────┬───────────────────────────┘
                                 ↓
Name:      user-authentication
           └───────┬──────────┘
                   ↓
Branch:    feature/user-authentication
Worktree:  ../worktrees/feature/user-authentication
Review:    docs/user/reviews/REVIEW_user-authentication.md
```

**Procedure**:

1. 플랜 파일명에서 이름을 추출한다 (`PLAN_` prefix, `.md` suffix 제거)
   - 예: `PLAN_user-authentication.md` → `user-authentication`
2. 브랜치 이름 결정: `feature/{name}` (예: `feature/user-authentication`)
3. **Commit plan file to main** before creating worktree (so it's included):
   ```bash
   git add docs/plans/{domain}/ready/PLAN_{name}.md
   git commit -m "docs: add implementation plan for {name}"
   ```
4. Check if the branch or worktree already exists (resume scenario)
5. If new:
   ```bash
   git worktree add -b feature/{name} ../worktrees/feature/{name} main
   ```
6. If already exists, **automatically resume** from the existing worktree (no confirmation needed)
7. Change working directory to the new worktree for all subsequent operations

**Important**: All file operations from this point forward MUST use the worktree path, not the original repository path.

### Step 3: Phase Execution

Execute phases **sequentially**, one at a time. For each phase:

#### 3a. Announce Phase
Inform the user which phase is starting, its goal, and the tasks involved.

#### 3b. Execute Tasks in TDD Order

Follow the task order defined in the plan document:

1. **🔴 RED Tasks**: Write failing tests first
   - Create test files at the paths specified in the plan
   - Run tests to confirm they fail (expected behavior)

2. **🟢 GREEN Tasks**: Implement minimal code to pass tests
   - Create/modify source files as specified
   - Run tests after each implementation task to verify progress

3. **🔵 REFACTOR Tasks**: Improve code quality
   - Apply refactoring items from the plan's checklist
   - Run tests after each refactoring step to ensure they still pass

#### 3c. Quality Gate Validation

After completing all tasks in a phase, automatically run validation commands:

```bash
# Build verification
./gradlew build

# Code style check
./gradlew ktlintCheck

# Run all tests
./gradlew test
```

Report results to the user in a summary table:

| Check | Result |
|-------|--------|
| Build | ✅ / ❌ |
| ktlintCheck | ✅ / ❌ |
| Tests | ✅ / ❌ (N passed, M failed) |

#### 3d. Update Plan Document

After quality gate validation, update the plan document in the **original repository** (not the worktree):
- Check off completed task checkboxes (`- [x]`)
- Update phase status to ✅ Complete
- Update "Last Updated" date
- Update progress tracking percentages

**Critical**: The plan document lives in the main repository. Use the original repo path to update it.

#### 3e. Phase Transition

**Auto-proceed policy**: Do NOT ask for confirmation between phases. Proceed automatically.

If quality gates pass:
- Inform user the phase is complete with a brief summary
- **Immediately proceed to the next phase** without asking

If quality gates fail:
- Report which checks failed with details
- Attempt to fix issues automatically (e.g., run `ktlintFormat` for style issues)
- Re-run failed checks
- If still failing after 2 attempts, THEN ask user how to proceed

### Step 4: Completion

After all phases are complete:
1. Run a final full validation (`./gradlew build test ktlintCheck`)
2. Update the plan document status to ✅ Complete
3. Report the final summary to the user
4. Inform user that code is ready in the worktree and suggest next steps:
   - Review changes with `/branch-review`
   - Commit and create PR
   - Merge worktree back

## Resume Protocol

When a worktree and branch already exist:

1. Detect existing worktree via `git worktree list`
2. Read the plan document to find progress (checked vs unchecked tasks)
3. Identify the current phase (first phase with unchecked tasks)
4. **Automatically resume** from the identified point (no confirmation needed)
5. Briefly inform user which phase is being resumed, then continue

## Error Handling

| Scenario | Action |
|----------|--------|
| Build fails | Show error output, attempt fix, re-run |
| Test fails | Show failing test details, implement fix |
| ktlintCheck fails | Run `./gradlew ktlintFormat` automatically, re-check |
| Worktree conflict | Ask user whether to reuse or recreate |
| Plan file not found | List available plans or ask user to run `/feature-planner` first |

## Conventions

- Follow all rules in CLAUDE.md (Hexagonal Architecture, CQS, naming conventions, etc.)
- All implementation classes use `internal` visibility
- Domain models are pure Kotlin (no JPA annotations)
- Time fields use `Instant`, DB columns use `TIMESTAMPTZ`
- Tests follow the project's existing test patterns and directory structure
