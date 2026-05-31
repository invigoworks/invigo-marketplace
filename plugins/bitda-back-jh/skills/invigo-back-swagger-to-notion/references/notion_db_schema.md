# 노션 API 맵핑 DB 스키마

## 데이터베이스 정보

- **DB ID**: `2d3471f8-dcff-8017-8f2c-f3db7658c869`
- **DB 이름**: API 맵핑 DB
- **위치**: [04. API 맵핑 DB](https://www.notion.so/invigoworks/04-API-DB-2d3471f8dcff80c298d9d34e36431d86)

## 속성 (Properties)

### API ID (title)
- **타입**: title
- **설명**: API를 식별하는 고유 ID
- **형식**: `{METHOD}_{RESOURCE}_{ACTION}`
- **예시**: `GET_ADMIN_USERS`, `CREATE_ADMIN_USER`, `DELETE_ADMIN_COMPANY`

### Endpoint (rich_text)
- **타입**: rich_text
- **설명**: API 엔드포인트 경로
- **예시**: `/api/v1/admin/users`, `/api/v1/admin/users/{id}`

### Method (select)
- **타입**: select
- **옵션**:
  - `GET` (yellow)
  - `POST` (default)
  - `PUT` (brown)
  - `DELETE` (pink)
  - `PATCH` (gray)
  - `TRACE` (orange)
  - `CONNECT` (red)
  - `OPTIONS` (purple)
  - `HEAD` (green)

### Git Link (url)
- **타입**: url
- **설명**: 컨트롤러 소스 코드 GitHub URL
- **형식**: `https://github.com/{org}/{repo}/blob/{branch}/{path}#L{line}`

### Request Spec (rich_text)
- **타입**: rich_text
- **설명**: 요청 파라미터/바디 요약

### Response Spec (rich_text)
- **타입**: rich_text
- **설명**: 응답 데이터 구조 요약

### 화면 DB (relation)
- **타입**: relation
- **연결 DB ID**: `2d3471f8-dcff-802f-945f-c5add962fc6f`
- **설명**: 이 API를 사용하는 화면과의 연결

### 컴포넌트 & 로직 DB (relation)
- **타입**: relation (dual_property)
- **연결 DB ID**: `2d3471f8-dcff-80d2-8041-f0e98910c922`
- **양방향 속성**: API ID
- **설명**: 이 API를 호출하는 컴포넌트와의 연결

## Notion MCP 사용법

### DB 아이템 생성

```
mcp__notion__notion_create_database_item(
    database_id="2d3471f8-dcff-8017-8f2c-f3db7658c869",
    properties={
        "API ID": {
            "title": [{"text": {"content": "GET_ADMIN_USERS"}}]
        },
        "Endpoint": {
            "rich_text": [{"text": {"content": "/api/v1/admin/users"}}]
        },
        "Method": {
            "select": {"name": "GET"}
        },
        "Git Link": {
            "url": "https://github.com/org/repo/blob/main/path/Controller.kt#L50"
        },
        "Request Spec": {
            "rich_text": [{"text": {"content": "page, size, sort, email?, name?"}}]
        },
        "Response Spec": {
            "rich_text": [{"text": {"content": "PageResponse<UserListResponse>"}}]
        }
    }
)
```

### 기존 아이템 검색 (중복 확인)

```
mcp__notion__notion_query_database(
    database_id="2d3471f8-dcff-8017-8f2c-f3db7658c869",
    filter={
        "property": "API ID",
        "title": {
            "equals": "GET_ADMIN_USERS"
        }
    }
)
```

### 아이템 업데이트

```
mcp__notion__notion_update_page_properties(
    page_id="{page_id}",
    properties={
        "Endpoint": {
            "rich_text": [{"text": {"content": "/api/v2/admin/users"}}]
        }
    }
)
```

### 상세 페이지에 블록 추가

```
mcp__notion__notion_append_block_children(
    block_id="{page_id}",
    children=[
        {
            "object": "block",
            "type": "heading_2",
            "heading_2": {
                "rich_text": [{"type": "text", "text": {"content": "개요"}}]
            }
        },
        {
            "object": "block",
            "type": "paragraph",
            "paragraph": {
                "rich_text": [{"type": "text", "text": {"content": "API 설명..."}}]
            }
        }
    ]
)
```