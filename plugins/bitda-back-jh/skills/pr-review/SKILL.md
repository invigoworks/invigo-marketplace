---
name: pr-review
description: Pull Request를 4개 전문 에이전트(code-reviewer, test-engineer, backend-architect, architect-reviewer)로 병렬 리뷰하고, 결과를 PR 댓글로 누적 등록하는 스킬입니다. CLAUDE.md 아키텍처 규칙 준수 여부를 검증합니다. 이 스킬은 "/pr-review", "/pr-review #123", "PR 리뷰", "코드 리뷰" 등을 요청할 때 사용됩니다.
---

# PR Review

## Purpose

Pull Request를 4개 전문 에이전트로 병렬 리뷰하고,
CLAUDE.md 아키텍처 규칙 준수 여부를 포함한 리뷰 결과를 PR 댓글로 **누적** 등록한다.
(매 리뷰마다 새 댓글 추가 — 히스토리 보존)

## Workflow

### Step 0: PR 번호 확인

PR 번호를 다음 우선순위로 결정한다:

1. **인자로 전달된 경우**: `/pr-review #123` → `#123`
2. **현재 브랜치의 PR 조회**:
   ```bash
   gh pr view --json number -q '.number'
   ```
3. **사용자에게 질문**: 위 방법으로 확인 불가 시

### Step 1: PR 정보 및 변경사항 수집

```bash
# PR 정보 조회
gh pr view {pr-number} -R invigoworks/bitda-back --json title,body,baseRefName,headRefName,files,commits

# 변경 파일 목록
gh pr diff {pr-number} -R invigoworks/bitda-back --name-only
```

수집 항목:
- PR 제목, 본문
- 변경된 파일 목록
- 커밋 이력
- 연결된 이슈 번호 (있는 경우)

### Step 1.5: Flyway 마이그레이션 버전 충돌 검사

PR에 Flyway 마이그레이션 파일이 포함된 경우, main 브랜치와의 버전 충돌 가능성을 검사한다.

#### 1.5.1 마이그레이션 파일 확인

```bash
# PR에 포함된 마이그레이션 파일 목록
gh pr view {pr-number} -R invigoworks/bitda-back --json files -q '.files[].path' | grep -E 'db/migration/V[0-9]+__.*\.sql$'
```

마이그레이션 파일이 없으면 이 단계를 건너뛴다.

#### 1.5.2 main 브랜치 최신 버전 확인

```bash
# main 브랜치의 최신 마이그레이션 버전 조회
git fetch origin main
git ls-tree -r origin/main --name-only | grep -E 'db/migration/V[0-9]+__.*\.sql$' | sort -V | tail -1
```

#### 1.5.3 버전 충돌 판정

**충돌 조건**: PR의 마이그레이션 버전 ≤ main의 최신 버전

```
예시:
- main 최신: V20260220003
- PR 포함: V20260219001  ← 충돌! (Out of Order 발생 예정)
```

#### 1.5.4 검사 결과 저장

검사 결과를 저장하여 Step 5 리뷰 결과에 포함한다:

| 상태 | 설명 |
|------|------|
| `migration_conflict: true` | 버전 충돌 감지됨 |
| `migration_conflict: false` | 충돌 없음 |
| `migration_files: []` | 마이그레이션 파일 없음 (검사 스킵) |

### Step 2: 이전 리뷰 확인 (재리뷰 감지)

PR 댓글에서 이전 `## 🔍 PR 리뷰 결과` 댓글을 검색한다:

```bash
gh pr view {pr-number} -R invigoworks/bitda-back --json comments
```

**이전 리뷰가 있으면**:
- 마지막 리뷰의 `조치 필요 항목` 테이블 파싱
- `⬜` 상태 항목 → 이전 미조치 항목
- 현재 리뷰 차수 = 이전 차수 + 1

### Step 3: 프로젝트 컨텍스트 로드

1. **CLAUDE.md 읽기**: 아키텍처 핵심 원칙 파악
2. **관련 시행령 확인**: 변경 파일에 해당하는 시행령 문서

### Step 4: 4개 에이전트 병렬 실행

**반드시 단일 메시지에서 4개의 Task 도구를 동시에 호출하여 병렬 실행한다.**

#### 공통 프롬프트 규칙

모든 에이전트에게 다음 규칙을 전달한다:

> **⛔ 필수: 로컬 `./gradlew` 절대 실행 금지**
> - 너는 read-only 리뷰어다. 컴파일·테스트·빌드 확인을 위해 **로컬에서 `./gradlew`를 절대 실행하지 마라.**
> - 로컬 Gradle은 데몬이 잔존하여 시스템을 느리게 만든다 (full-cycle 파이프라인이 멈춘 주 원인).
> - 빌드/테스트 정합성은 Jenkins CI 단계(`jenkins-ci-loop`)가 원격에서 검증한다. 리뷰는 코드를 컴파일하지 않는다.
> - 빌드 검증이 꼭 필요하다고 판단되면 직접 실행하지 말고 "원격 빌드 검증 권장" 항목으로 보고만 하라.
>
> **필수: diff가 아닌 최종 파일 상태 기반 리뷰**
> - 지적하기 전에 반드시 해당 파일을 Read 도구로 직접 읽어 **현재 최종 상태**를 확인하라.
> - 모든 지적에는 파일:라인, 함수명, 코드 근거가 포함되어야 한다.
>
> **필수: 심각도 기준**
> - **심각**: 런타임 오류, 데이터 손실, 보안 취약점 (반드시 수정)
> - **중간**: 유지보수성 저하, 컨벤션 불일치, 테스트 누락 (수정 권장)
> - **낮음**: 코드 스타일, 가독성 개선 (선택적 개선)
>
> **조건부: 재리뷰 모드**
> - 이전 미조치 항목의 수정 여부를 확인하라.
> - 수정됨 → `✅ 해결됨`, 미수정 → `⬜ 미해결`
>
> **조건부: 생산관리 도메인 함정 점검**
> - 변경 파일이 `modules/*/production*/*` 또는 생산계획/작업지시/생산입고/LOT/정정을 건드리면,
>   아래 함정 문서의 탐지 규칙(grep 가능)을 체크리스트로 적용하라. 위반 발견 시 심각도와 함께 보고:
>   - `.claude/skills/issue-plan/references/production-pitfalls.md` (R1~R4: Q엔티티 필드명·시간타입·상태 enum·엑셀 arch 상속)
>   - `.claude/skills/issue-plan/references/production-archunit-pitfalls.md` (A1~A4: Qty 접미사·UseCase<T,R> 상속·동사 Initiate·Result 패키지)
>   - `.claude/skills/issue-plan/references/production-domain-pitfalls.md` (D1~D7: LOT 불변·cancel→flush·silent 금지·LEFT JOIN·테스트 동적일자·필드 리네임 동반수정)
> - 단, 너는 read-only다. 탐지 grep을 직접 실행해 위반 여부만 확인하고, 컴파일/빌드는 하지 마라.

#### Agent 1: code-reviewer
- **관점**: 코드 품질, 보안, 유지보수성, 네이밍 컨벤션
- **CLAUDE.md 체크**: 가시성 규칙(internal), 네이밍 컨벤션, Zero-DTO 정책

#### Agent 2: test-engineer
- **관점**: 테스트 커버리지, 테스트 품질, 누락된 테스트 시나리오
- **CLAUDE.md 체크**: 테스트 전략(Domain Unit, Integration, E2E)

#### Agent 3: backend-architect
- **관점**: API 설계, 스키마 설계, 확장성, 성능
- **CLAUDE.md 체크**: Port 배치 원칙, CQS 분리, 트랜잭션 정책

#### Agent 4: architect-reviewer
- **관점**: 아키텍처 일관성, SOLID 원칙, 계층 분리, 의존성 방향
- **CLAUDE.md 체크**: Hexagonal Architecture, Double Model 전략

### Step 5: 결과 통합 및 리뷰 댓글 생성

4개 에이전트 결과를 수집하여 통합 리뷰 댓글을 생성한다.

**중복 제거**: 동일한 파일·동일한 이슈는 가장 구체적인 하나만 남긴다.

**리뷰 댓글 형식**:

```markdown
## 🔍 PR 리뷰 결과

**리뷰 일시**: YYYY-MM-DD HH:MM (N차 리뷰)
**PR**: #{pr-number}
**변경 파일 수**: N개
**커밋 수**: N개

---

### 📊 요약

**전체 평가**: {종합 평가 1-2문장}

### CLAUDE.md 준수 현황
| 규칙 | 상태 |
|------|------|
| Hexagonal Architecture | ✅/⚠️/❌ |
| 가시성 규칙 (internal) | ✅/⚠️/❌ |
| CQS 분리 | ✅/⚠️/❌ |
| 네이밍 컨벤션 | ✅/⚠️/❌ |

### Flyway 마이그레이션 검사 (해당 시에만)

> 마이그레이션 파일이 없으면 이 섹션 생략

| 항목 | 값 |
|------|-----|
| PR 마이그레이션 | `V20260219001__xxx.sql`, `V20260219002__yyy.sql` |
| main 최신 버전 | `V20260220003` |
| 버전 충돌 | ⚠️ **Out of Order 발생 예정** / ✅ 정상 |

> ⚠️ 충돌 시: `/pr-merge` 실행 시 자동 버전 조정이 제안됩니다.

---

### 🔎 상세 리뷰

#### 1. 코드 품질 (code-reviewer)
{발견 사항 또는 "발견 사항 없음"}

#### 2. 테스트 품질 (test-engineer)
{발견 사항 또는 "발견 사항 없음"}

#### 3. 백엔드 아키텍처 (backend-architect)
{발견 사항 또는 "발견 사항 없음"}

#### 4. 아키텍처 일관성 (architect-reviewer)
{발견 사항 또는 "발견 사항 없음"}

---

### 이전 리뷰 대비 개선 사항 (재리뷰 시에만)

| # | 이전 지적 | 조치 결과 |
|---|----------|----------|
| 1 | {이전 지적} | ✅ 해결됨 / ⬜ 미해결 |

---

### 📋 조치 필요 항목

| # | 심각도 | 분류 | 위치 | 내용 | 상태 | 비고 |
|---|--------|------|------|------|------|------|
| 1 | 심각 | 코드품질 | `파일:라인` | 설명 | ⬜ | N차 신규 |

> 분류: 코드품질, 테스트, 백엔드아키텍처, 아키텍처일관성

---

🤖 Reviewed by [Claude Code](https://claude.com/claude-code)
```

### Step 6: PR에 리뷰 댓글 등록

```bash
gh pr comment {pr-number} --body "{리뷰 결과}" -R invigoworks/bitda-back
```

**중요**: 기존 댓글을 수정하지 않고 새 댓글로 추가한다 (히스토리 보존).

### Step 7: 결과 보고

```
✅ PR 리뷰가 완료되었습니다.

| 항목 | 결과 |
|------|------|
| PR | #{pr-number} |
| 리뷰 차수 | N차 |
| 심각 이슈 | X건 |
| 중간 이슈 | Y건 |
| 낮음 이슈 | Z건 |

{이전 리뷰 대비 개선 사항 요약 - 재리뷰 시}

리뷰 댓글이 PR에 등록되었습니다.
```

## 재리뷰 시 동작

1. 이전 리뷰 댓글의 `조치 필요 항목` 테이블 파싱
2. 각 항목의 현재 수정 여부 확인
3. 새 발견 + 이전 미해결 항목 통합
4. 비고에 차수 정보 기록:
   - `N차 신규`: 이번 리뷰에서 새로 발견
   - `N차에서 해결`: 이전 지적이 해결됨
   - `1차 미조치 유지`: 이전 지적이 아직 미해결

## CLI Reference

```bash
# PR 정보 조회
gh pr view {number} -R owner/repo --json title,body,files,commits,comments

# PR diff (파일 목록만)
gh pr diff {number} -R owner/repo --name-only

# PR 변경 파일 중 마이그레이션 파일 확인
gh pr view {number} -R owner/repo --json files -q '.files[].path' | grep -E 'db/migration/V[0-9]+__.*\.sql$'

# main 브랜치 최신 마이그레이션 버전 조회
git fetch origin main && git ls-tree -r origin/main --name-only | grep -E 'db/migration/V[0-9]+__.*\.sql$' | sort -V | tail -1

# PR에 댓글 추가
gh pr comment {number} --body "댓글" -R owner/repo

# 현재 브랜치의 PR 조회
gh pr view --json number -q '.number'
```
