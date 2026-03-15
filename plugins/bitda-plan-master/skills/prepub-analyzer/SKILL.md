---
name: prepub-analyzer
description: Prepub UI 코드를 분석하여 "UI에 렌더링되는 것"과 "코드에만 존재하는 것"의 갭을 식별하고, 기획문서 작성 시 채택/제외 결정 리포트를 생성하는 사전 분석 스킬. plan-developer 실행 전 선행 스킬로 사용되며, 독립 호출도 가능. 트리거: "/prepub-analyze [모듈경로]", "prepub 분석해줘", "UI 코드 갭 분석해줘". Prepub 코드가 존재하는 모듈의 기획 작성/업데이트 시 자동 호출.
---

# Prepub Analyzer

## Overview

Prepub UI 코드베이스를 분석하여 **사용자에게 보이는 것(UI 렌더링)**과 **코드에만 숨어있는 것**의 갭을 식별한다. 기획문서 작성 시 UI 구현 기준으로 채택/제외를 사전 결정하여, 기획서와 실제 UI 간의 불일치를 방지한다.

### 핵심 원칙

> **UI 렌더링 우선**: 사용자가 화면에서 확인할 수 있는 형태로 구현된 항목이 기획문서의 기준선(baseline). 코드에만 존재하는 항목은 명시적 근거가 있을 때만 채택.

### 사용 시점

| 시점 | 설명 |
|------|------|
| plan-developer 선행 | Mode 1(기존 업데이트), Mode 4(기획 변경), Mode 5(페이지별 기획) 전에 실행 |
| 독립 호출 | `/prepub-analyze [모듈경로]`, "prepub 분석해줘" |
| 스킵 조건 | Mode 3(신규 기능) 등 prepub 코드가 없는 경우 |

### 산출물

`/tmp/<module>-ui-code-gap.md` — plan-developer의 content-writer가 참조

---

## Phase 1: 모듈 식별

1. 대상 모듈 경로 확인: `apps/[앱]/src/[도메인]/[기능]/`
2. 페이지 파일 목록 수집

```bash
# 페이지 파일 탐색
Glob: apps/[앱]/src/[도메인]/[기능]/**/*page*.tsx
Glob: apps/[앱]/src/[도메인]/[기능]/**/page.tsx
```

3. 모듈 내 전체 파일 구조 파악

```bash
# 타입, 컴포넌트, 훅, 상수 파일
Glob: apps/[앱]/src/[도메인]/[기능]/types.ts
Glob: apps/[앱]/src/[도메인]/[기능]/constants.ts
Glob: apps/[앱]/src/[도메인]/[기능]/components/**/*.tsx
Glob: apps/[앱]/src/[도메인]/[기능]/hooks/**/*.ts
```

---

## Phase 2: UI 표면 분석 (렌더링되는 것)

각 페이지 파일(`*-page.tsx`, `page.tsx`)을 읽고 다음을 추출한다.

### 2.1 컴포넌트 import 추적

```
분석 대상: 각 페이지 파일의 import 문
추출 항목: 실제 import된 로컬 컴포넌트 목록
```

### 2.2 JSX 렌더링 추적

각 페이지의 return/JSX 블록에서 실제 렌더링되는 요소를 추출한다.

| 분석 대상 | 추출 방법 |
|-----------|----------|
| 테이블 컬럼 | `<TableHead>`, `<TableCell>`, column 정의 배열에서 바인딩된 필드명 |
| 폼 필드 | `<Input>`, `<Select>`, `<Checkbox>`, `<Textarea>` 등에 바인딩된 필드명 |
| 뱃지/상태 표시 | `<Badge>`, `<StatusBadge>`, 커스텀 Badge 컴포넌트의 type/status prop |
| Dialog/Sheet 데이터 | Dialog/Sheet 내부에서 표시하는 데이터 필드 |
| 조건부 렌더링 | `{condition && <Component>}` 패턴에서 조건과 컴포넌트 |

### 2.3 결과 정리

각 페이지별로 **UI에 렌더링되는 항목 목록**을 작성한다:
- 사용 중인 컴포넌트
- 바인딩된 데이터 필드
- 표시되는 enum/타입 값
- 호출되는 hook 함수

---

## Phase 3: 코드 심층 분석 (숨어있는 것)

Phase 2에서 수집한 UI 표면 목록과 대조하여, **코드에 존재하지만 UI에 노출되지 않는 항목**을 식별한다.

### 3.1 타입/Enum 갭

```
1. types.ts에서 모든 union type, enum, const 객체의 값을 나열
2. Phase 2의 UI 표면에서 실제 사용되는 값과 대조
3. UI에 없는 값을 [HIDDEN]으로 분류
```

### 3.2 컴포넌트 갭

```
1. components/ 디렉토리의 모든 export 컴포넌트 나열
2. 각 페이지 파일의 import 문과 대조
3. 어떤 페이지에서도 import하지 않는 컴포넌트를 [ORPHAN]으로 분류
4. import는 하지만 JSX에서 렌더링하지 않는 경우 [HIDDEN]으로 분류
```

### 3.3 필드 갭

```
1. 주요 인터페이스(Record, Item, FormData 등)의 모든 필드 나열
2. Phase 2의 테이블 컬럼, 폼 필드, 표시 데이터와 대조
3. UI에 바인딩되지 않은 필드를 [HIDDEN]으로 분류
```

### 3.4 비즈니스 로직 갭

```
1. hooks/ 내 export된 함수/상태 나열
2. 페이지에서 실제 호출/사용되는 것과 대조
3. 호출되지 않는 로직을 [HIDDEN]으로 분류
4. 조건 분기 내 특정 값만 UI에서 트리거되지 않는 경우도 포함
   (예: switch문의 특정 case가 UI에서 도달 불가)
```

### 3.5 상수 갭

```
1. constants.ts의 모든 export 상수/매핑 나열
2. UI에서 참조되는 것과 대조
3. 미참조 상수를 [ORPHAN]으로 분류
```

---

## Phase 4: 갭 리포트 + 채택 결정

### 4.1 분류 체계

| 상태 | 의미 | 기본 결정 |
|------|------|----------|
| `[UI]` | 페이지에서 렌더링됨 | **채택** (기획서 반영) |
| `[HIDDEN]` | 코드에 존재하나 UI 미노출 | **판단 필요** (아래 기준 적용) |
| `[ORPHAN]` | 어디서도 참조되지 않음 | **제외** (기획서 미반영) |

### 4.2 HIDDEN 항목 채택 기준

`[HIDDEN]` 항목은 다음 기준을 **모두 확인**하여 채택/제외를 결정한다:

| 기준 | 채택 조건 | 제외 조건 |
|------|----------|----------|
| 비즈니스 임팩트 | 세액 계산, 상태 전이 등 핵심 로직에 영향 | UI 표시용에 불과 |
| 크로스 모듈 참조 | 다른 모듈에서 import하여 사용 중 | 해당 모듈 내부에서만 정의 |
| 구현 의도 | TODO/주석에 향후 구현 근거 존재 | 근거 없음 |
| 개념적 정합성 | 도메인 모델에 논리적으로 필요 | 분류 축 혼재, 개념 오류 (예: 처리유형에 사유 혼입) |

> **의심스러우면 제외**. UI에 렌더링되지 않는 항목을 기획서에 넣으면 "기획서에는 있지만 화면에는 없는" 갭이 재발한다.

### 4.3 산출물 형식

`/tmp/<module>-ui-code-gap.md`에 저장한다. 상세 형식은 `references/report-template.md` 참조.

---

## plan-developer 연동

### 입력 전달

plan-developer의 각 Mode에서 이 스킬의 산출물을 다음과 같이 활용한다:

| Mode | 활용 방식 |
|------|----------|
| Mode 1 (기존 업데이트) | code-analyst + content-writer 모두 gap 리포트 참조. 체크리스트에 [HIDDEN→제외] 항목이 기존 기획서에 있으면 제거 대상으로 표기 |
| Mode 4 (기획 변경) | 변경 영향 범위 분석 시 gap 리포트의 [UI] 항목만 변경 대상으로 한정 |
| Mode 5 (페이지별 기획) | PART 2 컴포넌트/테이블/데이터 명세 작성 시 [UI]+[HIDDEN→채택] 항목만 반영 |

### content-writer 프롬프트에 추가할 입력

```
UI-Code Gap 리포트: /tmp/<module>-ui-code-gap.md
규칙: [UI] 항목은 반드시 반영. [HIDDEN→채택] 항목은 "추가 구현 필요" 표기.
      [HIDDEN→제외] 및 [ORPHAN] 항목은 기획서에서 제외.
      기존 기획서에 [HIDDEN→제외] 항목이 있으면 제거.
```

---

## 코드-기획 불일치 필수 점검 (기획봇 인사이트 #1)

> 9건의 반복 에스컬레이션에서 도출된 추가 갭 탐지 항목

Phase 3 갭 식별 시 다음 항목을 **추가로** 점검한다:

| 점검 항목 | 예시 | 분류 |
|----------|------|------|
| **CRUD 동작 분기** | 수정/삭제 가능 여부가 상태에 따라 달라지는데 기획서에 미명시 | [HIDDEN→채택] |
| **파생 필드** | 다른 엔티티에서 join하여 표시하는 필드(납부기한, 거래처명)가 UI에 렌더링되지만 기획서에 미명시 | [UI] |
| **상태 전이 규칙** | `isConfirmed` 플래그에 따라 수정 가능/불가가 달라지는데 기획서에 상태 전이도 없음 | [HIDDEN→채택] |

---

## 실행 예시

```
사용자: "prepub 분석해줘 inventory/return-disposal"
또는
사용자: "환입/폐기 기획 업데이트해줘" → plan-developer가 자동 호출

1. Phase 1: apps/liquor/src/inventory/return-disposal/ 식별
2. Phase 2: page.tsx, detail-page.tsx, form-page.tsx, disposal-pending-page.tsx 분석
   → 각 페이지에서 렌더링되는 컴포넌트/필드/타입값 수집
3. Phase 3: types.ts, components/, hooks/, constants.ts 전수 조사
   → UI 표면과 대조하여 갭 식별
4. Phase 4: 갭 리포트 생성
   → 예: IncidentType.TRANSIT_LOSS → [HIDDEN→제외] (UI 미렌더링, 개념 혼재)
   → 예: IncidentTypeBadge in ReturnDisposalTable → [HIDDEN→채택] (기획서에 명시, 구현 누락)
5. /tmp/return-disposal-ui-code-gap.md 저장
```
