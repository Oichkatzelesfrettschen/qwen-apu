"""The calculator tool: the parser, the evaluator, the unit table, and the route."""

from __future__ import annotations

import json
import random
from collections.abc import Iterator
from decimal import Decimal
from fractions import Fraction

import pytest

from qwen_apu.tools.calculator import (
    CalculatorRefused,
    CalculatorSettings,
    Result,
    calculate,
    evaluate,
    routes,
)
from qwen_apu.web.http import Request, match

CLIENT = "127.0.0.1"


def request(body: object) -> Request:
    return Request(
        method="POST",
        path="/api/tools/calculator",
        query={},
        headers={"host": "127.0.0.1"},
        body=json.dumps(body).encode("utf-8"),
        client_address=CLIENT,
    )


def payload(response: object) -> object:
    return json.loads(response.body.decode("utf-8"))  # type: ignore[attr-defined]


# --- operators and precedence -----------------------------------------------


@pytest.mark.parametrize(
    ("expression", "expected"),
    [
        ("2 + 3", "5"),
        ("2 - 3", "-1"),
        ("2 * 3", "6"),
        ("7 / 2", "3.5"),
        ("7 // 2", "3"),
        ("7 % 2", "1"),
        ("2 ** 3", "8"),
        ("-2 ** 2", "-4"),  # unary minus binds looser than **, matching Python
        ("(-2) ** 2", "4"),
        ("2 + 3 * 4", "14"),
        ("(2 + 3) * 4", "20"),
        ("2 * 3 + 4 * 5", "26"),
        ("10 - 2 - 3", "5"),  # left-associative
        ("2 ** 2 ** 3", "256"),  # right-associative: 2 ** (2 ** 3)
        ("-5", "-5"),
        ("--5", "5"),
        ("sqrt(16)", "4"),
        ("abs(-7)", "7"),
        ("round(3.456, 2)", "3.46"),
        ("round(2.5)", "2"),  # ROUND_HALF_EVEN
        ("min(3, 1, 2)", "1"),
        ("max(3, 1, 2)", "3"),
        # Decimal's // and % truncate toward zero, unlike Python's own floor
        # division on int; this fixes the chosen semantics rather than
        # Python's, since the operands are Decimal throughout.
        ("-7 // 2", "-3"),
        ("-7 % 2", "-1"),
    ],
)
def test_operators_and_precedence(expression: str, expected: str) -> None:
    assert evaluate(expression).value == expected


# --- unit conversions --------------------------------------------------------


def test_miles_to_meters() -> None:
    result = evaluate("1 mi to m")
    assert result.value == "1609.344"
    assert result.unit_in == "mi"
    assert result.unit_out == "m"


def test_celsius_to_fahrenheit() -> None:
    result = evaluate("100 c to f")
    assert result.value == "212"


def test_gib_to_bytes() -> None:
    result = evaluate("1 gib to b")
    assert result.value == "1073741824"


def test_no_conversion_carries_no_units() -> None:
    result = evaluate("2 + 2")
    assert result.unit_in is None
    assert result.unit_out is None


def test_cross_dimension_conversion_is_refused() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("1 m to kg")


def test_temperature_to_length_is_refused() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("1 c to m")


def test_normalized_expression_carries_the_unit_suffix() -> None:
    result = evaluate("1 + 1 mi to m")
    assert result.expression.endswith("mi to m")


# --- refusals ------------------------------------------------------------


def test_refuses_expression_over_1024_characters() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("1+" * 600 + "1")


def test_refuses_nesting_deeper_than_32() -> None:
    expression = "(" * 33 + "1" + ")" * 33
    with pytest.raises(CalculatorRefused):
        evaluate(expression)


def test_admits_nesting_at_32() -> None:
    expression = "(" * 32 + "1" + ")" * 32
    assert evaluate(expression).value == "1"


def test_refuses_exponent_over_1000() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("2 ** 1001")


def test_admits_exponent_at_1000() -> None:
    evaluate("1 ** 1000")


def test_refuses_unknown_identifier() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("foo(1)")


def test_refuses_unknown_unit() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("1 parsec to m")


def test_refuses_division_by_zero() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("1 / 0")


def test_refuses_floor_division_by_zero() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("1 // 0")


def test_refuses_modulo_by_zero() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("1 % 0")


def test_refuses_negative_sqrt() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("sqrt(-1)")


def test_refuses_wrong_arity() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("sqrt(1, 2)")
    with pytest.raises(CalculatorRefused):
        evaluate("abs()")


def test_refuses_malformed_expression() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("1 +")
    with pytest.raises(CalculatorRefused):
        evaluate("(1 + 2")
    with pytest.raises(CalculatorRefused):
        evaluate("")


def test_refuses_bad_character() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("1 @ 2")


def test_refuses_unit_conversion_missing_to() -> None:
    with pytest.raises(CalculatorRefused):
        evaluate("1 mi m")


def test_refuses_round_past_the_34_digit_precision() -> None:
    # quantize demands a coefficient within the 34-digit context; a digit
    # count past that raises decimal.InvalidOperation, which the evaluator
    # turns into the same CalculatorRefused every other refusal answers with.
    with pytest.raises(CalculatorRefused):
        evaluate("round(1, 40)")


def test_refuses_an_exponent_chain_that_overflows() -> None:
    # Each ** in the chain passes the per-operator 1000 cap alone; the
    # compounded magnitude still overflows the context's Emax, and that
    # decimal.Overflow is refused rather than raised past evaluate().
    with pytest.raises(CalculatorRefused):
        evaluate("((9 ** 1000) ** 1000) ** 1000")


# --- the route ---------------------------------------------------------------


def test_route_refuses_without_session() -> None:
    settings = CalculatorSettings()
    response = calculate(settings, request({"expression": "2 + 2"}))
    assert response.status == 401


def test_route_admits_with_session_and_evaluates() -> None:
    settings = CalculatorSettings(session_admits=lambda _r: True)
    response = calculate(settings, request({"expression": "2 + 2"}))
    assert response.status == 200
    body = payload(response)
    assert isinstance(body, dict)
    assert body["value"] == "4"


def test_route_reports_refusal_as_400() -> None:
    settings = CalculatorSettings(session_admits=lambda _r: True)
    response = calculate(settings, request({"expression": "1 / 0"}))
    assert response.status == 400


def test_route_rejects_non_json_body() -> None:
    settings = CalculatorSettings(session_admits=lambda _r: True)
    malformed = Request(
        method="POST",
        path="/api/tools/calculator",
        query={},
        headers={"host": "127.0.0.1"},
        body=b"not json",
        client_address=CLIENT,
    )
    response = calculate(settings, malformed)
    assert response.status == 400


def test_route_is_registered_and_dispatches() -> None:
    settings = CalculatorSettings(session_admits=lambda _r: True)
    table = routes(settings)
    found = match(table, "POST", "/api/tools/calculator")
    assert found is not None
    route, params = found
    response = route.handler(request({"expression": "3 * 3"}))
    assert response.status == 200  # type: ignore[union-attr]


# --- property-style check against Fraction arithmetic -----------------------


def _random_int_expression(rng: random.Random, depth: int = 0) -> tuple[str, Fraction]:
    """One well-formed expression over +, -, * and integer literals, and its exact value."""
    if depth >= 3 or rng.random() < 0.4:
        value = rng.randint(-99, 99)
        return str(value), Fraction(value)
    left_text, left_value = _random_int_expression(rng, depth + 1)
    right_text, right_value = _random_int_expression(rng, depth + 1)
    op = rng.choice(["+", "-", "*"])
    text = f"({left_text} {op} {right_text})"
    if op == "+":
        return text, left_value + right_value
    if op == "-":
        return text, left_value - right_value
    return text, left_value * right_value


def _seeds() -> Iterator[int]:
    return iter(range(200))


@pytest.mark.parametrize("seed", list(_seeds()))
def test_property_matches_fraction_arithmetic(seed: int) -> None:
    rng = random.Random(seed)  # noqa: S311 -- a reproducible test fixture, not a cryptographic use
    expression, expected = _random_int_expression(rng)
    result: Result = evaluate(expression)
    assert Decimal(result.value) == Decimal(expected.numerator) / Decimal(expected.denominator)
