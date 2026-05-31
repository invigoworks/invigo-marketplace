---
name: issue-test-remote
description: |
  이슈 워크트리의 Gradle 테스트를 AI_server(원격 고스펙 서버)에서 실행하고 결과만
  로컬로 가져오는 스킬입니다. 로컬 Mac에서 테스트를 돌리면 JVM·Testcontainers·Gradle
  데몬이 컴퓨팅 자원을 점유해 성능이 하락하므로, 무거운 실행을 원격으로 오프로드합니다.
  이 스킬은 다음 상황에서 사용됩니다:
  - 로컬에서 테스트 실행 시 발열/성능 하락을 피하고 싶을 때
  - issue-impl로 개발한 이슈의 테스트를 원격에서 검증할 때
  - 사용자가 "원격 테스트", "AI_server 테스트", "/issue-test-remote" 등을 요청할 때
---

# Issue Test Remote

이슈 워크트리를 AI_server에 동기화하고, **변경된 모듈의 Gradle 테스트만** 원격 실행하여
결과를 로컬로 가져오는 스킬. `swagger-snapshot-remote`의 테스트 실행 버전.

## 목적

로컬(Mac)에서 Gradle 테스트를 돌리면 JVM·Testcontainers·Gradle 데몬이 CPU/메모리를
점유해 다른 작업 성능이 하락한다. 무거운 실행(컴파일·테스트·Testcontainers)을 100%
AI_server로 오프로드하고, 로컬은 가벼운 작업(`git diff`, `tar`, `scp`)만 수행한다.

## 로컬 vs 원격 선택 기준

| 상황 | 사용할 방식 |
|------|------------|
| 단일 단위 테스트 1개 | 로컬 (`./gradlew :module:test --tests`) |
| 로컬 발열/성능 하락 회피, 변경 모듈 테스트 | **`issue-test-remote`** (이 스킬) |
| 전체 build 최종 게이트 | `remote-testing-policy §3` 직접 (또는 이 스킬 전체모드) |

## 전제 조건

- `ssh AI_server` 접속 가능
- AI_server에 PostgreSQL·Keycloak 컨테이너 상시 가동 (`bitda-postgres`, `bitda-keycloak`)
- 로컬에 이슈 워크트리 존재 (`../worktrees/issue/{number}-{slug}`)

## 설계 원칙

| 원칙 | 적용 |
|------|------|
| **로컬 최소 부하** | 로컬은 `git diff` + `tar`/`scp`만. JVM/Gradle/Testcontainers는 전부 원격. |
| **변경 기반 선택 실행** | 전체 build 대신 변경 모듈 테스트만 실행 → 원격 시간도 단축. |
| **부가작업 배제** | 이슈 댓글 등록 안 함. 결과는 로컬 터미널 출력만. |

## 전체 흐름

```
1. [local·가벼움]  이슈번호 확인 → 워크트리 경로 결정
2. [local·가벼움]  git diff origin/main...HEAD → 변경 모듈 + 테스트 패턴 추출
3. [local→remote]  tar over ssh 동기화 (.git/build/.gradle 제외)
4. [remote·무거움] git init + 1 commit (generateGitProperties 의존)
5. [remote·무거움] ./gradlew :변경모듈:test [--tests '패턴'] --no-daemon (백그라운드)
6. [local·가벼움]  원격 test-results XML 파싱 → 통과/실패 요약 출력
```

## 단계별 절차

### Step 0: 이슈 번호 확인

우선순위로 결정:

1. 인자로 전달 (`/issue-test-remote #123` → `123`)
2. 현재 브랜치에서 추출 (`issue/123-feature` → `123`)
3. 현재 워크트리 이름에서 추출 (`../worktrees/issue/123-feature` → `123`)
4. 불가 시 사용자에게 질문

```bash
# 현재 브랜치에서 추출 예시
git branch --show-current | grep -oE 'issue/[0-9]+' | grep -oE '[0-9]+'
```

워크트리 경로 결정: `git worktree list`로 `issue/{number}-*` 매칭 경로를 찾는다.

### Step 1: 변경 모듈 + 테스트 패턴 추출 (LOCAL)

> **왜 로컬인가**: 원격은 tar 동기화 후 단일 커밋으로 init하므로 main 히스토리가 없어
> diff 불가. `origin/main` 기준은 로컬 워크트리에만 존재한다.

```bash
cd /path/to/local/worktree
git fetch origin main -q

# 변경 파일 목록
CHANGED=$(git diff --name-only origin/main...HEAD)
echo "$CHANGED"
```

**모듈 path 매핑** (변경 파일 경로 → Gradle 모듈):

| 파일 경로 prefix | Gradle 모듈 |
|------------------|-------------|
| `modules/common/` | `:modules:common` |
| `modules/excel-engine/` | `:modules:excel-engine` |
| `modules/domain/` | `:modules:domain` |
| `modules/infrastructure/` | `:modules:infrastructure` |
| `modules/keycloak-spi/` | `:modules:keycloak-spi` |
| `modules/application/core/` | `:modules:application:core` |
| `modules/application/api/` | `:modules:application:api` |
| `modules/application/batch/` | `:modules:application:batch` |
| `modules/application/consumer/` | `:modules:application:consumer` |
| `modules/support/arch-test/` | `:modules:support:arch-test` |

> 정확한 모듈 목록은 `settings.gradle.kts`의 `include(...)` 확인.

**테스트 패턴 결정**:

- 변경된 `*Test.kt` 파일 → 파일명(확장자 제거)으로 `--tests '*ClassName*'` 패턴 생성
- 테스트 파일 없이 prod 코드만 변경된 모듈 → 해당 모듈 전체 `:module:test` (패턴 없음)
- 변경 모듈 없음 → 사용자에게 알리고 종료

```bash
# 변경된 테스트 클래스명 추출 예시
echo "$CHANGED" | grep -E '.*Test\.kt$' | xargs -n1 basename 2>/dev/null \
  | sed 's/\.kt$//' | sort -u
```

> 여러 모듈이 변경된 경우 Step 5에서 각 모듈을 공백으로 나열해 한 번에 실행한다.

### Step 2: 코드 동기화 (tar over ssh)

> **rsync 금지** — macOS NFD ↔ Linux NFC 한글 파일명 깨짐. tar로 NFD 바이트 보존.

```bash
ISSUE=123  # Step 0에서 결정
ssh AI_server "rm -rf ~/bitda-work-${ISSUE} && mkdir ~/bitda-work-${ISSUE}"
cd /path/to/local/worktree
tar --exclude='.gradle' --exclude='build' --exclude='.idea' --exclude='.git' -cf - . \
  | ssh AI_server "cd ~/bitda-work-${ISSUE} && tar -xf -"
```

### Step 3: Git 초기화 (원격)

> `generateGitProperties` 태스크가 git 저장소 요구. tar에서 `.git` 제외했으므로 원격에서 init.

```bash
ssh AI_server "cd ~/bitda-work-${ISSUE} && git init -q && git add -A \
  && git -c user.email=t@t -c user.name=t commit -q -m wip"
```

### Step 4: 원격 테스트 실행 (백그라운드)

> **LC_ALL 필수** — AI_server native.encoding이 ASCII. 미설정 시 한글 리소스 파일명
> 인코딩 오류로 `processResources` 실패.
> **`--no-daemon`** — SSH 종료 시 데몬 잔존 방지.
> Gradle 1~5분 소요 → `run_in_background=true`로 실행하고 알림 대기.

**변경 테스트 클래스가 있는 경우**:

```bash
ssh AI_server "export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
  && cd ~/bitda-work-${ISSUE} \
  && ./gradlew :modules:application:core:test --tests '*XxxServiceTest*' \
       :modules:application:api:test --tests '*XxxControllerTest*' \
       --no-daemon -Dfile.encoding=UTF-8 2>&1 | tail -200"
```

**테스트 파일 없이 prod 코드만 변경된 모듈** (패턴 없이 모듈 전체):

```bash
ssh AI_server "export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
  && cd ~/bitda-work-${ISSUE} \
  && ./gradlew :modules:application:core:test \
       --no-daemon -Dfile.encoding=UTF-8 2>&1 | tail -200"
```

### Step 5: 결과 파싱 및 출력 (LOCAL)

Gradle 출력에 `BUILD SUCCESSFUL` / `BUILD FAILED`가 표시된다. 실패 시 test-results XML을
직접 파싱해 실패 케이스를 확인한다.

```bash
# 테스트 결과 XML에서 실패 케이스 추출
ssh AI_server "cd ~/bitda-work-${ISSUE} \
  && find modules -path '*test-results*' -name '*.xml' \
       -exec grep -lE '<failure|<error' {} \;"

# 실패 상세
ssh AI_server "cd ~/bitda-work-${ISSUE} \
  && find modules -path '*test-results*' -name '*.xml' \
       -exec grep -E 'testsuite name=|<testcase|<failure|<error' {} \;"
```

**결과 요약 출력** (로컬 터미널, 이슈 댓글 등록 안 함):

```markdown
## 원격 테스트 결과 (AI_server)

**이슈**: #123
**실행 모듈**: :modules:application:core, :modules:application:api
**결과**: BUILD SUCCESSFUL / BUILD FAILED

| 모듈 | 테스트 | 결과 |
|------|--------|------|
| core | *XxxServiceTest* | ✅ 12 passed |
| api  | *XxxControllerTest* | ❌ 1 failed / 8 passed |

### 실패 상세 (있을 경우)
- `XxxControllerTest.shouldReturn400` : expected 400 but was 200
```

## Error Handling

| 증상 | 원인 | 해결 |
|------|------|------|
| `No Git repository found` | git 미초기화 | Step 3 실행 |
| `Failed to create MD5 hash ... .xlsx` | 한글 파일명 인코딩 | Step 4 LC_ALL 설정 확인 |
| `project 'application' not found` | 잘못된 Gradle 경로 | `:modules:application:...` 사용 |
| `not a git repository: /Users/.../worktrees/...` | rsync로 .git 포인터 복사됨 | `.git` 제외 후 tar 재전송 |
| 변경 모듈 없음 | diff 결과 없음 | 사용자에게 알리고 종료 |

## 주의사항

| 항목 | 정책 |
|------|------|
| rsync 금지 | tar 사용 (한글 파일명 NFD 보존) |
| LC_ALL 필수 | `en_US.UTF-8` export |
| git init 필요 | tar에서 `.git` 제외 → 원격 빈 init + 1 commit |
| `--no-daemon` | 권장 (SSH 종료 시 데몬 잔존 방지) |
| `--no-verify` | 절대 금지 (block-no-verify hook 차단) |
| 백그라운드 | Gradle 빌드 `run_in_background=true` + 알림 대기 |

## 연관 자산

- `docs/standards/remote-testing-policy.md §3`: 원격 실행 표준 절차 (이 스킬의 근거 정책)
- `swagger-snapshot-remote`: 동일 정책의 swagger 수집 버전 (구조 참조)
- `issue-impl`: 이 스킬의 입력이 되는 이슈 워크트리를 생성
