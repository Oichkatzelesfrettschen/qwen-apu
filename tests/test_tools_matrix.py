"""What `GET /api/tools?model=ID` states for one selection, and why.

Every arm below fixes one input -- a ledger field, a launch setting, or a
filesystem fact -- and reads the state the matrix derives from it, so a
derivation that stops reading its authority fails against the authority rather
than against a recorded string.
"""

from __future__ import annotations

import dataclasses
import json
import socket
from pathlib import Path
from typing import Any

import pytest

from qwen_apu.config import models as config_models
from qwen_apu.config.schema import ImageProfile, ModelRow, WebProfile
from qwen_apu.tools import matrix, registry
from qwen_apu.tools import web as web_tools
from qwen_apu.web.http import Request, Response, match

TREE = Path(__file__).resolve().parents[1]

WEB_PROFILE = "web-open"
TEXT_MODEL = "qwen38-2b-distill"

# What an assembly that mounted `qwen_apu.tools.web` passes: the two schemas
# that executor advertises, read from the executor itself rather than copied
# here, so a row this module reports as available carries the object the
# request body forwards and the two artifacts cannot drift apart.
WEB_DEFINITIONS = web_tools.tool_definitions(
    web_tools.WebToolSettings(token_key_file=Path("token.key"), profile=WEB_PROFILE)
)


def tracked() -> matrix.Ledgers:
    return matrix.Ledgers.load()


def request_for(query: dict[str, str]) -> Request:
    return Request("GET", matrix.MATRIX_PATH, query, {"host": "127.0.0.1"}, b"", "127.0.0.1")


def body_of(response: Response) -> dict[str, Any]:
    parsed = json.loads(response.body.decode("utf-8"))
    assert isinstance(parsed, dict)
    return parsed


def rows_of(response: Response) -> dict[str, dict[str, Any]]:
    listed = body_of(response)["tools"]
    assert isinstance(listed, list)
    return {row["tool_id"]: row for row in listed}


def answer(settings: matrix.MatrixSettings, selector: str) -> Response:
    return matrix.handle(settings, request_for({"model": selector}))


def settings_for(ledgers: matrix.Ledgers | None = None, **overrides: Any) -> matrix.MatrixSettings:
    base: dict[str, Any] = {
        "approval_profile": WEB_PROFILE,
        "provider": "searxng",
        "ledgers": ledgers if ledgers is not None else tracked(),
    }
    base.update(overrides)
    return matrix.MatrixSettings(**base)


def replace_web_profile(ledgers: matrix.Ledgers, profile_id: str, **fields: Any) -> matrix.Ledgers:
    rows = tuple(
        dataclasses.replace(row, **fields) if row.profile_id == profile_id else row
        for row in ledgers.web_profiles
    )
    return dataclasses.replace(ledgers, web_profiles=rows)


def replace_model(ledgers: matrix.Ledgers, model_id: str, **fields: Any) -> matrix.Ledgers:
    rows = tuple(
        dataclasses.replace(row, **fields) if row.id == model_id else row for row in ledgers.models
    )
    return dataclasses.replace(ledgers, models=rows)


def bound_socket(directory: Path) -> Path:
    """A bound AF_UNIX socket, so `is_socket` reads the way a live worker leaves it."""
    path = directory / "image-service.sock"
    listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    listener.bind(str(path))
    listener.listen(1)
    # The descriptor closes with the test process; the path is what the
    # derivation reads and it survives the close until the file is unlinked.
    return path


# ---------------------------------------------------------------------------
# The route contract
# ---------------------------------------------------------------------------


def test_the_route_requires_the_selected_model() -> None:
    response = matrix.handle(settings_for(), request_for({}))
    assert response.status == 400
    assert "?model=ID" in body_of(response)["error"]


def test_an_unknown_selector_is_refused_by_name() -> None:
    response = answer(settings_for(), "no-such-row")
    assert response.status == 404
    assert "no-such-row" in body_of(response)["error"]


def test_the_matrix_carries_every_registry_row_with_a_closed_state() -> None:
    response = answer(settings_for(), WEB_PROFILE)
    assert response.status == 200
    payload = body_of(response)
    assert payload["schema"] == matrix.MATRIX_SCHEMA
    listed = rows_of(response)
    assert set(listed) == {row.tool_id for row in registry.TOOL_TABLE}
    closed = {str(state) for state in matrix.ToolState}
    for row in listed.values():
        assert row["state"] in closed, row
        assert row["reason"], row
        assert row["title"] and row["lane"] and row["execution_path"]


def test_the_task_named_tools_all_answer() -> None:
    """The eight tools the surface offers each carry a state for one selection."""
    listed = rows_of(answer(settings_for(), WEB_PROFILE))
    for tool_id in (
        "web_search",
        "read_url",
        "image_generation",
        "image_review",
        "image_interpretation",
        "documents",
        "calculator",
        "local_file_search",
    ):
        assert tool_id in listed


def test_the_route_mounts_under_the_gateway() -> None:
    mounted = matrix.routes(settings_for())
    assert match(mounted, "GET", matrix.MATRIX_PATH) is not None
    assert match(mounted, "POST", matrix.MATRIX_PATH) is None


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------


def test_a_web_profile_selector_resolves_its_checkpoint() -> None:
    selection = matrix.resolve_selection(tracked(), WEB_PROFILE)
    assert selection is not None
    assert selection.kind == "web-profile"
    assert selection.web_profile is not None
    assert selection.model.id == selection.web_profile.model_id


def test_a_checkpoint_selector_carries_no_web_profile() -> None:
    selection = matrix.resolve_selection(tracked(), TEXT_MODEL)
    assert selection is not None
    assert selection.kind == "model"
    assert selection.web_profile is None


def test_a_quarantined_checkpoint_refuses_every_row() -> None:
    ledgers = replace_model(tracked(), TEXT_MODEL, tier="quarantine")
    listed = rows_of(answer(settings_for(ledgers), TEXT_MODEL))
    assert {row["state"] for row in listed.values()} == {str(matrix.ToolState.POLICY_REFUSED)}
    assert "remote/quarantine.tsv" in listed["calculator"]["reason"]


# ---------------------------------------------------------------------------
# The web lane
# ---------------------------------------------------------------------------


def test_a_checkpoint_outside_the_web_ledger_installs_no_web_tool() -> None:
    listed = rows_of(answer(settings_for(), TEXT_MODEL))
    for tool_id in ("web_search", "read_url", "wikipedia_profile"):
        assert listed[tool_id]["state"] == str(matrix.ToolState.NOT_INSTALLED)
        assert "remote/web-profiles.tsv" in listed[tool_id]["reason"]


def test_a_profile_the_broker_does_not_sign_for_is_refused_up_front() -> None:
    """`POST /grant-image` refuses a foreign profile_id, so the matrix says so first."""
    other = next(row for row in tracked().web_profiles if row.profile_id != WEB_PROFILE)
    listed = rows_of(answer(settings_for(approval_profile=WEB_PROFILE), other.profile_id))
    assert listed["web_search"]["state"] == str(matrix.ToolState.POLICY_REFUSED)
    assert WEB_PROFILE in listed["web_search"]["reason"]


def test_a_refused_execution_policy_reaches_the_page_as_policy_refused() -> None:
    ledgers = replace_web_profile(tracked(), WEB_PROFILE, execution_policy="refused")
    listed = rows_of(answer(settings_for(ledgers), WEB_PROFILE))
    assert listed["web_search"]["state"] == str(matrix.ToolState.POLICY_REFUSED)
    assert "execution_policy refused" in listed["web_search"]["reason"]


def test_an_unset_searxng_url_is_temporary_rather_than_refused() -> None:
    ledgers = replace_web_profile(tracked(), WEB_PROFILE, searxng_url=None)
    listed = rows_of(answer(settings_for(ledgers, web_definitions=WEB_DEFINITIONS), WEB_PROFILE))
    assert listed["web_search"]["state"] == str(matrix.ToolState.TEMPORARILY_UNAVAILABLE)
    assert listed["web_search"]["helper"] == "searxng"


def test_an_unmounted_executor_leaves_the_web_rows_temporarily_unavailable() -> None:
    """The gateway mounts the grant routes and no tool executor today."""
    listed = rows_of(answer(settings_for(), WEB_PROFILE))
    for tool_id in ("web_search", "read_url", "wikipedia_profile"):
        assert listed[tool_id]["state"] == str(matrix.ToolState.TEMPORARILY_UNAVAILABLE)
        assert "no tool executor" in listed[tool_id]["reason"]


def test_a_mounted_executor_runs_the_two_rows_it_holds_the_schemas_for() -> None:
    """The gateway runs `web_search` and `read_url`; the instance answers the query."""
    listed = rows_of(answer(settings_for(web_definitions=WEB_DEFINITIONS), WEB_PROFILE))
    for tool_id in ("web_search", "read_url"):
        assert listed[tool_id]["state"] == str(matrix.ToolState.AVAILABLE)
        assert listed[tool_id]["definition"]["function"]["name"] == tool_id
        assert listed[tool_id]["execution_path"] == "src/qwen_apu/tools/web.py"
        assert listed[tool_id]["helper"] == "searxng"
    assert listed["wikipedia_profile"]["state"] == str(matrix.ToolState.AVAILABLE_THROUGH_HELPER)
    assert listed["wikipedia_profile"]["helper"] == "searxng"


def test_a_row_carries_a_schema_exactly_where_its_state_admits_a_call() -> None:
    """A page composing from the definitions and one reading the states pick one set."""
    listed = rows_of(answer(settings_for(web_definitions=WEB_DEFINITIONS), WEB_PROFILE))
    executing = {str(matrix.ToolState.AVAILABLE), str(matrix.ToolState.AVAILABLE_THROUGH_HELPER)}
    for tool_id, row in listed.items():
        if "definition" in row:
            assert row["state"] in executing, tool_id
            assert row["definition"]["function"]["name"] == tool_id
    unmounted = rows_of(answer(settings_for(), WEB_PROFILE))
    for tool_id in ("web_search", "read_url"):
        assert "definition" not in unmounted[tool_id]


def test_wikipedia_installs_nowhere_outside_the_searxng_provider() -> None:
    ledgers = replace_web_profile(
        tracked(),
        WEB_PROFILE,
        provider="exa",
        primary_category=None,
        fallback_category=None,
        minimum_results=None,
        searxng_url=None,
    )
    listed = rows_of(answer(settings_for(ledgers, web_definitions=WEB_DEFINITIONS), WEB_PROFILE))
    assert listed["web_search"]["state"] == str(matrix.ToolState.AVAILABLE)
    assert listed["wikipedia_profile"]["state"] == str(matrix.ToolState.NOT_INSTALLED)
    assert "settings.yml" in listed["wikipedia_profile"]["reason"]


# ---------------------------------------------------------------------------
# Vision on the selected checkpoint
# ---------------------------------------------------------------------------


def test_a_projectorless_checkpoint_analyzes_no_attachment() -> None:
    row = next(row for row in tracked().models if row.projector == "none")
    listed = rows_of(answer(settings_for(), row.id))
    assert listed["image_interpretation"]["state"] == str(matrix.ToolState.NOT_INSTALLED)
    assert "projector none" in listed["image_interpretation"]["reason"]


def test_a_projector_paired_checkpoint_analyzes_an_attachment_in_its_own_turn() -> None:
    row = next(row for row in tracked().models if row.projector == "required")
    listed = rows_of(answer(settings_for(), row.id))
    assert listed["image_interpretation"]["state"] == str(matrix.ToolState.AVAILABLE)
    assert listed["image_interpretation"]["helper"] == ""


# ---------------------------------------------------------------------------
# The image lane
# ---------------------------------------------------------------------------


def test_an_unarmed_image_lane_installs_neither_generation_nor_review() -> None:
    listed = rows_of(answer(settings_for(image_profile=""), WEB_PROFILE))
    for tool_id in ("image_generation", "image_review"):
        assert listed[tool_id]["state"] == str(matrix.ToolState.NOT_INSTALLED)
        assert "no image lane" in listed[tool_id]["reason"]


def test_a_refused_image_profile_refuses_generation_and_review() -> None:
    refused = next(row for row in tracked().image_profiles if row.execution_policy == "refused")
    listed = rows_of(answer(settings_for(image_profile=refused.profile_id), WEB_PROFILE))
    assert listed["image_generation"]["state"] == str(matrix.ToolState.POLICY_REFUSED)
    assert "remote/image-profiles.tsv" in listed["image_generation"]["reason"]
    # That row names no reviewer either, so review states the absent claim.
    assert listed["image_review"]["state"] == str(matrix.ToolState.NOT_INSTALLED)


def test_an_unbound_worker_socket_is_temporary_rather_than_refused(tmp_path: Path) -> None:
    served = next(
        row for row in tracked().image_profiles if row.execution_policy == "validator-gated"
    )
    listed = rows_of(
        answer(
            settings_for(
                image_profile=served.profile_id, image_socket=tmp_path / "image-service.sock"
            ),
            WEB_PROFILE,
        )
    )
    assert listed["image_generation"]["state"] == str(matrix.ToolState.TEMPORARILY_UNAVAILABLE)
    assert listed["image_generation"]["helper"] == served.model_id


def test_a_bound_worker_socket_names_the_bundle_as_the_helper(tmp_path: Path) -> None:
    served = next(
        row for row in tracked().image_profiles if row.execution_policy == "validator-gated"
    )
    listed = rows_of(
        answer(
            settings_for(image_profile=served.profile_id, image_socket=bound_socket(tmp_path)),
            WEB_PROFILE,
        )
    )
    assert listed["image_generation"]["state"] == str(matrix.ToolState.AVAILABLE_THROUGH_HELPER)
    assert listed["image_generation"]["helper"] == served.model_id


def test_the_review_row_names_the_registered_reviewer(tmp_path: Path) -> None:
    served = next(row for row in tracked().image_profiles if row.review_model is not None)
    listed = rows_of(
        answer(
            settings_for(image_profile=served.profile_id, image_socket=bound_socket(tmp_path)),
            WEB_PROFILE,
        )
    )
    assert listed["image_review"]["state"] == str(matrix.ToolState.AVAILABLE_THROUGH_HELPER)
    assert listed["image_review"]["helper"] == served.review_model


def test_a_reviewer_without_a_projector_reads_no_image() -> None:
    served = next(row for row in tracked().image_profiles if row.review_model is not None)
    reviewer = served.review_model
    assert reviewer is not None
    ledgers = replace_model(tracked(), reviewer, projector="none")
    listed = rows_of(answer(settings_for(ledgers, image_profile=served.profile_id), WEB_PROFILE))
    assert listed["image_review"]["state"] == str(matrix.ToolState.NOT_INSTALLED)
    assert "loads no image" in listed["image_review"]["reason"]


def test_a_profile_naming_no_reviewer_offers_no_review(tmp_path: Path) -> None:
    served = next(
        row for row in tracked().image_profiles if row.execution_policy == "validator-gated"
    )
    ledgers = dataclasses.replace(
        tracked(),
        image_profiles=tuple(
            dataclasses.replace(row, review_model=None)
            if row.profile_id == served.profile_id
            else row
            for row in tracked().image_profiles
        ),
    )
    listed = rows_of(
        answer(
            settings_for(
                ledgers, image_profile=served.profile_id, image_socket=bound_socket(tmp_path)
            ),
            WEB_PROFILE,
        )
    )
    assert listed["image_review"]["state"] == str(matrix.ToolState.NOT_INSTALLED)
    assert "review_model -" in listed["image_review"]["reason"]


# ---------------------------------------------------------------------------
# The local lane
# ---------------------------------------------------------------------------


def test_documents_and_the_calculator_run_inside_the_gateway() -> None:
    listed = rows_of(answer(settings_for(), WEB_PROFILE))
    for tool_id in ("documents", "calculator"):
        assert listed[tool_id]["state"] == str(matrix.ToolState.AVAILABLE)
        assert listed[tool_id]["helper"] == ""


def test_an_unmounted_document_surface_installs_nothing() -> None:
    listed = rows_of(answer(settings_for(documents_served=False), WEB_PROFILE))
    assert listed["documents"]["state"] == str(matrix.ToolState.NOT_INSTALLED)


def test_a_launch_without_a_file_root_refuses_the_scoped_search() -> None:
    listed = rows_of(answer(settings_for(file_roots=()), WEB_PROFILE))
    assert listed["local_file_search"]["state"] == str(matrix.ToolState.POLICY_REFUSED)
    assert "--file-root" in listed["local_file_search"]["reason"]


def test_a_declared_root_admits_the_scoped_search_and_names_the_guard(tmp_path: Path) -> None:
    listed = rows_of(answer(settings_for(file_roots=(tmp_path,)), WEB_PROFILE))
    row = listed["local_file_search"]
    assert row["state"] == str(matrix.ToolState.AVAILABLE)
    assert "guarded_tool_execution refused" in row["reason"]


def test_the_router_tool_grant_is_refused_on_every_checkpoint() -> None:
    """Every models.tsv row reads guarded_tool_execution refused, and AGENTS.md pins it."""
    for row in tracked().models:
        assert row.guarded_tool_execution == "refused"
    listed = rows_of(answer(settings_for(), WEB_PROFILE))
    assert listed["code_tools"]["state"] == str(matrix.ToolState.POLICY_REFUSED)
    assert listed["artifact_export"]["state"] == str(matrix.ToolState.NOT_INSTALLED)


# ---------------------------------------------------------------------------
# The offered set
# ---------------------------------------------------------------------------


def test_the_offered_set_reads_the_two_executing_states() -> None:
    listed = body_of(answer(settings_for(web_definitions=WEB_DEFINITIONS), WEB_PROFILE))["tools"]
    assert isinstance(listed, list)
    offered = matrix.offered_tool_ids(listed)
    assert "web_search" in offered
    assert "code_tools" not in offered
    assert "artifact_export" not in offered


def test_the_ledgers_load_from_the_tracked_tree() -> None:
    """`Ledgers.load` reads the three tracked files, so an unconfigured mount answers."""
    ledgers = matrix.Ledgers.load()
    assert isinstance(ledgers.models[0], ModelRow)
    assert isinstance(ledgers.web_profiles[0], WebProfile)
    assert isinstance(ledgers.image_profiles[0], ImageProfile)
    assert {row.id for row in ledgers.models} == {
        row.id for row in config_models.load_models(TREE / "remote" / "models.tsv")
    }


@pytest.mark.parametrize("selector", ["", "   "])
def test_a_blank_selector_is_refused(selector: str) -> None:
    response = matrix.handle(settings_for(), request_for({"model": selector}))
    assert response.status in (400, 404)


def test_the_image_row_carries_the_profiles_own_ceilings(tmp_path: Path) -> None:
    """The page checks a proposal against these before it opens the dialog."""
    served = next(
        row for row in tracked().image_profiles if row.execution_policy == "validator-gated"
    )
    listed = rows_of(
        answer(
            settings_for(image_profile=served.profile_id, image_socket=bound_socket(tmp_path)),
            WEB_PROFILE,
        )
    )
    assert listed["image_generation"]["bounds"] == {
        "profile_id": served.profile_id,
        "width": served.width,
        "height": served.height,
        "max_dimension": served.max_dimension,
        "max_steps": served.max_steps,
    }


def test_a_row_that_admits_no_call_states_no_bounds() -> None:
    listed = rows_of(answer(settings_for(image_profile=""), WEB_PROFILE))
    assert "bounds" not in listed["image_generation"]
    assert "bounds" not in listed["calculator"]
