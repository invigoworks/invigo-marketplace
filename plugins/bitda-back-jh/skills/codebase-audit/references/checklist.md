# Codebase Audit Checklist

에이전트별 상세 검사 항목 및 탐지 패턴을 정의한다.

---

## Agent 1: constitution-checker

**담당**: CLAUDE.md 핵심 원칙 검사

### 검사 항목

#### §2.2 가시성 규칙 위반

| 대상 | 규칙 | 탐지 패턴 |
|------|------|----------|
| Service 구현체 | `internal class` 필수 | `^class.*Service\s*[:(]` (internal 없이) |
| Adapter 구현체 | `internal class` 필수 | `^class.*Adapter\s*[:(]` (internal 없이) |
| 도메인 필드 | `private set` 필수 | `var.*:` (private set 없이) |

**Grep 예시**:
```bash
# internal 누락 Service
Grep pattern="^class [A-Z].*Service" glob="**/service/*.kt"

# internal 누락 Adapter
Grep pattern="^class [A-Z].*Adapter" glob="**/adapter/*.kt"
```

#### §2.3 도메인 공유 규칙 위반

| 대상 | 규칙 | 탐지 패턴 |
|------|------|----------|
| domain.common | 외부 참조 금지 | `import.*domain\.common\.` in api/infrastructure |

**Grep 예시**:
```bash
# API 모듈에서 domain.common 참조
Grep pattern="import.*domain\.common\." path="modules/application/api/"
```

#### §2.4 Zero-DTO 정책 위반

| 대상 | 규칙 | 탐지 패턴 |
|------|------|----------|
| infrastructure DTO | 1회성 Projection DTO 금지 | `data class.*Dto` in persistence/ |
| 반환 타입 | Tuple→Result 직접 매핑 | QueryRepository 반환값 확인 |

#### §3.1 계층별 패키지 배치 위반

| 클래스 유형 | 올바른 위치 | 위반 패턴 |
|------------|------------|----------|
| Aggregate Root | `domain.*.model` | `@Entity` in domain/ |
| UseCase | `application.*.query/command` | UseCase in infrastructure/ |
| JpaEntity | `persistence.*.entity` | JpaEntity in domain/ |

#### §3.2 Double Model 전략 위반

| 대상 | 규칙 | 탐지 패턴 |
|------|------|----------|
| domain 모듈 | JPA 어노테이션 금지 | `@Entity`, `@Table`, `@Column` in domain/ |

**Grep 예시**:
```bash
# domain 모듈에 JPA 어노테이션
Grep pattern="@(Entity|Table|Column|ManyToOne|OneToMany)" path="modules/domain/"
```

---

## Agent 2: policy-checker

**담당**: 시행령 문서 규칙 검사

### temporal-data-policy.md

| 규칙 | 탐지 패턴 | 위치 |
|------|----------|------|
| Instant only | `LocalDateTime`, `LocalTime` | domain/, application/ |
| TIMESTAMPTZ | `@Column.*timestamp` without timezone | infrastructure/ |

**Grep 예시**:
```bash
Grep pattern="LocalDateTime|LocalTime" path="modules/domain/"
Grep pattern="LocalDateTime|LocalTime" path="modules/application/"
```

### validation-exception-policy.md

| 규칙 | 탐지 패턴 | 위치 |
|------|----------|------|
| 예외 계층 | `throw RuntimeException`, `throw Exception(` | modules/ |
| 도메인 예외 | BusinessException 사용 | domain/ |
| 인프라 예외 | InfrastructureException 사용 | infrastructure/ |

**Grep 예시**:
```bash
Grep pattern="throw (RuntimeException|Exception\()" glob="**/*.kt"
```

### query-pattern.md

| 규칙 | 탐지 패턴 | 위치 |
|------|----------|------|
| QueryRepository 반환 | Entity 대신 Result | `QueryRepository.*: .*Entity` |
| Zero-DTO | Tuple→Result 직접 | `data class.*Projection` in adapter/ |

### messaging-policy.md

| 규칙 | 탐지 패턴 | 위치 |
|------|----------|------|
| Dispatcher 상속 | BaseIntegrationEventDispatcher | consumer/ |
| 멱등성 처리 | eventId + handlerId UK | handler/ |

### db-migration-policy.md

| 규칙 | 탐지 패턴 | 위치 |
|------|----------|------|
| 파일명 형식 | `V{YYYYMMDD}{NNN}__{desc}.sql` | db/migration/ |
| 병합 후 수정 | git log 확인 (main 병합 후 변경) | db/migration/ |

**검사 방법**:
```bash
# 파일명 형식 확인
ls db/migration/*.sql | grep -v "^V[0-9]\{8\}[0-9]\{3\}__"
```

### test-infrastructure-spec.md

| 규칙 | 탐지 패턴 | 위치 |
|------|----------|------|
| @DirtiesContext 금지 | `@DirtiesContext` | *Test.kt |
| Track 상속 필수 | E2E 테스트에서 Track 상속 | *E2ETest.kt |
| @SpringBootTest 직접 사용 금지 | `@SpringBootTest` (Track 없이) | *E2ETest.kt |

**Grep 예시**:
```bash
Grep pattern="@DirtiesContext" glob="**/*Test.kt"
Grep pattern="@SpringBootTest" glob="**/*E2ETest.kt"
```

---

## Agent 3: pattern-analyzer

**담당**: 패턴 일관성 분석

### 네이밍 패턴 분석

| 계층 | 다수 패턴 (기대) | 소수 패턴 (불일치) |
|------|-----------------|-------------------|
| Service | `{Action}{Domain}Service` | `{Domain}{Action}Service` |
| UseCase | `{Action}{Domain}UseCase` | `{Domain}{Action}UseCase` |
| Adapter | `{Domain}{Type}Adapter` | `{Type}{Domain}Adapter` |

**분석 방법**:
1. Glob으로 같은 계층 파일 수집
2. 클래스명 패턴 추출
3. 빈도 분석 → 다수/소수 식별
4. 소수 패턴 파일 목록 출력

### 반환값 패턴 분석

| UseCase 유형 | 기대 반환값 | 위반 |
|-------------|------------|------|
| Create | `UUID` | `Entity`, `Result`, `Unit` |
| Update/Delete | `Unit` | `Entity`, `Boolean` |
| Get/Search | `Result`, `List<Result>` | `Entity` |

### 예외 처리 패턴 분석

| 기대 패턴 | 위반 패턴 |
|----------|----------|
| `throw BusinessException` | `throw RuntimeException` |
| `require()` / `check()` | `if (!condition) throw` |

### Mapper 패턴 분석

| 변환 방향 | 기대 함수명 | 위반 |
|----------|------------|------|
| JpaEntity → Domain | `toDomain()` | `toEntity()`, `toModel()` |
| Domain → JpaEntity | `toJpaEntity()` | `toEntity()`, `toPersistence()` |
| Domain → Result | `toResult()` | `toDto()`, `toResponse()` |

---

## Agent 4: duplication-detector

**담당**: 코드 중복 탐지

### 중복 탐지 대상

| 유형 | 탐지 방법 | 임계값 |
|------|----------|--------|
| Mapper 로직 | 함수 본문 구조 비교 | 3회 이상 유사 |
| 검증 로직 | require/check 조건 비교 | 3회 이상 동일 |
| 쿼리 조건 | BooleanExpression 조합 비교 | 3회 이상 유사 |
| 예외 처리 | try-catch 블록 비교 | 3회 이상 유사 |

### 분석 방법

1. **Mapper 중복**:
   - `*Mapper.kt` 파일 수집
   - `fun to*()` 함수 추출
   - 본문 구조 해시 비교
   - 유사도 80% 이상 → 중복 후보

2. **검증 로직 중복**:
   - `require(`, `check(` 호출 추출
   - 조건문 정규화 비교
   - 동일 조건 3회 이상 → 공통 추출 제안

3. **쿼리 조건 중복**:
   - `BooleanExpression` 반환 함수 추출
   - 조건 조합 패턴 비교
   - 유사 패턴 → 공통 Spec 추출 제안

### 제안 형식

```markdown
**중복 발견**: Mapper 로직
- 파일들: `UserMapper.kt:25`, `OrderMapper.kt:30`, `ProductMapper.kt:18`
- 중복 내용: `?.let { ... } ?: default` 패턴
- 제안: 공통 확장함수 `fun <T, R> T?.mapOrDefault(default: R, transform: (T) -> R): R` 추출
```

---

## Agent 5: doc-sync-checker

**담당**: 문서/주석 동기화 검사

### 코드 ↔ 주석 불일치

| 검사 항목 | 탐지 방법 |
|----------|----------|
| KDoc 설명 불일치 | 함수명 vs KDoc 첫 줄 비교 |
| @param 불일치 | KDoc @param vs 실제 파라미터명 |
| @return 불일치 | KDoc @return vs 실제 반환 타입 |
| 삭제된 파라미터 언급 | KDoc에 없는 파라미터명 존재 |

**분석 방법**:
1. KDoc 블록 추출 (`/** ... */`)
2. 함수 시그니처 파싱
3. @param, @return 매칭 검증
4. 불일치 항목 보고

### 코드 ↔ MD 문서 불일치

| 문서 유형 | 검사 항목 |
|----------|----------|
| ADR | 결정사항 vs 실제 구현 |
| 시행령 | 예시 코드 vs 현재 패턴 |
| README | 설치/실행 방법 유효성 |

**분석 방법**:
1. MD 파일의 코드 블록 추출
2. 코드 블록에서 클래스/함수명 추출
3. 실제 코드베이스에서 해당 클래스/함수 검색
4. 존재 여부 및 시그니처 일치 확인

### 깨진 참조 (Broken References)

| 참조 유형 | 탐지 패턴 |
|----------|----------|
| MD → 파일 | `](path/to/file)` 링크 검증 |
| MD → 클래스 | 백틱 내 클래스명 존재 확인 |
| 코드 → 문서 | `@see`, `// See:` 링크 검증 |

**분석 방법**:
1. MD 파일의 모든 링크 추출
2. 각 링크 대상 파일 존재 확인
3. 깨진 링크 목록 출력

### 최신화 필요 신호

| 신호 | 탐지 패턴 |
|------|----------|
| TODO 주석 | `<!-- TODO:`, `// TODO:` |
| 오래된 날짜 | `마지막 업데이트:` > 6개월 전 |
| 버전 불일치 | 문서 버전 vs 코드 버전 |
| 삭제된 참조 | 문서에서 언급하는 파일/클래스가 없음 |

---

## 심각도 기준 (공통)

| 심각도 | 정의 | 예시 |
|--------|------|------|
| **심각** | 런타임 오류, 데이터 손실, 보안 취약점, 아키텍처 규칙 명백한 위반 | JPA in domain, @DirtiesContext |
| **중간** | 유지보수성 저하, 컨벤션 불일치, 잠재적 버그 | internal 누락, 네이밍 불일치 |
| **낮음** | 코드 스타일, 가독성 개선, 더 나은 대안 존재 | 주석 불일치, 경미한 중복 |
