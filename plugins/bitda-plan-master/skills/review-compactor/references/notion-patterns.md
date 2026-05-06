# Notion API/MCP 사용 패턴 — review-compactor 검증 완료

> 2026-03-23 테스트에서 검증된 패턴. 실패한 접근법과 해결책을 기록.

## 1. 이미지 블록 처리 (핵심 난제)

### 문제
- Notion API는 블록 이동(reparent)을 지원하지 않음
- 이미지 블록의 URL은 서명된 S3 URL로 매 fetch마다 변경 → MCP 매칭 불가
- 이미지를 `external` 타입으로 재생성하면 1시간 후 URL 만료 → 이미지 깨짐

### 해결: Notion File Upload API

```python
# API Version: 2026-03-11 필수

# Step 1: 이미지 다운로드
img_data = requests.get(signed_s3_url).content

# Step 2: File Upload 객체 생성
r = requests.post('https://api.notion.com/v1/file_uploads',
    headers={'Authorization': f'Bearer {TOKEN}', 'Notion-Version': '2026-03-11',
             'Content-Type': 'application/json'},
    json={})
upload_id = r.json()['id']
upload_url = r.json()['upload_url']

# Step 3: 파일 전송 (multipart/form-data, POST)
requests.post(upload_url,
    headers={'Authorization': f'Bearer {TOKEN}', 'Notion-Version': '2026-03-11'},
    files={'file': ('image.png', img_data, 'image/png')})

# Step 4: 새 이미지 블록으로 첨부
requests.patch(f'{API}/blocks/{parent_block_id}/children',
    headers={'Authorization': f'Bearer {TOKEN}', 'Notion-Version': '2026-03-11',
             'Content-Type': 'application/json'},
    json={'children': [{
        'object': 'block', 'type': 'image',
        'image': {'type': 'file_upload', 'file_upload': {'id': upload_id}}
    }]})

# Step 5: 원본 이미지 블록 삭제
requests.delete(f'{API}/blocks/{original_img_block_id}')
```

`file_upload` 타입은 Notion 서버에 영구 저장되므로 URL 만료 없음.

### 실패한 접근법
| 접근법 | 실패 이유 |
|--------|----------|
| `type: "external"` + 서명 URL | 1시간 후 만료, 이미지 깨짐 |
| MCP `update_content`로 이미지 매칭 | URL이 매 fetch마다 변경, 매칭 불가 |
| MCP `replace_content` | 전체 페이지 교체 → 검수결과4 이미지도 삭제 |
| REST API `PATCH /blocks/{id}/children` (기존 블록 이동) | "Existing blocks cannot be moved" |

## 2. MCP 들여쓰기 패턴

### 올바른 방법: 개별 매칭
```typescript
// ✅ 각 항목을 1:1로 매칭
content_updates: [
  { old_str: "- [x] 항목A", new_str: "\t- [x] 항목A" },
  { old_str: "- [x] 항목B", new_str: "\t- [x] 항목B" }
]
```

### 실패하는 방법: multi-line 매칭
```typescript
// ✗ 자식 이미지가 사이에 있으면 매칭 실패
old_str: "- [x] 항목A\n- [x] 항목B"
// 실제 콘텐츠: "- [x] 항목A\n\t![](image)\n- [x] 항목B"
// → 자식 이미지가 끼어있어 연속 매칭 불가
```

### 중복 매칭 처리
요약 섹션에 동일 텍스트가 복사되면 "Multiple matches found" 에러 발생.
해결: 앞뒤 컨텍스트 포함하여 유니크하게 매칭.
```typescript
// 앞 블록의 마지막 줄 + 대상 블록을 함께 매칭
old_str: "앞블록텍스트\n- 중복텍스트\n- [x] 다음항목"
new_str: "앞블록텍스트\n\t- 중복텍스트\n\t- [x] 다음항목"
```

## 3. 빈 블록의 영향

빈 paragraph 블록(`<empty-block/>`)이 헤딩과 콘텐츠 사이에 있으면:
- MCP 들여쓰기 시 부모-자식 체인이 끊김
- 들여쓰기한 블록이 토글 안에 안 들어갈 수 있음

**해결**: Phase A에서 빈 블록을 먼저 삭제한 후 Phase B 들여쓰기 진행.

## 4. REST API 참고 사항

### 헤딩 토글 변환
`is_toggleable`만 보내면 에러. `rich_text`도 함께 보내야 함.
```python
# ✗ 실패
requests.patch(url, json={'heading_2': {'is_toggleable': True}})

# ✅ 성공
requests.patch(url, json={'heading_2': {
    'rich_text': [{'type':'text','text':{'content':'✅ 검수결과 — 2/2 완료'}}],
    'is_toggleable': True
}})
```

### File Upload API 버전
`/file_uploads` 엔드포인트는 `Notion-Version: 2026-03-11` 이상 필요.
`2022-06-28` 버전으로는 `invalid_request_url` 에러 발생.

### 파일 전송 방식
```
POST {upload_url}
Content-Type: multipart/form-data
Authorization: Bearer {TOKEN}
file=@image.png
```
**주의**: PUT이 아닌 **POST**, Content-Type은 **multipart/form-data**.

## 5. 원본 DB 접근

| 구분 | DB ID | 비고 |
|------|-------|------|
| 원본 DB | `2e7471f8dcff808496d7fac8b0393ed0` | REST API 쿼리 가능 |
| Linked View DB | `305471f8dcff8036b1c5feb21a60fb14` | API bot 쿼리 불가 |

Linked View DB로 쿼리하면 `Database does not contain any data sources accessible by this API bot` 에러.
반드시 원본 DB ID 사용.
