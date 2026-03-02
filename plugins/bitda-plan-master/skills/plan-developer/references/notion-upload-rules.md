# Notion 콘텐츠 업로드 규칙

> **이 규칙을 위반하면 테이블 깨짐, 콘텐츠 손상이 발생합니다.**

---

## 규칙 1: Notion 업로드 전 검수 필수 (MANDATORY)

> plan-content-validator를 Notion 업로드 **전에 반드시** 실행합니다. (모든 Mode 공통)

```
콘텐츠 작성 완료
    │
    ├─ Step 1: 콘텐츠를 /tmp/plan-content-validate-input.md에 저장
    ├─ Step 2: python3 /tmp/validate-plan-tables.py 실행
    │   ├─ PASS → Notion 업로드 진행
    │   ├─ FIXED → 수정된 /tmp/plan-content-validate-fixed.md 콘텐츠로 업로드
    │   └─ FAIL → 수동 수정 후 재검수 (업로드 금지)
    │
    └─ Step 3: Notion 업로드 (검수 통과 콘텐츠만)
```

---

## 규칙 2: `insert_content_after` 사용 금지 (NEVER)

> **근본 원인**: `insert_content_after`는 선택 영역이 속한 블록(예: table) **내부에** 콘텐츠를 삽입합니다.
> 테이블 마지막 행 뒤에 새 섹션을 삽입하면, 새 콘텐츠가 테이블의 추가 행으로 병합됩니다.
> 이 문제로 이전 세션에서 섹션 2.2a/2.3/2.4 테이블 병합, 섹션 7.6~7.9 테이블 병합이 발생했습니다.

```typescript
// ❌ NEVER: insert_content_after → 테이블 내부에 삽입됨
notion-update-page({
  data: {
    page_id: "xxx",
    command: "insert_content_after",
    selection_with_ellipsis: "마지막 행 내용...테이블 끝",
    new_str: "### 새 섹션\n<table>...</table>"  // → 기존 테이블에 병합됨!
  }
})

// ✅ CORRECT: replace_content_range로 기존 섹션 + 새 섹션 함께 교체
notion-update-page({
  data: {
    page_id: "xxx",
    command: "replace_content_range",
    selection_with_ellipsis: "기존 섹션 시작...기존 섹션 끝",
    new_str: "기존 섹션 내용\n---\n### 새 섹션\n<table>...</table>"
  }
})

// ✅ CORRECT: replace_content로 전체 콘텐츠 교체 (가장 안전)
notion-update-page({
  data: {
    page_id: "xxx",
    command: "replace_content",
    new_str: "전체 문서 콘텐츠"
  }
})
```

---

## 규칙 3: Notion 업데이트 전략 (권장 순서)

| 상황 | 권장 명령 | 이유 |
|------|----------|------|
| 신규 문서 생성 | `replace_content` | 전체 콘텐츠를 한번에 업로드 |
| 전체 콘텐츠 재작성 | `replace_content` | 가장 안전, 구조 깨짐 없음 |
| 특정 섹션 수정 (1~2곳) | `replace_content_range` | 부분 교체, selection 정확히 지정 |
| 다수 섹션 수정 (3곳+) | `replace_content` | 부분 교체 누적 시 오류 위험 |
| 새 섹션 추가 | `replace_content_range` | 인접 섹션까지 포함하여 교체 |
| ~~섹션 삽입~~ | ~~`insert_content_after`~~ | **사용 금지** |

---

## 규칙 4: 테이블 확장 형식 필수

> 모든 테이블은 확장 형식(각 `<td>`가 개별 줄)으로 작성해야 합니다.
> `plan-content-validator`가 자동 변환하지만, 처음부터 올바른 형식으로 작성하는 것이 좋습니다.

```html
<!-- ✅ CORRECT: 확장 형식 -->
<table header-row="true">
<tr>
<td>역할</td>
<td>조회</td>
<td>비고</td>
</tr>
<tr>
<td>ADMIN</td>
<td>✓</td>
<td>전체 권한</td>
</tr>
</table>
```

```html
<!-- ❌ WRONG: 컴팩트 형식 → Notion 파서 오류 발생 -->
<table header-row="true">
<tr><td>역할</td><td>조회</td><td>비고</td></tr>
<tr><td>ADMIN</td><td>✓</td><td>전체 권한</td></tr>
</table>
```

---

## 규칙 5: 코드블록 반드시 닫기

> ` ```gherkin ` 등으로 열린 코드블록은 반드시 ` ``` `로 닫아야 합니다.
> 닫히지 않으면 이후 `###` 헤딩이 코드블록 안에 갇혀 Notion에서 보이지 않습니다.

---

## 규칙 6: 기존 테이블 태그 규칙 (유지)

1. 각 `<tr>`은 정확히 **1개 행**의 데이터만 포함
2. 모든 `<tr>`의 `<td>` 개수는 헤더와 **동일**해야 함
3. HTML 태그에 백슬래시 이스케이프 **절대 금지** (`\<table\>` 사용 금지)
4. 테이블 태그는 코드블록 밖에 작성
5. 새 섹션 추가 시 기존 섹션 번호 재매김 확인

---

## 검수 체크리스트 (7개 규칙)

| # | 규칙 | 자동 수정 | 심각도 |
|---|------|----------|--------|
| 1 | 태그 이스케이프 없음 | ✓ | CRITICAL |
| 2 | 테이블 행-컬럼 일치 | ✓ | CRITICAL |
| 3 | 테이블 확장 형식 | ✓ | CRITICAL |
| 4 | 코드블록 열기/닫기 짝 | ✗ | CRITICAL |
| 5 | 섹션번호 중복 없음 | ✗ | ERROR |
| 6 | 중첩 테이블 없음 | ✗ | ERROR |
| 7 | 빈 테이블 없음 | ✗ | WARNING |
