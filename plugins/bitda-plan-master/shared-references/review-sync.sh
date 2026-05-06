#!/bin/bash
# 라이트버전 작업 트래커 DB → 검수정리 매니페스트 동기화 스크립트
# REST API를 사용하여 상위/하위 작업 분리 및 봇 검수정리 일자 추적
#
# 사용법:
#   ./.claude/shared-references/review-sync.sh          # 전체 동기화
#   ./.claude/shared-references/review-sync.sh --diff   # 마지막 동기화 이후 변경 감지

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV_FILE="$PROJECT_DIR/.env"
MANIFEST="$SCRIPT_DIR/review-manifest.md"
TMPDIR_SYNC=$(mktemp -d)

trap "rm -rf $TMPDIR_SYNC" EXIT

# Load .env
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env file not found" >&2; exit 1
fi
set -a; source "$ENV_FILE"; set +a

if [[ -z "${NOTION_TOKEN:-}" ]]; then
  echo "ERROR: NOTION_TOKEN not set in .env" >&2; exit 1
fi

# 라이트버전 작업 트래커 원본 DB ID (linked view가 아닌 원본)
# linked view (305471f8dcff8036b1c5feb21a60fb14)는 API bot으로 직접 쿼리 불가
REVIEW_DB_ID="2e7471f8dcff808496d7fac8b0393ed0"
SPRINT_PAGE_ID="305471f8-dcff-8031-a1ee-d0cbe6986035"

API_BASE="https://api.notion.com/v1"
SYNC_LOCAL=$(TZ=Asia/Seoul date +"%Y-%m-%dT%H:%M:%S+09:00")

echo "라이트버전 검수문서 매니페스트 동기화 시작..." >&2

# --diff mode
if [[ "${1:-}" == "--diff" ]]; then
  LAST_SYNC=$(grep "최종 동기화:" "$MANIFEST" 2>/dev/null | sed 's/.*동기화: //' || echo "")
  if [[ -n "$LAST_SYNC" ]]; then
    echo "변경 감지: $LAST_SYNC 이후..." >&2
    curl -s -X POST "$API_BASE/databases/$REVIEW_DB_ID/query" \
      -H "Authorization: Bearer $NOTION_TOKEN" \
      -H "Notion-Version: 2022-06-28" \
      -H "Content-Type: application/json" \
      -d "{\"filter\":{\"and\":[{\"property\":\"스프린트\",\"relation\":{\"contains\":\"$SPRINT_PAGE_ID\"}},{\"timestamp\":\"last_edited_time\",\"last_edited_time\":{\"after\":\"$LAST_SYNC\"}}]},\"page_size\":100}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
pages = data.get('results', [])
print(f'{len(pages)}건 변경됨')
for p in pages:
    title = ''
    for k, v in p['properties'].items():
        if v['type'] == 'title' and v.get('title'):
            title = ''.join([t['plain_text'] for t in v['title']])
    edited = p.get('last_edited_time', '?')
    print(f'  {title} (edited: {edited})')
"
  fi
  echo "전체 동기화 진행..." >&2
fi

# Query all pages in the sprint
echo "  쿼리: 라이트버전 스프린트 페이지..." >&2

# Paginated query
HAS_MORE=true
START_CURSOR=""
ALL_PAGES="$TMPDIR_SYNC/all_pages.json"
echo "[]" > "$ALL_PAGES"

while [[ "$HAS_MORE" == "true" ]]; do
  if [[ -n "$START_CURSOR" ]]; then
    BODY="{\"filter\":{\"property\":\"스프린트\",\"relation\":{\"contains\":\"$SPRINT_PAGE_ID\"}},\"page_size\":100,\"start_cursor\":\"$START_CURSOR\"}"
  else
    BODY="{\"filter\":{\"property\":\"스프린트\",\"relation\":{\"contains\":\"$SPRINT_PAGE_ID\"}},\"page_size\":100}"
  fi

  RESULT=$(curl -s -X POST "$API_BASE/databases/$REVIEW_DB_ID/query" \
    -H "Authorization: Bearer $NOTION_TOKEN" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d "$BODY")

  # Merge results
  python3 -c "
import json, sys
existing = json.load(open('$ALL_PAGES'))
new_data = json.loads('''$(echo "$RESULT" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('results',[])))")''')
existing.extend(new_data)
json.dump(existing, open('$ALL_PAGES', 'w'))
"

  HAS_MORE=$(echo "$RESULT" | python3 -c "import json,sys; print(str(json.load(sys.stdin).get('has_more', False)).lower())")
  if [[ "$HAS_MORE" == "true" ]]; then
    START_CURSOR=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('next_cursor', ''))")
  fi
done

# Parse into top-level and sub-tasks
python3 -c "
import json, sys

pages = json.load(open('$ALL_PAGES'))

top_level = []
sub_tasks = []

for p in pages:
    props = p['properties']
    title = ''
    for k, v in props.items():
        if v['type'] == 'title' and v.get('title'):
            title = ''.join([t['plain_text'] for t in v['title']])

    pid = p['id']

    # 분류
    category = props.get('분류', {}).get('select', None)
    cat_name = category['name'] if category else '-'

    # 봇 검수정리 일자
    bot_date_prop = props.get('봇 검수정리 일자', {}).get('date', None)
    bot_date = bot_date_prop['start'] if bot_date_prop else '-'

    # 상위 작업 relation
    parent_rel = props.get('상위 작업', {}).get('relation', [])
    has_parent = len(parent_rel) > 0

    if has_parent:
        parent_id = parent_rel[0]['id'] if parent_rel else ''
        sub_tasks.append((title, pid, parent_id))
    else:
        top_level.append((title, pid, cat_name, bot_date))

# Sort
top_level.sort(key=lambda x: (x[2], x[0]))
sub_tasks.sort(key=lambda x: x[0])

# Find parent names for sub-tasks
parent_map = {p[1]: p[0] for p in top_level}

# Output top-level
print(f'TOP_COUNT={len(top_level)}')
with open('$TMPDIR_SYNC/top_level.md', 'w') as f:
    f.write('| 작업 이름 | Page ID | 분류 | 봇 검수정리 일자 |\n')
    f.write('|----------|---------|------|------------------|\n')
    for title, pid, cat, bot_date in top_level:
        f.write(f'| {title} | \`{pid}\` | {cat} | {bot_date} |\n')

# Output sub-tasks
print(f'SUB_COUNT={len(sub_tasks)}')
with open('$TMPDIR_SYNC/sub_tasks.md', 'w') as f:
    f.write('| 작업 이름 | Page ID | 상위 작업 |\n')
    f.write('|----------|---------|----------|\n')
    for title, pid, parent_id in sub_tasks:
        parent_name = parent_map.get(parent_id, parent_id[:8])
        f.write(f'| {title} | \`{pid}\` | {parent_name} |\n')

sys.stderr.write(f'  Top-level: {len(top_level)}건, 하위: {len(sub_tasks)}건\n')
" 2>&2

# Read counts
eval $(python3 -c "
import json
pages = json.load(open('$ALL_PAGES'))
top = sum(1 for p in pages if not p['properties'].get('상위 작업', {}).get('relation', []))
sub = sum(1 for p in pages if p['properties'].get('상위 작업', {}).get('relation', []))
print(f'TOP_COUNT={top}')
print(f'SUB_COUNT={sub}')
print(f'TOTAL_COUNT={len(pages)}')
")

# Generate manifest
cat > "$MANIFEST" << HEADER
# 라이트버전 검수문서 매니페스트

> 자동 생성 파일. 수동 편집 금지.
> 최종 동기화: $SYNC_LOCAL
> DB ID: \`$REVIEW_DB_ID\`
> Data Source URL: \`collection://2e7471f8-dcff-80c0-a65b-000b6cbf845f\`
> 라이트버전 Page: \`$SPRINT_PAGE_ID\`
> 총 페이지: ${TOTAL_COUNT}건 (Top-level: ${TOP_COUNT}, 하위: ${SUB_COUNT})

---

## Top-Level 작업 (${TOP_COUNT}건)

HEADER

cat "$TMPDIR_SYNC/top_level.md" >> "$MANIFEST"

cat >> "$MANIFEST" << FOOTER

---

## 하위 작업 (탐색 제외, ${SUB_COUNT}건)

FOOTER

cat "$TMPDIR_SYNC/sub_tasks.md" >> "$MANIFEST"

echo "" >&2
echo "동기화 완료: $MANIFEST" >&2
echo "  총 ${TOTAL_COUNT}건 (Top-level: ${TOP_COUNT}, 하위: ${SUB_COUNT})" >&2
