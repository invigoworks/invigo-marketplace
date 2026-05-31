---
name: issue-full-cycle
description: GitHub 이슈 번호를 받아 issue-plan → issue-impl-remote → issue-pr → pr-review → review-action → jenkins-ci-loop → pr-merge 전체 사이클을 멀티에이전트로 완전 자동 실행하는 스킬입니다. 메인 오케스트레이터가 각 단계별 전담 에이전트를 순차 파견하며 파이프라인 전체를 감독합니다. 이 스킬은 "/issue-full-cycle", "/issue-full-cycle #123", "이슈 전체 사이클", "이슈 풀 사이클" 등을 요청할 때 사용됩니다.
---

# Issue Full Cycle

## Purpose

GitHub 이슈 번호 하나로 전체 개발 사이클을 **완전 자동**으로 실행한다.

```
issue-plan → issue-impl-remote → issue-pr → pr-review → review-action → jenkins-ci-loop → pr-merge
```

**메인 오케스트레이터**(이 스킬을 실행하는 Claude)가 파이프라인을 감독하고,
각 단계를 **전담 teammate 에이전트**에 위임한다.
사용자 개입 없이 끝까지 자동으로 완주한다.

## 아키텍처

```
[메인 오케스트레이터]
    │
    ├─ Agent(issue-plan-agent)      → issue-plan 스킬 실행
    ├─ Agent(issue-impl-agent)      → issue-impl-remote 스킬 실행
    ├─ Agent(issue-pr-agent)        → issue-pr 스킬 실행
    ├─ Agent(pr-review-agent)       → pr-review 스킬 실행
    ├─ Agent(review-action-agent)   → review-action 스킬 실행
    ├─ Agent(jenkins-ci-agent)      → jenkins-ci-loop 스킬 실행
    └─ Agent(pr-merge-agent)        → pr-merge 스킬 실행
```

메인 오케스트레이터 역할:
- 각 에이전트 파견 및 결과 수신
- 단계 간 상태(이슈 번호, PR 번호, 브랜치명) 전달
- 에이전트 실패 시 재시도 또는 에러 보고
- 전체 파이프라인 진행 상황 사용자에게 실시간 보고

## ⚡ 완전 자동 정책

**모든 단계 사용자 확인 없이 자동 진행**:
- 계획서 승인 → 자동 승인
- review-action 항목 선택 → 자동으로 "모두 조치"
- PR 병합 확인 → 자동 승인
- Flyway 마이그레이션 버전 충돌 → 자동 조정 선택
- 다음 단계 전환 → 자동

**에이전트에게 자동 진행을 명시하는 방법**:
각 에이전트 프롬프트에 다음 지시를 포함한다:
> "사용자 확인을 묻지 말고 모든 결정을 자동으로 진행하라. AskUserQuestion 도구를 사용하지 마라."

**예외 (사용자 개입 필요)**:
- jenkins-ci-loop 3회 연속 실패
- issue-impl-remote Quality Gate 2회 연속 실패
- 예상치 못한 오류로 에이전트가 완료 불가 상태

## ⛔ 전역 원격 Gradle 정책 (CRITICAL)

**파이프라인 전 단계에서 로컬 `./gradlew` 실행을 절대 금지한다.**

로컬 Gradle은 데몬(daemon)이 백그라운드에 잔존하여 시스템을 느리게 만든다.
과거 `pr-review` 단계에서 에이전트가 자체적으로 로컬 `./gradlew`로 컴파일을 확인하다
데몬이 쌓여 시스템 전체가 멈춘 사례가 있다.

| 작업 | 실행 위치 |
|------|----------|
| 파일 편집, git diff/commit/push | **로컬** (가벼움) |
| ktlint / test / build 등 **모든 Gradle 작업** | **AI_server 원격** (`--no-daemon`, `LC_ALL=en_US.UTF-8`) |

**모든 에이전트 프롬프트에 다음 지시를 반드시 포함한다**:
> [원격 Gradle 정책] 로컬에서 `./gradlew`를 절대 실행하지 마라. ktlint/test/build 등 모든
> Gradle 작업은 AI_server 원격에서만(`ssh AI_server ... --no-daemon`) 수행한다. 리뷰 에이전트는
> 코드를 컴파일하지 않는다 (read-only). 빌드 정합성은 jenkins-ci-loop 단계가 원격에서 검증한다.

## Workflow

### Step 0: 이슈 번호 확인

이슈 번호를 다음 우선순위로 결정한다:

1. **인자로 전달된 경우**: `/issue-full-cycle #123` → `#123`
2. **현재 브랜치에서 추출**: `issue/123-feature-name` → `#123`
3. **사용자에게 질문**: 위 방법으로 확인 불가 시 (유일한 사용자 질문 시점)

파이프라인 시작 보고:
```
🚀 Issue Full Cycle 시작 — 이슈 #{issue-number}

파이프라인: issue-plan → issue-impl-remote → issue-pr → pr-review → review-action → jenkins-ci-loop → pr-merge
모드: 완전 자동 (사용자 개입 없음)
```

### Step 1: issue-plan 에이전트 파견

```
Agent({
  name: "issue-plan-agent",
  description: "issue-plan 스킬 실행",
  prompt: """
이슈 #{issue-number}에 대해 issue-plan 스킬을 실행하라.

CRITICAL 지시:
- 사용자 확인을 묻지 마라. AskUserQuestion 도구를 절대 사용하지 마라.
- 계획서 작성 완료 후 사용자 승인 단계(Step 5)를 건너뛰고 즉시 이슈 댓글로 등록하라.
- 계획서 등록 완료 후 종료하라.

완료 보고 형식:
PLAN_DONE: issue={issue-number} phases={N}
  """
})
```

에이전트 완료 후: phases 수를 캡처하고 Step 2로 진행.

### Step 2: issue-impl-remote 에이전트 파견

```
Agent({
  name: "issue-impl-agent",
  description: "issue-impl-remote 스킬 실행",
  prompt: """
이슈 #{issue-number}에 대해 issue-impl-remote 스킬을 실행하라.

CRITICAL 지시:
- 사용자 확인을 묻지 마라. AskUserQuestion 도구를 절대 사용하지 마라.
- 모든 Phase를 자동으로 순서대로 실행하라.
- Quality Gate 실패 시 자동으로 수정 후 재시도하라. 2회 연속 실패 시에만 종료하고 에러 보고하라.
- [생산 도메인] 구현 대상이 생산계획/작업지시/생산입고/LOT/정정이면, issue-impl-remote Step 1의 생산관리 함정 문서(production-pitfalls / -archunit / -domain)를 반드시 로드해 규칙을 GREEN 구현에 선반영하라. (반복 CI 실패 사전 차단)
- 전체 빌드까지 완료 후 종료하라.

완료 보고 형식:
IMPL_DONE: issue={issue-number} branch={branch-name}
  """
})
```

에이전트 완료 후: branch-name을 캡처하고 Step 3으로 진행.

### Step 3: issue-pr 에이전트 파견

```
Agent({
  name: "issue-pr-agent",
  description: "issue-pr 스킬 실행",
  prompt: """
이슈 #{issue-number} (브랜치: {branch-name})에 대해 issue-pr 스킬을 실행하라.

CRITICAL 지시:
- 사용자 확인을 묻지 마라. AskUserQuestion 도구를 절대 사용하지 마라.
- PR을 즉시 생성하라.
- 생성된 PR 번호를 반드시 보고하라.

완료 보고 형식:
PR_DONE: issue={issue-number} pr={pr-number} branch={branch-name}
  """
})
```

에이전트 완료 후: pr-number를 캡처하고 Step 4로 진행.

### Step 4: pr-review 에이전트 파견

```
Agent({
  name: "pr-review-agent",
  description: "pr-review 스킬 실행",
  prompt: """
PR #{pr-number}에 대해 pr-review 스킬을 실행하라.

CRITICAL 지시:
- 사용자 확인을 묻지 마라. AskUserQuestion 도구를 절대 사용하지 마라.
- [원격 Gradle 정책] 로컬에서 `./gradlew`를 절대 실행하지 마라. 리뷰는 read-only이며 코드를
  컴파일/빌드/테스트하지 않는다. 4개 하위 리뷰 에이전트에게도 동일하게 로컬 Gradle 실행을 금지하라.
  빌드 정합성은 후속 jenkins-ci-loop 단계가 원격(AI_server)에서 검증한다.
- 4개 에이전트 병렬 리뷰를 실행하고 결과를 PR 댓글로 등록하라.
- [생산 도메인] 변경 파일이 생산계획/작업지시/생산입고/LOT/정정이면, pr-review Step 4의 생산관리 함정 점검(탐지 grep 체크리스트)을 적용해 위반을 심각도와 함께 보고하라. (컴파일 금지, grep 확인만)
- 완료 후 즉시 종료하라.

완료 보고 형식:
REVIEW_DONE: pr={pr-number} critical={N} medium={M} low={L}
  """
})
```

에이전트 완료 후: 이슈 수를 캡처하고 Step 5로 진행.

### Step 5: review-action 에이전트 파견

```
Agent({
  name: "review-action-agent",
  description: "review-action 스킬 실행",
  prompt: """
PR #{pr-number}에 대해 review-action 스킬을 실행하라.

CRITICAL 지시:
- 사용자 확인을 묻지 마라. AskUserQuestion 도구를 절대 사용하지 마라.
- 조치 항목 선택 시 묻지 말고 즉시 전체 항목(모두 조치)을 자동 선택하라.
- 모든 미조치 항목을 심각도 순(심각 → 중간 → 낮음)으로 처리하라.
- 자동 수정 불가 항목은 건너뛰고 목록만 보고하라.
- 완료 후 즉시 종료하라.

완료 보고 형식:
ACTION_DONE: pr={pr-number} fixed={N} skipped={M}
  """
})
```

에이전트 완료 후: 수정 결과를 캡처하고 Step 6으로 진행.

### Step 6: jenkins-ci-loop 에이전트 파견

```
Agent({
  name: "jenkins-ci-agent",
  description: "jenkins-ci-loop 스킬 실행",
  prompt: """
PR #{pr-number}에 대해 jenkins-ci-loop 스킬을 실행하라.

CRITICAL 지시:
- 사용자 확인을 묻지 마라.
- SUCCESS가 될 때까지 자동으로 반복하라 (실패 시 코드 수정 → commit → push → 재빌드).
- 3회 연속 동일 원인 실패 시에만 종료하고 에러 보고하라.

완료 보고 형식 (성공):
CI_DONE: pr={pr-number} build={build-number} result=SUCCESS

완료 보고 형식 (3회 실패):
CI_FAILED: pr={pr-number} reason={실패원인}
  """
})
```

에이전트 결과:
- `CI_DONE` → Step 7로 진행
- `CI_FAILED` → 사용자에게 실패 내용 보고 후 중단

### Step 7: pr-merge 에이전트 파견

```
Agent({
  name: "pr-merge-agent",
  description: "pr-merge 스킬 실행",
  prompt: """
PR #{pr-number} (이슈 #{issue-number})에 대해 pr-merge 스킬을 실행하라.

CRITICAL 지시:
- 사용자 확인을 묻지 마라. AskUserQuestion 도구를 절대 사용하지 마라.
- 병합 확인 단계(Step 3)를 건너뛰고 즉시 squash merge를 실행하라.
- Flyway 마이그레이션 버전 충돌 감지 시 자동으로 버전 조정 후 진행하라.
- 워크트리 제거, 로컬/원격 브랜치 삭제, 이슈 종결, 라벨 정리 모두 자동 수행하라.
- API 문서 동기화 제안은 건너뛰어라.

완료 보고 형식:
MERGE_DONE: pr={pr-number} issue={issue-number} branch={branch-name}
  """
})
```

에이전트 완료 후: Step 8로 진행.

### Step 8: 완료 보고

```
🎉 Issue Full Cycle 완료

| 단계 | 에이전트 | 결과 |
|------|---------|------|
| 📋 issue-plan | issue-plan-agent | ✅ 계획서 등록 ({N} phases) |
| 🔨 issue-impl-remote | issue-impl-agent | ✅ 구현 완료 |
| 🔗 issue-pr | issue-pr-agent | ✅ PR #{pr-number} 생성 |
| 🔍 pr-review | pr-review-agent | ✅ 리뷰 완료 (심각 {N}건) |
| 🛠️ review-action | review-action-agent | ✅ {N}건 조치 완료 |
| 🏗️ jenkins-ci-loop | jenkins-ci-agent | ✅ Build #{build} SUCCESS |
| 🔀 pr-merge | pr-merge-agent | ✅ main 병합 완료 |

이슈 #{issue-number}가 완전히 종결되었습니다.
```

## 에이전트 간 상태 전달

각 에이전트 완료 보고에서 다음 정보를 파싱하여 다음 에이전트에 전달한다:

| 변수 | 캡처 시점 | 전달 대상 |
|------|----------|----------|
| `issue-number` | Step 0 | 전 에이전트 |
| `branch-name` | Step 2 완료 보고 | Step 3~7 에이전트 |
| `pr-number` | Step 3 완료 보고 | Step 4~7 에이전트 |
| `build-number` | Step 6 완료 보고 | Step 8 보고 |

PR 번호 백업 캡처 (에이전트 보고에 없는 경우):
```bash
gh pr view --json number -q '.number' -R invigoworks/bitda-back
```

## 중단 및 재개

특정 단계부터 재개하려면:

```
/issue-full-cycle #123 --from pr-review
/issue-full-cycle #123 --from jenkins-ci-loop
/issue-full-cycle #123 --from pr-merge
```

`--from` 없으면 항상 Step 1(issue-plan)부터 시작.
각 스킬의 Resume Protocol이 기존 워크트리/계획서/PR을 자동 감지하므로 중복 작업 없음.

## 에러 처리

| 에러 상황 | 처리 방법 |
|----------|----------|
| 에이전트가 `CI_FAILED` 보고 | 사용자에게 실패 원인 보고 후 중단 |
| 에이전트가 Quality Gate 2회 실패 보고 | 사용자에게 실패 내용 보고 후 중단 |
| 에이전트 응답 파싱 불가 | 해당 단계 재시도 1회, 실패 시 사용자 보고 |
| pr-merge 병합 불가 (BLOCKED 등) | 사용자에게 원인 보고 후 중단 |

