---
name: issue-create
description: GitHub 이슈를 일관된 양식으로 생성하는 스킬입니다. 사용자 요청을 분석하여 범위가 크면 여러 이슈로 분할을 제안하고, Parent-Sub Issue 관계를 설정합니다. 이 스킬은 사용자가 "이슈 생성", "이슈 등록", "/issue-create" 등을 요청할 때 사용됩니다.
---

# Issue Create

## Purpose

GitHub 이슈를 일관된 양식으로 생성한다.
범위가 큰 요청은 여러 이슈로 분할하여 Parent-Sub Issue 관계를 설정한다.

## Configuration

```
Repository: invigoworks/bitda-back
Labels:
  - 유형: feature, bug, refactor, docs, test
  - 우선순위: priority:high, priority:medium, priority:low
  - 크기: size:small, size:medium, size:large
  - 상태: in-progress, blocked, review-needed
  - 계층: epic (Parent Issue에만)
  - API 변경: api-change (API 인터페이스 변경 시 자동 부착)
```

## Workflow

### Step 1: 요청 분석

사용자의 요청을 분석하여 다음을 파악한다:

1. **기능 범위**: 어떤 기능을 구현해야 하는지
2. **유형 판별**: feature, bug, refactor, docs, test 중 하나
3. **도메인 식별**: 코드베이스의 어떤 도메인에 해당하는지
4. **예상 크기**: small (1-2시간), medium (3-8시간), large (1-3일)

### Step 1.5: 정보 보완 요청 (필요시)

요청 분석 후 다음 항목 중 **불충분하거나 모호한 정보**가 있으면 사용자에게 질문한다.

#### 필수 정보 체크리스트

| 항목 | 충분한 경우 | 불충분한 경우 (질문 필요) |
|------|------------|-------------------------|
| **기능 범위** | 구체적인 기능이 명시됨 | "개선해줘", "만들어줘" 등 추상적 표현 |
| **배경/목적** | 왜 필요한지 파악 가능 | 기능의 필요성이 불명확 |
| **요구사항** | 구체적 동작이 기술됨 | 세부 동작이 정의되지 않음 |
| **도메인** | 어떤 영역인지 명확 | 여러 도메인 후보가 있음 |
| **우선순위** | 긴급도가 명시되거나 추론 가능 | 우선순위 판단 불가 |

#### 질문 형식

```
이슈 등록을 위해 다음 정보가 추가로 필요합니다:

1. **{불충분한 항목 1}**: {구체적 질문}
2. **{불충분한 항목 2}**: {구체적 질문}

또는 더 구체적인 요구사항을 설명해주세요.
```

#### 질문 예시

**기능 범위가 모호한 경우**:
```
"로그인 기능을 개선해줘"라고 요청하셨는데,
구체적으로 어떤 부분을 개선하고 싶으신가요?
1. 로그인 속도 개선?
2. 새로운 로그인 방식 추가 (OAuth, 2FA 등)?
3. 로그인 UI 변경?
4. 기타 (직접 설명)
```

**요구사항이 불충분한 경우**:
```
"엑셀 내보내기 기능" 이슈를 등록하려면 다음 정보가 필요합니다:
1. 어떤 데이터를 내보내나요? (사용자 목록, 주문 내역 등)
2. 어떤 컬럼이 포함되어야 하나요?
3. 필터링/정렬 옵션이 필요한가요?
```

**도메인이 불명확한 경우**:
```
이 기능이 다음 중 어느 도메인에 속하나요?
1. user (사용자 관리)
2. subscription (구독 관리)
3. warehouse (창고 관리)
4. 새 도메인 생성
```

#### 추가 질문 없이 진행하는 경우

- 모든 필수 정보가 충분히 제공됨
- 코드베이스 분석으로 누락 정보를 합리적으로 추론 가능
- 사용자가 `/issue-create --quick` 옵션으로 빠른 생성 요청

**정보가 충분하면 Step 2로 진행한다.**

### Step 2: 범위 분할 판단

다음 기준으로 이슈 분할 여부를 결정한다:

**분할이 필요한 경우**:
- 예상 작업 시간이 8시간 초과
- 여러 도메인에 걸치는 작업
- 독립적으로 완료 가능한 여러 기능 포함
- 여러 API 엔드포인트를 추가해야 하는 경우

**분할 제안 형식**:
```
이 요청은 다음과 같이 분할하는 것을 제안합니다:

1. [Parent Issue] {전체 기능명} (epic)
   ├── [Sub-Issue 1] {하위 기능 1} (size:small)
   ├── [Sub-Issue 2] {하위 기능 2} (size:medium)
   └── [Sub-Issue 3] {하위 기능 3} (size:small)

이대로 진행할까요? 또는 다른 분할 방식을 제안해주세요.
```

**중요**: 사용자 승인 후에만 이슈를 생성한다.

### Step 3: 이슈 생성

#### 이슈 본문 템플릿

```markdown
## 개요
{기능에 대한 간단한 설명}

## 배경
{왜 이 기능이 필요한지, 어떤 문제를 해결하는지}

## 상세 요구사항
- [ ] {요구사항 1}
- [ ] {요구사항 2}
- [ ] {요구사항 3}

## 기술적 고려사항
- {아키텍처 관련 참고사항}
- {의존성 또는 연관 컴포넌트}

## 완료 기준
- [ ] 기능 구현 완료
- [ ] 테스트 작성 완료
- [ ] 코드 리뷰 완료

## 참고자료
- {관련 문서 링크}
- {참고할 기존 구현}
```

#### 라벨 자동 할당

| 조건 | 라벨 |
|------|------|
| 새 기능 | `feature` |
| 버그 수정 | `bug` |
| 리팩토링 | `refactor` |
| 문서 작업 | `docs` |
| 테스트 추가 | `test` |
| Parent Issue | `epic` |
| 1-2시간 작업 | `size:small` |
| 3-8시간 작업 | `size:medium` |
| 1-3일 작업 | `size:large` |
| **API 변경** | `api-change` |

#### API 변경 감지 (api-change 라벨 자동 부착)

다음 조건 중 하나라도 해당되면 `api-change` 라벨을 자동으로 추가한다:

**키워드 감지** (이슈 제목/본문):
- API, 엔드포인트, endpoint, REST, HTTP
- Controller, 컨트롤러
- Request, Response, DTO
- GET, POST, PUT, PATCH, DELETE (대문자)
- `/api/v1/...` 패턴

**작업 유형 감지**:
- 새로운 API 추가
- 기존 API 수정 (요청/응답 스키마 변경)
- API 삭제 또는 deprecation
- API 권한/인증 변경

**참고**: `api-change` 라벨이 붙은 이슈의 PR 병합 시, `/pr-merge` 스킬이 Notion API 문서 동기화를 제안한다.

### Step 4: Parent-Sub Issue 연결

분할된 이슈의 경우:

1. **Parent Issue 먼저 생성**:
   ```bash
   gh issue create --title "[Epic] {전체 기능명}" \
     --body "{본문}" \
     --label "epic,feature,size:large" \
     -R invigoworks/bitda-back
   ```

2. **Sub-Issue 생성 및 연결**:
   ```bash
   # Sub-Issue 생성
   gh issue create --title "{하위 기능명}" \
     --body "{본문}" \
     --label "feature,size:small" \
     -R invigoworks/bitda-back
   ```

3. **Parent Issue 본문에 Sub-Issue 목록 추가**:
   ```bash
   # Parent Issue 본문 업데이트
   gh issue edit {parent-number} --body "{updated-body-with-sub-issues}" \
     -R invigoworks/bitda-back
   ```

   본문에 추가할 형식:
   ```markdown
   ## Sub-Issues
   - [ ] #{sub-issue-1} {하위 기능 1}
   - [ ] #{sub-issue-2} {하위 기능 2}
   - [ ] #{sub-issue-3} {하위 기능 3}
   ```

### Step 5: 결과 보고

이슈 생성 완료 후 사용자에게 보고한다:

```
✅ 이슈가 생성되었습니다.

| 유형 | 번호 | 제목 | 라벨 |
|------|------|------|------|
| Parent | #100 | [Epic] 사용자 인증 기능 | epic, feature |
| Sub | #101 | 로그인 API 구현 | feature, size:small |
| Sub | #102 | 회원가입 API 구현 | feature, size:medium |

다음 단계:
- `/issue-plan #101` 로 계획서 작성
```

## 이슈 제목 컨벤션

| 유형 | 형식 | 예시 |
|------|------|------|
| Feature | `[Feature] {기능명}` | `[Feature] 사용자 로그인 기능 구현` |
| Bug | `[Bug] {버그 설명}` | `[Bug] 로그인 시 토큰 만료 처리 오류` |
| Refactor | `[Refactor] {리팩토링 대상}` | `[Refactor] UserService 의존성 정리` |
| Test | `[Test] {테스트 대상}` | `[Test] UserService 단위 테스트 추가` |
| Docs | `[Docs] {문서 대상}` | `[Docs] API 문서 업데이트` |
| Epic | `[Epic] {전체 기능명}` | `[Epic] 사용자 인증 시스템` |

## CLI Reference

```bash
# 이슈 생성
gh issue create --title "제목" --body "본문" --label "label1,label2" -R owner/repo

# 이슈 조회
gh issue view {number} -R owner/repo

# 이슈 본문 수정
gh issue edit {number} --body "새 본문" -R owner/repo

# 이슈에 라벨 추가
gh issue edit {number} --add-label "label" -R owner/repo

# 이슈 목록
gh issue list -R owner/repo --label "label"
```
