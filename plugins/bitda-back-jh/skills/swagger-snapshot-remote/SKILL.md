---
name: swagger-snapshot-remote
description: |
  AI_server(원격 개발 서버)에서 Bitda API를 기동하여 Swagger(/v3/api-docs) JSON을
  수집하고 로컬로 가져오는 스킬입니다. 로컬 Docker가 없거나 느릴 때 사용합니다.
  이 스킬은 다음 상황에서 사용됩니다:
  - 로컬 Docker 인프라가 없을 때
  - AI_server의 원격 DB를 기준으로 Swagger 스냅샷이 필요할 때
  - 사용자가 "원격 swagger 스냅샷", "AI_server swagger" 등을 요청할 때
---

# Swagger Snapshot Remote

AI_server에서 Bitda API를 기동하여 Swagger JSON을 수집하고 로컬로 가져오는 스킬.
로컬 `swagger-snapshot` 스킬의 원격 실행 버전.

## 로컬 vs 원격 선택 기준

| 상황 | 사용할 스킬 |
|------|------------|
| 로컬 Docker 가동 중 | `swagger-snapshot` |
| 로컬 Docker 없음 / 원격 DB 사용 | **`swagger-snapshot-remote`** (이 스킬) |

> **배경**: AI_server는 PostgreSQL·Keycloak 컨테이너 상시 가동 중. Notion MCP는 로컬에서만 동작하므로 스냅샷만 원격에서 수집 후 로컬로 복사.

## 전제 조건

- `ssh AI_server` 접속 가능
- AI_server에 PostgreSQL, Keycloak 컨테이너 가동 중 (`bitda-postgres`, `bitda-keycloak`)
- 로컬에 동기화할 코드 워크트리 존재

## 전체 흐름

```
1. [local]  코드 동기화 (tar over ssh) — rsync 금지 (한글 파일명 NFD/NFC 문제)
2. [remote] git init (generateGitProperties 태스크 필요)
3. [remote] swagger-snapshot.sh 실행 (LC_ALL=en_US.UTF-8 필수)
4. [local]  scp로 api-docs.json 가져오기
5. [local]  /api-to-notion 실행
```

## 단계별 명령어

```bash
# 1. 코드 동기화 (tar over ssh)
ISSUE=1710  # 이슈 번호 또는 작업명
ssh AI_server "rm -rf ~/bitda-work-${ISSUE} && mkdir ~/bitda-work-${ISSUE}"
cd /path/to/local/worktree
tar --exclude='.gradle' --exclude='build' --exclude='.idea' --exclude='.git' -cf - . \
  | ssh AI_server "cd ~/bitda-work-${ISSUE} && tar -xf -"

# 2. Git 초기화 (Spring Boot generateGitProperties 태스크 요구)
ssh AI_server "cd ~/bitda-work-${ISSUE} && git init -q && git add -A && git commit -q -m 'snapshot'"

# 3. 원격 스냅샷 수집
# ⚠️ LC_ALL=en_US.UTF-8 필수 — AI_server의 native.encoding이 ASCII여서
#    한글 파일명이 ?로 변환됨. LC_ALL이 sun.jnu.encoding을 UTF-8로 강제.
ssh AI_server "export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 && cd ~/bitda-work-${ISSUE} && bash .claude/skills/swagger-snapshot/scripts/swagger-snapshot.sh"
# 출력 마지막 줄: SNAPSHOT_DIR=/tmp/bitda-swagger-snapshot/{ts}

# 4. 로컬로 복사 (ts는 위 출력값)
TS=20260527_063000  # 위에서 확인한 timestamp
mkdir -p /tmp/bitda-swagger-snapshot/${TS}
scp "AI_server:/tmp/bitda-swagger-snapshot/${TS}/api-docs.json" \
    "/tmp/bitda-swagger-snapshot/${TS}/api-docs.json"

# 5. /api-to-notion 실행 (로컬에서)
```

## 주의사항

### rsync 금지
- macOS NFD ↔ Linux NFC 한글 파일명 깨짐
- `tar` 사용 (NFD 바이트 그대로 보존)
- 한글 템플릿 파일(`주류반출명세서.xlsx` 등) 인코딩 보호

### LC_ALL 필수
- AI_server의 Java `native.encoding`이 ASCII
- 한글 파일명이 `?`로 변환되어 `processResources` 태스크 MD5 해시 실패
- `LC_ALL=en_US.UTF-8` 설정으로 `sun.jnu.encoding`을 UTF-8로 강제

### git init 필요
- Spring Boot `generateGitProperties` 태스크가 git 메타데이터 요구
- tar 동기화 시 `.git` 제외했으므로 원격에서 빈 init + 1 commit 생성

### Flyway out-of-order
- 원격 DB에 이미 마이그레이션 있으면 추가 옵션 필요할 수 있음
- 스크립트는 그대로 사용, 환경변수 또는 args로 처리

## 연관 스킬

- `swagger-snapshot`: 로컬 실행용 (스크립트는 공유)
- `api-to-notion`: 이 스킬로 수집한 스냅샷을 Notion에 업로드
- `docs/standards/remote-testing-policy.md §3`: AI_server 원격 작업 정책
