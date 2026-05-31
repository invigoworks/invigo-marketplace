# Notion DB 스키마 상세

## API 맵핑 DB

**DB ID**: `2d3471f8-dcff-8017-8f2c-f3db7658c869`

### 속성

| 속성명 | 속성 ID | 타입 | 상세 |
|--------|---------|------|------|
| API ID | title | title | API 고유 식별자 (예: GET_USERS_BY_ADMIN) |
| Endpoint | JIgb | rich_text | API 경로 (예: /api/v1/admin/users) |
| Method | =gec | select | HTTP 메서드 옵션: GET, POST, PUT, DELETE, PATCH, TRACE, CONNECT, OPTIONS, HEAD |
| Git Link | SHet | url | GitHub 소스 코드 링크 |
| Request Spec | :CvW | rich_text | 요청 스펙 요약 |
| Response Spec | N@:I | rich_text | 응답 스펙 요약 |
| 화면 DB | Qajd | relation | 연결된 화면 목록 (→ 화면 DB) |
| 컴포넌트 & 로직 DB | jgxE | relation (dual) | 연결된 컴포넌트 목록 (↔ 컴포넌트 & 로직 DB.API ID) |

### Relation 설정

```json
{
  "화면 DB": {
    "type": "single_property",
    "database_id": "2d3471f8-dcff-802f-945f-c5add962fc6f"
  },
  "컴포넌트 & 로직 DB": {
    "type": "dual_property",
    "database_id": "2d3471f8-dcff-80d2-8041-f0e98910c922",
    "synced_property_name": "API ID",
    "synced_property_id": "\\uoE"
  }
}
```

---

## 컴포넌트 & 로직 DB

**DB ID**: `2d3471f8-dcff-80d2-8041-f0e98910c922`

### 속성

| 속성명 | 속성 ID | 타입 | 상세 |
|--------|---------|------|------|
| 요소명(ID) | title | title | 컴포넌트 또는 로직 이름 |
| API ID | \\uoE | relation (dual) | 연결된 API 목록 (↔ API 맵핑 DB.컴포넌트 & 로직 DB) |
| 화면 DB 연동 | zud> | relation (dual) | 연결된 화면 목록 (↔ 화면 DB.연결된 컴포넌트 & 로직 DB) |
| 비즈니스 로직 | usLE | rich_text | 로직 상세 설명 |
| 화면 ID | xBCs | rollup | 연결된 화면의 코드 ID (자동) |
| 화면 ID 작업 상태 | pS?O | rollup | 연결된 화면의 작업 상태 (자동) |
| source url | i`Ed | rollup | 연결된 화면의 소스 링크 (자동) |

### Relation 설정

```json
{
  "API ID": {
    "type": "dual_property",
    "database_id": "2d3471f8-dcff-8017-8f2c-f3db7658c869",
    "synced_property_name": "컴포넌트 & 로직 DB",
    "synced_property_id": "jgxE"
  },
  "화면 DB 연동": {
    "type": "dual_property",
    "database_id": "2d3471f8-dcff-802f-945f-c5add962fc6f",
    "synced_property_name": "연결된 컴포넌트 & 로직 DB",
    "synced_property_id": "i;aa"
  }
}
```

---

## 화면 DB

**DB ID**: `2d3471f8-dcff-802f-945f-c5add962fc6f`

### 속성

| 속성명 | 속성 ID | 타입 | 상세 |
|--------|---------|------|------|
| 화면명 | title | title | 화면 이름 |
| 화면 코드 ID | yzic | formula | 자동 생성 코드 (BITDA-도메인-모듈-기능-유형NNN) |
| 기능코드 | ca`p | relation (dual) | 연결된 기능 (→ 기능코드 DB) |
| 화면유형 코드 | pllg | relation | 화면 유형 선택 |
| 상태 | vPbs | status | 시작 전, 기획 중, 개발 중, 기획 완료, 개발 완료 |
| source 링크 | M]QO | url | 소스 코드 링크 |
| 연결된 컴포넌트 & 로직 DB | i;aa | relation (dual) | 연결된 컴포넌트 목록 (↔ 컴포넌트 & 로직 DB.화면 DB 연동) |
| 도메인 코드 | ncO~ | rollup | 기능코드에서 추출한 도메인 (자동) |
| 모듈 코드 | BrI` | rollup | 기능코드에서 추출한 모듈 (자동) |

### 상태 옵션

| 상태 | 색상 | 그룹 |
|------|------|------|
| 시작 전 | default | To-do |
| 기획 중 | blue | In progress |
| 개발 중 | orange | In progress |
| 기획 완료 | green | Complete |
| 개발 완료 | purple | Complete |

---

## 관계 다이어그램

```
                    ┌─────────────────────┐
                    │    기능코드 DB      │
                    │ (2d3471f8-dcff-    │
                    │  80cd-9de7-...)    │
                    └─────────┬───────────┘
                              │ 기능코드
                              ↓
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  API 맵핑 DB    │     │    화면 DB      │     │ 화면유형 코드 DB │
│                 │     │                 │     │                 │
│ 컴포넌트&로직 DB├────→│ 연결된 컴포넌트 │←────┤ 화면유형 코드   │
│ 화면 DB        ├────→│ & 로직 DB       │     │                 │
└────────┬────────┘     └────────┬────────┘     └─────────────────┘
         │                       │
         │                       │
         │  ┌────────────────────┘
         │  │
         ↓  ↓
┌─────────────────────┐
│ 컴포넌트 & 로직 DB  │
│                     │
│ API ID (relation)   │←───── 양방향 동기화
│ 화면 DB 연동        │←───── 양방향 동기화
└─────────────────────┘
```

---

## 쿼리 예시

### API 검색 (API ID로)

```python
mcp__notion__notion_query_database(
    database_id="2d3471f8-dcff-8017-8f2c-f3db7658c869",
    filter={
        "property": "API ID",
        "title": {"equals": "GET_USERS_BY_ADMIN"}
    }
)
```

### API 검색 (Endpoint로)

```python
mcp__notion__notion_query_database(
    database_id="2d3471f8-dcff-8017-8f2c-f3db7658c869",
    filter={
        "property": "Endpoint",
        "rich_text": {"contains": "/admin/users"}
    }
)
```

### 컴포넌트 검색

```python
mcp__notion__notion_query_database(
    database_id="2d3471f8-dcff-80d2-8041-f0e98910c922",
    filter={
        "property": "요소명(ID)",
        "title": {"contains": "UserList"}
    }
)
```

### 화면 검색 (상태별)

```python
mcp__notion__notion_query_database(
    database_id="2d3471f8-dcff-802f-945f-c5add962fc6f",
    filter={
        "property": "상태",
        "status": {"equals": "개발 중"}
    }
)
```

### Relation 업데이트

```python
# API에 컴포넌트 연결
mcp__notion__notion_update_page_properties(
    page_id="<API 페이지 ID>",
    properties={
        "컴포넌트 & 로직 DB": {
            "relation": [
                {"id": "<컴포넌트1 페이지 ID>"},
                {"id": "<컴포넌트2 페이지 ID>"}
            ]
        }
    }
)

# API에 화면 연결
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
