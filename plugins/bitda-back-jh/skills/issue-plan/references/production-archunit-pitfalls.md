# 생산관리 ArchUnit·네이밍 함정 (Production ArchUnit Pitfalls)

> **목적**: 생산 도메인 PR에서 ArchUnit 네이밍/상속 위반으로 가장 많이(19+ 커밋) 반복된
> `/jenkins-ci-loop` 실패를 설계 단계에서 차단한다. 모든 규칙은 grep 탐지 가능 + 예외 명시.
>
> **근거 커밋**: fe6153266, 50d0b2a34, a72aa28aa, 9994ffc6a, f09b16846, 4df07f2b9,
> 007b78514, e24bdd090, 9ca5f1bce, e488f8f12, 4011d95d2, db2b8d004, f0e090878.
>
> **정책 출처**: `docs/standards/arch-test-policy.md`, CLAUDE.md §4. 위반 시 `:modules:support:arch-test:test` FAIL.

---

## A1. 수량 필드는 `Qty`, `Quantity` 금지 (value-object-policy §3.2)

수량 의미 필드/프로퍼티는 `qty`/`Qty` 접미사. `quantity`/`Quantity`를 필드명으로 쓰면
`NamingConventionArchTest`가 FAIL (실 사례 `disposalQuantity`→`disposalQty`).

**탐지:**
```bash
grep -rnE 'val [a-zA-Z]*[Qq]uantity\b|var [a-zA-Z]*[Qq]uantity\b' \
  modules/application/core/src/main/kotlin/com/invigoworks/bitda/application/production --include='*.kt'
```

**예외 (위반 아님):**
- `Quantity` **VO 타입** 자체 (`val qty: Quantity` — 타입명은 OK, 필드명만 규제).
- `NamingConventionArchTest`의 마이그레이션 화이트리스트 클래스.
- 메서드명 `parseQuantity()` 등 (필드 아님).

**근거**: fe6153266, 50d0b2a34.

---

## A2. UseCase 인터페이스는 `UseCase<Input, Output>` 상속 (Output nullable도 허용)

`application.{query,command}`의 `XxxUseCase` 인터페이스는 마커 `UseCase<I, O>`를 상속하고
`override fun execute`. **반환이 nullable이어도 `UseCase<Cmd, XxxResult?>`로 상속 가능하다** —
nullable이라 못 쓴다고 오해해 상속을 붙였다 뗐다 한 회귀(db2b8d004↔f0e090878)가 반복됐다.

**탐지** (상속이 다음 줄로 줄바꿈되므로 줄바꿈을 제거하고 한 줄로 매칭):
```bash
for f in modules/application/core/src/main/kotlin/com/invigoworks/bitda/application/production/{query,command}/*UseCase.kt; do
  tr '\n' ' ' < "$f" | grep -qE "interface +\w+UseCase[^{]*: *UseCase<" || echo "NO-MARKER: $(basename $f)"
done
# 출력이 비면 전부 마커 상속 → 통과
```

**예외 (위반 아님):**
- `execute`의 파라미터 **이름**은 base와 달라도 됨 (Kotlin 허용). 이름 맞추려 리네임 금지.
- Service 구현체(`XxxService`)는 UseCase 인터페이스만 상속하면 됨 (마커 직접 상속 불필요).
- 마커가 면제된 특수 인터페이스(arch-test 화이트리스트, KDoc에 사유 명시).

**근거**: 50d0b2a34, 9994ffc6a, 9ca5f1bce, db2b8d004, f0e090878. 실예: `UpdateLotExpirationUseCase : UseCase<UpdateLotExpirationCommand, UpdatedLotInfoResult?>`.

---

## A3. UseCase 동사 접두사는 승인 목록만 — `Start`/`Begin` 금지, `Initiate` 사용

`NamingConventionArchTest` 동사 화이트리스트에 `Initiate`/`Initialize`는 있으나 `Start`는 없다.
"활동 시작" UseCase는 `Initiate*`. (실 사례 `StartProductionPlanDetailUseCase`→`InitiateProductionPlanDetailUseCase`.)

**탐지:**
```bash
ls modules/application/core/src/main/kotlin/com/invigoworks/bitda/application/production/{command,query}/ \
  | grep -E '^(Start|Begin|Do)[A-Z].*UseCase\.kt$'
```

**예외 (위반 아님):**
- **Command 클래스명**은 `Start*` 허용 (UseCase 인터페이스명만 규제).
- Service 구현 클래스명이 Command에서 파생된 경우.
- 화이트리스트에 실제 포함된 동사로 시작하는 경우 (arch-test의 승인 목록 확인).

**근거**: f09b16846. 동사 목록: `NamingConventionArchTest.kt` 내 `Initiate/Initialize/Complete...`.

---

## A4. 출력 데이터 클래스는 `Result`/`Query` 접미사 + `application.xx.query` 패키지

UseCase 출력 data class는 `Result`(또는 조회입력 `Query`) 접미사이고 `query` 패키지에 위치한다.
`Data` 접미사(`GanttBarData`) 또는 접미사 누락(`CompletionStatus`)은 arch FAIL.
command UseCase의 출력 Result도 **`query` 패키지**에 둔다.

**탐지:**
```bash
# command 패키지에 Result 클래스가 잘못 위치
find modules/application/core/src/main/kotlin/com/invigoworks/bitda/application/production/command \
  -name '*Result.kt'
# query 패키지 data class가 Result/Query/Ref/Row 접미사 없음
ls modules/application/core/src/main/kotlin/com/invigoworks/bitda/application/production/query/*.kt \
  | grep -vE '(Result|Query|Criteria|Ref|Row|Summary|UseCase|Service)\.kt$'
```

**예외 (위반 아님):**
- `XxxRef`(경량 참조), `XxxRow`(엑셀행), `XxxCriteria`(검색조건) 접미사.
- Command 입력 클래스(`XxxCommand`)는 `command` 패키지 유지.
- arch-test 화이트리스트의 보조 enum/range 타입.

**근거**: 9994ffc6a(Data→Result), a72aa28aa(Query 접미사), c955bad66·db2b8d004(query 패키지 이동).
