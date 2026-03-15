#!/usr/bin/env python3
"""Notion REST API 기반 마크다운 업로더.

기획문서 마크다운 파일을 Notion REST API로 직접 업로드합니다.
MCP 대비 속도/안정성 테스트용.

사용법:
  # 신규 페이지 생성
  python notion-md-uploader.py <markdown_file> --title "제목"
  # 기존 페이지 전체 교체 (블록 삭제 후 재업로드)
  python notion-md-uploader.py <markdown_file> --page-id "ID" --replace
  # 기존 페이지에 콘텐츠 추가 (append)
  python notion-md-uploader.py <markdown_file> --page-id "ID"
  # 블록 변환만 테스트
  python notion-md-uploader.py <markdown_file> --dry-run

환경변수:
  NOTION_TOKEN: Notion Integration 토큰
  NOTION_PLAN_DB_ID: 기획문서 DB ID (기본값 하드코딩)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

import asyncio

import httpx

NOTION_API = "https://api.notion.com/v1"
NOTION_VERSION = "2022-06-28"
DEFAULT_DB_ID = "2df471f8-dcff-80b2-9a6d-f9972b15aa06"
MAX_BLOCKS_PER_BATCH = 100


def _headers() -> dict:
    token = os.environ.get("NOTION_TOKEN", "")
    if not token:
        # Try loading from .env — search upward from script location
        search = Path(__file__).resolve().parent
        for _ in range(5):
            env_path = search / ".env"
            if env_path.exists():
                for line in env_path.read_text().splitlines():
                    if line.startswith("NOTION_TOKEN="):
                        token = line.split("=", 1)[1].strip()
                        break
            if token:
                break
            search = search.parent
    if not token:
        print("❌ NOTION_TOKEN 환경변수가 설정되지 않았습니다.")
        sys.exit(1)
    return {
        "Authorization": f"Bearer {token}",
        "Notion-Version": NOTION_VERSION,
        "Content-Type": "application/json",
    }


# ─── Page Creation ───────────────────────────────────────────────


def create_page(db_id: str, title: str) -> str:
    """Create a new page in the planning DB with default properties.

    Returns: page_id
    """
    body = {
        "parent": {"database_id": db_id},
        "properties": {
            "기획 명칭": {"title": [{"text": {"content": title}}]},
            "유형": {"select": {"name": "신규 기능"}},
            "우선 순위": {"select": {"name": "P2(보통)"}},
            "진행 단계": {"status": {"name": "기획 초벌"}},
            "버전": {"number": 1.0},
            "사업팀 검토": {"select": {"name": "대기"}},
            "BE 검토": {"select": {"name": "대기"}},
            "FE 검토": {"select": {"name": "대기"}},
            "디자인 핸드오프": {"checkbox": False},
            "인프라 변경 필요": {"checkbox": False},
        },
    }

    resp = httpx.post(f"{NOTION_API}/pages", headers=_headers(), json=body, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    page_id = data["id"]
    url = data.get("url", "")
    print(f"✅ 페이지 생성 완료: {page_id}")
    print(f"   URL: {url}")
    return page_id


# ─── Block Upload ────────────────────────────────────────────────


def get_child_block_ids(page_id: str) -> list[str]:
    """Get all child block IDs of a page (for deletion)."""
    block_ids: list[str] = []
    cursor = None
    while True:
        params: dict = {"page_size": 100}
        if cursor:
            params["start_cursor"] = cursor
        resp = httpx.get(
            f"{NOTION_API}/blocks/{page_id}/children",
            headers=_headers(),
            params=params,
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()
        for block in data.get("results", []):
            block_ids.append(block["id"])
        if not data.get("has_more"):
            break
        cursor = data.get("next_cursor")
    return block_ids


async def _delete_blocks_async(block_ids: list[str], concurrency: int = 10) -> int:
    """Delete blocks concurrently with semaphore-based rate limiting."""
    sem = asyncio.Semaphore(concurrency)
    deleted = 0
    headers = _headers()

    async def _delete_one(client: httpx.AsyncClient, bid: str) -> bool:
        async with sem:
            resp = await client.delete(
                f"{NOTION_API}/blocks/{bid}",
                headers=headers,
                timeout=30,
            )
            return resp.status_code == 200

    async with httpx.AsyncClient() as client:
        tasks = [_delete_one(client, bid) for bid in block_ids]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        deleted = sum(1 for r in results if r is True)

    return deleted


def delete_all_blocks(page_id: str) -> int:
    """Delete all child blocks of a page. Returns count of deleted blocks."""
    block_ids = get_child_block_ids(page_id)
    if not block_ids:
        print("   ℹ️  삭제할 블록 없음")
        return 0

    print(f"   🗑️  기존 블록 {len(block_ids)}개 병렬 삭제 중...")
    deleted = asyncio.run(_delete_blocks_async(block_ids))
    print(f"   ✅ {deleted}/{len(block_ids)}개 블록 삭제 완료")
    return deleted


def update_page_properties(page_id: str, properties: dict) -> None:
    """Update page properties via Notion API."""
    body = {"properties": properties}
    resp = httpx.patch(
        f"{NOTION_API}/pages/{page_id}",
        headers=_headers(),
        json=body,
        timeout=30,
    )
    if resp.status_code == 200:
        print(f"   ✅ 속성 업데이트 완료")
    else:
        print(f"   ❌ 속성 업데이트 실패: {resp.status_code}")
        print(f"   Response: {resp.text[:300]}")


def append_blocks(page_id: str, blocks: list[dict]) -> None:
    """Append blocks to a page in batches of 100."""
    total = len(blocks)
    for i in range(0, total, MAX_BLOCKS_PER_BATCH):
        batch = blocks[i : i + MAX_BLOCKS_PER_BATCH]
        batch_num = i // MAX_BLOCKS_PER_BATCH + 1
        total_batches = (total + MAX_BLOCKS_PER_BATCH - 1) // MAX_BLOCKS_PER_BATCH
        print(f"   📤 배치 {batch_num}/{total_batches} ({len(batch)}블록)...", end=" ")

        t0 = time.time()
        resp = httpx.patch(
            f"{NOTION_API}/blocks/{page_id}/children",
            headers=_headers(),
            json={"children": batch},
            timeout=60,
        )
        elapsed = time.time() - t0

        if resp.status_code == 200:
            print(f"✅ ({elapsed:.1f}s)")
        else:
            print(f"❌ {resp.status_code}")
            print(f"   Response: {resp.text[:500]}")
            resp.raise_for_status()


# ─── Markdown → Notion Blocks Parser ─────────────────────────────


def _to_rich_text(text: str) -> list[dict]:
    """Convert text with markdown formatting to Notion rich_text array.

    Handles: **bold**, `code`, [text](url), plain text.
    Notion limits each rich_text item to 2000 chars.
    """
    MAX_LEN = 2000
    parts: list[dict] = []

    # Pattern: **bold**, `code`, [text](url)
    pattern = r"(\*\*[^*]+\*\*|`[^`]+`|\[[^\]]+\]\([^)]+\))"
    segments = re.split(pattern, text)

    for segment in segments:
        if not segment:
            continue

        # **bold**
        bold_match = re.match(r"^\*\*(.+)\*\*$", segment)
        if bold_match:
            content = bold_match.group(1)
            parts.append({
                "type": "text",
                "text": {"content": content},
                "annotations": {"bold": True},
            })
            continue

        # `code`
        code_match = re.match(r"^`(.+)`$", segment)
        if code_match:
            content = code_match.group(1)
            parts.append({
                "type": "text",
                "text": {"content": content},
                "annotations": {"code": True},
            })
            continue

        # [text](url)
        link_match = re.match(r"^\[([^\]]+)\]\(([^)]+)\)$", segment)
        if link_match:
            display = link_match.group(1)
            url = link_match.group(2)
            parts.append({
                "type": "text",
                "text": {"content": display, "link": {"url": url}},
            })
            continue

        # Plain text — split if over 2000 chars
        remaining = segment
        while remaining:
            chunk = remaining[:MAX_LEN]
            remaining = remaining[MAX_LEN:]
            parts.append({"type": "text", "text": {"content": chunk}})

    return parts if parts else [{"type": "text", "text": {"content": ""}}]


def _parse_html_table(lines: list[str], start: int) -> tuple[dict | None, int]:
    """Parse <table header-row="true"> ... </table> block.

    Returns (table_block, next_line_index).
    """
    # Collect all lines until </table>
    table_lines = []
    i = start
    while i < len(lines):
        table_lines.append(lines[i])
        if "</table>" in lines[i]:
            i += 1
            break
        i += 1

    content = "\n".join(table_lines)
    has_header = 'header-row="true"' in content

    # Extract rows: each <tr>...</tr>
    rows: list[list[str]] = []
    row_pattern = re.compile(r"<tr>(.*?)</tr>", re.DOTALL)
    cell_pattern = re.compile(r"<td>(.*?)</td>", re.DOTALL)

    for row_match in row_pattern.finditer(content):
        row_content = row_match.group(1)
        cells = [m.group(1).strip() for m in cell_pattern.finditer(row_content)]
        if cells:
            rows.append(cells)

    if not rows:
        return None, i

    col_count = max(len(r) for r in rows)

    # Build table_row children
    children = []
    for row in rows:
        padded = row + [""] * (col_count - len(row))
        cells = [_to_rich_text(cell) for cell in padded]
        children.append({
            "object": "block",
            "type": "table_row",
            "table_row": {"cells": cells},
        })

    table_block = {
        "object": "block",
        "type": "table",
        "table": {
            "table_width": col_count,
            "has_column_header": has_header,
            "has_row_header": False,
            "children": children,
        },
    }

    return table_block, i


def _parse_markdown_table(lines: list[str], start: int) -> tuple[dict | None, int]:
    """Parse standard markdown table (| col1 | col2 |).

    Returns (table_block, next_line_index).
    """
    table_lines = []
    i = start
    while i < len(lines):
        stripped = lines[i].strip()
        if stripped.startswith("|") and stripped.endswith("|"):
            table_lines.append(stripped)
            i += 1
        else:
            break

    rows: list[list[str]] = []
    for line in table_lines:
        cells = [c.strip() for c in line.split("|")[1:-1]]
        # Skip separator rows (|---|---|)
        if all(re.match(r"^:?-+:?$", c) for c in cells if c):
            continue
        rows.append(cells)

    if not rows:
        return None, i

    col_count = max(len(r) for r in rows)

    children = []
    for row in rows:
        padded = row + [""] * (col_count - len(row))
        cells = [_to_rich_text(cell) for cell in padded]
        children.append({
            "object": "block",
            "type": "table_row",
            "table_row": {"cells": cells},
        })

    table_block = {
        "object": "block",
        "type": "table",
        "table": {
            "table_width": col_count,
            "has_column_header": True,
            "has_row_header": False,
            "children": children,
        },
    }

    return table_block, i


def md_to_blocks(markdown: str) -> list[dict]:
    """Convert planning document markdown to Notion block list.

    Supports:
    - ## / ### / #### headings
    - <table header-row="true"> HTML tables
    - | markdown | tables |
    - ```lang code blocks ```
    - > blockquotes
    - - / * bullet lists
    - 1. numbered lists
    - --- dividers
    - Plain paragraphs
    """
    blocks: list[dict] = []
    lines = markdown.split("\n")
    i = 0
    in_code_block = False
    code_lines: list[str] = []
    code_lang = ""

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # ── Code block toggle ──
        if stripped.startswith("```"):
            if in_code_block:
                # End code block
                in_code_block = False
                blocks.append({
                    "object": "block",
                    "type": "code",
                    "code": {
                        "rich_text": [{"type": "text", "text": {"content": "\n".join(code_lines)}}],
                        "language": code_lang or "plain text",
                    },
                })
                code_lines = []
                code_lang = ""
            else:
                in_code_block = True
                code_lang = stripped[3:].strip() or "plain text"
                # Map common lang names to Notion's supported languages
                lang_map = {
                    "ts": "typescript",
                    "tsx": "typescript",
                    "js": "javascript",
                    "jsx": "javascript",
                    "py": "python",
                    "sh": "shell",
                    "bash": "shell",
                    "": "plain text",
                }
                code_lang = lang_map.get(code_lang, code_lang)
                code_lines = []
            i += 1
            continue

        if in_code_block:
            code_lines.append(line)
            i += 1
            continue

        # ── Empty line → skip ──
        if not stripped:
            i += 1
            continue

        # ── HTML table ──
        if stripped.startswith("<table"):
            table_block, i = _parse_html_table(lines, i)
            if table_block:
                blocks.append(table_block)
            continue

        # ── Markdown table ──
        if stripped.startswith("|") and stripped.endswith("|") and "|" in stripped[1:-1]:
            table_block, i = _parse_markdown_table(lines, i)
            if table_block:
                blocks.append(table_block)
            continue

        # ── Headings ──
        h_match = re.match(r"^(#{1,4})\s+(.+)", stripped)
        if h_match:
            level = len(h_match.group(1))
            text = h_match.group(2)
            # Notion supports heading_1, heading_2, heading_3 (no heading_4)
            notion_level = min(level, 3)
            block_type = f"heading_{notion_level}"
            blocks.append({
                "object": "block",
                "type": block_type,
                block_type: {
                    "rich_text": _to_rich_text(text),
                    "is_toggleable": False,
                },
            })
            i += 1
            continue

        # ── Divider ──
        if stripped == "---":
            blocks.append({"object": "block", "type": "divider", "divider": {}})
            i += 1
            continue

        # ── Blockquote ──
        if stripped.startswith(">"):
            quote_lines = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                content = lines[i].strip().lstrip(">").strip()
                quote_lines.append(content)
                i += 1
            # Check if it's a callout (starts with emoji)
            full_text = "\n".join(quote_lines)
            callout_match = re.match(r"^(📌|⚠️|💡|🚨|ℹ️|❗|🔑|🚫|✅|❌|📋|🤖|⭐|🎯|💰|🏷️|📊|🔄|📐)\s*(.+)", full_text, re.DOTALL)
            if callout_match:
                emoji = callout_match.group(1)
                content = callout_match.group(2)
                blocks.append({
                    "object": "block",
                    "type": "callout",
                    "callout": {
                        "icon": {"type": "emoji", "emoji": emoji},
                        "rich_text": _to_rich_text(content),
                    },
                })
            else:
                blocks.append({
                    "object": "block",
                    "type": "quote",
                    "quote": {"rich_text": _to_rich_text(full_text)},
                })
            continue

        # ── Bullet list ──
        if re.match(r"^[-*]\s+", stripped):
            content = re.sub(r"^[-*]\s+", "", stripped)
            blocks.append({
                "object": "block",
                "type": "bulleted_list_item",
                "bulleted_list_item": {"rich_text": _to_rich_text(content)},
            })
            i += 1
            continue

        # ── Numbered list ──
        num_match = re.match(r"^\d+\.\s+(.+)", stripped)
        if num_match:
            blocks.append({
                "object": "block",
                "type": "numbered_list_item",
                "numbered_list_item": {"rich_text": _to_rich_text(num_match.group(1))},
            })
            i += 1
            continue

        # ── Default: paragraph ──
        blocks.append({
            "object": "block",
            "type": "paragraph",
            "paragraph": {"rich_text": _to_rich_text(stripped)},
        })
        i += 1

    # Flush unclosed code block
    if code_lines:
        blocks.append({
            "object": "block",
            "type": "code",
            "code": {
                "rich_text": [{"type": "text", "text": {"content": "\n".join(code_lines)}}],
                "language": code_lang or "plain text",
            },
        })

    return blocks


# ─── Main ────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(description="Notion REST API 마크다운 업로더")
    parser.add_argument("file", help="업로드할 마크다운 파일 경로")
    parser.add_argument("--title", help="페이지 제목 (미지정 시 파일명 사용)")
    parser.add_argument("--db-id", default=DEFAULT_DB_ID, help="Notion DB ID")
    parser.add_argument("--dry-run", action="store_true", help="블록 변환만 하고 업로드하지 않음")
    parser.add_argument("--page-id", help="기존 페이지에 콘텐츠 추가 (신규 생성 안 함)")
    parser.add_argument("--replace", action="store_true", help="기존 페이지 콘텐츠를 전체 교체 (--page-id와 함께 사용)")
    parser.add_argument("--version", type=float, help="버전 속성 업데이트 (예: 3.8)")
    args = parser.parse_args()

    # Read markdown file
    md_path = Path(args.file)
    if not md_path.exists():
        print(f"❌ 파일 없음: {md_path}")
        sys.exit(1)

    md_content = md_path.read_text(encoding="utf-8")
    print(f"📄 파일 읽기 완료: {md_path.name} ({len(md_content):,} chars)")

    # Convert to blocks
    t0 = time.time()
    blocks = md_to_blocks(md_content)
    elapsed = time.time() - t0
    print(f"🔄 블록 변환 완료: {len(blocks)}개 블록 ({elapsed:.2f}s)")

    # Block type summary
    type_counts: dict[str, int] = {}
    for b in blocks:
        t = b.get("type", "unknown")
        type_counts[t] = type_counts.get(t, 0) + 1
    print(f"   블록 구성: {json.dumps(type_counts, ensure_ascii=False)}")

    if args.dry_run:
        print("\n🏷️  --dry-run 모드: 업로드 생략")
        # Print first 3 blocks as sample
        print("\n📋 샘플 블록 (처음 3개):")
        for b in blocks[:3]:
            print(json.dumps(b, ensure_ascii=False, indent=2)[:500])
        return

    # Create page or use existing
    title = args.title or md_path.stem
    if args.page_id:
        page_id = args.page_id
        if args.replace:
            print(f"\n🔄 기존 페이지 전체 교체: {page_id}")
            t_del = time.time()
            delete_all_blocks(page_id)
            print(f"   삭제 소요: {time.time() - t_del:.1f}s")
        else:
            print(f"📝 기존 페이지에 추가: {page_id}")
    else:
        print(f"\n📝 새 페이지 생성: '{title}'")
        page_id = create_page(args.db_id, title)

    # Upload blocks
    print(f"\n📤 블록 업로드 시작 ({len(blocks)}개)...")
    t0 = time.time()
    append_blocks(page_id, blocks)
    elapsed = time.time() - t0
    print(f"\n✅ 업로드 완료! 총 {elapsed:.1f}초 소요")
    print(f"   페이지 ID: {page_id}")

    # Update version property if specified
    if args.version:
        print(f"\n📋 버전 속성 업데이트: {args.version}")
        update_page_properties(page_id, {
            "버전": {"number": args.version},
        })


if __name__ == "__main__":
    main()
