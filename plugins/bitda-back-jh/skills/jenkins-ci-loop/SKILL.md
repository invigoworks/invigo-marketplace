---
name: jenkins-ci-loop
description: push 후 Jenkins CI 빌드를 모니터링하고 실패 시 원인 파악 → 수정 → 재push를 SUCCESS까지 반복하는 스킬입니다. "/jenkins-ci-loop", "젠킨슨 루프", "CI 루프", "빌드 실패 수정" 등을 요청할 때 사용됩니다.
---

# Jenkins CI Loop

## Purpose

`git push` 후 Jenkins CI 빌드 결과를 모니터링하고,
실패 시 원인 파악 → 로컬 수정 → commit → push → 재빌드를 **SUCCESS가 될 때까지 자동 반복**한다.

> **⛔ 로컬 `./gradlew` 절대 금지.** 모든 Gradle 작업(ktlint/test/build)은 AI_server 원격에서만 실행한다.
> 파일 편집·git commit·push만 로컬에서 수행한다.

## Environment (Bitda 프로젝트 고정값)

| 항목 | 값 |
|------|-----|
| Jenkins host | `AI_server` |
| Jenkins container | `jenkins` |
| Workspace 패턴 | `/var/jenkins_home/workspace/bitda-back-ci_PR-{pr}` |
| Build log 패턴 | `/var/jenkins_home/jobs/bitda-back-ci/branches/PR-{pr}/builds/{build}/log` |
| Test XML 위치 | `{workspace}/modules/{module}/build/test-results/test/TEST-*.xml` |

## Jenkins 크리덴셜

> **🔐 크리덴셜은 하드코딩하지 않는다.** 저장소 루트의 `.env.jenkins` 파일(git-ignored)에서 로드한다.

`.env.jenkins` 형식:

```bash
JENKINS_URL=https://jenkins.invigoworks.co.kr
JENKINS_USER=invigoworks
JENKINS_TOKEN=<토큰>
```

Jenkins API 호출 전 매 Bash 호출에서 `.env.jenkins`를 source 한다:

```bash
set -a; . /Users/gimjinhyeog/Desktop/coding/bitda-back/.env.jenkins; set +a
```

> **⛔ Playwright 절대 금지.** Jenkins API 호출은 반드시 `curl` + 위 크리덴셜로만 한다.
> Playwright/브라우저 자동화는 이 스킬에서 사용하지 않는다.

### Jenkins API 호출 패턴

```bash
set -a; . /Users/gimjinhyeog/Desktop/coding/bitda-back/.env.jenkins; set +a

# 빌드 트리거
curl -s -u "$JENKINS_USER:$JENKINS_TOKEN" \
  "$JENKINS_URL/job/bitda-back-ci/job/PR-{pr}/build"

# 빌드 상태 확인
curl -s -u "$JENKINS_USER:$JENKINS_TOKEN" \
  "$JENKINS_URL/job/bitda-back-ci/job/PR-{pr}/lastBuild/api/json?tree=number,result,building"

# 빌드 로그 (콘솔 출력)
curl -s -u "$JENKINS_USER:$JENKINS_TOKEN" \
  "$JENKINS_URL/job/bitda-back-ci/job/PR-{pr}/{build}/consoleText"
```

## ⚡ Auto-Proceed Policy

**확인 없이 자동 실행**:
- 빌드 로그 분석
- 코드 수정 (원인이 명확한 경우)
- commit + push
- 다음 빌드 polling

**사용자에게 질문하는 경우**:
- 3회 연속 실패 시
- 비즈니스 로직 변경이 필요한 경우
- 여러 수정 방향이 있고 판단 불가한 경우

## Workflow

### Step 0: PR 번호 확인

```bash
gh pr view --json number -q '.number' -R invigoworks/bitda-back
```

인자로 전달된 경우 (`/jenkins-ci-loop #1778`) 우선 사용.

---

### Step 0.5: main 동기화 사전 점검 (병렬 작업 대비, MANDATORY)

> **병렬 작업 환경에서 다른 PR이 먼저 main에 머지되면 이 PR 브랜치가 `BEHIND` 상태가 된다.
> 그대로 CI를 돌리면 낡은 base로 빌드/머지가 꼬이고 뒤늦게 rebase가 강제된다.
> 루프 시작 전에 미리 rebase하여 최신 main 기준으로 CI를 돌린다.**

#### 0.5a. BEHIND 여부 확인

```bash
HEAD_BRANCH=$(gh pr view {pr} --json headRefName -q .headRefName -R invigoworks/bitda-back)
git fetch origin main -q
BEHIND=$(git rev-list --count origin/${HEAD_BRANCH}..origin/main 2>/dev/null)
echo "main이 PR 브랜치보다 ${BEHIND}개 커밋 앞섬"
```

- `BEHIND == 0` → 이미 최신. **Step 1로 진행** (rebase 불필요).
- `BEHIND > 0` → 0.5b 진행.

> mergeStateStatus로 교차 확인 가능: `gh pr view {pr} --json mergeStateStatus -q .mergeStateStatus` → `BEHIND`면 rebase 필요.

#### 0.5b. 워크트리에서 rebase

```bash
WORKTREE_PATH={worktree-path}   # git worktree list로 확인
cd ${WORKTREE_PATH}

# .omc/state 등 추적 캐시가 rebase를 막으면 정리
git checkout -- .omc/state 2>/dev/null || true

git rebase origin/main 2>&1 | tail -15
```

- **충돌 없음** → 0.5c (force push).
- **충돌 발생** → `git rebase --abort` 후 사용자에게 보고 (자동 충돌 해결 금지).
  복잡한 충돌은 수동 개입 필요.

#### 0.5c. force push + 데몬 정리

```bash
git push --force-with-lease origin ${HEAD_BRANCH} 2>&1 | tail -5

# ⚠️ pre-push 훅이 로컬 gradle ktlint를 돌려 데몬을 남길 수 있음 → 즉시 종료
cd {메인-저장소-루트} && ./gradlew --stop 2>&1 | tail -1
```

force push 후 Jenkins가 새 빌드를 자동 트리거한다. **새 빌드 번호로 Step 1 진행.**

**예외 (rebase 생략):**
- `BEHIND == 0` (이미 최신 main 기준).
- PR이 이미 `MERGED`/`CLOSED` 상태 (정리만 필요).
- rebase 충돌이 발생해 사용자 개입이 필요한 경우 (자동 진행 중단).

---

### Step 1: 최신 빌드 번호 확인

```bash
ssh AI_server "docker exec jenkins ls -t /var/jenkins_home/jobs/bitda-back-ci/branches/PR-{pr}/builds/ 2>/dev/null | grep -E '^[0-9]+$' | head -1"
```

빌드가 아직 없으면 30초 대기 후 재확인.

---

### Step 2: 빌드 완료 대기 (background polling)

```bash
ssh AI_server "while ! docker exec jenkins grep -qE 'Finished: ' /var/jenkins_home/jobs/bitda-back-ci/branches/PR-{pr}/builds/{build}/log 2>/dev/null; do sleep 30; done; docker exec jenkins grep -E 'GitHub check.*completed|Finished:|FAILED' /var/jenkins_home/jobs/bitda-back-ci/branches/PR-{pr}/builds/{build}/log 2>/dev/null | grep -v 'ha:////'" 2>&1
```

`run_in_background: true`로 실행하여 완료 알림 대기.

---

### Step 3: 결과 판정

```bash
ssh AI_server "docker exec jenkins grep -E 'Finished: ' /var/jenkins_home/jobs/bitda-back-ci/branches/PR-{pr}/builds/{build}/log 2>/dev/null | tail -1"
```

- `Finished: SUCCESS` → **Step 7 (완료)로 이동**
- `Finished: FAILURE` → **Step 4 (원인 파악)로 이동**

---

### Step 4: 실패 원인 파악

#### 4a. 실패 단계 식별

```bash
ssh AI_server "docker exec jenkins grep -E 'GitHub check.*completed|FAILED|ProductionPlan.*FAILED|\\bFAILED\\b' /var/jenkins_home/jobs/bitda-back-ci/branches/PR-{pr}/builds/{build}/log 2>/dev/null | grep -v 'ha:////' | tail -20"
```

#### 4b. 테스트 실패인 경우 → XML report 확인

```bash
# 실패한 테스트 XML 찾기
ssh AI_server "docker exec jenkins find /var/jenkins_home/workspace/bitda-back-ci_PR-{pr}/modules -name 'TEST-*.xml' -exec grep -l 'failures=\"[^0]\\|errors=\"[^0]' {} \; 2>/dev/null | head -5"

# 실패 상세 확인
ssh AI_server "docker exec jenkins grep -A 30 'failure\|error' {xml_path} | head -60"
```

XML에서 확인할 핵심 정보:
- `failure message`: 예외 메시지 (예: `IllegalArgumentException: 생산일자는 오늘 또는 과거여야 합니다`)
- `at {ClassName}.kt:{line}`: 실패 위치

#### 4c. 컴파일 에러인 경우 → 로그에서 직접 확인

```bash
ssh AI_server "docker exec jenkins grep -E 'error:|error\[|Compilation error|Type mismatch|Unresolved reference' /var/jenkins_home/jobs/bitda-back-ci/branches/PR-{pr}/builds/{build}/log 2>/dev/null | grep -v 'ha:////' | head -20"
```

---

### Step 5: 수정

파악된 원인에 따라 **로컬 워크트리에서 파일만 수정**한다 (Gradle 실행 금지):

> **⛔ 로컬 `./gradlew` 절대 금지.** 파일 편집·git 조작만 로컬에서 하고,
> ktlint/test/build 등 모든 Gradle 작업은 **AI_server 원격**에서만 실행한다.
> 로컬 Gradle은 데몬이 잔존하여 시스템을 느리게 만든다.

1. 해당 파일 `Read` (Edit 직전 필수)
2. `Edit`으로 수정
3. `ktlintCheck` 확인 (**AI_server 원격**):
   ```bash
   PR={pr-number}
   WORKTREE_PATH={worktree-path}

   # 동기화 (tar over ssh — 한글 파일명 보존). impl workdir와 충돌 방지 위해 ci 전용 디렉토리 사용
   ssh AI_server "rm -rf ~/bitda-ci-${PR} && mkdir ~/bitda-ci-${PR}"
   cd ${WORKTREE_PATH}
   tar --exclude='.gradle' --exclude='build' --exclude='.idea' --exclude='.git' -cf - . \
     | ssh AI_server "cd ~/bitda-ci-${PR} && tar -xf -"
   ssh AI_server "cd ~/bitda-ci-${PR} && git init -q && git add -A \
     && git -c user.email=t@t -c user.name=t commit -q -m wip"

   # ktlintCheck (원격, --no-daemon, LC_ALL 필수)
   ssh AI_server "export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
     && cd ~/bitda-ci-${PR} \
     && ./gradlew ktlintCheck --no-daemon -Dfile.encoding=UTF-8 2>&1 | tail -50"
   ```
   실패 시 원격에서 `ktlintFormat` 실행 후 변경 파일을 로컬로 역전송:
   ```bash
   ssh AI_server "export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
     && cd ~/bitda-ci-${PR} \
     && ./gradlew ktlintFormat --no-daemon -Dfile.encoding=UTF-8 2>&1 | tail -50"

   # 수정 파일 로컬로 동기화
   ssh AI_server "cd ~/bitda-ci-${PR} && tar -cf - --exclude='.gradle' --exclude='build' --exclude='.git' ." \
     | (cd ${WORKTREE_PATH} && tar -xf -)
   ```

#### 자주 발생하는 패턴 및 수정 가이드

| 에러 패턴 | 원인 | 수정 방법 |
|----------|------|----------|
| `생산일자는 오늘 또는 과거여야 합니다: YYYY-MM-DD` | 테스트에 미래 날짜 하드코딩 | `LocalDate.now().minusDays(N)` 으로 변경 |
| `Type mismatch: inferred type is List<X> but MutableList<X>` | List/MutableList 타입 불일치 | `.toMutableList()` 또는 `.toList()` 추가 |
| `Unresolved reference: XXX` | import 누락 또는 잘못된 참조 | import 추가 또는 참조 수정 |
| `Compilation error` in `kaptGenerateStubsTestKotlin` | 테스트 파일 구조 오류 | 중괄호 닫힘/inner class 위치 확인 |

---

### Step 6: commit + push

```bash
cd {worktree-path}
git add {수정된 파일들}
git commit -m "fix: {원인 요약}"
git push

# ⚠️ pre-push 훅의 로컬 gradle 데몬 정리
cd {메인-저장소-루트} && ./gradlew --stop 2>&1 | tail -1
```

push 완료 후 Jenkins가 자동으로 새 빌드 트리거됨.

> **루프 반복 중 재점검**: 루프가 길어지면 그 사이 다른 PR이 main에 머지될 수 있다.
> push 전 `git rev-list --count origin/${HEAD_BRANCH}..origin/main`이 0이 아니면
> **Step 0.5b(rebase)를 먼저 수행**한 뒤 push한다.

**Step 1로 돌아가 새 빌드 번호 확인 후 반복.**

---

### Step 7: 완료

```
✅ Jenkins CI 통과

| 빌드 | 결과 |
|------|------|
| #{build} | SUCCESS |

모든 단계 통과:
- Build ✅
- Lint ✅
- Unit Test ✅
- Integration Test ✅
```

---

## 3회 연속 실패 시

동일 원인으로 3회 실패하거나 수정 방향을 모르겠으면:

```
⚠️ Jenkins CI 3회 연속 실패

| 빌드 | 실패 원인 |
|------|----------|
| #N-2 | {원인} |
| #N-1 | {원인} |
| #N   | {원인} |

수동 개입이 필요합니다.
```

사용자에게 실패 로그 전체를 공유하고 방향 결정 요청.

---

## CLI Reference

```bash
# Jenkins 빌드 목록 확인
ssh AI_server "docker exec jenkins ls -t /var/jenkins_home/jobs/bitda-back-ci/branches/PR-{pr}/builds/ | grep -E '^[0-9]+$'"

# 빌드 로그 tail
ssh AI_server "docker exec jenkins tail -50 /var/jenkins_home/jobs/bitda-back-ci/branches/PR-{pr}/builds/{build}/log"

# 빌드 완료 여부 확인
ssh AI_server "docker exec jenkins grep -c 'Finished: ' /var/jenkins_home/jobs/bitda-back-ci/branches/PR-{pr}/builds/{build}/log 2>/dev/null"

# 실패 테스트 XML 검색
ssh AI_server "docker exec jenkins find /var/jenkins_home/workspace/bitda-back-ci_PR-{pr}/modules -name 'TEST-*.xml' | xargs grep -l 'failures=\"[1-9]' 2>/dev/null"

# XML 실패 메시지 확인
ssh AI_server "docker exec jenkins cat {xml_path} | grep -A 20 'failure'"

# 컴파일 에러 확인
ssh AI_server "docker exec jenkins grep -E 'error:|Compilation error|Type mismatch' /var/jenkins_home/jobs/bitda-back-ci/branches/PR-{pr}/builds/{build}/log | grep -v 'ha:////'"
```

## 연관 스킬

- `review-action`: 리뷰 조치 후 이 스킬 자동 실행
- `issue-impl`: 구현 완료 + push 후 이 스킬 자동 실행
- `pr-merge`: Jenkins SUCCESS 확인 후 실행

