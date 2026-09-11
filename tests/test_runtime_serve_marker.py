"""The appliance's serve request carries the authorizer marker; the bare serve leaves it off."""

from __future__ import annotations

from qwen_apu.runtime import appliance, serve


def test_the_appliance_sets_the_authorizer_marker_and_serve_leaves_it_off() -> None:
    bare = serve.ServeRequest(router=True)
    assert bare.web_authorizer_ready is False
    request = appliance.ApplianceRequest(serve=bare)
    owner = appliance.Appliance.__new__(appliance.Appliance)
    owner.request = request  # type: ignore[misc]
    assert owner._serve_request().web_authorizer_ready is True
    assert owner._serve_request().router is True
