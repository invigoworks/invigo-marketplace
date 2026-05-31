---
name: backend-planner
description: This skill should be used when the user describes a feature or product requirement in rough, informal language (Korean or English) and wants it translated into a structured backend implementation prompt. It converts vague planning content into precise domain model, API list, business rules, and Claude implementation commands following the bitda-back hexagonal architecture patterns (Kotlin/Spring Boot, DDD, CQS).
---

# Backend Planner

Convert rough product planning input into a structured backend design and ready-to-use Claude implementation prompt, following bitda-back's hexagonal architecture.

## When to Use

Trigger when the user says things like:
- "~기능 만들어줘", "~관리 화면이 필요해"
- "기획은 이래: ..."
- "이런 기능을 추가하고 싶은데 어떻게 해?"
- Any informal Korean/English description of a product requirement without structured API/DB design

## Workflow

### Step 1: Load the Reference

Load `references/design-framework.md` before processing any input. It contains the translation rules, output format templates, and Claude prompt template.

### Step 2: Clarify if Needed

If the input is too vague to produce a design, ask at most two focused questions before proceeding. Examples:

- "어떤 데이터를 저장해야 하나요?" (필수 필드가 불분명할 때)
- "어떤 조건으로 수정/삭제가 제한되나요?" (상태 전이가 불분명할 때)
- "다른 도메인(재고, 회계 등)에 영향을 주나요?" (이벤트 범위가 불분명할 때)

If it is possible to make reasonable assumptions, state them and proceed rather than asking.

### Step 3: Produce the Design Output

Generate the full structured design using the 7-section format from `references/design-framework.md`:

1. 도메인 언어 정의
2. 데이터 모델 (Aggregate 구조 + DB 테이블)
3. API 목록
4. 핵심 API 요청/응답 (POST + 목록 GET만)
5. 비즈니스 규칙 (검증/상태/중복/이벤트 트리거)
6. 이벤트 정의
7. UseCase 목록 (Command/Query 분리)

### Step 4: Generate the Implementation Prompt

After the design, produce a **ready-to-copy Claude implementation prompt** in a fenced code block.

The prompt must:
- Say "기존 ProductionInbound 도메인 패턴을 참고해서 동일한 구조로 만들어줘"
- Include the Aggregate structure with all fields
- Include UseCase list with Command/Query/Returns
- Include key business rules inline
- End with the implementation order: Domain → UseCase → Infrastructure → API

## Output Structure

```
## 설계 결과

### 1. 도메인 언어
[table]

### 2. 데이터 모델
[Aggregate 구조 + DB 컬럼 목록 + 제약]

### 3. API 목록
[table: 기능 | 메서드 | URL | 타입]

### 4. 핵심 API 요청/응답
[POST 요청/응답, 목록 GET 응답]

### 5. 비즈니스 규칙
[번호 목록, [검증]/[상태]/[중복] 태그]

### 6. 이벤트
[이벤트명 + 필드, 없으면 "이벤트 없음"]

### 7. UseCase 목록
[Command / Query 분리 표]

---

## Claude 구현 프롬프트

(복사해서 그대로 사용 가능한 프롬프트)
```

## Quality Checklist

Apply these rules to every output — they reflect bitda-back's mandatory conventions:

- `organizationId` is always in every Aggregate (multi-tenant)
- DB tables always include `created_at`, `updated_at`, `version` columns
- Soft delete → `deleted_at TIMESTAMPTZ NULL`; hard delete → omit
- List APIs always include `page` / `size` query params
- Dates: `Instant` in domain, `TIMESTAMPTZ` in DB, ISO-8601 `Z` in API responses
- Service implementations are `internal class`
- Command UseCase returns `UUID` (create) or `Unit` (update/delete)
- UNIQUE constraints always scoped by `organization_id`
