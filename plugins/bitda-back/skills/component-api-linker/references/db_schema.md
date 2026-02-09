# Notion DB 스키마 (Component-API Linker)

## 컴포넌트 & 로직 DB (소스)

**DB ID**: `2d3471f8-dcff-80d2-8041-f0e98910c922`

| 속성명 | 속성 ID | 타입 | 설명 |
|--------|---------|------|------|
| 요소명(ID) | title | title | 컴포넌트/로직 이름 |
| API ID | \uoE | relation (dual) | 연결된 API 목록 (↔ API 맵핑 DB) |
| 화면 DB 연동 | zud> | relation (dual) | 연결된 화면 목록 |
| 비즈니스 로직 | usLE | rich_text | 로직 상세 설명 |
| 화면 ID | xBCs | rollup | 화면 코드 ID (자동) |

### Relation 설정

```json
{
  "API ID": {
    "type": "dual_property",
    "database_id": "2d3471f8-dcff-8017-8f2c-f3db7658c869",
    "synced_property_name": "컴포넌트 & 로직 DB",
    "synced_property_id": "jgxE"
  }
}
```

---

## API 맵핑 DB (타겟)

**DB ID**: `2d3471f8-dcff-8017-8f2c-f3db7658c869`

| 속성명 | 속성 ID | 타입 | 설명 |
|--------|---------|------|------|
| API ID | title | title | API 고유 식별자 (예: GET_USERS_BY_ADMIN) |
| Endpoint | JIgb | rich_text | API 경로 |
| Method | =gec | select | HTTP 메서드 |
| Request Spec | :CvW | rich_text | 요청 스펙 요약 |
| Response Spec | N@:I | rich_text | 응답 스펙 요약 |
| 컴포넌트 & 로직 DB | jgxE | relation (dual) | 연결된 컴포넌트 목록 |

---

## API ID 네이밍 규칙

**형식**: `{METHOD}_{RESOURCE}_{ACTION}[_BY_{ROLE}]`

| 패턴 | 예시 |
|------|------|
| 관리자 API | `GET_USERS_BY_ADMIN`, `CREATE_USER_BY_ADMIN` |
| 일반 API | `GET_USERS`, `PATCH_USER` |

---

## 비즈니스 로직 → API 매핑 키워드

| 비즈니스 로직 키워드 | API 패턴 |
|---------------------|---------|
| 목록 조회, 리스트, 검색 | `GET_*S_*` / `SEARCH_*` |
| 상세 조회, 단건 조회 | `GET_*_DETAIL_*` / `GET_*_*` |
| 생성, 등록, 추가 | `CREATE_*_*` / `REGISTER_*_*` |
| 수정, 변경, 업데이트 | `PATCH_*_*` / `UPDATE_*_*` |
| 삭제, 제거 | `DELETE_*_*` |
| 엑셀 다운로드, 내보내기 | `EXPORT_*_*` / `DOWNLOAD_*_*` |
| 엑셀 업로드, 가져오기 | `IMPORT_*_*` / `UPLOAD_*_*` |
