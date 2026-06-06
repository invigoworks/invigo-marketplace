# 오탐 방지 규칙 (gap-fe-code)

실측 경험상 갭 후보의 다수(직전 라운드 18후보 중 11)는 "BE에 이미 있음" 오탐이다.
verifier와 메인 재판정 모두 아래 규칙을 적용한다.

## 갭 판정 기준 (이것만 갭)

다음 **4가지를 직접 grep/read로 확인**하여, 해당하는 계층 중 하나라도 실제로 없을 때만 갭:

1. **BE Response DTO** (XxxResponse, XxxResult의 val 필드)
2. **JpaAdapter SELECT** (QueryDSL/native 쿼리에서 실제 조회하는 컬럼)
3. **Flyway 컬럼** (db/migration/V*.sql)
4. **Domain/Service 로직** (require/check, Service의 검증·계산 호출)

## 갭이 아닌 것 (이슈 생성 금지)

| 패턴 | 이유 |
|------|------|
| FE가 `.find()`/`.map()`으로 로컬 가공 | BE Response에 필드 있으면 갭 아님 |
| FE 타입 정의에 필드 없음 | BE Response에 있으면 갭 아님 |
| plan-master 목업 경로불일치 (`/xxx` vs `/api/v1/xxx`) | 목업 아티팩트, 갭 아님 |
| 횡단 API가 생산 패키지에 없음 | 다른 패키지(inventory/lot 등)에 있을 수 있음 → 전체 모듈 grep 필수 |
| 마스터 조회 API "없음" 주장 | VesselController/BomTemplateController/LotRuleController 등 별도 도메인에 흔히 존재 |
| 멱등성 "검증 필요" | `@Idempotent`가 이미 적용됐는지 확인. FE 헤더 생성은 FE 작업이지 BE 갭 아님 |
| 작업지시서 "출력 API 없음" | 출력=FE `@media print` 클라이언트 인쇄. 상세조회로 데이터 충족하면 BE API 불필요 |

## 목업 패러다임 함정 (가장 미묘 — 사람 확인 필요)

plan-master는 localStorage 기반이라 화면을 **자유 CRUD 엔티티**로 다루는 경우가 있다.
예: work-status를 `repo.create()/update()/findByProductionPlanId()`로 독립 저장.

그러나 BE는 같은 개념을 **다른 패러다임**으로 설계했을 수 있다.
예: WorkOrder를 "생산계획 종속 자동생성 + 상태전이만" (독립 CRUD 없음 = 의도).

→ 이때 목업의 편집/저장 호출을 그대로 "BE 갭"으로 단정하면 안 된다. **경로 불일치가 아니라
설계 가정 차이**다. 이런 후보는 `mockParadigmRisk=true`로 표시하고, 화면이 실제로
자유편집이어야 하는지 **사용자에게 확인**한 뒤 갭 여부를 확정한다.

판별 신호:
- 목업이 create/update/delete를 자유 호출하는데 BE엔 대응 PATCH/POST/DELETE가 전무
- BE 모델이 다른 Aggregate에 종속돼 자동생성되는 구조
- 실 운영 FE(bitda-front)에서 해당 화면이 PRO 목업/미구현이라 실제 요구를 단정 못 할 때

## 메인 재판정 의무

워크플로우 `confirmed`도 **그대로 믿지 않는다**. 메인 컨텍스트가 각 confirmed 갭의
근거 파일을 직접 열어(Read/grep) 위 4계층을 재확인한 뒤에만 이슈로 승격한다.
