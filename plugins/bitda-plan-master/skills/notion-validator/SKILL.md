---
name: notion-validator
description: This skill validates Notion DB entries created by notion-uploader. Checks for invalid source URLs, incorrect screen code mappings, missing component relations, and business logic content quality. Use this skill after notion-uploader completes to verify data quality. Triggers on requests like "노션 검수해줘", "업로드 검증해줘", "화면 DB 검수", "Notion 검증", "/validate-notion".
---

# Notion Validator

## Overview

This skill validates Notion database entries created by the notion-uploader skill:

1. **Source URL Validation**: Verify that GitHub source links are accessible
2. **Screen Code Validation**: Verify code structure matches actual project folder structure in `apps/`
3. **Component Relation Validation**: Verify all screens have linked components in the Component & Logic DB
4. **Business Logic Content Validation**: Verify data fields use Korean names (not FE variable names)

## Prerequisites

- **Notion MCP**: Connected and authenticated
- **notion-uploader**: Previously executed with data to validate

---

## STEP 0: Notion MCP 연결 확인

`notion-get-self` 도구를 호출하여 연결 상태 확인. 실패 시 사용자에게 MCP 재연결 안내 후 중단.

---

## Reference Files

- `../../shared-references/convention-template.md`: BITDA ERP screen code conventions (shared)
- `references/code-structure-mapping.md`: 프로젝트 앱 폴더 구조와 화면코드 매핑 규칙

---

## Validation Workflow

### Phase 1: Fetch Screen Data from Notion

> **IMPORTANT**: 검수 대상은 **상태가 "기획 완료"인 화면만** 대상으로 합니다.

1. **화면 DB 조회** (기획 완료 상태만):
   - Data Source ID: `2d3471f8-dcff-8067-b573-000b0e2b1d04`
   - **필터 조건**: `상태 = "기획 완료"`

2. **조회할 속성**: 화면명, 화면코드, source 링크, 기능코드, 화면유형 코드, 상태

3. **검수 범위**: "기획 완료" 상태만 검수. 대상 화면 수 확인 후 출력.

### Phase 1.5: Empty URL Detection (CRITICAL)

> 화면의 `source 링크`가 비어있으면 후속 검증이 불가능. 빈 URL은 등록 누락이므로 즉시 오류 처리.

1. **source 링크 존재 여부 확인**: 각 화면의 `source 링크` 속성이 빈 문자열("")인지 확인
2. **빈 URL 발견 시**: ❌ Critical 오류로 기록 (등록 누락)
3. **연관 기획문서의 `퍼블리싱 결과 확인` 속성도 확인**: 빈 값이면 ⚠️ Warning

| 검증 항목 | 빈 값일 때 심각도 | 이유 |
|----------|-----------------|------|
| `source 링크` (화면 DB) | ❌ Critical | 코드 리뷰/구조 검증 불가 |
| `퍼블리싱 결과 확인` (기획문서 DB) | ⚠️ Warning | 미리보기 링크 롤업 누락 |

> **근본 원인 기록**: 병렬 에이전트 작업 시 공유 지침에서 source 링크 설정이 누락되면 전체 화면이 빈 URL로 등록됨. 이 Phase가 없으면 검수 시 "URL 접근성 정상"으로 오탐됨 (빈 값은 접근 시도 자체가 안 되므로).

### Phase 2: Source URL Validation

> 각 화면의 GitHub source 링크가 실제로 접속 가능한지 검증
> **전제**: Phase 1.5에서 빈 URL이 없음을 확인한 후 실행

1. **URL 형식 확인**: `https://github.com/invigoworks/pre-publishing/blob/main/...`
2. **URL 접근성 테스트**: WebFetch 또는 gh CLI로 접근 시도
3. **오류 유형**: 404 Not Found, Invalid URL, Branch Not Found, Repository Access, **Empty URL (Phase 1.5에서 감지)**

### Phase 3: Screen Code Structure Validation

> 화면코드가 프로젝트의 실제 앱 폴더 구조와 일치하는지 검증

#### 화면코드 구조: `BITDA-[도메인]-[모듈]-[기능]-[화면유형][순번]`

#### 매핑 규칙

| 앱 폴더 | 도메인 | 모듈 경로 | 모듈 코드 |
|---------|--------|----------|----------|
| `apps/admin` | CM | `users`, `companies` | ADM |
| `apps/liquor` | BR | `settings/master-data` | MST |
| `apps/liquor` | BR | `settings/system` | SYS |
| `apps/manufacturing` | CM | `settings/master-data` | MST |
| `apps/tax-office` | BR | `declaration` | TAX |
| `apps/tax-office` | BR | `payment` | OFC |

#### 검증 절차

1. Source URL에서 앱/모듈/기능 경로 추출
2. 매핑 규칙으로 기대 화면코드 생성
3. 실제 등록된 화면코드와 비교

### Phase 4: Component Relation Validation

> 모든 화면에 연결된 컴포넌트 & 로직이 있는지 검증

1. **컴포넌트 & 로직 DB 조회**: Data Source ID `2d3471f8-dcff-8076-a4a3-000b502a3811`
2. **화면별 relation 확인**: 연결된 컴포넌트 0개면 오류
3. **기대 패턴**:

| 화면유형 | 기대 컴포넌트 |
|---------|-------------|
| S (Screen) | `*Table.tsx` |
| F (Form) | `*Sheet.tsx` 또는 `*FormPage` |
| P (Popup) | `*Dialog.tsx` |
| R (Report) | `*Report.tsx` |
| D (Dashboard) | `Dashboard.tsx` |

### Phase 5: Business Logic Content Validation (CRITICAL)

> 컴포넌트의 비즈니스 로직 텍스트가 작성 가이드를 준수하는지 검증

#### 5.1 FE 변수명 사용 감지

**규칙**: 데이터 필드, 필터, 정렬 테이블의 "항목/파라미터" 컬럼에 FE 변수명(camelCase/snake_case) 사용 금지. 반드시 한글 서술명 사용.

**감지 패턴**:
- camelCase: 소문자로 시작하고 중간에 대문자 포함 (예: `orderNumber`, `supplierId`, `totalAmount`)
- snake_case: 언더스코어 구분 (예: `order_number`, `supplier_id`)
- 연속 영문+숫자 조합: 명백한 변수명 패턴 (예: `status`, `keyword`, `page`, `limit`)

**예외 (변수명이 아닌 것)**:
- 타입 표기: `string`, `number`, `boolean`, `enum`, `datetime`, `string(UUID)`, `string[]`
- HTTP 메서드/경로: `GET /api/v1/...`, `POST`, `PUT`, `DELETE`
- 형식 표기: `YYYY-MM-DD`, `PO-yyyyMMdd-NNN`
- 단위: `kg`, `L`, `EA`
- 영문 고유명사: `Lot`, `BOM`, `UUID`, `FK`, `soft delete`

**BAD 예시** (변수명 감지 대상):
```
| 항목 | 타입 | 필수 | 설명 |
|------|------|------|------|
| orderNumber | string | Y | 주문번호 |        ← ❌ camelCase
| supplierId | string(UUID) | Y | 입고처 |     ← ❌ camelCase
| total_amount | number | Y | 합계 |           ← ❌ snake_case
```

**GOOD 예시** (올바른 한글 서술명):
```
| 항목 | 타입 | 필수 | 설명 |
|------|------|------|------|
| 발주번호 | string | Y | 자동 채번 |         ← ✅ 한글
| 입고처 | string(UUID) | Y | 거래처 FK |      ← ✅ 한글
| 합계 금액 | number | Y | 자동 계산 |         ← ✅ 한글
```

#### 5.2 필터/정렬 파라미터 변수명 감지

필터, 정렬 테이블에서도 동일 규칙 적용:

**BAD**:
```
| 파라미터 | 타입 | 설명 |
|---------|------|------|
| warehouseId | string[] | 창고 |     ← ❌
| stockStatus | enum | 재고 상태 |    ← ❌
```

**GOOD**:
```
| 필터 항목 | 타입 | 설명 |
|----------|------|------|
| 창고 | string[] | 다중 선택 |       ← ✅
| 재고 상태 | enum | 전체/있음/없음 |  ← ✅
```

#### 5.3 검증 절차

1. 각 컴포넌트의 비즈니스 로직 텍스트를 가져옴
2. 테이블 형태의 데이터 필드 섹션 파싱
3. "항목" 또는 "파라미터" 컬럼의 각 셀에 대해:
   - camelCase 패턴 매칭: `/[a-z][A-Z]/` (소문자 뒤 대문자)
   - snake_case 패턴 매칭: `/[a-z]_[a-z]/` (언더스코어 구분)
   - 순수 영문 단어 중 타입/형식/단위가 아닌 것 (예외 목록 제외)
4. 위반 항목 기록

#### 5.4 심각도

| 위반 유형 | 심각도 | 처리 |
|----------|--------|------|
| camelCase 변수명 | ❌ Critical | 즉시 수정 필요 |
| snake_case 변수명 | ❌ Critical | 즉시 수정 필요 |
| 영문 단어 사용 (비-타입) | ⚠️ Warning | 한글 변환 권고 |

---

## Validation Report Output

```markdown
# Notion 데이터 검수 결과

## 검수 일시
- 날짜: [YYYY-MM-DD HH:MM]
- 검수 대상: "기획 완료" 상태 화면 [N]개, 연결된 컴포넌트 [N]개
- 제외된 화면: 기타 상태 [N]개

---

## 1. 빈 URL 검출 (Phase 1.5)

### 요약
- 총 화면 수: [N]개
- source 링크 있음: [N]개 ✅ / 비어있음: [N]개 ❌
- 퍼블리싱 결과 확인 있음: [N]개 ✅ / 비어있음: [N]개 ⚠️

### 빈 URL 상세 (있을 경우)
| # | 화면명 | 속성 | 심각도 | 권장 조치 |
|---|--------|------|--------|----------|

---

## 2. Source URL 검증

### 요약
- 총 화면 수: [N]개 (빈 URL 제외)
- 정상: [N]개 ✅ / 오류: [N]개 ❌

### 오류 상세 (있을 경우)
| # | 화면명 | Source URL | 오류 유형 | 권장 조치 |
|---|--------|-----------|----------|----------|

---

## 3. 화면코드 구조 검증

### 요약
- 총 화면 수: [N]개
- 정상: [N]개 ✅ / 불일치: [N]개 ⚠️

### 불일치 상세 (있을 경우)
| # | 화면명 | Source 경로 | 기대 코드 | 등록된 코드 | 불일치 항목 |
|---|--------|------------|----------|------------|------------|

---

## 4. 컴포넌트 연결 검증

### 요약
- 총 화면 수: [N]개
- 연결됨: [N]개 ✅ / 누락: [N]개 ❌

### 누락 상세 (있을 경우)
| # | 화면명 | 화면유형 | 기대 컴포넌트 | 상태 |
|---|--------|---------|--------------|------|

---

## 5. 비즈니스 로직 콘텐츠 검증

### 요약
- 총 컴포넌트 수: [N]개
- 정상: [N]개 ✅ / 위반: [N]개 ❌

### 위반 상세 (있을 경우)
| # | 컴포넌트명 | 위반 필드 | 위반 유형 | 권장 수정 |
|---|-----------|----------|----------|----------|
| 1 | [컴포넌트] | orderNumber | camelCase | → 발주번호 |
| 2 | [컴포넌트] | supplierId | camelCase | → 입고처 |

---

## 6. 권장 조치 사항

### 즉시 수정 필요 (Critical)
1. [항목] - [사유]

### 검토 필요 (Warning)
1. [항목] - [사유]

---

## 7. 검수 통과 여부

| 항목 | 결과 |
|------|------|
| 빈 URL 검출 | ✅ PASS / ❌ FAIL |
| Source URL | ✅ PASS / ❌ FAIL |
| 화면코드 구조 | ✅ PASS / ❌ FAIL |
| 컴포넌트 연결 | ✅ PASS / ❌ FAIL |
| 비즈니스 로직 콘텐츠 | ✅ PASS / ❌ FAIL |

**최종 결과**: ✅ 검수 통과 / ❌ 수정 필요
```

---

## Notion Database References

- **화면 DB**: Data Source `2d3471f8-dcff-8067-b573-000b0e2b1d04` ([URL](https://www.notion.so/2d3471f8dcff802f945fc5add962fc6f))
- **컴포넌트 & 로직 DB**: Data Source `2d3471f8-dcff-8076-a4a3-000b502a3811` ([URL](https://www.notion.so/2d3471f8dcff80d28041f0e98910c922))
- **마스터 기능코드**: Data Source `2d3471f8-dcff-803d-8b2c-000b5b9855af`

---

## Error Handling

| 오류 | 원인 | 해결 |
|-----|------|------|
| Notion MCP 연결 실패 | 인증 만료/MCP 끊김 | MCP 재연결 |
| 화면 DB 조회 실패 | Data Source ID 오류 | ID 재확인 |
| URL 접근 실패 | 네트워크/인증 | 수동 URL 확인 |
| 코드 매핑 실패 | 새 앱/모듈 폴더 | code-structure-mapping.md 업데이트 |

---

## 최종 업데이트

- 날짜: 2026-02-15
- 버전: 1.2.0
- 변경: Phase 5 비즈니스 로직 콘텐츠 검증 추가 (FE 변수명 감지)
