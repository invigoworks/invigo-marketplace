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

- **REST API Script**: `.claude/shared-references/notion-db-uploader.py` for DB 행 등록 (화면/컴포넌트)
- **Notion MCP**: 읽기(`notion-fetch`, `notion-search`)와 속성 업데이트(`notion-update-page update_properties`)용
- **GitHub Deployment**: Code already pushed via github-deployer skill
- **Design Review**: UI confirmed and ready for registration

---

## 도구 분담 (REST API vs MCP)

| 작업 | 도구 | 이유 |
|------|------|------|
| **화면/컴포넌트 DB 행 등록** | `python .claude/shared-references/notion-db-uploader.py` | 빠르고 안정적, 토큰 0 |
| **마스터 코드 조회** | REST API `lookup` 명령 또는 MCP `notion-search` | 자동 해석 |
| **속성 업데이트** | MCP `notion-update-page update_properties` | 속성 전용 |
| **페이지 조회** | MCP `notion-fetch`, `notion-search` | 읽기 전용 |
| **테스트 데이터 삭제** | REST API `archive` 명령 | 빠른 정리 |

---

## Reference Files

- `../../shared-references/convention-template.md`: BITDA ERP screen code conventions (shared)
- `../../shared-references/notion-db-uploader.py`: REST API DB 행 등록 스크립트
- `references/notion-db-config.md`: Notion database IDs and schemas
- `references/agent-integration-guide.md`: Specialized agent usage for documentation quality

---

## Workflow

### Phase 1: Gather Context from Planning Documents

1. **기획문서 확인**:
   - **먼저** `.claude/shared-references/notion-manifest.md`에서 해당 기획문서의 Page ID 확인 (0 토큰)
   - 매니페스트에 있으면 해당 Page ID로 직접 `notion-fetch`
   - 매니페스트에 없으면: https://www.notion.so/invigoworks/01-2df471f8dcff80c0893becf766c394b0 에서 검색
   - Note: 기획문서는 초안 상태이므로 퍼블리싱 코드에 반영된 피드백 사항들을 추가로 파악해야 함

2. **퍼블리싱 코드 분석**:
   - Read the deployed code from GitHub (source 링크)
   - Identify UI components, form fields, validation rules
   - Extract actual business logic implemented in the code
   - This represents the FINAL confirmed specifications after feedback

### Phase 2: Gather Registration Data

1. **Screen Information**: 화면코드, 화면명, 화면유형 (S/F/P/R/D/M), 기능코드, GitHub source 링크, 연관된 기획문서
2. **Component Information**: 요소명, 비즈니스 로직 (Phase 3 참조), 연결할 화면

### Phase 2.5: 컴포넌트 등록 단위 판단 (CRITICAL)

> 테이블 API와 결합된 요소를 별도 등록하면 백엔드가 파편화된 문서를 참조하게 됨.

#### 판단 기준: "이 요소가 독립적인 API를 필요로 하는가?"

| 질문 | Yes → 분리 등록 | No → 병합 |
|------|----------------|----------|
| 자체 CRUD 엔드포인트가 필요한가? | Sheet, Dialog | FilterBar, Toolbar |
| 독립적으로 데이터를 조회/저장하는가? | 별도 API 호출 위젯 | 테이블 쿼리 파라미터 변경 UI |
| 다른 화면에서도 동일 API로 재사용되는가? | 공통 모달 | 특정 테이블 전용 필터 |

#### 병합 대상 (별도 등록 금지)

| 유형 | 예시 | 병합 위치 |
|------|------|----------|
| 필터바/검색바 | `*FilterBar`, `*SearchBar` | 부모 Table → 필터 파라미터 |
| 정렬/페이지네이션 | `SortableHeader`, `*Pagination` | 부모 Table → 정렬/페이징 |
| 테이블 툴바 | `TableToolbar`, `BulkInputToolbar` | 부모 Table → 대량 작업 |
| 인라인 액션 | 행 내 버튼, 토글 | 부모 Table → 행 액션 |

#### 분리 등록 대상

| 유형 | 예시 | 이유 |
|------|------|------|
| Sheet (생성/수정 폼) | `UserSheet`, `OrderSheet` | 독립적인 Create/Update API |
| Dialog (확인/삭제) | `DeleteDialog`, `ConfirmDialog` | 독립적인 Delete/Action API |
| 독립 모달 폼 | `ImportExcelDialog` | 독립적인 업로드 API |

**BAD** (파편화):
```
1. InventoryTable        → 목록 조회 로직
2. InventoryFilterBar    → 필터 로직     ← ❌ 별도 등록
3. InventoryPagination   → 페이지네이션  ← ❌ 별도 등록
```

**GOOD** (병합):
```
1. InventoryTable → 목록 조회 + 필터 + 정렬 + 페이지네이션 통합
2. InventorySheet → CRUD 로직
```

#### Route Page 컴포넌트 등록 규칙 (CRITICAL)

> **배경**: form-page.tsx, detail-page.tsx 등 route page가 화면 DB에 등록되었으나
> 대응하는 컴포넌트가 생성되지 않는 누락 사고가 발생함. 원인: `components/` 디렉토리에
> Sheet 파일이 없는 자기완결형 route page를 에이전트가 컴포넌트로 인식하지 못함.

**필수 검증**: 화면 DB에 등록한 **모든** route page에 대해 컴포넌트 1:1 매칭 확인.

| route 파일 패턴 | 화면유형 | 컴포넌트 매핑 방법 |
|----------------|---------|-------------------|
| `page.tsx` | S (Screen) | `components/*Table.tsx` → 컴포넌트 등록 |
| `form-page.tsx` 또는 `form/page.tsx` | F (Form) | 아래 판단 로직 적용 |
| `detail-page.tsx` 또는 `detail/page.tsx` | F (Form) | 아래 판단 로직 적용 |

**Form/Detail 컴포넌트 매핑 판단:**

```
form-page.tsx 또는 form/page.tsx 발견
    │
    ├─ components/ 에 *Sheet.tsx 존재?
    │   ├─ YES → 해당 Sheet를 컴포넌트로 등록 (기존 패턴)
    │   │        예: SalesOrderSheet.tsx → form-page.tsx 화면에 연결
    │   │
    │   └─ NO → route page 자체를 컴포넌트로 등록 ⚠️
    │            명명: [Module]FormPage (예: MiscIncomingFormPage)
    │            비즈니스 로직: route 파일 내부 코드에서 추출
    │
detail-page.tsx 또는 detail/page.tsx 발견
    │
    ├─ components/ 에 *DetailSheet.tsx 존재?
    │   ├─ YES → 해당 DetailSheet를 컴포넌트로 등록
    │   │
    │   └─ NO → route page 자체를 컴포넌트로 등록 ⚠️
    │            명명: [Module]DetailPage (예: MiscIncomingDetailPage)
```

**최종 검증 (Phase 5 완료 직전)**:

```
모든 화면에 최소 1개 이상의 컴포넌트가 연결되어 있는가?
```

컴포넌트가 0개인 화면이 있으면 누락된 것이므로 추가 생성한 후 Phase 6으로 진행.

### Phase 3: 비즈니스 로직 작성 가이드

> **목적**: 백엔드 개발자가 기획문서 없이 API를 개발할 수 있는 수준의 상세 명세

#### 🚫 절대 금지: 데이터 필드에 FE 변수명 사용

> **ENFORCEMENT**: 데이터 필드 테이블의 "항목" 컬럼에는 **반드시 한글 서술명**만 사용.
> 변수명은 백엔드가 자체 정의하므로 FE 변수명을 기재하면 혼란만 초래함.

**BAD** - FE 변수명 사용:
```
| 항목 | 타입 | 필수 | 설명 |
|------|------|------|------|
| orderNumber | string | Y | 주문번호 |
| supplierId | string(UUID) | Y | 입고처 ID |
| totalAmount | number | Y | 합계 금액 |
| status | enum | Y | 진행상태 |
```

**GOOD** - 한글 서술명 사용:
```
| 항목 | 타입 | 필수 | 설명 |
|------|------|------|------|
| 발주번호 | string | Y | 자동 채번 (PO-yyyyMMdd-NNN) |
| 입고처 | string(UUID) | Y | 거래처 FK |
| 합계 금액 | number | Y | 품목별 금액 합산, 자동 계산 |
| 진행상태 | enum | Y | 작성중/발주완료/입고완료/취소 |
```

> 이 규칙은 필터 파라미터, 정렬 필드, 페이지네이션 파라미터에도 동일하게 적용됨.

**BAD** - 필터에 변수명:
```
| 파라미터 | 타입 | 설명 |
|---------|------|------|
| warehouseId | string[] | 창고 필터 |
| keyword | string | 검색어 |
```

**GOOD** - 필터에 한글명:
```
| 필터 항목 | 타입 | 설명 |
|----------|------|------|
| 창고 | string[] | 다중 선택 |
| 검색어 | string | 품목명/품목코드 부분 일치 |
```

#### 비즈니스 로직 필수 포함 사항

1. **데이터 필드 정의**: 항목(한글), 타입, 필수 여부, 유효성 규칙, 기본값/옵션
2. **CRUD 동작**: 생성(필수/자동 필드), 조회(필터/정렬/페이징), 수정(가능/불가 필드), 삭제(조건/연관 처리)
3. **비즈니스 규칙**: 상태 변경 로직, 권한 체크, 연관 관계
4. **API 엔드포인트 제안**: HTTP Method + Path

#### 작성 예시

```
## InventoryTable (재고 목록)

### 데이터 필드
| 항목 | 타입 | 필수 | 설명 |
|------|------|------|------|
| 품목 ID | string(UUID) | Y | 자동생성 |
| 품목명 | string | Y | 제품/원재료명 |
| 창고 | string | Y | 창고 FK |
| 현재고 | number | Y | 실시간 수량 |
| 단위 | string | Y | kg, L, EA 등 |
| 최종입고일 | datetime | N | 마지막 입고 일시 |

### 목록 조회
- GET /api/v1/inventory

#### 필터
| 필터 항목 | 타입 | 설명 |
|----------|------|------|
| 창고 | string[] | 다중 선택 |
| 품목 분류 | string | 분류 코드 |
| 검색어 | string | 품목명/품목코드 부분 일치 |
| 재고 상태 | enum | 전체/재고있음/재고없음 |

#### 정렬
| 정렬 기준 | 기본값 | 설명 |
|----------|--------|------|
| 최종입고일 | desc | 기본 정렬 |
| 품목명 | - | 가나다순 |

#### 페이지네이션
- 기본 20건, 최대 100건
- 응답에 전체 건수, 전체 페이지 수 포함

### 비즈니스 규칙
- 재고 0 이하: 빨간색 강조
- 권한: 전체 사용자 조회 가능
```

### Phase 4: 화면 DB 등록

#### 4.1 Find Related Codes

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
- Search for the feature code → Get page URL for relation

> **CRITICAL: 중복 기능코드 선택 규칙**
>
> 일부 기능코드(DCL, PMA 등)는 **여러 모듈에 동일한 코드명으로 존재**함.
> `notion-search`로 기능코드를 검색하면 **2건 이상** 나올 수 있으므로, 반드시 **모듈 코드(`모듈 코드` relation)를 확인**하여 올바른 것을 선택해야 함.
>
> **앱별 모듈 코드 매핑:**
> | 대상 앱 | 앱 폴더 | 모듈 코드 | 모듈 Page ID |
> |--------|---------|----------|-------------|
> | 주류 ERP | `apps/liquor` | TAX | `d71c7ac7-e101-49e9-aaad-a6ae2aea0b60` |
> | 세무서 연동 | `apps/tax-office` | OFC | `2e3471f8-dcff-8039-836f-fa67a897ae8d` |
>
> **중복 기능코드 올바른 선택 테이블:**
> | 기능코드 | 주류앱(TAX) 사용 시 | 세무서앱(OFC) 사용 시 |
> |----------|-------------------|---------------------|
> | DCL | `2d3471f8-dcff-8035-8fe4-c9b102554fd1` | `2e3471f8-dcff-80d2-9e5c-c51e3a37768b` |
> | PMA | `2d3471f8-dcff-80d2-8d8d-c1304047a73e` | `2e3471f8-dcff-802f-8487-c69ee879f7a3` |
>
> **검증 방법**: 기능코드 페이지를 `notion-fetch`하여 `모듈 코드` relation이 대상 앱의 모듈과 일치하는지 확인.

#### 4.2 화면명 네이밍 규칙 (CRITICAL)

> **화면명에 화면코드를 절대 포함하지 않는다.**
> 화면코드는 DB의 `화면 코드 ID` formula 속성에서 자동 생성되므로 화면명에 중복 기재하면 안 됨.

**BAD** - 화면코드 포함:
```
BITDA-CM-HAC-LOG-S001 검사일지 (목록)
BITDA-CM-HAC-LOG-F001 검사일지 등록/수정 (폼)
BITDA-BR-DOC-EVD-P001 증빙 미리보기 Dialog
```

**GOOD** - 한글 화면명만 사용:
```
검사일지 (목록)
검사일지 등록/수정 (폼)
증빙 미리보기 Dialog
```

**네이밍 패턴**:
| 화면유형 | 패턴 | 예시 |
|---------|------|------|
| S (Screen) | `[기능명]` 또는 `[기능명] (목록)` | `증빙자료 관리`, `검사품목 (목록)` |
| F (Form) | `[기능명] 등록/수정 Sheet` 또는 `[기능명] 등록/수정 (폼)` | `보건증 등록/수정 Sheet` |
| P (Popup) | `[기능/동작명] Dialog` | `삭제 확인 Dialog`, `구매서 선택 Dialog` |
| R (Report) | `[리포트명]` | `월간 보고서` |
| D (Dashboard) | `[대시보드명]` | `관리자 대시보드` |

#### 4.3 Create Screen Entries

> **CRITICAL: `source 링크` 필수** - 모든 화면에 GitHub source URL을 반드시 설정해야 함.
> 빈 값으로 등록하면 notion-validator에서 Critical 오류로 검출됨.
> 병렬 에이전트 작업 시 공유 지침에서 이 속성이 누락되면 전체 화면이 빈 URL로 등록되는 사고가 발생함.

**source 링크 URL 구성 규칙:**
| 화면유형 | URL 패턴 |
|---------|---------|
| S (Screen/PAGE) | `[base]/[module]/page.tsx` |
| F (Form) | `[base]/[module]/form-page.tsx` 또는 `[base]/[module]/components/[Name]Sheet.tsx` |
| P (Popup) | `[base]/[module]/components/[Name]Dialog.tsx` |

- **base**: `https://github.com/invigoworks/pre-publishing/blob/main/apps/[app]/src/[domain]/[feature]`
- 실제 파일이 존재하는 경로여야 함 (등록 전 `Glob`으로 확인 권장)

**REST API로 등록** (권장):

```bash
# 단일 화면 등록
python .claude/shared-references/notion-db-uploader.py screen \
  --title "검사일지 (목록)" \
  --source "https://github.com/invigoworks/pre-publishing/blob/main/apps/liquor/src/haccp/inspection-log/page.tsx" \
  --status "기획 완료" \
  --screen-type "S" \
  --feature-code "LOG" \
  --plan-doc "기획문서-page-id"

# 일괄 등록 (JSON 파일)
python .claude/shared-references/notion-db-uploader.py batch --file /tmp/entries.json
```

**JSON 일괄 등록 형식:**
```json
{
  "screens": [
    {
      "title": "검사일지 (목록)",
      "source": "https://github.com/invigoworks/pre-publishing/blob/main/...",
      "status": "기획 완료",
      "screen_type": "S",
      "feature_code": "LOG",
      "plan_doc": "기획문서-page-id"
    }
  ],
  "components": [
    {
      "title": "InspectionTable",
      "logic": "## 목록 조회\n- GET /api/v1/inspections\n...",
      "screen": "auto:0"
    }
  ]
}
```

> `"screen": "auto:0"` → 같은 JSON의 screens[0] page_id를 자동 참조

**MCP 대체 사용법** (REST API 실패 시 fallback):

```json
notion-create-pages({
  parent: { data_source_id: "2d3471f8-dcff-8067-b573-000b0e2b1d04" },
  pages: [{
    properties: {
      "화면명": "[화면명]",
      "source 링크": "https://github.com/.../[path]",
      "상태": "기획 완료",
      "화면유형 코드": "[\"[화면유형URL]\"]",
      "기능코드": "[\"[기능코드URL]\"]",
      "연관된 기획문서": "[\"[기획문서URL]\"]"
    }
  }]
})
```

> **등록 직후 확인**: 모든 화면의 `source 링크`가 비어있지 않은지 검증. 1건이라도 빈 값이면 즉시 수정.

### Phase 4.5: 기획문서 DB Prepub URL 설정 (MANDATORY)

> 기획문서 DB의 `퍼블리싱 결과 확인` 속성에 prepub URL을 반드시 설정해야 함.
> 이 속성이 화면 DB의 `미리보기 링크` 롤업으로 연결되므로, 빈 값이면 미리보기 링크도 빈 값이 됨.

**Prepub URL 구성**: `https://prepub.invigoworks.co.kr/[route-path]`

```
notion-update-page({
  page_id: "[기획문서 Page ID]",
  command: "update_properties",
  properties: {
    "퍼블리싱 결과 확인": "https://prepub.invigoworks.co.kr/[route-path]"
  }
})
```

| 예시 | route-path | Prepub URL |
|------|-----------|------------|
| 기초 자료 설정 | liquor-tax/basic-data | https://prepub.invigoworks.co.kr/liquor-tax/basic-data |
| 회사 관리 | admin/company | https://prepub.invigoworks.co.kr/admin/company |

### Phase 5: 컴포넌트 & 로직 DB 등록

> Phase 2.5 완료 후 등록. FilterBar/Toolbar/Pagination은 부모 Table에 통합.

**REST API로 등록** (권장):

```bash
# 단일 컴포넌트 등록
python .claude/shared-references/notion-db-uploader.py component \
  --title "InspectionTable" \
  --logic-file /tmp/inspection-table-logic.md \
  --screen "화면-page-id"

# 비즈니스 로직을 인라인으로 전달
python .claude/shared-references/notion-db-uploader.py component \
  --title "InspectionSheet" \
  --logic "## 등록/수정\n- POST /api/v1/inspections\n..." \
  --screen "화면-page-id"
```

> 비즈니스 로직이 긴 경우 `--logic-file`로 파일 경로 전달 권장 (2000자 자동 분할)

**MCP 대체 사용법** (REST API 실패 시 fallback):

```json
notion-create-pages({
  parent: { data_source_id: "2d3471f8-dcff-8076-a4a3-000b502a3811" },
  pages: [{
    properties: {
      "요소명(ID)": "[컴포넌트명]",
      "비즈니스 로직": "[상세 비즈니스 로직]",
      "화면 DB 연동": "[\"[화면URL]\"]"
    }
  }]
})
```

### Phase 6: 등록 검수 (MANDATORY)

Phase 5 완료 후 반드시 `/notion-validator` 스킬 실행. 검수 결과에 따라:

| 결과 | 처리 |
|------|------|
| ✅ 통과 | 등록 완료 확정 |
| ⚠️ 경고 | 사용자에게 수정 권고 |
| ❌ 오류 | 즉시 수정 후 재검수 |

---

## Notion Database References

### 화면 DB
- **Data Source ID**: `2d3471f8-dcff-8067-b573-000b0e2b1d04`
- **Database URL**: https://www.notion.so/2d3471f8dcff802f945fc5add962fc6f

| 속성 | 타입 | 설명 |
|-----|------|------|
| 화면명 | title | 화면 이름 |
| source 링크 | url | GitHub 소스 링크 |
| 기능코드 | relation | 마스터 기능코드 연결 |
| 화면유형 코드 | relation | 화면유형 코드 연결 |
| 연관된 기획문서 | relation | 기획문서 DB 연결 |
| 상태 | status | 시작 전/기획 중/개발 중/기획 완료/개발 완료 |

### 컴포넌트 & 로직 DB
- **Data Source ID**: `2d3471f8-dcff-8076-a4a3-000b502a3811`
- **Database URL**: https://www.notion.so/2d3471f8dcff80d28041f0e98910c922

| 속성 | 타입 | 설명 |
|-----|------|------|
| 요소명(ID) | title | 컴포넌트 이름 |
| 비즈니스 로직 | text | 백엔드 API 개발용 상세 비즈니스 로직 |
| 화면 DB 연동 | relation | 화면 DB 연결 |

### 기타 DB

> **⚠️ REST API vs MCP ID 차이**: MCP Data Source ID와 REST API Database ID가 다른 경우 있음. `notion-db-uploader.py`에 올바른 REST API ID가 하드코딩되어 있으므로 스크립트 사용 시 별도 ID 지정 불필요.

| DB | MCP Data Source ID | REST API Database ID |
|----|----|---|
| 마스터 기능코드 | `2d3471f8-dcff-803d-8b2c-000b5b9855af` | `2d3471f8-dcff-80cd-9de7-dac5de60856a` |
| 화면유형 코드 | `2d3471f8-dcff-8051-ac76-000b25732bf2` | `c7255e5a-4433-4977-95cb-18b1f8d31a39` |
| 기획문서 DB | `2df471f8-dcff-80b2-9a6d-f9972b15aa06` | 동일 ([URL](https://www.notion.so/invigoworks/01-2df471f8dcff80c0893becf766c394b0)) |

---

## Registration Checklist

**Before**:
- [ ] GitHub 배포 완료
- [ ] 화면코드 컨벤션 준수
- [ ] 기능코드/화면유형 코드 확인
- [ ] 기획문서 URL 확보
- [ ] 퍼블리싱 코드 분석 완료
- [ ] 컴포넌트 등록 단위 검증 (Phase 2.5)
- [ ] 비즈니스 로직 상세 작성 (한글 필드명, 변수명 없음)
- [ ] **source 링크 URL 준비** (화면별 GitHub 파일 경로 매핑)
- [ ] **Prepub URL 준비** (기획문서별 라우트 경로 매핑)

**After (MANDATORY)**:
- [ ] 모든 화면의 `source 링크`가 비어있지 않은지 확인
- [ ] 모든 기획문서의 `퍼블리싱 결과 확인`이 비어있지 않은지 확인
- [ ] `/notion-validator` 검수 완료

---

## Post-Registration Output

```markdown
## Notion 등록 완료

### 화면 DB
| 화면명 | 화면코드 | 상태 | 연관된 기획문서 |
|--------|---------|------|----------------|
| [화면명] | BITDA-XX-XX-XX-S001 | 기획 완료 | [기획문서명] |

등록된 화면: [N]개

### 컴포넌트 & 로직 DB
| 요소명 | 연결 화면 | 비즈니스 로직 요약 |
|--------|----------|-------------------|
| [컴포넌트] | [화면명] | [CRUD 요약] |

등록된 컴포넌트: [N]개

### 확인 링크
- 화면 DB: https://www.notion.so/2d3471f8dcff802f945fc5add962fc6f
- 컴포넌트 DB: https://www.notion.so/2d3471f8dcff80d28041f0e98910c922
```

---

## Error Handling

| 오류 | 해결 |
|-----|------|
| Notion 연결 실패 | MCP 재연결 |
| 중복 등록 | 기존 항목 확인 |
| 코드 오류 | BITDA 컨벤션 재확인 |
| Relation 누락 | 마스터 DB에서 코드 검색 |
| 비즈니스 로직 부실 | Phase 3 가이드 재참조 |
