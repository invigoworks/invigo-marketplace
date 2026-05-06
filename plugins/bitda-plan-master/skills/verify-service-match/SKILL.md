---
name: verify-service-match
description: 실서비스 코드(data/bitda-front)와 현재 구현 간 UI 텍스트/레이아웃/논리적 정합성을 검증. 기능 존재 여부가 아닌 "동일하게 보이고 동작하는가"를 검사.
---

# 실서비스 UI 대조 검증

이 스킬은 `data/bitda-front` 실서비스 코드와 현재 구현(`apps/`) 간의 **UI-레벨 차이**를 검증한다.
기존 갭 분석에서 반복 누락된 패턴들을 사전에 차단하기 위한 검증 규칙.

## 실행 조건

- `/verify-implementation` 실행 시 자동 호출
- 실서비스 대조 작업 후 (Wave 7, 8 등)
- "실서비스 대조", "UI 일치 검증" 요청 시

## 검증 원칙

### 원칙 1: 3-레벨 검증 (존재 → 텍스트 → 논리)

| 레벨 | 질문 | 예시 |
|------|------|------|
| L1 존재 | "이 필드/컬럼이 있는가?" | 전화번호 필드 존재 여부 |
| L2 텍스트 | "라벨/placeholder/버튼이 실서비스와 동일한가?" | "생성" vs "저장", "분류 선택" vs "분류를 선택하세요" |
| L3 논리 | "삭제/추가 대상이 도메인 논리상 필요/불필요한가?" | 신고서에 기간 필드가 논리적으로 필수인가? |

**L1만 통과하면 안 됨. L2+L3도 반드시 확인.**

### 원칙 2: 삭제 전 논리 검증 (CRITICAL)

실서비스 스크린샷이나 코드에 보이지 않는다고 해서 바로 삭제하면 안 됨.
삭제 전 반드시 확인:

1. **도메인 필수성**: 이 필드 없이 엔티티가 생성/저장될 수 있는가?
2. **참조 관계**: 이 필드를 다른 곳에서 참조하는가? (ID 생성, 계산, 조건부 렌더링)
3. **상태 의존성**: 특정 상태에서만 보이는 조건부 필드인가?
4. **스크린샷 상태**: 스크린샷이 초기 상태(미선택)를 보여주는 것은 아닌가?

**위 4가지 중 하나라도 Yes이면 삭제 금지.**

### 원칙 3: 스크린샷은 한 순간의 스냅샷

스크린샷 1장은 폼의 한 가지 상태만 보여준다:
- Select가 "선택..."이면 → 조건부 필드가 숨겨진 상태
- 새 폼이면 → 수정 모드에서만 보이는 필드가 없음
- 빈 폼이면 → 데이터가 있을 때만 보이는 영역이 없음

**반드시 코드의 조건부 렌더링 로직과 교차 검증할 것.**

## 검증 패턴

### 패턴 1: 라벨/placeholder 불일치

**검증 방법**: 실서비스 `fields.ts`의 label/placeholder와 현재 구현의 FormLabel/placeholder 비교

```bash
# 실서비스 필드 정의에서 label 추출
grep -n "label:" data/bitda-front/apps/liquor/src/pages/{TARGET_MODULE}/shared/fields.ts

# 현재 구현에서 FormLabel 추출
grep -n "FormLabel>" apps/liquor/src/{TARGET_MODULE}/components/*Sheet.tsx
```

**판정**: label이 다르면 ❌ — 실서비스 label로 통일

### 패턴 2: 버튼 텍스트 불일치

**검증 방법**: 실서비스 submitLabel과 현재 Button 텍스트 비교

**주요 불일치 패턴**:
- "등록/수정" → 실서비스는 대부분 "저장"
- "생성" → 실서비스는 "저장" 또는 "등록"
- "삭제" vs "제거" vs "삭제하기"

**판정**: 텍스트가 다르면 ⚠️ — 실서비스 텍스트로 통일

### 패턴 3: 폼 레이아웃 (그리드 배치) 불일치

**검증 방법**: 실서비스 formConfig의 columns/groups와 현재 grid-cols 비교

**주요 불일치 패턴**:
- 1열 배치 vs 2열 배치
- 필드 순서 차이
- 섹션 헤더 텍스트 차이

**판정**: 배치가 다르면 ⚠️ — 실서비스 레이아웃으로 조정

### 패턴 4: 조건부 필드의 잘못된 삭제/표시

**검증 방법**: 실서비스 formConfig의 create vs edit 차이 확인

```bash
# 실서비스에서 create/edit config 차이 확인
grep -A5 "CreateFormConfig\|EditFormConfig\|createFormConfig\|editFormConfig" \
  data/bitda-front/apps/liquor/src/pages/{TARGET_MODULE}/shared/configs/*FormConfig.ts
```

**주요 불일치 패턴**:
- 생성 시에만 숨겨야 할 필드가 항상 표시됨 (예: status)
- 수정 시에만 표시할 필드가 생성 시에도 표시됨
- 특정 값 선택 시 나타나는 조건부 필드가 누락됨

**판정**: 조건부 표시가 다르면 ❌ — 실서비스 조건과 일치시키기

### 패턴 5: 필드 필수/선택 불일치

**검증 방법**: 실서비스 schema의 required/optional과 현재 Zod schema 비교

```bash
# 실서비스 스키마 확인
cat data/bitda-front/apps/liquor/src/pages/{TARGET_MODULE}/shared/schemas/*.schema.ts

# 현재 구현 스키마 확인
grep -A2 "z\.\(string\|number\|enum\)" apps/liquor/src/{TARGET_MODULE}/components/*Sheet.tsx
```

**판정**: 필수/선택이 다르면 ❌ — 도메인 논리 기준으로 판단

### 패턴 6: 도메인 논리 누락 (삭제된 필수 필드)

**검증 방법**: 엔티티 ID 생성 로직에서 사용되는 필드가 폼에 존재하는지 확인

```bash
# ID 생성에 사용되는 필드 확인
grep -n "id:.*\`\|id = \`" apps/liquor/src/{TARGET_MODULE}/ -r --include="*.tsx" --include="*.ts"
```

**판정**: ID 생성에 필요한 필드가 폼에 없으면 ❌ — CRITICAL, 반드시 복원

### 패턴 7: re-export 체인 추적 실패

**문제**: 실서비스 파일이 `export { X } from '@bitda/core-*'` 한 줄인 경우, 실제 정의가 packages/core/*/에 있음.
단순히 앱 레벨 파일만 읽으면 빈 파일로 보여 "구현 없음"으로 오판.

**검증 방법**: 실서비스 configs 파일이 re-export만 하는 경우, 원본 패키지까지 추적

```bash
# re-export 체인 감지
grep -rn "export.*from '@bitda/" data/bitda-front/apps/liquor/src/pages/{TARGET_MODULE}/
# 원본 패키지에서 실제 정의 찾기
grep -rn "export.*{TARGET_EXPORT}" data/bitda-front/packages/core/
```

**판정**: re-export인데 원본을 확인하지 않았으면 ❌ — 원본 패키지의 실제 컬럼/필드 정의를 반드시 읽을 것

### 패턴 8: 테이블 컬럼 구조 불일치 (그룹/세부 컬럼)

**문제**: 실서비스의 GridColumnGroup (headerName + children) 구조를 현재 구현이 단순화함.
예: 주세 6개 + 교육세 3개 세부 컬럼 → 납부세액 1개로 합침.

**검증 방법**: 실서비스 columns.tsx의 GridColumnGroup과 현재 TableHead 구조 비교

**판정**: 그룹 내 세부 컬럼 수가 다르면 ❌ — 실서비스 컬럼 구조로 맞출 것

### 패턴 9: "불가능" 판단 전 기존 패턴 미확인

**문제**: "API가 없어서 stub으로 처리"라고 판단하기 전에, 같은 프로젝트에서 이미 클라이언트사이드로 동일 기능을 구현한 곳이 있는지 확인하지 않음.

**검증 방법**:
```bash
# stub으로 남겨진 곳 찾기
grep -rn "준비 중\|기능 준비\|toast.info.*준비" apps/liquor/src/ --include="*.tsx" --include="*.ts"

# 같은 기능이 이미 구현된 곳 찾기 (예: xlsx)
grep -rn "import.*xlsx\|from.*xlsx\|writeFile\|exportToExcel" apps/liquor/src/ --include="*.tsx" --include="*.ts"
```

**판정**: stub인데 같은 프로젝트에 이미 작동하는 구현 패턴이 있으면 ❌ — 기존 패턴 참조하여 구현

### 패턴 10: 공유 상태가 잘못된 컴포넌트에 배치됨

**문제**: 여러 탭/컴포넌트에서 사용하는 상태가 하나의 자식 컴포넌트 내부에 배치됨.
예: 제조유형(자가/위탁/수탁)이 REL 탭 내부에 있지만 LED 탭에서도 필요.

**검증 방법**: 
1. 부모 컴포넌트(detail-page 등)에서 여러 자식에 동일한 prop을 전달하는지 확인
2. 자식 컴포넌트 내부에 useState가 있는데, 해당 상태가 형제 컴포넌트에서도 필요한지 확인
3. 실서비스의 상태 배치 위치와 비교

**판정**: 상태가 형제 컴포넌트에서도 필요한데 하나의 자식에만 있으면 ❌ — 부모로 lift up

### 패턴 11: 동일 개념의 타입/상수 중복 정의

**문제**: 같은 비즈니스 개념이 다른 이름과 다른 값으로 중복 존재.
예: `FilingType = REGULAR|AMENDED|LATE` vs `DeclarationType = REGULAR|AMENDED|OVERDUE`

**검증 방법**:
```bash
# 유사한 라벨을 가진 타입 찾기
grep -rn "type.*=.*REGULAR.*AMENDED" apps/liquor/src/ --include="*.ts"
```

**판정**: 동일 라벨을 가진 다른 타입이 존재하면 ⚠️ — alias로 통일하거나 하나를 제거

### 패턴 12: 부모-자식 간 동일 컴포넌트 중복 렌더링

**문제**: 부모에서 DownloadButton을 배치했는데, 자식 컴포넌트 내부에도 이미 같은 DownloadButton이 있음.

**검증 방법**:
```bash
# 부모와 자식 모두에서 같은 컴포넌트를 import하는 경우 찾기
grep -rn "import.*DownloadButton" apps/liquor/src/liquor-tax/ --include="*.tsx"
```

부모 파일(detail-page.tsx 등)과 자식 파일(Tab 컴포넌트)에서 동일 컴포넌트를 import하면 중복 가능성 확인

**판정**: 부모와 자식이 같은 UI 컴포넌트를 렌더링하면 ❌ — 한쪽만 유지

### 패턴 13: Excel export 구조가 실서비스 columns.tsx와 불일치

**문제**: 클라이언트 Excel export의 컬럼 순서/헤더/데이터 포맷이 실서비스의 columns.tsx + fields.ts 기준과 다름.
실서비스는 백엔드에서 Excel을 생성하지만, columns.tsx의 컬럼 정의가 export 구조의 SSOT.

**검증 방법**:
1. 실서비스 `columns.tsx`의 컬럼 순서 추출
2. 현재 `excel-io.ts`의 HEADER_MAP 순서 비교
3. 각 컬럼의 데이터 포맷 비교 (number/date/boolean/relation 처리)
4. 다중 시트 패턴 비교 (Product Declarations: 2시트)

**판정**: 컬럼 순서, 헤더, 시트 구조가 다르면 ❌ — columns.tsx 기준으로 일치

### 패턴 14: 백엔드 리소스(템플릿/에셋) 미사용으로 인한 서식 불일치 (CRITICAL)

**근본 원인**: `data/bitda-back/`에 실제 사용되는 리소스 파일(xlsx 템플릿, 이미지, 설정 등)이 존재하는데,
이를 확인하지 않고 프론트엔드에서 처음부터 새로 만들어 결과물이 완전히 달라지는 패턴.

**발생 경과 (2026-04-13 실례)**:
1. 사용자: "data에 백엔드 구현 참고해서 동일하게 만들어"
2. 에이전트: 백엔드 **코드만** 분석하고, 백엔드가 사용하는 **xlsx 템플릿 파일**의 존재를 확인하지 않음
3. 결과: 정부 양식(별지 제1호서식 등)을 프로그래밍으로 재현 시도 → 서식 완전 불일치
4. 3번의 수정을 거쳐야 "템플릿 로드 → 데이터 주입" 방식(백엔드와 동일)에 도달

**핵심 실수**: 백엔드 Generator 코드에 `loadTemplate(TEMPLATE_PATH)`가 명확히 있었고,
분석 에이전트도 "Pattern B: Template-Injection"이라 보고했는데, 구현 시 이를 무시함.

**검증 방법**:
```bash
# 1. 백엔드 리소스 디렉토리에서 사용 가능한 에셋 찾기
find data/bitda-back/ -name "*.xlsx" -o -name "*.pdf" -o -name "*.png" | grep -i "template\|resource"

# 2. 백엔드 코드에서 템플릿/리소스 로딩 패턴 찾기
grep -rn "getResourceAsStream\|loadTemplate\|TEMPLATE_PATH\|classpath:" \
  data/bitda-back/modules/ --include="*.kt" | grep -v "test/"

# 3. 프론트엔드에서 해당 리소스를 사용하고 있는지 확인
ls apps/liquor/public/templates/ 2>/dev/null || echo "❌ 템플릿 디렉토리 없음"

# 4. 프론트엔드 Excel 생성 코드에서 템플릿 로드 vs 직접 생성 확인
grep -rn "loadTemplate\|fetch.*template\|new ExcelJS.Workbook()" \
  apps/liquor/src/ --include="*.ts"
```

**판정 기준**:
| 조건 | 판정 |
|------|------|
| 백엔드에 템플릿 파일이 있고, 프론트엔드에서 직접 생성하고 있으면 | ❌ CRITICAL |
| 백엔드 템플릿이 `public/templates/`에 복사되어 있으면 | ✅ |
| 프론트엔드가 `fetch → load → 데이터 주입` 패턴을 사용하면 | ✅ |

**수정 방법**:
1. 백엔드 `src/main/resources/templates/` 에서 `public/templates/` 로 복사
2. 백엔드 Generator의 셀 좌표 상수를 그대로 옮겨 사용 (0-indexed row/col)
3. `fetch(templateUrl) → workbook.xlsx.load(buffer) → 셀 주입 → saveAs` 패턴 적용
4. 절대로 양식을 프로그래밍으로 재현하려 하지 말 것

**적용 범위**: Excel/PDF 다운로드뿐 아니라, 인쇄 양식, 증명서, 거래명세서 등
백엔드에 서식 템플릿이 있는 모든 기능에 적용.

### 패턴 15: 분석 결과→구현 지시 단절

**근본 원인**: 리서치 에이전트의 분석 결과가 충분히 상세했으나,
구현 에이전트에게 전달할 때 핵심 정보가 빠져 잘못된 방식으로 구현되는 패턴.

**발생 경과**:
- 분석 에이전트: "Pattern B: Template-Injection, 템플릿에 데이터 주입" 보고
- 구현 에이전트 프롬프트: "공유 유틸 사용해서 구현해" → 템플릿 방식 정보 누락
- 결과: 데이터 테이블 형식으로 구현 (실서비스와 완전 불일치)

**검증 방법**:
구현 시작 전 다음 체크리스트를 반드시 확인:
1. 백엔드의 **생성 방식**(직접 생성 vs 템플릿 주입)이 구현 계획에 반영되었는가?
2. 백엔드의 **셀 좌표 상수**가 구현 코드에 매핑되었는가?
3. 백엔드의 **리소스 파일**이 프론트엔드에 복사되었는가?
4. 분석 에이전트의 보고에서 "template", "inject", "Pattern B" 키워드가 있었는데 무시한 것은 아닌가?

**판정**: 분석 결과에 "템플릿" 키워드가 있었는데 구현에서 직접 생성하고 있으면 ❌ — 분석 결과 재확인

### 패턴 16: 템플릿 기반 Excel에서 헤더 영역 데이터 주입 누락

**근본 원인**: 백엔드 Generator가 `fillHeader()` + `fillData()` 두 단계로 나뉘는데,
프론트에서 데이터 행만 구현하고 헤더(회사명, 기간, 제조유형, 사업자번호) 주입을 빠뜨림.

**검증 방법**:
```bash
# 백엔드 Generator에서 fillHeader 로직 확인
grep -n "fillHeader" data/bitda-back/modules/application/api/src/main/kotlin/com/invigoworks/bitda/api/tax/declaration/taxform/*.kt

# 프론트 export 함수에서 헤더 주입 유무 확인
grep -A5 "loadTemplate" apps/liquor/src/liquor-tax/declaration/utils/excel-export.ts | grep -E "header|companyName|businessRegistration|manufacturing"
```

**판정**: 백엔드에 `fillHeader`가 있는데 프론트에 없으면 ❌

### 패턴 17: 클라이언트 PDF 생성 시 한글 폰트 미등록

**근본 원인**: jsPDF의 기본 폰트(helvetica, courier, times)는 한글 글리프를 포함하지 않음.
한글 폰트(NanumGothic 등)를 `addFileToVFS` + `addFont`로 등록하지 않으면 한글이 깨짐.

**발생 경과 (2026-04-13)**:
- jsPDF로 PDF 생성 → 한글 전부 깨짐 (ÈüÁ8Âà¬àÁ 등)
- NanumGothic-Regular.ttf를 `public/fonts/`에 배치 → SPA fallback으로 fetch 실패
- `src/assets/fonts/`로 이동 + Vite `?url` import → 정상 로드

**검증 방법**:
```bash
# 1. PDF 생성 코드에서 한글 폰트 등록 확인
grep -rn "addFont\|addFileToVFS\|NanumGothic" apps/liquor/src/ --include="*.ts"

# 2. 기본 폰트 사용 여부 확인 (FAIL이면 한글 깨짐)
grep -rn '"helvetica"\|"courier"\|"times"' apps/liquor/src/ --include="*.ts" | grep -v "node_modules"

# 3. 폰트 파일 존재 확인
ls apps/liquor/src/assets/fonts/*.ttf
```

**판정**: PDF 생성 코드에 `addFont` 없이 `helvetica` 사용 중이면 ❌

### 패턴 18: 백엔드 @ExcelColumn 속성값 불일치 (CRITICAL)

**근본 원인**: 프론트엔드 `ExcelColumnDef`에 속성이 정의되어 있어도, 각 모듈의 `excel-io.ts`에서
백엔드 `@ExcelColumn` 어노테이션의 속성값과 실제로 일치하는지 검증해야 한다.

**구현 완료 속성** (2026-04-13): comment, guide, example, dropdownValues, readOnly, freeze,
hidden, collapsed, formula, SheetBlock — `ExcelColumnDef`에 추가 + `excel-utils.ts`에서 처리.

**검증 방법**:
```bash
# 1. 백엔드 ExcelRow DTO에서 속성값 추출
grep -A2 "dropdownValues\|readOnly\|comment\|guide\|example\|freeze\|collapsed\|formula" \
  data/bitda-back/modules/application/api/src/main/kotlin/com/invigoworks/bitda/api/*/dto/*ExcelRow.kt

# 2. 프론트 excel-io.ts에서 대응하는 속성값 추출
grep -n "dropdownValues:\|readOnly:\|comment:\|guide:\|example:\|freeze:\|collapsed:\|formula:" \
  apps/liquor/src/settings/master-data/*/utils/excel-io.ts

# 3. 양쪽 값 대조 — 불일치 탐지
```

**판정**: 백엔드 DTO에 정의된 속성값이 프론트 excel-io.ts에서 누락되거나 값이 다르면 ❌

**잔여 갭** (구현 불가 — 프론트 제한):
- `useEnumValidation` → Kotlin enum 런타임 해석 불가, 라벨 배열로 수동 매핑
- `referenceType` → 동적 참조 드롭다운 (API 데이터 필요), 프론트에서 정적 대체 불가
- `crossSheetRef` → 2-시트 구조에서만 적용 (상표신고 등), 개별 구현 필요

### 패턴 19: 템플릿 downloadTemplate 출력 동작 불일치 (CRITICAL)

**근본 원인**: `@ExcelColumn` 속성값이 모두 맞아도, 백엔드 `ExcelOrchestrator.renderSheet(templateMode=true)`의
**출력 동작**까지 재현하지 않으면 실서비스 양식과 시각적으로 다른 결과가 나온다.

**필수 동작** (ExcelOrchestrator 기준):
1. readOnly 컬럼 제외 (formula/lookupSource 있는 것은 유지)
2. 빈 데이터 행 1000행에 테두리+배경+정렬+numFmt+수식+드롭다운 전체 사전 적용
3. SheetBlock 경고/안내 박스 렌더링
4. 가이드행 자동생성 (readOnly→"자동생성", required→"필수 입력", dropdown→"드롭다운에서 선택")
5. 예시행 렌더링

**검증 방법**:
```bash
# 1. downloadTemplate에서 readOnly 컬럼 필터링 확인
grep -n "readOnly\|templateColumns\|filter" apps/liquor/src/utils/excel-utils.ts | head -5

# 2. 빈 행 수 확인 (백엔드 DEFAULT_EMPTY_ROWS=1000)
grep -n "TEMPLATE_EMPTY_ROWS\|1000\|rowCount" apps/liquor/src/utils/excel-utils.ts

# 3. SheetBlock 사용 여부 확인
grep -rn "sheetBlocks\|SheetBlockDef" apps/liquor/src/settings/master-data/*/utils/excel-io.ts

# 4. 빈 행에 테두리+배경이 적용되는지 확인
grep -n "applyTemplateEmptyRows\|ALL_BORDERS\|WHITE" apps/liquor/src/utils/excel-utils.ts
```

**판정**: 위 5가지 동작 중 하나라도 누락이면 ❌
| SheetBlock | 중 | 낮음 (안내 텍스트) | P3 |

## Exceptions (false positive 방지)

1. **FormSheet title/description**: 실서비스가 FormView를 쓰므로 title이 없을 수 있음. 현재 구현의 FormSheet title은 UX 추가이므로 불일치가 아님.
2. **DynamicIcon vs lucide import**: 아이콘 구현 방식의 차이는 기능 갭이 아님.
3. **FormSheetFooter vs div**: 래퍼 컴포넌트 차이는 기능 갭이 아님.
4. **실서비스에 없는 UX 추가**: dirty check, 확인 다이얼로그 등 현재 구현에 추가된 UX 개선은 갭이 아님 (오히려 장점).

## 실행 절차

1. 대상 모듈의 실서비스 `fields.ts` + `*FormConfig.ts` + `columns.tsx` 읽기
2. re-export 파일이면 원본 패키지까지 추적 (패턴 7)
3. 현재 구현의 `*Sheet.tsx` + `page.tsx` + `excel-io.ts` 읽기
4. 패턴 1~13 순서대로 검증
5. 각 이슈에 레벨(L1/L2/L3) + 심각도(❌/⚠️) 태그
6. L3 논리 검증 결과를 별도 섹션으로 리포트
7. stub 목록과 기존 구현 패턴 교차 확인 (패턴 9)
