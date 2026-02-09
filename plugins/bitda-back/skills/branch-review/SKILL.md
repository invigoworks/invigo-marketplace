---
name: branch-review
description: "현재 브랜치의 변경사항을 code-reviewer, test-engineer, backend-architect, architect-reviewer 에이전트 4개로 병렬 리뷰하는 스킬입니다. CLAUDE.md 아키텍처 규칙 준수 여부를 포함하여 통합 리뷰 보고서를 한글 마크다운으로 생성합니다. feature-planner로 생성된 플랜 문서가 있으면 리뷰에 포함합니다. 이 스킬은 브랜치 작업 완료 후 커밋/PR 전에 코드 품질을 점검할 때, 또는 사용자가 /branch-review를 요청할 때 사용됩니다."
---

# Branch Review

## Purpose

현재 브랜치에서 main 대비 변경된 코드를 4개 전문 에이전트로 병렬 리뷰하고,
CLAUDE.md 아키텍처 규칙 준수 여부를 포함한 통합 리뷰 보고서를 생성한다.
feature-planner/feature-impl로 생성된 플랜 문서가 있으면 구현 의도 대비 리뷰를 수행한다.

## Workflow

### Step 1: 변경사항 및 플랜 문서 수집

1. 베이스 브랜치를 결정한다: `git rev-parse --verify main 2>/dev/null`로 로컬 main 존재 여부를 확인한다. 없으면 `origin/main`을 사용한다. (worktree 환경 대응)
2. `git diff {base}...HEAD --name-status`로 변경된 파일 목록을 수집한다.
3. `git log {base}..HEAD --oneline`으로 커밋 이력을 수집한다.
4. 프로젝트 루트의 `CLAUDE.md` 파일을 읽어 아키텍처 규칙을 파악한다.
5. **플랜 문서 탐색**: 현재 브랜치와 연관된 플랜 문서를 찾는다.

**주의: diff 전문은 에이전트에게 전달하지 않는다.** 변경 파일 목록(`--name-status`)만 전달하고, 에이전트가 직접 Read 도구로 파일을 읽도록 한다. 이는 대규모 변경 시 토큰 초과를 방지한다.

#### 플랜 문서 탐색 로직

브랜치 이름에서 feature 이름을 추출하여 플랜 문서를 탐색한다.

**브랜치 → 플랜 문서 매핑 예시**:
```
브랜치: feature/user-authentication
플랜 문서 후보:
  - docs/plans/*/ready/PLAN_user-authentication.md
  - docs/plans/*/in-progress/PLAN_user-authentication.md
  - docs/plans/*/done/PLAN_user-authentication.md
```

**탐색 절차**:
1. 현재 브랜치 이름을 가져온다: `git branch --show-current`
2. 브랜치 이름에서 feature 이름을 추출한다 (예: `feature/user-authentication` → `user-authentication`)
3. `docs/plans/**/PLAN_{feature-name}.md` 패턴으로 플랜 문서를 검색한다 (Glob 도구 사용)
4. 플랜 문서가 발견되면:
   - 해당 파일을 Read로 읽어 내용을 파악한다
   - 플랜 문서 경로에서 도메인을 추출한다 (예: `docs/plans/user/ready/PLAN_*.md` → `user`)
5. 플랜 문서가 없으면:
   - 변경된 파일 경로에서 도메인을 추론한다 (예: `modules/domain/src/.../user/...` → `user`)
   - 도메인 추론이 불가하면 기본값 사용

**도메인 추출 우선순위**:
1. 플랜 문서 경로 (`docs/plans/<domain>/...`)
2. 변경 파일의 도메인 패턴 (`modules/*/src/**/domain/<domain>/...`)
3. 기본값: 브랜치 이름의 첫 번째 단어 또는 `general`

### Step 2: 4개 에이전트 병렬 실행

**반드시 단일 메시지에서 4개의 Task 도구를 동시에 호출하여 병렬 실행한다.**

각 에이전트에게 전달할 프롬프트에는 다음을 포함한다:
- 변경된 파일 목록 (`--name-status` 결과, diff 전문은 포함하지 않음)
- CLAUDE.md의 핵심 아키텍처 규칙
- 각 에이전트 역할에 맞는 리뷰 관점
- **(플랜 문서가 있는 경우)** 플랜 문서의 핵심 정보:
  - Feature Description (기능 설명)
  - Success Criteria (성공 기준)
  - Architecture Decisions (아키텍처 결정사항)
  - Test Strategy (테스트 전략)
  - 각 Phase의 Goal과 Tasks

**공통 검증 규칙 (모든 에이전트 프롬프트에 포함)**:
> **필수: diff가 아닌 최종 파일 상태 기반 리뷰**
> - 지적하기 전에 반드시 해당 파일을 Read 도구로 직접 읽어 **현재 최종 상태**를 확인하라.
> - diff에서 문제처럼 보여도, 최종 파일에서 이미 수정되었으면 지적하지 마라.
> - 여러 파일에 걸친 변경은 관련 파일들을 모두 Read로 확인한 후 판단하라.
> - diff는 변경 범위 파악용으로만 사용하고, 실제 리뷰는 최종 코드 기준으로 수행하라.
>
> **필수: 기존 코드 패턴 참조**
> - 변경된 파일과 같은 패키지 또는 같은 계층(controller, service, adapter 등)의 기존 파일을 1-2개 Read로 읽어 프로젝트의 기존 패턴을 파악하라.
> - 기존 패턴과 다른 방식으로 구현된 부분이 있으면, 일관성 관점에서 지적하라.
>
> **필수: 시행령 문서 참조**
> - 변경 파일이 해당 도메인에 속하면 관련 시행령 문서를 Read로 읽고 규칙을 적용하라:
>   - Consumer/이벤트 핸들러 → `docs/standards/messaging-policy.md`
>   - 시간 필드/Audit 컬럼 → `docs/standards/temporal-data-policy.md`
>   - 조회 기능/Repository → `docs/standards/query-pattern.md`
>   - 검증/예외 처리 → `docs/standards/validation-exception-policy.md`
>   - DB 마이그레이션 파일 → `docs/standards/db-migration-policy.md`
>
> **필수: 구체적 위치 명시 형식**
> - **파일 경로**: `modules/domain/src/main/.../UserService.kt`
> - **라인 번호**: `:42` (가능한 경우)
> - **함수/클래스명**: `UserService.createUser()`
> - **코드 스니펫**: 문제가 되는 실제 코드 3-5줄 인용
>
> 예시: "`modules/api/src/.../UserController.kt:35` — `createUser()` 함수에서 `CreateUserService`를 직접 의존하고 있음. UseCase 인터페이스(`CreateUserUseCase`)를 통해 주입해야 한다."
>
> 설명만으로 구성된 추상적 피드백은 금지한다. 모든 지적에는 파일:라인, 함수명, 코드 근거가 포함되어야 한다.
>
> **필수: 발견 사항 없음 처리**
> - 리뷰 결과 지적할 사항이 없으면 "발견 사항 없음"을 명시하고, 잘 지켜진 부분을 1-2줄로 요약하라.
>
> **필수: 심각도 기준**
> - **심각**: 런타임 오류, 데이터 손실, 보안 취약점, 아키텍처 규칙 명백한 위반 (반드시 수정)
> - **중간**: 유지보수성 저하, 컨벤션 불일치, 잠재적 버그, 테스트 누락 (수정 권장)
> - **낮음**: 코드 스타일, 가독성 개선, 더 나은 대안 존재 (선택적 개선)
>
> **조건부: 플랜 문서 기반 리뷰 (플랜 문서가 제공된 경우)**
> - 플랜 문서가 제공되면 구현이 플랜의 의도와 부합하는지 추가로 검토하라.
> - 플랜의 **Success Criteria**가 구현에서 충족되었는지 확인하라.
> - 플랜의 **Architecture Decisions**이 코드에 반영되었는지 확인하라.
> - 플랜의 **Test Strategy**에 명시된 테스트 범위가 구현되었는지 확인하라.
> - 플랜에서 벗어난 구현이 있으면 "플랜 불일치"로 지적하고 이유를 설명하라.

#### Agent 1: code-reviewer
- **관점**: 코드 품질, 보안, 유지보수성, 네이밍 컨벤션
- **CLAUDE.md 체크**: 가시성 규칙(internal), 네이밍 컨벤션, Zero-DTO 정책
- **프롬프트 핵심**: "변경된 파일을 읽고 코드 품질, 보안 취약점, 유지보수성을 리뷰하라. CLAUDE.md의 가시성 규칙(internal class), 네이밍 컨벤션(UseCase, Command, Result, Response), Zero-DTO 정책 준수 여부를 확인하라. 모든 지적은 파일경로:라인번호, 함수명, 실제 코드 스니펫과 함께 작성하라."

#### Agent 2: test-engineer
- **관점**: 테스트 커버리지, 테스트 품질, 누락된 테스트 시나리오
- **CLAUDE.md 체크**: 테스트 전략(Domain Unit, Application Service, Infrastructure Integration, ArchUnit)
- **프롬프트 핵심**: "변경된 파일과 관련 테스트 파일을 읽고 테스트 커버리지와 품질을 리뷰하라. CLAUDE.md의 테스트 전략(Domain Unit Test, Application Service Test, Infrastructure Integration Test) 준수 여부를 확인하라. 누락된 테스트를 지적할 때는 대상 파일경로, 클래스명, 함수명을 명시하고 어떤 시나리오가 빠졌는지 구체적으로 기술하라."

#### Agent 3: backend-architect
- **관점**: API 설계, 스키마 설계, 확장성, 성능
- **CLAUDE.md 체크**: Port 배치 원칙, CQS 분리, 트랜잭션 정책
- **프롬프트 핵심**: "변경된 파일을 읽고 API 설계, 데이터 모델, 확장성을 리뷰하라. CLAUDE.md의 Port 배치 원칙(Command Port → domain, Query Port → application), CQS 분리, 트랜잭션 정책 준수 여부를 확인하라. 설계 이슈 지적 시 관련 파일경로, 클래스/인터페이스명, 문제 코드를 인용하라."

#### Agent 4: architect-reviewer
- **관점**: 아키텍처 일관성, SOLID 원칙, 계층 분리, 의존성 방향
- **CLAUDE.md 체크**: Hexagonal Architecture, Double Model 전략, 의존성 방향, 도메인 공유 규칙
- **프롬프트 핵심**: "변경된 파일을 읽고 아키텍처 일관성과 계층 분리를 리뷰하라. CLAUDE.md의 Hexagonal Architecture, Double Model 전략(Domain ↔ JPA 분리), 의존성 방향(Infrastructure → Application → Domain), 도메인 공유 규칙(shared vs common) 준수 여부를 확인하라. 위반 사항마다 파일경로:라인번호, import문이나 의존 코드 스니펫을 근거로 제시하라."

### Step 3: 결과 통합 및 보고서 생성

4개 에이전트의 결과를 수집한 후, 아래 규칙에 따라 통합 보고서를 생성한다.

**중복 제거**: 여러 에이전트가 동일한 파일·동일한 이슈를 지적한 경우, 가장 구체적인 하나만 남기고 나머지는 제거한다. 조치 필요 항목 테이블에도 중복 없이 정리한다.

#### 리뷰 파일 경로 및 네이밍

**파일 경로**: `docs/{domain}/reviews/REVIEW_{name}.md`

- `{name}`: 플랜 파일명에서 추출한 이름 (또는 브랜치명에서 `feature/` prefix 제거)
- 도메인은 Step 1에서 추출한 값을 사용한다
- 디렉토리가 없으면 생성한다

**네이밍 일관성 예시**:
```
플랜 파일:   docs/plans/user/ready/PLAN_user-authentication.md
브랜치:     feature/user-authentication
리뷰 파일:   docs/user/reviews/REVIEW_user-authentication.md
```

**이름 추출 우선순위**:
1. 플랜 문서가 있으면 → 플랜 파일명에서 추출 (`PLAN_{name}.md` → `{name}`)
2. 플랜 문서가 없으면 → 브랜치명에서 추출 (`feature/{name}` → `{name}`)

**도메인 추출 실패 시 기본값**: `docs/reviews/REVIEW_{name}.md`

**보고서 형식**:

```markdown
# 브랜치 리뷰: {name}

**리뷰 일시**: YYYY-MM-DD
**이름**: `{name}` (예: `user-authentication`)
**브랜치**: `feature/{name}`
**도메인**: `{domain}`
**커밋 수**: N개
**변경 파일 수**: N개
**플랜 문서**: `docs/plans/{domain}/*/PLAN_{name}.md` 또는 없음

---

## 요약

### 전체 평가
[종합적인 코드 품질 평가 1-2문장]

### 플랜 준수 현황 (플랜 문서가 있는 경우)
| 항목 | 상태 | 비고 |
|------|------|------|
| Success Criteria 충족 | ✅/⚠️/❌ | [설명] |
| Architecture Decisions 반영 | ✅/⚠️/❌ | [설명] |
| Test Strategy 준수 | ✅/⚠️/❌ | [설명] |
| Phase Goals 달성 | ✅/⚠️/❌ | [설명] |

### CLAUDE.md 준수 현황
| 규칙 | 상태 | 비고 |
|------|------|------|
| Hexagonal Architecture | ✅/⚠️/❌ | [설명] |
| 가시성 규칙 (internal) | ✅/⚠️/❌ | [설명] |
| CQS 분리 | ✅/⚠️/❌ | [설명] |
| Double Model 전략 | ✅/⚠️/❌ | [설명] |
| Zero-DTO 정책 | ✅/⚠️/❌ | [설명] |
| 네이밍 컨벤션 | ✅/⚠️/❌ | [설명] |
| 시간 데이터 (Instant) | ✅/⚠️/❌ | [설명] |
| Port 배치 원칙 | ✅/⚠️/❌ | [설명] |

---

## 플랜 불일치 항목 (플랜 문서가 있는 경우)

> 이 섹션은 플랜 문서가 있을 때만 포함됩니다.

| # | 구분 | 플랜 내용 | 구현 현황 | 심각도 |
|---|------|----------|----------|--------|
| 1 | Success Criteria / Architecture / Test | 플랜에 명시된 내용 | 실제 구현 상태 | 심각/중간/낮음 |

---

## 상세 리뷰

### 1. 코드 품질 (code-reviewer)

#### 발견 사항
각 항목은 아래 형식을 따른다:
> **[심각도]** `파일경로:라인` — `클래스.함수()`
> ```kotlin
> // 문제 코드 스니펫 (3-5줄)
> ```
> **문제**: 구체적 설명
> **제안**: 수정 방향

### 2. 테스트 품질 (test-engineer)

#### 발견 사항
각 항목은 아래 형식을 따른다:
> **[누락/개선]** `대상 파일경로` — `클래스.함수()`
> **누락 시나리오**: 어떤 케이스가 테스트되지 않았는지
> **제안**: 추가할 테스트 설명

### 3. 백엔드 아키텍처 (backend-architect)

#### 발견 사항
각 항목은 아래 형식을 따른다:
> **[심각도]** `파일경로:라인` — `클래스/인터페이스명`
> ```kotlin
> // 관련 코드 스니펫
> ```
> **문제**: 설계 이슈 설명
> **제안**: 개선 방향

### 4. 아키텍처 일관성 (architect-reviewer)

#### 발견 사항
각 항목은 아래 형식을 따른다:
> **[위반/권장]** `파일경로:라인` — `클래스명`
> ```kotlin
> // 위반 근거 코드 (import문, 의존성 등)
> ```
> **위반 규칙**: CLAUDE.md 섹션 번호와 규칙명
> **제안**: 수정 방향

---

## 조치 필요 항목

| # | 심각도 | 분류 | 위치 (`파일:라인` — `함수명`) | 내용 | 상태 |
|---|--------|------|-------------------------------|------|------|
| 1 | 심각/중간/낮음 | 코드품질/테스트/아키텍처/플랜불일치 | `파일경로:라인` — `Class.method()` | 구체적 설명 | ⬜ |

> 분류: 코드품질, 테스트, 백엔드아키텍처, 아키텍처일관성, 플랜불일치

---

## 변경 파일 목록

| 상태 | 파일 |
|------|------|
| M/A/D | 파일경로 |
```

### Step 4: 결과 안내

보고서 생성 후 사용자에게 다음을 안내한다:
- 보고서 파일 경로
- 발견된 심각 이슈 수
- 조치 필요 항목 요약