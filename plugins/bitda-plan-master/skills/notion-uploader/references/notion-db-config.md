# Notion Database Configuration

> 이 파일은 notion-uploader 스킬에서 사용하는 Notion 데이터베이스 설정입니다.

---

## Database IDs

### 화면 DB

| 항목 | 값 |
|-----|-----|
| Database URL | https://www.notion.so/2d3471f8dcff802f945fc5add962fc6f |
| Data Source ID | `2d3471f8-dcff-8067-b573-000b0e2b1d04` |
| Purpose | 화면 정보 등록 |

**Schema:**

| 속성 | 타입 | 설명 |
|-----|------|------|
| 화면명 | title | 화면 이름 (필수) |
| source 링크 | url | GitHub 소스 파일 링크 |
| 기능코드 | relation | 마스터 기능코드 연결 |
| 화면유형 코드 | relation | 화면유형 코드 연결 |
| 상태 | status | 시작 전/기획 중/개발 중/기획 완료/개발 완료 |

---

### 컴포넌트 & 로직 DB

| 항목 | 값 |
|-----|-----|
| Database URL | https://www.notion.so/2d3471f8dcff80d28041f0e98910c922 |
| Data Source ID | `2d3471f8-dcff-8076-a4a3-000b502a3811` |
| Purpose | 컴포넌트 및 비즈니스 로직 등록 |

**Schema:**

| 속성 | 타입 | 설명 |
|-----|------|------|
| 요소명(ID) | title | 컴포넌트 이름 (필수) |
| 비즈니스 로직 | text | 백엔드 API 개발용 상세 비즈니스 로직 |
| 화면 DB 연동 | relation | 화면 DB 연결 |

---

### 마스터 기능코드

| 항목 | 값 |
|-----|-----|
| Data Source ID | `2d3471f8-dcff-803d-8b2c-000b5b9855af` |
| Purpose | 기능코드 마스터 (참조용) |

**주요 기능코드:**

| 기능코드 | 설명 |
|---------|------|
| DASH | 대시보드 |
| COM | 회사관리 |
| USR | 사용자관리 |
| ROLE | 권한관리 |
| PERM | 권한매트릭스 |
| CPA | 세무사관리 |
| CMAP | 클라이언트매핑 |
| SRV | 서비스설정 |
| ITEM | 제품 |
| MATR | 원재료 |
| CUS | 거래처 |
| WO | 작업지시 |

---

### 화면유형 코드

| 항목 | 값 |
|-----|-----|
| Data Source ID | `2d3471f8-dcff-8051-ac76-000b25732bf2` |
| Purpose | 화면유형 코드 마스터 (참조용) |

**화면유형:**

| 코드 | 원어 | 한글 |
|------|------|------|
| D | Dashboard | 대시보드 |
| S | Screen | 일반화면 |
| F | Form | 등록/수정 |
| P | Popup | 팝업/모달 |
| R | Report | 리포트 |
| M | Matrix | 매트릭스 |

---

### 기획문서 (참조용)

| 항목 | 값 |
|-----|-----|
| URL | https://www.notion.so/invigoworks/01-2df471f8dcff80c0893becf766c394b0 |
| Purpose | 기획 초안 확인 (피드백 전 버전) |

**주의사항:**
- 기획문서는 초안 상태이므로 최종 스펙이 아님
- 퍼블리싱 코드에 피드백이 반영되어 있음
- 비즈니스 로직 작성 시 기획문서 + 퍼블리싱 코드를 모두 참조해야 함

---

## API Usage Examples

### 화면 DB 등록

```json
{
  "parent": {
    "type": "data_source_id",
    "data_source_id": "2d3471f8-dcff-8067-b573-000b0e2b1d04"
  },
  "pages": [
    {
      "properties": {
        "화면명": "[화면명]",
        "source 링크": "https://github.com/invigoworks/pre-publishing/blob/main/src/app/[path]",
        "상태": "기획 완료",
        "화면유형 코드": "[\"[화면유형URL]\"]",
        "기능코드": "[\"[기능코드URL]\"]"
      }
    }
  ]
}
```

### 컴포넌트 DB 등록

```json
{
  "parent": {
    "type": "data_source_id",
    "data_source_id": "2d3471f8-dcff-8076-a4a3-000b502a3811"
  },
  "pages": [
    {
      "properties": {
        "요소명(ID)": "[컴포넌트명]",
        "비즈니스 로직": "[상세 비즈니스 로직]",
        "화면 DB 연동": "[\"[화면URL]\"]"
      }
    }
  ]
}
```

---

## 비즈니스 로직 작성 가이드

### 목적

백엔드 개발자가 기획문서 없이도 API를 개발할 수 있도록 상세한 비즈니스 로직 제공

### 필수 포함 사항

#### 1. 데이터 필드 정의

```markdown
| 필드명 | 타입 | 필수 | 설명 |
|--------|------|------|------|
| id | string(UUID) | Y | 고유 ID (자동생성) |
| name | string | Y | 이름 (2-50자) |
| email | string | Y | 이메일 (중복 불가) |
| status | enum | Y | 상태 (active/inactive) |
```

#### 2. CRUD 동작

```markdown
### 생성 (POST /api/v1/users)
- 필수 필드: email, name, role, companyId
- 자동 생성: id, createdAt, updatedAt
- 검증: 이메일 중복 체크

### 조회 (GET /api/v1/users)
- 필터: companyId, role, status, keyword
- 정렬: createdAt desc (기본)
- 페이지네이션: page, limit

### 수정 (PUT /api/v1/users/:id)
- 수정 가능: name, role, status
- 수정 불가: email, id

### 삭제 (DELETE /api/v1/users/:id)
- Soft delete (status = 'deleted')
- 연관 데이터 확인 필요
```

#### 3. 비즈니스 규칙

```markdown
- 이메일 형식 검증 (RFC 5322)
- 권한별 접근 제어
  - admin: 전체 CRUD
  - manager: 본인 회사만
  - user: 조회만
- 상태가 'deleted'인 경우 수정 불가
```

#### 4. API 응답 예시

```markdown
### 성공 응답
{
  "success": true,
  "data": { ... }
}

### 에러 응답
{
  "success": false,
  "error": {
    "code": "DUPLICATE_EMAIL",
    "message": "이미 사용 중인 이메일입니다."
  }
}
```

---

## Workflow Sequence

1. **기획문서 확인**
   - https://www.notion.so/invigoworks/01-2df471f8dcff80c0893becf766c394b0 fetch
   - 원래 기획 의도 파악

2. **퍼블리싱 코드 분석**
   - GitHub source 링크에서 실제 구현 확인
   - 피드백 반영된 최종 스펙 추출

3. **마스터 코드 조회**
   - 화면유형 코드 URL 검색 (D, S, F, P, R, M)
   - 기능코드 URL 검색 (DASH, USR, COM 등)

4. **화면 DB 등록**
   - 화면명, source 링크, 상태 설정
   - 화면유형 코드 relation 연결
   - 기능코드 relation 연결
   - 등록된 화면 URL 수집

5. **비즈니스 로직 작성**
   - 기획문서 + 퍼블리싱 코드 기반
   - 백엔드 API 개발 가능 수준으로 상세 작성

6. **컴포넌트 DB 등록**
   - 요소명, 상세 비즈니스 로직 설정
   - 화면 DB 연동 relation 연결

---

## 최종 업데이트

- 날짜: 2025-01-07
- 변경사항:
  - Figma No. 컬럼 삭제
  - 비즈니스 로직 작성 가이드 강화
  - 기획문서 참조 워크플로우 추가
- 작성자: Claude Code
