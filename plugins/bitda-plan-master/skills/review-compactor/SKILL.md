---
name: review-compactor
description: "라이트버전 검수 문서를 자동 정리하는 스킬. 검수결과 회차별 헤딩을 토글로 변환하고, 완료된 항목은 토글을 닫아 압축하며, 미완료 항목은 마지막 회차에 모아 한눈에 볼 수 있게 정리합니다. 트리거: '/review-compact', '검수정리해줘', '검수 압축해줘', '검수결과 정리', 'compact reviews'. 검수결과가 포함된 Notion 페이지 작업 시 적극적으로 사용하세요."
---

# Review Compactor — 검수결과 자동 정리 스킬

라이트버전 작업 트래커 DB의 각 페이지에서 검수결과 회차(검수내용/검수결과N)를 순회하여,
완료된 회차는 토글로 접고, 미완료 항목을 마지막 회차에 집약하는 자동화 스킬입니다.

## 핵심 개념

검수 페이지에는 여러 회차의 검수결과가 쌓입니다:
- `## 검수내용(1차)` or `## 검수결과` → 1차
- `## 검수결과2` → 2차
- ...

시간이 지나면 이전 회차의 대부분은 해결([x])되어 있고, 일부만 미해결([ ])로 남습니다.
이 스킬은 해결 완료된 회차를 토글로 닫아 시각적으로 숨기고,
미해결 항목만 마지막 회차에 모아 "지금 해야 할 것"만 보이게 합니다.

## 사전 준비

### 매니페스트
`.claude/shared-references/review-manifest.md`에서 대상 페이지 목록을 확인합니다.
없거나 오래되었으면 동기화:

```bash
./.claude/shared-references/review-sync.sh
```

### Notion 연결
- **REST API**: `.env`의 `NOTION_TOKEN` 사용 (블록 조작, 파일 업로드)
- **Notion MCP**: 텍스트 블록 들여쓰기에 사용 (`notion-update-page` update_content)

## 실행 흐름 (2-Phase 구조)

> REST API(블록 조작)와 Notion MCP(텍스트 들여쓰기)를 조합합니다.
> 이미지 보존을 위해 Notion File Upload API를 사용합니다.

### Phase A: REST API 블록 조작

#### A-0: 대상 페이지 선별
매니페스트에서 **상위 작업이 없는 페이지**(top-level)만 대상.
사용자가 특정 페이지를 지정하면 해당 페이지만 처리.

#### A-1: 페이지 블록 파싱
REST API `GET /blocks/{page_id}/children`로 블록 목록을 조회합니다.
`heading_2` **또는 `heading_3`** 블록 중 "검수" 키워드가 포함된 것을 찾아 섹션을 분리합니다.
각 섹션은 헤딩 블록 + 다음 divider 또는 다음 검수 헤딩까지의 콘텐츠 블록으로 구성됩니다.

> **주의**: 실제 문서에서 검수결과 헤딩이 H2와 H3이 혼재합니다.
> 반드시 두 레벨 모두 탐색해야 합니다.

#### A-2: 독립 이미지 → 앞 블록 자식으로 재배치

> Notion API는 블록 이동(reparent)을 지원하지 않습니다.
> 대신 **다운로드 → File Upload API 재업로드 → 앞 블록 자식으로 첨부 → 원본 삭제**로 처리합니다.

완료 섹션(1~N-1차)에서 독립 이미지 블록(체크박스 자식이 아닌 것)을 찾아:

```python
# 1. 이미지 다운로드
img_data = requests.get(signed_url).content

# 2. Notion File Upload API로 업로드 (API Version: 2026-03-11)
r = requests.post(f'{API}/file_uploads', headers=upload_headers, json={})
upload_id = r.json()['id']
requests.post(r.json()['upload_url'], headers=send_headers,
              files={'file': ('image.png', img_data, 'image/png')})

# 3. 앞 블록(체크박스/리스트)의 자식으로 첨부
requests.patch(f'{API}/blocks/{parent_id}/children', json={
    'children': [{'type':'image','image':{'type':'file_upload','file_upload':{'id':upload_id}}}]
})

# 4. 원본 독립 이미지 삭제
requests.delete(f'{API}/blocks/{original_img_id}')
```

이렇게 하면 이미지가 `file_upload` 타입으로 영구 보존됩니다 (서명 URL 만료 문제 없음).

**중요**: 이미 체크박스의 자식인 이미지는 건드리지 않습니다 (Phase B에서 부모와 함께 이동).

#### A-3: 빈 블록 삭제
완료 섹션의 빈 paragraph 블록(`rich_text: []`)을 전부 삭제합니다.
빈 블록이 있으면 MCP 들여쓰기 시 부모-자식 체인이 끊깁니다.

#### A-4: 미해결 항목 수집
1~(N-1)차에서 미완료 체크박스(`checked: false`)와 비체크박스 리스트 항목(검수일 제외)을 수집합니다.

#### A-5: 헤딩 토글 변환
```python
requests.patch(f'{API}/blocks/{heading_id}', json={
    'heading_2': {
        'rich_text': [{'type':'text','text':{'content':'✅ 검수결과N — M/T 완료'}}],
        'is_toggleable': True
    }
})
```

#### A-6: 미해결 항목 요약 추가
페이지 맨 아래에 `📋 미해결 항목 종합` 섹션을 추가합니다.
각 항목에 출처 표기: `*(← 검수결과2)*`

#### A-7: 봇 검수정리 일자 속성 업데이트
```python
requests.patch(f'{API}/pages/{page_id}', json={
    'properties': {'봇 검수정리 일자': {'date': {'start': 'YYYY-MM-DD'}}}
})
```

### Phase B: MCP 텍스트 들여쓰기

Phase A에서 독립 이미지와 빈 블록을 제거했으므로,
완료 섹션에는 텍스트/체크박스 블록만 남아있습니다.
이 블록들을 MCP `update_content`로 탭 들여쓰기하면 토글 헤딩의 자식이 됩니다.

```typescript
notion-update-page({
  page_id: "xxx",
  command: "update_content",
  content_updates: [
    { old_str: "- [x] 항목 텍스트", new_str: "\t- [x] 항목 텍스트" },
    { old_str: "- 검수일 : 02/27",  new_str: "\t- 검수일 : 02/27" }
  ]
})
```

**핵심 규칙 — 반드시 개별 매칭:**

각 블록을 **1:1 개별 old_str/new_str**로 처리해야 합니다.
여러 항목을 한 old_str로 묶으면 중간에 자식 블록(이미지)이 있을 때 매칭이 실패합니다.

```
# ✗ 잘못 — multi-line 매칭 (자식 이미지가 끼어있으면 실패)
old_str: "- [x] 항목A\n- [x] 항목B"

# ✓ 올바름 — 개별 매칭
old_str: "- [x] 항목A"  →  new_str: "\t- [x] 항목A"
old_str: "- [x] 항목B"  →  new_str: "\t- [x] 항목B"
```

**중복 텍스트 주의:**
요약 섹션에 동일 텍스트가 복사되어 있으면 MCP가 "Multiple matches found" 에러를 반환합니다.
이 경우 앞뒤 컨텍스트를 포함하여 유니크하게 매칭합니다:
```
old_str: "앞블록텍스트\n- 중복될수있는텍스트"
new_str: "앞블록텍스트\n\t- 중복될수있는텍스트"
```

## Notion API 핵심 패턴

### REST API (블록 조작)
| 작업 | 엔드포인트 | API Version |
|------|-----------|-------------|
| 블록 목록 조회 | `GET /blocks/{id}/children` | 2022-06-28 |
| 블록 수정 | `PATCH /blocks/{id}` | 2022-06-28 |
| 자식 블록 추가 | `PATCH /blocks/{id}/children` | 2026-03-11 (file_upload) |
| 블록 삭제 | `DELETE /blocks/{id}` | 2022-06-28 |
| 파일 업로드 생성 | `POST /file_uploads` | 2026-03-11 |
| 파일 전송 | `POST {upload_url}` | 2026-03-11, multipart/form-data |
| 페이지 속성 수정 | `PATCH /pages/{id}` | 2022-06-28 |

### Notion MCP (텍스트 조작)
| 작업 | 도구 | 명령 |
|------|------|------|
| 페이지 읽기 | `notion-fetch` | `{ id: "page_id" }` |
| 텍스트 들여쓰기 | `notion-update-page` | `update_content` + `content_updates[]` |
| 속성 업데이트 | `notion-update-page` | `update_properties` |

### 절대 금지
- `WebFetch`, `Playwright`로 Notion 접근
- `replace_content` — 이미지 등 기존 블록이 삭제됨
- `notion-fetch({ page_id: "xxx" })` — `id` 파라미터만 존재
- MCP multi-line 매칭 — 자식 이미지 블록이 매칭을 끊음

## 엣지 케이스

1. **검수결과가 없는 페이지**: 스킵, "검수결과 없음" 보고
2. **검수결과가 1개인 페이지**: 토글 변환만, 이관 없음
3. **전체 완료 페이지**: 모든 회차 토글 + "전체 완료" 보고
4. **체크박스 없는 회차**: 토글 변환만, 완료 판정 불가 → 수동 확인 필요
5. **이미 처리된 페이지**: 봇 검수정리 일자 확인 후 재처리 여부 결정
6. **MCP 중복 매칭**: 요약 섹션과 원본에 같은 텍스트 → 컨텍스트 포함 매칭

## DB 정보 (하드코딩)

```
DB Name: 작업 트래커
원본 DB ID: 2e7471f8dcff808496d7fac8b0393ed0  (REST API 쿼리용)
Linked View DB: 305471f8dcff8036b1c5feb21a60fb14 (API bot 직접 쿼리 불가)
Data Source URL: collection://2e7471f8-dcff-80c0-a65b-000b6cbf845f
Parent Page (라이트버전): 305471f8-dcff-8031-a1ee-d0cbe6986035
Sprint Filter: 스프린트 relation contains 라이트버전 page ID
```

## 참고 자료

- `references/manifest-schema.md` — 매니페스트 파일 형식
- `references/notion-patterns.md` — Notion API/MCP 사용 패턴 및 시행착오
