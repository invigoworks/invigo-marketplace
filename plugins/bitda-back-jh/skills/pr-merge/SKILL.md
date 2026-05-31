---
name: pr-merge
description: PR을 squash merge하고 워크트리/브랜치를 정리한 후 이슈를 종결하는 스킬입니다. PR 병합, 로컬/원격 브랜치 삭제, 워크트리 제거, 이슈 종결 및 in-progress 라벨 제거를 수행합니다. 이 스킬은 "/pr-merge", "/pr-merge #123", "PR 병합", "머지" 등을 요청할 때 사용됩니다.
---

# PR Merge

## Purpose

PR을 squash merge하고 관련 리소스(워크트리, 브랜치)를 정리한 후 이슈를 종결한다.
issue 워크플로우의 마지막 단계로, `/pr-review` 완료 후 실행한다.

## Workflow

### Step 0: PR 번호 확인

PR 번호를 다음 우선순위로 결정한다:

1. **인자로 전달된 경우**: `/pr-merge #123` → PR `#123`
2. **현재 브랜치의 PR 조회**:
   ```bash
   gh pr view --json number -q '.number' -R invigoworks/bitda-back
   ```
3. **사용자에게 질문**: 위 방법으로 확인 불가 시

### Step 1: PR 및 이슈 정보 수집

```bash
# PR 정보 조회
gh pr view {pr-number} -R invigoworks/bitda-back --json number,title,state,mergeable,mergeStateStatus,headRefName,body

# PR 본문에서 연결된 이슈 번호 추출 (Closes #123 패턴)
# body에서 "Closes #(\d+)" 패턴 파싱

# 연결된 이슈의 라벨 조회 (커밋 타입 결정용)
gh issue view {issue-number} -R invigoworks/bitda-back --json labels -q '.labels[].name'
```

수집 항목:
- PR 상태 (OPEN/MERGED/CLOSED)
- 병합 가능 여부 (mergeable)
- 병합 상태 (mergeStateStatus: CLEAN, BLOCKED, etc.)
- head 브랜치 이름
- 연결된 이슈 번호
- **이슈 라벨** (커밋 타입 결정용, `api-change` 라벨 확인)

```bash
# PR 변경 파일 목록 조회 (API 변경 감지용)
gh pr view {pr-number} -R invigoworks/bitda-back --json files -q '.files[].path'
```

**API 변경 감지 조건** (하나라도 해당되면 `api_changed=true`):
1. 이슈에 `api-change` 라벨 존재
2. 변경 파일 중 Controller 파일 포함 (`*Controller.kt`)
3. 변경 파일 중 API DTO 파일 포함 (`*/api/*/dto/*.kt`)

### Step 2: 병합 전 검증

다음 조건을 확인한다:

| 검증 항목 | 조건 | 실패 시 |
|----------|------|---------|
| PR 상태 | `state == "OPEN"` | 이미 병합/종료됨 알림 |
| 병합 가능 | `mergeable == "MERGEABLE"` | 충돌 해결 안내 |
| 병합 상태 | `mergeStateStatus == "CLEAN"` | CI 실패/리뷰 필요 안내 |

**검증 실패 시**:
- 구체적인 문제점 설명
- 해결 방법 안내
- 스킬 종료

### Step 2.5: Flyway 마이그레이션 버전 충돌 검사

PR에 Flyway 마이그레이션 파일이 포함된 경우, main 브랜치와의 버전 충돌을 검사하고 필요시 자동 조정한다.

#### 2.5.1 마이그레이션 파일 확인

```bash
# PR에 포함된 마이그레이션 파일 목록
gh pr view {pr-number} -R invigoworks/bitda-back --json files -q '.files[].path' | grep -E 'db/migration/V[0-9]+__.*\.sql$'
```

마이그레이션 파일이 없으면 이 단계를 건너뛴다.

#### 2.5.2 main 브랜치 최신 버전 확인

```bash
# main 브랜치의 최신 마이그레이션 버전 조회
git fetch origin main
git ls-tree -r origin/main --name-only | grep -E 'db/migration/V[0-9]+__.*\.sql$' | sort -V | tail -1

# 버전 번호 추출 (예: V20260220003__xxx.sql → 20260220003)
```

#### 2.5.3 버전 충돌 판정

**충돌 조건**: PR의 마이그레이션 버전 ≤ main의 최신 버전

```
예시:
- main 최신: V20260220003
- PR 포함: V20260219001  ← 충돌! (Out of Order 발생 예정)
```

#### 2.5.4 충돌 시 자동 조정

**충돌이 감지되면**:

1. **새 버전 번호 계산**:
   - main 최신 버전의 날짜 부분 확인
   - 오늘 날짜가 더 최신이면: `V{오늘날짜}001`부터 시작
   - 같은 날짜면: 최신 시퀀스 + 1

2. **사용자에게 알림 및 확인**:
   ```
   ⚠️ Flyway 마이그레이션 버전 충돌 감지

   | 항목 | 값 |
   |------|-----|
   | main 최신 버전 | V20260220003 |
   | PR 마이그레이션 | V20260219001__create_xxx.sql |
   | 상태 | Out of Order 발생 예정 |

   **자동 조정 제안**:
   - 변경 전: V20260219001__create_xxx.sql
   - 변경 후: V20260221001__create_xxx.sql

   버전을 자동 조정하시겠습니까?
   1. 예 - 자동 조정 후 병합 진행
   2. 아니오 - 그대로 병합 (Out of Order 허용)
   3. 취소 - 병합 중단
   ```

3. **자동 조정 실행** (사용자가 "예" 선택 시):
   ```bash
   # PR 브랜치 체크아웃
   git fetch origin {head-branch}
   git checkout {head-branch}

   # 파일 이름 변경
   git mv modules/infrastructure/src/main/resources/db/migration/V20260219001__create_xxx.sql \
          modules/infrastructure/src/main/resources/db/migration/V20260221001__create_xxx.sql

   # 커밋 & 푸시
   git commit -m "chore: Flyway 마이그레이션 버전 조정 (V20260219001 → V20260221001)"
   git push origin {head-branch}
   ```

4. **CI 완료 대기**:
   - 버전 조정 후 CI가 다시 실행됨
   - CI 통과 확인 후 병합 단계로 진행

#### 2.5.5 여러 파일 충돌 시

PR에 여러 마이그레이션 파일이 있고 모두 충돌하는 경우:

```bash
# 충돌 파일들을 순서대로 재조정
V20260219001__xxx.sql → V20260221001__xxx.sql
V20260219002__yyy.sql → V20260221002__yyy.sql
V20260219003__zzz.sql → V20260221003__zzz.sql
```

상대적 순서는 유지하면서 새 날짜 기준으로 재배치한다.

### Step 2.7: main rebase (병렬 작업 순서 보장)

> **병렬 작업 환경에서 필수**: 다른 PR이 먼저 main에 머지되었을 경우, rebase 없이 머지하면 커밋 순서가 꼬이거나 충돌이 발생할 수 있다.

#### 2.7.1 main과의 차이 확인

```bash
git fetch origin main
git log origin/main..origin/{head-branch} --oneline  # PR 브랜치의 ahead 커밋
git log origin/{head-branch}..origin/main --oneline  # main의 ahead 커밋 (rebase 필요 여부)
```

main에 새 커밋이 있으면 rebase를 진행한다.

#### 2.7.2 워크트리에서 rebase 실행

```bash
# 워크트리 경로로 이동
cd {worktree-path}  # 예: .claude/worktrees/issue/1234-xxx

# main 최신화 후 rebase
git fetch origin main
git rebase origin/main

# 충돌 없으면 force push
git push --force-with-lease origin {head-branch}
```

#### 2.7.3 충돌 발생 시

```bash
# 충돌 파일 확인
git status

# 충돌 해결 후
git add {resolved-files}
git rebase --continue

# force push
git push --force-with-lease origin {head-branch}
```

충돌 해결이 복잡한 경우 사용자에게 알리고 수동 해결 요청.

#### 2.7.4 rebase 후 CI 재확인

force push 후 Jenkins CI가 재트리거된다. CI 통과를 확인한 후 Step 3으로 진행한다.

- CI 모니터링은 `/jenkins-ci-loop` 스킬 참고
- `mergeStateStatus == "CLEAN"` 확인 후 병합

> main과 이미 동일한 base를 가지면 rebase를 생략해도 된다.

---

### Step 3: 사용자 확인 (CRITICAL)

병합 실행 전 반드시 사용자 확인을 받는다:

```
🔀 PR 병합을 진행합니다.

| 항목 | 값 |
|------|-----|
| PR | #{pr-number} - {title} |
| 브랜치 | {head-branch} → main |
| 연결 이슈 | #{issue-number} |

**진행할 작업**:
1. PR squash merge
2. 워크트리 제거: `../worktrees/{branch-name}`
3. 로컬 브랜치 삭제: `{branch-name}`
4. 원격 브랜치 삭제: `origin/{branch-name}`
5. 이슈 #{issue-number} 종결
6. in-progress 라벨 제거

진행할까요?
```

### Step 4: PR Squash Merge

#### 4.1 커밋 타입 결정

이슈 라벨 또는 브랜치 prefix에서 Conventional Commits 타입을 결정한다:

| 우선순위 | 소스 | 매핑 |
|----------|------|------|
| 1 | 이슈 라벨 | `enhancement` → `feat`, `bug` → `fix`, `refactoring` → `refactor`, `documentation` → `docs`, `test` → `test` |
| 2 | 브랜치 prefix | `feature/` → `feat`, `fix/` → `fix`, `refactor/` → `refactor`, `docs/` → `docs` |
| 3 | 기본값 | `chore` |

#### 4.2 커밋 메시지 생성

**표준 형식** (Conventional Commits):
```
<type>: <description> (#issue-number)
```

- `<type>`: 위에서 결정된 타입 (소문자)
- `<description>`: PR 제목에서 타입 prefix 제거 후 사용. 첫 글자 소문자로 통일
- `(#issue-number)`: 연결된 이슈 번호

**예시**:
- PR 제목: `[기능] 창고 리소스 사용량 조회 API 추가`
- 이슈: `#6`
- 결과: `feat: 창고 리소스 사용량 조회 API 추가 (#6)`

#### 4.3 병합 실행

```bash
# 커밋 메시지를 명시적으로 지정하여 squash merge
gh pr merge {pr-number} --squash --delete-branch \
  --subject "<type>: <description> (#issue-number)" \
  -R invigoworks/bitda-back
```

**옵션 설명**:
- `--squash`: 커밋 히스토리를 하나로 합침 (선형 그래프 유지)
- `--delete-branch`: 원격 브랜치 자동 삭제
- `--subject`: 커밋 메시지 제목 (Conventional Commits 형식)

**병합 실패 시**:
- 에러 메시지 표시
- 가능한 원인 설명 (충돌, CI 실패 등)
- 스킬 종료

### Step 5: 워크트리 정리

```bash
# 현재 워크트리 목록 확인
git worktree list

# 해당 브랜치의 워크트리 경로 확인
# 패턴: ../worktrees/issue/{number}-* 또는 ../worktrees/{branch-name}

# 워크트리가 존재하면 제거
git worktree remove {worktree-path} --force
```

**주의**: 현재 작업 디렉토리가 해당 워크트리인 경우:
1. 메인 저장소로 이동 안내
2. 또는 `--force` 옵션으로 강제 제거

### Step 6: 로컬 브랜치 정리 (CRITICAL)

**반드시 로컬 브랜치를 삭제한다.**

```bash
# 메인 브랜치로 전환 (필요시)
git checkout main

# main 최신화
git pull origin main

# 로컬 브랜치 삭제 (강제)
git branch -D {branch-name}
```

**참고**: `gh pr merge --delete-branch`가 원격 브랜치는 삭제하지만, 로컬 브랜치는 삭제하지 않으므로 수동 삭제 필수.

### Step 7: 이슈 종결 및 라벨 정리

```bash
# 이슈 상태 확인 (Closes #으로 자동 닫혔는지)
gh issue view {issue-number} -R invigoworks/bitda-back --json state

# 이슈가 열려있으면 수동으로 닫기
gh issue close {issue-number} -R invigoworks/bitda-back

# in-progress 라벨 제거 (있는 경우)
gh issue edit {issue-number} --remove-label "in-progress" -R invigoworks/bitda-back
```

### Step 8: 완료 댓글 등록

이슈에 완료 댓글을 추가한다:

```bash
gh issue comment {issue-number} --body "$(cat <<'EOF'
## ✅ 작업 완료

**완료 시간**: YYYY-MM-DD HH:MM
**병합된 PR**: #{pr-number}

### 정리된 리소스
- [x] PR squash merge 완료
- [x] 원격 브랜치 삭제: `origin/{branch-name}`
- [x] 로컬 브랜치 삭제: `{branch-name}`
- [x] 워크트리 제거: `{worktree-path}`
- [x] 이슈 종결
- [x] in-progress 라벨 제거

---

🤖 Merged by [Claude Code](https://claude.com/claude-code)
EOF
)" -R invigoworks/bitda-back
```

### Step 9: 결과 보고

```
✅ PR 병합 및 정리가 완료되었습니다.

| 항목 | 결과 |
|------|------|
| PR | #{pr-number} → main (squash merged) |
| 이슈 | #{issue-number} 종결됨 |
| 워크트리 | {worktree-path} 제거됨 |
| 로컬 브랜치 | {branch-name} 삭제됨 |
| 원격 브랜치 | origin/{branch-name} 삭제됨 |
| 라벨 | in-progress 제거됨 |

다음 작업을 진행할 수 있습니다.
```

### Step 10: API 문서 동기화 제안 (조건부)

**Step 1에서 `api_changed=true`로 판정된 경우에만 실행**

#### 10.1 변경된 Controller 파일 분석

```bash
# 변경된 Controller 파일 목록 추출
gh pr view {pr-number} -R invigoworks/bitda-back --json files -q '.files[].path' | grep -E 'Controller\.kt$'
```

변경된 각 Controller에서 영향받은 API 엔드포인트를 식별한다.

#### 10.2 사용자에게 동기화 제안

```
📝 API 변경이 감지되었습니다.

**변경된 Controller**:
- {controller1}.kt
- {controller2}.kt

**영향받은 API** (추정):
- POST /api/v1/warehouses
- GET /api/v1/warehouses/{id}

Notion API 문서를 동기화하시겠습니까?

1. 예 - `/swagger-snapshot` → `/api-to-notion` 실행
2. 아니오 - 건너뛰기
3. 나중에 - 수동으로 실행
```

#### 10.3 동기화 실행 (사용자가 "예" 선택 시)

1. **Swagger 스냅샷 수집**:
   ```
   /swagger-snapshot 스킬 실행
   ```

2. **API 문서 동기화**:
   ```
   /api-to-notion 스킬 실행
   - 변경된 Controller의 API만 대상으로 지정
   ```

3. **연관 컴포넌트 문서 업데이트**:
   업데이트된 각 API에 대해 연결된 컴포넌트 페이지 조회 및 필드 매핑 테이블 갱신:

   ```
   /component-api-linker 스킬 실행
   - API 맵핑 DB에서 해당 API의 "컴포넌트 & 로직 DB" relation 조회
   - 연결된 컴포넌트 페이지들의 필드 매핑 테이블 업데이트
   ```

   > API 필드가 변경되면 컴포넌트의 화면↔API 필드 매핑도 갱신해야 함

4. **완료 보고**:
   ```
   ✅ API 문서 동기화 완료

   | API | 상태 | 연관 컴포넌트 |
   |-----|------|--------------|
   | POST /api/v1/warehouses | 업데이트됨 | 창고 등록 폼 |
   | GET /api/v1/warehouses/{id} | 신규 등록 | - |

   📝 컴포넌트 필드 매핑 업데이트:
   - 창고 등록 폼: 필드 매핑 테이블 갱신됨
   ```

#### 10.4 건너뛰기 (사용자가 "아니오" 또는 "나중에" 선택 시)

```
ℹ️ API 문서 동기화를 건너뛰었습니다.
나중에 `/swagger-snapshot` → `/api-to-notion`으로 수동 실행할 수 있습니다.
```

## Error Handling

| 시나리오 | 조치 |
|----------|------|
| PR 이미 병합됨 | 상태 알림, 정리 작업만 진행 여부 확인 |
| PR 병합 불가 | 구체적 원인 표시, 해결 방법 안내 |
| 워크트리 미존재 | 건너뛰고 다음 단계 진행 |
| 브랜치 미존재 | 건너뛰고 다음 단계 진행 |
| 이슈 이미 종결 | 라벨 정리만 진행 |
| 라벨 미존재 | 건너뛰고 다음 단계 진행 |
| 마이그레이션 버전 충돌 | 자동 조정 제안, 사용자 선택에 따라 처리 |
| 마이그레이션 조정 후 CI 실패 | CI 실패 원인 안내, 수동 해결 유도 |

## Resume Protocol

PR이 이미 병합된 경우에도 정리 작업을 진행할 수 있다:

1. PR 상태 확인 (MERGED)
2. 남은 정리 작업 식별:
   - 워크트리 존재 여부
   - 로컬 브랜치 존재 여부
   - 이슈 상태
   - 라벨 상태
3. 사용자에게 정리 작업 진행 여부 확인
4. 필요한 정리만 수행

## CLI Reference

```bash
# PR 정보 조회
gh pr view {number} -R owner/repo --json number,title,state,mergeable,mergeStateStatus,headRefName,body

# PR 변경 파일 중 마이그레이션 파일 확인
gh pr view {number} -R owner/repo --json files -q '.files[].path' | grep -E 'db/migration/V[0-9]+__.*\.sql$'

# main 브랜치 최신 마이그레이션 버전 조회
git fetch origin main && git ls-tree -r origin/main --name-only | grep -E 'db/migration/V[0-9]+__.*\.sql$' | sort -V | tail -1

# 마이그레이션 파일 이름 변경 (버전 조정)
git mv modules/infrastructure/src/main/resources/db/migration/{old}.sql modules/infrastructure/src/main/resources/db/migration/{new}.sql

# PR squash merge (원격 브랜치 삭제 포함, 커밋 메시지 지정)
gh pr merge {number} --squash --delete-branch --subject "<type>: <desc> (#issue)" -R owner/repo

# 이슈 정보 조회
gh issue view {number} -R owner/repo --json state,labels

# 이슈 종결
gh issue close {number} -R owner/repo

# 이슈 라벨 제거
gh issue edit {number} --remove-label "label" -R owner/repo

# 이슈에 댓글 추가
gh issue comment {number} --body "댓글" -R owner/repo

# 워크트리 목록
git worktree list

# 워크트리 제거
git worktree remove {path} [--force]

# 로컬 브랜치 삭제 (강제)
git branch -D {branch-name}

# 원격 브랜치 삭제 (수동 필요시)
git push origin --delete {branch-name}
```

## Workflow Integration

```
issue-create → issue-plan → issue-impl → issue-pr → pr-review → pr-merge
     │              │             │           │          │           │
     └──────────────┴─────────────┴───────────┴──────────┴───────────┘
                              완전한 Issue 라이프사이클
```
