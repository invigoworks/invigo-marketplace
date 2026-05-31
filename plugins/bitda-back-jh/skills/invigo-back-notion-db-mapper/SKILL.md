---
name: invigo-back-notion-db-mapper
description: |
  Notion DB 간 관계 매핑을 수행하는 스킬입니다.
  API 맵핑 DB에 등록된 API를 컴포넌트 & 로직 DB, 화면 DB와 연결합니다.
  이 스킬은 다음 상황에서 사용됩니다:
  - API와 프론트엔드 컴포넌트 간의 연결 관계를 설정할 때
  - API와 화면 간의 연결 관계를 설정할 때
  - 기존 매핑 관계를 조회하거나 업데이트할 때
---

# Notion DB 매핑 스킬

API 맵핑 DB와 컴포넌트/화면 DB 간의 관계를 설정하는 스킬입니다.

## DB 관계 구조

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────┐
│  API 맵핑 DB    │ ←→  │ 컴포넌트 & 로직 DB   │ ←→  │  화면 DB    │
│                 │     │                      │     │             │
│ - API ID       │     │ - 요소명(ID)         │     │ - 화면명    │
│ - Endpoint     │     │ - API ID (relation)  │     │ - 화면 코드 ID│
│ - Method       │     │ - 화면 DB 연동       │     │ - 기능코드  │
│ - 컴포넌트&로직│     │ - 비즈니스 로직      │     │ - 상태      │
│ - 화면 DB      │     │                      │     │             │
└─────────────────┘     └──────────────────────┘     └─────────────┘
```

## 사용 시점

- 사용자가 "API에 컴포넌트 연결해줘", "API와 화면 매핑해줘" 등을 요청할 때
- invigo-back-swagger-to-notion 스킬로 API 문서화 완료 후 연결 관계 설정 시
- 기존 매핑 관계를 조회하거나 변경할 때

## 필수 확인 사항

매핑 작업 전 반드시 확인:

1. **대상 API 확인**: 매핑할 API가 API 맵핑 DB에 등록되어 있어야 함
2. **대상 컴포넌트/화면 확인**: 연결할 컴포넌트 또는 화면이 해당 DB에 존재해야 함
3. **매핑 방향 확인**: API → 컴포넌트, API → 화면, 또는 양방향 매핑 여부

## 자동 매핑 규칙

### ADMIN API ↔ ADM 화면/컴포넌트 매핑

**규칙**: `_BY_ADMIN` 접미사가 있는 API는 화면 코드 ID에 `ADM`이 포함된 화면 및 컴포넌트와 연결합니다.

| API 패턴 | 화면 코드 ID 패턴 | 설명 |
|----------|------------------|------|
| `*_BY_ADMIN` | `BITDA-*-ADM-*` | 관리자 전용 API ↔ 관리자 화면 |

#### 예시

```
API: GET_USERS_BY_ADMIN
  ↓ 매핑 대상
화면 코드 ID: BITDA-USR-ADM-USER-LST001  (사용자 관리 목록 화면)
컴포넌트: AdminUserListTable, AdminUserSearchBox 등
```

#### 자동 매핑 워크플로우

1. **API 유형 판별**: API ID가 `_BY_ADMIN`으로 끝나는지 확인
2. **ADM 화면 검색**: 화면 코드 ID에 `ADM`이 포함된 화면 조회
3. **도메인 매칭**: API 도메인(USER, COMPANY 등)과 화면 도메인 코드 일치 여부 확인
4. **화면 연결**: 매칭된 화면과 API 연결 (`화면 DB` 속성)
5. **컴포넌트 연결**: 해당 화면에 연결된 컴포넌트 조회 후 API와 연결 (`컴포넌트 & 로직 DB` 속성)

#### 화면-컴포넌트 기반 자동 매핑

**규칙**: API가 화면에 연결되면, 해당 화면의 `연결된 컴포넌트 & 로직 DB`에 있는 컴포넌트들도 자동으로 API와 연결합니다.

```
API → 화면 연결 완료
  ↓
화면의 "연결된 컴포넌트 & 로직 DB" 조회
  ↓
조회된 컴포넌트들을 API의 "컴포넌트 & 로직 DB"에 연결
```

#### 컴포넌트 자동 매핑 쿼리

```python
# 1. 화면 페이지에서 연결된 컴포넌트 조회
screen_page = mcp__notion__notion_retrieve_page(
    page_id="<화면 페이지 ID>",
    format="json"
)
component_ids = screen_page["properties"]["연결된 컴포넌트 & 로직 DB"]["relation"]

# 2. API에 컴포넌트 연결
mcp__notion__notion_update_page_properties(
    page_id="<API 페이지 ID>",
    properties={
        "컴포넌트 & 로직 DB": {
            "relation": component_ids  # 화면에서 가져온 컴포넌트 목록
        }
    }
)
```

#### ADM 화면별 연결된 컴포넌트

| 화면 | 화면 ID | 연결된 컴포넌트 |
|------|---------|----------------|
| 사용자 목록 | `2e3471f8-dcff-81fe-9c22-ee880a342fdc` | UserTable |
| 역할 목록 | `2e3471f8-dcff-81a6-9bb2-daabec0b4f74` | RoleList |
| 회사 목록 | `2e3471f8-dcff-8109-b612-c345bbc825a6` | CompanyTable |
| 회사 정보 | `2e6471f8-dcff-810f-bca1-c4026206af34` | CompanySettings |
| 세무사 목록 | `2e3471f8-dcff-81d7-9e3b-e30f5eea38f7` | TaxAccountantList |
| 세무사-클라이언트 | `2e3471f8-dcff-81eb-9ce9-ebd2ea359d60` | TaxAccountantCompanyMapping |
| 관리자 대시보드 | `2e3471f8-dcff-810c-be10-edc6ad271656` | Dashboard |
| 서비스 설정 | `2e3471f8-dcff-8140-a969-de96716576d2` | ServiceSettings |
| 권한 매트릭스 | `2e3471f8-dcff-81fb-a045-da457d6a1d06` | RoleMatrix |

#### ADM 화면 검색 쿼리

```python
# 화면 코드 ID에 ADM이 포함된 화면 검색
# 화면 코드 ID는 formula 속성이므로 rollup 통해 조회하거나
# 전체 조회 후 필터링 필요

mcp__notion__notion_query_database(
    database_id="2d3471f8-dcff-802f-945f-c5add962fc6f",
    format="json"
)
# 결과에서 화면 코드 ID에 "ADM" 포함 여부로 필터링
```

#### 도메인 코드 매핑 테이블

| API 도메인 | 화면 도메인 코드 | 설명 |
|------------|-----------------|------|
| USER | USR | 사용자 관리 |
| COMPANY | CMP | 회사 관리 |
| TAX_ACCOUNTANT | TAX | 세무사 관리 |
| ROLE | ROL | 역할 관리 |
| DASHBOARD | DSH | 대시보드 |

#### 자동 매핑 예시

```
입력: GET_USERS_BY_ADMIN, GET_USER_DETAIL_BY_ADMIN, CREATE_USER_BY_ADMIN

자동 매핑 로직:
1. API 도메인 추출: USER
2. 화면 도메인 코드: USR
3. ADM 화면 검색: BITDA-USR-ADM-* 패턴
4. 매칭된 화면:
   - BITDA-USR-ADM-USER-LST001 (사용자 목록)
   - BITDA-USR-ADM-USER-DTL001 (사용자 상세)
   - BITDA-USR-ADM-USER-CRT001 (사용자 생성)
5. API-화면 연결:
   - GET_USERS_BY_ADMIN → LST (목록) 화면
   - GET_USER_DETAIL_BY_ADMIN → DTL (상세) 화면
   - CREATE_USER_BY_ADMIN → CRT (생성) 화면
```

### 비즈니스 로직 기반 API 매핑

컴포넌트의 `비즈니스 로직` 속성을 분석하여 관련 API를 자동으로 연결합니다.

#### 비즈니스 로직 분석 워크플로우

1. **컴포넌트 조회**: 컴포넌트 & 로직 DB에서 대상 컴포넌트 조회
2. **화면 ID 확인**: `화면 DB 연동` relation으로 연결된 화면 확인
3. **비즈니스 로직 분석**: `비즈니스 로직` 속성에서 API 호출 패턴 추출
4. **관련 API 매칭**: 추출된 패턴과 일치하는 API 검색
5. **연결 설정**: 컴포넌트와 API 간 relation 설정

#### 비즈니스 로직 패턴 분석

```python
# 컴포넌트의 비즈니스 로직에서 API 관련 키워드 추출
keywords_to_api = {
    "목록 조회": "GET_*S_",        # 복수형 GET
    "상세 조회": "GET_*_DETAIL_",   # 단일 상세
    "생성": "CREATE_*_",           # POST
    "수정": "PATCH_*_",            # PATCH
    "삭제": "DELETE_*_",           # DELETE
    "권한 할당": "ASSIGN_*_",      # 권한 관련
    "모듈 선택": "SELECT_*_",      # 선택 관련
}
```

#### 비즈니스 로직 분석 쿼리

```python
# 1. 컴포넌트의 비즈니스 로직과 화면 ID 조회
mcp__notion__notion_query_database(
    database_id="2d3471f8-dcff-80d2-8041-f0e98910c922",
    format="json"
)

# 2. 각 컴포넌트에서 추출할 정보:
#    - 요소명(ID): 컴포넌트 이름
#    - 화면 DB 연동: 연결된 화면 (화면 코드 ID 확인용)
#    - 비즈니스 로직: API 연동 패턴 분석용
#    - 화면 ID (rollup): 화면 코드 ID 자동 계산값
```

#### 화면 ID 기반 컴포넌트-API 매칭

컴포넌트의 `화면 ID` rollup 속성을 활용하여 해당 화면에 적합한 API를 연결합니다.

| 화면 ID 패턴 | 컴포넌트 유형 | 연결할 API 패턴 |
|-------------|--------------|----------------|
| `*-LST*` | 목록 테이블 | `GET_*S_*` (목록 조회) |
| `*-DTL*` | 상세 뷰 | `GET_*_DETAIL_*` (상세 조회) |
| `*-CRT*` | 생성 폼 | `CREATE_*_*` (생성) |
| `*-EDT*` | 수정 폼 | `PATCH_*_*` (수정) |
| `*-DEL*` | 삭제 확인 | `DELETE_*_*` (삭제) |

#### 비즈니스 로직 기반 매핑 예시

```
컴포넌트: UserTable
화면 ID: BITDA-@CM-@ADM-@USR-@S001 (사용자 목록)
비즈니스 로직: "관리자가 사용자 목록을 조회하고 필터링"

분석 결과:
- 화면 유형: LST (목록)
- 도메인: USR (사용자)
- 모듈: ADM (관리자)

연결할 API:
- GET_USERS_BY_ADMIN (목록 조회)
- GET_USER_DETAIL_BY_ADMIN (상세 조회 - 테이블 행 클릭 시)
```

#### 전체 매핑 워크플로우 (화면 + 컴포넌트)

```python
# 1. API와 화면 연결
mcp__notion__notion_update_page_properties(
    page_id="<API 페이지 ID>",
    properties={
        "화면 DB": {
            "relation": [{"id": "<화면 페이지 ID>"}]
        }
    }
)

# 2. 화면에 연결된 컴포넌트 조회 (역방향 relation 활용)
# 컴포넌트 DB에서 해당 화면과 연결된 컴포넌트 검색
components = mcp__notion__notion_query_database(
    database_id="2d3471f8-dcff-80d2-8041-f0e98910c922",
    filter={
        "property": "화면 DB 연동",
        "relation": {
            "contains": "<화면 페이지 ID>"
        }
    },
    format="json"
)

# 3. API와 컴포넌트 연결
mcp__notion__notion_update_page_properties(
    page_id="<API 페이지 ID>",
    properties={
        "컴포넌트 & 로직 DB": {
            "relation": [
                {"id": "<컴포넌트1 ID>"},
                {"id": "<컴포넌트2 ID>"}
            ]
        }
    }
)
```

## DB ID 정보

| DB 이름 | DB ID |
|---------|-------|
| API 맵핑 DB | `2d3471f8-dcff-8017-8f2c-f3db7658c869` |
| 컴포넌트 & 로직 DB | `2d3471f8-dcff-80d2-8041-f0e98910c922` |
| 화면 DB | `2d3471f8-dcff-802f-945f-c5add962fc6f` |

## 워크플로우

### 1단계: 대상 API 조회

API 맵핑 DB에서 매핑할 API를 검색합니다.

```python
# API ID로 검색
mcp__notion__notion_query_database(
    database_id="2d3471f8-dcff-8017-8f2c-f3db7658c869",
    filter={
        "property": "API ID",
        "title": {
            "equals": "GET_USERS_BY_ADMIN"
        }
    },
    format="json"
)
```

### 2단계: 연결할 컴포넌트/화면 조회

#### 컴포넌트 검색

```python
# 컴포넌트 이름으로 검색
mcp__notion__notion_query_database(
    database_id="2d3471f8-dcff-80d2-8041-f0e98910c922",
    filter={
        "property": "요소명(ID)",
        "title": {
            "contains": "UserList"
        }
    },
    format="json"
)
```

#### 화면 검색

```python
# 화면명으로 검색
mcp__notion__notion_query_database(
    database_id="2d3471f8-dcff-802f-945f-c5add962fc6f",
    filter={
        "property": "화면명",
        "title": {
            "contains": "사용자 목록"
        }
    },
    format="json"
)
```

### 3단계: 관계 설정

#### API → 컴포넌트 연결

API 맵핑 DB의 `컴포넌트 & 로직 DB` 속성을 업데이트합니다.

```python
mcp__notion__notion_update_page_properties(
    page_id="<API 페이지 ID>",
    properties={
        "컴포넌트 & 로직 DB": {
            "relation": [
                {"id": "<컴포넌트 페이지 ID>"}
            ]
        }
    }
)
```

#### API → 화면 연결

API 맵핑 DB의 `화면 DB` 속성을 업데이트합니다.

```python
mcp__notion__notion_update_page_properties(
    page_id="<API 페이지 ID>",
    properties={
        "화면 DB": {
            "relation": [
                {"id": "<화면 페이지 ID>"}
            ]
        }
    }
)
```

#### 컴포넌트 → API 연결 (역방향)

컴포넌트 & 로직 DB의 `API ID` 속성을 업데이트합니다.

```python
mcp__notion__notion_update_page_properties(
    page_id="<컴포넌트 페이지 ID>",
    properties={
        "API ID": {
            "relation": [
                {"id": "<API 페이지 ID>"}
            ]
        }
    }
)
```

## 매핑 시나리오

### 시나리오 1: 단일 API - 단일 컴포넌트 연결

```
사용자: "GET_USERS_BY_ADMIN API를 UserListTable 컴포넌트와 연결해줘"

1. API 맵핑 DB에서 GET_USERS_BY_ADMIN 검색 → page_id 획득
2. 컴포넌트 DB에서 UserListTable 검색 → page_id 획득
3. API의 "컴포넌트 & 로직 DB" 속성에 컴포넌트 relation 추가
```

### 시나리오 2: 단일 API - 다중 컴포넌트 연결

```
사용자: "CREATE_USER_BY_ADMIN API를 UserForm, UserModal 컴포넌트와 연결해줘"

1. API 검색 → page_id 획득
2. 각 컴포넌트 검색 → page_id 목록 획득
3. API의 relation에 여러 컴포넌트 ID 추가:
   {
     "relation": [
       {"id": "<UserForm ID>"},
       {"id": "<UserModal ID>"}
     ]
   }
```

### 시나리오 3: 다중 API - 단일 화면 연결

```
사용자: "사용자 관리 화면에 관련된 모든 User API를 연결해줘"

1. 화면 DB에서 "사용자 관리" 화면 검색 → page_id 획득
2. API 맵핑 DB에서 User 관련 API 목록 검색
3. 각 API의 "화면 DB" 속성에 화면 relation 추가
```

### 시나리오 4: 기존 매핑에 추가

```
사용자: "GET_USERS_BY_ADMIN에 UserSearchBox 컴포넌트도 추가해줘"

1. API 검색 → 현재 연결된 컴포넌트 목록 확인
2. 새 컴포넌트 검색 → page_id 획득
3. 기존 relation 배열에 새 ID 추가 (덮어쓰기 주의!)
   {
     "relation": [
       {"id": "<기존 컴포넌트1 ID>"},
       {"id": "<기존 컴포넌트2 ID>"},
       {"id": "<새 컴포넌트 ID>"}  // 추가
     ]
   }
```

## DB 속성 상세

### API 맵핑 DB 속성

| 속성명 | 타입 | 설명 |
|--------|------|------|
| API ID | title | API 고유 식별자 |
| Endpoint | rich_text | API 경로 |
| Method | select | HTTP 메서드 |
| Git Link | url | 소스 코드 링크 |
| Request Spec | rich_text | 요청 스펙 요약 |
| Response Spec | rich_text | 응답 스펙 요약 |
| 화면 DB | relation | 연결된 화면 목록 |
| 컴포넌트 & 로직 DB | relation | 연결된 컴포넌트 목록 |

### 컴포넌트 & 로직 DB 속성

| 속성명 | 타입 | 설명 |
|--------|------|------|
| 요소명(ID) | title | 컴포넌트/로직 이름 |
| API ID | relation | 연결된 API 목록 |
| 화면 DB 연동 | relation | 연결된 화면 목록 |
| 비즈니스 로직 | rich_text | 로직 설명 |
| 화면 ID | rollup | 화면 코드 ID (자동 계산) |
| 화면 ID 작업 상태 | rollup | 화면 작업 상태 (자동 계산) |
| source url | rollup | 소스 링크 (자동 계산) |

### 화면 DB 속성

| 속성명 | 타입 | 설명 |
|--------|------|------|
| 화면명 | title | 화면 이름 |
| 화면 코드 ID | formula | 자동 생성 코드 |
| 기능코드 | relation | 연결된 기능 |
| 화면유형 코드 | relation | 화면 유형 |
| 상태 | status | 작업 진행 상태 |
| source 링크 | url | 소스 코드 링크 |
| 연결된 컴포넌트 & 로직 DB | relation | 연결된 컴포넌트 목록 |
| 도메인 코드 | rollup | 도메인 (자동 계산) |
| 모듈 코드 | rollup | 모듈 (자동 계산) |

## 주의사항

1. **Relation 업데이트 시 기존 값 유지**: 새 항목 추가 시 기존 relation 배열을 먼저 조회하고, 기존 ID들을 포함한 전체 배열로 업데이트해야 함
2. **양방향 relation 자동 동기화**: Notion의 dual_property relation은 한쪽을 업데이트하면 반대쪽도 자동 동기화됨
3. **페이지 ID 형식**: 32자 UUID 형식 (8-4-4-4-12 하이픈 포함)
4. **대소문자 구분**: API ID 검색 시 대소문자 정확히 일치해야 함
5. **빈 relation 처리**: relation을 비우려면 빈 배열 `[]` 전달

## 참조

- `references/db_schema.md` - 전체 DB 스키마 상세
- invigo-back-swagger-to-notion 스킬 - API 문서화 후 이 스킬로 매핑 진행
- [BITDA 코드 컨벤션](https://www.notion.so/invigoworks/00-BITDA-2ce471f8dcff804abd94d6a09fa4f16b) - 화면 코드 ID, 도메인 코드 등 명명 규칙 참조
