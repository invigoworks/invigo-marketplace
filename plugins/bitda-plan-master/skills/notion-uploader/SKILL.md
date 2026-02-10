---
name: notion-uploader
description: This skill registers BITDA ERP UI screens and components to Notion databases. Use this skill AFTER github-deployer when the deployed code has been reviewed and confirmed. Triggers on requests like "노션에 등록해줘", "Notion DB 업데이트해줘", "화면 DB에 올려줘", "컴포넌트 등록해줘". This skill requires the github-deployer to be completed first.
---

# Notion Uploader

## Overview

This skill handles the Notion registration phase for BITDA ERP UI:

1. **화면 DB 등록**: Register screens with code, type, and source links
2. **컴포넌트 & 로직 DB 등록**: Register components with detailed business logic for backend API development
3. **Relation 연결**: Link components to their parent screens
4. **자동 검수**: `/notion-validator` 스킬로 등록 데이터 품질 검증 (MANDATORY)

## Prerequisites

- **Notion MCP**: Connected and authenticated
- **GitHub Deployment**: Code already pushed via github-deployer skill
- **Design Review**: UI confirmed and ready for registration

---

## STEP 0: Notion MCP 연결 확인 (필수 선행 단계)

> **CRITICAL**: 이 스킬의 모든 작업을 시작하기 전에 반드시 Notion MCP 연결 상태를 확인해야 합니다.

### 연결 확인 절차

1. **연결 테스트 실행**:
   ```
   notion-get-self 도구를 호출하여 현재 연결 상태 확인
   ```

2. **성공 시**: 스킬 워크플로우 진행
   - Bot user 정보가 반환되면 연결 정상
   - Phase 1부터 정상 진행

3. **실패 시**: 재연결 안내
   ```markdown
   ⚠️ Notion MCP 연결 실패

   Notion MCP가 연결되지 않았습니다. 다음 단계를 수행해주세요:

   1. Claude Code 설정에서 Notion MCP 연결 상태 확인
   2. Notion 인증 토큰이 유효한지 확인
   3. MCP 서버 재시작 필요 시:
      - Claude Code 재시작
      - 또는 MCP 서버 수동 재연결

   연결 완료 후 다시 시도해주세요.
   ```

### 연결 확인 코드

```typescript
// 스킬 시작 시 자동 실행
const checkNotionConnection = async () => {
  try {
    const result = await mcp__plugin_Notion_notion__notion_get_self();
    if (result) {
      console.log('✅ Notion MCP 연결 확인됨:', result.name);
      return true;
    }
  } catch (error) {
    console.error('❌ Notion MCP 연결 실패');
    return false;
  }
  return false;
};

// 연결 실패 시 스킬 진행 중단
if (!await checkNotionConnection()) {
  throw new Error('Notion MCP 연결이 필요합니다. 연결 후 다시 시도해주세요.');
}
```

### 연결 상태별 동작

| 상태 | 동작 |
|------|------|
| ✅ 연결됨 | Phase 1부터 정상 진행 |
| ❌ 연결 안됨 | 에러 메시지 표시 + 재연결 안내 |
| ⚠️ 토큰 만료 | 재인증 안내 |

---

## Reference Files

- `../../shared-references/convention-template.md`: BITDA ERP screen code conventions (shared)
- `references/notion-db-config.md`: Notion database IDs and schemas

> **Note**: convention-template.md is a shared reference file. All skills use the same file to maintain consistency.

---

## Specialized Agent Integration

This skill leverages invigo-agents for documentation quality and context management:

### Recommended Agents by Task

| Task | Agent | Purpose |
|------|-------|---------|
| API Documentation | `invigo-agents:api-documenter` | OpenAPI specs, endpoint documentation, SDK generation |
| Context Management | `invigo-agents:context-manager` | Multi-agent workflows, session coordination |
| Backend Architecture | `invigo-agents:backend-architect` | API design review, business logic validation |
| Code Explorer | `feature-dev:code-explorer` | Analyze codebase features, trace execution paths |

### Agent Invocation Strategy

**During Context Gathering (Phase 1):**

1. **Code Analysis** - Deep codebase analysis:
   ```
   Task(subagent_type="feature-dev:code-explorer")
   Prompt: "Analyze the deployed code at [GitHub URL].
   Extract component structure, data models, and business logic."
   ```

2. **Context Coordination** - For complex multi-source documentation:
   ```
   Task(subagent_type="invigo-agents:context-manager")
   Prompt: "Coordinate context from planning document and published code.
   Identify discrepancies and consolidate final specifications."
   ```

**During Business Logic Documentation (Phase 3):**

3. **API Documentation** - Generate backend specs:
   ```
   Task(subagent_type="invigo-agents:api-documenter")
   Prompt: "Generate OpenAPI specification for [기능명] based on UI components.
   Include request/response schemas, validation rules, and error codes."
   ```

4. **Architecture Validation** - Verify business logic completeness:
   ```
   Task(subagent_type="invigo-agents:backend-architect")
   Prompt: "Review business logic documentation for [기능명].
   Verify completeness for backend API development."
   ```

### Parallel Documentation Generation

For multi-component features, document in parallel:

```typescript
// Parallel business logic documentation
const parallelDocs = [
  Task({
    subagent_type: "invigo-agents:api-documenter",
    prompt: "Document CRUD endpoints for UserTable component"
  }),
  Task({
    subagent_type: "invigo-agents:api-documenter",
    prompt: "Document form validation API for UserSheet component"
  }),
  Task({
    subagent_type: "invigo-agents:api-documenter",
    prompt: "Document delete operation API for DeleteDialog component"
  })
];
```

### Documentation Quality Gate

Before Notion registration, validate with agents:

```typescript
// Sequential quality check
const docReview = Task({
  subagent_type: "invigo-agents:backend-architect",
  prompt: `Verify business logic documentation is complete for backend development:
  - All CRUD operations documented
  - Validation rules specified
  - Error handling defined
  - API endpoints proposed`
});
```

### Context Preservation

For long-running documentation sessions:

```typescript
// Context management for multi-session work
const contextSave = Task({
  subagent_type: "invigo-agents:context-manager",
  prompt: `Preserve documentation context for [기능명]:
  - Current progress state
  - Pending documentation items
  - Cross-references to related features`
});
```

---

## Workflow

### Phase 1: Gather Context from Planning Documents

Before registration, **MUST** gather context from planning documents:

1. **기획문서 확인**:
   - **먼저** `.claude/shared-references/notion-manifest.md`에서 해당 기획문서의 Page ID와 메타데이터 확인 (0 토큰)
   - 매니페스트에 있으면 해당 Page ID로 직접 `notion-fetch` (전체 DB 검색 불필요)
   - 매니페스트에 없으면: https://www.notion.so/invigoworks/01-2df471f8dcff80c0893becf766c394b0 에서 검색
   - Note: 기획문서는 초안 상태이므로 퍼블리싱 코드에 반영된 피드백 사항들을 추가로 파악해야 함

2. **퍼블리싱 코드 분석**:
   - Read the deployed code from GitHub (source 링크)
   - Identify UI components, form fields, validation rules
   - Extract actual business logic implemented in the code
   - This represents the FINAL confirmed specifications after feedback

### Phase 2: Gather Registration Data

1. **Screen Information**:
   - 화면코드 (e.g., BITDA-CM-ADM-USR-S001)
   - 화면명 (e.g., 사용자 목록)
   - 화면유형 (S/F/P/R/D/M)
   - 기능코드 (e.g., ADM-USR)
   - GitHub source 링크
   - 연관된 기획문서 (출처가 된 기획문서 URL)

2. **Component Information**:
   - 요소명 (e.g., UserTable, UserSheet)
   - 비즈니스 로직 (상세 작성 - Phase 3 참조)
   - 연결할 화면

### Phase 3: 비즈니스 로직 작성 가이드

**중요**: 비즈니스 로직은 백엔드 개발자가 API를 개발할 때 기획문서 없이도 작업할 수 있을 정도로 상세해야 함.

#### 비즈니스 로직 필수 포함 사항:

1. **데이터 필드 정의**:
   - 필드명, 타입, 필수 여부
   - 유효성 검사 규칙 (최소/최대 길이, 형식 등)
   - 기본값, 선택 옵션 목록

2. **CRUD 동작**:
   - 생성(Create): 필수 필드, 자동 생성 필드
   - 조회(Read): 목록 필터, 정렬, 페이지네이션
   - 수정(Update): 수정 가능 필드, 수정 불가 필드
   - 삭제(Delete): 삭제 조건, 연관 데이터 처리

3. **비즈니스 규칙**:
   - 상태 변경 로직 (예: 상태가 '완료'면 수정 불가)
   - 권한 체크 (예: 본인 데이터만 수정 가능)
   - 연관 관계 (예: 회사 삭제 시 소속 사용자 처리)

4. **API 엔드포인트 제안**:
   - HTTP Method + Path
   - Request/Response 예시

#### 비즈니스 로직 작성 예시:

```
## UserTable (사용자 목록)

### 데이터 필드
| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| id | string(UUID) | Y | 사용자 고유 ID (자동생성) |
| email | string | Y | 이메일 (중복 불가, 형식 검증) |
| name | string | Y | 이름 (2-50자) |
| role | enum | Y | 권한 (admin/manager/user) |
| companyId | string | Y | 소속 회사 ID (FK) |
| status | enum | Y | 상태 (active/inactive/pending) |
| createdAt | datetime | Y | 생성일시 (자동) |
| updatedAt | datetime | Y | 수정일시 (자동) |

### 목록 조회
- GET /api/v1/users
- 필터: companyId, role, status, keyword(이름/이메일 검색)
- 정렬: createdAt desc (기본), name asc
- 페이지네이션: page, limit (기본 20)
- 권한: admin은 전체, manager는 본인 회사만

### 비즈니스 규칙
- 이메일 중복 체크 필수
- 상태 변경 시 이력 기록
- 삭제 시 soft delete (status = 'deleted')
```

### Phase 4: 화면 DB 등록

#### 4.1 Find Related Codes

Search for existing codes in Notion:

**화면유형 코드** (DB ID: `2d3471f8-dcff-8051-ac76-000b25732bf2`):
| 코드 | 원어 | 한글 |
|------|------|------|
| D | Dashboard | 대시보드 |
| S | Screen | 일반화면 |
| F | Form | 등록/수정 |
| P | Popup | 팝업/모달 |
| R | Report | 리포트 |
| M | Matrix | 매트릭스 |

**마스터 기능코드** (DB ID: `2d3471f8-dcff-803d-8b2c-000b5b9855af`):
- Search for the feature code (e.g., "USR", "COM", "DASH")
- Get the page URL for relation

#### 4.2 Create Screen Entries

Use `notion-create-pages` with:

```json
{
  "parent": {
    "type": "data_source_id",
    "data_source_id": "2d3471f8-dcff-8067-b573-000b0e2b1d04"
  },
  "pages": [
    {
      "properties": {
        "화면명": "[화면명]",
        "source 링크": "https://github.com/invigoworks/pre-publishing/blob/main/src/app/[path]",
        "상태": "기획 완료",
        "화면유형 코드": "[\"[화면유형URL]\"]",
        "기능코드": "[\"[기능코드URL]\"]",
        "연관된 기획문서": "[\"[기획문서URL]\"]"
      }
    }
  ]
}
```

> **참고**: `연관된 기획문서`는 해당 화면의 기획 출처가 되는 기획문서(01.기획문서 DB)의 페이지 URL입니다. Phase 1에서 확인한 기획문서의 URL을 사용합니다.

### Phase 5: 컴포넌트 & 로직 DB 등록

#### 5.1 Create Component Entries

Use `notion-create-pages` with:

```json
{
  "parent": {
    "type": "data_source_id",
    "data_source_id": "2d3471f8-dcff-8076-a4a3-000b502a3811"
  },
  "pages": [
    {
      "properties": {
        "요소명(ID)": "[컴포넌트명]",
        "비즈니스 로직": "[상세 비즈니스 로직 - Phase 3 형식 참조]",
        "화면 DB 연동": "[\"[화면URL]\"]"
      }
    }
  ]
}
```

### Phase 6: 등록 검수 (MANDATORY)

> **CRITICAL**: Phase 5 완료 후 반드시 `/notion-validator` 스킬을 실행하여 등록된 데이터를 검수해야 합니다.

#### 6.1 자동 검수 실행

등록 완료 후 자동으로 `/notion-validator` 스킬을 호출:

```typescript
// 등록 완료 후 자동 검수
Skill({
  skill: "notion-validator",
  args: "[등록된 화면 목록]"
});
```

#### 6.2 검수 항목

`/notion-validator`가 확인하는 항목:
- source 링크 유효성 (GitHub URL 접근 가능 여부)
- 화면코드 매핑 정확성
- 컴포넌트 Relation 연결 상태
- 연관된 기획문서 Relation 연결 상태
- 필수 필드 누락 여부

#### 6.3 검수 결과 처리

| 검수 결과 | 처리 방법 |
|----------|----------|
| ✅ 검수 통과 | 등록 완료 확정 |
| ⚠️ 경고 발견 | 사용자에게 수정 권고 |
| ❌ 오류 발견 | 즉시 수정 후 재검수 |

---

## Notion Database References

### 화면 DB
- **Data Source ID**: `2d3471f8-dcff-8067-b573-000b0e2b1d04`
- **Database URL**: https://www.notion.so/2d3471f8dcff802f945fc5add962fc6f

**Schema**:
| 속성 | 타입 | 설명 |
|-----|------|------|
| 화면명 | title | 화면 이름 |
| source 링크 | url | GitHub 소스 링크 |
| 기능코드 | relation | 마스터 기능코드 연결 |
| 화면유형 코드 | relation | 화면유형 코드 연결 |
| 연관된 기획문서 | relation | 기획문서 DB 연결 (화면 기획의 출처가 된 기획문서) |
| 상태 | status | 시작 전/기획 중/개발 중/기획 완료/개발 완료 |

### 컴포넌트 & 로직 DB
- **Data Source ID**: `2d3471f8-dcff-8076-a4a3-000b502a3811`
- **Database URL**: https://www.notion.so/2d3471f8dcff80d28041f0e98910c922

**Schema**:
| 속성 | 타입 | 설명 |
|-----|------|------|
| 요소명(ID) | title | 컴포넌트 이름 |
| 비즈니스 로직 | text | 백엔드 API 개발용 상세 비즈니스 로직 |
| 화면 DB 연동 | relation | 화면 DB 연결 |

### 마스터 기능코드
- **Data Source ID**: `2d3471f8-dcff-803d-8b2c-000b5b9855af`

### 화면유형 코드
- **Data Source ID**: `2d3471f8-dcff-8051-ac76-000b25732bf2`

### 기획문서 DB
- **DB ID**: `2df471f8-dcff-80b2-9a6d-f9972b15aa06`
- **URL**: https://www.notion.so/invigoworks/01-2df471f8dcff80c0893becf766c394b0
- **Purpose**: 기획 초안 확인 (피드백 전 버전)
- **Relation**: 화면 DB의 "연관된 기획문서" 컬럼에서 연결됨 (화면 기획의 출처 추적용)

---

## Registration Checklist

Before registering, verify:

- [ ] GitHub 배포 완료 (github-deployer)
- [ ] 디자인/기능 검토 완료
- [ ] 화면코드 컨벤션 준수 확인
- [ ] 기능코드 존재 여부 확인
- [ ] 화면유형 코드 확인
- [ ] 기획문서 내용 확인 완료 (연관된 기획문서 URL 확보)
- [ ] 퍼블리싱 코드 분석 완료
- [ ] 비즈니스 로직 상세 작성 완료 (백엔드 API 개발 가능 수준)

After registering, **MANDATORY**:

- [ ] `/notion-validator` 스킬로 검수 완료

---

## Post-Registration Output

After successful registration, provide:

```markdown
## Notion 등록 완료

### 화면 DB
| 화면명 | 화면코드 | 상태 | 연관된 기획문서 |
|--------|---------|------|----------------|
| [화면명1] | BITDA-XX-XX-XX-S001 | 기획 완료 | [FEAT] 기능명 |
| [화면명2] | BITDA-XX-XX-XX-F001 | 기획 완료 | [FEAT] 기능명 |

등록된 화면: [N]개 ✓
연관된 기획문서: [기획문서 링크]

### 컴포넌트 & 로직 DB
| 요소명 | 연결 화면 | 비즈니스 로직 요약 |
|--------|----------|-------------------|
| [컴포넌트1] | [화면명1] | [CRUD 요약] |
| [컴포넌트2] | [화면명2] | [CRUD 요약] |

등록된 컴포넌트: [N]개 ✓

### 확인 링크
- 화면 DB: https://www.notion.so/2d3471f8dcff802f945fc5add962fc6f
- 컴포넌트 DB: https://www.notion.so/2d3471f8dcff80d28041f0e98910c922

### 백엔드 개발 참고
비즈니스 로직에 다음 내용이 포함되어 있습니다:
- 데이터 필드 정의 및 유효성 검사 규칙
- CRUD 동작 상세 명세
- 비즈니스 규칙 및 권한 체크
- API 엔드포인트 제안

---

## 🔍 검수 진행 중...

`/notion-validator` 스킬을 실행하여 등록된 데이터를 검수합니다.
```

---

## Usage Examples

**Example 1: Full Registration with Business Logic**
```
User: 방금 배포한 사용자 관리 화면 노션에 등록해줘

Process:
1. 기획문서 확인 (https://www.notion.so/invigoworks/01-2df471f8dcff80c0893becf766c394b0)
2. GitHub 코드 분석 (퍼블리싱 코드에서 실제 구현 확인)
3. 기획 초안 + 피드백 반영된 최종 스펙 기반으로 비즈니스 로직 작성
4. 화면 DB 등록
5. 컴포넌트 DB 등록 (상세 비즈니스 로직 포함)

Response:
## Notion 등록 완료

### 화면 DB
| 화면명 | 화면코드 | 상태 |
|--------|---------|------|
| 사용자 목록 | BITDA-CM-ADM-USR-S001 | 기획 완료 |
| 사용자 등록/수정 | BITDA-CM-ADM-USR-F001 | 기획 완료 |
| 사용자 삭제 확인 | BITDA-CM-ADM-USR-P001 | 기획 완료 |

등록된 화면: 3개 ✓

### 컴포넌트 & 로직 DB
| 요소명 | 비즈니스 로직 요약 |
|--------|-------------------|
| UserTable | 목록 조회, 필터링, 정렬, 페이지네이션 |
| UserSheet | 사용자 CRUD, 유효성 검사, 권한 체크 |
| DeleteDialog | Soft delete, 연관 데이터 확인 |

등록된 컴포넌트: 3개 ✓

비즈니스 로직에 백엔드 API 개발에 필요한 상세 명세가 포함되었습니다.

---

## 🔍 검수 진행 중...

[/notion-validator 스킬 자동 실행]

### 검수 결과
✅ source 링크 유효성: 통과
✅ 화면코드 매핑: 정상
✅ 컴포넌트 Relation: 정상 연결
✅ 연관된 기획문서: 정상 연결

**검수 완료** - 모든 항목 통과 ✓
```

---

## Error Handling

- **Notion Connection Failed**: Check Notion MCP authentication
- **Duplicate Entry**: Check if screen already exists in DB
- **Invalid Code**: Verify code follows BITDA convention
- **Missing Relation**: Search for required code in master DBs first
- **Incomplete Business Logic**: Ensure all CRUD operations and validation rules are documented
