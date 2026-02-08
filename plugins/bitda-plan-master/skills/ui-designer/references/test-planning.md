# Test Planning & Parallel Execution Strategy (Phase 7)

## feature-planner 스킬 연동

코드 생성 전 `feature-planner` 스킬을 활용하여 사전 설계:

```
User: 회사 관리 화면 코드 생성해줘

Process:
1. feature-planner 스킬 호출하여 구현 계획 수립
2. 테스트 시나리오 그룹화 (병렬 처리 가능 단위)
3. UI 코드 생성
4. 테스트 코드 병렬 생성
```

## 테스트 시나리오 그룹화 원칙

**병렬 처리 가능 조건:**
- 서로 다른 기능을 테스트하는 경우
- 상태를 공유하지 않는 독립적인 테스트
- 다른 데이터셋을 사용하는 테스트

**순차 처리 필요 조건:**
- 상태를 공유하는 테스트 (예: 등록 → 수정 → 삭제)
- 이전 테스트 결과에 의존하는 테스트
- 동일한 Mock 데이터를 변경하는 테스트

## 테스트 그룹 분류 예시

### Group A: 목록 조회 테스트 (병렬 가능)
| 테스트 | 설명 | 의존성 |
|--------|------|--------|
| A1 | 초기 목록 렌더링 | 없음 |
| A2 | 검색 필터링 | 없음 |
| A3 | 상태 필터링 | 없음 |
| A4 | 페이지네이션 | 없음 |
| A5 | 정렬 기능 | 없음 |

### Group B: 폼 유효성 검증 테스트 (병렬 가능)
| 테스트 | 설명 | 의존성 |
|--------|------|--------|
| B1 | 필수 필드 검증 | 없음 |
| B2 | 사업자번호 형식 검증 | 없음 |
| B3 | 이메일 형식 검증 | 없음 |
| B4 | 최대 길이 검증 | 없음 |

### Group C: CRUD 시퀀스 테스트 (순차 필요)
| 테스트 | 설명 | 의존성 |
|--------|------|--------|
| C1 | 회사 등록 | 없음 |
| C2 | 등록된 회사 조회 | C1 |
| C3 | 회사 정보 수정 | C2 |
| C4 | 회사 삭제 | C3 |

### Group D: UI 상호작용 테스트 (병렬 가능)
| 테스트 | 설명 | 의존성 |
|--------|------|--------|
| D1 | Sheet 열기/닫기 | 없음 |
| D2 | Dialog 확인/취소 | 없음 |
| D3 | Checkbox 선택/해제 | 없음 |
| D4 | Dropdown 메뉴 동작 | 없음 |

## 병렬 에이전트 실행 전략

**실행 방법:**
```
# 병렬 가능 그룹들을 동시에 에이전트로 실행
Task(Group A 테스트 작성) | Task(Group B 테스트 작성) | Task(Group D 테스트 작성)

# 순차 필요 그룹은 별도 에이전트로 순차 실행
Task(Group C 테스트 작성)
```

**에이전트 호출 예시:**
```typescript
// 병렬 실행 - 3개 에이전트 동시 실행
const parallelAgents = [
  Task({ type: "test-engineer", prompt: "Group A 목록 조회 테스트 작성" }),
  Task({ type: "test-engineer", prompt: "Group B 폼 유효성 검증 테스트 작성" }),
  Task({ type: "test-engineer", prompt: "Group D UI 상호작용 테스트 작성" }),
];

// 순차 실행 - CRUD 시퀀스
const sequentialAgent = Task({
  type: "test-engineer",
  prompt: "Group C 순차 테스트 작성 (상태 의존성 있음)"
});
```

## 테스트 파일 구조

```
src/app/companies/__tests__/
├── group-a/                    # 목록 조회 (병렬)
│   ├── list-render.test.tsx
│   ├── search-filter.test.tsx
│   └── pagination.test.tsx
├── group-b/                    # 폼 검증 (병렬)
│   ├── required-fields.test.tsx
│   └── email-format.test.tsx
├── group-c/                    # CRUD 시퀀스 (순차)
│   └── crud-sequence.test.tsx
└── group-d/                    # UI 상호작용 (병렬)
    └── sheet-interaction.test.tsx
```

## 병렬 실행 명령어

```bash
# 병렬 그룹 동시 실행
npm test -- --testPathPattern="group-[abd]" --maxWorkers=4

# 순차 그룹 별도 실행
npm test -- --testPathPattern="group-[ce]" --runInBand
```
