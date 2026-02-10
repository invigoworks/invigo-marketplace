#!/bin/bash
# 마스터 기능코드 동기화 스크립트
# convention-template.md ↔ Notion 마스터 기능코드 DB 동기화
#
# 사용법:
#   .claude/shared-references/sync-feature-codes.sh --check      # 불일치 감지 (dry-run)
#   .claude/shared-references/sync-feature-codes.sh --register   # convention → Notion 등록
#   .claude/shared-references/sync-feature-codes.sh --sync       # Notion → convention 동기화

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV_FILE="$PROJECT_DIR/.env"
CONVENTION="$PROJECT_DIR/.claude/shared-references/convention-template.md"
TMPDIR_FC=$(mktemp -d)

trap "rm -rf $TMPDIR_FC" EXIT

# Load .env
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env file not found" >&2; exit 1
fi
set -a; source "$ENV_FILE"; set +a

if [[ -z "${NOTION_TOKEN:-}" ]]; then
  echo "ERROR: NOTION_TOKEN not set in .env" >&2; exit 1
fi
if [[ -z "${NOTION_FEATURE_CODE_DB_ID:-}" ]]; then
  echo "ERROR: NOTION_FEATURE_CODE_DB_ID not set in .env" >&2; exit 1
fi

API_BASE="https://api.notion.com/v1"

# ── 도메인/모듈 Relation 캐시 ──

fetch_domain_map() {
  # 도메인 DB 조회 → {코드: URL} 맵 생성
  local DOMAIN_DB_ID="8d28416a-a225-4a5f-9c27-858a52fc49f3"
  curl -s -X POST "$API_BASE/databases/$DOMAIN_DB_ID/query" \
    -H "Authorization: Bearer $NOTION_TOKEN" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d '{"page_size":100}' | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data.get('results', []):
    title = ''
    for k, v in p['properties'].items():
        if v['type'] == 'title' and v.get('title'):
            title = ''.join([t['plain_text'] for t in v['title']])
    if title:
        print(f'{title}\thttps://www.notion.so/{p[\"id\"].replace(\"-\", \"\")}')
" > "$TMPDIR_FC/domain_map.tsv"
}

fetch_module_map() {
  # 모듈 코드 DB 조회 → {코드: URL} 맵 생성
  local MODULE_DB_ID="d31e2668-a372-4603-990a-536cae9966f7"
  curl -s -X POST "$API_BASE/databases/$MODULE_DB_ID/query" \
    -H "Authorization: Bearer $NOTION_TOKEN" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d '{"page_size":100}' | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data.get('results', []):
    title = ''
    for k, v in p['properties'].items():
        if v['type'] == 'title' and v.get('title'):
            title = ''.join([t['plain_text'] for t in v['title']])
    if title:
        print(f'{title}\thttps://www.notion.so/{p[\"id\"].replace(\"-\", \"\")}')
" > "$TMPDIR_FC/module_map.tsv"
}

# ── convention-template.md 파싱 ──

parse_convention() {
  # convention-template.md에서 기능코드 추출
  # 출력: 모듈코드\t기능코드\t원어\t한글\t도메인
  python3 -c "
import re, sys

with open('$CONVENTION', 'r') as f:
    content = f.read()

# 기능 코드 섹션 추출
sections = re.findall(
    r'### (\w+) \(.*?\) - (\w+)\s*\n\s*\|.*?\n\s*\|.*?\n((?:\s*\|.*?\n)*)',
    content
)

for module_code, domain_code, table_body in sections:
    rows = re.findall(r'\|\s*(\w+)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|', table_body)
    for func_code, eng, kor in rows:
        # 설명 컬럼이 있는 경우 (4컬럼 테이블) 건너뛰기
        kor = kor.strip()
        if kor and func_code != '코드':
            print(f'{module_code}\t{func_code}\t{eng}\t{kor}\t{domain_code}')
" > "$TMPDIR_FC/convention_codes.tsv"
}

# ── Notion DB 조회 ──

fetch_notion_codes() {
  # 기본: 기능코드, 원어, 한글만 (--check용)
  curl -s -X POST "$API_BASE/databases/$NOTION_FEATURE_CODE_DB_ID/query" \
    -H "Authorization: Bearer $NOTION_TOKEN" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d '{"page_size":100}' | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data.get('results', []):
    props = p['properties']
    func_code = ''
    for k, v in props.items():
        if v['type'] == 'title' and v.get('title'):
            func_code = ''.join([t['plain_text'] for t in v['title']])

    eng = ''
    eng_prop = props.get('원어', {})
    if eng_prop.get('type') == 'rich_text' and eng_prop.get('rich_text'):
        eng = ''.join([t['plain_text'] for t in eng_prop['rich_text']])

    kor = ''
    kor_prop = props.get('한글', {})
    if kor_prop.get('type') == 'rich_text' and kor_prop.get('rich_text'):
        kor = ''.join([t['plain_text'] for t in kor_prop['rich_text']])

    if func_code:
        print(f'{func_code}\t{eng}\t{kor}')
" > "$TMPDIR_FC/notion_codes.tsv"
}

fetch_notion_codes_full() {
  # 전체: 기능코드, 원어, 한글 + 도메인/모듈 relation ID (--sync용)
  curl -s -X POST "$API_BASE/databases/$NOTION_FEATURE_CODE_DB_ID/query" \
    -H "Authorization: Bearer $NOTION_TOKEN" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d '{"page_size":100}' > "$TMPDIR_FC/notion_raw.json"
}

# ── 도메인/모듈 ID→코드 역방향 맵 ──

fetch_domain_id_map() {
  local DOMAIN_DB_ID="8d28416a-a225-4a5f-9c27-858a52fc49f3"
  curl -s -X POST "$API_BASE/databases/$DOMAIN_DB_ID/query" \
    -H "Authorization: Bearer $NOTION_TOKEN" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d '{"page_size":100}' | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data.get('results', []):
    title = ''
    for k, v in p['properties'].items():
        if v['type'] == 'title' and v.get('title'):
            title = ''.join([t['plain_text'] for t in v['title']])
    if title:
        pid = p['id']
        pid_nodash = pid.replace('-', '')
        print(f'{pid}\t{title}')
        print(f'{pid_nodash}\t{title}')
" > "$TMPDIR_FC/domain_id_map.tsv"
}

fetch_module_id_map() {
  local MODULE_DB_ID="d31e2668-a372-4603-990a-536cae9966f7"
  curl -s -X POST "$API_BASE/databases/$MODULE_DB_ID/query" \
    -H "Authorization: Bearer $NOTION_TOKEN" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d '{"page_size":100}' | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data.get('results', []):
    title = ''
    for k, v in p['properties'].items():
        if v['type'] == 'title' and v.get('title'):
            title = ''.join([t['plain_text'] for t in v['title']])
    if title:
        pid = p['id']
        pid_nodash = pid.replace('-', '')
        print(f'{pid}\t{title}')
        print(f'{pid_nodash}\t{title}')
" > "$TMPDIR_FC/module_id_map.tsv"
}

# ── --check: 불일치 감지 ──

do_check() {
  echo "기능코드 동기화 상태 확인 중..." >&2

  parse_convention
  fetch_notion_codes

  python3 -c "
import sys

# convention에서 기능코드 읽기
conv = {}
with open('$TMPDIR_FC/convention_codes.tsv') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) >= 5:
            module, func, eng, kor, domain = parts
            conv[func] = {'module': module, 'eng': eng, 'kor': kor, 'domain': domain}

# Notion에서 기능코드 읽기
notion = set()
with open('$TMPDIR_FC/notion_codes.tsv') as f:
    for line in f:
        parts = line.strip().split('\t')
        if parts:
            notion.add(parts[0])

# 차이 분석
only_conv = [k for k in conv if k not in notion]
only_notion = [k for k in notion if k not in conv]

if not only_conv and not only_notion:
    print('✅ 동기화 완료 — 불일치 없음')
    print(f'   convention: {len(conv)}개, Notion: {len(notion)}개')
else:
    if only_conv:
        print(f'⚠️  convention에만 있는 코드 ({len(only_conv)}건):')
        for k in only_conv:
            info = conv[k]
            print(f'   {info[\"module\"]}-{k} ({info[\"eng\"]} / {info[\"kor\"]})')
    if only_notion:
        print(f'⚠️  Notion에만 있는 코드 ({len(only_notion)}건):')
        for k in only_notion:
            print(f'   {k}')
    print()
    print(f'총: convention {len(conv)}개 / Notion {len(notion)}개')
    sys.exit(1)
"
}

# ── --register: convention → Notion 등록 ──

do_register() {
  echo "convention → Notion 등록 시작..." >&2

  parse_convention
  fetch_notion_codes
  fetch_domain_map
  fetch_module_map

  python3 << 'PYEOF'
import json, sys, subprocess, os

TMPDIR = os.environ.get('TMPDIR_FC', '/tmp')
API_BASE = os.environ.get('API_BASE', 'https://api.notion.com/v1')
TOKEN = os.environ.get('NOTION_TOKEN', '')
DB_ID = os.environ.get('NOTION_FEATURE_CODE_DB_ID', '')

# convention 기능코드 읽기
conv = {}
with open(f'{TMPDIR}/convention_codes.tsv') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) >= 5:
            module, func, eng, kor, domain = parts
            conv[func] = {'module': module, 'eng': eng, 'kor': kor, 'domain': domain}

# Notion 기능코드 읽기
notion = set()
with open(f'{TMPDIR}/notion_codes.tsv') as f:
    for line in f:
        parts = line.strip().split('\t')
        if parts:
            notion.add(parts[0])

# 도메인 맵 읽기
domain_map = {}
with open(f'{TMPDIR}/domain_map.tsv') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) == 2:
            domain_map[parts[0]] = parts[1]

# 모듈 맵 읽기
module_map = {}
with open(f'{TMPDIR}/module_map.tsv') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) == 2:
            module_map[parts[0]] = parts[1]

# 누락 코드 등록
missing = [k for k in conv if k not in notion]
if not missing:
    print('등록할 누락 코드 없음')
    sys.exit(0)

for func_code in missing:
    info = conv[func_code]
    domain_url = domain_map.get(info['domain'], '')
    module_url = module_map.get(info['module'], '')

    if not domain_url:
        print(f'⚠️  도메인 {info["domain"]} URL을 찾을 수 없음 — {func_code} 건너뜀', file=sys.stderr)
        continue
    if not module_url:
        print(f'⚠️  모듈 {info["module"]} URL을 찾을 수 없음 — {func_code} 건너뜀', file=sys.stderr)
        continue

    payload = {
        "parent": {"database_id": DB_ID},
        "properties": {
            "기능 코드": {"title": [{"text": {"content": func_code}}]},
            "원어": {"rich_text": [{"text": {"content": info['eng']}}]},
            "한글": {"rich_text": [{"text": {"content": info['kor']}}]},
            "도메인": {"relation": [{"id": domain_url.split('/')[-1]}]},
            "모듈 코드": {"relation": [{"id": module_url.split('/')[-1]}]}
        }
    }

    result = subprocess.run(
        ['curl', '-s', '-X', 'POST', f'{API_BASE}/pages',
         '-H', f'Authorization: Bearer {TOKEN}',
         '-H', 'Notion-Version: 2022-06-28',
         '-H', 'Content-Type: application/json',
         '-d', json.dumps(payload)],
        capture_output=True, text=True
    )

    resp = json.loads(result.stdout)
    if 'id' in resp:
        print(f'✅ {func_code} ({info["eng"]} / {info["kor"]}) → Notion 등록 완료')
    else:
        print(f'❌ {func_code} 등록 실패: {resp.get("message", "unknown error")}', file=sys.stderr)

print(f'\n등록 완료: {len(missing)}건')
PYEOF
}

# ── --sync: Notion → convention 동기화 ──

do_sync() {
  echo "Notion → convention-template.md 동기화 시작..." >&2

  echo "  도메인 DB 조회..." >&2
  fetch_domain_id_map
  echo "  모듈 코드 DB 조회..." >&2
  fetch_module_id_map
  echo "  기능코드 DB 조회..." >&2
  fetch_notion_codes_full

  export CONVENTION

  python3 << 'PYEOF'
import json, re, os, sys
from collections import defaultdict

TMPDIR = os.environ['TMPDIR_FC']
CONVENTION = os.environ['CONVENTION']

# ── 1. 도메인/모듈 ID→코드 맵 로드 ──

domain_id_map = {}
with open(f'{TMPDIR}/domain_id_map.tsv') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) == 2:
            domain_id_map[parts[0]] = parts[1]

module_id_map = {}
with open(f'{TMPDIR}/module_id_map.tsv') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) == 2:
            module_id_map[parts[0]] = parts[1]

# ── 2. Notion 기능코드 파싱 + relation resolve ──

with open(f'{TMPDIR}/notion_raw.json') as f:
    data = json.load(f)

notion_entries = []  # (module, domain, func_code, eng, kor)

for p in data.get('results', []):
    props = p['properties']

    func_code = ''
    for k, v in props.items():
        if v['type'] == 'title' and v.get('title'):
            func_code = ''.join([t['plain_text'] for t in v['title']])

    if not func_code or func_code == '코드':
        continue

    eng = ''
    eng_prop = props.get('원어', {})
    if eng_prop.get('type') == 'rich_text' and eng_prop.get('rich_text'):
        eng = ''.join([t['plain_text'] for t in eng_prop['rich_text']])

    kor = ''
    kor_prop = props.get('한글', {})
    if kor_prop.get('type') == 'rich_text' and kor_prop.get('rich_text'):
        kor = ''.join([t['plain_text'] for t in kor_prop['rich_text']])

    # resolve domain relation
    domain_code = '?'
    domain_rel = props.get('도메인', {})
    if domain_rel.get('type') == 'relation' and domain_rel.get('relation'):
        rel_id = domain_rel['relation'][0]['id']
        domain_code = domain_id_map.get(rel_id, domain_id_map.get(rel_id.replace('-',''), '?'))

    # resolve module relation
    module_code = '?'
    module_rel = props.get('모듈 코드', {})
    if module_rel.get('type') == 'relation' and module_rel.get('relation'):
        rel_id = module_rel['relation'][0]['id']
        module_code = module_id_map.get(rel_id, module_id_map.get(rel_id.replace('-',''), '?'))

    notion_entries.append((module_code, domain_code, func_code, eng, kor))

# ── 3. Notion 데이터를 모듈+도메인으로 그룹화 ──

grouped = defaultdict(list)
for module, domain, func, eng, kor in notion_entries:
    grouped[(module, domain)].append((func, eng, kor))

print(f'Notion에서 {len(notion_entries)}개 기능코드 로드 (resolve 실패 제외: {sum(1 for m,d,_,_,_ in notion_entries if m == "?" or d == "?")}건)', file=sys.stderr)
for key, codes in sorted(grouped.items()):
    print(f'  {key[0]}-{key[1]}: {", ".join(c[0] for c in codes)}', file=sys.stderr)

# ── 4. convention-template.md 읽기 ──

with open(CONVENTION, 'r') as f:
    content = f.read()

# ── 5. 각 모듈 섹션의 테이블을 Notion 데이터로 업데이트 ──

# 섹션 패턴: ### MODULE (English / Korean) - DOMAIN
section_pattern = re.compile(
    r'(### (\w+) \([^)]+\) - (\w+)\s*\n)'       # 헤더
    r'(\s*\|[^\n]+\n)'                             # 테이블 헤더
    r'(\s*\|[-| ]+\n)'                             # 구분선
    r'((?:\s*\|[^\n]+\n)*)',                        # 데이터 행들
    re.MULTILINE
)

changes = []

def replace_section(match):
    header = match.group(1)
    module = match.group(2)
    domain = match.group(3)
    table_header = match.group(4)
    separator = match.group(5)
    old_rows = match.group(6)

    key = (module, domain)
    if key not in grouped:
        return match.group(0)  # Notion에 없으면 그대로 유지

    notion_codes = grouped[key]

    # 기존 행에서 첫 번째 컬럼(코드)만 추출 (순서 보존)
    existing_codes = []
    for line in old_rows.strip().split('\n'):
        line = line.strip()
        if line.startswith('|'):
            cells = [c.strip() for c in line.split('|') if c.strip()]
            if cells and cells[0] not in ('코드', '------'):
                existing_codes.append(cells[0])

    # 테이블이 3컬럼인지 4컬럼인지 판별
    col_count = table_header.count('|') - 1
    has_desc = col_count >= 4

    # Notion 코드를 기존 순서 유지하면서 새 코드는 끝에 추가
    notion_map = {c[0]: c for c in notion_codes}
    ordered = []
    for code in existing_codes:
        if code in notion_map:
            ordered.append(notion_map.pop(code))
    for code, entry in notion_map.items():
        ordered.append(entry)
        changes.append(f'  + {module}-{domain}: {code} ({entry[1]} / {entry[2]})')

    # 기존에 있었지만 Notion에 없는 코드 제거
    notion_code_set = {c[0] for c in notion_codes}
    for code in existing_codes:
        if code not in notion_code_set:
            changes.append(f'  - {module}-{domain}: {code} (Notion에서 삭제됨)')

    # 새 행 생성
    new_rows = ''
    for func, eng, kor in ordered:
        if has_desc:
            # 4컬럼: 기존 설명 유지 시도
            desc = ''
            desc_match = re.search(rf'\|\s*{re.escape(func)}\s*\|[^|]+\|[^|]+\|\s*([^|]*)\s*\|', old_rows)
            if desc_match:
                desc = desc_match.group(1).strip()
            new_rows += f'| {func} | {eng} | {kor} | {desc} |\n'
        else:
            new_rows += f'| {func} | {eng} | {kor} |\n'

    return header + table_header + separator + new_rows

updated = section_pattern.sub(replace_section, content)

# ── 6. 버전 업데이트 ──

if changes:
    # 패치 버전 증가
    ver_match = re.search(r'- 버전: (\d+)\.(\d+)\.(\d+)', updated)
    if ver_match:
        major, minor, patch = int(ver_match.group(1)), int(ver_match.group(2)), int(ver_match.group(3))
        new_ver = f'{major}.{minor}.{patch + 1}'
        updated = re.sub(r'- 버전: \d+\.\d+\.\d+', f'- 버전: {new_ver}', updated)

    # 날짜 업데이트
    from datetime import datetime
    today = datetime.now().strftime('%Y-%m-%d')
    updated = re.sub(r'- 날짜: \d{4}-\d{2}-\d{2}', f'- 날짜: {today}', updated)

# ── 7. 파일 쓰기 ──

with open(CONVENTION, 'w') as f:
    f.write(updated)

if changes:
    print(f'\n✅ convention-template.md 업데이트 완료 ({len(changes)}건 변경):')
    for c in changes:
        print(c)
else:
    print('\n✅ convention-template.md — 변경 사항 없음 (이미 동기화됨)')
PYEOF
}

# ── 환경변수 내보내기 (Python에서 사용) ──

export TMPDIR_FC API_BASE NOTION_TOKEN NOTION_FEATURE_CODE_DB_ID

# ── 메인 ──

case "${1:-}" in
  --check)
    do_check
    ;;
  --register)
    do_register
    ;;
  --sync)
    do_sync
    ;;
  *)
    echo "사용법: $0 {--check|--register|--sync}" >&2
    echo "" >&2
    echo "  --check     불일치 감지 (dry-run)" >&2
    echo "  --register  convention → Notion 등록" >&2
    echo "  --sync      Notion → convention-template.md 동기화" >&2
    exit 1
    ;;
esac
