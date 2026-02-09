---
name: swagger-snapshot
description: |
  Bitda API 서버를 임시 포트로 기동하여 Swagger(/v3/api-docs) JSON을 수집하고
  임시 폴더에 저장하는 스킬입니다. 수집된 스냅샷은 후속 스킬의 입력 데이터로 활용됩니다.
  이 스킬은 다음 상황에서 사용됩니다:
  - Swagger JSON 스냅샷이 필요할 때
  - API 문서 동기화 전 최신 API 명세를 수집할 때
  - 사용자가 "swagger 스냅샷", "API 스냅샷", "api-docs 수집" 등을 요청할 때
---

# Swagger Snapshot

Bitda API 서버를 사용하지 않는 임시 포트로 기동하여 `/v3/api-docs` Swagger JSON을 수집하고, 타임스탬프 기반 임시 폴더에 저장하는 스킬.

## 사용 시점

- Swagger JSON 스냅샷을 수집해야 할 때
- 후속 스킬 실행 전 최신 API 명세가 필요할 때
- API 문서 변경 사항을 확인하고 싶을 때

## 전제 조건

- Docker 인프라(PostgreSQL, Keycloak)가 실행 중이어야 함 (`./docker/start.sh`)
- 컨테이너가 없으면 스크립트가 **사용자에게 보고하고 즉시 종료**됨 (자동 실행하지 않음)
- Gradle 빌드가 가능한 상태여야 함

## 워크플로우

### 1단계: 스크립트 실행

`scripts/swagger-snapshot.sh` 스크립트를 실행하여 자동으로 처리:

```bash
bash .claude/skills/swagger-snapshot/scripts/swagger-snapshot.sh
```

스크립트가 수행하는 작업:
1. OS에서 사용 가능한 빈 포트 2개를 자동 할당 (앱 포트, 관리 포트)
2. 환경 변수를 설정하고 `local` 프로필로 Spring Boot 앱을 백그라운드 기동
3. Actuator health check로 앱 준비 상태 대기 (최대 120초)
4. `http://localhost:{port}/v3/api-docs` 에서 Swagger JSON 수집
5. `/tmp/bitda-swagger-snapshot/{YYYYMMDD_HHMMSS}/` 에 저장
6. Spring Boot 앱을 graceful shutdown

### 2단계: 결과 확인

스크립트 종료 후 마지막 줄에 `SNAPSHOT_DIR=...` 형태로 경로가 출력됨.

출력 디렉토리 구조:
```
/tmp/bitda-swagger-snapshot/{timestamp}/
├── api-docs.json         ← Swagger JSON (핵심 파일)
├── snapshot-meta.json    ← 메타 정보 (포트, 프로필, 타임스탬프)
└── boot.log              ← Spring Boot 기동 로그 (문제 발생 시 디버깅용)
```

### 3단계: 후속 스킬에 전달

수집된 `api-docs.json` 경로를 후속 스킬에 전달하여 입력 데이터로 활용.

## 환경 변수

스크립트에 기본값이 내장되어 있어 별도 설정 없이 실행 가능. 필요 시 환경 변수로 오버라이드:

| 변수 | 기본값 |
|------|--------|
| `JWT_ALLOWED_AUDIENCES` | `bitda-api-server,bitda-admin-app,bitda-liquor-app,bitda-manufact-app` |
| `KEYCLOAK_API_SERVER_CLIENT_ID` | `bitda-api-server` |
| `KEYCLOAK_API_SERVER_CLIENT_SECRET` | `bitda-api-server-secret-12345` |
| `POSTGRES_USER` | `bitda_api` |
| `POSTGRES_PASSWORD` | `bitda_api_dlsqlrhdnjrtm1!` |

## 트러블슈팅

### 앱이 기동 중 종료되는 경우
- Docker 인프라 실행 여부 확인: `docker ps` → PostgreSQL, Keycloak 컨테이너 확인
- `boot.log` 확인: `cat /tmp/bitda-swagger-snapshot/{timestamp}/boot.log | tail -100`

### 120초 내 준비되지 않는 경우
- Flyway 마이그레이션이 오래 걸릴 수 있음 → `boot.log`에서 마이그레이션 진행 상태 확인
- 포트 충돌 가능성 → 스크립트가 자동으로 빈 포트를 찾으므로 일반적으로 발생하지 않음

## 주의사항

- 스크립트 종료 시 Spring Boot 앱은 자동으로 종료됨 (trap 설정)
- 비정상 종료 시에도 cleanup이 동작하여 프로세스가 남지 않음
- `/tmp/bitda-swagger-snapshot/` 하위에 타임스탬프별로 저장되므로 이전 스냅샷도 보존됨
