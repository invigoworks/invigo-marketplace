---
name: plan-developer
description: This skill automates feature planning and specification development with Notion DB integration. Supports five modes - 신규 기능 개발, 재설계 개발, 기존 기획 업데이트, 기획 변경, and **페이지별 기획**. Creates detailed specs per page (하위 메뉴), ensuring clarity for FE/BE developers with AC (Given-When-Then + 기술상세), 화면 흐름, 권한 체계. Triggers on "기획해줘", "페이지별 기획해줘", "상세 기획서 작성해줘", "[Notion URL] 수정해줘". CRITICAL: Always access Notion pages via Notion MCP tools only - NEVER use WebFetch or Playwright.
---

# Plan Developer

## Overview

Transforms feature ideas into comprehensive planning documents. Supports **페이지별 기획** for granular, page-level specifications.

### Development Modes

| Mode | 용도 | 트리거 |
|------|------|--------|
| 1. 기존 기획 업데이트 | 기획확정 전 문서 수정 | Notion URL + 수정 요청 |
| 2. 재설계 개발 | 기존 솔루션 분석 후 재설계 | "마이그레이션", "재설계" |
| 3. 신규 기능 개발 | 기능 단위 기획서 (상위 메뉴) | "기능 기획해줘" |
| 4. 기획 변경 | 기획확정 후 변경 명세서 | "기획 변경해줘" |
| **5. 페이지별 기획** | 하위 메뉴별 상세 명세 | "페이지별 기획해줘", "상세 기획서" |

### Output

- Notion 기획문서 DB에 자동 저장
- shadcn UI 컴포넌트 명세 포함
- **FE/BE 개발자가 문서만으로 구현 가능한 수준**

---

## Prerequisites

- **Notion MCP**: Required for all operations
- **Reference Files**:
  - `references/notion-access-rules.md`: Notion 접근 규칙
  - `references/notion-upload-rules.md`: **Notion 업로드 규칙 (6개 규칙 + 체크리스트)**
  - `references/ui-consistency-rules.md`: **UI 일관성 규칙 (5대 컴포넌트, 재사용 인벤토리, 유사 페이지 참조)**
  - `references/page-spec-template.md`: 페이지별 기획서 템플릿 (PART 1-3 상세 예시 포함)
  - `references/permission-template.md`: 권한 명세 템플릿
  - `references/document-template.md`: 기능 단위 기획서 템플릿
  - `references/change-spec-template.md`: 기획 변경 명세서 템플릿

---

## CRITICAL: Notion 업로드 규칙

> **상세 규칙 및 코드 예시**: `references/notion-upload-rules.md` 참조

**핵심 요약:**
1. **업로드 전 검수 필수**: `plan-content-validator` 실행 → PASS/FIXED만 업로드
2. **`insert_content_after` 사용 금지**: 테이블 내부에 삽입되어 구조 파괴
3. **업데이트 전략**: `replace_content` (가장 안전) > `replace_content_range` (부분) > ~~`insert_content_after`~~
4. **테이블 확장 형식**: 각 `<td>`가 개별 줄 (컴팩트 형식 금지)
5. **코드블록 반드시 닫기**: 미닫힘 시 이후 헤딩이 코드블록 안에 갇힘
6. **기본 태그 규칙**: 1 `<tr>` = 1행, `<td>` 수 일치, 이스케이프 금지

---

## CRITICAL: Notion 접근 규칙

- ❌ `WebFetch`, `Playwright` 절대 사용 금지
- ✅ Notion MCP만 사용: `notion-search`, `notion-fetch`, `notion-update-page`, `notion-create-pages`, `notion-update-data-source`
- ⚠️ 정확한 파라미터는 `references/notion-access-rules.md` 참조

### 🚫 "로그 저장용" 상태 문서 - 절대 접근 금지

> "로그 저장용" 상태는 레거시 아카이브입니다. Claude는 **절대** 이 상태의 문서를 변경하거나, 다른 문서를 이 상태로 변경해서는 안 됩니다.

---

## Mode 5: 페이지별 기획 (Page-level Spec)

> **목적**: 하나의 페이지(하위 메뉴)에 대해 FE/BE가 이 문서만으로 구현 가능한 상세 명세 작성
> **상세 템플릿 및 예시**: `references/page-spec-template.md` 참조

### 문서 제목 형식
```
[화면코드]-[화면유형]-(화면명)
예: BITDA-CM-ADM-COM-S001-PAGE-(회사 관리)
```

### 문서 구조 (PART 기반)

```
# ━━━━━ PART 1: 화면 DB (→ 02.화면 DB) ━━━━━
1. 화면 유형 정의 (PAGE/OVERLAY/TAB)
2. 페이지 개요 (배경, 목적, 사용자)
3. 화면 흐름 (진입 경로, 내부 흐름, 연결 화면)
4. 권한 및 접근 제어 (RBAC, 모듈/기능 코드)
5. 레이아웃 (ASCII 다이어그램)
6. DB 연결 정보 (화면 코드, Prepub URL)
7. 유사 페이지 참조 (UI 일관성 Shift Left)

# ━━━━━ PART 2: 컴포넌트 & 로직 DB (→ 03.컴포넌트 & 로직 DB) ━━━━━
1. 인수 조건 (Given-When-Then)
2. 컴포넌트 명세 (shadcn 매핑) + UI 일관성 규칙
3. 테이블 컬럼 정의
4. 데이터 명세 (입력 필드, 유효성 검증)
5. 상태별 UI (Loading, Empty, Error 등)
6. 에러 처리 (HTTP 코드별 UI 처리 - 403은 권한없음 페이지)
7. 비즈니스 규칙 (목록/등록/수정/삭제)

# ━━━━━ PART 3: API 맵핑 DB (→ 04.API 맵핑 DB) ━━━━━
1. API 의존성 (사용 API, 데이터 로드 시퀀스)

# ━━━━━ 부록 ━━━━━
1. 변경 이력
```

### UI 일관성 필수 규칙 (CRITICAL - Shift Left)

> **상세**: `references/ui-consistency-rules.md` 참조 (5대 필수 컴포넌트, 재사용 인벤토리, 유사 페이지 참조)

### 워크플로우

1. **페이지 식별**: 하위 메뉴 페이지 확인, 화면 유형 결정
2. **PART 1 작성**: `references/page-spec-template.md` 참조
3. **PART 2 작성**: AC, 컴포넌트, 테이블 컬럼, 데이터, 상태별 UI, 에러, 비즈니스 규칙
4. **PART 3 작성**: API 의존성, 데이터 로드 시퀀스
5. **콘텐츠 검수 (MANDATORY)**:
   - 콘텐츠를 `/tmp/plan-content-validate-input.md`에 저장
   - `plan-content-validator`의 `scripts/validate-plan-tables.py`를 `/tmp/`에 복사 후 실행
   - PASS/FIXED → Step 6, FAIL → 수동 수정 후 재검수
6. **Notion 저장**: `replace_content` 권장, `insert_content_after` 금지
7. **업로드 후 검수 (선택)**: `/validate-plan-content [Page ID]`

> **CRITICAL**: Step 5는 필수. 검수 생략 시 8건 오류 수정에 12회 API 호출이 필요했던 사례 있음.

---

## Mode 1-4 (기존 모드)

### Mode 1: 기존 기획 업데이트 (기획확정 전)

1. URL에서 Page ID 추출
2. Notion MCP로 조회 (`notion-fetch`)
3. 수정 사항 분석
4. **콘텐츠 수정본 작성** (로컬에서 전체 콘텐츠 준비)
5. **검수 실행 (MANDATORY)**: `plan-content-validator` 실행
6. **Notion 업로드**: `replace_content` 권장, `insert_content_after` 금지

> **⚠️ 다수 페이지 업데이트 시**: 3건 이상은 `references/notion-access-rules.md` "컨텍스트 관리" 참조. subagent 위임 필수.

### Mode 2: 재설계 개발 (Migration)

1. `/migration_image/[feature]/` 이미지 분석
2. 분석 결과 요약 (화면, 로직, 데이터)
3. 추가 요구사항 확인
4. Mode 3 또는 Mode 5로 진행

### Mode 3: 신규 기능 개발

**Phase 1**: 기획초벌 - 핵심 목적, 주요 기능
**Phase 2**: 디벨롭 - 비즈니스 로직, 데이터 로드, 권한
**Phase 3**: 문서 생성 - `references/document-template.md` 참조
**Phase 4**: 콘텐츠 검수 (MANDATORY) - `plan-content-validator` 실행
**Phase 5**: Notion 업로드 - `replace_content` 사용 (검수 통과 콘텐츠만)

### Mode 4: 기획 변경 (기획확정 후)

1. 변경 유형 분류 (수정/보완/보충/제거)
2. 영향 범위 분석 (UI/API/데이터/로직)
3. 변경 명세서 작성 - `references/change-spec-template.md`
4. Notion 업데이트 (진행 단계: 기획 변경, 버전 +0.1)

> **⚠️ 다수 페이지 변경 시**: 3건 이상은 `references/notion-access-rules.md` "컨텍스트 관리" 참조.

---

## Conversation Strategy

### 모드 선택 질문
```
어떤 방식으로 기획을 진행할까요?

1. 기능 단위 기획 - 상위 메뉴 전체 (여러 페이지 포함)
2. 페이지별 기획 - 하위 메뉴 하나씩 상세하게 ⭐ 권장
3. 기존 문서 수정 - Notion URL 제공 필요
```

### 페이지별 기획 질문 흐름 (PART 기반)

**Step 1: PART 1 - 화면 DB 정보 수집**
- 사이드바 메뉴 위치, 라우트 경로, 화면 유형
- 배경, 목적, 사용자
- 화면 흐름 (진입→내부→연결)
- 권한 (ADMIN 전용 vs 다중 역할)

**Step 2: PART 2 - 컴포넌트 & 로직 정보 수집**
- 인수 조건 (Given-When-Then)
- 테이블 컬럼, 입력 필드, 유효성 검증
- 비즈니스 규칙 (정렬, 페이징, 삭제 방식)

**Step 3: PART 3 - API 맵핑 정보 수집**
- 사용 API 목록 (용도, 호출 시점)
- 데이터 로드 시퀀스

---

## Design Handoff

기획 완료 시:

1. 화면 코드 생성 (`references/convention-template.md`)
2. shadcn 컴포넌트 명세
3. Notion DB: `디자인 핸드오프: __YES__`
4. **기능코드 자동 등록**: 새 기능코드가 convention-template.md에 없으면 자동 등록
   - convention-template.md에 행 추가 → 버전 패치 증가 → `sync-feature-codes.sh --register` 실행

**관련 DB 상수:** `references/planning-db-schema.md` 참조

---

## Next Skills

- **plan-content-validator**: 콘텐츠 검수 (**필수** - Notion 업로드 전 반드시 실행)
- **ui-designer**: UI 코드 생성
- **github-deployer**: GitHub 배포

Trigger: "디자인 단계로 넘어가줘", "코드 생성해줘"

---

## Notion Integration

**기획문서 DB**: `references/planning-db-schema.md` 참조 (DB ID, Data Source URL 등 하드코딩 상수)

> 별도 페이지 생성 안 함. DB 항목 content에 직접 작성.
> **⚠️ Context Overflow 주의**: 기획문서 1건은 10k-20k 토큰.
> 3건 이상 fetch 시 반드시 subagent 격리. 상세: `references/notion-access-rules.md`

### 매니페스트 활용 (토큰 최적화)

> DB 전체 조회 전에 `.claude/shared-references/notion-manifest.md`를 먼저 확인.

| 작업 | 매니페스트 활용 |
|------|---------------|
| Mode 1/4 (업데이트/변경) | 매니페스트에서 Page ID 조회 → subagent로 fetch → 수정 후 매니페스트 업데이트 |
| Mode 3/5 (신규 생성) | notion-create-pages 완료 → 매니페스트에 "기획 초벌" 그룹에 추가 |
| 상태 조회 | 매니페스트 읽기만으로 완료 (0 Notion 토큰) |

### 주요 DB 속성

| 속성명 | 타입 | 용도 |
|--------|------|------|
| 기획 명칭 | Title | 화면 코드 + 화면명 |
| 퍼블리싱 결과 확인 | URL | **Prepub URL 저장** |
| 디자인 핸드오프 | Checkbox | 디자인 준비 완료 여부 |
| 버전 | Number | 문서 버전 |

> **중요**: Prepub URL은 문서 본문이 아닌 `퍼블리싱 결과 확인` 속성에 저장

---

## Error Handling

- **Incomplete Requirements**: 누락 항목 질문
- **Conflicting Requirements**: 충돌 강조 후 해결 요청
- **Notion Connection Failed**: 로컬 저장 후 대안 제시
