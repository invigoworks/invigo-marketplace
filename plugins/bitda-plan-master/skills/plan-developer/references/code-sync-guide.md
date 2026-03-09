# Code-to-Planning Document Sync Guide

> Mode 1 (기존 기획 업데이트) 실행 시 코드 변경사항을 분석하여 기획서와의 불일치를 감지하는 가이드.
> **팀 기반 워크플로우**: 3개 에이전트(code-analyst, content-writer, cross-validator)가 각 단계를 전담한다.

---

## 에이전트 역할 정의

### code-analyst (코드 변경 분석 전담)

**목표**: BASE 커밋 이후 모든 코드 변경을 커밋별로 분석하여 기획서 반영 체크리스트 생성.

**절차**:
1. 이 가이드의 Section 3 (git diff 분석 프로토콜) 전체를 따른다
2. Section 4 (변경 분류)로 각 변경을 분류한다
3. Section 5 형식으로 `/tmp/<module>-code-changes.md`에 저장한다

**필수 산출물**: `/tmp/<module>-code-changes.md`
- 커밋별 변경 상세 (변경 파일, 변경 내용, 기획서 반영 대상)
- **통합 기획서 반영 체크리스트** (PART별 정리, 각 항목에 출처 커밋 표기)

**주의사항**:
- `git diff BASE..HEAD`만으로 분석 완료하지 않는다. 반드시 커밋별 `git show`를 실행한다
- 커밋 메시지에서 변경 의도를 파악하여 기획서 반영 항목에 포함한다
- mock-data 변경은 체크리스트에서 제외하되, 타입 변경 확인용으로 참고한다

### content-writer (기획서 수정 전담)

**목표**: 현재 기획서 + 코드 변경 체크리스트 + 사용자 요청을 병합하여 수정본 작성.

**입력**:
1. `/tmp/<module>-current-plan.md` — 현재 Notion 기획서 원본
2. `/tmp/<module>-code-changes.md` — 코드 변경 요약 + 통합 체크리스트
3. 사용자의 수정 요청 사항 (프롬프트로 전달)

**절차**:
1. 현재 기획서를 읽는다
2. 통합 체크리스트의 **모든 항목**을 기획서의 해당 섹션에서 찾아 반영한다
3. 사용자 요청 사항을 추가 반영한다
4. Notion 업로드 규칙(`references/notion-upload-rules.md`)을 준수하여 작성한다
5. `/tmp/plan-content-validate-input.md`에 저장한다

**주의사항**:
- 체크리스트 항목을 건너뛰지 않는다. 판단이 어려운 항목은 `<!-- TODO: 확인 필요 -->` 주석으로 표기한다
- 기존 기획서 구조(PART 1/2/3)를 유지한다. 섹션 순서를 변경하지 않는다

### cross-validator (교차 검증 전담)

**목표**: 수정본에 통합 체크리스트의 모든 항목이 반영되었는지 1:1 확인.

**입력**:
1. `/tmp/<module>-code-changes.md` — 통합 체크리스트 섹션
2. `/tmp/plan-content-validate-input.md` — 수정본

**절차**: 이 가이드의 Section 6 (교차 검증) 전체를 따른다.

**산출물**: `/tmp/<module>-validation-report.md`
```markdown
## 교차 검증 결과

**총 항목**: X개
**반영됨 [x]**: Y개
**누락 [!]**: Z개
**의도적 미반영 [-]**: W개

### 항목별 상세
| # | 출처 커밋 | 체크리스트 항목 | 상태 | 수정본 위치/사유 |
|---|----------|---------------|------|----------------|
| 1 | Commit 1 | 데이터 명세: warehouseId 필드 | [x] | PART 2 섹션 4 |
| 2 | Commit 2 | 비즈니스 규칙: 재보관 증빙 필수 | [!] | 누락 → 보완 필요 |
| ... | | | | |

### 누락 항목 목록 ([!] 상태)
1. (Commit 2) 비즈니스 규칙: 재보관 증빙 필수 → PART 2 섹션 7에 추가 필요
```

**주의사항**:
- `[!]` 항목이 1개라도 있으면 **검증 실패**. content-writer에게 누락 목록을 전달하여 보완 요청한다
- `[-]` 의도적 미반영은 반드시 사유를 기록한다 (근거 없이 미반영 불가)
- 최종적으로 모든 항목이 `[x]` 또는 `[-]`가 되어야 한다

---

## 1. 모듈 디렉토리 → 기획문서 매핑

모듈 경로로 기획문서를 식별한다. Page ID는 `notion-manifest.md`에서 조회.

| 모듈 경로 | 기획문서 검색 키워드 |
|-----------|-------------------|
| inventory/return-disposal/ | 환입 및 폐기 |
| inventory/product/ | 제품관리 |
| liquor-tax/product-declaration/ | 상품신고 |
| liquor-tax/evidence/ | 증빙관리 |
| production/plan/ | 생산계획 |
| production/process/ | 공정현황 |
| production/work/ | 작업현황 |
| settings/company/ | 회사관리 |
| settings/warehouse/ | 창고관리 |
| document/ | 문서관리 |

> 매핑에 없는 모듈은 사용자에게 경로 확인 후 이 테이블에 행 추가.

---

## 2. 파일 패턴 → 기획서 섹션 매핑

변경된 파일 유형에 따라 기획서의 어떤 섹션을 확인/업데이트해야 하는지 결정한다.

| 파일 패턴 | 기획서 섹션 | 확인 항목 |
|-----------|-----------|----------|
| types.ts | PART 2: 데이터 명세 | 필드 추가/제거/타입 변경 |
| hooks/*.ts | PART 2: 비즈니스 규칙 | 계산 로직, 조건 분기, 상태 전이 |
| form-page.tsx | PART 2: 컴포넌트 명세, 테이블 컬럼 정의 | 컬럼 추가/제거, UI 변경 |
| *Table.tsx, *Dialog.tsx | PART 2: 컴포넌트 명세 | 컴포넌트 Props, 동작 변경 |
| *Sheet.tsx | PART 2: 컴포넌트 명세 | 오버레이 동작, 입력 필드 변경 |
| validation.ts, *.schema.ts | PART 2: 유효성 검증 | 검증 규칙 변경 |
| page.tsx (목록) | PART 1: 레이아웃, PART 2: 상태별 UI | 화면 구성 변경 |
| *-page.tsx (상세) | PART 1: 화면 흐름 | 네비게이션 변경 |
| mock-data/*.ts | (직접 반영 불필요) | 타입 변경 확인용 참고 |
| constants.ts | PART 2: 비즈니스 규칙 | 상수값, 옵션 목록 변경 |

---

## 3. git diff 분석 프로토콜

> **핵심 원칙**: 구현 후 코드 수정은 여러 커밋에 걸쳐 진행된다. `git diff BASE..HEAD`(최종 diff)만으로는 중간 커밋의 변경 의도와 세부 사항이 누락된다. 따라서 **커밋별 개별 분석 → 통합 체크리스트** 방식을 사용한다.

### 3.1 기획 업데이트 기준점(BASE) 찾기

```bash
# 기획 관련 커밋 검색 (메시지에 "기획", "plan", "Notion", "v2" 등 포함)
git log --oneline --all --grep="기획\|plan\|Notion" -- <module-path>/ | head -1
```

- 기획 관련 커밋이 없으면: 초안 기획서 작성 직후의 첫 구현 커밋 이전을 BASE로 사용
- BASE를 찾았으면 해당 커밋 해시 기록

### 3.2 커밋 목록 전체 추출 (CRITICAL)

```bash
# BASE 이후 모든 커밋을 시간순으로 나열
git log --oneline --reverse <BASE>..HEAD -- <module-path>/
```

> **⚠️ 모든 커밋을 빠짐없이 나열해야 한다.** 커밋이 10개 이상이면 `--reverse` 옵션으로 시간순 정렬하여 흐름을 파악한다.

### 3.3 커밋별 개별 분석

**각 커밋에 대해 다음을 수행한다:**

```bash
# 커밋 N의 변경 파일 확인
git show --stat <commit-hash> -- <module-path>/

# 커밋 N의 상세 diff 확인
git show <commit-hash> -- <module-path>/
```

각 커밋에서 아래를 추출한다:
1. **커밋 메시지** — 변경 의도 파악
2. **변경 파일 목록** — 파일 패턴→섹션 매핑 적용
3. **핵심 변경 내용** — 필드 추가/제거, 로직 변경, UI 변경 등 구체적 항목

### 3.4 최종 diff로 교차 확인

커밋별 분석 후, 최종 diff도 확인하여 누락된 변경이 없는지 검증한다:

```bash
# 전체 변경 파일 목록
git diff <BASE>..HEAD --name-only -- <module-path>/

# 핵심 파일별 최종 상태 diff
git diff <BASE>..HEAD -- <module-path>/types.ts
git diff <BASE>..HEAD -- <module-path>/hooks/
git diff <BASE>..HEAD -- <module-path>/components/
git diff <BASE>..HEAD -- <module-path>/*-page.tsx <module-path>/form-page.tsx
```

> 커밋별 분석에서 발견한 항목 + 최종 diff에서만 보이는 누적 변경 = **완전한 변경 목록**

---

## 4. 변경 분류

git diff 결과를 아래 5가지 유형으로 분류한다. (`verify-plan-changes`와 동일 체계)

| 변경 유형 | 감지 패턴 | 기획서 반영 항목 |
|-----------|----------|----------------|
| 필드 추가/제거 | interface 멤버의 `+`/`-` 라인 | 데이터 명세 테이블 |
| 컬럼 추가/제거 | TableHead/TableCell 추가/제거 | 테이블 컬럼 정의 |
| 비즈니스 규칙 변경 | hook 내 조건/로직 변경 | 비즈니스 규칙 섹션 |
| UI 컴포넌트 변경 | 컴포넌트 Props/렌더링 변경 | 컴포넌트 명세 |
| 검증 규칙 변경 | validation/Zod 스키마 변경 | 유효성 검증 섹션 |

---

## 5. 변경 요약 파일 형식 (커밋별 추적)

분석 결과를 `/tmp/<module>-code-changes.md`에 저장한다.

```markdown
# 코드 변경 요약: <모듈명>

**분석 기간**: <BASE 커밋 해시> ~ HEAD
**총 커밋 수**: N개
**변경 파일 수**: M개

---

## 커밋별 변경 상세

### Commit 1: <hash> <커밋 메시지>
- **변경 파일**: file1.ts, file2.tsx
- **변경 내용**:
  - [필드 추가] ReturnItem에 warehouseId 필드 추가
  - [UI 변경] 환입 테이블에 창고 선택 컬럼 추가
- **기획서 반영 대상**:
  - [ ] PART 2 데이터 명세: warehouseId 필드 추가
  - [ ] PART 2 테이블 컬럼 정의: 창고 컬럼 추가

### Commit 2: <hash> <커밋 메시지>
- **변경 파일**: hooks/useReturnDisposalForm.ts
- **변경 내용**:
  - [비즈니스 규칙] 처리방식 '재보관' 시 증빙 필수 검증 추가
- **기획서 반영 대상**:
  - [ ] PART 2 비즈니스 규칙: 재보관 증빙 필수 조건 추가
  - [ ] PART 2 유효성 검증: 증빙 완료 검증 규칙 추가

### Commit 3: ...

---

## 통합 기획서 반영 체크리스트

> 위 커밋별 항목을 기획서 섹션별로 재정리한 **마스터 체크리스트**.
> 콘텐츠 수정본 작성 시 이 체크리스트의 모든 항목을 반영해야 한다.

### PART 1 관련
- [ ] (Commit 3) 화면 흐름에 폐기 대기 페이지 네비게이션 추가

### PART 2 관련
- [ ] (Commit 1) 데이터 명세: warehouseId 필드
- [ ] (Commit 1) 테이블 컬럼: 창고 선택 컬럼
- [ ] (Commit 2) 비즈니스 규칙: 재보관 증빙 필수
- [ ] (Commit 2) 유효성 검증: 증빙 완료 검증
- [ ] (Commit 4) 컴포넌트 명세: DisposalConversionDialog에 증빙 차단 로직

### PART 3 관련
- [ ] (해당 없음)

**총 반영 항목: X개**
```

---

## 6. 교차 검증 (CRITICAL - 누락 방지)

콘텐츠 수정본 작성 후, **통합 체크리스트의 모든 항목**을 하나씩 검증한다.

### 검증 절차

1. **체크리스트 순회**: 각 항목에 대해 수정본에서 해당 내용이 반영된 위치를 확인
2. **상태 표기**:
   - `[x]` **반영됨** — 수정본에 해당 내용 존재
   - `[!]` **누락됨** — 수정본에 미반영 → **즉시 보완**
   - `[-]` **의도적 미반영** — 사유 기록 (예: "mock-data 전용 변경")
3. **누락 항목 보완**: `[!]` 항목이 있으면 수정본을 재작성하여 반영
4. **최종 확인**: 모든 항목이 `[x]` 또는 `[-]`가 될 때까지 반복

### 검증 결과 리포트

```markdown
## 교차 검증 결과

**총 항목**: X개
**반영됨 [x]**: Y개
**누락 보완 [!→x]**: Z개
**의도적 미반영 [-]**: W개 (사유 첨부)

### 누락 보완 내역
1. (Commit 2) 비즈니스 규칙: 재보관 증빙 필수 → PART 2 섹션 7에 추가
2. ...
```

> **⚠️ 교차 검증을 통과하지 못한 수정본은 Notion에 업로드하지 않는다.**
