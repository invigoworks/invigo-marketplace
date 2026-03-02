---
name: plan-content-validator
description: Validates Notion planning document content before/after upload. Checks table structure (row merging, tag escaping, column count, compact format, header merge false negatives), code block closure, section numbering, and structural integrity. Auto-triggered by plan-developer before every Notion upload. Can also be manually invoked with "/validate-plan-content".
---

# Plan Content Validator

## Overview

Notion 기획문서 콘텐츠를 업로드 **전**(필수) 및 후(선택)에 검수하여 구조 오류를 방지하는 스킬.

> **CRITICAL**: `plan-developer`가 Notion에 콘텐츠를 업로드하기 **전에 반드시** 실행해야 합니다.

### 검수 규칙 (실행 순서)

| # | 검수 항목 | 심각도 | 자동 수정 |
|---|----------|--------|----------|
| 1 | 태그 이스케이프 (`\<table\>` 등) | CRITICAL | O |
| 2 | 컴팩트 테이블 형식 (`<tr><td>...</td></tr>` 한 줄) | CRITICAL | O |
| 3 | 테이블 행 합침 (1 `<tr>`에 다수 행) | CRITICAL | O |
| 4 | **헤더 합침** (헤더 셀 반복 패턴 / 8+ 컬럼) | CRITICAL | X |
| 5 | 코드블록 미닫힘 (` ``` ` 짝 불일치) | CRITICAL | X |
| 6 | 섹션번호 중복 (같은 `###` 번호 2회+) | ERROR | X |
| 7 | 중첩 테이블 (`<table>` in `<table>`) | ERROR | X |
| 8 | 빈 테이블 (헤더만 존재) | WARNING | X |

> **v3.0 변경**: Rule 2(컴팩트 확장)가 Rule 3(행 합침) **전에** 실행됨.
> 이유: 컴팩트 형식이 먼저 확장되어야 헤더 컬럼 수를 정확히 셀 수 있음.
> **Rule 4 추가**: 헤더도 합쳐진 false negative 사례 감지 (반복 패턴 + 비정상 컬럼 수).

---

## 트리거

| 조건 | 시점 |
|------|------|
| 자동 (plan-developer 연동) | `replace_content` / `notion-create-pages` 직전 |
| 수동 | `/validate-plan-content` + Notion Page ID 또는 파일 경로 |

---

## 검수 절차

### Phase 1: 콘텐츠 확보

| 소스 | 방법 |
|------|------|
| Notion Page ID | `notion-fetch({ id })` |
| 로컬 파일 | `Read` 도구 |
| 인라인 콘텐츠 | plan-developer가 전달한 content 문자열 |

### Phase 2: 스크립트 실행

```
1. 콘텐츠 → /tmp/plan-content-validate-input.md
2. scripts/validate-plan-tables.py → /tmp/validate-plan-tables.py 복사
3. python3 /tmp/validate-plan-tables.py
4. 결과: /tmp/plan-content-validate-report.json
5. 수정본: /tmp/plan-content-validate-fixed.md (변경 시)
```

> 스크립트: `scripts/validate-plan-tables.py` (8개 규칙, 자동 수정 3건 지원)

### Phase 3: 결과 처리

| 결과 | 처리 |
|------|------|
| **PASS** | Notion 업로드 진행 |
| **FIXED** | `/tmp/plan-content-validate-fixed.md` 콘텐츠로 업로드 |
| **FAIL** | 오류 목록 제시 → 수동 수정 후 재검수 (업로드 금지) |

---

## plan-developer 연동

```
콘텐츠 작성 완료 → 검수 (MANDATORY) → Notion 업로드 (검수 통과만)
```

| Mode | 검수 시점 |
|------|----------|
| Mode 1 (업데이트) | replace_content 전 |
| Mode 3 (신규) | notion-create-pages 전 |
| Mode 4 (변경) | replace_content_range 전 |
| Mode 5 (페이지별) | notion-create-pages 전 |

---

## Error Handling

| 상황 | 처리 |
|------|------|
| 테이블 없음 | PASS (코드블록/섹션번호만 검수) |
| Notion fetch 실패 | 에러 메시지 + 수동 검수 안내 |
| 자동 수정 완료 | 수정본으로 업로드 |
| 수동 수정 필요 | 오류 목록 + 재검수 |
