---
name: issue-impl
description: GitHub 이슈와 계획서 댓글을 기반으로 TDD 워크플로우로 구현을 수행하는 스킬입니다. main에서 새 워크트리와 브랜치를 생성하고, 진행 상황을 이슈 댓글로 업데이트합니다. 이 스킬은 "/issue-impl", "/issue-impl #123", "이슈 구현", "구현 시작" 등을 요청할 때 사용됩니다.
---

# Issue Impl

## Purpose

GitHub 이슈와 계획서 댓글을 기반으로 TDD 워크플로우로 Phase-by-Phase 구현을 수행한다.
main에서 새 워크트리와 브랜치를 생성하고, 진행 상황을 이슈 댓글로 업데이트한다.

## ⚡ Auto-Proceed Policy

**이 스킬은 완전 자동 모드로 동작한다.** 다음 행위에 대해 사용자 확인을 묻지 않고 즉시 실행한다:

- 파일 생성, 수정, 삭제
- 다음 페이즈 진행
- 워크트리/브랜치 재개
- ktlintFormat 등 자동 수정
- 진행 상황 댓글 업데이트

**사용자에게 질문하는 경우는 오직**:
- Quality gate가 2회 연속 실패했을 때
- 계획서에 명시되지 않은 모호한 비즈니스 요구사항이 있을 때

## Workflow

### Step 0: 이슈 번호 확인

이슈 번호를 다음 우선순위로 결정한다:

1. **인자로 전달된 경우**: `/issue-impl #123` → `#123`
2. **현재 브랜치에서 추출**: `issue/123-feature-name` → `#123`
3. **현재 워크트리 이름에서 추출**: `../worktrees/issue/123-feature-name` → `#123`
4. **사용자에게 질문**: 위 방법으로 확인 불가 시

### Step 1: 프로젝트 컨텍스트 로드 (MANDATORY)

**CRITICAL**: 구현 시작 전 반드시 프로젝트 컨텍스트를 로드한다.

1. **CLAUDE.md 읽기**: 아키텍처 핵심 원칙, 계층 구조, 네이밍 컨벤션 숙지
2. **관련 시행령 확인**: 기능과 관련된 시행령 문서(docs/standards/) 읽기
3. **E2E 테스트 헌법**: 테스트 작성 시 §6.2 헌법 준수
4. **테스트 레벨 결정** (CLAUDE.md §6.1): 테스트 작성 전 아래 결정 트리를 반드시 따른다

#### 테스트 레벨 결정 트리

새 테스트 작성 전 반드시 확인:

1. `@Valid`/입력 검증(400)인가? → **Controller 단위 테스트** (standaloneSetup)
2. 단순 404/빈 결과인가? → **Controller 단위 테스트** (mock)
3. 필터/정렬/페이지네이션 파라미터 바인딩인가? → **Controller 단위 테스트**
4. `@PreAuthorize` 권한 검증(403)인가? → **ArchUnit 정적 검사** (E2E 금지)
5. DB 관통이 반드시 필요한가? (CRUD 관통, Unique/FK, 테넌트 격리, 상태 전이, 벌크 트랜잭션, Import/Export, 감사 로그) → **E2E Test**, 도메인당 5-10개 제한
6. 위 어디에도 해당하지 않으면 → **Unit Test**

> ⚠️ `SecurityE2ESupport` (Track B) 상속은 금지한다. `@PreAuthorize` 검증은 ArchUnit으로 대체한다 (#1339).

### Step 2: 이슈 및 계획서 수집

```bash
# 이슈 정보 조회
gh issue view {issue-number} -R invigoworks/bitda-back --json title,body,labels,comments
```

이슈 댓글에서 `## 📋 구현 계획서`로 시작하는 계획서를 찾아 파싱한다.

**계획서가 없는 경우**: 사용자에게 `/issue-plan #{issue-number}` 실행을 안내한다.

### Step 3: 워크트리 & 브랜치 설정

이슈 번호와 제목에서 브랜치 이름을 생성한다.

**네이밍 규칙**:
```
Issue #123: 사용자 로그인 기능 구현
           └─────────┬────────────┘
                     ↓
Branch:    issue/123-user-login
Worktree:  ../worktrees/issue/123-user-login
```

**Procedure**:

1. **(CRITICAL) main 브랜치 최신화**:
   ```bash
   git fetch origin main
   git checkout main
   git pull origin main
   ```
   > ⚠️ 이 단계를 건너뛰면 최신 코드 없이 작업하게 되어 충돌 및 Out of Order 문제 발생

2. 이슈 제목에서 슬러그 생성 (한글 → 영문 변환 또는 핵심 키워드 추출)
3. 브랜치 이름 결정: `issue/{number}-{slug}`

4. **기존 워크트리/브랜치 확인 (Resume 시나리오)**:
   ```bash
   git worktree list
   git branch --list "issue/{number}-*"
   ```

5. **신규 생성**:
   ```bash
   git worktree add -b issue/{number}-{slug} ../worktrees/issue/{number}-{slug} main
   ```

6. **이미 존재 시**:
   - 워크트리로 이동 후 main 변경사항 rebase:
     ```bash
     cd ../worktrees/issue/{number}-{slug}
     git fetch origin main
     git rebase origin/main
     ```
   - 자동으로 해당 워크트리에서 재개 (확인 불필요)

7. 이후 모든 파일 작업은 워크트리 경로에서 수행

### Step 4: Phase 실행

계획서의 Phase를 **순차적으로** 실행한다.

#### 4a. Phase 시작 알림

사용자에게 현재 Phase 정보를 알린다.

#### 4b. TDD 순서로 태스크 실행

1. **🔴 RED Tasks**: 테스트 먼저 작성
   - 테스트 파일 생성
   - 테스트 실행하여 실패 확인 (expected)

2. **🟢 GREEN Tasks**: 최소 구현
   - 테스트를 통과하는 최소한의 코드 작성
   - 테스트 실행하여 통과 확인

3. **🔵 REFACTOR Tasks**: 리팩토링
   - 코드 품질 개선
   - 테스트가 계속 통과하는지 확인

#### 4c. Quality Gate 검증 (Incremental)

> **효율성 원칙**: Phase별 검증은 **해당 Phase에서 수정한 모듈** 단위로 테스트한다. Gradle Build Cache가 변경되지 않은 태스크를 자동 스킵하므로, 모듈 단위 실행으로도 충분히 빠르다.

**수정된 모듈 테스트 실행**:
```bash
# 수정된 모듈의 테스트 실행 (예시)
./gradlew :modules:application:core:test

# ktlintCheck는 전체 실행 (빠름)
./gradlew ktlintCheck
```

**테스트 범위 결정 기준**:
- 해당 Phase에서 생성/수정한 **모듈 단위**로 테스트 실행
- 여러 모듈을 수정한 경우 해당 모듈들을 모두 포함
- 컴파일 에러는 `./gradlew classes testClasses`로 빠르게 확인
- Step 5의 `./gradlew build`에서 의존 모듈 포함 전체 regression 검증

| Check | Result |
|-------|--------|
| Compile | ✅ / ❌ |
| ktlintCheck | ✅ / ❌ |
| Phase Tests | ✅ / ❌ (N passed, M failed) |

#### 4d. 이슈 댓글로 진행 상황 업데이트

각 Phase 완료 시 이슈에 진행 상황 댓글을 추가한다:

```bash
gh issue comment {issue-number} --body "{진행 상황}" -R invigoworks/bitda-back
```

**진행 상황 댓글 형식**:
```markdown
## ✅ Phase 1 완료

**완료 시간**: YYYY-MM-DD HH:MM
**Quality Gate**: ✅ All Passed

### 완료된 작업
- [x] `UserService.kt` 생성
- [x] `UserServiceTest.kt` 테스트 추가

### 다음 Phase
Phase 2: Core Feature 진행 중...
```

**문제 발생 시 댓글 형식**:
```markdown
## ⚠️ Phase 2 진행 중 문제 발생

**발생 시간**: YYYY-MM-DD HH:MM

### 문제 내용
{문제 설명}

### 시도한 해결 방법
1. {시도 1}
2. {시도 2}

### 현재 상태
{블로킹 여부, 다음 조치 등}
```

#### 4e. Phase 전환

Quality gate 통과 시:
- Phase 완료 댓글 등록
- **즉시 다음 Phase로 진행** (확인 불필요)

Quality gate 실패 시:
- 자동 수정 시도 (예: `ktlintFormat`)
- 재검증
- 2회 실패 시 사용자에게 질문

### Step 5: 완료 (Full Verification)

모든 Phase 완료 후:

1. **전체 검증** (MANDATORY)
   ```bash
   ./gradlew build
   ```
   > ⚠️ `clean` 없이 실행하여 Gradle Build Cache + Incremental Compilation을 활용한다. 변경되지 않은 모듈은 UP-TO-DATE로 스킵되어 빌드 시간이 대폭 단축된다. Phase별 incremental 테스트에서 놓친 regression은 의존성 그래프를 통해 자동 감지된다.

2. 계획서 댓글의 체크박스 업데이트 (편집 가능한 경우)

3. 완료 댓글 등록:
   ```markdown
   ## 🎉 구현 완료

   **완료 시간**: YYYY-MM-DD HH:MM
   **브랜치**: `issue/{number}-{slug}`

   ### 완료된 Phase
   - [x] Phase 1: Foundation
   - [x] Phase 2: Core Feature
   - [x] Phase 3: Integration

   ### Quality Gate 최종 결과 (Clean Build)
   - `./gradlew build`: ✅
   - Tests: ✅ (N passed)
   - ktlintCheck: ✅

   ### 다음 단계
   - `/issue-pr #{issue-number}` 로 PR 생성
   ```

4. 사용자에게 다음 단계 안내

## Resume Protocol

워크트리와 브랜치가 이미 존재하는 경우:

1. 기존 워크트리 감지: `git worktree list`
2. **(CRITICAL) main 최신화 후 rebase**:
   ```bash
   cd ../worktrees/issue/{number}-{slug}
   git fetch origin main
   git rebase origin/main
   ```
   > ⚠️ 충돌 발생 시 해결 후 `git rebase --continue`
3. 이슈 댓글에서 마지막 진행 상황 확인
4. 계획서에서 미완료 Phase 식별
5. **자동으로 해당 지점에서 재개** (확인 불필요)
6. 재개 중인 Phase 정보만 간략히 알림

## Error Handling

| 시나리오 | 조치 |
|----------|------|
| Build 실패 | 에러 출력, 수정 시도, 재실행 |
| Test 실패 | 실패 테스트 상세 표시, 수정 구현 |
| ktlintCheck 실패 | `./gradlew ktlintFormat` 자동 실행, 재검증 |
| 워크트리 충돌 | 재사용 또는 재생성 사용자 선택 |
| 계획서 없음 | `/issue-plan` 실행 안내 |

## Conventions

- CLAUDE.md의 모든 규칙 준수 (Hexagonal Architecture, CQS, 네이밍 컨벤션 등)
- 모든 구현 클래스는 `internal` 가시성
- 도메인 모델은 순수 코틀린 (JPA 어노테이션 금지)
- 시간 필드는 `Instant`, DB 컬럼은 `TIMESTAMPTZ`
- 테스트는 프로젝트의 기존 패턴 준수

## CLI Reference

```bash
# main 브랜치 최신화 (작업 시작 전 필수)
git fetch origin main
git checkout main
git pull origin main

# 기존 브랜치에서 main 변경사항 rebase (재개 시)
git fetch origin main
git rebase origin/main

# 이슈 조회 (댓글 포함)
gh issue view {number} -R owner/repo --json title,body,labels,comments

# 이슈에 댓글 추가
gh issue comment {number} --body "댓글 내용" -R owner/repo

# 워크트리 목록
git worktree list

# 워크트리 생성
git worktree add -b {branch} {path} main

# 워크트리 제거
git worktree remove {path}
```
