# 동적 검증 (L3) — E2E 실호출로 silent mismatch 탐지

> L1(정적 diff)·L2(소스 추론)가 못 잡는 **동적◎ 갭(~19%)** 표적 검증.
> 실제 API를 호출해 **응답 JSON 실측**으로 "필드는 있는데 값/형태가 FE 기대와 다른"
> silent mismatch를 잡는다. 전수 호출 금지 — 의심 도메인 대표 시나리오만.
> 산출물도 **후보** — Stage 2 직렬 verifier로 확정.

## 언제 L3를 돌리나 (표적 조건)

전수 E2E 금지. 다음 중 하나일 때만 해당 엔드포인트 표적 호출:
- L1에서 **타입 불일치(LR2)** 후보가 나옴 (BigDecimal/Instant/UUID 직렬화 실측 필요)
- FE 타입이 `nullable` 의존인데 BE `@JsonInclude` 불명 (S8 null vs 미포함)
- enum 필드가 FE union ↔ BE LabeledEnum (S3 직렬화 문자열 실측)
- 삭제/상태전이 시 에러 메시지 한글 노출 여부 (E4)
- QueryDSL leftJoin 행 중복 의심 (API5)

## 전제 / 인프라

| 항목 | 값 |
|------|----|
| API 서버 | `http://localhost:8080` (고정, Keycloak SPI 참조) |
| Keycloak | `http://localhost:9090` realm `bitda` |
| 토큰 캐시 | `/tmp/bitda-e2e/access_token.txt` |
| 로그인 스크립트 | `.claude/skills/e2e-test/scripts/keycloak-login.sh <user> <pw> <client>` |

> Docker 인프라(`./docker/start.sh`) + API 8080 기동 필요. 미기동 시 e2e-test 스킬 절차 참조.

## 자격증명 로딩 (.env)

**계정은 절대 하드코딩 금지.** 루트 `.env`에서 로딩 (`.gitignore`로 커밋 차단됨):
```bash
cd /Users/gimjinhyeog/Desktop/coding/bitda-back
set -a; source .env; set +a   # GAP_E2E_USERNAME / GAP_E2E_PASSWORD / GAP_E2E_CLIENT_ID
[ -z "$GAP_E2E_USERNAME" ] && { echo ".env에 GAP_E2E_* 없음 → .env.example 참조해 작성"; exit 1; }
```

## 실행 절차

### 1. 로그인 (토큰 획득)
```bash
bash .claude/skills/e2e-test/scripts/keycloak-login.sh \
  "$GAP_E2E_USERNAME" "$GAP_E2E_PASSWORD" "$GAP_E2E_CLIENT_ID"
TOKEN=$(cat /tmp/bitda-e2e/access_token.txt)
```

### 2. 표적 라운드트립 (생성→조회 1사이클)
의심 도메인 대표 1건만:
```bash
# 예: 생성
curl -s -X POST "http://localhost:8080/api/v1/{domain}" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{...최소필드...}' | tee /tmp/gap-l3-create.json
# 예: 조회 (응답 JSON 실측 대상)
curl -s "http://localhost:8080/api/v1/{domain}/{id}" \
  -H "Authorization: Bearer $TOKEN" | tee /tmp/gap-l3-get.json
```

### 3. 동적 어서션 (응답 JSON ↔ FE 기대 형태)
| 검사 | jq 명령 | 갭 조건 |
|------|---------|---------|
| **DV1 Instant 포맷** | `jq -r '.data.createdAt' f.json` | `Z` 끝 ISO-8601 아니고 epoch millis면 갭 |
| **DV2 BigDecimal 형태** | `jq '.data.qty\|type' f.json` | FE가 number 기대인데 `"string"`이면 silent 버그 |
| **DV3 null vs 미포함** | `jq 'has("expirationDate")' f.json` | FE가 `field === null` 의존인데 키 자체 없으면(false) 갭 |
| **DV4 enum 직렬화** | `jq -r '.data.status' f.json` | FE union 값과 대소문자/언더스코어 다르면 갭 (예 FE `IN_PROGRESS` vs BE `inProgress`) |
| **DV5 응답 래퍼** | `jq 'keys' f.json` | FE가 `data.content` 기대인데 실제 `data`만 / 반대면 갭 |
| **DV6 에러 메시지** | `curl 실패케이스 \| jq -r '.message'` | 삭제/검증 실패 시 message가 null/영문/빈값이면 한글 갭(E4) |
| **DV7 JOIN 행중복** | `jq '.data.content\|length' vs 기대 count` | leftJoin 중복으로 행 부풀면 갭(API5) |

### 4. 정리 (테스트 데이터 롤백)
생성한 리소스는 DELETE로 정리하거나 테넌트 격리 확인. 잔여 데이터 방치 금지.

## 핵심 규칙 3종 (점진 도입)

### DV-SER. 직렬화 형태 불일치 (Medium, silent)
응답 JSON의 Instant/BigDecimal/UUID 실제 형태 ≠ FE 타입 기대.
- 탐지: DV1/DV2 jq 실측
- **예외**: FE가 수신 후 `new Date()`/`Number()` 변환하면 무해 → N/A
- **예외**: BigDecimal string은 정밀도 보존 의도일 수 있음 — FE 연산 코드 확인 후 판정

### DV-NULL. null vs 미포함 (Medium)
선택 필드가 응답에서 `null`인지 키 자체 누락인지 ≠ FE 처리 방식.
- 탐지: DV3 `has()` 실측
- **예외**: FE가 `data.field ?? x` (null·undefined 둘 다 처리)면 무해 → N/A

### DV-ENUM. enum 직렬화 문자열 (High)
BE LabeledEnum JSON 값 ≠ FE union 타입 문자열 (대소문자/언더스코어).
- 탐지: DV4 실측 후 FE union 정의와 정확 대조
- **예외**: FE가 enum 매핑 테이블로 변환하면 무해 → N/A

## 예외 / 한계

1. **인프라 미기동 시 L3 스킵** — Docker/API 8080 없으면 후보를 "동적검증 보류"로 표시, L1/L2 결과만 진행.
2. **쓰기 부작용 주의** — 생성/삭제 호출은 테스트 데이터 잔류 위험. 표적 최소화 + 정리 필수.
3. **L3는 표적 전용** — 전 엔드포인트 호출 금지. L1/L2가 의심 띄운 것만.
4. L3 산출도 후보 — Stage 2 직렬 verifier 3관문 통과해야 CONFIRMED.
5. 🚨 **stale-runtime 오탐 (2026-06 실증)** — 기동 중인 API가 **구버전 빌드**면 동적 결과가 거짓이다.
   - 전례: `POST /production-processes {isActive:false}` → 응답 `isActive:true`로 "생성 시 isActive 무시" 버그처럼 보였으나, 실제 소스(`toCommand` → Service → 도메인)는 전부 정상 연결. **기동 시각 < 소스 수정 시각**이라 런타임이 옛 코드였을 뿐.
   - **방어**: L3가 "동작 버그" 후보를 띄우면 Stage 2 verifier 관문2가 **반드시 현 HEAD 소스(Request.toCommand → Service → 도메인 create) 전 계층을 직접 Read**해 값 전파를 확인한다. 소스가 정상이면 → 오탐(stale runtime), REFUTED.
   - **사전 점검**: L3 실행 전 `기동 시각(api-boot.log "Started") vs 관련 *.kt 수정 시각(stat -f %Sm)` 비교. 기동이 더 오래됐으면 **재빌드 후 L3** (안 그러면 동작 갭 전부 신뢰 불가).
   - 직렬화/래퍼/포맷(DV1/DV5) 같은 **구조** 갭은 stale에 덜 민감(직렬화 설정은 잘 안 바뀜). **동작**(값 무시/기본값/상태전이) 갭만 stale 위험.

## L3 출력 형식
```
## L3 동적 검증 결과 (후보)
| # | 엔드포인트 | 필드 | 응답 실측 | FE 기대 | 검사 | 후보 |
|---|-----------|------|----------|---------|------|------|
| 1 | GET /work-status/{id} | createdAt | 1717459200000 | ISO-8601 Z | DV1 | DV-SER Med |
| 2 | GET /process-status/{id} | status | "inProgress" | "IN_PROGRESS" | DV4 | DV-ENUM High |
보류(인프라 미기동): [도메인 목록]
```
