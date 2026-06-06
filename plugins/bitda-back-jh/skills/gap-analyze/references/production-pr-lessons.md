# Production PR Lessons — production/BOM 갭 탐지 규칙

> **출처**: 머지된 production/BOM PR 82개 마이닝(2026-06). "Prepub CRUD 빈틈+완전 상이"
> 피드백 직후 실제로 사후 수정된 갭을 사전 탐지 규칙으로 역추출.
> Agent C/D 실행 시 production·BOM·생산계획·공정현황 도메인이면 이 파일을 Read하여
> 아래 규칙을 추가 점검한다. (마스터 A~I 체크리스트와 병행)
>
> 모든 경로 기준: `BACK=/Users/gimjinhyeog/Desktop/coding/bitda-back`

---

## J-RI. Soft-Delete & 참조 무결성

### RI1. 참조검증 쿼리 soft-delete 필터 누락 (High) — #1927, #1803
삭제 전 "사용 중" 검증(`existsByXxx`)이 이미 soft-delete된 행까지 세어 잘못된 차단/허용.
```bash
grep -rn "existsBy\|countBy" $BACK/modules/infrastructure/src/main/kotlin \
  --include="*Adapter.kt" -A2 | grep -iv "deletedAt\|deleted_at"
```
**예외**: `reconstitute()` 로드 경로, `*Test.kt`, `@Query` native SQL(이미 `AND deleted_at IS NULL` 포함).

### RI2. 참조검증 organizationId 필터 누락 (High) — #1924
참조 무결성 검증 시 테넌트 격리 빠져 타 조직 데이터로 오판.
```bash
grep -rn "existsBy\|findByIdAnd" $BACK/modules/infrastructure/src/main/kotlin \
  --include="*Adapter.kt" -A2 | grep -iv "organizationId"
```
**예외**: `@PreAuthorize("hasRole('ADMIN')")` 시스템 API, 내부 도메인 간 Port 참조.

### RI3. 생성 시 선택 마스터 soft-delete 검증 누락 (High) — #1927
`CreateXxxService`가 선택한 factory/equipment/material의 삭제 여부 미검증 → 죽은 마스터로 생성.
```bash
grep -rn "class Create.*Service" $BACK/modules/application/core/src/main/kotlin \
  --include="*.kt" -A25 | grep -iE "DeletedAtIsNull|require.*deleted|check.*active"
```
없으면 갭. **완화**: `findByIdAndOrganizationIdAndDeletedAtIsNull()` 호출 있으면 PASS.
**예외**: 마스터 참조 없는 단순 생성, 테스트.

### RI4. 삭제 시 orphan FK cascade 정리 누락 (High) — #1927
부모 soft-delete 시 자식(WorkOrder.productionPlanDetailId 등) orphan 방치.
```bash
grep -rn "class Delete.*Service" $BACK/modules/application/core/src/main/kotlin \
  --include="*.kt" -A12 | grep -iE "publishEvent|DomainEvent|ApplicationEvent"
```
이벤트 발행 없으면 갭 후보. **예외**: ADR/docs/standards에 "cascade 무시(운영 정책)" 명시, 자식 없는 aggregate.

### RI5. Cascade fallback parent 필터 누락 (High) — #1939
마스터 삭제 cascade가 parent aggregate(materialId 등) 미한정 → cross-material 오염.
```bash
grep -rn "class Delete.*Service\|fun cascade\|fallback" $BACK/modules/application/core/src/main/kotlin \
  --include="*.kt" -A8 | grep -iv "materialId\|parentId\|aggregateId"
```
**예외**: 의도적 전체 일괄 정책(메서드명 `deleteForAll*`/ADR 문서화), 테스트.

---

## J-DB. DB 마이그레이션/제약

### DB1. Flyway 버전 중복/누락 (High) — #1857, #1731
```bash
find $BACK/modules/infrastructure/src -name "V*.sql" -exec basename {} \; \
  | sed 's/__.*//' | sort | uniq -d
```
출력 있으면 버전 충돌 갭. **예외**: 의도적 repeatable(`R__`) 마이그레이션.

### DB2. enum 값 변경 ↔ CHECK 제약 미동기화 (High) — #1901, #511
enum 이름/값 변경(PLANNED→SCHEDULED) 후 Flyway CHECK 제약 미갱신.
```bash
grep -rn "enum class .*Status" $BACK/modules/domain/src/main/kotlin --include="*.kt"
grep -rn "CHECK" $BACK/modules/infrastructure/src/main/resources/db/migration --include="*.sql"
```
enum 값 변경 PR인데 CHECK 갱신 마이그레이션 없으면 갭. **예외**: CHECK 미사용(앱 레벨 검증) 정책, enum 신규 추가(기존 값 불변).

### DB3. FK ON DELETE 정책 미정의 (Medium) — #1902
```bash
grep -rn "FOREIGN KEY\|REFERENCES" $BACK/modules/infrastructure/src/main/resources/db/migration \
  --include="*.sql" | grep -iv "ON DELETE"
```
**예외**: soft-delete 엔티티(앱 레벨 RESTRICT), 다대다 교차테이블(CASCADE 기본).

---

## J-API. API 계약/에러/직렬화

### API1. DataIntegrityViolation 상태 코드 (Medium) — #1855
DB 제약 위반을 500이 아닌 409(CONFLICT)로 매핑하는지.
```bash
grep -rn "DataIntegrityViolation\|ConstraintViolation" $BACK/modules/application/api/src/main/kotlin \
  --include="*ExceptionHandler*.kt" -A3 | grep -i "CONFLICT\|409"
```
없으면 갭. **예외**: CHECK 위반(400), `@Valid` 실패(400).

### API2. 제한 검증 예외 타입 (High) — #1835
API 계층 제한 초과(BOM 최대 10개 등)를 `require()`(→500) 아닌 `BusinessException`(→400)으로.
```bash
grep -rn "require(" $BACK/modules/application/core/src/main/kotlin --include="*Service.kt" \
  | grep -iE "size|count|max|limit|<=|>="
```
**예외**: `domain/` 모델 내부 invariant require()(도메인 논리, 별도 매핑), API의 `@Min/@Max`.

### API3. Response 필드명 ↔ JSON 키 불일치 (Medium) — #1914
FE 기대 JSON 키와 DTO 필드명 다른데 `@JsonProperty` 미명시 → FE undefined.
FE `types.ts` 키와 BE `*Response.kt` val 명을 직접 대조. 다르면 `@JsonProperty` 필요.
```bash
grep -rLn "@JsonProperty\|@JsonNaming" \
  $(grep -rln "data class .*Response" $BACK/modules/application/api/src/main/kotlin --include="*.kt")
```
**예외**: FE↔BE 필드명 동일(글로벌 네이밍 전략 자동 매핑), 내부 Result.

### API4. Summary/통계가 목록 필터 미반영 (Medium) — #1957
목록 API 필터(keyword/status)가 summary/count 응답엔 적용 안 되어 통계 부정확.
```bash
grep -rn "summariz\|countBy\|Summary" $BACK/modules/infrastructure/src/main/kotlin \
  --include="*Adapter.kt" -A4 | grep -iv "buildWhere\|booleanBuilder\|predicate"
```
**예외**: 조직 전체 dashboard summary(필터 무관 의도), 캐시된 집계.

### API5. 비상관(cross) JOIN 데이터 중복 (High) — #1917
QueryDSL `leftJoin`에 `on()` 술어 없으면 cross join → 행 중복.
```bash
grep -rn "leftJoin\|innerJoin" $BACK/modules/infrastructure/src/main/kotlin \
  --include="*Adapter.kt" -A2 | grep -v "\.on("
```
**예외**: `.on()`이 다음 줄 분리, 연관관계 기반 path join. 의심 시 count 비교 단위테스트로 확정.

---

## J-FIELD. 필드 전파 / DTO 일관성

### FIELD-REQ. Create/Update Request DTO 필드 부재 — 오탐 완화 + isActive 함정 (High↔N/A) — 2026-06 공정설정

FE 생성/수정 폼(Sheet)이 submit하는 필드가 BE `*Request.kt`에 없을 때. **이슈화 전 N/A 3종 확인**:

**① 자동채번** — `code`/`lotNumber`/`serialNumber`/`productionCode`
- 확인: `code-generation-policy.md` 대상 + `XxxCodeNumberFactory` 구현체 존재
- 채번 정책이면 FE 전송해도 BE 수신 경로 없는 게 설계 → **N/A**

**② 생성 기본값 + 토글 전용 엔드포인트 — 🚨 조건부**
- 해당: `isActive`, `isEnabled`
- 확인: 생성 Service `isActive = true` 고정 + `ChangeActiveStatus`/`active-status` 엔드포인트 존재
- **그러나 N/A 단정 금지** — FE 생성/수정 Sheet의 onSubmit이 isActive를 submit하면 **진짜 ❌ 갭**:
```bash
# FE Sheet 폼 schema에 isActive 있나
grep -n "isActive" $FE/apps/liquor/src/{domain}/components/*Sheet.tsx
# page.tsx onSubmit이 createX/updateX에 {...data} 넘기나 (data에 isActive 포함)
grep -n "createX\|updateX\|handleSubmit\|{...data}" $FE/apps/liquor/src/{domain}/page.tsx
# BE Create/Update Request에 isActive 있나
grep -c "isActive" <(awk '/data class Create.*Request\(/,/^\)/' $BACK/.../*Request.kt)
```
- 폼이 보내고 BE 미수용 → 비활성 생성 불가 / 수정폼 활성토글 저장 불가 = **High**. 행목록 빠른토글(`updateX(id,{isActive:!x})`)은 별개 — 혼동 금지.

**③ 전용 엔드포인트 분리** — `sortOrder`/`displayOrder`
- 확인: KDoc "Reorder API 사용" 또는 `@PatchMapping(".../reorder")` 존재 → **N/A**

**CONFIRMED 조건**: 3종 해당 없음(②는 폼 submit 포함 시 갭) + BE `*Request.kt` 직접 Read로 필드 부재 눈으로 확인.
또한 **Update Request에 `name` 부재**도 흔한 갭(수정폼 이름 변경 불가) — Factory/Equipment/Vessel Update Request에서 발생.

### FP1. Request→Command→Service→Response 전파 끊김 (High) — #1954
신규 필드(unitTagId 등)가 Request엔 있으나 Command/Service.build()/Response 어딘가 누락(write 미연결).
수동 추적: 신규 필드 1개를 잡아 4계층 grep.
```bash
F=unitTagId   # 점검 필드로 치환
grep -rn "$F" $BACK/modules/application/api/src/main/kotlin   # Request/Response
grep -rn "$F" $BACK/modules/application/core/src/main/kotlin  # Command/Service
grep -rn "$F" $BACK/modules/domain/src/main/kotlin            # Domain
```
한 계층이라도 0건이면 전파 끊김 갭. **예외**: 읽기 전용 파생 필드(Response만), 쓰기 전용(Request만, audit).

### FP2. @Schema 문서 누락 (Medium) — #1891, #1882
API Request/Response DTO에 `@Schema` 설명 없어 Swagger 불완전.
```bash
grep -rLn "@Schema" \
  $(grep -rln "data class .*Request\|data class .*Response" $BACK/modules/application/api/src/main/kotlin --include="*.kt")
```
**예외**: 상속 필드(부모 DTO에 `@Schema`), `application/core`의 internal Command/Query/Result.

### FP2b. @Schema description 한글 설명 누락 (Medium)
`@Schema`는 있으나 `description`이 **없거나 빈 문자열이거나 한글이 아님** → Swagger 스키마 설명이 비어 FE/문서·노션 동기화 무용.
FP2(어노테이션 자체 누락)와 구분: 어노테이션은 붙었는데 **설명 내용이 비었거나 영문뿐**인 케이스.

(1) 코드 검사 — `@Schema(`인데 `description=` 인자 없는 것:
```bash
grep -rn "@Schema(" $BACK/modules/application/api/src/main/kotlin --include="*.kt" \
  | grep -v "description\s*="
```
(2) 코드 검사 — `description`은 있으나 값에 한글(가-힣) 없음(영문/플레이스홀더):
```bash
grep -rno "@Schema([^)]*description\s*=\s*\"[^\"]*\"" $BACK/modules/application/api/src/main/kotlin \
  --include="*.kt" | grep -Pv "[가-힣]"
```
(3) 스웨거 스냅샷 직접 검사 (가장 확실) — api-docs.json 수집 후 description 빈/누락 필드:
```bash
# swagger-snapshot[-remote] 스킬로 api-docs.json 수집한 뒤:
jq -r '.components.schemas | to_entries[] | .key as $s | .value.properties // {} | to_entries[]
  | select((.value.description // "") | test("[가-힣]") | not)
  | "\($s).\(.key): \(.value.description // "<없음>")"' api-docs.json
# 출력된 필드 = swagger에 한글 설명 없는 스키마 프로퍼티 → 갭 후보
```
**판정**: FE/노션 문서화에 노출되는 Request/Response DTO 필드인데 한글 description 없으면 갭(Medium).
**예외**: `id`/`createdAt` 등 자명한 공통 필드(팀 정책상 설명 생략 허용), internal Command/Query/Result, enum 값 자체.
> Stage 2 관문2에서 확정: 해당 `*Response.kt`/`*Request.kt` 직접 Read하여 `@Schema(description=...)` 한글 여부 눈으로 확인. 스냅샷만으로 확정 금지(구버전 스냅샷 가능성).

### FP3. enum 크기 하드코딩 (Medium) — #1735
`size == 4`, `entries.size` 고정 비교 → enum 추가 시 동기화 실패.
```bash
grep -rn "\.entries\.size\|\.values()\.size\|size == [0-9]" $BACK/modules/application/core/src/main/kotlin \
  --include="*.kt"
```
**예외**: 정책 상수로 중앙화, 테스트 단언.

---

## J-CUT. Cutover (JSONB → 테이블 전환)

### CUT1. Dual-Write 트랜잭션 원자성 (High) — #1926
JSONB와 신규 테이블 동시 쓰기가 단일 트랜잭션 경계 안에 있는지(부분 쓰기 불일치 방지).
```bash
grep -rn "dual.write\|JSONB\|jsonb" $BACK/modules/infrastructure/src/main/kotlin \
  --include="*Adapter.kt" -B2 -A4 | grep -i "save\|persist"
```
별도 트랜잭션/이벤트 분리면 outbox·feature-flag 보장 확인. **예외**: eventually-consistent outbox 설계, 읽기 전용.

### CUT2. Cutover Phase 단계 추적 (Medium) — #1930
JSONB→테이블 cutover가 write/read/legacy-remove 단계 중 어디인지 미추적 → 롤백 경로 불명확.
탐지: cutover 진행 PR이면 read cutover 완료 + 레거시 제거 여부 확인.
**예외**: 완료된 cutover, 비-JSONB 단순 마이그레이션. (참고 메모: 단위 테이블 cutover 상태)

---

## 오탐 방지 요약

| 규칙 | 흔한 오탐 | 완화 |
|------|---------|------|
| RI1 | `@Query` native SQL 내 `deleted_at` | `@Query` 라인 제외 |
| RI1/API5 | `reconstitute()`·테스트·다음줄 분리 | `*Test.kt` 제외, 인접 라인 확인 |
| RI2 | admin/내부 Port 참조 | `@PreAuthorize ADMIN` 확인 |
| RI5 | 의도적 전체 일괄 정책 | 메서드명 `*ForAll*`/ADR |
| API2 | domain require()(도메인 논리) | `domain/` 경로 제외, `application`만 |
| FP2 | 상속 필드·internal DTO | `extends` 확인, `api/src`로 한정 |
| FP2b | `id`/`createdAt` 등 자명 공통필드·enum값·구버전 스냅샷 | 공통필드 제외, 현 HEAD `*Response.kt` 직접 Read |
| API4 | dashboard summary 의도적 무필터 | 클래스/메서드명 구분 |

> 판정 원칙: 규칙 매칭 = **후보**일 뿐. Agent C가 실제 코드를 열어 예외 해당 여부를 확인하고,
> Agent D가 FE 시나리오에서 실제 영향 있는 것만 갭으로 승격한다. 매칭만으로 이슈 생성 금지.
