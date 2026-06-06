# 정적 계약 Diff (L1) — Swagger ↔ FE types.ts 자동 대조

> Stage 1 병렬 발굴 **이전**에 돌리는 기계적 그물.
> BE Swagger(api-docs.json) ↔ FE Request 타입(types.ts)을 필드 단위로 diff하여
> 구조적 갭(필드 부재·타입 불일치·required 불일치)을 후보로 자동 추출한다.
> 에이전트 추론 없이 grep/jq로 잡으므로 싸고 빠르다 (구조갭 70~80% 커버).
> 여기서 나온 것도 **후보**일 뿐 — Stage 2 직렬 verifier로 확정한다.

## 입력 소스

| 소스 | 경로 | 비고 |
|------|------|------|
| BE 계약 | `/tmp/bitda-swagger-snapshot/{최신ts}/api-docs.json` | swagger-snapshot 스킬 산출. 없으면 먼저 실행 |
| FE 계약 (실서비스) | `/Users/gimjinhyeog/Desktop/coding/bitda-front/packages/services/**/types.ts` | `export interface *Request` |
| FE 계약 (목업 폴백) | `plan-master/apps/liquor/src/**/*Sheet.tsx` `z.object({...})` | 실서비스 없는 도메인만 |

> ⚠️ **실 FE 레포는 `bitda-front`** (plan-master 아님). plan-master/data/bitda-front는 복사본.
> Request 계약 1차 소스는 `bitda-front/packages/services/**/types.ts`.

## 실행 절차

### 1. 최신 swagger 스냅샷 확보
```bash
SNAP=$(ls -dt /tmp/bitda-swagger-snapshot/*/ 2>/dev/null | head -1)
[ -z "$SNAP" ] && echo "스냅샷 없음 → swagger-snapshot 스킬 먼저 실행" || echo "$SNAP"
API_DOCS="${SNAP}api-docs.json"
```

### 2. BE Request 스키마 추출 (jq)
엔드포인트별 requestBody 스키마명 → 필드 + required:
```bash
# 특정 Request 스키마의 필드/required (예: CreateFactoryRequest)
jq '.components.schemas.CreateFactoryRequest | {required, props: (.properties|keys)}' "$API_DOCS"

# 전체 Request 스키마 목록
jq -r '.components.schemas | keys[] | select(test("Request$"))' "$API_DOCS"

# 엔드포인트 → Request 스키마명 매핑
jq -r '.paths | to_entries[] | .key as $p | .value | to_entries[]
  | select(.key|test("post|put|patch"))
  | "\(.key|ascii_upcase) \($p) -> \(.value.requestBody.content."application/json".schema."$ref" // "inline")"' "$API_DOCS"
```

### 3. FE Request 타입 추출
```bash
FE=/Users/gimjinhyeog/Desktop/coding/bitda-front/packages/services
# Request interface 전부 + 필드
grep -rn "export interface.*Request" "$FE" --include="types.ts"
# 특정 도메인 types.ts 직접 Read (필드 + optional? 정확히)
```

### 4. 3-way diff (필드 단위)
이름 매칭된 BE Request ↔ FE Request 쌍마다:

| 검사 | 갭 조건 | 갭 유형 |
|------|---------|---------|
| **필드 부재(BE→FE)** | BE props/required에 있는데 FE interface에 없음 | BE 기능 FE 미사용 (역방향, 보통 N/A 많음) |
| **필드 부재(FE→BE)** | FE가 보내는데 BE Request 스키마에 없음 | ❌ write 막힘 후보 (High) |
| **타입 불일치** | FE `number` ↔ BE `string` (또는 반대), UUID ↔ string | ⚠️ silent 파싱 버그 후보 |
| **required 불일치** | BE `required` 배열에 있는데 FE optional/누락 | ⚠️ 400 후보 |

> 핵심: **FE→BE 필드 부재**가 가장 가치 큰 갭 (예: isActive — FE 폼 submit하나 BE CreateXxxRequest props에 없음).
> 검증법: `jq '.components.schemas.CreateFactoryRequest.properties | keys' "$API_DOCS"`에 `isActive` 없으면 후보.

## 추가할 핵심 규칙 3종 (점진 도입)

### LR1. FE→BE 필드 부재 (High)
FE types.ts(또는 폼 schema)가 submit하는 필드가 BE Request swagger props에 없음.
- 탐지: FE 필드 목록 − BE `properties` keys = 차집합 비어있지 않음
- **N/A 예외** (crud-roundtrip-matrix §5와 동일): ①자동채번(code) ②생성기본값+토글(isActive — 단 FE 폼 submit 포함 시 갭) ③전용엔드포인트(sortOrder)

### LR2. 타입 불일치 (Medium, silent)
같은 이름 필드의 BE swagger type ↔ FE TS type 불일치.
- 탐지: `number` vs `string`, `boolean` vs `string`, UUID(`string` format uuid) vs 일반 string
- **예외**: BigDecimal은 BE가 `string`/`number` 양쪽 가능(Jackson 설정) — L1은 후보만, 확정은 Stage 2/L3(동적)
- **예외**: FE가 `string`으로 받아 즉시 `Number()` 변환하면 무해 — Stage 3 사람판단

### LR3a. required 불일치: BE 필수 ↔ FE 선택 (Medium)
BE `required` 배열 필드를 FE가 optional(`field?`)로 선언하거나 미전송 → 400 후보.
- 탐지: BE required − FE non-optional 필드 = 비어있지 않음
- **예외**: BE default 값 존재 필드(`@Schema default`)는 미전송해도 무해 → N/A
- **예외**: FE가 항상 채워 보내는 필드(submit handler 확인)면 타입만 optional이고 실제 전송 → N/A

### LR3b. required **역방향** 불일치: 기획/FE 필수 ↔ BE nullable·미검증 (High)
> ⚠️ **이 방향이 #2069를 놓친 결함.** 생산계획 등록에서 factoryId/equipmentId/processId/taskId/warehouseId/estimatedWorkHours가 **기획(목업 폼) 필수**인데 BE Request가 전부 `nullable`이라, 다 빼고도 201로 불완전 생산계획이 등록됨. LR3a(단방향)만 보면 영영 못 잡는다.

**FE 폼(zod schema)/기획서의 필수 필드가 BE Create/Update Request에서 nullable 또는 `@NotNull` 미시행** → 불완전 데이터 저장 허용.
- 탐지:
  1. FE 필수 필드 수집: 목업 Sheet의 zod schema에서 **물음표 없는**(필수) 필드 + page.tsx onSubmit body 포함 필드
     ```bash
     grep -A30 "z.object\|useForm" $MOCK/{domain}/components/*Sheet.tsx   # 필수=물음표 없음
     ```
  2. BE Request 필드/nullable 수집: `Create/Update*Request.kt` 소스 또는 swagger
     ```bash
     jq '.components.schemas.CreateXxxRequest | {required, props:(.properties|keys)}' "$API_DOCS"
     ```
  3. 판정: **FE 필수 필드 ∉ BE required**(또는 BE props에서 `nullable:true`) → LR3b 갭
- **N/A 예외** (crud-roundtrip-matrix §5와 동일): ①자동채번(code) ②생성기본값+토글분리(isActive — 단 FE 폼 onSubmit에 포함되면 N/A 아님=진짜 갭) ③전용엔드포인트(sortOrder via reorder)
- **확정**: Stage 2 verifier가 목업 Sheet zod schema를 직접 Read하여 해당 필드가 FE 필수+submit 포함인지 확인. 맞으면 **CONFIRMED High**.
- 출력 행 예시:
  ```
  | 3 | POST /production-plans | factoryId | zod 필수+onSubmit 포함 | Request nullable | FE필수↔BE nullable | — | LR3b High |
  | 4 | POST /production-plans | isActive | zod optional+onSubmit 미포함 | nullable | active-status 별도 엔드포인트 | N/A | — |
  ```

## 예외 / 한계 (오탐 방지)

1. **production 5종(factory/equipment/vessel/process/task)은 bitda-front 서비스 패키지 없음** → L1 적용 불가. 이 도메인은 L2(plan-master 목업 Sheet schema ↔ BE Request 소스 대조)로만. (production-inbound는 서비스 존재 → L1 가능)
2. **BE에만 있는 스키마**(admin/batch 전용 Request)는 FE 미사용이 정상 → FE→BE 방향만 갭, BE→FE 부재는 대부분 N/A.
3. **inline schema**(드묾): `$ref` 없이 requestBody에 직접 정의된 건 jq 추출 안 됨 → 소스 Read 폴백.
4. **동작 갭은 L1 불가**: "isActive 값 무시하고 항상 true 저장" 같은 서비스 로직, invariant, cross-field 검증은 swagger에 안 나옴 → L2(소스)/L3(E2E).
5. L1 산출은 전부 **후보** — Stage 2 직렬 verifier 3관문 통과해야 CONFIRMED.

## L1 출력 형식
```
## L1 정적 계약 Diff 결과 (후보)
| # | 엔드포인트 | 필드 | FE | BE(swagger) | 유형 | N/A? | 후보 |
|---|-----------|------|----|-----------|------|------|------|
| 1 | POST /factories | isActive | 폼 submit O | props 없음 | FE→BE부재 | 폼포함→N/A아님 | LR1 High |
| 2 | PATCH /materials | unitPrice | string | number | 타입불일치 | — | LR2 Med |
적용 불가 도메인(서비스 없음): factory/equipment/vessel/process/task → L2로 이관
```
