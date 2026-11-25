"""E2E and accessibility tests for the built Hugo site."""

from __future__ import annotations

import functools
import http.server
import json
import os
import socketserver
import sys
import threading
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

from playwright.sync_api import Page, sync_playwright

PUBLIC_DIR = Path(__file__).resolve().parent.parent / "public"
HOME_PATHS = ["/", "/en/"]


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP handler serving ./public without noisy request logs."""

    def log_message(self, format: str, *args: object) -> None:
        pass


def fetch_post_paths(base_url: str) -> list[str]:
    """Verify JSON search indexes and RSS XML feeds, and return all post paths."""
    post_paths: list[str] = []

    for path in ("/index.json", "/en/index.json"):
        with urllib.request.urlopen(f"{base_url}{path}") as resp:
            assert resp.status == 200, f"{path} returned {resp.status}"
            data = json.loads(resp.read().decode("utf-8"))
            assert isinstance(data, list) and len(data) > 0, (
                f"{path} is empty or invalid"
            )
            for entry in data:
                permalink = entry.get("permalink", "")
                if permalink:
                    parsed = urllib.parse.urlparse(permalink)
                    post_paths.append(parsed.path or "/")
            print(f"OK: {path} -> {len(data)} search entries")

    for path in ("/index.xml", "/en/index.xml"):
        with urllib.request.urlopen(f"{base_url}{path}") as resp:
            assert resp.status == 200, f"{path} returned {resp.status}"
            root = ET.fromstring(resp.read().decode("utf-8"))
            items = root.findall("./channel/item")
            assert len(items) > 0, f"{path} has no RSS <item> entries"
            print(f"OK: {path} -> {len(items)} RSS items")

    return list(dict.fromkeys(post_paths))


def check_theme_toggle_and_404(page: Page, base_url: str) -> None:
    """Verify dark/light theme toggle works and /404.html renders."""
    page.goto(f"{base_url}/", wait_until="networkidle")
    initial = page.evaluate("document.documentElement.dataset.theme || ''")
    page.locator("#theme-toggle").click()
    toggled = page.evaluate("document.documentElement.dataset.theme || ''")
    assert toggled != initial, f"Theme toggle did not change theme (stayed {initial!r})"
    print(f"OK: / -> Theme toggle ({initial!r} -> {toggled!r})")

    page.goto(f"{base_url}/404.html", wait_until="networkidle")
    assert page.locator("body").inner_text().strip(), "404.html rendered empty body"
    print("OK: /404.html rendered")


def check_all_pages(
    page: Page, base_url: str, paths: list[str], axe_source: str
) -> None:
    """Check Mermaid rendering, mobile layout, and axe-core on every page."""
    mermaid_checked = 0
    total_violations = 0

    for path in paths:
        url = f"{base_url}{path}"

        # Desktop check: Mermaid (if present) + axe-core accessibility
        page.set_viewport_size({"width": 1280, "height": 800})
        resp = page.goto(url, wait_until="networkidle")
        assert resp is not None and resp.status == 200, (
            f"Unexpected status for {path}: {resp.status if resp else None}"
        )

        mermaid_count = page.locator("pre.mermaid").count()
        for idx in range(mermaid_count):
            svg = page.locator("pre.mermaid svg").nth(idx)
            svg.wait_for(state="visible", timeout=15000)
            box = svg.bounding_box()
            assert box and box["width"] > 0 and box["height"] > 0, (
                f"Invalid Mermaid SVG bounding box on {path}: {box}"
            )
            text = svg.text_content() or ""
            assert "Syntax error" not in text, f"Mermaid syntax error on {path}: {text}"
            mermaid_checked += 1

        page.add_script_tag(content=axe_source)
        results = page.evaluate("async () => await axe.run()")
        violations = results.get("violations", [])
        critical = [v for v in violations if v.get("impact") == "critical"]
        assert not critical, (
            f"Critical axe-core violations on {path}: {[v['id'] for v in critical]}"
        )
        total_violations += len(violations)

        # Mobile viewport check
        page.set_viewport_size({"width": 390, "height": 844})
        overflow = page.evaluate(
            "document.documentElement.scrollWidth > window.innerWidth"
        )
        assert not overflow, f"Horizontal overflow on mobile viewport for {path}"

    print(
        f"OK: {len(paths)} pages checked "
        f"(Mermaid SVGs: {mermaid_checked}, 0 critical axe violations, "
        f"{total_violations} total minor/moderate, 0 mobile overflows)"
    )


def main() -> int:
    """Run all E2E checks against ./public."""
    if not PUBLIC_DIR.is_dir():
        print(
            f"ERROR: {PUBLIC_DIR} does not exist. Run build-hugo first.",
            file=sys.stderr,
        )
        return 1

    axe_path = os.environ.get("AXE_JS_PATH", "")
    if not axe_path or not Path(axe_path).is_file():
        print("ERROR: AXE_JS_PATH is not set or missing.", file=sys.stderr)
        return 1
    axe_source = Path(axe_path).read_text(encoding="utf-8")

    handler = functools.partial(QuietHandler, directory=str(PUBLIC_DIR))
    with socketserver.TCPServer(("127.0.0.1", 0), handler) as httpd:
        port = httpd.server_address[1]
        base_url = f"http://127.0.0.1:{port}"
        thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        thread.start()

        all_paths = HOME_PATHS + fetch_post_paths(base_url)

        launch_kwargs: dict[str, object] = {"headless": True}
        exe = os.environ.get("PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH")
        if exe:
            launch_kwargs["executable_path"] = exe

        errors: list[str] = []
        with sync_playwright() as p:
            browser = p.chromium.launch(**launch_kwargs)
            page = browser.new_page()
            page.on("pageerror", lambda err: errors.append(f"pageerror: {err}"))

            check_theme_toggle_and_404(page, base_url)
            check_all_pages(page, base_url, all_paths, axe_source)

            browser.close()

        httpd.shutdown()

    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
