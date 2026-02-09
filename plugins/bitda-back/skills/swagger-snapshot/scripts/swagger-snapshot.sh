#!/usr/bin/env bash
# swagger-snapshot.sh
# Spring Boot API 앱을 임시 포트로 기동 → /v3/api-docs 수집 → 임시 폴더에 저장 → 앱 종료
#
# 사용법: ./swagger-snapshot.sh [PROJECT_ROOT]
# 결과:  SNAPSHOT_DIR 경로를 stdout 마지막 줄에 출력

set -euo pipefail

PROJECT_ROOT="${1:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
GRADLE="$PROJECT_ROOT/gradlew"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SNAPSHOT_DIR="/tmp/bitda-swagger-snapshot/$TIMESTAMP"
LOG_FILE="$SNAPSHOT_DIR/boot.log"

# ── 환경 변수 기본값 (이미 설정되어 있으면 덮어쓰지 않음) ──
export JWT_ALLOWED_AUDIENCES="${JWT_ALLOWED_AUDIENCES:-bitda-api-server,bitda-admin-app,bitda-liquor-app,bitda-manufact-app}"
export KEYCLOAK_API_SERVER_CLIENT_ID="${KEYCLOAK_API_SERVER_CLIENT_ID:-bitda-api-server}"
export KEYCLOAK_API_SERVER_CLIENT_SECRET="${KEYCLOAK_API_SERVER_CLIENT_SECRET:-bitda-api-server-secret-12345}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-bitda_api_dlsqlrhdnjrtm1!}"
export POSTGRES_USER="${POSTGRES_USER:-bitda_api}"

# ── Docker 컨테이너 사전 검증 (없으면 보고 후 즉시 종료) ──
MISSING_CONTAINERS=()

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "postgres"; then
  MISSING_CONTAINERS+=("PostgreSQL")
fi

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "keycloak"; then
  MISSING_CONTAINERS+=("Keycloak")
fi

if [ ${#MISSING_CONTAINERS[@]} -gt 0 ]; then
  echo "ERROR: 필수 Docker 컨테이너가 실행되고 있지 않습니다."
  echo ""
  for c in "${MISSING_CONTAINERS[@]}"; do
    echo "  - $c"
  done
  echo ""
  echo "먼저 Docker 인프라를 실행해주세요: ./docker/start.sh"
  exit 1
fi

echo ">>> Docker 컨테이너 확인 완료 (PostgreSQL, Keycloak)"

# ── 사용 가능한 포트 찾기 ──
find_free_port() {
  local port
  # Python으로 OS에게 빈 포트를 할당받음 (가장 안전)
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')
  echo "$port"
}

APP_PORT=$(find_free_port)
MGMT_PORT=$(find_free_port)

echo "=== Bitda Swagger Snapshot ==="
echo "Project Root : $PROJECT_ROOT"
echo "App Port     : $APP_PORT"
echo "Mgmt Port    : $MGMT_PORT"
echo "Snapshot Dir : $SNAPSHOT_DIR"

mkdir -p "$SNAPSHOT_DIR"

# ── Spring Boot 앱 기동 ──
echo ">>> Starting Spring Boot (profile=local, port=$APP_PORT)..."

"$GRADLE" -p "$PROJECT_ROOT" :modules:application:api:bootRun \
  --args="--spring.profiles.active=local --server.port=$APP_PORT --management.server.port=$MGMT_PORT" \
  > "$LOG_FILE" 2>&1 &

APP_PID=$!
echo ">>> App PID: $APP_PID"

# ── 클린업 트랩 (스크립트 종료 시 앱 반드시 종료) ──
cleanup() {
  if kill -0 "$APP_PID" 2>/dev/null; then
    echo ">>> Shutting down Spring Boot (PID=$APP_PID)..."
    kill "$APP_PID" 2>/dev/null || true
    # graceful shutdown 대기 (최대 15초)
    for i in $(seq 1 15); do
      if ! kill -0 "$APP_PID" 2>/dev/null; then
        break
      fi
      sleep 1
    done
    # 아직 살아있으면 강제 종료
    if kill -0 "$APP_PID" 2>/dev/null; then
      echo ">>> Force killing (PID=$APP_PID)..."
      kill -9 "$APP_PID" 2>/dev/null || true
    fi
    echo ">>> Spring Boot stopped."
  fi
}
trap cleanup EXIT

# ── Health Check 대기 (최대 120초) ──
echo ">>> Waiting for app to be ready..."
MAX_WAIT=120
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
  # 앱이 죽었는지 확인
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "ERROR: App exited unexpectedly. Check $LOG_FILE"
    tail -50 "$LOG_FILE"
    exit 1
  fi

  # Health check (actuator)
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$MGMT_PORT/actuator/health" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "200" ]; then
    echo ">>> App is ready! (took ${ELAPSED}s)"
    break
  fi

  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
  echo "ERROR: App did not become ready within ${MAX_WAIT}s. Check $LOG_FILE"
  tail -50 "$LOG_FILE"
  exit 1
fi

# ── Swagger JSON 수집 ──
echo ">>> Fetching /v3/api-docs..."

HTTP_CODE=$(curl -s -o "$SNAPSHOT_DIR/api-docs.json" -w "%{http_code}" "http://localhost:$APP_PORT/v3/api-docs")

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: Failed to fetch api-docs (HTTP $HTTP_CODE)"
  exit 1
fi

# JSON 유효성 검사
if ! python3 -m json.tool "$SNAPSHOT_DIR/api-docs.json" > /dev/null 2>&1; then
  echo "ERROR: api-docs.json is not valid JSON"
  exit 1
fi

# ── 메타 정보 저장 ──
cat > "$SNAPSHOT_DIR/snapshot-meta.json" <<METAEOF
{
  "timestamp": "$TIMESTAMP",
  "appPort": $APP_PORT,
  "profile": "local",
  "sourceProject": "$PROJECT_ROOT",
  "files": {
    "apiDocs": "api-docs.json",
    "bootLog": "boot.log"
  }
}
METAEOF

# ── 요약 출력 ──
API_COUNT=$(python3 -c "
import json, sys
with open('$SNAPSHOT_DIR/api-docs.json') as f:
    data = json.load(f)
paths = data.get('paths', {})
total = sum(len(methods) for methods in paths.values())
print(f'Paths: {len(paths)}, Operations: {total}')
")

echo ""
echo "=== Snapshot Complete ==="
echo "APIs       : $API_COUNT"
echo "File       : $SNAPSHOT_DIR/api-docs.json"
echo "Meta       : $SNAPSHOT_DIR/snapshot-meta.json"
echo "Boot Log   : $SNAPSHOT_DIR/boot.log"
echo ""
echo "SNAPSHOT_DIR=$SNAPSHOT_DIR"
