---
name: prd-to-issues
description: |
  plan-master PRD 기획서 파일(.md)을 파싱하여 bitda-back 백엔드 구현에 필요한
  GitHub 이슈를 자동 생성하는 스킬입니다.
  PRD의 엔티티, AC, DB 스키마를 분석해 Epic + Sub-Issue 구조로 제안하고
  사용자 승인 후 invigoworks/bitda-back 레포에 이슈를 등록합니다.
  이 스킬은 다음 상황에서 사용됩니다:
  - 사용자가 PRD 파일 경로를 제공하고 이슈 생성을 요청할 때
  - "/prd-to-issues", "기획서로 이슈 만들어줘", "PRD 이슈화" 등을 요청할 때
  - plan-master의 spec 파일을 bitda-back 이슈로 변환할 때
---

# PRD to Issues

plan-master PRD 기획서를 파싱하여 bitda-back 백엔드 구현 이슈를 자동 생성한다.
PRD 구조 상세는 `references/prd-structure.md`를 참조한다.

## Configuration

```
Repository: invigoworks/bitda-back
PRD 기본 경로: /Users/gimjinhyeog/Desktop/coding/plan-master/docs/specs/
```

## Workflow

### Step 0: PRD 파일 경로 확보

파일 경로를 다음 우선순위로 결정한다:

1. **인자로 전달된 경우**: `/prd-to-issues path/to/file.md`
2. **사용자에게 질문**: "분석할 PRD 파일 경로를 알려주세요."

경로가 상대경로이면 PRD 기본 경로(`/Users/gimjinhyeog/Desktop/coding/plan-master/docs/specs/`)를 prefix로 붙인다.

### Step 1: PRD 파싱

파일을 Read 도구로 읽고 다음 항목을 추출한다.
섹션별 파싱 포인트는 `references/prd-structure.md`를 참조한다.

| 추출 항목 | 소스 섹션 | 용도 |
|----------|----------|------|
| `screen_code` | Frontmatter | 이슈 제목 prefix |
| `title` | Frontmatter | 기능명 |
| `summary` | Frontmatter | 이슈 개요/배경 |
| `related_screens` | Frontmatter | 기술적 고려사항 |
| 엔티티 목록 & CRUD 연산 | PART 3.1 핵심 기능 목록 | 분할 전략 결정 |
| 핵심 비즈니스 규칙 | PART 3.2 Acceptance Criteria | 상세 요구사항 |
| 엔티티 필드 & FK 관계 | PART 3.6 데이터 타입 정의 | Domain/Infra 이슈 |
| DB 스키마 | PART 4.3 정합성 체크리스트 | DB 마이그레이션 이슈 |
| ❌ 미정 항목 | PART 4.3 정합성 체크리스트 | 이슈 필요 항목 확인 |

### Step 2: 이슈 구조 설계

#### 엔티티 수에 따른 분할 전략

| 엔티티 수 | 전략 |
|----------|------|
| 1개 | Epic + 계층별 4개 Sub-Issue |
| 2~3개 (계층 관계) | Epic + 계층별 4~5개 Sub-Issue (엔티티 묶음) |
| 4개 이상 (독립적) | Epic + 엔티티 그룹별 Sub-Issue |

#### 표준 Sub-Issue 구성 (계층별)

```
[Epic] {screen_code} {title} 백엔드 구현
  ├── [Sub-1] DB 마이그레이션 — {엔티티명} 테이블 생성           (size:small)
  ├── [Sub-2] Domain 계층 — Aggregate, Repository Port          (size:small~medium)
  ├── [Sub-3] Application 계층 — CRUD UseCase/Service           (size:medium)
  ├── [Sub-4] Infrastructure 계층 — JPA Entity, Adapter, QueryDSL (size:medium)
  └── [Sub-5] API 계층 — Controller, Request/Response DTO       (size:small, api-change)
```

엔티티가 여럿이고 독립 구현 가능한 경우:

```
[Epic] {screen_code} {title} 백엔드 구현
  ├── [Sub-1] DB 마이그레이션 — 전체 테이블                     (size:small)
  ├── [Sub-2] {EntityA} 전 계층 구현                           (size:medium~large)
  ├── [Sub-3] {EntityB} 전 계층 구현                           (size:medium)
  └── [Sub-4] {EntityC} 전 계층 구현                           (size:medium)
```

### Step 3: 이슈 구조 제안 및 사용자 확인

파싱 결과와 제안 구조를 사용자에게 표시한다:

```
📋 PRD 분석 결과
- screen_code: {screen_code}
- 화면명: {title}
- 엔티티: {entity list} ({count}개)
- 핵심 기능: {PART 3.1에서 추출한 주요 기능}

📦 제안 이슈 구조 ({n}개)
1. [Epic] {screen_code} {title} 백엔드 구현
2. [Sub] DB 마이그레이션 — {테이블 목록}
3. [Sub] Domain 계층 — {엔티티명} Aggregate, Repository Port
...

이대로 진행할까요?
```

**중요**: 사용자 승인 후에만 이슈를 생성한다.

### Step 4: 이슈 생성

#### 4.1 Epic 이슈 생성

```bash
gh issue create \
  --title "[Epic] {screen_code} {title} 백엔드 구현" \
  --body "{epic_body}" \
  --label "epic,feature,size:large" \
  -R invigoworks/bitda-back
```

**Epic 본문:**
```markdown
## 개요
{frontmatter.summary}

## 배경
{PART 1.1 목적 — 첫 2~3문장}

## 화면 정보
- **화면 코드**: {screen_code}
- **관련 화면**: {related_screens}

## 구현 범위
{PART 3.1 핵심 기능 목록 테이블 인용}

## Sub-Issues
- [ ] #{TBD} DB 마이그레이션
- [ ] #{TBD} Domain 계층
- [ ] #{TBD} Application 계층
- [ ] #{TBD} Infrastructure 계층
- [ ] #{TBD} API 계층

## 완료 기준
- [ ] 전체 Sub-Issue 완료
- [ ] E2E 테스트 통과
- [ ] Swagger 문서 최신화
```

#### 4.2 Sub-Issue 생성

각 Sub-Issue를 순서대로 생성한다. 생성 후 Epic 본문의 Sub-Issues 목록을 실제 번호로 업데이트한다.

**Sub-Issue 본문 공통 구조:**
```markdown
## 개요
{이 계층에서 구현할 내용 요약}

## 배경
Part of #{epic-number} — {epic-title}

## 상세 요구사항
{계층별 구현 항목 — 아래 가이드 참조}

## 기술적 고려사항
- CLAUDE.md 헌법 준수 (internal 가시성, CQS 원칙)
- {PRD에서 추출한 특수 비즈니스 규칙}
- {관련 시행령 문서 참조}

## 완료 기준
- [ ] 기능 구현 완료
- [ ] 단위 테스트 작성 (도메인 비즈니스 규칙)
- [ ] ktlintCheck 통과
```

**계층별 상세 요구사항 소스:**

| Sub-Issue | 요구사항 소스 |
|-----------|-------------|
| DB 마이그레이션 | PART 4.3 DB 스키마 (없으면 PART 3.6 타입 정의에서 추론) |
| Domain 계층 | PART 3.6 데이터 타입 + AC의 비즈니스 규칙 (제약, 상호배타성 등) |
| Application 계층 | PART 3.1 기능 목록 + 핵심 AC 항목 |
| Infrastructure 계층 | PART 3.6 타입 정의 + PART 3.3 데이터 흐름 |
| API 계층 | PART 3.1 기능 목록 + PART 1.2 권한 + PART 2 컴포넌트 Props (API 스펙 단서) |

#### 4.3 라벨 규칙

| Sub-Issue | 라벨 |
|-----------|------|
| DB 마이그레이션 | `feature,size:small` |
| Domain 계층 | `feature,size:small` 또는 `feature,size:medium` |
| Application 계층 | `feature,size:medium` |
| Infrastructure 계층 | `feature,size:medium` |
| API 계층 | `feature,size:small,api-change` |
| Epic | `epic,feature,size:large` |

API 계층 이슈에는 항상 `api-change` 라벨을 부착한다.

### Step 5: 결과 보고

```
✅ 이슈 생성 완료 ({n}개)

| 유형  | 번호 | 제목                                    | 라벨                           |
|-------|------|------------------------------------------|-------------------------------|
| Epic  | #NNN | [Epic] {screen_code} {title} 백엔드 구현 | epic,feature                  |
| Sub   | #NNN | DB 마이그레이션 — {테이블}               | feature,size:small            |
| Sub   | #NNN | Domain 계층 — {엔티티}                   | feature,size:medium           |
| Sub   | #NNN | Application 계층 — CRUD UseCase/Service  | feature,size:medium           |
| Sub   | #NNN | Infrastructure 계층 — JPA, Adapter       | feature,size:medium           |
| Sub   | #NNN | API 계층 — Controller, DTO               | feature,size:small,api-change |

다음 단계: `/issue-plan #{first-sub-number}` 으로 첫 번째 Sub-Issue 계획서 작성
```
