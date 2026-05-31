# TDD 워크플로우 가이드

## Test-First Development Workflow

**For Each Feature Component**:

1. **Specify Test Cases** (before writing ANY code)
   - What inputs will be tested?
   - What outputs are expected?
   - What edge cases must be handled?
   - What error conditions should be tested?

2. **Write Tests** (Red Phase)
   - Write tests that WILL fail
   - Verify tests fail for the right reason
   - Run tests to confirm failure
   - Commit failing tests to track TDD compliance

3. **Implement Code** (Green Phase)
   - Write minimal code to make tests pass
   - Run tests frequently (every 2-5 minutes)
   - Stop when all tests pass
   - No additional functionality beyond tests

4. **Refactor** (Blue Phase)
   - Improve code quality while tests remain green
   - Extract duplicated logic
   - Improve naming and structure
   - Run tests after each refactoring step
   - Commit when refactoring complete

---

## Test Types

### Unit Tests
- **Target**: Individual functions, methods, classes
- **Dependencies**: None or mocked/stubbed
- **Speed**: Fast (<100ms per test)
- **Isolation**: Complete isolation from external systems
- **Coverage**: ≥80% of business logic

### Integration Tests
- **Target**: Interaction between components/modules
- **Dependencies**: May use real dependencies
- **Speed**: Moderate (<1s per test)
- **Isolation**: Tests component boundaries
- **Coverage**: Critical integration points

### End-to-End (E2E) Tests
- **Target**: Complete user workflows
- **Dependencies**: Real or near-real environment
- **Speed**: Slow (seconds to minutes)
- **Isolation**: Full system integration
- **Coverage**: Critical user journeys

---

## Test Coverage Calculation

**Coverage Thresholds** (adjust for your project):
- **Business Logic**: ≥90% (critical code paths)
- **Data Access Layer**: ≥80% (repositories, DAOs)
- **API/Controller Layer**: ≥70% (endpoints)
- **UI/Presentation**: Integration tests preferred over coverage

**Coverage Commands for Kotlin/Gradle**:
```bash
# Kotlin/Gradle (JaCoCo)
./gradlew test jacocoTestReport

# Report location
open build/reports/jacoco/test/html/index.html
```

---

## Common Test Patterns

### Arrange-Act-Assert (AAA) Pattern
```kotlin
@Test
fun `should validate user credentials`() {
    // Arrange: Set up test data and dependencies
    val authService = AuthService(mockUserRepository)
    val credentials = UserCredentials("user@email.com", "password123")

    // Act: Execute the behavior being tested
    val result = authService.authenticate(credentials)

    // Assert: Verify expected outcome
    assertThat(result.isSuccess).isTrue()
    assertThat(result.user).isNotNull()
}
```

### Given-When-Then (BDD Style)
```kotlin
@Test
fun `given valid user when login then should return token`() {
    // Given: Initial context/state
    val user = createValidUser()
    every { userRepository.findByEmail(user.email) } returns user

    // When: Action occurs
    val result = authService.login(user.email, user.password)

    // Then: Observable outcome
    assertThat(result).isInstanceOf(LoginSuccess::class.java)
    assertThat((result as LoginSuccess).token).isNotBlank()
}
```

### Mocking/Stubbing Dependencies (MockK)
```kotlin
@Test
fun `should call repository when creating user`() {
    // Create mock
    val mockRepository = mockk<UserRepository>()
    val service = CreateUserService(mockRepository)

    // Configure mock behavior
    every { mockRepository.save(any()) } returns mockk()

    // Execute
    service.create(CreateUserCommand("test@email.com", "Test User"))

    // Verify
    verify(exactly = 1) { mockRepository.save(any()) }
}
```

---

## Test Documentation in Plan

**In each phase, specify**:
1. **Test File Location**: Exact path where tests will be written
2. **Test Scenarios**: List of specific test cases
3. **Expected Failures**: What error should tests show initially?
4. **Coverage Target**: Percentage for this phase
5. **Dependencies to Mock**: What needs mocking/stubbing?
6. **Test Data**: What fixtures/factories are needed?

---

## TDD Red-Green-Refactor Cycle Visualization

```
Phase 1: 🔴 RED
├── Write test for feature X
├── Run test → FAILS ❌
└── Commit: "test: add failing test for X"

Phase 2: 🟢 GREEN
├── Write minimal code
├── Run test → PASSES ✅
└── Commit: "feat: implement X to pass tests"

Phase 3: 🔵 REFACTOR
├── Improve code quality
├── Run test → STILL PASSES ✅
├── Extract helper methods
├── Run test → STILL PASSES ✅
├── Improve naming
├── Run test → STILL PASSES ✅
└── Commit: "refactor: improve X design"

Repeat for next feature →
```

---

## TDD Example: Adding User Authentication

### Phase 1: RED (Write Failing Tests)

```kotlin
class AuthServiceTest {
    private val mockUserRepository = mockk<UserRepository>()
    private val authService = AuthService(mockUserRepository)

    @Test
    fun `should authenticate user with valid credentials`() {
        // Arrange
        val user = User(email = "user@test.com", passwordHash = hashPassword("password123"))
        every { mockUserRepository.findByEmail("user@test.com") } returns user

        // Act
        val result = authService.authenticate("user@test.com", "password123")

        // Assert
        assertThat(result.isSuccess).isTrue()
        assertThat(result.user).isEqualTo(user)
        // TEST FAILS - AuthService doesn't exist yet
    }
}
```

### Phase 2: GREEN (Minimal Implementation)

```kotlin
class AuthService(private val userRepository: UserRepository) {
    fun authenticate(email: String, password: String): AuthResult {
        val user = userRepository.findByEmail(email)
            ?: return AuthResult.failure("User not found")

        return if (verifyPassword(password, user.passwordHash)) {
            AuthResult.success(user)
        } else {
            AuthResult.failure("Invalid password")
        }
        // TEST PASSES - minimal functionality works
    }
}
```

### Phase 3: REFACTOR (Improve Design)

```kotlin
class AuthService(
    private val userRepository: UserRepository,
    private val passwordEncoder: PasswordEncoder
) {
    fun authenticate(credentials: AuthCredentials): AuthResult {
        // Add input validation
        credentials.validate().onFailure { return AuthResult.failure(it.message) }

        return runCatching {
            val user = userRepository.findByEmail(credentials.email)
                ?: return AuthResult.failure("Invalid credentials")

            if (passwordEncoder.matches(credentials.password, user.passwordHash)) {
                AuthResult.success(user)
            } else {
                AuthResult.failure("Invalid credentials")
            }
        }.getOrElse { e ->
            logger.error("Authentication failed", e)
            AuthResult.failure("Authentication error")
        }
        // TESTS STILL PASS - improved code quality
    }
}
```

---

## Benefits of TDD

| Benefit | Description |
|---------|-------------|
| **Safety** | Tests catch regressions immediately |
| **Design** | Tests force you to think about API design first |
| **Documentation** | Tests document expected behavior |
| **Confidence** | Refactor without fear of breaking things |
| **Quality** | Higher code coverage from day one |
| **Debugging** | Failures point to exact problem area |
