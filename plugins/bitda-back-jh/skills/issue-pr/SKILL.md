---
name: issue-pr
description: GitHub 이슈와 연결된 형식화된 Pull Request를 생성하는 스킬입니다. 이슈 정보를 기반으로 PR 제목과 본문을 자동 생성하고, Closes #{issue-number}로 이슈를 연결합니다. 이 스킬은 "/issue-pr", "/issue-pr #123", "PR 생성", "풀리퀘스트 생성" 등을 요청할 때 사용됩니다.
---

# Issue PR

## Purpose

GitHub 이슈와 연결된 형식화된 Pull Request를 생성한다.
이슈 정보를 기반으로 PR 제목과 본문을 자동 생성하고, `Closes #{issue-number}`로 이슈를 연결한다.

## Workflow

### Step 0: 이슈 번호 확인

이슈 번호를 다음 우선순위로 결정한다:

1. **인자로 전달된 경우**: `/issue-pr #123` → `#123`
2. **현재 브랜치에서 추출**: `issue/123-feature-name` → `#123`
3. **현재 워크트리 이름에서 추출**: `../worktrees/issue/123-feature-name` → `#123`
4. **사용자에게 질문**: 위 방법으로 확인 불가 시

### Step 1: 정보 수집

```bash
# 이슈 정보 조회
gh issue view {issue-number} -R invigoworks/bitda-back --json title,body,labels

# 현재 브랜치 상태
git status
git log main..HEAD --oneline
git diff main...HEAD --stat
```

수집 항목:
- 이슈 제목 및 요구사항
- 커밋 이력
- 변경된 파일 목록

### Step 2: PR 제목 생성

**형식**: `[{타입}] {간결한 설명} (#{issue-number})`

| 이슈 라벨 | PR 타입 | 예시 |
|----------|---------|------|
| feature | 기능 | `[기능] 사용자 로그인 API 구현 (#123)` |
| bug | 수정 | `[수정] 토큰 만료 처리 오류 해결 (#124)` |
| refactor | 리팩토링 | `[리팩토링] UserService 의존성 정리 (#125)` |
| docs | 문서 | `[문서] API 문서 업데이트 (#126)` |
| test | 테스트 | `[테스트] UserService 테스트 보강 (#127)` |

**제목 규칙**:
- 70자 이내
- 한글 사용 (타입, 설명 모두)
- 이슈 번호 포함

### Step 3: PR 본문 생성

**PR 본문 템플릿**:

```markdown
## 개요

{이슈에서 요약한 핵심 변경 사항 1-2문장}

Closes #{issue-number}

## 변경 사항

### 주요 변경
- {주요 변경 1}
- {주요 변경 2}
- {주요 변경 3}

### 파일 변경 요약
- `{파일 경로}`: {변경 내용}
- `{파일 경로}`: {변경 내용}

## 테스트

- [ ] 단위 테스트 추가/수정
- [ ] 통합 테스트 추가/수정
- [ ] 수동 테스트 완료

### 테스트 커버리지
```bash
./gradlew test
```

## 체크리스트

- [ ] CLAUDE.md 아키텍처 규칙 준수
- [ ] ktlintCheck 통과
- [ ] 모든 테스트 통과
- [ ] 관련 문서 업데이트 (필요시)

## 스크린샷 / 로그 (해당시)

{API 응답 예시, 로그 출력 등}

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### Step 4: 브랜치 Push

로컬 브랜치가 리모트에 없으면 push한다:

```bash
# 현재 브랜치 확인
git branch --show-current

# 리모트 추적 확인
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "no-upstream"

# Push (필요시)
git push -u origin {branch-name}
```

### Step 5: PR 생성

```bash
gh pr create \
  --title "{PR 제목}" \
  --body "$(cat <<'EOF'
{PR 본문}
EOF
)" \
  --base main \
  -R invigoworks/bitda-back
```

### Step 6: 이슈에 PR 링크 댓글

PR 생성 후 이슈에 연결 댓글을 추가한다:

```bash
gh issue comment {issue-number} --body "## 🔗 PR 생성됨

Pull Request: #{pr-number}
브랜치: \`{branch-name}\`

다음 단계:
- \`/pr-review #{pr-number}\` 로 리뷰 진행" -R invigoworks/bitda-back
```

### Step 7: 결과 보고

```
✅ PR이 생성되었습니다.

| 항목 | 값 |
|------|-----|
| PR 번호 | #{pr-number} |
| 제목 | {PR 제목} |
| 브랜치 | {branch} → main |
| 연결 이슈 | #{issue-number} |
| URL | {pr-url} |

다음 단계:
- `/pr-review #{pr-number}` 로 코드 리뷰 진행
```

## PR 체크리스트 자동 확인 (원격 실행 전용)

> **⛔ 로컬 `./gradlew` 절대 금지.** 로컬에서 Gradle을 실행하면 데몬이 잔존하여
> 시스템이 느려진다. 모든 Gradle 검증은 **AI_server 원격**에서만 수행한다.
> `issue-full-cycle` 파이프라인에서는 직전 `issue-impl-remote` 단계가 이미 원격 전체 빌드를
> 통과시켰으므로, 이 검증은 **건너뛴다** (중복).

**단독 실행(`/issue-pr`만 호출) 시에만** 원격 검증을 수행한다:

```bash
ISSUE={issue-number}
WORKTREE_PATH=$(git rev-parse --show-toplevel)

# 동기화 (tar over ssh — 한글 파일명 보존)
ssh AI_server "rm -rf ~/bitda-work-${ISSUE} && mkdir ~/bitda-work-${ISSUE}"
cd ${WORKTREE_PATH}
tar --exclude='.gradle' --exclude='build' --exclude='.idea' --exclude='.git' -cf - . \
  | ssh AI_server "cd ~/bitda-work-${ISSUE} && tar -xf -"
ssh AI_server "cd ~/bitda-work-${ISSUE} && git init -q && git add -A \
  && git -c user.email=t@t -c user.name=t commit -q -m wip"

# 전체 빌드 (원격, --no-daemon, LC_ALL 필수) — run_in_background=true 권장
ssh AI_server "export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
  && cd ~/bitda-work-${ISSUE} \
  && ./gradlew build --no-daemon -Dfile.encoding=UTF-8 2>&1 | tail -300"
```

검증 실패 시:
- 실패 항목 표시
- 사용자에게 진행 여부 확인
- `--force` 옵션으로 강제 생성 가능 안내

## CLI Reference

```bash
# 이슈 조회
gh issue view {number} -R owner/repo --json title,body,labels

# 이슈에 댓글 추가
gh issue comment {number} --body "댓글" -R owner/repo

# PR 생성
gh pr create --title "제목" --body "본문" --base main -R owner/repo

# PR 조회
gh pr view {number} -R owner/repo

# 브랜치 Push
git push -u origin {branch-name}
```
