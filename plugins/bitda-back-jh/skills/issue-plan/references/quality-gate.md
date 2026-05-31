# Quality Gate 표준

## Quality Gate Standards

각 Phase MUST validate these items before proceeding to next phase.

---

## TDD Compliance (CRITICAL)

- [ ] **Red Phase**: Tests were written FIRST and initially failed
- [ ] **Green Phase**: Production code written to make tests pass
- [ ] **Refactor Phase**: Code improved while tests still pass
- [ ] **Coverage Check**: Test coverage meets requirements

```bash
# Coverage check command
./gradlew test jacocoTestReport
```

---

## Build & Compilation

- [ ] Project builds/compiles without errors
- [ ] No syntax errors
- [ ] All dependencies resolved

```bash
./gradlew build
```

---

## Testing

- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Test coverage maintained or improved
- [ ] Unit tests: ≥80% coverage for business logic
- [ ] Integration tests: Critical user flows validated
- [ ] Test suite runs in acceptable time (<5 minutes)
- [ ] No flaky tests (run 3+ times to verify)

```bash
./gradlew test
```

---

## Code Quality

- [ ] Linting passes with no errors
- [ ] Type checking passes
- [ ] Code formatting consistent

```bash
./gradlew ktlintCheck

# Auto-fix if needed
./gradlew ktlintFormat
```

---

## Functionality

- [ ] Manual testing confirms feature works
- [ ] No regressions in existing functionality
- [ ] Edge cases tested
- [ ] Error states handled properly

---

## Security & Performance

- [ ] No new security vulnerabilities
- [ ] No performance degradation
- [ ] Resource usage acceptable
- [ ] No memory leaks or resource issues
- [ ] Proper error handling implemented

---

## Documentation

- [ ] Code comments updated (complex logic)
- [ ] KDoc for public interfaces
- [ ] README updated if needed

---

## Validation Commands (Kotlin/Gradle)

```bash
# Full validation suite
./gradlew build test ktlintCheck

# Individual checks
./gradlew build              # Build verification
./gradlew test               # Run all tests
./gradlew ktlintCheck        # Code style check
./gradlew ktlintFormat       # Auto-fix code style
./gradlew jacocoTestReport   # Coverage report
```

---

## Manual Test Checklist Template

Phase 완료 시 수동으로 확인할 항목:

- [ ] **Happy Path**: 정상 시나리오 동작 확인
- [ ] **Edge Cases**: 경계 조건 테스트
- [ ] **Error Handling**: 예외 상황 처리 확인
- [ ] **API Response**: 올바른 응답 형식 확인
- [ ] **Database State**: 데이터 정합성 확인

---

## Progress Tracking Protocol

```markdown
**CRITICAL INSTRUCTIONS**: After completing each phase:
1. ✅ Check off completed task checkboxes
2. 🧪 Run all quality gate validation commands
3. ⚠️ Verify ALL quality gate items pass
4. 📅 Update "Last Updated" date
5. 📝 Document learnings in Notes section
6. ➡️ Only then proceed to next phase

⛔ DO NOT skip quality gates or proceed with failing checks
```

---

## Phase Transition Criteria

| 조건 | 다음 Phase 진행 가능 여부 |
|------|--------------------------|
| Build 실패 | ❌ 불가 |
| 테스트 실패 | ❌ 불가 |
| ktlintCheck 실패 | ❌ 불가 (ktlintFormat 후 재시도) |
| 커버리지 미달 | ⚠️ 검토 후 진행 |
| 수동 테스트 미완료 | ⚠️ 검토 후 진행 |
| 모든 항목 통과 | ✅ 진행 가능 |
