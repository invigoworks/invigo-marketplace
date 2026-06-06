# 구조 형태 갭 (Structural Shape Gaps) — 카디널리티 손실 안티패턴

> **목적**: gap-analyze의 **필드 존재(presence) diff**만으로는 탐지 불가능한
> **도메인 구조 결함**(relational cardinality loss)을 카탈로그하고
> 기계 탐지 신호 + 거짓양성 방지 가이드를 제공한다.
>
> **핵심 통찰**: FE와 BE가 **동일한 평탄 구조**를 공유하면 diff=0이므로
> 기존 갭-분석 규칙(필드 누락, Response 부재, LR3b 비대칭 등)이 전부 통과한다.
> 그러나 도메인 의미상 N:M 관계를 두 개의 1:N 평탄 리스트로 표현하면
> **매핑 정보가 영구 손실**되어, Gantt 그룹핑·권한 제어 같은 기능 구현 시
> 구조 재설계 비용이 배가된다.

---

## 왜 이 갭이 기존 gap-analyze로 안 잡히나 (RCA, #2087)

gap-analyze는 본질적으로 **FE↔BE 필드 존재 diff 엔진**이다. 탐지하는 것:
API 경로/메서드 불일치, Response DTO 필드 누락, Flyway 컬럼 누락,
폼 렌더 필드(name/colorId/isActive) 누락, LR3b(FE필수↔BE nullable) 비대칭.
전부 **"이 필드가 있는가?"** 수준의 비교다.

`ProductionPlanDetail` assignments 갭(#2087)은 **필드 존재 문제가 아니다**:

- `departmentIds: List<UUID>` + `workerIds: List<UUID>` — **둘 다 존재, 둘 다 사용됨**.
- **plan-master FE도 동일하게 평탄**(`types.ts:57-59` `departmentIds?: string[]` + `workerIds?: string[]`).
  seed-data는 행마다 단일 부서+단일 인력만 1:1로 페어링 → N:M 시연조차 없음.
- → **FE 구조 === BE 구조. diff = 0.** 모든 필드-존재 규칙 통과 → 3관문 전부 PASS → REFUTED.

**FE와 BE가 같은 설계 결함을 공유하면 diff 엔진은 구조적으로 탐지 불가.**
`assignments` 요구는 어떤 산출물(FE 코드/기획서/목업)에도 없었고,
**인간의 도메인 통찰**(N:M 매핑 손실 → 간트 부서 그루핑 불가)에서만 나왔다.

→ 신규 miss class = **shared-structural-flaw-with-cardinality-loss**.

---

## 사례 분석: ProductionPlanDetail 할당 (#2087)

| 요소 | 현재(평탄) | 필요(중첩) | 손실 정보 |
|------|-----------|-----------|---------|
| **BE Request DTO** | `departmentIds: List<UUID>`, `workerIds: List<UUID>` | `assignments: List<Assignment>` (`Assignment = { departmentId, workerIds }`) | "어느 인력이 어느 부서?" |
| **BE Domain 필드** | 동일 평탄 (`ProductionPlanDetail`) | 중첩 VO | 같음 |
| **DB 테이블** | 독립 `@ElementCollection` 2개 (`department_id`, `worker_id`) | 조인 테이블(detail_id, department_id, worker_id) | N:M 매핑 |
| **FE 구현** | 평탄 배열 (plan-master 목업) | 중첩 (bitda-front 미구현) | 같음 |
| **Gantt 필요성** | "부서별 그룹핑 + 소속 인력" | 구조에서 자명 | 매핑 없어 그룹핑 불가 |

---

## 안티패턴 분류

### AP1. 평탄 형제 배열 (Flat Sibling Arrays) — 카디널리티 손실

```kotlin
// Request / Domain 양쪽 동일
val departmentIds: List<UUID>
val workerIds: List<UUID>
```

문제: 두 배열 간 대응 관계 없음. `[d1,d2]` + `[w1,w2,w3]` 전송 시
DB에 3개 부서ID + 3개 인력ID만 저장 → "w1은 d1? d2? 둘 다?" 불명확.

해결:
```kotlin
data class Assignment(val departmentId: UUID, val workerIds: List<UUID>)
// Request / Domain 양쪽
val assignments: List<Assignment>
```

### AP2. 직교(독립) vs 계층(의존) 혼동

| 관계 | 특징 | 최적 구조 | 예시 |
|------|------|---------|------|
| **직교 (⊥)** | 배열 간 의미 관계 없음 | **평탄 OK (갭 아님)** | `tagIds` + `categoryIds`, 검색 `statuses` + `sortKeys` |
| **계층 (→)** | 상위 선택이 하위 필터링 | 중첩 필요 | 공장→설비, 부서→인력 |
| **N:M (↔)** | 양방향 참조 필요 | 중첩 또는 명시 매핑 | 부서↔인력, 프로젝트↔팀 |

판별 핵심: 두 배열이 **함께 의미를 가지는가(계층/N:M)** vs **각자 독립적인가(직교)**.

### AP3. DB 스키마-도메인 구조 불일치

평탄 도메인 → 독립 `@ElementCollection` 2개로 매핑되면, 추후 N:M이 필요해질 때
조인 테이블/Entity 신설 + Flyway 마이그레이션이 강제됨. 처음부터 중첩이면 회피 가능.

---

## 기계 탐지 신호 (Agent C/D 추출)

### 신호 T1: Request/Domain에 형제 ID 배열 쌍 존재

```bash
BACK=/Users/gimjinhyeog/Desktop/coding/bitda-back

# Request/Command DTO에서 List<UUID> 2개+ 보유 클래스
grep -rn "List<UUID>" "$BACK/modules/application" --include="*.kt" -B 30 \
  | grep -E "data class.*(Request|Command)" | sort -u

# Domain 집계에서 동일 패턴
grep -rn "List<UUID>" "$BACK/modules/domain/src" --include="*.kt" -B 30 \
  | grep -E "data class|^class " | sort -u
```

### 신호 T2: 함께 접근(co-access) 메서드 부재 + KDoc 의도 부재

```bash
# 두 배열을 한 메서드/표현식에서 같이 쓰는가?
grep -rn "departmentIds" "$BACK/modules/domain/src" --include="*.kt" \
  | grep "workerIds"          # 결과 없음 = 의도 불명확 신호

# KDoc/주석에 독립/N:M 의도 명시?
grep -rB5 "val departmentIds\|val workerIds" "$BACK/modules/domain/src" \
  --include="*.kt" | grep -E "/\*\*|\*|독립|직교|N:M|매핑"
```

### 신호 T3: FE 사용처가 N:M을 암시

```bash
FE=/Users/gimjinhyeog/Desktop/coding/plan-master
# Gantt/그룹핑 코드에서 부서 단위 그룹핑 의도
grep -rn "groupBy\|partition\|부서별\|by.*department" \
  "$FE/apps/liquor/src/production" --include="*.ts" --include="*.tsx"
```

---

## 거짓양성 방지 (FALSE POSITIVE GUARDS)

> ⚠️ **단순 "List 필드 2개" = 갭 절대 아님.** Skeptic이 4개 규칙을 FP-storm으로 기각했다
> (sibling-list 카디널리티, 이름패턴 휴리스틱, annotation 게이트, FE groupBy 휴리스틱).
> 아래 가드를 통과한 것만 후보로 승격.

| 패턴 | 판정 | 근거 |
|------|------|------|
| `tagIds` + `categoryIds` | ✅ 독립 (갭 아님) | 직교: 태그·카테고리 무관 |
| 조회 `statuses` + `sortKeys` | ✅ 독립 | 쿼리 파라미터, 페이로드 구조 아님 |
| `roleIds` + `scopeIds` | ⚠️ KDoc 확인 | 직교일 수 있으나 invariant/KDoc로 의도 확인 |
| 두 배열 함께 쓰는 메서드 有 / KDoc에 "직교" 명시 | ✅ 갭 아님 | 의도 문서화 = 설계대로 |
| `departmentIds` + `workerIds` + Gantt 부서그룹핑 필요 | ❌ L5 후보 | 도메인 의미 N:M + 사용처가 매핑 요구 |

**핵심**: 구조 신호(T1)만으로 확정 금지. **사용처(T3) + 의도부재(T2)** 가 함께여야 후보.
최종 확정은 사람(관문3)이.

---

## 판정 흐름 (3관문 연동)

```
[Agent C/D: T1+T2+T3 신호 동시 충족 → L5 후보]
   ↓
관문1 (소스진위): 기획서(docs/specs/liquor)에 중첩/N:M 명시?
   YES → CONFIRM
   NO  → 관문2
   ↓
관문2 (현HEAD 실측): Request/Domain/DB(@ElementCollection) 구조 직접 Read
   불일치 발견 → CONFIRM
   모두 평탄 일치 → 관문3
   ↓
관문3 (도메인 영향도, 사람 판정):
   "이 use case(Gantt 부서그룹핑/권한)가 N:M 매핑을 실제 요구하나?"
   YES → CONFIRM (L5 갭)
   "KDoc/invariant에 의도적 독립 명시" → REFUTE
   "1:1 pairing으로 충분" → REFUTE
   "기획 정보 불충분" → UNCERTAIN (보류, 사람 검토)
```

---

## 범위 & 한계 (정직한 disclaimer)

**gap-analyze는 필드-존재 diff 엔진이므로 L5는 확장 스코프다.**

- ✅ 탐지 가능: Request DTO 구조 vs Domain 집계 필드 비교 (Agent C 코드 레벨)
- ✅ 탐지 가능: 평탄 형제 배열 + co-access/KDoc 부재 (grep)
- ❌ 탐지 불가: FE 실제 의도 (plan-master는 목업, bitda-front 미구현이면 증거 없음)
- ❌ 탐지 불가: N:M vs 의도적 독립 판별 (도메인 전문가 판단 필수)

**따라서 L5 산출물은 항상 "후보"다. 자동 이슈 생성 금지.**
관문3(도메인 영향도)을 사람이 통과시킨 것만 CONFIRMED.

---

## 체크리스트

- [ ] Request/Domain에 형제 `List<UUID>` 쌍? (T1)
- [ ] 두 배열 함께 쓰는 메서드 부재 + KDoc 의도 부재? (T2)
- [ ] FE/기획 use case가 그룹핑/매핑 요구? (T3)
- [ ] 위 3개 동시 충족 → 후보. 1개라도 미충족 → 갭 아님.
- [ ] 후보 → 관문1~3. 관문3은 사람.

## 참고

- **CLAUDE.md §3.2** Double Model, **§2.3** 도메인 공유 규칙
- **#2087** ProductionPlanDetail assignments 구조 갭 (확정 사례 / 기준 앵커)
- 연관: `static-contract-diff.md`(LR3b), `fe-perspective-checklist.md`
