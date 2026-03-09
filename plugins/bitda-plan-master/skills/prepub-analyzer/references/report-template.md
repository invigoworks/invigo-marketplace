# UI-Code Gap Analysis Report Template

> 이 템플릿은 prepub-analyzer의 산출물 형식을 정의한다.
> `/tmp/<module>-ui-code-gap.md`에 저장할 때 이 형식을 따른다.

---

## 파일명 규칙

`/tmp/<module>-ui-code-gap.md`

- `<module>`: 모듈 디렉토리명 (예: `return-disposal`, `product`, `evidence`)
- 예시: `/tmp/return-disposal-ui-code-gap.md`

---

## 리포트 형식

```markdown
# UI-Code Gap Analysis: <모듈 한글명>

**분석일**: YYYY-MM-DD
**모듈 경로**: apps/<앱>/src/<도메인>/<기능>/
**분석 페이지**: page.tsx, detail-page.tsx, form-page.tsx, ...
**총 파일 수**: N개

---

## 1. 요약

| 분류 | 건수 | 설명 |
|------|------|------|
| [UI] 렌더링됨 | X | 기획서 반영 (baseline) |
| [HIDDEN→채택] | Y | 코드 존재, 채택 근거 있음 |
| [HIDDEN→제외] | Z | 코드 존재, UI 미노출, 제외 |
| [ORPHAN] | W | 미참조, 제외 |

---

## 2. 타입/Enum 갭

| 타입명 | 값 | UI 노출 위치 | 상태 | 결정 | 사유 |
|--------|---|-------------|------|------|------|
| IncidentType | FACTORY_RETURN | detail-page 뱃지, form-page 선택 | [UI] | 채택 | - |
| IncidentType | TRANSIT_LOSS | (없음) | [HIDDEN] | 제외 | UI 미렌더링, 개념적으로 사유에 가까움 |
| IncidentType | DIRECT_DISPOSAL | form-page 선택 | [UI] | 채택 | - |
| IncidentType | MIXED | detail-page 뱃지 | [UI] | 채택 | - |
| DisposalReason | EXPIRED | form-page 선택 | [UI] | 채택 | - |

> **작성 규칙**:
> - 모든 union type / const 객체의 값을 빠짐없이 나열
> - UI 노출 위치는 "페이지명 + 구체적 위치" 형식 (예: "form-page 테이블 3번째 컬럼")
> - [HIDDEN] 항목의 사유는 구체적으로 기술

---

## 3. 컴포넌트 갭

| 컴포넌트 | 파일 | 페이지 import 현황 | 상태 | 결정 | 사유 |
|----------|------|-------------------|------|------|------|
| IncidentTypeBadge | components/IncidentTypeBadge.tsx | detail-page ✅, page ❌ | [HIDDEN] | 채택 | 목록 테이블에 컬럼 추가 필요 |
| BulkEvidenceDialog | components/BulkEvidenceDialog.tsx | (없음) | [ORPHAN] | 제외 | 어떤 페이지에서도 미사용 |
| StatusSummaryCards | components/StatusSummaryCards.tsx | page ✅ | [UI] | 채택 | - |

> **작성 규칙**:
> - components/ 디렉토리의 모든 export 컴포넌트 나열
> - 페이지 import 현황에 각 페이지별 ✅/❌ 표기
> - barrel export(index.ts)만 있고 실제 페이지 import 없으면 [ORPHAN]

---

## 4. 필드 갭

| 인터페이스 | 필드 | UI 바인딩 위치 | 상태 | 결정 | 사유 |
|-----------|------|--------------|------|------|------|
| ReturnDisposalRecord | managementNumber | page 테이블 1열 | [UI] | 채택 | - |
| ReturnDisposalRecord | incidentType | page 테이블 ❌ | [HIDDEN] | 채택 | 컬럼 추가 필요 |
| ReturnDisposalItem | returnReason | form-page ❌ | [HIDDEN] | 제외 | UI 미구현, 입력 필드 없음 |
| ReturnDisposalFormData | salesOrderId | form-page 판매서 선택 | [UI] | 채택 | - |

> **작성 규칙**:
> - 주요 인터페이스(Record, Item, FormData, PendingItem 등)의 필드를 전수 나열
> - optional 필드(`?`)도 포함
> - UI 바인딩: "페이지명 + 바인딩 유형(테이블 컬럼/폼 필드/표시 텍스트/뱃지)"

---

## 5. 비즈니스 로직 갭

| Hook/함수 | 기능 | UI 트리거 | 상태 | 결정 | 사유 |
|----------|------|----------|------|------|------|
| useReturnDisposalForm.setIncidentType | 처리유형 변경 | form-page 라디오 선택 | [UI] | 채택 | - |
| calculateTax (TRANSIT_LOSS 분기) | 운송손실 세액계산 | (없음) | [HIDDEN] | 제외 | TRANSIT_LOSS 제외에 연동 |
| generateManagementNumber | 관리번호 생성 | form-page 저장 시 | [UI] | 채택 | - |

> **작성 규칙**:
> - hooks/ 내 export 함수 + 유틸리티 함수 포함
> - switch/if 분기 내 특정 case가 UI에서 도달 불가한 경우도 기록
> - "UI 트리거"는 어떤 사용자 액션이 이 로직을 호출하는지 기술

---

## 6. 기획서 작성 가이드

### 채택 항목 (기획서에 반영)

> [UI] + [HIDDEN→채택] 항목을 기획서 섹션별로 정리

#### 데이터 명세 반영
1. (필드명) — (반영할 섹션)

#### 컴포넌트 명세 반영
1. (컴포넌트명) — (반영 방식)

#### 비즈니스 규칙 반영
1. (규칙) — (반영할 섹션)

### 제외 항목 (기획서에서 생략)

> [HIDDEN→제외] + [ORPHAN] 항목. 기존 기획서에 이 항목이 있으면 **제거 대상**.

1. (항목) — (제외 사유)
2. ...

### 주의 사항

- [HIDDEN→채택] 항목은 기획서에 **"현재 UI 미구현, 추가 필요"** 표기
- [HIDDEN→제외] 항목이 기존 기획서에 포함되어 있으면 **제거 또는 주석 처리**
- [ORPHAN] 항목은 향후 코드 정리(dead code removal) 대상으로 별도 기록
```

---

## 리포트 작성 시 주의사항

1. **전수 조사 원칙**: 타입/컴포넌트/필드/로직을 하나도 빠뜨리지 않는다. 누락은 기획서 갭으로 이어진다.
2. **UI 노출 위치 구체화**: "사용됨"이 아니라 "detail-page 기본정보 영역 3번째 행"처럼 구체적으로 기술한다.
3. **결정 사유 필수**: [HIDDEN] 항목의 채택/제외 결정에는 반드시 사유를 기록한다. 사유 없는 결정은 불가.
4. **연쇄 영향 표기**: 하나의 제외 결정이 다른 항목에 영향을 주면 명시한다 (예: TRANSIT_LOSS 제외 → calculateTax TRANSIT_LOSS 분기도 제외).
