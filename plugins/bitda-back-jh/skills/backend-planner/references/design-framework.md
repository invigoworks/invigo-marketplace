# Backend Design Translation Framework

이 문서는 기획 내용을 백엔드 설계로 번역하는 방법을 정의합니다.
`docs/learn-backend/` 시리즈의 핵심 내용을 압축한 실전 참고서입니다.

---

## Section 1: 도메인 언어 정의

기획서의 용어를 코드 이름으로 매핑합니다.

출력 형식:
| 비즈니스 용어 | 코드 이름 | 타입 | 설명 |
|-------------|----------|------|------|
| 생산 실적 | `ProductionRecord` | Aggregate Root | |
| 수량 | `Quantity` | Value Object | 0 이상 정수 |
| 불량률 초과 | `DefectRateExceededEvent` | Domain Event | |

규칙:
- Aggregate Root: 고유 ID로 식별, 트랜잭션 경계
- Value Object: ID 없음, 불변, 자체 검증 포함
- Domain Event: 과거형 동사 + "Event" 접미사

---

## Section 2: 데이터 모델

### Aggregate 구조

```
[AggregateRoot이름] (Aggregate Root)
  ├── id: UUID
  ├── organizationId: UUID          ← 항상 포함 (멀티테넌트)
  ├── [비즈니스 필드들]
  ├── status: [StatusEnum]?          ← 상태 전이가 있을 때
  └── deletedAt: Instant?            ← 소프트 딜리트일 때
```

### DB 테이블 컬럼

필수 포함:
```
id              UUID         PK
organization_id UUID         FK → organizations.id
[비즈니스 컬럼들]
deleted_at      TIMESTAMPTZ  NULL (소프트 딜리트 시)
created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
version         BIGINT       NOT NULL DEFAULT 0  (낙관적 잠금)
```

### UNIQUE 제약 표기

중복 방지 조합이 있으면 명시:
```
UNIQUE (organization_id, [컬럼들]) WHERE deleted_at IS NULL
```

---

## Section 3: API 목록

기획서의 "액션" → 메서드+URL 매핑:

| 기획 액션 | HTTP 메서드 | URL 패턴 | UseCase 타입 |
|----------|------------|---------|-------------|
| ~를 등록한다 | POST | `/{리소스}` | Command |
| ~목록을 본다 | GET | `/{리소스}` | Query |
| ~상세를 본다 | GET | `/{리소스}/{id}` | Query |
| ~를 수정한다 | PATCH | `/{리소스}/{id}` | Command |
| ~를 삭제한다 | DELETE | `/{리소스}/{id}` | Command |
| ~를 정정한다 (이력 O) | POST | `/{리소스}/{id}/corrections` | Command |
| ~엑셀 다운로드 | GET | `/{리소스}/export` | Query |

URL 기본 prefix: `/api/v1/production/{리소스명(복수)}`

---

## Section 4: 핵심 API 요청/응답

### POST (생성) 패턴

```
Request Body:
{
  "필드1": "...",
  "필드2": 0
}

Response 201:
{
  "data": "생성된-uuid",
  "error": null,
  "message": null
}

에러 케이스:
  400: 유효성 검증 실패
  409: 중복 데이터
```

### GET (목록) 패턴

```
Query Params:
  - [필터 필드들]: (선택)
  - page: 0
  - size: 20

Response 200:
{
  "data": {
    "content": [ { "id": "...", ... } ],
    "totalElements": 0,
    "page": 0,
    "size": 20
  },
  "error": null
}
```

---

## Section 5: 비즈니스 규칙

기획서에서 "~해야 한다", "~하면 안 된다", "~인 경우에만" 패턴을 찾아 번호 목록으로 정리.

분류:
- **[검증]** 입력값 제약 (Domain의 `require()`/`check()`)
- **[상태]** 상태별 제약 (예: CANCELLED 상태에서는 수정 불가)
- **[중복]** 유니크 제약 (DB UNIQUE + UseCase에서 사전 확인)
- **[이벤트]** 특정 조건 충족 시 이벤트 발행 트리거

---

## Section 6: 이벤트 정의

다른 도메인에 알려야 할 사건이 있을 때만 정의.

```
[이벤트명] (과거형, 예: ProductionRecordCreated)
  ├── recordId: UUID
  ├── organizationId: UUID
  ├── occurredAt: Instant
  └── [트리거가 된 비즈니스 데이터]

→ 수신 도메인: [어떤 도메인이 받는지]
→ 수신 후 처리: [무엇을 하는지]
```

없으면: "이벤트 없음 (도메인 간 연동 불필요)"

---

## Section 7: UseCase 목록

```
[Command UseCase]
Create[도메인]UseCase
  - Command: [필드 목록]
  - Returns: UUID

Update[도메인]UseCase
  - Command: [필드 목록]
  - Returns: Unit

Delete[도메인]UseCase
  - Command: id, organizationId
  - Returns: Unit

[Query UseCase]
Search[도메인]sUseCase
  - Query: [필터 필드들], page, size
  - Returns: Page<[도메인]Result>

Get[도메인]UseCase
  - Query: id, organizationId
  - Returns: [도메인]Result
```

---

## Claude 구현 프롬프트 템플릿

```
[도메인명] 기능을 구현해줘.
기존 ProductionInbound 도메인 패턴을 참고해서 동일한 구조로 만들어줘.

## Aggregate

[AggregateRoot이름] (Aggregate Root)
[필드 목록]

비즈니스 규칙:
- [규칙 1]
- [규칙 2]
...

## UseCase 목록

[Command]
- [UseCaseName]: Command([필드들]) → UUID/Unit
...

[Query]
- [UseCaseName]: Query([필드들]) → 반환타입
...

## DB 테이블

테이블명: [snake_case]
컬럼: [목록]
제약: [UNIQUE 등]

## 이벤트

[이벤트명]: [조건] 시 발행
필드: [목록]

## 구현 순서

1. Domain: [AggregateRoot이름].kt, [ValueObjects], [Events]
2. Application/Core: UseCase 인터페이스 + Service
3. Infrastructure: JpaEntity, Adapter, Migration SQL
4. API: Controller, Request/Response DTO
```
