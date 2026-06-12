---
name: e2e-test-dev
description: >
  jh_kim dev 계정(dev Keycloak)으로 E2E API 테스트를 수행하는 스킬입니다.
  로컬 main 빌드 API + dev DB + dev Keycloak PKCE 토큰 조합으로,
  dev API 서버에 아직 배포되지 않은 머지 코드를 실데이터 환경에서 검증할 때 사용합니다.
  "/e2e-test-dev", "dev 계정으로 E2E", "jh_kim으로 API 테스트", "dev DB로 E2E 테스트" 등을
  요청할 때 사용됩니다. (로컬 Docker Keycloak 기반 테스트는 e2e-test 스킬 사용)
---

# E2E Test (dev 계정 / jh_kim)

로컬에서 빌드한 main 코드를 **dev DB + dev Keycloak(jh_kim 계정)** 으로 E2E 검증한다.
2026-06-12 #2327 검증에서 실증된 절차 그대로다.

## e2e-test(로컬) 스킬과의 선택 기준

| 상황 | 스킬 |
|------|------|
| 로컬 Docker Keycloak 시드 계정(admin)으로 충분 | `e2e-test` |
| **jh_kim 실계정·dev 실데이터 필요 / dev API에 미배포된 main 코드 검증** | **이 스킬** |

## 고정 환경 정보

| 항목 | 값 |
|------|-----|
| dev 서버 | `AI_server` (ssh alias, 100.119.99.90) |
| dev Keycloak | `http://auth.invigoworks.co.kr:9090` (로컬 직접 미도달 → `--connect-to` 필수) |
| 계정 | 저장소 루트 `.env`(git-ignored)의 `GAP_E2E_USERNAME` / `GAP_E2E_PASSWORD` / `GAP_E2E_CLIENT_ID` |
| org_id | `019e9186-ef38-7110-8e3a-82808d567949` |
| 토큰 수명 | 1800s — 만료 시 401, 재로그인 |
| DB 계정 | `bitda_api` (dev 컨테이너 env에서 추출. **jh_kim 개인 DB계정 금지** — 신규 테이블 grant 누락으로 500) |

## 워크플로우

### 1단계: dev API 배포 버전 확인 (필수 분기)

```bash
ssh AI_server "docker exec bitda-api sh -c 'unzip -p /app/app.jar BOOT-INF/classes/git.properties' | grep -E 'commit.id.abbrev|branch'"
git log origin/main --oneline -1
```

- dev 배포 커밋 == 검증 대상 커밋 → **dev API(100.119.99.90:8080) 직접 테스트 가능**
  (단 토큰 issuer가 `https://auth.invigoworks.co.kr/realms/bitda` 여야 함 — 4단계 참고)
- 다르면 (예: infra/* 브랜치 배포 중) → **2~3단계로 로컬 API 기동 필수**

### 2단계: 로컬 API 기동 (dev DB + issuer override)

```bash
# 8080 점유 확인 — OrbStack Helper의 CLOSED 소켓은 무시 (LISTEN만 확인)
lsof -nP -iTCP:8080 -sTCP:LISTEN

nohup bash .claude/skills/e2e-test-dev/scripts/start-api-devdb.sh > /tmp/api_server.log 2>&1 &

# 준비 대기 (actuator 8081)
until curl -s -m 2 http://localhost:8081/actuator/health | grep -q '"status":"UP"'; do sleep 3; done
```

스크립트가 처리하는 함정 (수동 기동 시에도 동일 적용):
- `spring.flyway.enabled=false` — local 프로파일 seed가 dev DB 오염 방지
- DB 계정 `bitda_api` (비번은 `ssh AI_server docker exec bitda-api env` 에서 자동 추출)
- `--no-daemon` — orphan JVM = 500 유령 방지
- issuer-uri는 auth 호스트, jwk-set-uri는 IP 직접

### 3단계: dev Keycloak 로그인 (PKCE)

```bash
bash .claude/skills/e2e-test-dev/scripts/dev-login.sh
# → /tmp/bitda-e2e/access_token.txt
```

내장 함정 처리 (스크립트가 모두 처리하나, 디버깅 시 인지 필요):
1. **direct access grant 금지** — `grant_type=password` 는 `unauthorized_client`. PKCE auth-code flow만 가능
2. **호스트 통일** — Keycloak frontend URL이 auth.invigoworks.co.kr 고정. IP로 auth 페이지를 받으면 form action 호스트가 달라 쿠키 불일치 **400**, auth 호스트 직접 접속은 로컬서 미도달 **hang** (기존 e2e-test keycloak-login.sh가 step3에서 무한대기하는 원인)
3. 해법 = 전체 플로우 URL을 auth 호스트로 + `--connect-to "auth.invigoworks.co.kr:9090:100.119.99.90:9090"` (zsh에서 배열로 전달 — unquoted 변수는 분할 안 됨)

### 4단계: API 호출

```bash
T=$(cat /tmp/bitda-e2e/access_token.txt)
curl -s -H "Authorization: Bearer $T" "http://localhost:8080/api/v1/..."
```

- POST/PATCH 는 `Idempotency-Key: $(uuidgen)` 헤더 필수
- 토큰 issuer 주의: 이 플로우의 토큰 iss = `http://auth.invigoworks.co.kr:9090/realms/bitda`.
  dev API 직접 호출 시엔 `INVALID_ISSUER` (dev API는 `https://...` 무포트 기대) —
  dev API 직접 테스트면 `https://auth.invigoworks.co.kr` (443, 공개 도달 가능)로 토큰 발급

### 5단계: 테스트 케이스 계획 및 승인

`e2e-test` 스킬과 동일: 케이스 표로 정리 → **dev DB 실데이터 쓰기 발생 명시** → 사용자 승인 후 실행.

### 6단계: 픽스처가 필요한 경우

- attachment 등 S3 연동 픽스처: 로컬 garage가 죽어있어 API 업로드 불가 →
  **dev DB 직접 INSERT** (`status='CONFIRMED'`, 용도별 purpose). 쓰기경로 검증은 DB row만으로 충분
  ```bash
  ssh AI_server "docker exec bitda-postgres psql -U bitda_api -d bitda -t -A -c \"INSERT ... RETURNING id;\""
  ```
- 생성한 픽스처 ID는 기록해두고 테스트 후 원복(soft delete)

### 7단계: 결과 저장 + 원복

- 결과: `docs/e2e-test/{test-name}/README.md` + `responses/` (e2e-test 스킬 형식)
- **dev DB 원복 필수**: 테스트로 생성/변경한 행 복원. API로 안 되면 DB 직접 정리
  - 알려진 케이스: `PATCH work-status {"barrelLots": []}` 전체삭제는 422 INVALID_REFERENCE → DB DELETE로 정리
- 서버 종료: `pkill -f bootRun; pkill -f BitdaApiApplication`

## 트러블슈팅

| 증상 | 원인 / 해법 |
|------|------------|
| 로그인 step3 무한 hang | auth.invigoworks.co.kr 미도달 — `--connect-to` 누락 |
| 로그인 400 Bad Request | 쿠키 호스트 불일치 — 플로우 전체를 auth 호스트로 통일 |
| `unauthorized_client` | direct grant 시도 — PKCE로 |
| API 500 `...테이블에 대한 접근 권한 없음` | DB 계정이 jh_kim 개인계정 — bitda_api로 |
| API 401 `INVALID_ISSUER` | 토큰 iss와 서버 issuer-uri 불일치 — 2단계 override 확인 |
| 갑자기 전부 401 | 토큰 만료(1800s) — 3단계 재실행 |
| `user_not_found` | 로컬 Keycloak에 jh_kim 시도 — jh_kim은 dev 전용 |

## 주의

- dev DB는 **공유 자원** — 파괴적 쿼리 금지, 시드 데이터 변경 시 반드시 원복, DROP/TRUNCATE 절대 금지
- bitda_api DB 비번·토큰을 결과 문서에 남기지 말 것
