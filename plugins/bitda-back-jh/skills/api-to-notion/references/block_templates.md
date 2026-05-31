# Notion Block Templates

API 상세 페이지에 추가할 Notion native block JSON 구조.
`mcp__notion__API-patch-block-children`의 `children` 파라미터로 전달.

## 1. 개요

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

## 2. 인증 및 권한

테이블 블록 (2열: 항목, 값):

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
              [{"type": "text", "text": {"content": "항목"}}],
              [{"type": "text", "text": {"content": "값"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "필요 역할"}}],
              [{"type": "text", "text": {"content": "ADMIN"}, "annotations": {"code": true}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "필요 권한"}}],
              [{"type": "text", "text": {"content": "X"}}]
            ]
          }
        }
      ]
    }
  },
  {
    "object": "block",
    "type": "divider",
    "divider": {}
  }
]
```

## 3. 요청 (Request)

### 3-1. Path Parameters

```json
[
  {
    "object": "block",
    "type": "heading_2",
    "heading_2": {
      "rich_text": [{"type": "text", "text": {"content": "요청"}}]
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
              [{"type": "text", "text": {"content": "리소스 고유 식별자"}}]
            ]
          }
        }
      ]
    }
  }
]
```

### 3-2. Header

커스텀 헤더(Idempotency-Key 등)가 있는 경우:

```json
[
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {
      "rich_text": [{"type": "text", "text": {"content": "Header"}}]
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
              [{"type": "text", "text": {"content": "Idempotency-Key"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "string (uuid)"}}],
              [{"type": "text", "text": {"content": "Yes"}}],
              [{"type": "text", "text": {"content": "멱등성 키 (UUID). 동일한 키로 재요청 시 첫 번째 응답이 리플레이됩니다."}}]
            ]
          }
        }
      ]
    }
  }
]
```

### 3-3. Query Parameters

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
              [{"type": "text", "text": {"content": "integer"}}],
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

### 3-4. Request Body

테이블 + 요청 예시 코드 블록:

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
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "name"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "string"}}],
              [{"type": "text", "text": {"content": "Yes"}}],
              [{"type": "text", "text": {"content": "창고명"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "address"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "object"}}],
              [{"type": "text", "text": {"content": "Yes"}}],
              [{"type": "text", "text": {"content": "주소 정보"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "address.city"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "string"}}],
              [{"type": "text", "text": {"content": "Yes"}}],
              [{"type": "text", "text": {"content": "도시"}}]
            ]
          }
        }
      ]
    }
  },
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {
      "rich_text": [{"type": "text", "text": {"content": "요청 예시"}}]
    }
  },
  {
    "object": "block",
    "type": "code",
    "code": {
      "rich_text": [{"type": "text", "text": {"content": "{\n  \"name\": \"메인 창고\",\n  \"address\": {\n    \"city\": \"서울\"\n  }\n}"}}],
      "language": "json"
    }
  }
]
```

## 4. 응답 (Response)

### 4-1. 성공 응답

테이블 (계층 구조 포함) + 응답 예시:

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
      "rich_text": [{"type": "text", "text": {"content": "응답"}}]
    }
  },
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {
      "rich_text": [{"type": "text", "text": {"content": "성공 응답"}}]
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
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "id"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "string (uuid)"}}],
              [{"type": "text", "text": {"content": "Yes"}}],
              [{"type": "text", "text": {"content": "고유 식별자"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "status"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "object"}}],
              [{"type": "text", "text": {"content": "Yes"}}],
              [{"type": "text", "text": {"content": "상태 정보 (LabeledEnum)"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "status.value"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "string"}}],
              [{"type": "text", "text": {"content": "Yes"}}],
              [{"type": "text", "text": {"content": "상태 코드"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "status.label"}, "annotations": {"code": true}}],
              [{"type": "text", "text": {"content": "string"}}],
              [{"type": "text", "text": {"content": "Yes"}}],
              [{"type": "text", "text": {"content": "상태 표시명"}}]
            ]
          }
        }
      ]
    }
  },
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {
      "rich_text": [{"type": "text", "text": {"content": "응답 예시"}}]
    }
  },
  {
    "object": "block",
    "type": "code",
    "code": {
      "rich_text": [{"type": "text", "text": {"content": "{\n  \"data\": {\n    \"id\": \"550e8400-e29b-41d4-a716-446655440000\",\n    \"status\": {\n      \"value\": \"ACTIVE\",\n      \"label\": \"활성\"\n    }\n  }\n}"}}],
      "language": "json"
    }
  }
]
```

### 4-2. 실패 응답

코드베이스 분석 기반으로 작성:

```json
[
  {
    "object": "block",
    "type": "heading_3",
    "heading_3": {
      "rich_text": [{"type": "text", "text": {"content": "실패 응답"}}]
    }
  },
  {
    "object": "block",
    "type": "paragraph",
    "paragraph": {
      "rich_text": [
        {"type": "text", "text": {"content": "404 - WAREHOUSE_NOT_FOUND"}, "annotations": {"bold": true}}
      ]
    }
  },
  {
    "object": "block",
    "type": "code",
    "code": {
      "rich_text": [{"type": "text", "text": {"content": "{\n  \"error\": \"WAREHOUSE_NOT_FOUND\",\n  \"message\": \"창고를 찾을 수 없습니다\"\n}"}}],
      "language": "json"
    }
  },
  {
    "object": "block",
    "type": "paragraph",
    "paragraph": {
      "rich_text": [
        {"type": "text", "text": {"content": "409 - DUPLICATE_WAREHOUSE_CODE"}, "annotations": {"bold": true}}
      ]
    }
  },
  {
    "object": "block",
    "type": "code",
    "code": {
      "rich_text": [{"type": "text", "text": {"content": "{\n  \"data\": {\n    \"code\": \"WH-001\"\n  },\n  \"error\": \"DUPLICATE_WAREHOUSE_CODE\",\n  \"message\": \"이미 존재하는 창고 코드입니다\"\n}"}}],
      "language": "json"
    }
  }
]
```

> **data 필드 규칙**: 예외 클래스에서 `ApplicationException(error, data)` 형태로 data를 전달하는 경우에만 포함. 그렇지 않으면 data 필드 생략.

## 5. 변경이력

상세 페이지 맨 하단에 추가. 신규 등록 시 `1.0 / 최초 등록` 행만 포함.

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
      "rich_text": [{"type": "text", "text": {"content": "변경이력"}}]
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
              [{"type": "text", "text": {"content": "버전"}}],
              [{"type": "text", "text": {"content": "변경내용"}}]
            ]
          }
        },
        {
          "object": "block",
          "type": "table_row",
          "table_row": {
            "cells": [
              [{"type": "text", "text": {"content": "1.0"}}],
              [{"type": "text", "text": {"content": "최초 등록"}}]
            ]
          }
        }
      ]
    }
  }
]
```
