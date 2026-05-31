# 생산관리 도메인 설계 함정 (Production Pitfalls)

> **목적**: 역대 생산관리 PR에서 `/jenkins-ci-loop` 단계로 반복 유출된 CI 실패를
> `/issue-plan` 설계 단계에서 미리 차단한다. 각 규칙은 grep/glob으로 탐지 가능하며
> PASS/FAIL 판정이 자동화된다.
>
> **적용 시점**: 이슈가 `modules/*/production/*` 또는 생산계획/작업지시/생산입고를
> 건드릴 때, Step 3 코드베이스 분석 중 이 문서를 Read로 로드하여 각 규칙을 플랜에 반영.
>
> **근거**: #1907(QueryDSL 필드명 4연속 컴파일 fixup + arch 상속 누락 + 상태 셋업),
> #1900(PLANNED→SCHEDULED enum), #1824(PUT→PATCH) 등.

---

## R1. QueryDSL Q-class 필드명은 도메인 엔티티 실제 프로퍼티명과 일치해야 한다

생산 어댑터에서 QueryDSL `Q클래스`(`QProductionPlanDetail` 등) 경로를 작성할 때
**추측한 필드명을 쓰면 `Unresolved reference` 컴파일 에러**가 난다. 실제 프로퍼티명을
도메인 엔티티에서 먼저 확인한다.

**확정된 실제 필드명 (혼동 주의):**

**중요 구분**: QueryDSL의 `process`/`item` 등은 **JPA Q엔티티**(`QProductionProcessJpaEntity`)이고,
`ProcessRef`/`ItemRef`는 **결과 VO**다. 둘은 필드 집합이 다르다 — Q엔티티에는 `code`가 있어도
VO 생성자에는 없을 수 있다. #1907의 실제 버그는 `ProcessRef(code = ...)`로 **VO에 없는 인자**를
넘긴 것이지 `process.code`(Q엔티티 접근, 정상) 자체가 아니다.

| ❌ 추측하기 쉬운 사용 | ✅ 실제 | 위치 |
|---------------------|--------|------|
| `planDetail.quantity` (Q엔티티) | `planDetail.qty` (`Quantity` VO) | `ProductionPlanDetail.qty` |
| `planDetail.code` (Q엔티티) | `planDetail.productionCode` (`String?`) | `ProductionPlanDetail.productionCode` |
| `ProcessRef(code = ...)` (VO 생성자) | `ProcessRef`는 `id`, `name`만 | `domain.shared.ProcessRef` |
| `item.spec` | `item.specification` | item 엔티티 |

**탐지** (플래닝 후 구현 코드 검증용):
```bash
# Q엔티티 경로에 quantity/code 오용 (qty/productionCode가 정답)
grep -rnE 'planDetail\.(quantity|code)\b' \
  modules/infrastructure/src/main/kotlin/com/invigoworks/bitda/infrastructure/persistence/production/**/*.kt
# VO 생성자에 존재하지 않는 인자(code) 전달 의심 — ProcessRef/ItemRef 호출부 수동 점검
grep -rnA3 'ProcessRef(' \
  modules/infrastructure/src/main/kotlin/com/invigoworks/bitda/infrastructure/persistence/production/**/*.kt | grep -n 'code ='
```

**예외 (위반 아님):**
- **Q엔티티의 `process.code`/`item.code` 접근은 정상** — `ProductionProcessJpaEntity.code` 컬럼이 실재한다.
- DTO/Result 클래스의 `quantity` 필드명 (Q엔티티가 아닌 일반 data class).
- 주석/KDoc 안의 `quantity` 텍스트.

> **설계 액션**: 플랜의 GREEN 단계에 "대상 엔티티 프로퍼티명을 `Read`로 확인 후
> Q클래스 경로 작성" 체크 항목을 명시한다.

---

## R2. 생산 시간 필드는 도메인 `LocalDate`/`Instant` 구분을 보존해야 한다

생산계획 detail의 날짜 필드는 타입이 혼재한다. Tuple→Result 매핑 시 타입을
잘못 변환하면 `Type mismatch` 컴파일 에러 또는 잘못된 시간값이 발생한다.

**확정된 타입:**
- `ProductionPlanDetail.expectedCompletionDate: LocalDate?` (날짜만, nullable)
- Aggregate Root 시간(생성/수정 등): `Instant` (CLAUDE.md temporal-data-policy)

**규칙**: `LocalDate?` → `Instant` 변환이 필요하면 명시적으로
`.atStartOfDay(ZoneOffset.UTC).toInstant()` 하고, **null 처리(`?:` fallback)를 반드시 포함**한다.

**탐지:**
```bash
# expectedCompletionDate를 non-null로 단정(!!)하거나 fallback 없이 변환
grep -rnE 'expectedCompletionDate!!|expectedCompletionDate\.atStartOfDay' \
  modules/infrastructure/src/main/kotlin/**/production/**/*.kt
```

**예외 (위반 아님):**
- 이미 `?.atStartOfDay(...)?...  ?: Instant.EPOCH` 형태로 null-safe 처리된 경우.
- 도메인 모델 내부에서 `LocalDate`를 그대로 보존하는 코드 (변환 자체가 없음).

> **설계 액션**: 플랜의 매핑 단계에 "날짜 필드 nullable + 타입(LocalDate vs Instant) 명시" 기재.

---

## R3. 생산 상태 enum의 기본값(SCHEDULED)과 조회 필터 기대값을 일치시켜야 한다

`ProductionPlanDetail.create()`는 항상 `status = SCHEDULED`로 생성된다.
`WorkOrderStatus`/`ProductionPlanDetailStatus` 모두 **`PLANNED` 값은 없다** (과거
`PLANNED`→`SCHEDULED` 리네임 #1900). "기존 코드 조회"처럼 `IN_PROGRESS`를 필터하는
기능은 테스트 셋업에서 `startWork()` 전이를 거쳐야 빈 결과가 안 난다.

**확정된 enum 값**: `SCHEDULED`, `IN_PROGRESS`, `COMPLETED` (+ WorkOrder는 `CANCELLED`).

**규칙:**
1. 코드/테스트에 `PLANNED` 사용 금지 (존재하지 않는 값 → `Unresolved reference`).
2. `IN_PROGRESS` 데이터를 조회하는 테스트는 `create()` 후 `startWork()`로 전이.

**탐지:**
```bash
# 존재하지 않는 PLANNED 참조 (생산 도메인)
grep -rnE '(WorkOrderStatus|ProductionPlanDetailStatus)\.PLANNED' modules
# IN_PROGRESS 필터 테스트인데 startWork 전이가 없는 경우 수동 점검
grep -rln 'IN_PROGRESS' modules/infrastructure/src/test/**/production/**/*.kt
```

**예외 (위반 아님):**
- 다른 도메인의 자체 enum이 `PLANNED`를 가진 경우 (생산 도메인 한정 규칙).
- `SCHEDULED` 상태만 조회/검증하는 테스트 (전이 불필요).
- DB migration의 CHECK 제약 문자열 (Kotlin enum 참조가 아님).

> **설계 액션**: 상태 조회 기능 플랜의 RED 단계에 "필터 대상 상태로 데이터 셋업
> (필요 시 상태 전이 메서드 호출)" 명시.

---

## R4. 엑셀 전건 조회는 표준 인터페이스 상속이 강제된다 (arch-test)

생산 엑셀 내보내기를 추가하면 ArchUnit이 인터페이스 상속을 강제한다. 누락 시
`arch-test` 모듈이 FAIL (#1907).

**규칙:**
1. `searchUnpaged`를 가진 `XXQueryRepository`는 `UnpagedSearchable<Q, R>` 상속 + `override`.
2. `application.{query,command}`의 `XXUseCase` 인터페이스는 `UseCase<Input, Output>` 상속 + `override`.

**탐지:**
```bash
# searchUnpaged 보유하나 UnpagedSearchable 미상속 의심
grep -rln 'fun searchUnpaged' modules/application/core/src/main/kotlin/**/port/*.kt \
  | xargs grep -L 'UnpagedSearchable'
# UseCase 인터페이스인데 base 미상속 의심
grep -rlnE 'interface \w+UseCase' modules/application/core/src/main/kotlin/**/{query,command}/*.kt \
  | xargs grep -L ': UseCase<'
```

**예외 (위반 아님):**
- `override fun execute(...)`의 파라미터 **이름**은 base와 달라도 됨 (Kotlin은 이름 불일치 허용).
  → 따라서 단지 이름 맞추려고 `query`→`input` 리네임 금지 (named-arg 호출 깨짐).
- Service **구현체**(`XXService`)는 인터페이스만 상속하면 되고 base 직접 상속 불필요.
- 페이지네이션 조회(`search`)만 있고 `searchUnpaged`가 없는 Repository.

> **설계 액션**: 엑셀 내보내기/신규 UseCase 플랜에 "표준 인터페이스 상속 + override" 항목 명시.
> 관련 정책: `docs/standards/excel-export-policy.md` §2.1, CLAUDE.md §4.1.
