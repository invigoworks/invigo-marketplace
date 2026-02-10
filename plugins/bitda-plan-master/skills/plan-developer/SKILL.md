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
  - `references/page-spec-template.md`: **페이지별 기획서 템플릿**
  - `references/permission-template.md`: **권한 명세 템플릿**
  - `references/document-template.md`: 기능 단위 기획서 템플릿
  - `references/change-spec-template.md`: 기획 변경 명세서 템플릿

---

## CRITICAL: Notion 접근 규칙

- ❌ `WebFetch`, `Playwright` 절대 사용 금지
- ✅ Notion MCP만 사용: `notion-search`, `notion-fetch`, `notion-update-page`, `notion-create-pages`, `notion-update-data-source`
- ⚠️ 정확한 파라미터는 `references/notion-access-rules.md` 참조 (특히 `notion-fetch`는 `id` 파라미터만 존재)

---

## Mode 5: 페이지별 기획 (Page-level Spec)

> **목적**: 하나의 페이지(하위 메뉴)에 대해 FE/BE가 이 문서만으로 구현 가능한 상세 명세 작성

### 문서 제목 형식
```
[화면코드]-[화면유형]-(화면명)
예: BITDA-CM-ADM-COM-S001-PAGE-(회사 관리)
```

### 문서 구조 (PART 기반)

**템플릿**: `references/page-spec-template.md`

```
# ━━━━━ PART 1: 화면 DB (→ 02.화면 DB) ━━━━━
1. 화면 유형 정의
2. 페이지 개요 (배경, 목적, 사용자)
3. 화면 흐름 (진입 경로, 내부 흐름, 연결 화면)
4. 권한 및 접근 제어 (RBAC, 모듈/기능 코드)
5. 레이아웃 (ASCII 다이어그램)
6. DB 연결 정보 (화면 코드, Prepub URL)

# ━━━━━ PART 2: 컴포넌트 & 로직 DB (→ 03.컴포넌트 & 로직 DB) ━━━━━
1. 인수 조건 (Given-When-Then)
2. 컴포넌트 명세 (shadcn 매핑)
3. 테이블 컬럼 정의
4. 데이터 명세 (입력 필드, 유효성 검증)
5. 상태별 UI (Loading, Empty, Error 등)
6. 에러 처리 (HTTP 코드별 UI 처리)
7. 비즈니스 규칙 (목록/등록/수정/삭제)

# ━━━━━ PART 3: API 맵핑 DB (→ 04.API 맵핑 DB) ━━━━━
1. API 의존성 (사용 API, 데이터 로드 시퀀스)

# ━━━━━ 부록 ━━━━━
1. 변경 이력
```

---

### PART 1: 화면 DB (→ 02.화면 DB)

#### 1.1 화면 유형 정의

| 유형 | 설명 | 예시 |
|------|------|------|
| **PAGE** | 독립적인 라우트 페이지 | 목록 페이지, 대시보드 |
| **OVERLAY** | Sheet, Dialog, Drawer | 등록 폼, 상세 보기 |
| **TAB** | 탭 내 콘텐츠 영역 | 상세 페이지의 탭 |

> OVERLAY, TAB은 부모 PAGE를 명시해야 함

#### 1.2 페이지 개요

```markdown
### 배경 (Background)
시스템 관리자가 거래처 회사를 통합 관리해야 함

### 목적 (Purpose)
회사 등록/조회/수정/삭제 및 요금제 관리

### 사용자 (Target Users)
> **주의**: 역할 코드가 동일하면 하나의 행으로 통합

| 역할 코드 | 주요 시나리오 |
|----------|--------------|
| ADMIN | 전체 데이터 관리 |
```

#### 1.3 화면 흐름 (User Flow)

```markdown
### 진입 경로
사이드바 > 공통 관리 > 회사 관리
Route: /admin/company

### 화면 내 흐름
회사 목록 (PAGE)
    │
    ├─▶ [등록] 버튼 → 회사 등록 Sheet (OVERLAY)
    │       └─▶ [저장] → 목록 갱신
    │
    └─▶ [행 클릭] → 회사 상세 Sheet (OVERLAY)
            ├─▶ [수정] → 목록 갱신
            └─▶ [삭제] → 확인 Dialog → 목록 갱신

### 연결 화면
| 연결 방향 | 화면 코드 | 화면명 | 화면유형 | 연결 방식 |
|----------|----------|--------|---------|----------|
| FROM | - | - | - | 사이드바 메뉴 |
| TO | COM-O001 | 회사 등록/수정 | OVERLAY | 버튼/행 클릭 |
```

#### 1.4 권한 및 접근 제어

**ADMIN 전용 페이지:**
```markdown
역할(Role): ADMIN
권한 코드: 불필요 (역할 기반 접근)
```

**일반 페이지 (다중 역할):**
```markdown
| 역할 | 조회 | 등록 | 수정 | 삭제 |
|------|------|------|------|------|
| ADMIN | ✓ | ✓ | ✓ | ✓ |
| MANAGER | ✓ | ✓ | ✓ | ✗ |

권한 코드:
| 기능 | 권한 코드 | 설명 |
|------|----------|------|
| 목록 조회 | company:read | 회사 목록 조회 |
| 등록 | company:create | 회사 등록 |
| 수정 | company:update | 회사 수정 |
| 삭제 | company:delete | 회사 삭제 |

모듈/기능 코드:
| 구분 | 코드 | 설명 |
|------|------|------|
| 모듈 | CM | 공통 관리 |
| 기능 | CM-CMP | 회사 관리 |
```

#### 1.5 레이아웃

```
┌─────────────────────────────────────────────┐
│ PageHeader: 회사 관리                        │
├─────────────────────────────────────────────┤
│ Toolbar: [검색] [필터] [등록 버튼]           │
├─────────────────────────────────────────────┤
│              DataTable                      │
├─────────────────────────────────────────────┤
│ Pagination                                  │
└─────────────────────────────────────────────┘
```

#### 1.6 DB 연결 정보

| 항목 | 값 | Notion DB 속성 |
|------|------|---------------|
| 화면 코드 | `BITDA-CM-ADM-COM-S001` | 기획 명칭 |
| Prepub URL | `https://prepub.invigoworks.co.kr/admin/companies` | **퍼블리싱 결과 확인** |
| 기획문서 | 현재 문서 URL | url |

> **중요**: Prepub URL은 문서 본문에 기재하지 않고, Notion DB의 `퍼블리싱 결과 확인` 속성(URL 타입)에 저장

#### 1.7 유사 페이지 참조 (CRITICAL - Shift Left)

> **목적**: UI 생성 후 반복적인 스타일 수정을 방지하기 위해, 기획 단계에서 참조할 기존 페이지를 명시

```markdown
### 참조 페이지
| 참조 페이지 | 경로 | 참조 포인트 |
|------------|------|------------|
| [유사 기능 페이지명] | apps/[앱]/src/[경로] | 테이블 구조, 뱃지 패턴, 필터 구성 |
| [동일 도메인 페이지명] | apps/[앱]/src/[경로] | 레이아웃, 컬럼 스타일(border-r 등) |

### UI 스타일 일관성 지시
- 테이블 세로 구분선: [참조 페이지]의 border-r 패턴 따름
- 뱃지 컴포넌트: [LiquorTypeBadge/StatusBadge 등] 사용
- 액션 버튼 배치: [참조 페이지]와 동일한 CardHeader 구성
```

**필수 확인 항목**:
- 동일 도메인(같은 앱, 같은 기능 그룹)에 이미 구현된 페이지가 있는지 검색
- 있다면 해당 페이지의 테이블 스타일, 뱃지 사용, 필터 구성을 참조 페이지로 명시
- 이 페이지와의 **시각적 일관성**을 ui-designer가 보장할 수 있도록 구체적 지시 포함

---

### PART 2: 컴포넌트 & 로직 DB (→ 03.컴포넌트 & 로직 DB)

#### 2.1 인수 조건 (Given-When-Then)

> **중요**: AC에 역할과 UI 흐름 포함. API 엔드포인트는 Swagger 참조.

```gherkin
### AC-1: 회사 목록 조회
Given: 관리자가 회사 목록 페이지에 접속
  - 역할: ADMIN

When: 페이지 로드 완료

Then: 회사 목록이 표시됨
  - UI: DataTable에 회사 목록 렌더링
  - 데이터: 회사코드, 회사명, 사업자번호, 대표자, 상태, 요금제, 만료일
```

```gherkin
### AC-2: 회사 등록
Given: 관리자가 등록 버튼 클릭
  - 역할: ADMIN
  - UI: Sheet (OVERLAY) 오픈

When: 필수 정보 입력 후 저장 클릭
  - 입력: 회사명, 사업자번호, 대표자명, 업태, 업종, 주소

Then: 등록 완료
  - UI: Sheet 닫힘 + 성공 Toast
  - 자동 생성: 회사코드 (COM{yyMMSeq:4}), 무료 요금제
  - 후처리: 목록 갱신
```

#### 2.2 컴포넌트 명세

> **참고**: 검색/필터 기본값, Request/Response Body, QueryParameter, ErrorCode 등은 **Swagger 문서** 참조

| 영역 | shadcn 컴포넌트 | Prepub 매핑 | 설명 |
|------|----------------|-------------|------|
| 검색 | `Input` | TextField | 검색어 입력 |
| 검색 버튼 | `Button` | Button | 검색 실행 |
| 필터 | `Select` | Select | 상태 필터 드롭다운 |
| 목록 | `DataTable` | DataTable | 메인 데이터 테이블 |
| 등록/수정 | `Sheet` + `Form` | Sheet + Form | 슬라이드 패널 폼 |
| 삭제 확인 | `AlertDialog` | AlertDialog | 삭제 전 확인 모달 |
| 알림 | `Toast` (sonner) | Toast | 성공/실패 피드백 |

> 커스텀 컴포넌트/외부 라이브러리 사용 시 별도 명시 필요

#### 2.2a UI 일관성 필수 규칙 (CRITICAL - Shift Left)

> **목적**: ui-improver/ui-supervisor에서 반복 발견되는 이슈를 기획 단계에서 사전 방지

**4대 필수 컴포넌트 규칙** (기획서에 반드시 명시):

| 규칙 | 올바른 컴포넌트 | 금지 패턴 |
|------|----------------|----------|
| 페이지 타이틀 | `PageTitle` 컴포넌트 | `<h1>` 직접 사용 |
| Sheet/폼 | `FormSheet` + `FormSheetFooter` | Sheet + 수동 패딩 |
| 날짜 선택 | `DateRangeFilter` / `DateRangePicker` | `<input type="date">` |
| 테이블 래퍼 | `overflow-x-auto px-4 py-2` | 패딩 없이 Table 렌더링 |

**재사용 컴포넌트 인벤토리** (기획 시 검색 필수):

| UI 요소 | 기존 공유 컴포넌트 | 위치 |
|---------|-------------------|------|
| 시간 입력 | `TimeInput` | `@bitda/web-platform` |
| 검색 선택 | `SearchableSelect` | `@bitda/web-platform` |
| 상태 뱃지 | `StatusBadge`, `LiquorTypeBadge` | `@bitda/web-platform` |
| 증빙 뱃지 | `EvidenceStatusBadge` | 앱 레벨 components |
| 확인 다이얼로그 | `ConfirmActionDialog` | `@bitda/web-platform` |
| 수량+단위 | `QuantityUnitInput` | `@bitda/web-platform` |
| 다중 품목 선택 | `MultiItemSelectDialog` | `@bitda/web-platform` |

> **중요**: 위 인벤토리에 있는 컴포넌트를 기획서 컴포넌트 명세에서 명시적으로 지정하면, ui-designer가 신규 구현 대신 기존 컴포넌트를 재사용합니다.

#### 2.2b UI 요소 필요성 판단 (Shift Left)

> **목적**: 기획에서 과도한 UI 요소를 정의하여 나중에 제거하는 낭비 방지

기획 시 다음 질문으로 각 UI 요소의 필요성을 검토:

| UI 요소 | 필요성 질문 | 판단 기준 |
|---------|------------|----------|
| 요약 카드 | 이 통계가 사용자 의사결정에 필수인가? | 데이터가 10건 미만이면 불필요할 수 있음 |
| 필터 | 목록이 30건 이상일 때 필터가 필요한가? | 소규모 데이터셋은 검색만으로 충분 |
| 검색창 | 데이터 건수가 검색이 필요한 수준인가? | 20건 미만이면 검색 불필요할 수 있음 |
| 탭 분리 | 하나의 뷰로 충분한데 탭을 나누는 건 아닌가? | 데이터 성격이 확연히 다를 때만 탭 분리 |

#### 2.3 테이블 컬럼 정의

> **한글 컬럼명만 기재** (기술 필드명은 API 문서 참조)

| 컬럼명 | 타입 | 정렬 | 필터 | 너비 |
|--------|------|------|------|------|
| 번호 | number | ✗ | ✗ | 60px |
| 회사코드 | string | ✓ | ✗ | 100px |
| 회사명 | string | ✓ | ✓ | auto |
| 사업자번호 | string | ✗ | ✗ | 120px |
| 대표자 | string | ✗ | ✗ | 100px |
| 상태 | badge | ✗ | ✓ | 80px |
| 요금제 | badge | ✗ | ✓ | 80px |
| 만료일 | date | ✓ | ✗ | 100px |

#### 2.4 데이터 명세

> **한글 필드명만 기재** (기술 필드명은 API 문서 참조)

**입력 필드:**
| 필드명 | 필수 | 유효성 검증 | UI 컴포넌트 |
|--------|------|------------|------------|
| 회사명 | ✓ | 1~100자 | Input |
| 사업자번호 | ✓ | 000-00-00000 형식 | Input (마스크) |
| 대표자명 | ✓ | 1~50자 | Input |
| 업종 | ✗ | - | Input |
| 업태 | ✗ | - | Input |
| 주소 | ✗ | - | Input |

**유효성 검증 규칙:**
| 필드 | 규칙 | 에러 메시지 |
|------|------|------------|
| 회사명 | 필수 | "회사명을 입력해주세요" |
| 사업자번호 | 형식 | "올바른 사업자번호 형식으로 입력해주세요" |
| 사업자번호 | 중복 확인 | "이미 등록된 사업자번호입니다" |

#### 2.5 상태별 UI

| 상태 | 조건 | UI 표현 |
|------|------|---------|
| Initial | 페이지 진입 직후 | Skeleton 테이블 |
| Loading | API 호출 중 | Spinner 오버레이 |
| Success | 데이터 있음 | 테이블 + 데이터 |
| Empty | 데이터 0건 | EmptyState + 등록 버튼 |
| Error | 조회 실패 | ErrorState + 재시도 버튼 |

#### 2.6 에러 처리

| HTTP 코드 | 상황 | UI 처리 |
|----------|------|---------|
| **403** | 권한 없음 | **403 페이지 표시** (로그인 이동 X) |
| 404 | 데이터 없음 | Toast + 목록 갱신 |
| 409 | 중복/충돌 | 필드 에러 표시 또는 Toast |
| 500 | 서버 오류 | Toast + 재시도 안내 |

> **중요**: 403 에러 시 로그인 페이지가 아닌 403 권한 없음 페이지 표시

#### 2.7 비즈니스 규칙

**목록 조회 규칙:**
| 항목 | 규칙 |
|------|------|
| 기본 정렬 | 등록일 기준 최신순 |
| 페이지당 건수 | 20건 (변경 가능: 10/20/50/100) |
| 검색 대상 | 회사명, 사업자번호 |
| 검색 방식 | 부분 일치 |

**등록/수정 규칙:**
| 항목 | 규칙 |
|------|------|
| 회사코드 | 등록 시 자동 생성, 수정 불가 |
| 사업자번호 | 중복 불가 |

**삭제 규칙:**
| 항목 | 규칙 |
|------|------|
| 삭제 조건 | 연결된 사용자가 없어야 함 |
| 삭제 방식 | **Soft Delete** (status = 'DELETED') |

**다건 삭제 처리:**
| 항목 | 규칙 |
|------|------|
| 트랜잭션 | **원자적 처리** (All or Nothing) |
| 실패 시 | 전체 롤백 + 실패 사유 Toast |
| 일부 불가 시 | 삭제 불가 항목 목록 표시 후 사용자 확인 |

---

### PART 3: API 맵핑 DB (→ 04.API 맵핑 DB)

#### 3.1 API 의존성

> **엔드포인트는 Swagger 참조**, 용도와 호출 시점만 명시

**사용 API 목록:**
| 용도 | 호출 시점 |
|------|----------|
| 목록 조회 | 페이지 로드, 검색, 필터 변경 |
| 상세 조회 | 수정 폼 오픈 |
| 등록 | 저장 버튼 클릭 |
| 수정 | 저장 버튼 클릭 |
| 삭제 | 삭제 확인 |
| 일괄 삭제 | 일괄 삭제 확인 |

**데이터 로드 시퀀스:**
```
페이지 마운트
    │
    └─▶ 목록 조회 API
        ├── 정렬: 최신 등록순
        └── 페이징: 20건씩
```

---

### 워크플로우

1. **페이지 식별**: 하위 메뉴 페이지 확인, 화면 유형 결정 (PAGE/OVERLAY/TAB)
2. **PART 1 작성**: 화면 유형, 개요, 흐름, 권한, 레이아웃, DB 연결 정보
3. **PART 2 작성**: AC, 컴포넌트, 테이블 컬럼, 데이터, 상태별 UI, 에러, 비즈니스 규칙
4. **PART 3 작성**: API 의존성, 데이터 로드 시퀀스
5. **Notion 저장**: `[화면코드]-[화면유형]-(화면명)` 형식으로 DB에 저장

---

## Mode 1-4 (기존 모드)

### Mode 1: 기존 기획 업데이트 (기획확정 전)

1. URL에서 Page ID 추출
2. Notion MCP로 조회
3. 수정 사항 분석 후 업데이트

> **⚠️ 다수 페이지 업데이트 시**: 3건 이상 페이지를 수정해야 할 경우
> 반드시 `references/notion-access-rules.md`의 "컨텍스트 관리" 섹션 참조.
> 메인 컨텍스트에서 notion-fetch는 **최대 2건**, 나머지는 **subagent 위임** 필수.

### Mode 2: 재설계 개발 (Migration)

1. `/migration_image/[feature]/` 이미지 분석
2. 분석 결과 요약 (화면, 로직, 데이터)
3. 추가 요구사항 확인
4. Mode 3 또는 Mode 5로 진행

### Mode 3: 신규 기능 개발

**Phase 1**: 기획초벌 - 핵심 목적, 주요 기능
**Phase 2**: 디벨롭 - 비즈니스 로직, 데이터 로드, 권한
**Phase 3**: 문서 생성 - `references/document-template.md` 참조

### Mode 4: 기획 변경 (기획확정 후)

1. 변경 유형 분류 (수정/보완/보충/제거)
2. 영향 범위 분석 (UI/API/데이터/로직)
3. 변경 명세서 작성 - `references/change-spec-template.md`
4. Notion 업데이트 (진행 단계: 기획 변경, 버전 +0.1)

> **⚠️ 다수 페이지 변경 시**: 영향 범위가 3건 이상 페이지에 걸치면
> `references/notion-access-rules.md`의 "컨텍스트 관리" 섹션 참조.
> 변경사항을 scratchpad 파일에 정리 → subagent가 개별 페이지 업데이트.

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
```
[화면 유형 / 개요]
- 사이드바 메뉴 위치: (예: 공통 관리 > 회사 관리)
- 라우트 경로: (예: /admin/company)
- 화면 유형: PAGE / OVERLAY / TAB
- 배경: 왜 이 페이지가 필요한가요?
- 목적: 핵심 기능은 무엇인가요?
- 사용자: 누가 사용하나요? (ADMIN / MANAGER / USER)

[화면 흐름]
- 진입 경로
- 내부 흐름 (목록→등록→수정→삭제)
- 연결 화면

[권한]
- ADMIN 전용: 권한 코드 불필요
- 다중 역할: 역할별 권한 매트릭스 + 권한 코드
- 모듈/기능 코드
```

**Step 2: PART 2 - 컴포넌트 & 로직 정보 수집**
```
[인수 조건]
- 주요 시나리오 (Given-When-Then)
- 목록 조회, 등록, 수정, 삭제 각각

[컴포넌트 / 데이터]
- 테이블 컬럼
- 입력 필드 / 유효성 검증
- 상태별 UI (Loading, Empty, Error)

[비즈니스 규칙]
- 목록 조회 규칙 (정렬, 페이징, 검색)
- 등록/수정 규칙
- 삭제 규칙 (Soft Delete, 다건 삭제)
```

**Step 3: PART 3 - API 맵핑 정보 수집**
```
[API 의존성]
- 사용 API 목록 (용도, 호출 시점)
- 데이터 로드 시퀀스
```

---

## Design Handoff

기획 완료 시:

1. 화면 코드 생성 (`references/convention-template.md`)
2. shadcn 컴포넌트 명세
3. Notion DB: `디자인 핸드오프: __YES__`

---

## Next Skills

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
> 상세: `references/notion-access-rules.md` → "매니페스트 우선 조회" 섹션

| 작업 | 매니페스트 활용 |
|------|---------------|
| Mode 1/4 (업데이트/변경) | 매니페스트에서 Page ID 조회 → 해당 페이지만 fetch (subagent) → 수정 후 매니페스트 업데이트 |
| Mode 3/5 (신규 생성) | notion-create-pages 완료 → 매니페스트에 "기획 초벌" 그룹에 새 행 추가 |
| 상태 조회 ("부서 협의중 목록") | 매니페스트 읽기만으로 완료 (0 Notion 토큰) |

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
