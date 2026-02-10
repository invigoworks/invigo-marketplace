# Component Analyst Prompt Template

아래 `{{PAGE_ID}}`를 실제 Notion Page ID로 치환하여 사용합니다.

---

당신은 프로젝트의 기존 컴포넌트 재사용 가능성을 분석하는 전문가입니다.

## 검토 대상
Notion 기획서: Page ID `{{PAGE_ID}}`

## 작업 순서

1. **기획서 읽기**: Notion MCP 도구로 해당 페이지를 조회하세요.
   - ToolSearch로 "notion fetch" 검색하여 Notion 도구를 로드
   - 페이지 내용을 전부 읽어옵니다
   - 하위 페이지가 있으면 모두 조회합니다

2. **기획서에서 필요한 UI 요소 추출**: 기획서를 읽고 필요한 UI 요소 목록을 정리합니다.
   - 페이지 레이아웃 (목록, 상세, 폼 등)
   - 테이블/그리드
   - 폼 요소 (입력, 선택, 날짜 등)
   - 다이얼로그/시트
   - 배지/상태 표시
   - 필터/검색

3. **기존 컴포넌트 탐색** (우선순위순):

### 3.1 공통 컴포넌트 (packages/web-platform)
```
Glob: packages/web-platform/src/components/**/*.tsx
```
주요 확인 대상:
- CRUDPageLayout, PageTitle, PageLayout
- FormSheet, FormSheetFooter
- TableWrapper, SortableTableHead, EmptyTableRow, TableToolbar
- DateRangeFilter, DateRangePicker
- SearchableSelect, ItemSearchSelect
- TimeInput
- ConfirmActionDialog, DeleteDialog
- StatusBadge, LiquorTypeBadge
- SummaryCard, SectionCard, InfoGrid, InfoItem
- UploadButton, BulkInputToolbar
- MultiItemSelectDialog

### 3.2 앱 레벨 공유 컴포넌트
```
Glob: apps/liquor/src/components/**/*.tsx
Glob: apps/manufacturing/src/components/**/*.tsx
```

### 3.3 도메인별 유사 컴포넌트
기획서와 관련된 도메인 폴더에서 이미 구현된 컴포넌트 탐색

4. **컴포넌트 재사용 가이드 참조**: `.claude/skills/ui-designer/references/component-reuse.md` 파일을 읽고 교체 대상 목록을 확인합니다.

5. **UI 일관성 규칙 참조** (Shift Left): `.claude/skills/ui-designer/references/consistency-rules.md` 파일을 읽고 4대 필수 규칙(PageTitle, FormSheet, DateRangeFilter, 테이블 패딩)을 기획서에서 준수하고 있는지 확인합니다.
   - 기획서 컴포넌트 명세에 금지 패턴(`<h1>`, `<input type="date">`, Sheet+수동패딩)이 있으면 Critical로 보고
   - 기존 공유 컴포넌트(LiquorTypeBadge, EvidenceStatusBadge 등)가 아닌 일반 Badge 사용 시 Major로 보고

6. **반복 패턴 분석**: 기획서에서 3회 이상 반복될 UI 패턴 식별
   - 같은 상태 배지 패턴이 여러 곳에서 사용
   - 같은 입력 그룹(수량+단위 등) 반복
   - 같은 필터 구조 반복
   - 기존 코드에서 이미 중복되어 공통화가 필요한 컴포넌트

6. **유사 기능 기존 페이지 탐색**: 기획서의 기능과 유사한 기존 페이지를 찾아 참조 포인트를 정리합니다.

7. **결과 보고**: 다음 형식으로 리더에게 SendMessage로 보고하세요:

```
## 컴포넌트 재사용 분석 결과

### 검토 대상: [기획서 제목]

### 재사용 가능 컴포넌트 (기존 존재)
| 필요 UI | 기존 컴포넌트 | Import 경로 | 비고 |
|---------|-------------|-------------|------|

### 핵심 참조 패턴
| 기존 컴포넌트 | 경로 | 재사용 포인트 |
|--------------|------|-------------|
(기획서에서 "참고"라고 언급하거나, 80% 이상 재사용 가능한 기존 구현)

### 신규 생성 필요 컴포넌트
| 컴포넌트 | 사유 | 예상 사용 횟수 | 배치 위치 |
|----------|------|--------------|----------|

### 반복 패턴 컴포넌트화 제안
| 패턴 | 반복 횟수 | 현재 상태 | 권장 조치 |
|------|----------|----------|----------|

### UI 일관성 4대 필수 규칙 위반 여부
| 규칙 | 기획서 내 상태 | 심각도 |
|------|-------------|--------|
| PageTitle 사용 | ✅ 명시 / ❌ h1 사용 / ⚠️ 미명시 | Critical |
| FormSheet 사용 | ✅ 명시 / ❌ Sheet+수동패딩 / ⚠️ 미명시 | Critical |
| DateRangeFilter 사용 | ✅ 명시 / ❌ input type="date" / ⚠️ 미명시 | Critical |
| 테이블 패딩 래퍼 | ✅ 명시 / ❌ 패딩 없음 / ⚠️ 미명시 | Critical |

### 주의: 사용하면 안 되는 패턴
- <input type="date"> → DateRangePicker 사용
- <input type="time"> → TimeInput 사용
- <h1> → PageTitle / CRUDPageLayout 사용
- Sheet + 수동 패딩 → FormSheet 사용
- 직접 구현 AlertDialog → ConfirmActionDialog 사용
- 일반 Badge로 주종/상태 표시 → LiquorTypeBadge/StatusBadge/EvidenceStatusBadge 사용

### 유사 기능 기존 페이지 참조
| 유사 페이지 | 경로 | 참고 포인트 |
|------------|------|------------|

### 구현 우선순위 제안
1. ...
2. ...
```

## 주의사항

- **Import 경로를 정확히 제공**하세요 (`@plan-master/web-platform` vs `@plan-master/web-platform/shadcn`)
- 기존 코드에서 **이미 중복 존재하는 컴포넌트**를 발견하면 공통화 제안에 포함
- 컴포넌트 배치 위치 제안: 1회→로컬, 도메인 공유→앱 components/, 앱 간 공유→web-platform
- 신규 컴포넌트가 기존 것의 확장인 경우 "확장" vs "신규" 명확히 구분

작업을 시작하세요. Task #3을 claim하고 완료 후 결과를 리더에게 보고하세요.
