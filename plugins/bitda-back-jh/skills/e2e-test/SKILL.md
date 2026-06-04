---
name: e2e-test
description: |
  실제 API 서버(8080 포트)를 실행하고 Keycloak OAuth 인증을 통해 E2E API 테스트를 수행하는 스킬입니다.
  테스트 결과와 요청/응답을 docs/e2e-test/{test}/ 디렉토리에 markdown 형식으로 기록합니다.
  이 스킬은 다음 상황에서 사용됩니다:
  - 특정 API의 실제 동작을 테스트하고 싶을 때
  - API 변경 후 실제 환경에서 검증이 필요할 때
  - 사용자가 "E2E 테스트", "API 테스트", "/e2e-test" 등을 요청할 때
---

# E2E API Test

실제 API 서버(8080 포트)와 Keycloak 인증을 사용하여 E2E API 테스트를 수행하고, 결과를 `docs/e2e-test/` 디렉토리에 기록하는 스킬.

## 사용 시점

- 특정 API 엔드포인트의 실제 동작을 확인하고 싶을 때
- 로컬 환경에서 API 통합 테스트가 필요할 때
- API 변경 사항을 실제 요청/응답으로 검증할 때

## 전제 조건

- **Docker 엔진(OrbStack) 실행 중**이어야 함. OrbStack 앱이 떠 있어도 엔진이 꺼져 있을 수 있음 → `orbctl start` 후 `docker ps`로 확인.
- Docker 인프라(PostgreSQL, Keycloak)가 실행 중이어야 함. **반드시 local override 포함 기동**:
  ```bash
  cd docker && docker compose -f docker-compose.yml -f docker-compose.local.yml -p bitda up -d
  ```
  > ⚠️ `./docker/start.sh`(plain `docker compose up -d`) 금지. 자동 병합되는 `docker-compose.override.yml`(dev 서버용)이 (1) 네트워크 subnet 미고정 → OrbStack가 192.168.x 할당 → `pg_hba.conf`(172.16/12만 허용)가 keycloak/infra 인증 거부, (2) Keycloak SPI(`BITDA_API_BASE_URL`)를 운영서버로 보내 로그인이 timeout(curl 28)된다. `docker-compose.local.yml`이 subnet을 172.20.0.0/16로 고정하고 SPI를 `host.docker.internal:8080`로 교정한다.
- **API 서버는 반드시 8080 포트**로 실행해야 함 (Keycloak SPI가 고정 포트 참조)
- 테스트에 사용할 Keycloak 사용자 계정이 있어야 함

## 워크플로우

### 1단계: 테스트 정보 수집 (필수)

**사용자에게 다음 정보를 반드시 확인한다:**

#### 1-1. Keycloak 앱 선택 (3개 중 1개)

| 앱 | Client ID | 용도 |
|----|-----------|------|
| **관리자 앱** | `bitda-admin-app` | 관리자용 기능 테스트 |
| **주류 앱** | `bitda-liquor-app` | 주류 업체용 기능 테스트 |
| **제조 앱** | `bitda-manufact-app` | 제조업체용 기능 테스트 |

#### 1-2. 테스트 계정 정보

- **이메일(username)**: 예) `admin@invigoworks.co.kr`
- **비밀번호**: 예) `dlsqlrhdnjrtm1!`

#### 1-3. 테스트할 API 범위

- 예) "창고 CRUD 전체", "제품 목록 조회", "GET /api/v1/warehouses" 등

### 2단계: 인프라 및 서버 상태 확인

```bash
# Docker 엔진 확인 (OrbStack 엔진이 꺼져 있으면 시작)
docker ps >/dev/null 2>&1 || { orbctl start; for i in {1..30}; do docker ps >/dev/null 2>&1 && break; sleep 2; done; }

# Docker 인프라 확인
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "keycloak|postgres"

# 인프라 미기동 시 local override 포함 기동 (전제 조건 참조)
# cd docker && docker compose -f docker-compose.yml -f docker-compose.local.yml -p bitda up -d
# 서브넷 확인: docker network inspect bitda-infra --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'  → 172.20.0.0/16 이어야 함

# API 서버 실행 여부 확인 (8080 포트)
if curl -s "http://localhost:8081/actuator/health" | grep -q '"status"'; then
    echo "API_SERVER_ALREADY_RUNNING=true"
else
    echo "API_SERVER_ALREADY_RUNNING=false"
fi
```

> **중요**: `API_SERVER_ALREADY_RUNNING` 값을 기억해둔다. 스킬 종료 시 서버 정리 여부를 결정하는 데 사용.

### 3단계: API 서버 시작 (필요 시)

**`API_SERVER_ALREADY_RUNNING=true`인 경우 이 단계를 건너뛴다.**

```bash
# API 서버 시작 스크립트
cat > /tmp/start_api.sh << 'EOF'
#!/bin/bash
cd "$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || echo /Users/gimjinhyeog/Desktop/coding/bitda-back)"
export JWT_ALLOWED_AUDIENCES=bitda-api-server,bitda-admin-app,bitda-liquor-app,bitda-tax-app,bitda-manufact-app
export KEYCLOAK_API_SERVER_CLIENT_ID=bitda-api-server
export KEYCLOAK_API_SERVER_CLIENT_SECRET=bitda-api-server-secret-12345
# POSTGRES_USER/PASSWORD: 로컬 DB의 bitda_api 계정 자격증명.
# 비번이 안 맞으면("password 인증 실패") superuser invigoworks로 재설정:
#   docker exec bitda-postgres psql -U invigoworks -d bitda -c "ALTER USER bitda_api WITH PASSWORD 'bitda_api_dlsqlrhdnjrtm1!';"
export POSTGRES_USER=bitda_api
export POSTGRES_PASSWORD='bitda_api_dlsqlrhdnjrtm1!'
export INTERNAL_API_KEY=local-internal-api-key-12345
export GARAGE_ACCESS_KEY=test-access-key
export GARAGE_SECRET_KEY=test-secret-key
./gradlew :modules:application:api:bootRun --args='--spring.profiles.active=local'
EOF
chmod +x /tmp/start_api.sh
nohup /tmp/start_api.sh > /tmp/api_server.log 2>&1 &

# 준비 대기 (actuator port: 8081)
for i in {1..60}; do
  curl -s "http://localhost:8081/actuator/health" | grep -q '"status"' && break
  sleep 2
done
```

### 4단계: Keycloak 로그인

```bash
bash .claude/skills/e2e-test/scripts/keycloak-login.sh <username> <password> <client_id>
```

#### 토큰 캐싱 기능

로그인 스크립트는 계정+클라이언트 조합별로 토큰을 캐싱합니다:
- **캐시 위치**: `/tmp/bitda-e2e/token-cache/`
- **캐시 키**: `{username}_{client_id}`의 MD5 해시
- **유효성**: 토큰 만료 60초 전까지 재사용
- **강제 재로그인**: `--force` 옵션 사용

```bash
# 캐시된 토큰 사용 (기본)
bash .claude/skills/e2e-test/scripts/keycloak-login.sh user@example.com password bitda-admin-app

# 강제 재로그인
bash .claude/skills/e2e-test/scripts/keycloak-login.sh user@example.com password bitda-admin-app --force
```

> **팁**: 여러 계정으로 테스트할 때 각 계정의 토큰이 별도로 캐싱되어 빠르게 전환 가능

### 5단계: 테스트 케이스 계획 및 승인 (필수)

**테스트 실행 전 반드시 사용자 승인을 받는다.**

#### 5-1. 테스트 케이스 목록화

`TaskCreate` 도구를 사용하여 테스트 케이스를 Task로 등록한다:

```
예시:
- Task 1: [GET] 목록 조회 - /api/v1/warehouses
- Task 2: [POST] 생성 - /api/v1/warehouses
- Task 3: [GET] 단건 조회 - /api/v1/warehouses/{id}
- Task 4: [PATCH] 수정 - /api/v1/warehouses/{id}
- Task 5: [DELETE] 삭제 - /api/v1/warehouses/{id}
- Task 6: [POST] 예외 - 중복 코드로 생성 시 409 Conflict
```

#### 5-2. 사용자 확인

`TaskList`로 전체 테스트 케이스를 보여주고, 사용자에게 확인을 요청한다:

```markdown
## 테스트 케이스 목록

| # | 메서드 | API | 설명 | 예상 결과 |
|---|--------|-----|------|----------|
| 1 | GET | /api/v1/warehouses | 목록 조회 | 200 OK |
| 2 | POST | /api/v1/warehouses | 생성 | 201 Created |
| 3 | GET | /api/v1/warehouses/{id} | 단건 조회 | 200 OK |
| 4 | PATCH | /api/v1/warehouses/{id} | 수정 | 200 OK |
| 5 | DELETE | /api/v1/warehouses/{id} | 삭제 | 204 No Content |
| 6 | POST | /api/v1/warehouses | 중복 코드 | 409 Conflict |

위 테스트 케이스로 진행할까요? (추가/수정/삭제 가능)
```

#### 5-3. 승인 후 진행

- 사용자가 **승인**하면 6단계로 진행
- 사용자가 **수정 요청**하면 Task 목록 업데이트 후 재확인
- 사용자가 **취소**하면 8단계(정리)로 이동

### 6단계: API 테스트 수행

승인된 테스트 케이스를 순차적으로 실행한다.

각 테스트 케이스 실행 시:
1. `TaskUpdate`로 해당 Task를 `in_progress`로 변경
2. API 호출 수행
3. 결과 확인 후 `TaskUpdate`로 `completed`로 변경

저장된 토큰을 사용하여 API 호출:

```bash
ACCESS_TOKEN=$(cat /tmp/bitda-e2e/access_token.txt)
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" "http://localhost:8080/api/v1/..."
```

### 7단계: 결과 저장

**저장 위치**: `docs/e2e-test/{test-name}/`

디렉토리 구조:
```
docs/e2e-test/{test-name}/
├── README.md              # 테스트 결과 요약 (reference 형식)
├── files/                 # import/export에 사용된 파일
│   ├── import-sample.xlsx
│   └── export-result.xlsx
└── responses/             # 각 테스트 케이스별 상세 응답 (선택적)
    └── case-01-response.json
```

### 8단계: 정리 (Cleanup)

**스킬 종료 전 반드시 실행한다.**

```bash
# API 서버 정리 (스킬에서 시작한 경우에만)
if [ "$API_SERVER_ALREADY_RUNNING" = "false" ]; then
    # 스킬에서 시작한 서버 종료
    API_PID=$(lsof -ti :8080)
    if [ -n "$API_PID" ]; then
        kill $API_PID
        echo "API server stopped (PID: $API_PID)"
    fi
else
    echo "API server was already running - skipping cleanup"
fi
```

| 조건 | 동작 |
|------|------|
| `API_SERVER_ALREADY_RUNNING=false` | 스킬에서 시작한 서버 → **종료** |
| `API_SERVER_ALREADY_RUNNING=true` | 기존 실행 중인 서버 → **유지** |

---

## 결과 문서 형식 (Reference)

`docs/e2e-test/{test-name}/README.md` 파일은 반드시 아래 형식을 따른다:

```markdown
# E2E Test: {테스트 이름}

## 테스트 정보

| 항목 | 값 |
|------|-----|
| **테스트 일시** | 2024-02-14 16:45:00 |
| **테스트 환경** | local (8080 포트) |
| **Keycloak 앱** | bitda-admin-app |

## 로그인 계정 정보

| 항목 | 값 |
|------|-----|
| **이메일** | admin@invigoworks.co.kr |
| **User ID** | 018b6421-8400-78d3-a9c9-61519d3070d2 |
| **Organization ID** | {조직 ID 또는 N/A} |
| **역할(Roles)** | ADMIN, OWNER |
| **권한(Permissions)** | inventory:read, inventory:write, ... |

## 테스트 결과 요약

| # | API | 메서드 | 결과 | 비고 |
|---|-----|--------|------|------|
| 1 | /api/v1/warehouses | GET | ✅ 성공 | 목록 조회 |
| 2 | /api/v1/warehouses | POST | ✅ 성공 | 생성 |
| 3 | /api/v1/warehouses/{id} | GET | ✅ 성공 | 단건 조회 |
| 4 | /api/v1/warehouses/{id} | PATCH | ✅ 성공 | 수정 |
| 5 | /api/v1/warehouses/{id} | DELETE | ✅ 성공 | 삭제 |
| 6 | /api/v1/warehouses | POST | ❌ 실패 | 중복 코드 (예외 케이스) |

## 상세 테스트 케이스

### Case 1: 창고 목록 조회

**Request:**
\`\`\`http
GET /api/v1/warehouses?page=0&size=10
Authorization: Bearer {token}
\`\`\`

**Response:** `200 OK`
\`\`\`json
{
  "data": {
    "content": [...],
    "totalElements": 5
  }
}
\`\`\`

### Case 2: 창고 생성 (정상)

**Request:**
\`\`\`http
POST /api/v1/warehouses
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "테스트 창고",
  "code": "TEST-001"
}
\`\`\`

**Response:** `201 Created`
\`\`\`json
{
  "data": "550e8400-e29b-41d4-a716-446655440000"
}
\`\`\`

### Case 3: 창고 생성 - 예외 케이스 (중복 코드)

**Request:**
\`\`\`http
POST /api/v1/warehouses
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "중복 창고",
  "code": "TEST-001"
}
\`\`\`

**Response:** `409 Conflict`
\`\`\`json
{
  "error": "DUPLICATE_WAREHOUSE_CODE",
  "message": "이미 존재하는 창고 코드입니다: TEST-001"
}
\`\`\`

## Import/Export 테스트 (해당 시)

### Import 테스트

**사용 파일:** `files/import-sample.xlsx`

| 파일명 | 행 수 | 결과 |
|--------|-------|------|
| import-sample.xlsx | 100 | ✅ 98건 성공, 2건 실패 |

**실패 상세:**
- Row 45: 필수 필드 누락 (name)
- Row 78: 잘못된 형식 (date)

### Export 테스트

**결과 파일:** `files/export-result.xlsx`

## 예외 케이스 검증

| # | 케이스 | 예상 에러 | 실제 에러 | 결과 |
|---|--------|----------|----------|------|
| 1 | 인증 없이 요청 | 401 Unauthorized | 401 | ✅ |
| 2 | 권한 없는 사용자 | 403 Forbidden | 403 | ✅ |
| 3 | 존재하지 않는 리소스 | 404 Not Found | 404 | ✅ |
| 4 | 잘못된 입력값 | 400 Bad Request | 400 | ✅ |
| 5 | 중복 데이터 | 409 Conflict | 409 | ✅ |
```

## 환경 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `KEYCLOAK_URL` | `http://localhost:9090` | Keycloak 서버 URL |
| `REALM` | `bitda` | Keycloak Realm |
| `API_PORT` | `8080` | API 서버 포트 (고정) |
| `ACTUATOR_PORT` | `8081` | Actuator 포트 |

## 사용 가능한 Keycloak 앱

| Client ID | 앱 이름 | 용도 |
|-----------|---------|------|
| `bitda-admin-app` | 관리자 앱 | 시스템 관리자용 |
| `bitda-liquor-app` | 주류 앱 (B&Bitda) | 주류 업체용 |
| `bitda-manufact-app` | 제조 앱 (M&Bitda) | 제조업체용 |

## 트러블슈팅

### 로그인 실패: service_error

API 서버(8080 포트)가 실행 중이지 않음. Keycloak SPI가 API 서버를 호출하므로 먼저 실행 필요.

### 로그인 [3/4] 단계에서 timeout (curl exit 28)

credential submit 단계에서 멈춤 = Keycloak SPI가 API 서버를 잘못된 주소로 호출. plain `docker compose up -d`로 dev override가 병합되어 `BITDA_API_BASE_URL`이 운영서버(`https://api-bitda.invigoworks.co.kr`)로 설정된 것이 원인.
**해결**: `docker-compose.local.yml` 포함해 인프라 재기동 (전제 조건 참조). 확인: `docker exec bitda-keycloak printenv | grep BITDA_API_BASE_URL` → `http://host.docker.internal:8080` 이어야 함.

### Keycloak 부팅 실패: `pg_hba.conf` 인증 거부 / `UnknownHostException: postgres`

bitda-infra 네트워크 subnet이 172.16/12 대역 밖(예: OrbStack 192.168.x)이라 `pg_hba.conf`가 infra_keycloak/infra_debezium 접속을 거부. 또는 컨테이너를 compose 없이 `docker start`해 네트워크 alias가 유실됨.
**해결**: `docker-compose.local.yml` 포함해 stack 재기동(subnet 172.20 고정). pg_hba.conf를 직접 수정하지 말 것(증상 땜질).

### DB 인증 실패: `사용자 "bitda_api"의 password 인증을 실패했습니다`

로컬 DB의 bitda_api 계정 비번이 start_api.sh의 `POSTGRES_PASSWORD`와 불일치.
**해결**: superuser로 재설정 — `docker exec bitda-postgres psql -U invigoworks -d bitda -c "ALTER USER bitda_api WITH PASSWORD 'bitda_api_dlsqlrhdnjrtm1!';"` (postgres 볼륨에 영속).

### 8080 포트 사용 중

```bash
# 포트 사용 프로세스 확인
lsof -i :8080

# 필요시 종료
kill -9 <PID>
```

### 토큰 만료

토큰은 자동으로 만료 60초 전에 갱신됩니다. 수동으로 갱신하려면:

```bash
# 자동 갱신 (캐시된 토큰이 만료 직전이면 새로 발급)
bash .claude/skills/e2e-test/scripts/keycloak-login.sh <username> <password> <client_id>

# 강제 재발급
bash .claude/skills/e2e-test/scripts/keycloak-login.sh <username> <password> <client_id> --force
```

### 캐시 초기화

모든 캐시된 토큰을 삭제하려면:

```bash
rm -rf /tmp/bitda-e2e/token-cache/
```

## 주의사항

- **8080 포트 고정**: Keycloak SPI가 고정 포트를 참조하므로 반드시 8080 사용
- **서버 생명주기 관리**: 스킬에서 시작한 서버만 종료, 기존 실행 중인 서버는 유지
- 테스트 데이터는 로컬 DB에 실제로 생성됨
- 결과 문서에서 민감 정보(토큰 전체, 비밀번호)는 마스킹할 것
- import/export 테스트 시 사용한 파일은 반드시 `files/` 디렉토리에 보관
