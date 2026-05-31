# 생산관리 도메인·인프라·테스트 함정 (Production Domain Pitfalls)

> **목적**: 생산입고/LOT/정정·조회 어댑터·테스트에서 반복된 CI 실패를 설계 단계에서 차단.
> grep 탐지 가능 + 예외 명시. 위반은 컴파일/테스트 FAIL 또는 silent 데이터 누락을 유발.
>
> **근거 커밋**: c4d22b63a, fd525e531, 8a64a445e, 09c1833e4, b21876cb3, bcdbd63f4,
> 328114b5b, 007993adc, 61b950b76, bd44f5ecb, ba5a37cb6, 67ae88d81, 5c23ad28a.

---

## D1. 생산입고 정정 시 기존 LOT 번호 불변 (LOT Immutability)

정정(correction)에서 기존 항목의 LOT 번호는 **유지/재사용**한다. 새로 채번하면 추적성·
재고 정합성이 깨진다. 새 항목만 LOT 신규 채번 허용.

**탐지:**
```bash
grep -rln 'Correct.*Service' modules/application/core/src/main/kotlin/com/invigoworks/bitda/application/production/service \
  | xargs grep -L 'enforceOriginalLotNumbers\|originalLot'
```

**예외 (위반 아님):**
- 정정에서 **신규 추가**된 항목은 `createLotsAndBuildItems()`로 LOT 신규 채번.
- 정정이 아닌 최초 생산입고 등록(채번 자체가 정상 흐름).
- LOT 미사용 도메인의 정정.

**근거**: c4d22b63a, 09c1833e4, 1cf3165b4. CLAUDE.md 상태 전이 정책.

---

## D2. cancel→save→**flush** 순서로 UK 충돌 회피

번호 UK(`idx_*_org_number`)를 재사용/재삽입하는 정정·취소 흐름은 cancel 후 즉시 `flush()`
해야 한다. Hibernate가 INSERT를 UPDATE보다 먼저 배치하면 UK 충돌이 난다.

**탐지:**
```bash
grep -rnA3 '\.cancel\(\)' modules/application/core/src/main/kotlin/com/invigoworks/bitda/application/production --include='*.kt' \
  | grep -B1 'save' | grep -v 'flush'
```

**예외 (위반 아님):**
- cancel 없는 in-place 업데이트(`@Transactional` 경계로 충분).
- `saveAll` + 암묵 flush를 쓰는 배치 삭제.
- 번호 재사용이 없는 단순 상태 변경.

**근거**: 8a64a445e, fd525e531.

---

## D3. 상태 변경 후 결과는 실 DB 조회 — stub/emptyList 금지 (Silent Failure)

상태 변경(BulkComplete 등) 후 반환 데이터는 실제 Repository 조회로 채운다. `emptyList()`/
`null`/하드코딩 stub을 반환하면 silent failure로 누락이 숨는다.

**탐지:**
```bash
grep -rnE 'return (emptyList|emptyMap|null)' \
  modules/application/core/src/main/kotlin/com/invigoworks/bitda/application/production/service/*.kt \
  | grep -v 'if (' | grep -v 'isEmpty'
```

**예외 (위반 아님):**
- 가드절: `if (ids.isEmpty()) return emptyMap()`.
- LEFT JOIN으로 정당하게 null일 수 있는 선택 필드.
- 입력이 비었을 때의 빠른 반환.

**근거**: b21876cb3(successLots stub→`findDetail()` 실조회).

---

## D4. 집계는 `@Formula` 대신 QueryDSL 서브쿼리

카운트/합계 집계를 `@Formula`로 하면 QueryDSL Tuple 프로젝션에 안 잡혀 필드가 silent 누락된다.
QueryDSL 서브쿼리로 작성한다.

**탐지:**
```bash
grep -rn '@Formula' modules/infrastructure/src/main/kotlin --include='*.kt'
```

**예외 (위반 아님):**
- Entity-mode 단건 로드 전용 계산(Tuple 프로젝션에 미사용).
- 읽기 전용 reference 모델에서 의도된 계산.

**근거**: bcdbd63f4(증빙 카운트 @Formula→서브쿼리). query-pattern.md.

---

## D5. 선택 관계는 LEFT JOIN — INNER JOIN 금지 (행 누락)

조회 어댑터에서 선택적(nullable FK) 관계는 `leftJoin`. `innerJoin`을 쓰면 관계가 없는 행이
조용히 빠진다 (factory/equipment/process/task/warehouse 등).

**탐지:**
```bash
grep -rn '\.innerJoin(' modules/infrastructure/src/main/kotlin/com/invigoworks/bitda/infrastructure/persistence/production/**/*QueryJpaAdapter.kt
```

**예외 (위반 아님):**
- FK NOT NULL이 보장된 필수 부모 aggregate join.
- WHERE 필터링용 join (SELECT 누락 아님).
- 조직 마스터 등 항상 존재가 보장된 reference.

**근거**: 328114b5b(findByDate LEFT JOIN 추가).

---

## D6. 테스트의 생산일자는 `LocalDate.now().minusDays(N)` — 미래/절대일자 금지

도메인이 미래 생산일자를 거부하므로(`require`), 테스트에 절대일자(`LocalDate.of(2026,...)`)나
미래일을 하드코딩하면 시간이 지나며 또는 즉시 FAIL한다. 동적 상대일자 사용.

**탐지:**
```bash
grep -rnE 'LocalDate\.of\(20[0-9]{2}|Instant\.parse\("20' \
  modules/**/src/test/**/*[Pp]roduction*.kt modules/**/src/test/**/*[Ll]ot*.kt 2>/dev/null
```

**예외 (위반 아님):**
- 시간정책 무관한 순수 VO/도메인 유닛 테스트(미래일자 검증 자체가 대상).
- 고정 clock을 주입해 시간을 통제하는 테스트.
- 과거 절대일자가 시나리오상 의미를 갖는 경우(주석 명시).

**근거**: 61b950b76, bd44f5ecb.

---

## D7. 도메인 필드 리네임 시 테스트 fixture·mock stub 동반 수정

도메인/Result 필드명 변경(`items`→`details` 등)이나 포트 시그니처 변경 시, 컨트롤러 테스트
jsonPath·mock stub·E2E fixture를 **같은 PR에서** 갱신한다. 누락 시 CI에서 늦게 터진다.

**탐지:**
```bash
# 옛 필드명 jsonPath 잔존 (생산 컨트롤러 테스트)
grep -rn '\.items\[' modules/application/api/src/test/**/*[Pp]roduction*.kt 2>/dev/null
# mock stub arity drift: 새 파라미터 추가됐는데 anyOrNull 없음
grep -rn 'createLotsAndBuildItems' modules/application/core/src/test/**/*.kt 2>/dev/null | grep -v 'anyOrNull'
```

**예외 (위반 아님):**
- 페이지네이션 래퍼의 `items`(aggregate 필드명과 무관).
- `items` 필드명이 의도된 다른 도메인.
- 폴리모픽 메서드의 변형별 정확한 stub.

**근거**: ba5a37cb6(items→details 8곳), 97e9be8c7(QueryPort 의존), 67ae88d81(stub arity).
