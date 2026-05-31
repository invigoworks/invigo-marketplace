# API 상세 페이지 템플릿

API 맵핑 DB 아이템의 상세 페이지에 추가할 블록 구조입니다.

## 블록 구조

### 1. 개요 섹션

```json
[
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
      "rich_text": [
        {
          "type": "text",
          "text": {"content": "{Operation.summary}"},
          "annotations": {"bold": true}
        }
      ]
    }
  },
  {
    "object": "block",
    "type": "paragraph",
    "paragraph": {
      "rich_text": [{"type": "text", "text": {"content": "{Operation.description}"}}]
    }
  },
  {
    "object": "block",
    "type": "divider",
    "divider": {}
  }
]
```

### 2. 인증 및 권한 섹션

```json
[
  {
    "object": "block",
    "type": "heading_2",
    "heading_2": {
      "rich_text": [{"type": "text", "text": {"content": "인증 및 권한"}}]
    }
  },
  {
    "object": "block",
    "type": "callout",
    "callout": {
      "rich_text": [
        {"type": "text", "text": {"content": "필요 역할: "}},
        {"type": "text", "text": {"content": "ADMIN"}, "annotations": {"code": true}}
      ],
      "icon": {"emoji": "🔐"},
      "color": "yellow_background"
    }
  },
  {
    "object": "block",
    "type": "divider",
    "divider": {}
  }
]
```

권한 없음(Public API)인 경우:
```json
{
  "object": "block",
  "type": "callout",
  "callout": {
    "rich_text": [{"type": "text", "text": {"content": "인증 불필요 (Public API)"}}],
    "icon": {"emoji": "🌐"},
    "color": "green_background"
  }
}
```

### 3. 요청 섹션

#### 3-1. Path Parameters가 있는 경우

```json
[
  {
    "object": "block",
    "type": "heading_2",
    "heading_2": {
      "rich_text": [{"type": "text", "text": {"content": "요청 (Request)"}}]
    }
  },
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {
      "rich_text": [{"type": "text", "text": {"content": "Path Parameters"}}]
    }
  },
  {
    "object": "block",
    "type": "table",
    "table": {
      "table_width": 4,
      "has_column_header": true,
      "has_row_header": false,
      "children": [
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "파라미터"}}],
              [{"type": "text", "text": {"content": "타입"}}],
              [{"type": "text", "text": {"content": "필수"}}],
              [{"type": "text", "text": {"content": "설명"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "id"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "UUID"}}],
              [{"type": "text", "text": {"content": "Yes"}}],
              [{"type": "text", "text": {"content": "사용자 ID"}}]
            ]
          }
        }
      ]
    }
  }
]
```

#### 3-2. Query Parameters가 있는 경우

```json
[
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {
      "rich_text": [{"type": "text", "text": {"content": "Query Parameters"}}]
    }
  },
  {
    "object": "block",
    "type": "table",
    "table": {
      "table_width": 4,
      "has_column_header": true,
      "has_row_header": false,
      "children": [
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "파라미터"}}],
              [{"type": "text", "text": {"content": "타입"}}],
              [{"type": "text", "text": {"content": "필수"}}],
              [{"type": "text", "text": {"content": "설명"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "page"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "Integer"}}],
              [{"type": "text", "text": {"content": "No"}}],
              [{"type": "text", "text": {"content": "페이지 번호 (기본값: 0)"}}]
            ]
          }
        }
      ]
    }
  }
]
```

#### 3-3. Request Body가 있는 경우

```json
[
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {
      "rich_text": [{"type": "text", "text": {"content": "Request Body"}}]
    }
  },
  {
    "object": "block",
    "type": "table",
    "table": {
      "table_width": 4,
      "has_column_header": true,
      "has_row_header": false,
      "children": [
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "필드"}}],
              [{"type": "text", "text": {"content": "타입"}}],
              [{"type": "text", "text": {"content": "필수"}}],
              [{"type": "text", "text": {"content": "설명"}}]
            ]
          }
        }
      ]
    }
  },
  {
    "object": "block",
    "type": "paragraph",
    "paragraph": {
      "rich_text": [
        {"type": "text", "text": {"content": "예시"}, "annotations": {"bold": true}}
      ]
    }
  },
  {
    "object": "block",
    "type": "code",
    "code": {
      "rich_text": [{"type": "text", "text": {"content": "{\n  \"email\": \"user@example.com\",\n  \"name\": \"홍길동\"\n}"}}],
      "language": "json"
    }
  }
]
```

### 4. 응답 섹션

```json
[
  {
    "object": "block",
    "type": "divider",
    "divider": {}
  },
  {
    "object": "block",
    "type": "heading_2",
    "heading_2": {
      "rich_text": [{"type": "text", "text": {"content": "응답 (Response)"}}]
    }
  },
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {
      "rich_text": [{"type": "text", "text": {"content": "성공 응답 (200 OK)"}}]
    }
  },
  {
    "object": "block",
    "type": "table",
    "table": {
      "table_width": 3,
      "has_column_header": true,
      "has_row_header": false,
      "children": [
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "필드"}}],
              [{"type": "text", "text": {"content": "타입"}}],
              [{"type": "text", "text": {"content": "설명"}}]
            ]
          }
        }
      ]
    }
  },
  {
    "object": "block",
    "type": "paragraph",
    "paragraph": {
      "rich_text": [
        {"type": "text", "text": {"content": "예시"}, "annotations": {"bold": true}}
      ]
    }
  },
  {
    "object": "block",
    "type": "code",
    "code": {
      "rich_text": [{"type": "text", "text": {"content": "{\n  \"data\": {\n    \"id\": \"550e8400-e29b-41d4-a716-446655440000\",\n    \"email\": \"user@example.com\"\n  }\n}"}}],
      "language": "json"
    }
  }
]
```

> **주의**: `"success": true`는 사용하지 않습니다. ApiResponse 래퍼에는 `data`, `error`, `message` 필드만 있습니다.

### 5. 응답 코드 섹션

```json
[
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {
      "rich_text": [{"type": "text", "text": {"content": "응답 코드"}}]
    }
  },
  {
    "object": "block",
    "type": "table",
    "table": {
      "table_width": 2,
      "has_column_header": true,
      "has_row_header": false,
      "children": [
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "코드"}}],
              [{"type": "text", "text": {"content": "설명"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "200"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "성공"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "400"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "잘못된 요청"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "401"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "인증 필요"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "403"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "권한 없음"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "404"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "리소스 없음"}}]
            ]
          }
        }
      ]
    }
  }
]
```

### 6. 에러 응답 예시 섹션

API에서 발생할 수 있는 주요 에러에 대한 응답 예시를 추가합니다.

```json
[
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {
      "rich_text": [{"type": "text", "text": {"content": "에러 응답 예시"}}]
    }
  },
  {
    "object": "block",
    "type": "paragraph",
    "paragraph": {
      "rich_text": [
        {"type": "text", "text": {"content": "404 Not Found"}, "annotations": {"bold": true}}
      ]
    }
  },
  {
    "object": "block",
    "type": "code",
    "code": {
      "rich_text": [{"type": "text", "text": {"content": "{\n  \"data\": null,\n  \"error\": \"USER_NOT_FOUND\",\n  \"message\": \"사용자를 찾을 수 없습니다\"\n}"}}],
      "language": "json"
    }
  },
  {
    "object": "block",
    "type": "paragraph",
    "paragraph": {
      "rich_text": [
        {"type": "text", "text": {"content": "403 Forbidden"}, "annotations": {"bold": true}}
      ]
    }
  },
  {
    "object": "block",
    "type": "code",
    "code": {
      "rich_text": [{"type": "text", "text": {"content": "{\n  \"data\": null,\n  \"error\": \"ACCESS_DENIED\",\n  \"message\": \"접근 권한이 없습니다\"\n}"}}],
      "language": "json"
    }
  }
]
```

> **에러 코드 작성 규칙**:
> - `error` 필드: 에러 타입을 UPPER_SNAKE_CASE로 작성 (예: `USER_NOT_FOUND`, `INVALID_REQUEST`)
> - `message` 필드: 사용자에게 표시할 한글 메시지
> - `data` 필드: 에러 시에는 보통 `null`, 일부 경우 추가 정보 포함 가능

## 완성 예시 (전체 블록 배열)

AdminUserController의 `GET /api/v1/admin/users/{id}` API 상세 페이지:

```json
[
  {
    "object": "block",
    "type": "heading_2",
    "heading_2": {"rich_text": [{"type": "text", "text": {"content": "개요"}}]}
  },
  {
    "object": "block",
    "type": "paragraph",
    "paragraph": {
      "rich_text": [
        {"type": "text", "text": {"content": "사용자 상세 조회"}, "annotations": {"bold": true}}
      ]
    }
  },
  {
    "object": "block",
    "type": "paragraph",
    "paragraph": {
      "rich_text": [{"type": "text", "text": {"content": "특정 사용자의 상세 정보를 조회합니다"}}]
    }
  },
  {
    "object": "block",
    "type": "divider",
    "divider": {}
  },
  {
    "object": "block",
    "type": "heading_2",
    "heading_2": {"rich_text": [{"type": "text", "text": {"content": "인증 및 권한"}}]}
  },
  {
    "object": "block",
    "type": "callout",
    "callout": {
      "rich_text": [
        {"type": "text", "text": {"content": "필요 역할: "}},
        {"type": "text", "text": {"content": "ADMIN"}, "annotations": {"code": true}}
      ],
      "icon": {"emoji": "🔐"},
      "color": "yellow_background"
    }
  },
  {
    "object": "block",
    "type": "divider",
    "divider": {}
  },
  {
    "object": "block",
    "type": "heading_2",
    "heading_2": {"rich_text": [{"type": "text", "text": {"content": "요청 (Request)"}}]}
  },
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {"rich_text": [{"type": "text", "text": {"content": "Path Parameters"}}]}
  },
  {
    "object": "block",
    "type": "bulleted_list_item",
    "bulleted_list_item": {
      "rich_text": [
        {"type": "text", "text": {"content": "id"}, "annotations": {"code": true}},
        {"type": "text", "text": {"content": " (UUID, 필수): 사용자 ID"}}
      ]
    }
  },
  {
    "object": "block",
    "type": "divider",
    "divider": {}
  },
  {
    "object": "block",
    "type": "heading_2",
    "heading_2": {"rich_text": [{"type": "text", "text": {"content": "응답 (Response)"}}]}
  },
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {"rich_text": [{"type": "text", "text": {"content": "성공 응답 (200 OK)"}}]}
  },
  {
    "object": "block",
    "type": "code",
    "code": {
      "rich_text": [{"type": "text", "text": {"content": "{\n  \"data\": {\n    \"id\": \"550e8400-e29b-41d4-a716-446655440000\",\n    \"code\": \"USR25010001\",\n    \"subjectId\": \"550e8400-e29b-41d4-a716-446655440000\",\n    \"email\": \"user@example.com\",\n    \"name\": \"홍길동\",\n    \"role\": {\n      \"id\": \"550e8400-e29b-41d4-a716-446655440000\",\n      \"code\": \"ROLE_ADMIN\",\n      \"name\": \"관리자\"\n    },\n    \"status\": {\n      \"value\": \"ACTIVE\",\n      \"label\": \"활성\"\n    },\n    \"lastLoginAt\": \"2024-01-15T09:30:00\",\n    \"emailVerified\": true\n  }\n}"}}],
      "language": "json"
    }
  },
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {"rich_text": [{"type": "text", "text": {"content": "응답 코드"}}]}
  },
  {
    "object": "block",
    "type": "bulleted_list_item",
    "bulleted_list_item": {
      "rich_text": [
        {"type": "text", "text": {"content": "200"}, "annotations": {"code": true}},
        {"type": "text", "text": {"content": " - 성공"}}
      ]
    }
  },
  {
    "object": "block",
    "type": "bulleted_list_item",
    "bulleted_list_item": {
      "rich_text": [
        {"type": "text", "text": {"content": "401"}, "annotations": {"code": true}},
        {"type": "text", "text": {"content": " - 인증 필요"}}
      ]
    }
  },
  {
    "object": "block",
    "type": "bulleted_list_item",
    "bulleted_list_item": {
      "rich_text": [
        {"type": "text", "text": {"content": "403"}, "annotations": {"code": true}},
        {"type": "text", "text": {"content": " - 권한 없음"}}
      ]
    }
  },
  {
    "object": "block",
    "type": "bulleted_list_item",
    "bulleted_list_item": {
      "rich_text": [
        {"type": "text", "text": {"content": "404"}, "annotations": {"code": true}},
        {"type": "text", "text": {"content": " - 사용자를 찾을 수 없음"}}
      ]
    }
  }
]
```