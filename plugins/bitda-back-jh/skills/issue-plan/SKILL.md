---
name: issue-plan
description: GitHub 이슈 정보와 프로젝트 컨텍스트를 기반으로 TDD 기반 구현 계획서를 작성하여 이슈 댓글로 등록하는 스킬입니다. feature-planner와 유사하지만 결과물이 이슈 댓글로 저장됩니다. 이 스킬은 "/issue-plan", "/issue-plan #123", "이슈 계획", "계획서 작성" 등을 요청할 때 사용됩니다.
---

# Issue Plan

## Purpose

GitHub 이슈 정보와 프로젝트 컨텍스트를 기반으로 TDD 기반 구현 계획서를 작성하여
해당 이슈의 댓글로 등록한다.

---

## Enterprise Mindset (할거면 제대로 하자)

> **"할거면 제대로 하자"** — 이 스킬이 만드는 산출물은 단순히 "작동하는 코드"를 위한 메모가 아니다.
> **프로덕션 레디 엔터프라이즈 시스템**을 위한 구현 계획서다.

계획서 작성 시 다음 관점을 항상 견지한다:

| 관점 | 요구사항 |
|------|---------|
| **아키텍처** | CLAUDE.md 헌법 완전 준수 — Hexagonal Architecture, `internal` 가시성, CQS 원칙 |
| **테스트** | Unit → Integration → E2E 피라미드 완전 구현, 비즈니스 규칙은 반드시 Unit 테스트 |
| **보안** | 인증/인가(`@PreAuthorize`), 입력 검증(`@Valid`, `require()`), 취약점 분석 |
| **감사 로그** | 상태 변경 UseCase는 `AuditableEvent` 적용 여부 검토 (`audit-logging-policy.md`) |
| **데이터 정합성** | Flyway 마이그레이션 정책 준수, 낙관적 락(`@Version`), 트랜잭션 범위 최소화 |
| **운영** | 롤백 전략, 장애 시 영향 범위, 마이그레이션 역방향 지원 명시 |

> ⚠️ **"일단 돌아가게만" 하는 계획은 실패다.** Phase별 설계 결정에는 반드시 근거와 트레이드오프를 명시한다.

---

## References

계획서 작성 시 다음 상세 가이드를 참조한다:

| 문서 | 내용 |
|------|------|
| [tdd-workflow.md](references/tdd-workflow.md) | TDD 워크플로우, 테스트 전략, 테스트 패턴 |
| [quality-gate.md](references/quality-gate.md) | Quality Gate 표준, 검증 항목, Phase 전환 기준 |
| [plan-template.md](references/plan-template.md) | 계획서 템플릿 (GitHub 이슈 댓글용) |
| [production-pitfalls.md](references/production-pitfalls.md) | **생산 컴파일·매핑 함정** (R1~R4: Q엔티티 필드명·시간타입·상태 enum·엑셀 arch 상속). 생산 이슈 시 필수 |
| [production-archunit-pitfalls.md](references/production-archunit-pitfalls.md) | **생산 ArchUnit·네이밍 함정** (A1~A4: Qty 접미사·UseCase<T,R> 상속·동사 Initiate·Result 패키지). 가장 반복된 실패 |
| [production-domain-pitfalls.md](references/production-domain-pitfalls.md) | **생산 도메인·인프라·테스트 함정** (D1~D7: LOT 불변·flush 순서·silent failure·LEFT JOIN·테스트 동적일자·필드 리네임 동반수정) |

> **CRITICAL**: Step 4 계획서 작성 전 반드시 `plan-template.md`를 Read 도구로 읽어 전체 형식을 확인한다.

---

## Workflow

### Step 0: 이슈 번호 확인

이슈 번호를 다음 우선순위로 결정한다:

1. **인자로 전달된 경우**: `/issue-plan #123` → `#123`
2. **현재 브랜치에서 추출**: `issue/123-feature-name` → `#123`
3. **현재 워크트리 이름에서 추출**: `../worktrees/issue/123-feature-name` → `#123`
4. **사용자에게 질문**: 위 방법으로 확인 불가 시

### Step 1: 프로젝트 컨텍스트 로드 (MANDATORY)

**CRITICAL**: 플래닝 시작 전 반드시 프로젝트 컨텍스트를 로드한다.

1. **CLAUDE.md 읽기**: `CLAUDE.md` 파일을 Read 도구로 읽어서 전체 내용을 파악
2. **핵심 원칙 확인**: 아키텍처 핵심 원칙, 계층 구조, 네이밍 컨벤션 숙지
3. **관련 시행령 식별**: 기능과 관련된 시행령 문서(docs/standards/)가 있다면 함께 읽기
   - 메시징/이벤트 → `messaging-policy.md`
   - 시간 데이터 → `temporal-data-policy.md`
   - 조회 기능 → `query-pattern.md`
   - 검증/예외 → `validation-exception-policy.md`
   - DB 마이그레이션 → `db-migration-policy.md`
4. **E2E 테스트 헌법 확인**: 테스트 작성이 포함된 플랜이라면 §6.2 E2E 테스트 헌법 숙지

> ⚠️ 이 단계를 건너뛰면 프로젝트 아키텍처와 맞지 않는 플랜이 생성될 수 있습니다.

### Step 2: 이슈 정보 수집

```bash
gh issue view {issue-number} -R invigoworks/bitda-back --json title,body,labels
```

이슈의 다음 정보를 파악한다:
- 제목과 설명
- 요구사항 체크리스트
- 기술적 고려사항
- 완료 기준

### Step 3: 코드베이스 분석 (Enterprise-Grade)

1. **관련 파일 탐색**: 변경이 필요한 파일과 의존성 파악
2. **기존 패턴 파악**: 유사한 기능의 구현 방식 확인 — 코드베이스 내 best practice 적용
3. **복잡도 평가**: 리스크와 불확실성 식별
4. **Scope 결정**: Phase Sizing Guidelines 참조
5. **ADR 검토**: `docs/adr/` — 관련 아키텍처 결정 기록이 있으면 반드시 확인
6. **감사 로그 필요성 검토**: 상태 변경 UseCase라면 `audit-logging-policy.md` 적용 여부 판단
7. **보안 영향 분석**: 인가 정책(`@PreAuthorize`) 적용 범위, 외부 입력 검증 지점
8. **성능 고려사항**: N+1 쿼리 가능성, 인덱스 필요 여부, 대용량 데이터 처리 여부
9. **DB 마이그레이션 필요 여부**: 스키마 변경 시 `db-migration-policy.md` 준수 확인
10. **생산관리 도메인 함정 점검 (조건부)**: 이슈가 `modules/*/production*/*` 또는 생산계획/작업지시/생산입고/LOT/정정을 건드리면 **반드시 아래 3개 함정 문서를 Read로 로드**하여 해당 규칙을 각 Phase 플랜에 선반영한다. — 역대 생산 PR에서 `/jenkins-ci-loop`로 유출되던 반복 실패를 설계 단계에서 차단:
    - `references/production-pitfalls.md` (R1~R4: 컴파일·매핑)
    - `references/production-archunit-pitfalls.md` (A1~A4: ArchUnit·네이밍 — **가장 빈번**)
    - `references/production-domain-pitfalls.md` (D1~D7: LOT·flush·silent·JOIN·테스트)

### Step 4: 계획서 작성

**CRITICAL**: 계획서 작성 전 반드시 `references/plan-template.md`를 Read 도구로 읽어 전체 형식을 확인한다.

TDD 기반 Phase-by-Phase 계획서를 작성한다.

#### Phase 구조 (각 Phase 1-4시간)

각 Phase는 다음 TDD 사이클을 따른다:

1. **🔴 RED**: 테스트 먼저 작성
   - 테스트 파일 경로 명시
   - 테스트 시나리오 (Happy path, Edge cases, Error conditions)
   - Expected: Tests FAIL (red)

2. **🟢 GREEN**: 최소 구현
   - 소스 파일 경로 명시
   - 구현 내용 설명
   - Goal: Make tests pass with minimal code

3. **🔵 REFACTOR**: 리팩토링
   - DRY 원칙 적용
   - 네이밍 개선
   - 코드 품질 향상

4. **✅ Quality Gate**: Phase 완료 검증
   - `./gradlew build test ktlintCheck`
   - 상세 항목은 `references/quality-gate.md` 참조

#### 테스트 전략 (references/tdd-workflow.md 참조)

| 테스트 유형 | 커버리지 목표 | 용도 |
|------------|--------------|------|
| **Unit Tests** | ≥80% | 비즈니스 로직, 모델, 핵심 알고리즘 |
| **Integration Tests** | Critical paths | 컴포넌트 상호작용, 데이터 흐름 |
| **E2E Tests** | Key user flows | 전체 시스템 동작 검증 |

### Step 5: 사용자 승인 (CRITICAL)

**계획서를 이슈에 등록하기 전에 사용자 승인을 받는다.**

AskUserQuestion 도구를 사용하여 다음을 확인:
- "이 Phase 분할이 적절한가요?"
- "접근 방식에 우려 사항이 있나요?"
- "계획서를 이슈 댓글로 등록할까요?"

사용자가 승인한 후에만 계획서를 등록한다.

### Step 6: 이슈 댓글로 등록

```bash
gh issue comment {issue-number} --body "$(cat <<'EOF'
{계획서 내용}
EOF
)" -R invigoworks/bitda-back
```

### Step 7: 이슈 라벨 업데이트

계획서 작성 완료 후 이슈에 `in-progress` 라벨을 추가한다:

```bash
gh issue edit {issue-number} --add-label "in-progress" -R invigoworks/bitda-back
```

### Step 8: 결과 보고

```
✅ 계획서가 이슈 #{issue-number} 댓글로 등록되었습니다.

- Phases: {N}개
- 예상 시간: {X}시간
- Scope: Small/Medium/Large

다음 단계:
- `/issue-impl #{issue-number}` 으로 구현 시작
```

---

## Phase Sizing Guidelines

| Scope | Phases | 총 시간 | 적용 상황 |
|-------|--------|--------|----------|
| **Small** | 2-3개 | 3-6시간 | 단일 컴포넌트, 간단한 기능 |
| **Medium** | 4-5개 | 8-15시간 | 여러 컴포넌트, DB 변경 포함 |
| **Large** | 6-7개 | 15-25시간 | 복잡한 기능, 다중 통합 |

### Scope 예시

**Small**: Dark mode toggle, 새 form component, 필드 validation 추가
**Medium**: 사용자 인증 시스템, 검색 기능, 새 Entity CRUD
**Large**: AI 기반 검색, 실시간 협업, 복잡한 리포팅 시스템

---

## Risk Assessment

식별하고 문서화할 리스크:

- **Technical Risks**: API 변경, 성능 이슈, 데이터 마이그레이션
- **Dependency Risks**: 외부 라이브러리 업데이트, 서드파티 서비스 가용성
- **Timeline Risks**: 복잡도 불확실성, 블로킹 의존성
- **Quality Risks**: 테스트 커버리지 갭, 회귀 가능성

각 리스크에 대해:
- **Probability**: Low/Medium/High
- **Impact**: Low/Medium/High
- **Mitigation Strategy**: 구체적인 조치 단계

---

## Rollback Strategy

각 Phase에 대해 롤백 방법을 문서화:

- 어떤 코드 변경을 되돌려야 하는지
- 데이터베이스 마이그레이션 롤백 (해당되는 경우)
- 설정 변경 복원
- 의존성 제거

---

## CLI Reference

```bash
# 이슈 조회
gh issue view {number} -R owner/repo --json title,body,labels

# 이슈에 댓글 추가
gh issue comment {number} --body "댓글 내용" -R owner/repo

# 이슈 라벨 추가
gh issue edit {number} --add-label "label" -R owner/repo

# 현재 브랜치 확인
git branch --show-current

# 워크트리 목록
git worktree list
```
