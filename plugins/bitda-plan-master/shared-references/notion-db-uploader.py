#!/usr/bin/env python3
"""Notion REST API 기반 DB 행 등록기.

화면 DB, 컴포넌트 & 로직 DB에 행을 등록합니다.
MCP notion-create-pages의 REST API 대체.

사용법:
  # 화면 DB 등록
  python .claude/shared-references/notion-db-uploader.py screen \
    --title "검사일지 (목록)" \
    --source "https://github.com/invigoworks/pre-publishing/blob/main/apps/liquor/..." \
    --status "기획 완료" \
    --screen-type "S" \
    --feature-code "LOG" \
    --plan-doc "2e9471f8-dcff-81d9-ba35-c3c691ebc883"

  # 컴포넌트 DB 등록
  python .claude/shared-references/notion-db-uploader.py component \
    --title "InspectionTable" \
    --logic "## 목록 조회\n- GET /api/v1/inspections\n..." \
    --screen "화면-page-id"

  # JSON 파일로 일괄 등록
  python .claude/shared-references/notion-db-uploader.py batch --file entries.json

  # 마스터 코드 조회 (기능코드, 화면유형 코드)
  python .claude/shared-references/notion-db-uploader.py lookup --type feature --query "LOG"
  python .claude/shared-references/notion-db-uploader.py lookup --type screen-type --query "S"

  # dry-run (API 호출 없이 요청 확인)
  python .claude/shared-references/notion-db-uploader.py screen --title "테스트" --dry-run

환경변수:
  NOTION_TOKEN: Notion Integration 토큰
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

import httpx

NOTION_API = "https://api.notion.com/v1"
NOTION_VERSION = "2022-06-28"

# Database IDs
DB_SCREEN = "2d3471f8-dcff-802f-945f-c5add962fc6f"  # 화면 DB
DB_COMPONENT = "2d3471f8-dcff-80d2-8041-f0e98910c922"  # 컴포넌트 & 로직 DB
DB_FEATURE_CODE = "2d3471f8-dcff-80cd-9de7-dac5de60856a"  # 마스터 기능코드 (REST API ID)
DB_SCREEN_TYPE = "c7255e5a-4433-4977-95cb-18b1f8d31a39"  # 화면유형 코드 (REST API ID)

# 화면유형 코드 Page ID 캐시 (알려진 값)
SCREEN_TYPE_IDS: dict[str, str] = {}  # 런타임에 lookup으로 채움


def _headers() -> dict:
    token = os.environ.get("NOTION_TOKEN", "")
    if not token:
        # Try .env files in order
        for env_path in [
            Path(__file__).resolve().parent.parent / ".env",
            Path.cwd() / ".env",
        ]:
            if env_path.exists():
                for line in env_path.read_text().splitlines():
                    if line.startswith("NOTION_TOKEN="):
                        token = line.split("=", 1)[1].strip().strip('"').strip("'")
                        break
            if token:
                break
    if not token:
        print("❌ NOTION_TOKEN 환경변수가 설정되지 않았습니다.")
        sys.exit(1)
    return {
        "Authorization": f"Bearer {token}",
        "Notion-Version": NOTION_VERSION,
        "Content-Type": "application/json",
    }


# ─── Notion API Helpers ─────────────────────────────────────────


def _query_db(db_id: str, filter_obj: dict | None = None, page_size: int = 100) -> list[dict]:
    """Query a Notion database with optional filter."""
    body: dict = {"page_size": page_size}
    if filter_obj:
        body["filter"] = filter_obj
    resp = httpx.post(
        f"{NOTION_API}/databases/{db_id}/query",
        headers=_headers(),
        json=body,
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json().get("results", [])


def _get_page_title(page: dict) -> str:
    """Extract title text from a Notion page object."""
    for prop in page.get("properties", {}).values():
        if prop.get("type") == "title":
            title_arr = prop.get("title", [])
            return "".join(t.get("plain_text", "") for t in title_arr)
    return ""


def lookup_master_code(code_type: str, query: str) -> list[dict]:
    """Search master code DB for matching entries.

    code_type: 'feature' (기능코드) or 'screen-type' (화면유형 코드)
    query: code to search for (e.g., 'LOG', 'S')

    Returns list of {id, title, url} dicts.
    """
    db_id = DB_FEATURE_CODE if code_type == "feature" else DB_SCREEN_TYPE
    title_prop = "기능 코드" if code_type == "feature" else "코드"

    # Query with title filter
    results = _query_db(db_id, {
        "property": title_prop,
        "title": {"equals": query},
    })

    matches = []
    for page in results:
        page_id = page["id"]
        title = _get_page_title(page)
        url = page.get("url", "")
        matches.append({"id": page_id, "title": title, "url": url})

    return matches


def _resolve_feature_code(code: str) -> str | None:
    """Resolve a feature code string to its page ID."""
    # If it's already a UUID-like string, use as-is
    if len(code) == 36 and "-" in code:
        return code
    if len(code) == 32 and "-" not in code:
        # Format as UUID
        return f"{code[:8]}-{code[8:12]}-{code[12:16]}-{code[16:20]}-{code[20:]}"

    # Lookup by code name
    matches = lookup_master_code("feature", code)
    if not matches:
        print(f"  ⚠️ 기능코드 '{code}' 없음")
        return None
    if len(matches) > 1:
        print(f"  ⚠️ 기능코드 '{code}' 중복 {len(matches)}건 → 첫 번째 사용")
        for m in matches:
            print(f"     - {m['id']}: {m['title']}")
    return matches[0]["id"]


def _resolve_screen_type(code: str) -> str | None:
    """Resolve a screen type code (D/S/F/P/R/M) to its page ID."""
    if len(code) == 36 and "-" in code:
        return code

    if code in SCREEN_TYPE_IDS:
        return SCREEN_TYPE_IDS[code]

    matches = lookup_master_code("screen-type", code)
    if not matches:
        print(f"  ⚠️ 화면유형 '{code}' 없음")
        return None
    page_id = matches[0]["id"]
    SCREEN_TYPE_IDS[code] = page_id
    return page_id


# ─── Page Creation ───────────────────────────────────────────────


def create_screen_entry(
    title: str,
    source_url: str = "",
    status: str = "기획 완료",
    screen_type: str = "",
    feature_code: str = "",
    plan_doc_id: str = "",
    dry_run: bool = False,
) -> str | None:
    """Create a screen entry in 화면 DB.

    Returns: page_id or None on dry-run.
    """
    properties: dict = {
        "화면명": {"title": [{"text": {"content": title}}]},
    }

    if source_url:
        properties["source 링크"] = {"url": source_url}

    if status:
        properties["상태"] = {"status": {"name": status}}

    # Relations
    if screen_type:
        st_id = _resolve_screen_type(screen_type)
        if st_id:
            properties["화면유형 코드"] = {"relation": [{"id": st_id}]}

    if feature_code:
        fc_id = _resolve_feature_code(feature_code)
        if fc_id:
            properties["기능코드"] = {"relation": [{"id": fc_id}]}

    if plan_doc_id:
        if len(plan_doc_id) == 32:
            plan_doc_id = f"{plan_doc_id[:8]}-{plan_doc_id[8:12]}-{plan_doc_id[12:16]}-{plan_doc_id[16:20]}-{plan_doc_id[20:]}"
        properties["연관된 기획문서"] = {"relation": [{"id": plan_doc_id}]}

    body = {
        "parent": {"database_id": DB_SCREEN},
        "properties": properties,
    }

    if dry_run:
        print(f"\n🏷️  [DRY-RUN] 화면 DB 등록:")
        print(json.dumps(body, ensure_ascii=False, indent=2))
        return None

    t0 = time.time()
    resp = httpx.post(f"{NOTION_API}/pages", headers=_headers(), json=body, timeout=30)
    elapsed = time.time() - t0

    if resp.status_code == 200:
        data = resp.json()
        page_id = data["id"]
        print(f"  ✅ 화면 등록: {title} → {page_id} ({elapsed:.1f}s)")
        return page_id
    else:
        print(f"  ❌ 화면 등록 실패: {title} ({resp.status_code})")
        print(f"     {resp.text[:300]}")
        return None


def create_component_entry(
    title: str,
    logic: str = "",
    screen_id: str = "",
    dry_run: bool = False,
) -> str | None:
    """Create a component entry in 컴포넌트 & 로직 DB.

    Returns: page_id or None on dry-run.
    """
    properties: dict = {
        "요소명(ID)": {"title": [{"text": {"content": title}}]},
    }

    if logic:
        # rich_text has 2000 char limit per item
        MAX_LEN = 2000
        rich_text_items = []
        remaining = logic
        while remaining:
            chunk = remaining[:MAX_LEN]
            remaining = remaining[MAX_LEN:]
            rich_text_items.append({"type": "text", "text": {"content": chunk}})
        properties["비즈니스 로직"] = {"rich_text": rich_text_items}

    if screen_id:
        if len(screen_id) == 32:
            screen_id = f"{screen_id[:8]}-{screen_id[8:12]}-{screen_id[12:16]}-{screen_id[16:20]}-{screen_id[20:]}"
        properties["화면 DB 연동"] = {"relation": [{"id": screen_id}]}

    body = {
        "parent": {"database_id": DB_COMPONENT},
        "properties": properties,
    }

    if dry_run:
        print(f"\n🏷️  [DRY-RUN] 컴포넌트 DB 등록:")
        print(json.dumps(body, ensure_ascii=False, indent=2))
        return None

    t0 = time.time()
    resp = httpx.post(f"{NOTION_API}/pages", headers=_headers(), json=body, timeout=30)
    elapsed = time.time() - t0

    if resp.status_code == 200:
        data = resp.json()
        page_id = data["id"]
        print(f"  ✅ 컴포넌트 등록: {title} → {page_id} ({elapsed:.1f}s)")
        return page_id
    else:
        print(f"  ❌ 컴포넌트 등록 실패: {title} ({resp.status_code})")
        print(f"     {resp.text[:300]}")
        return None


def batch_create(json_file: str, dry_run: bool = False) -> dict:
    """Batch create entries from a JSON file.

    JSON format:
    {
      "screens": [
        {
          "title": "검사일지 (목록)",
          "source": "https://github.com/...",
          "status": "기획 완료",
          "screen_type": "S",
          "feature_code": "LOG",
          "plan_doc": "page-id"
        }
      ],
      "components": [
        {
          "title": "InspectionTable",
          "logic": "## 목록 조회\\n...",
          "screen": "auto"  // "auto"면 같은 인덱스의 screen page_id 사용
        }
      ]
    }

    Returns: {"screens": [page_ids], "components": [page_ids]}
    """
    with open(json_file, encoding="utf-8") as f:
        data = json.load(f)

    result: dict = {"screens": [], "components": []}

    # Create screens first
    screens = data.get("screens", [])
    for entry in screens:
        page_id = create_screen_entry(
            title=entry["title"],
            source_url=entry.get("source", ""),
            status=entry.get("status", "기획 완료"),
            screen_type=entry.get("screen_type", ""),
            feature_code=entry.get("feature_code", ""),
            plan_doc_id=entry.get("plan_doc", ""),
            dry_run=dry_run,
        )
        result["screens"].append(page_id)

    # Then create components
    components = data.get("components", [])
    for entry in components:
        screen_id = entry.get("screen", "")
        # "auto:N" → use Nth screen's page_id
        if screen_id.startswith("auto"):
            idx = 0
            if ":" in screen_id:
                idx = int(screen_id.split(":")[1])
            if idx < len(result["screens"]) and result["screens"][idx]:
                screen_id = result["screens"][idx]
            else:
                screen_id = ""
                print(f"  ⚠️ auto 참조 실패: screen[{idx}] 없음")

        page_id = create_component_entry(
            title=entry["title"],
            logic=entry.get("logic", ""),
            screen_id=screen_id,
            dry_run=dry_run,
        )
        result["components"].append(page_id)

    return result


# ─── Delete (Soft) ──────────────────────────────────────────────


def archive_page(page_id: str) -> bool:
    """Archive (soft-delete) a Notion page."""
    resp = httpx.patch(
        f"{NOTION_API}/pages/{page_id}",
        headers=_headers(),
        json={"archived": True},
        timeout=30,
    )
    if resp.status_code == 200:
        print(f"  🗑️ 아카이브: {page_id}")
        return True
    else:
        print(f"  ❌ 아카이브 실패: {page_id} ({resp.status_code})")
        return False


# ─── Main ────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(description="Notion REST API DB 행 등록기")
    subparsers = parser.add_subparsers(dest="command", help="명령")

    # screen command
    p_screen = subparsers.add_parser("screen", help="화면 DB 등록")
    p_screen.add_argument("--title", required=True, help="화면명")
    p_screen.add_argument("--source", default="", help="GitHub source URL")
    p_screen.add_argument("--status", default="기획 완료", help="상태")
    p_screen.add_argument("--screen-type", default="", help="화면유형 코드 (S/F/P/D/R/M)")
    p_screen.add_argument("--feature-code", default="", help="기능코드 (LOG, COM 등)")
    p_screen.add_argument("--plan-doc", default="", help="기획문서 Page ID")
    p_screen.add_argument("--dry-run", action="store_true", help="요청만 확인")

    # component command
    p_comp = subparsers.add_parser("component", help="컴포넌트 DB 등록")
    p_comp.add_argument("--title", required=True, help="요소명")
    p_comp.add_argument("--logic", default="", help="비즈니스 로직 텍스트")
    p_comp.add_argument("--logic-file", default="", help="비즈니스 로직 파일 경로")
    p_comp.add_argument("--screen", default="", help="연결할 화면 Page ID")
    p_comp.add_argument("--dry-run", action="store_true", help="요청만 확인")

    # batch command
    p_batch = subparsers.add_parser("batch", help="JSON 파일로 일괄 등록")
    p_batch.add_argument("--file", required=True, help="JSON 파일 경로")
    p_batch.add_argument("--dry-run", action="store_true", help="요청만 확인")

    # lookup command
    p_lookup = subparsers.add_parser("lookup", help="마스터 코드 조회")
    p_lookup.add_argument("--type", required=True, choices=["feature", "screen-type"], help="조회 유형")
    p_lookup.add_argument("--query", required=True, help="검색할 코드")

    # archive command
    p_archive = subparsers.add_parser("archive", help="페이지 아카이브 (삭제)")
    p_archive.add_argument("--page-id", required=True, help="삭제할 Page ID")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    t0 = time.time()

    if args.command == "screen":
        page_id = create_screen_entry(
            title=args.title,
            source_url=args.source,
            status=args.status,
            screen_type=args.screen_type,
            feature_code=args.feature_code,
            plan_doc_id=args.plan_doc,
            dry_run=args.dry_run,
        )
        if page_id:
            print(f"\n📋 등록된 Page ID: {page_id}")

    elif args.command == "component":
        logic = args.logic
        if args.logic_file:
            logic = Path(args.logic_file).read_text(encoding="utf-8")
        page_id = create_component_entry(
            title=args.title,
            logic=logic,
            screen_id=args.screen,
            dry_run=args.dry_run,
        )
        if page_id:
            print(f"\n📋 등록된 Page ID: {page_id}")

    elif args.command == "batch":
        result = batch_create(args.file, dry_run=args.dry_run)
        print(f"\n📊 결과: 화면 {len(result['screens'])}건, 컴포넌트 {len(result['components'])}건")
        if not args.dry_run:
            print(json.dumps(result, ensure_ascii=False, indent=2))

    elif args.command == "lookup":
        matches = lookup_master_code(args.type, args.query)
        if matches:
            for m in matches:
                print(f"  ✅ {m['title']} → {m['id']}")
        else:
            print(f"  ❌ '{args.query}' 없음")

    elif args.command == "archive":
        archive_page(args.page_id)

    elapsed = time.time() - t0
    print(f"\n⏱️ 총 {elapsed:.1f}초 소요")


if __name__ == "__main__":
    main()
