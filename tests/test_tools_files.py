"""The file search and read tool: the root boundary, the caps, and the routes."""

from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from qwen_apu.tools.files import (
    FileSearchRefused,
    FileSearchSettings,
    FilesToolSettings,
    handle_read,
    handle_search,
    read,
    routes,
    search,
)
from qwen_apu.web.http import Request, match

CLIENT = "127.0.0.1"


def request(path: str, body: object) -> Request:
    return Request(
        method="POST",
        path=path,
        query={},
        headers={"host": "127.0.0.1"},
        body=json.dumps(body).encode("utf-8"),
        client_address=CLIENT,
    )


def payload(response: object) -> object:
    return json.loads(response.body.decode("utf-8"))  # type: ignore[attr-defined]


@pytest.fixture
def tree(tmp_path: Path) -> Path:
    """A nested tree: two subdirectories, a binary file, and two symlinks.

    `root/inside/link.txt` targets `root/nested/target.txt`, inside the root.
    `root/outside_link.txt` targets a file one level above the root.
    """
    root = tmp_path / "root"
    (root / "nested").mkdir(parents=True)
    (root / "inside").mkdir()
    (root / "nested" / "target.txt").write_text("needle in the nested file\nsecond line\n")
    (root / "top.txt").write_text("the needle sits at the top\nNEEDLE uppercase\nno match here\n")
    (root / "binary.dat").write_bytes(b"prefix\x00needle after a NUL byte\n")
    (root / "inside" / "link.txt").symlink_to(root / "nested" / "target.txt")

    outside = tmp_path / "outside.txt"
    outside.write_text("needle outside the root\n")
    (root / "outside_link.txt").symlink_to(outside)
    return root


@pytest.fixture
def settings(tree: Path) -> FileSearchSettings:
    return FileSearchSettings(roots=(tree,))


# --- search --------------------------------------------------------------


def test_search_finds_matches_in_nested_directories(
    settings: FileSearchSettings, tree: Path
) -> None:
    hits = search(settings, "needle", root=tree)
    paths = {hit.path for hit in hits}
    assert "top.txt" in paths
    assert os.path.join("nested", "target.txt") in paths


def test_search_skips_binary_files(settings: FileSearchSettings, tree: Path) -> None:
    hits = search(settings, "needle", root=tree)
    assert all(hit.path != "binary.dat" for hit in hits)


def test_search_follows_a_symlink_inside_the_root(settings: FileSearchSettings, tree: Path) -> None:
    hits = search(settings, "needle", root=tree)
    assert any(hit.path == os.path.join("inside", "link.txt") for hit in hits)


def test_search_refuses_to_follow_a_symlink_leaving_the_root(
    settings: FileSearchSettings, tree: Path
) -> None:
    hits = search(settings, "needle", root=tree)
    assert all(hit.path != "outside_link.txt" for hit in hits)


def test_search_case_insensitive_by_default(settings: FileSearchSettings, tree: Path) -> None:
    hits = search(settings, "needle", root=tree)
    assert any(hit.path == "top.txt" and hit.line == 2 for hit in hits)


def test_search_case_sensitive_excludes_a_different_case(
    settings: FileSearchSettings, tree: Path
) -> None:
    hits = search(settings, "needle", root=tree, case_sensitive=True)
    assert all(not (hit.path == "top.txt" and hit.line == 2) for hit in hits)


def test_search_regex_mode(settings: FileSearchSettings, tree: Path) -> None:
    hits = search(settings, r"need\w+", root=tree, regex=True)
    assert any(hit.path == "top.txt" for hit in hits)


def test_search_regex_syntax_error_is_refused(settings: FileSearchSettings, tree: Path) -> None:
    with pytest.raises(FileSearchRefused):
        search(settings, "(unclosed", root=tree, regex=True)


def test_search_literal_query_is_not_a_pattern(settings: FileSearchSettings, tree: Path) -> None:
    hits = search(settings, "(unclosed", root=tree)
    assert hits == ()


def test_search_result_cap(tree: Path) -> None:
    capped = FileSearchSettings(roots=(tree,), max_results=1)
    hits = search(capped, "needle", root=tree)
    assert len(hits) == 1


def test_search_max_file_bytes_excludes_large_files(tree: Path) -> None:
    big = tree / "big.txt"
    big.write_text("needle\n" * 10)
    capped = FileSearchSettings(roots=(tree,), max_file_bytes=5)
    hits = search(capped, "needle", root=big.parent, glob="big.txt")
    assert hits == ()


def test_search_max_total_bytes_stops_the_walk(tree: Path) -> None:
    small_total = FileSearchSettings(roots=(tree,), max_total_bytes=1)
    hits = search(small_total, "needle", root=tree)
    assert hits == ()


def test_search_line_bound_at_400_characters(tree: Path) -> None:
    long_line = "needle " + ("x" * 500)
    (tree / "long.txt").write_text(long_line + "\n")
    hits = search(FileSearchSettings(roots=(tree,)), "needle", root=tree, glob="long.txt")
    assert len(hits) == 1
    assert len(hits[0].text) == 400


def test_search_refuses_root_outside_declared_set(
    settings: FileSearchSettings, tmp_path: Path
) -> None:
    other = tmp_path / "elsewhere"
    other.mkdir()
    with pytest.raises(FileSearchRefused):
        search(settings, "needle", root=other)


def test_search_refuses_dotdot_in_root(settings: FileSearchSettings, tree: Path) -> None:
    with pytest.raises(FileSearchRefused):
        search(settings, "needle", root=tree / ".." / "root")


def test_search_glob_narrows_the_walk(settings: FileSearchSettings, tree: Path) -> None:
    hits = search(settings, "needle", root=tree, glob="top.txt")
    assert {hit.path for hit in hits} == {"top.txt"}


# --- read ------------------------------------------------------------------


def test_read_returns_a_window(settings: FileSearchSettings, tree: Path) -> None:
    result = read(settings, Path("top.txt"), root=tree, start_line=1, end_line=2)
    assert result.lines == ("the needle sits at the top", "NEEDLE uppercase")
    assert result.path == "top.txt"


def test_read_nested_path(settings: FileSearchSettings, tree: Path) -> None:
    result = read(settings, Path("nested/target.txt"), root=tree, start_line=1, end_line=1)
    assert result.lines == ("needle in the nested file",)


def test_read_refuses_a_window_over_2000_lines(settings: FileSearchSettings, tree: Path) -> None:
    with pytest.raises(FileSearchRefused):
        read(settings, Path("top.txt"), root=tree, start_line=1, end_line=2002)


def test_read_admits_a_window_of_exactly_2000_lines(tree: Path) -> None:
    big = tree / "big.txt"
    big.write_text("\n".join(str(n) for n in range(2500)) + "\n")
    result = read(
        FileSearchSettings(roots=(tree,)), Path("big.txt"), root=tree, start_line=1, end_line=2000
    )
    assert len(result.lines) == 2000


def test_read_refuses_end_before_start(settings: FileSearchSettings, tree: Path) -> None:
    with pytest.raises(FileSearchRefused):
        read(settings, Path("top.txt"), root=tree, start_line=3, end_line=1)


def test_read_refuses_root_outside_declared_set(
    settings: FileSearchSettings, tmp_path: Path
) -> None:
    other = tmp_path / "elsewhere"
    other.mkdir()
    with pytest.raises(FileSearchRefused):
        read(settings, Path("top.txt"), root=other, start_line=1, end_line=1)


def test_read_refuses_dotdot_in_path(settings: FileSearchSettings, tree: Path) -> None:
    with pytest.raises(FileSearchRefused):
        read(settings, Path("../outside.txt"), root=tree, start_line=1, end_line=1)


def test_read_refuses_absolute_path(settings: FileSearchSettings, tree: Path) -> None:
    with pytest.raises(FileSearchRefused):
        read(settings, tree / "top.txt", root=tree, start_line=1, end_line=1)


def test_read_refuses_a_symlink_leaving_the_root(settings: FileSearchSettings, tree: Path) -> None:
    with pytest.raises(FileSearchRefused):
        read(settings, Path("outside_link.txt"), root=tree, start_line=1, end_line=1)


def test_read_follows_a_symlink_inside_the_root(settings: FileSearchSettings, tree: Path) -> None:
    result = read(settings, Path("inside/link.txt"), root=tree, start_line=1, end_line=1)
    assert result.lines == ("needle in the nested file",)


def test_read_refuses_a_directory(settings: FileSearchSettings, tree: Path) -> None:
    with pytest.raises(FileSearchRefused):
        read(settings, Path("nested"), root=tree, start_line=1, end_line=1)


def test_read_refuses_a_missing_file(settings: FileSearchSettings, tree: Path) -> None:
    with pytest.raises(FileSearchRefused):
        read(settings, Path("absent.txt"), root=tree, start_line=1, end_line=1)


# --- the routes --------------------------------------------------------------


def tool_settings(tree: Path, *, admits: bool = True) -> FilesToolSettings:
    return FilesToolSettings(
        search=FileSearchSettings(roots=(tree,)), session_admits=lambda _r: admits
    )


def test_search_route_refuses_without_session(tree: Path) -> None:
    settings = tool_settings(tree, admits=False)
    response = handle_search(
        settings, request("/api/tools/files/search", {"query": "needle", "root": str(tree)})
    )
    assert response.status == 401


def test_search_route_admits_with_session(tree: Path) -> None:
    settings = tool_settings(tree)
    response = handle_search(
        settings, request("/api/tools/files/search", {"query": "needle", "root": str(tree)})
    )
    assert response.status == 200
    body = payload(response)
    assert isinstance(body, dict)
    assert body["hits"]


def test_search_route_reports_refusal_as_400(tree: Path) -> None:
    settings = tool_settings(tree)
    response = handle_search(
        settings, request("/api/tools/files/search", {"query": "needle", "root": "/no/such/root"})
    )
    assert response.status == 400


def test_read_route_refuses_without_session(tree: Path) -> None:
    settings = tool_settings(tree, admits=False)
    response = handle_read(
        settings,
        request(
            "/api/tools/files/read",
            {"path": "top.txt", "root": str(tree), "start_line": 1, "end_line": 1},
        ),
    )
    assert response.status == 401


def test_read_route_admits_with_session(tree: Path) -> None:
    settings = tool_settings(tree)
    response = handle_read(
        settings,
        request(
            "/api/tools/files/read",
            {"path": "top.txt", "root": str(tree), "start_line": 1, "end_line": 1},
        ),
    )
    assert response.status == 200
    body = payload(response)
    assert isinstance(body, dict)
    assert body["lines"] == ["the needle sits at the top"]


def test_routes_are_registered_and_dispatch(tree: Path) -> None:
    settings = tool_settings(tree)
    table = routes(settings)
    found = match(table, "POST", "/api/tools/files/search")
    assert found is not None
    route, _params = found
    response = route.handler(
        request("/api/tools/files/search", {"query": "needle", "root": str(tree)})
    )
    assert response.status == 200  # type: ignore[union-attr]

    found_read = match(table, "POST", "/api/tools/files/read")
    assert found_read is not None
    read_route, _params = found_read
    read_response = read_route.handler(
        request(
            "/api/tools/files/read",
            {"path": "top.txt", "root": str(tree), "start_line": 1, "end_line": 1},
        )
    )
    assert read_response.status == 200  # type: ignore[union-attr]
