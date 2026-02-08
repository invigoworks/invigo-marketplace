---
name: notion-validator
description: This skill validates Notion DB entries created by notion-uploader. Checks for invalid source URLs, incorrect screen code mappings, and missing component relations. Use this skill after notion-uploader completes to verify data quality. Triggers on requests like "노션 검수해줘", "업로드 검증해줘", "화면 DB 검수", "Notion 검증", "/validate-notion".
---

# Notion Validator

## Overview

This skill validates Notion database entries created by the notion-uploader skill. It performs comprehensive checks to ensure data quality and consistency:

1. **Source URL Validation**: Verify that GitHub source links are accessible
2. **Screen Code Validation**: Verify code structure matches actual project folder structure in `apps/`
3. **Component Relation Validation**: Verify all screens have linked components in the Component & Logic DB

## Prerequisites

- **Notion MCP**: Connected and authenticated
- **notion-uploader**: Previously executed with data to validate

---

## STEP 0: Notion MCP 연결 확인 (필수 선행 단계)

> **CRITICAL**: 검수 작업을 시작하기 전에 반드시 Notion MCP 연결 상태를 확인해야 합니다.

### 연결 확인 절차

1. **연결 테스트 실행**:
   ```
   notion-get-self 도구를 호출하여 현재 연결 상태 확인
   ```

2. **성공 시**: 검수 워크플로우 진행
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

### 연결 상태별 동작

| 상태 | 동작 |
|------|------|
| ✅ 연결됨 | Phase 1부터 검수 진행 |
| ❌ 연결 안됨 | 에러 메시지 표시 + 재연결 안내 |
| ⚠️ 토큰 만료 | 재인증 안내 |

---

## Reference Files

- `../../shared-references/convention-template.md`: BITDA ERP screen code conventions (shared)
- `references/code-structure-mapping.md`: 프로젝트 앱 폴더 구조와 화면코드 매핑 규칙

> **Note**: convention-template.md is a shared reference file. All skills use the same file to maintain consistency.

---

## Validation Workflow

### Phase 1: Fetch Screen Data from Notion

> **IMPORTANT**: 검수 대상은 **상태가 "기획 완료"인 화면만** 대상으로 합니다.

1. **화면 DB 조회** (기획 완료 상태만):
   - Database URL: https://www.notion.so/2d3471f8dcff802f945fc5add962fc6f
   - Data Source ID: `2d3471f8-dcff-8067-b573-000b0e2b1d04`
   - **필터 조건**: `상태 = "기획 완료"`

2. **조회할 속성**:
   - 화면명 (title)
   - 화면코드 (if available)
   - source 링크 (url)
   - 기능코드 (relation)
   - 화면유형 코드 (relation)
   - 상태 (status) - "기획 완료"만 대상

3. **검수 범위 확인**:
   - "시작 전", "기획 중", "개발 중", "개발 완료" 상태는 검수 제외
   - "기획 완료" 상태만 검수 진행
   - 검수 시작 전 대상 화면 수 확인 및 출력

### Phase 2: Source URL Validation

> 각 화면의 GitHub source 링크가 실제로 접속 가능한지 검증

#### 검증 방법

1. **URL 형식 확인**:
   - 유효한 GitHub URL 형식인지 확인
   - Expected format: `https://github.com/invigoworks/pre-publishing/blob/main/...`

2. **URL 접근성 테스트**:
   - WebFetch 도구를 사용하여 각 URL 접근 시도
   - 200 응답이 아닌 경우 오류로 기록

3. **검증 결과 기록**:
   ```markdown
   | 화면명 | Source URL | 상태 |
   |--------|-----------|------|
   | 사용자 목록 | [URL] | ✅ 접근 가능 |
   | 거래처 목록 | [URL] | ❌ 404 Not Found |
   ```

#### URL 오류 유형

| 오류 유형 | 설명 | 권장 조치 |
|----------|------|----------|
| 404 Not Found | 파일이 존재하지 않음 | 올바른 경로로 수정 |
| Invalid URL | URL 형식 오류 | URL 재확인 |
| Branch Not Found | 브랜치 없음 | main 브랜치 확인 |
| Repository Access | 저장소 접근 불가 | 권한 확인 |

### Phase 3: Screen Code Structure Validation

> 화면코드가 프로젝트의 실제 앱 폴더 구조와 일치하는지 검증

#### 화면코드 구조

```
BITDA-[도메인]-[모듈]-[기능]-[화면유형][순번]
```

#### 앱 폴더 → 화면코드 매핑 규칙

| 앱 폴더 | 도메인 코드 | 설명 |
|---------|------------|------|
| `apps/admin` | CM (Common) | 공통 관리자 |
| `apps/liquor` | BR (Brewery) | 주류 제조 |
| `apps/manufacturing` | CM (Common) | 제조업 공통 |
| `apps/tax-office` | BR (Brewery) | 주류 세무사사무소 |
| `apps/preview` | - | 프리뷰 (코드 제외) |

#### 모듈 폴더 → 모듈 코드 매핑

| 폴더 경로 | 모듈 코드 | 설명 |
|----------|----------|------|
| `settings/master-data` | MST | 기준정보 |
| `settings/system` | SYS | 시스템관리 |
| `declaration` | TAX | 주세신고 (tax-office) |
| `payment` | OFC | 세무사사무소 |
| `users` | ADM | 관리자 |
| `companies` | ADM | 관리자 |

#### 기능 폴더 → 기능 코드 매핑

| 폴더명 | 기능 코드 | 설명 |
|--------|----------|------|
| `materials` | MATR | 원재료 |
| `products` | ITEM | 제품 |
| `partners` | CUS | 거래처 |
| `warehouses` | WHS | 창고 |
| `users` | USR | 사용자 |
| `company` | COM | 회사정보 |
| `roles` | AUTH | 권한관리 |
| `dcl01` | DCL01 | 주세신고 |

#### 검증 절차

1. **Source URL에서 경로 추출**:
   ```
   URL: https://github.com/invigoworks/pre-publishing/blob/main/apps/liquor/src/settings/master-data/materials/page.tsx

   추출:
   - App: liquor → BR
   - Module: master-data → MST
   - Feature: materials → MATR
   ```

2. **기대되는 화면코드 생성**:
   ```
   BITDA-BR-MST-MATR-[화면유형][순번]
   ```

3. **실제 화면코드와 비교**:
   - 기능코드 relation이 올바른지 확인
   - 화면유형이 파일 유형과 일치하는지 확인

4. **검증 결과 기록**:
   ```markdown
   | 화면명 | 실제 경로 | 기대 코드 | 등록된 코드 | 상태 |
   |--------|----------|----------|------------|------|
   | 원재료 목록 | liquor/settings/master-data/materials | BR-MST-MATR | BR-MST-MATR | ✅ 일치 |
   | 사용자 목록 | admin/users | CM-ADM-USR | CM-SYS-USR | ⚠️ 모듈 불일치 |
   ```

### Phase 4: Component Relation Validation

> 모든 화면에 연결된 컴포넌트 & 로직이 있는지 검증

#### 검증 방법

1. **컴포넌트 & 로직 DB 조회**:
   - Data Source ID: `2d3471f8-dcff-8076-a4a3-000b502a3811`

2. **화면 DB 연동 relation 확인**:
   - 각 화면 ID에 대해 연결된 컴포넌트가 있는지 확인

3. **누락된 화면 기록**:
   ```markdown
   ## 컴포넌트 연결 누락 화면

   | 화면명 | 화면 URL | 연결된 컴포넌트 수 |
   |--------|---------|-----------------|
   | 사용자 목록 | [URL] | 0개 ❌ |
   | 거래처 목록 | [URL] | 0개 ❌ |
   ```

#### 기대되는 컴포넌트 패턴

| 화면유형 | 기대 컴포넌트 |
|---------|-------------|
| S (Screen) | `*Table.tsx` |
| F (Form) | `*Sheet.tsx` |
| P (Popup) | `*Dialog.tsx` |
| R (Report) | `*Report.tsx` |
| D (Dashboard) | `Dashboard.tsx` |
| M (Matrix) | `*Matrix.tsx` |

---

## Validation Report Output

검수 완료 후 다음 형식으로 결과 출력:

```markdown
# Notion 데이터 검수 결과

## 검수 일시
- 날짜: [YYYY-MM-DD HH:MM]
- 검수 대상: "기획 완료" 상태 화면 [N]개, 연결된 컴포넌트 [N]개
- 제외된 화면: 기타 상태 [N]개 (시작 전/기획 중/개발 중/개발 완료)

---

## 1. Source URL 검증

### 요약
- 총 화면 수: [N]개
- 정상 URL: [N]개 ✅
- 오류 URL: [N]개 ❌

### 오류 상세
| # | 화면명 | Source URL | 오류 유형 | 권장 조치 |
|---|--------|-----------|----------|----------|
| 1 | [화면명] | [URL] | 404 Not Found | 경로 수정 필요 |

---

## 2. 화면코드 구조 검증

### 요약
- 총 화면 수: [N]개
- 정상 매핑: [N]개 ✅
- 불일치: [N]개 ⚠️

### 불일치 상세
| # | 화면명 | Source 경로 | 기대 코드 | 등록된 코드 | 불일치 항목 |
|---|--------|------------|----------|------------|------------|
| 1 | [화면명] | [경로] | BR-MST-MATR | BR-SYS-MATR | 모듈 코드 |

---

## 3. 컴포넌트 연결 검증

### 요약
- 총 화면 수: [N]개
- 컴포넌트 연결됨: [N]개 ✅
- 컴포넌트 누락: [N]개 ❌

### 누락 상세
| # | 화면명 | 화면유형 | 기대 컴포넌트 | 상태 |
|---|--------|---------|--------------|------|
| 1 | [화면명] | S | *Table.tsx | ❌ 누락 |

---

## 4. 권장 조치 사항

### 즉시 수정 필요 (Critical)
1. [화면명] - Source URL 404 오류
2. [화면명] - 컴포넌트 연결 누락

### 검토 필요 (Warning)
1. [화면명] - 화면코드 모듈 불일치

---

## 5. 검수 통과 여부

| 항목 | 결과 |
|------|------|
| Source URL | ✅ PASS / ❌ FAIL |
| 화면코드 구조 | ✅ PASS / ❌ FAIL |
| 컴포넌트 연결 | ✅ PASS / ❌ FAIL |

**최종 결과**: ✅ 검수 통과 / ❌ 수정 필요
```

---

## Notion Database References

### 화면 DB
- **Data Source ID**: `2d3471f8-dcff-8067-b573-000b0e2b1d04`
- **Database URL**: https://www.notion.so/2d3471f8dcff802f945fc5add962fc6f

### 컴포넌트 & 로직 DB
- **Data Source ID**: `2d3471f8-dcff-8076-a4a3-000b502a3811`
- **Database URL**: https://www.notion.so/2d3471f8dcff80d28041f0e98910c922

### 마스터 기능코드
- **Data Source ID**: `2d3471f8-dcff-803d-8b2c-000b5b9855af`

---

## Usage Examples

**Example 1: Full Validation**
```
User: 노션에 등록된 화면들 검수해줘

Process:
1. Notion MCP 연결 확인
2. 화면 DB 전체 조회
3. Source URL 검증 (각 URL 접근성 테스트)
4. 화면코드 구조 검증 (apps 폴더 구조와 대조)
5. 컴포넌트 연결 검증 (relation 확인)
6. 검수 결과 보고서 출력

Response:
# Notion 데이터 검수 결과
...
```

**Example 2: Specific Screen Validation**
```
User: 원재료 관리 화면만 검수해줘

Process:
1. Notion MCP 연결 확인
2. "원재료" 관련 화면 검색
3. 해당 화면들만 검증 수행
4. 결과 보고서 출력
```

**Example 3: After notion-uploader**
```
User: 방금 노션에 등록한 화면들 검증해줘

Process:
1. Notion MCP 연결 확인
2. 최근 등록된 화면 조회 (created_time 기준)
3. 전체 검증 수행
4. 문제 발견 시 수정 안내
```

---

## Error Handling

| 오류 | 원인 | 해결 방법 |
|-----|------|----------|
| Notion MCP 연결 실패 | 인증 만료 또는 MCP 연결 끊김 | MCP 재연결 후 재시도 |
| 화면 DB 조회 실패 | Data Source ID 오류 | ID 재확인 |
| URL 접근 실패 | 네트워크 또는 인증 문제 | 수동으로 URL 확인 |
| 코드 매핑 실패 | 새로운 앱/모듈 폴더 | code-structure-mapping.md 업데이트 |

---

## 최종 업데이트

- 날짜: 2026-02-09
- 버전: 1.1.0
- 작성자: Claude Code
