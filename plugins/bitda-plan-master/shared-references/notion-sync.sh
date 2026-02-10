#!/bin/bash
# Notion 기획문서 DB → 매니페스트 동기화 스크립트
# REST API를 사용하여 정확한 속성 기반 필터링 수행
#
# 사용법:
#   ./.claude/shared-references/notion-sync.sh          # 전체 동기화
#   ./.claude/shared-references/notion-sync.sh --diff   # 마지막 동기화 이후 변경 감지

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV_FILE="$PROJECT_DIR/.env"
MANIFEST="$SCRIPT_DIR/notion-manifest.md"
TMPDIR_SYNC=$(mktemp -d)

trap "rm -rf $TMPDIR_SYNC" EXIT

# Load .env
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env file not found" >&2; exit 1
fi
set -a; source "$ENV_FILE"; set +a

if [[ -z "${NOTION_TOKEN:-}" || -z "${NOTION_PLAN_DB_ID:-}" ]]; then
  echo "ERROR: NOTION_TOKEN or NOTION_PLAN_DB_ID not set in .env" >&2; exit 1
fi

API_BASE="https://api.notion.com/v1"
SYNC_LOCAL=$(TZ=Asia/Seoul date +"%Y-%m-%dT%H:%M:%S+09:00")

query_and_parse() {
  local status="$1"
  local outfile="$2"
  local is_review="$3"

  local result
  result=$(curl -s -X POST "$API_BASE/databases/$NOTION_PLAN_DB_ID/query" \
    -H "Authorization: Bearer $NOTION_TOKEN" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d "{\"filter\":{\"property\":\"진행 단계\",\"status\":{\"equals\":\"$status\"}},\"page_size\":100}")

  echo "$result" | python3 -c "
import json, sys

data = json.load(sys.stdin)
pages = data.get('results', [])
is_review = '$is_review' == '1'

review_map = {
    '01.대기': '대기',
    '02.의견있음': '의견있음',
    '03.의견 반영 -> 재검토 요청': '의견반영',
    '04.승인 완료': '승인완료',
}

for p in pages:
    props = p['properties']
    title = ''
    for k, v in props.items():
        if v['type'] == 'title' and v.get('title'):
            title = ''.join([t['plain_text'] for t in v['title']])
    version = props.get('버전', {}).get('number', 0) or 0
    vs = str(version)
    if '.' not in vs:
        vs += '.0'
    pid = p['id']

    if is_review:
        be = props.get('BE 검토', {}).get('select', None)
        fe = props.get('FE 검토', {}).get('select', None)
        biz = props.get('사업팀 검토', {}).get('select', None)
        be_s = review_map.get(be['name'], be['name']) if be else '대기'
        fe_s = review_map.get(fe['name'], fe['name']) if fe else '대기'
        biz_s = review_map.get(biz['name'], biz['name']) if biz else '대기'
        print(f'| {title} | \`{pid}\` | {vs} | {be_s} | {fe_s} | {biz_s} |')
    else:
        print(f'| {title} | \`{pid}\` | {vs} |')

sys.stderr.write(f'{len(pages)}')
" > "$outfile" 2>"${outfile}.count"
}

echo "Notion 기획문서 매니페스트 동기화 시작..." >&2

# --diff mode: show changes since last sync
if [[ "${1:-}" == "--diff" ]]; then
  LAST_SYNC=$(grep "최종 동기화:" "$MANIFEST" 2>/dev/null | sed 's/.*동기화: //' || echo "")
  if [[ -n "$LAST_SYNC" ]]; then
    echo "변경 감지: $LAST_SYNC 이후..." >&2
    curl -s -X POST "$API_BASE/databases/$NOTION_PLAN_DB_ID/query" \
      -H "Authorization: Bearer $NOTION_TOKEN" \
      -H "Notion-Version: 2022-06-28" \
      -H "Content-Type: application/json" \
      -d "{\"filter\":{\"timestamp\":\"last_edited_time\",\"last_edited_time\":{\"after\":\"$LAST_SYNC\"}},\"page_size\":100}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
pages = data.get('results', [])
print(f'{len(pages)}건 변경됨')
for p in pages:
    title = ''
    for k, v in p['properties'].items():
        if v['type'] == 'title' and v.get('title'):
            title = ''.join([t['plain_text'] for t in v['title']])
    status = p['properties'].get('진행 단계', {}).get('status', {}).get('name', '?')
    edited = p.get('last_edited_time', '?')
    print(f'  [{status}] {title} (edited: {edited})')
"
    echo "" >&2
  fi
  echo "전체 동기화 진행..." >&2
fi

# Query all 4 status groups
echo "  쿼리: 기획 초벌..." >&2
query_and_parse "기획 초벌" "$TMPDIR_SYNC/draft" "0"
C_DRAFT=$(cat "$TMPDIR_SYNC/draft.count")
echo "    -> ${C_DRAFT}건" >&2

echo "  쿼리: 부서 협의중..." >&2
query_and_parse "부서 협의중" "$TMPDIR_SYNC/review" "1"
C_REVIEW=$(cat "$TMPDIR_SYNC/review.count")
echo "    -> ${C_REVIEW}건" >&2

echo "  쿼리: 기획 확정..." >&2
query_and_parse "기획 확정" "$TMPDIR_SYNC/confirmed" "0"
C_CONFIRMED=$(cat "$TMPDIR_SYNC/confirmed.count")
echo "    -> ${C_CONFIRMED}건" >&2

echo "  쿼리: 기획 변경..." >&2
query_and_parse "기획 변경" "$TMPDIR_SYNC/changed" "0"
C_CHANGED=$(cat "$TMPDIR_SYNC/changed.count")
echo "    -> ${C_CHANGED}건" >&2

TOTAL=$((C_DRAFT + C_REVIEW + C_CONFIRMED + C_CHANGED))

# Generate manifest
cat > "$MANIFEST" << EOF
# Notion 기획문서 매니페스트

> 자동 생성 파일. 수동 편집 금지.
> 최종 동기화: $SYNC_LOCAL
> 동기화 방법: REST API (Status 속성 필터링, 4회 쿼리)
> DB ID: \`$NOTION_PLAN_DB_ID\`
> Data Source URL: \`collection://2df471f8-dcff-8083-8ce6-000b81ceb6f9\`
> 총 페이지: ${TOTAL}건

---

## 기획 초벌 (${C_DRAFT}건)

| 기획 명칭 | Page ID | 버전 |
|----------|---------|------|
$(cat "$TMPDIR_SYNC/draft")

---

## 부서 협의중 (${C_REVIEW}건)

| 기획 명칭 | Page ID | 버전 | BE검토 | FE검토 | 사업팀검토 |
|----------|---------|------|--------|--------|----------|
$(cat "$TMPDIR_SYNC/review")

---

## 기획 확정 (${C_CONFIRMED}건)

| 기획 명칭 | Page ID | 버전 |
|----------|---------|------|
$(cat "$TMPDIR_SYNC/confirmed")

---

## 기획 변경 (${C_CHANGED}건)

| 기획 명칭 | Page ID | 버전 |
|----------|---------|------|
$(cat "$TMPDIR_SYNC/changed")
EOF

echo "매니페스트 동기화 완료: ${TOTAL}건 ($MANIFEST)" >&2
