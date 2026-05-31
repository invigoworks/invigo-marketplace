# 구현 계획서 템플릿 (GitHub 이슈 댓글용)

이 템플릿을 GitHub 이슈 댓글로 등록할 때 사용한다.

---

```markdown
## 📋 엔터프라이즈급 구현 계획서

> 🏛️ **"할거면 제대로 하자"** — 이 계획서는 프로덕션 레디 수준의 구현을 목표로 한다.

**이슈**: #{issue-number}
**작성일**: YYYY-MM-DD
**예상 소요**: X시간
**Scope**: Small / Medium / Large

---

**⚠️ CRITICAL INSTRUCTIONS**: After completing each phase:
1. ✅ Check off completed task checkboxes
2. 🧪 Run all quality gate validation commands
3. ⚠️ Verify ALL quality gate items pass
4. 📅 Update progress in comments
5. 📝 Document issues/learnings in comments
6. ➡️ Only then proceed to next phase

⛔ **DO NOT skip quality gates or proceed with failing checks**

---

### 🎯 목표

{이슈에서 파악한 핵심 목표}

### 성공 기준
- [ ] {성공 기준 1}
- [ ] {성공 기준 2}
- [ ] {성공 기준 3}

---

### 🏗️ 아키텍처 결정사항

| 결정 | 근거 | 트레이드오프 |
|------|------|-------------|
| {결정 1} | {이유} | {대안 대비 장단점} |
| {결정 2} | {이유} | {대안 대비 장단점} |

---

### 📦 의존성

#### 시작 전 필요사항
- [ ] {의존성 1}
- [ ] {의존성 2}

#### 외부 의존성
- {라이브러리/패키지}: version X.Y.Z

---

### 🧪 테스트 전략

**TDD Principle**: Write tests FIRST, then implement to make them pass

| 테스트 유형 | 커버리지 목표 | 용도 |
|------------|--------------|------|
| **Unit Tests** | ≥80% | 비즈니스 로직, 모델, 핵심 알고리즘 |
| **Integration Tests** | Critical paths | 컴포넌트 상호작용, 데이터 흐름 |
| **E2E Tests** | Key user flows | 전체 시스템 동작 검증 |

---

## 🚀 Implementation Phases

### 📦 Phase 1: {Foundation}

**Goal**: {이 페이즈의 구체적 목표}
**예상 시간**: X시간
**Status**: ⏳ Pending

#### 🔴 RED: 테스트 먼저 작성

- [ ] **Test 1.1**: {테스트 설명}
  - File: `{테스트 파일 경로}`
  - Expected: Tests FAIL (red) because feature doesn't exist yet
  - Test cases:
    - Happy path scenarios
    - Edge cases
    - Error conditions

- [ ] **Test 1.2**: {통합 테스트 설명}
  - File: `{테스트 파일 경로}`
  - Expected: Tests FAIL (red)

#### 🟢 GREEN: 구현

- [ ] **Task 1.3**: {구현 내용}
  - File: `{소스 파일 경로}`
  - Goal: Make Test 1.1 pass with minimal code

- [ ] **Task 1.4**: {구현 내용}
  - File: `{소스 파일 경로}`
  - Goal: Make Test 1.2 pass

#### 🔵 REFACTOR: 리팩토링

- [ ] **Task 1.5**: Refactor for code quality
  - [ ] Remove duplication (DRY)
  - [ ] Improve naming clarity
  - [ ] Extract reusable components
  - [ ] Add inline documentation

#### ✅ Quality Gate

**⚠️ STOP: Do NOT proceed to Phase 2 until ALL checks pass**

```bash
./gradlew build test ktlintCheck
```

**TDD Compliance**:
- [ ] Red Phase: Tests written FIRST and initially failed
- [ ] Green Phase: Production code makes tests pass
- [ ] Refactor Phase: Code improved while tests stay green
- [ ] Coverage: ≥80% for new business logic

**Build & Tests**:
- [ ] Build successful
- [ ] All tests passing
- [ ] No flaky tests

**Code Quality**:
- [ ] ktlintCheck passing
- [ ] No compiler warnings

---

### 📦 Phase 2: {Core Feature}

**Goal**: {구체적 목표}
**예상 시간**: X시간
**Status**: ⏳ Pending

#### 🔴 RED: 테스트 먼저 작성
- [ ] **Test 2.1**: {테스트 설명}
- [ ] **Test 2.2**: {테스트 설명}

#### 🟢 GREEN: 구현
- [ ] **Task 2.3**: {구현 내용}
- [ ] **Task 2.4**: {구현 내용}

#### 🔵 REFACTOR: 리팩토링
- [ ] **Task 2.5**: Refactor for code quality

#### ✅ Quality Gate
```bash
./gradlew build test ktlintCheck
```
- [ ] All checks passing

---

### 📦 Phase 3: {Integration / API}

**Goal**: {구체적 목표}
**예상 시간**: X시간
**Status**: ⏳ Pending

#### 🔴 RED: 테스트 먼저 작성
- [ ] **Test 3.1**: {E2E 또는 통합 테스트}

#### 🟢 GREEN: 구현
- [ ] **Task 3.2**: {API 구현 등}

#### 🔵 REFACTOR: 리팩토링
- [ ] **Task 3.3**: Final cleanup

#### ✅ Quality Gate
```bash
./gradlew build test ktlintCheck
```
- [ ] All checks passing
- [ ] API 수동 테스트 완료

---

## ⚠️ 리스크 평가

| 리스크 | 확률 | 영향 | 대응 전략 |
|--------|------|------|----------|
| {리스크 1} | Low/Med/High | Low/Med/High | {대응 방법} |
| {리스크 2} | Low/Med/High | Low/Med/High | {대응 방법} |

---

## 🔄 롤백 전략

### Phase 1 실패 시
- Revert: `git revert` 또는 파일 삭제
- 영향 범위: {영향받는 파일/기능}

### Phase 2 실패 시
- Restore to Phase 1 complete state
- DB migration rollback: {해당되는 경우}

### Phase 3 실패 시
- Restore to Phase 2 complete state
- API endpoint 비활성화

---

## 📊 진행 상황 추적

### 완료 상태
- **Phase 1**: ⏳ 0%
- **Phase 2**: ⏳ 0%
- **Phase 3**: ⏳ 0%

**전체 진행률**: 0%

### 시간 추적
| Phase | 예상 | 실제 | 차이 |
|-------|------|------|------|
| Phase 1 | X시간 | - | - |
| Phase 2 | X시간 | - | - |
| Phase 3 | X시간 | - | - |
| **Total** | X시간 | - | - |

---

## 📝 Notes & Learnings

{구현 중 발견한 인사이트, 결정 사항 변경, 디버깅 팁 등을 기록}

---

## ✅ 최종 체크리스트

**완료로 표시하기 전**:

**기본 품질**:
- [ ] 모든 Phase 완료 + Quality Gate 통과
- [ ] 전체 통합 테스트 수행 (`./gradlew test`)
- [ ] `ktlintCheck` 통과

**엔터프라이즈 기준 (할거면 제대로 하자)**:
- [ ] CLAUDE.md 아키텍처 규칙 준수 (Hexagonal Architecture, `internal`, CQS)
- [ ] 비즈니스 규칙 Unit 테스트 커버리지 ≥80%
- [ ] E2E 테스트 §6.2 헌법 준수 (Track 상속, `@SpringBootTest` 직접 사용 금지)
- [ ] 보안: 인증/인가 정책 적용 여부 확인
- [ ] 감사 로그: 상태 변경 UseCase AuditableEvent 적용 여부 확인
- [ ] DB 마이그레이션: Flyway 네이밍 규칙 준수, 병합 후 수정 금지
- [ ] KDoc: UseCase 인터페이스, Domain AggregateRoot 문서화 완료
- [ ] Swagger: 새 API 엔드포인트 문서 업데이트
```

---

## Phase Sizing Guidelines

| Scope | Phases | 총 시간 | 적용 상황 |
|-------|--------|--------|----------|
| **Small** | 2-3개 | 3-6시간 | 단일 컴포넌트, 간단한 기능 |
| **Medium** | 4-5개 | 8-15시간 | 여러 컴포넌트, DB 변경 포함 |
| **Large** | 6-7개 | 15-25시간 | 복잡한 기능, 다중 통합 |

### Small Scope 예시
- Add dark mode toggle
- Create new form component
- Add validation to existing field

### Medium Scope 예시
- User authentication system
- Search functionality
- CRUD for new entity

### Large Scope 예시
- AI-powered search with embeddings
- Real-time collaboration
- Complex reporting system

---

## Risk Assessment Categories

식별하고 문서화할 리스크:

- **Technical Risks**: API changes, performance issues, data migration
- **Dependency Risks**: External library updates, third-party service availability
- **Timeline Risks**: Complexity unknowns, blocking dependencies
- **Quality Risks**: Test coverage gaps, regression potential

각 리스크에 대해:
- **Probability**: Low/Medium/High
- **Impact**: Low/Medium/High
- **Mitigation Strategy**: 구체적인 조치 단계
