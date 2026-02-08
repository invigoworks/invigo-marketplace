# Bitda Backend 아키텍처 개요

> 이 문서는 bitda-back 프로젝트의 아키텍처를 설명합니다.
> 기획자, 개발자, Claude Code 자동화 스킬 제작을 위한 레퍼런스 문서입니다.

---

## 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [모듈 구조](#2-모듈-구조)
3. [아키텍처 패턴](#3-아키텍처-패턴)
   - [헥사고날 아키텍처](#31-헥사고날-아키텍처-ports--adapters)
   - [도메인 주도 설계 (DDD)](#32-도메인-주도-설계-ddd)
   - [명령-조회 분리 (CQS/CQRS)](#33-명령-조회-분리-cqscqrs)
   - [이벤트 기반 설계 (EDD)](#34-이벤트-기반-설계-edd)
4. [핵심 패턴 상세](#4-핵심-패턴-상세)
5. [데이터 흐름](#5-데이터-흐름)
6. [파일 구조 레퍼런스](#6-파일-구조-레퍼런스)

---

## 1. 프로젝트 개요

### 기술 스택

| 구분 | 기술 |
|------|------|
| 언어 | Kotlin 1.9.25 |
| 프레임워크 | Spring Boot 3.4.12 |
| JDK | 21 |
| 빌드 도구 | Gradle (Kotlin DSL) |
| 데이터베이스 | PostgreSQL |
| 인증 | Keycloak (OAuth2/OIDC) |
| 메시지 브로커 | RabbitMQ |
| CDC | Debezium |

---

## 2. 모듈 구조

```
bitda-back/
├── modules/
│   ├── common/              # 공통 유틸리티, 인터페이스
│   ├── domain/              # 도메인 모델, 비즈니스 로직
│   ├── infrastructure/      # 외부 시스템 연동 (DB, API)
│   └── application/
│       ├── api/             # REST API 서버
│       ├── batch/           # 배치 처리
│       └── consumer/        # 메시지 컨슈머
└── docker/                  # Docker 인프라
```

### 의존성 방향

```
┌─────────────────────────────────────┐
│     Application (api, batch, consumer)     │
└───────────────────┬─────────────────┘
                    ▼
┌─────────────────────────────────────┐
│      Domain, Infrastructure, Common        │
└───────────────────┬─────────────────┘
                    ▼
┌─────────────────────────────────────┐
│               Common                       │
└─────────────────────────────────────┘
```

**핵심 원칙**: 의존성은 항상 **안쪽(도메인)**으로 향합니다.

---

## 3. 아키텍처 패턴

### 3.1 헥사고날 아키텍처 (Ports & Adapters)

> 도메인 로직을 외부 기술로부터 격리시키는 아키텍처 패턴입니다.

```
┌─────────────────────────────────────────────────────────────┐
│                      외부 세계                               │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  HTTP    │    │  DB      │    │ Keycloak │              │
│  │  Client  │    │ (PostgreSQL) │ │          │              │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘              │
│       │               │               │                     │
└───────┼───────────────┼───────────────┼─────────────────────┘
        │               │               │
        ▼               ▼               ▼
┌───────────────────────────────────────────────────────────┐
│                    어댑터 계층                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Controller   │  │ JpaAdapter   │  │ KeycloakAdapter │   │
│  │ (Inbound)    │  │ (Outbound)   │  │ (Outbound)   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
└─────────┼─────────────────┼─────────────────┼──────────────┘
          │                 │                 │
          ▼                 ▼                 ▼
┌───────────────────────────────────────────────────────────┐
│                     포트 (인터페이스)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ UseCase      │  │ Repository   │  │ AuthClient   │      │
│  │ (Inbound)    │  │ (Outbound)   │  │ (Outbound)   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────┬─────────────────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────────┐
│                     도메인 계층                              │
│  ┌───────────────────────────────────────────────────┐    │
│  │  • Aggregate Root (User, Company, Warehouse)      │    │
│  │  • Value Object (BusinessRegistrationNumber)      │    │
│  │  • Domain Event (UserCreatedEvent)                │    │
│  │  • Business Logic                                 │    │
│  └───────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────┘
```

#### 포트 (Port) - 인터페이스

도메인 계층에 정의된 인터페이스입니다.

| 포트 타입 | 이름 | 위치 | 설명 |
|-----------|------|------|------|
| Outbound | `UserRepository` | domain/user/port/ | 사용자 저장소 |
| Outbound | `CompanyRepository` | domain/company/port/ | 회사 저장소 |
| Outbound | `AuthUserClient` | domain/user/port/ | 외부 인증 시스템 |
| Outbound | `MessagePublisher` | domain/messaging/port/ | 이벤트 발행 |
| Outbound | `ProcessedEventStore` | domain/messaging/port/ | 이벤트 중복 처리 방지 |

#### 어댑터 (Adapter) - 구현체

인프라스트럭처 계층에 정의된 포트의 구현체입니다.

| 어댑터 | 구현 포트 | 위치 |
|--------|----------|------|
| `UserJpaAdapter` | `UserRepository` | infrastructure/persistence/user/adapter/ |
| `CompanyJpaAdapter` | `CompanyRepository` | infrastructure/persistence/company/adapter/ |
| `KeycloakUserClientAdapter` | `AuthUserClient` | infrastructure/auth/adapter/ |
| `DomainEventPublisher` | `MessagePublisher` | infrastructure/persistence/event/adapter/ |

---

### 3.2 도메인 주도 설계 (DDD)

> 복잡한 비즈니스 도메인을 모델링하기 위한 설계 방법론입니다.

#### Aggregate Root (애그리거트 루트)

트랜잭션 일관성의 경계를 정의하는 핵심 엔티티입니다.

```kotlin
// 예시: User Aggregate Root
class User : AggregateRoot() {
    val id: UUID
    val email: String
    var name: String
    var roles: Set<UserRole>
    var lastLoginAt: LocalDateTime?

    // 비즈니스 로직
    fun patch(name: PatchField<String>, role: PatchField<UserRole>)
    fun delete()
    fun recordLogin(loginAt: LocalDateTime)

    companion object {
        fun create(...): User  // 팩토리 메서드
    }
}
```

| Aggregate | 위치 | 설명 |
|-----------|------|------|
| `User` | domain/user/model/aggregate/ | 사용자 |
| `Company` | domain/company/model/aggregate/ | 회사 |
| `Warehouse` | domain/warehouse/model/aggregate/ | 창고 |

#### Value Object (값 객체)

불변의 값을 표현하는 객체입니다.

```kotlin
// 예시: 사업자등록번호
data class BusinessRegistrationNumber(val value: String) {
    init {
        require(value.matches(Regex("^\\d{10}$"))) {
            "사업자등록번호는 10자리 숫자여야 합니다"
        }
    }
    fun formatted(): String = "${value.substring(0,3)}-${value.substring(3,5)}-${value.substring(5)}"
}
```

| Value Object | 설명 |
|--------------|------|
| `BusinessRegistrationNumber` | 사업자등록번호 (10자리 검증) |
| `UserRole` | 사용자 역할 (ADMIN, OWNER, MEMBER) |

#### Domain Event (도메인 이벤트)

도메인에서 발생한 중요한 사건을 표현합니다.

```kotlin
data class UserCreatedEvent(
    override val aggregateId: UUID,
    val email: String,
    val name: String,
    val roles: Set<UserRole>,
) : DomainEvent {
    override val aggregateType: String = "User"
    override val eventType: String = "user.created"
}
```

| 이벤트 | 발생 시점 |
|--------|----------|
| `UserCreatedEvent` | 사용자 생성 시 |
| `UserUpdatedEvent` | 사용자 정보 수정 시 |
| `UserDeletedEvent` | 사용자 삭제 시 |
| `UserLoggedInEvent` | 로그인 성공 시 |
| `CompanyCreatedEvent` | 회사 생성 시 |
| `WarehouseCreatedEvent` | 창고 생성 시 |

#### Bounded Context (경계 컨텍스트)

| 컨텍스트 | 포함 요소 |
|----------|----------|
| **Company** | Company Aggregate, 사업자등록번호 |
| **User** | User Aggregate, 인증, 역할 |
| **Warehouse** | Warehouse Aggregate, 재고 관리 |

---

### 3.3 명령-조회 분리 (CQS/CQRS)

> 데이터를 변경하는 명령(Command)과 조회(Query)를 명확히 분리합니다.

```
┌─────────────────────────────────────────────────────────────┐
│                      Controller                              │
└───────────────┬─────────────────────────┬───────────────────┘
                │                         │
        ┌───────▼───────┐         ┌───────▼───────┐
        │    Command    │         │     Query     │
        │    (변경)     │         │    (조회)     │
        └───────┬───────┘         └───────┬───────┘
                │                         │
        ┌───────▼───────┐         ┌───────▼───────┐
        │   UseCase     │         │   UseCase     │
        │  (변경 로직)   │         │  (조회 로직)   │
        └───────┬───────┘         └───────────────┘
                │
        ┌───────▼───────┐
        │ Domain Event  │
        │   (발행)      │
        └───────────────┘
```

#### Command (명령)

상태를 변경하는 작업을 표현합니다.

```kotlin
// 회사 생성 명령
data class CreateCompanyCommand(
    val name: String,
    val businessRegistrationNumber: BusinessRegistrationNumber,
    val representativeName: String,
)

// 사용자 수정 명령 (부분 수정)
data class PatchUserCommand(
    val id: UUID,
    val name: PatchField<String>,
    val role: PatchField<UserRole>,
)
```

| 명령 | 설명 |
|------|------|
| `CreateCompanyCommand` | 회사 생성 |
| `PatchCompanyCommand` | 회사 정보 수정 |
| `DeleteCompanyCommand` | 회사 삭제 |
| `CreateUserCommand` | 사용자 생성 |
| `RecordLoginEventCommand` | 로그인 이벤트 기록 |

#### Query (조회)

데이터를 조회하는 작업을 표현합니다.

```kotlin
// 단일 조회
data class GetCompanyQuery(val id: UUID)

// 목록 조회 (검색 + 페이징)
data class GetAllCompaniesQuery(
    val pageRequest: PageRequest,
    val searchCriteria: CompanySearchCriteria,
)
```

#### UseCase (유즈케이스)

명령/조회를 처리하는 애플리케이션 서비스입니다.

```kotlin
interface UseCase<Input : Any, Output : Any> {
    fun execute(input: Input): Output
}

// 예시
@Service
class CreateCompanyByAdminUseCase(
    private val companyRepository: CompanyRepository,
) : UseCase<CreateCompanyCommand, Company> {

    @Transactional
    override fun execute(input: CreateCompanyCommand): Company {
        // 중복 검증
        if (companyRepository.existsByBusinessRegistrationNumber(...)) {
            throw DuplicateBusinessRegistrationNumberException(...)
        }
        // 도메인 객체 생성 (이벤트 등록됨)
        val company = Company.create(...)
        // 저장 (이벤트 발행됨)
        return companyRepository.save(company)
    }
}
```

| UseCase | 타입 | 설명 |
|---------|------|------|
| `CreateCompanyByAdminUseCase` | Command | 회사 생성 |
| `GetCompanyByAdminUseCase` | Query | 회사 단일 조회 |
| `GetAllCompaniesByAdminUseCase` | Query | 회사 목록 조회 |
| `PatchCompanyByAdminUseCase` | Command | 회사 수정 |
| `DeleteCompanyByAdminUseCase` | Command | 회사 삭제 |

---

### 3.4 이벤트 기반 설계 (EDD)

> 시스템 간 느슨한 결합을 위해 이벤트를 통해 통신합니다.

#### Transactional Outbox Pattern

데이터베이스 트랜잭션과 메시지 발행의 일관성을 보장합니다.

```
┌─────────────────────────────────────────────────────────────┐
│                    트랜잭션 범위                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  1. Aggregate 저장 (users 테이블)                      │  │
│  │  2. Event 저장 (msg_domain_events 테이블)              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Debezium CDC                              │
│  PostgreSQL WAL → msg_domain_events INSERT 감지             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    RabbitMQ                                  │
│  Topic Exchange: user.created, company.updated 등           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Consumer (구독자)                         │
│  이벤트 핸들러에서 비동기 처리                                │
└─────────────────────────────────────────────────────────────┘
```

#### 이벤트 발행 흐름

```kotlin
// 1. Aggregate에서 이벤트 등록
class User : AggregateRoot() {
    fun recordLogin(loginAt: LocalDateTime) {
        this.lastLoginAt = loginAt
        registerEvent(UserLoggedInEvent(id, email, loginAt))
    }
}

// 2. Repository Adapter에서 저장 후 이벤트 발행
class UserJpaAdapter : UserRepository {
    override fun save(user: User): User {
        userJpaRepository.save(user.toEntity())
        user.publishEventsAndClear(messagePublisher)  // 이벤트 발행
        return user
    }
}

// 3. DomainEventPublisher에서 Outbox 테이블에 저장
class DomainEventPublisher : MessagePublisher {
    override fun publish(message: Message) {
        domainEventRepository.save(DomainEventJpaEntity(
            eventType = message.eventType,
            payload = serialize(message),
            correlationId = MDC.get("correlationId"),
        ))
    }
}
```

#### 멱등성 보장 (Idempotent Event Handling)

중복 이벤트 처리를 방지합니다.

```kotlin
interface ProcessedEventStore {
    fun isProcessed(eventId: UUID, handlerId: String): Boolean
    fun markAsProcessed(eventId: UUID, eventType: String, handlerId: String, consumerId: String)
}
```

| 테이블 | 설명 |
|--------|------|
| `msg_domain_events` | 이벤트 Outbox |
| `processed_events` | 처리된 이벤트 기록 (UK: event_id + handler_id) |

---

## 4. 핵심 패턴 상세

### 4.1 PatchField 패턴 (부분 수정)

PATCH 요청에서 "값이 없음" vs "null로 설정"을 구분합니다.

```kotlin
sealed class PatchField<out T> {
    data object Absent : PatchField<Nothing>()      // 필드 미제공
    data class Present<T>(val value: T?) : PatchField<T>()  // 필드 제공 (null 포함)
}

// 사용 예시
fun patch(name: PatchField<String> = PatchField.Absent) {
    name.ifPresentNotNull { newName ->
        this.name = newName
        registerEvent(UserUpdatedEvent(...))
    }
}
```

### 4.2 페이지네이션 패턴

두 가지 페이지네이션 전략을 지원합니다.

| 전략 | 클래스 | 용도 |
|------|--------|------|
| **Offset 기반** | `OffsetPageRequest` | 작은 데이터셋, 전통적인 페이징 |
| **Cursor 기반** | `CursorPageRequest` | 대용량 데이터, 실시간 데이터 |

```kotlin
sealed interface PageRequest {
    val sort: SortRequest
}

data class OffsetPageRequest(
    val page: Int = 0,
    val size: Int = 20,
    override val sort: SortRequest,
) : PageRequest

data class CursorPageRequest(
    val cursor: String? = null,
    val limit: Int = 20,
    override val sort: SortRequest,
) : PageRequest
```

### 4.3 검색 조건 패턴

```kotlin
interface SearchCriteria {
    fun isEmpty(): Boolean
}

data class CompanySearchCriteria(
    val businessRegistrationNumber: String? = null,
    val representativeName: String? = null,
) : SearchCriteria {
    override fun isEmpty() =
        businessRegistrationNumber.isNullOrBlank() &&
        representativeName.isNullOrBlank()
}
```

### 4.4 에러 처리 패턴

```kotlin
// 도메인 에러 열거형
enum class CompanyError(
    override val status: Int,
    override val message: String,
) : Error {
    COMPANY_NOT_FOUND(404, "회사를 찾을 수 없습니다"),
    DUPLICATE_BUSINESS_REGISTRATION_NUMBER(409, "[%s] 이미 등록된 사업자등록번호입니다"),
}

// 예외 클래스
class CompanyNotFoundException(id: UUID) :
    DomainException(CompanyError.COMPANY_NOT_FOUND)
```

---

## 5. 데이터 흐름

### 5.1 생성 요청 흐름

```
HTTP POST /api/v1/admin/companies
           │
           ▼
┌──────────────────────┐
│  AdminCompanyController  │
│  @Valid CreateRequest    │
└───────────┬──────────┘
            │ request.toCommand()
            ▼
┌──────────────────────┐
│  CreateCompanyCommand    │
└───────────┬──────────┘
            │
            ▼
┌──────────────────────┐
│ CreateCompanyByAdminUseCase │
│  1. 중복 검증              │
│  2. Company.create()       │
│  3. repository.save()      │
└───────────┬──────────┘
            │
            ▼
┌──────────────────────┐
│  CompanyJpaAdapter       │
│  1. Entity 저장          │
│  2. Event 발행           │
└───────────┬──────────┘
            │
            ▼
┌──────────────────────┐
│  DomainEventPublisher    │
│  Outbox 테이블에 저장    │
└──────────────────────┘
            │
            ▼
┌──────────────────────┐
│  Debezium CDC            │
│  RabbitMQ로 전달         │
└──────────────────────┘
```

### 5.2 조회 요청 흐름

```
HTTP GET /api/v1/admin/companies?page=0&size=20
           │
           ▼
┌──────────────────────┐
│  AdminCompanyController  │
│  PageRequest + SearchParams │
└───────────┬──────────┘
            │
            ▼
┌──────────────────────┐
│ GetAllCompaniesQuery     │
└───────────┬──────────┘
            │
            ▼
┌──────────────────────┐
│ GetAllCompaniesByAdminUseCase │
└───────────┬──────────┘
            │
            ▼
┌──────────────────────┐
│  CompanyJpaAdapter       │
│  QueryDSL 쿼리 실행      │
└───────────┬──────────┘
            │
            ▼
┌──────────────────────┐
│  PageResult<Company>     │
│  → PageResponse<CompanyResponse> │
└──────────────────────┘
```

---

## 6. 파일 구조 레퍼런스

### 도메인 계층 (domain/)

```
domain/
└── src/main/kotlin/com/invigoworks/bitda/domain/
    ├── common/
    │   ├── AggregateRoot.kt              # 애그리거트 루트 베이스
    │   └── port/PaginatedRepository.kt   # 페이지네이션 레포지토리 인터페이스
    │
    ├── user/
    │   ├── model/aggregate/
    │   │   └── User.kt                   # 사용자 애그리거트
    │   ├── model/aggregate/value/
    │   │   └── UserRole.kt               # 역할 값 객체
    │   ├── port/
    │   │   ├── UserRepository.kt         # 사용자 레포지토리 포트
    │   │   └── AuthUserClient.kt         # 인증 클라이언트 포트
    │   ├── event/
    │   │   ├── UserCreatedEvent.kt       # 생성 이벤트
    │   │   ├── UserUpdatedEvent.kt       # 수정 이벤트
    │   │   └── UserLoggedInEvent.kt      # 로그인 이벤트
    │   ├── error/UserError.kt            # 에러 정의
    │   └── query/UserSearchCriteria.kt   # 검색 조건
    │
    ├── company/                          # (user와 동일한 구조)
    ├── warehouse/                        # (user와 동일한 구조)
    │
    └── messaging/
        └── port/
            ├── MessagePublisher.kt       # 메시지 발행 포트
            └── ProcessedEventStore.kt    # 이벤트 처리 기록 포트
```

### 인프라스트럭처 계층 (infrastructure/)

```
infrastructure/
└── src/main/kotlin/com/invigoworks/bitda/infrastructure/
    ├── persistence/
    │   ├── user/
    │   │   ├── adapter/UserJpaAdapter.kt     # 레포지토리 구현
    │   │   ├── entity/UserJpaEntity.kt       # JPA 엔티티
    │   │   ├── mapper/UserMapper.kt          # 도메인 ↔ 엔티티 매퍼
    │   │   └── repository/UserJpaRepository.kt  # Spring Data JPA
    │   │
    │   ├── event/
    │   │   ├── adapter/DomainEventPublisher.kt  # 이벤트 발행 구현
    │   │   ├── entity/DomainEventJpaEntity.kt   # Outbox 엔티티
    │   │   └── repository/DomainEventRepository.kt
    │   │
    │   └── support/pagination/
    │       ├── CompositeCursor.kt            # 커서 인코딩/디코딩
    │       └── PageRequestConverter.kt       # 페이지 요청 변환
    │
    └── auth/
        └── adapter/KeycloakUserClientAdapter.kt  # Keycloak 연동
```

### 애플리케이션 계층 (application/api/)

```
application/api/
└── src/main/kotlin/com/invigoworks/bitda/api/
    ├── company/
    │   ├── controller/AdminCompanyController.kt   # REST 컨트롤러
    │   ├── application/
    │   │   ├── command/
    │   │   │   ├── CreateCompanyCommand.kt        # 생성 명령
    │   │   │   ├── PatchCompanyCommand.kt         # 수정 명령
    │   │   │   └── DeleteCompanyCommand.kt        # 삭제 명령
    │   │   ├── query/
    │   │   │   ├── GetCompanyQuery.kt             # 단일 조회
    │   │   │   └── GetAllCompaniesQuery.kt        # 목록 조회
    │   │   └── service/
    │   │       ├── CreateCompanyByAdminUseCase.kt # 생성 유즈케이스
    │   │       ├── GetCompanyByAdminUseCase.kt    # 조회 유즈케이스
    │   │       └── ...
    │   └── dto/
    │       ├── CreateCompanyByAdminRequest.kt     # 요청 DTO
    │       ├── CompanyResponse.kt                 # 응답 DTO
    │       └── CompanySearchParams.kt             # 검색 파라미터
    │
    ├── user/                                      # (company와 동일한 구조)
    ├── warehouse/                                 # (company와 동일한 구조)
    │
    └── config/
        ├── security/SecurityConfig.kt            # 보안 설정
        ├── web/GlobalExceptionHandler.kt         # 전역 예외 처리
        └── jackson/                              # JSON 직렬화 설정
```

---

## 부록: Claude Code Skill 제작 가이드

이 아키텍처를 기반으로 Claude Code Skill을 만들 때 참고할 수 있는 핵심 정보입니다.

### 새 도메인 추가 시 필요한 파일

1. **Domain 계층**
   - `domain/{name}/model/aggregate/{Name}.kt` - 애그리거트 루트
   - `domain/{name}/model/aggregate/value/*.kt` - 값 객체 (필요시)
   - `domain/{name}/port/{Name}Repository.kt` - 레포지토리 포트
   - `domain/{name}/event/{Name}*Event.kt` - 도메인 이벤트들
   - `domain/{name}/error/{Name}Error.kt` - 에러 정의
   - `domain/{name}/query/{Name}SearchCriteria.kt` - 검색 조건

2. **Infrastructure 계층**
   - `infrastructure/persistence/{name}/adapter/{Name}JpaAdapter.kt`
   - `infrastructure/persistence/{name}/entity/{Name}JpaEntity.kt`
   - `infrastructure/persistence/{name}/mapper/{Name}Mapper.kt`
   - `infrastructure/persistence/{name}/repository/{Name}JpaRepository.kt`

3. **Application 계층**
   - `api/{name}/controller/Admin{Name}Controller.kt`
   - `api/{name}/application/command/Create{Name}Command.kt`
   - `api/{name}/application/command/Patch{Name}Command.kt`
   - `api/{name}/application/command/Delete{Name}Command.kt`
   - `api/{name}/application/query/Get{Name}Query.kt`
   - `api/{name}/application/query/GetAll{Name}sQuery.kt`
   - `api/{name}/application/service/Create{Name}ByAdminUseCase.kt`
   - `api/{name}/application/service/Get{Name}ByAdminUseCase.kt`
   - `api/{name}/dto/Create{Name}ByAdminRequest.kt`
   - `api/{name}/dto/Patch{Name}ByAdminRequest.kt`
   - `api/{name}/dto/{Name}Response.kt`
   - `api/{name}/dto/{Name}SearchParams.kt`

### 패턴 적용 체크리스트

- [ ] Aggregate Root가 `AggregateRoot`를 상속하는가?
- [ ] 도메인 이벤트가 상태 변경 시 등록되는가?
- [ ] Repository가 포트(인터페이스)와 어댑터(구현체)로 분리되어 있는가?
- [ ] Command와 Query가 분리되어 있는가?
- [ ] UseCase가 `UseCase<Input, Output>` 인터페이스를 구현하는가?
- [ ] PATCH 요청에 `PatchField<T>`를 사용하는가?
- [ ] 검색 조건이 `SearchCriteria`를 구현하는가?
- [ ] 에러가 `Error` 인터페이스를 구현하는 Enum인가?

---

*문서 작성일: 2025-01-05*
*작성: Claude Code*
