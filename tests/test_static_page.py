"""The served page's own shape: two references, no inline block, one origin.

`web.app.content_security_policy` names the SHA-256 of every inline script and
style block the page carries, so a page holding none needs no hash source and
runs under `script-src 'self'` plus `style-src 'self'` alone. That is the whole
reason the split exists, and the first three assertions below are what keep it
true: one module script, one stylesheet link, and nothing inline.

The two origin meta tags are the other half. `qwen-web-broker` and
`qwen-image-artifacts` named sibling listeners the page derived a credentialed
origin from, and the gateway serves those routes itself, so their absence is
what proves the page reaches one origin. The two LAN bound tags stay, because a
launch writes the served ceiling into them through
`remote/stage-webui-page.sh`, and `connect-src 'self'` is enforced by every
`fetch(` URL literal naming an `/api/` path.
"""

from __future__ import annotations

import re
from html.parser import HTMLParser
from pathlib import Path

import pytest

STATIC_ROOT = Path(__file__).resolve().parents[1] / "static"
INDEX = STATIC_ROOT / "index.html"
SCRIPT_DIRECTORY = STATIC_ROOT / "js"

# The two tags the LAN launch writes its ceiling into.
LAN_BOUND_TAGS = ("qwen-lan-max-prompt-tokens", "qwen-lan-max-output-tokens")
# The two tags that named sibling origins the gateway now serves itself.
RETIRED_ORIGIN_TAGS = ("qwen-web-broker", "qwen-image-artifacts")

# One `fetch(` call's first argument, where that argument is a string literal.
# A template literal counts: its leading text is what decides the origin, and a
# substitution never precedes the path.
FETCH_LITERAL = re.compile(r"""fetch\(\s*(['"`])([^'"`$]*)""")


class PageReader(HTMLParser):
    """Collect the script, link, style, and meta facts one page states."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.scripts: list[dict[str, str]] = []
        self.links: list[dict[str, str]] = []
        self.metas: list[dict[str, str]] = []
        self.inline_scripts = 0
        self.inline_styles = 0
        self._collecting = ""

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = {name: value or "" for name, value in attrs}
        if tag == "script":
            self.scripts.append(attributes)
            if "src" not in attributes:
                self._collecting = tag
        elif tag == "link":
            self.links.append(attributes)
        elif tag == "meta":
            self.metas.append(attributes)
        elif tag == "style":
            self._collecting = tag

    def handle_endtag(self, tag: str) -> None:
        if tag == self._collecting:
            self._collecting = ""

    def handle_data(self, data: str) -> None:
        if not data.strip():
            return
        if self._collecting == "script":
            self.inline_scripts += 1
        elif self._collecting == "style":
            self.inline_styles += 1


@pytest.fixture(scope="module")
def page() -> PageReader:
    reader = PageReader()
    reader.feed(INDEX.read_text(encoding="utf-8"))
    reader.close()
    return reader


def test_the_page_carries_no_inline_script_or_style(page: PageReader) -> None:
    assert page.inline_scripts == 0, "the page carries an inline script block"
    assert page.inline_styles == 0, "the page carries an inline style block"


def test_the_page_references_one_module_script(page: PageReader) -> None:
    assert len(page.scripts) == 1, f"the page carries {len(page.scripts)} script elements"
    script = page.scripts[0]
    assert script.get("type") == "module", "the page's script is no ES module"
    assert script.get("src") == "js/status.js", "the page names another entry point"
    assert (SCRIPT_DIRECTORY / "status.js").is_file()


def test_the_page_references_one_stylesheet(page: PageReader) -> None:
    stylesheets = [link for link in page.links if link.get("rel") == "stylesheet"]
    assert len(stylesheets) == 1, f"the page carries {len(stylesheets)} stylesheet links"
    assert stylesheets[0].get("href") == "app.css"
    assert (STATIC_ROOT / "app.css").is_file()


def test_the_page_derives_no_sibling_origin(page: PageReader) -> None:
    named = {meta.get("name", "") for meta in page.metas}
    for retired in RETIRED_ORIGIN_TAGS:
        assert retired not in named, f"the page still carries the {retired} meta tag"


def test_the_page_carries_both_lan_bound_tags(page: PageReader) -> None:
    named = {meta.get("name", "") for meta in page.metas}
    for bound in LAN_BOUND_TAGS:
        assert bound in named, f"the page carries no {bound} meta tag"
    # The launch writes the served value; an unstaged page states an empty one,
    # which `configuredLanBound` reads as no bound at all.
    for meta in page.metas:
        if meta.get("name") in LAN_BOUND_TAGS:
            assert "content" in meta, f"{meta['name']} states no content attribute"


def test_every_fetch_names_a_gateway_route() -> None:
    modules = sorted(SCRIPT_DIRECTORY.glob("*.js"))
    assert modules, "the static root holds no module to check"
    offenders: list[str] = []
    literals = 0
    for module in modules:
        source = module.read_text(encoding="utf-8")
        for _, target in FETCH_LITERAL.findall(source):
            literals += 1
            if not target.startswith("/api/"):
                offenders.append(f"{module.name}: fetch({target!r})")
    assert literals, "no module reaches the network through a URL literal"
    assert offenders == [], "a module fetches outside the gateway: " + "; ".join(offenders)
