# 검수정리 매니페스트 스키마

> 자동 생성 파일. 수동 편집 금지.
> 동기화 방법: `.claude/shared-references/review-sync.sh`

## 형식

```markdown
# 라이트버전 검수문서 매니페스트

> 자동 생성 파일. 수동 편집 금지.
> 최종 동기화: {ISO-8601 타임스탬프}
> Data Source URL: `collection://2e7471f8-dcff-80c0-a65b-000b6cbf845f`
> 총 페이지: {N}건

---

## Top-Level 작업 ({N}건)

| 작업 이름 | Page ID | 분류 | 봇 검수정리 일자 | 검수 회차 |
|----------|---------|------|----------------|----------|
| 제품관리 | `305471f8-dcff-8082-a89a-db4b2b3868ac` | 설정 | 2026-03-23 | 4 |
| 거래처 관리 | `305471f8-...` | 설정 | - | 2 |

---

## 하위 작업 (탐색 제외, {N}건)

| 작업 이름 | Page ID | 상위 작업 |
|----------|---------|----------|
| [BE] 거래처 등록 | `...` | 거래처 관리 |
| [FE] 창고 관리 | `...` | 창고 관리 |
```

## 필드 설명

### Top-Level 작업
- **작업 이름**: DB의 title 속성
- **Page ID**: Notion page UUID
- **분류**: select 속성 (설정/재고관리/주세관리/세무사 앱/문서관리)
- **봇 검수정리 일자**: 마지막 봇 정리 실행일 (`-`는 미실행)
- **검수 회차**: 페이지 내 검수결과 헤딩 수 (동기화 시점에 파악 불가하면 `?`)

### 하위 작업
- 상위 작업 relation이 있는 페이지
- 탐색 대상에서 제외됨
- 목록만 관리하여 실수로 탐색하지 않도록 방지

## Top-Level 판별 기준

"상위 작업" relation이 비어있는 페이지 = Top-Level

REST API 쿼리 시 `상위 작업` relation 속성으로 필터:
- `is_empty: true` → Top-Level
- `is_not_empty: true` → 하위 작업

## 동기화 스크립트 사용법

```bash
# 전체 동기화
./.claude/shared-references/review-sync.sh

# 마지막 동기화 이후 변경 감지
./.claude/shared-references/review-sync.sh --diff
```

환경 변수 필요:
- `NOTION_TOKEN` — Notion Integration 토큰
- `.env` 파일에 정의
