"""A deterministic arithmetic and unit-conversion tool, mounted on the gateway.

`evaluate` runs no `eval`: a tokenizer and a recursive-descent parser build an
expression tree over `+ - * / // % **`, parentheses, unary minus, and decimal
literals, and a fixed 34-digit `decimal.Context` evaluates it. `+ - * / //`
and `%` follow Python's own precedence and associativity; unary minus binds
looser than `**`, so `-2 ** 2` reads as `-(2 ** 2)` the way Python's own
grammar reads it. `sqrt`, `abs`, `round`, `min`, and `max` are the whole
function table, and a unit table converts length, mass, temperature, data
size (SI and IEC), time, and speed through Decimal factors kept as strings so
the digits a conversion carries are the digits this module states, not a
binary float's nearest approximation.

An expression names a unit conversion by trailing itself with `<unit> to
<unit>`, so `1 mi to m` and `100 c to f` are complete inputs and a bare
arithmetic expression is one that never reaches that suffix. Temperature
converts through Celsius because its three units relate by an affine
formula rather than a common factor; every other dimension converts by
`value * in_factor / out_factor` against one base unit per dimension, and a
conversion across dimensions is refused rather than guessed.

`POST /api/tools/calculator` carries one JSON body naming `expression` and
answers the value, the normalized expression, and the units the request
named. The route sits behind an injectable session check that defaults to
refused, matching `web/artifacts.py`'s `session_refused`: a caller that wires
no session authority serves nothing rather than serving everyone.
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from decimal import (
    ROUND_HALF_EVEN,
    Context,
    Decimal,
    DecimalException,
    DivisionByZero,
    InvalidOperation,
    localcontext,
)
from typing import cast

from qwen_apu.web.http import Request, Response, Route

CALCULATOR_ROUTE = "/api/tools/calculator"

MAX_EXPRESSION_CHARS = 1024
MAX_NESTING_DEPTH = 32
MAX_EXPONENT = Decimal(1000)
DECIMAL_PRECISION = 34

FUNCTION_TABLE = frozenset({"sqrt", "abs", "round", "min", "max"})
TEMPERATURE_UNITS = frozenset({"c", "f", "k"})
TO_KEYWORD = "to"

# Each entry: unit -> (dimension, factor to the dimension's base unit).
# Every factor is exact: a repeating decimal (km/h to m/s, for one) is left
# out of the table rather than truncated to an inexact string.
UNIT_TABLE: Mapping[str, tuple[str, Decimal]] = {
    # length, base meter
    "m": ("length", Decimal(1)),
    "km": ("length", Decimal(1000)),
    "cm": ("length", Decimal("0.01")),
    "mm": ("length", Decimal("0.001")),
    "mi": ("length", Decimal("1609.344")),
    "yd": ("length", Decimal("0.9144")),
    "ft": ("length", Decimal("0.3048")),
    "in": ("length", Decimal("0.0254")),
    # mass, base kilogram
    "kg": ("mass", Decimal(1)),
    "g": ("mass", Decimal("0.001")),
    "mg": ("mass", Decimal("0.000001")),
    "lb": ("mass", Decimal("0.45359237")),
    "oz": ("mass", Decimal("0.028349523125")),
    # data size, base byte -- SI decimal and IEC binary prefixes both present
    "b": ("data", Decimal(1)),
    "kb": ("data", Decimal(1000)),
    "mb": ("data", Decimal(1000) ** 2),
    "gb": ("data", Decimal(1000) ** 3),
    "tb": ("data", Decimal(1000) ** 4),
    "kib": ("data", Decimal(1024)),
    "mib": ("data", Decimal(1024) ** 2),
    "gib": ("data", Decimal(1024) ** 3),
    "tib": ("data", Decimal(1024) ** 4),
    # time, base second
    "s": ("time", Decimal(1)),
    "ms": ("time", Decimal("0.001")),
    "min": ("time", Decimal(60)),
    "h": ("time", Decimal(3600)),
    "day": ("time", Decimal(86400)),
    # speed, base meter per second -- each factor is exact by construction
    "mps": ("speed", Decimal(1)),
    "mph": ("speed", Decimal("0.44704")),
    "fps": ("speed", Decimal("0.3048")),
}


class CalculatorRefused(Exception):
    """One refusal: a malformed expression, an over-large operand, or a foreign identifier."""

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


@dataclass(frozen=True, slots=True)
class Result:
    """The evaluated value, the normalized expression, and the units it named."""

    value: str
    expression: str
    unit_in: str | None
    unit_out: str | None


# --- expression tree -------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Num:
    text: str


@dataclass(frozen=True, slots=True)
class Neg:
    operand: Node


@dataclass(frozen=True, slots=True)
class BinOp:
    op: str
    left: Node
    right: Node


@dataclass(frozen=True, slots=True)
class Call:
    name: str
    args: tuple[Node, ...]


Node = Num | Neg | BinOp | Call


# --- tokenizer ---------------------------------------------------------------

_TOKEN_PATTERN = re.compile(
    r"""
    (?P<ws>\s+)
  | (?P<number>\d+(?:\.\d+)?)
  | (?P<ident>[A-Za-z_][A-Za-z_0-9]*)
  | (?P<pow>\*\*)
  | (?P<floordiv>//)
  | (?P<punct>[+\-*/%(),])
    """,
    re.VERBOSE,
)

Token = tuple[str, str]


def _tokenize(expression: str) -> list[Token]:
    tokens: list[Token] = []
    pos = 0
    length = len(expression)
    while pos < length:
        match = _TOKEN_PATTERN.match(expression, pos)
        if match is None:
            raise CalculatorRefused(
                f"the character {expression[pos]!r} at position {pos} is not admitted"
            )
        pos = match.end()
        kind = match.lastgroup or ""
        if kind == "ws":
            continue
        tokens.append((kind, match.group()))
    return tokens


# --- parser ------------------------------------------------------------------


class _Parser:
    """One pass over the token list, tracking parenthesis nesting depth."""

    def __init__(self, tokens: list[Token]) -> None:
        self._tokens = tokens
        self._pos = 0
        self._depth = 0

    def _peek(self) -> Token | None:
        return self._tokens[self._pos] if self._pos < len(self._tokens) else None

    def _advance(self) -> Token:
        token = self._tokens[self._pos]
        self._pos += 1
        return token

    def _enter_paren(self) -> None:
        self._depth += 1
        if self._depth > MAX_NESTING_DEPTH:
            raise CalculatorRefused(f"nesting exceeds {MAX_NESTING_DEPTH} levels")

    def _leave_paren(self) -> None:
        self._depth -= 1

    def _expect_punct(self, text: str) -> None:
        token = self._peek()
        if token is None or token[1] != text:
            found = token[1] if token else "the end of the expression"
            raise CalculatorRefused(f"expected {text!r}, found {found!r}")
        self._advance()

    def parse_statement(self) -> tuple[Node, str | None, str | None]:
        tree = self.parse_expr()
        unit_in: str | None = None
        unit_out: str | None = None
        token = self._peek()
        if token is not None:
            unit_in = self._admitted_unit(token)
            self._advance()
            to_token = self._peek()
            if to_token is None or to_token[1] != TO_KEYWORD:
                raise CalculatorRefused("a unit conversion names 'to' and a target unit")
            self._advance()
            out_token = self._peek()
            if out_token is None or out_token[0] != "ident":
                raise CalculatorRefused("a unit conversion names a target unit")
            unit_out = self._admitted_unit(out_token)
            self._advance()
        trailing = self._peek()
        if trailing is not None:
            raise CalculatorRefused(f"unexpected trailing token {trailing[1]!r}")
        return tree, unit_in, unit_out

    @staticmethod
    def _admitted_unit(token: Token) -> str:
        if token[0] != "ident":
            raise CalculatorRefused(f"unexpected token {token[1]!r} where a unit is expected")
        name = token[1]
        if name not in UNIT_TABLE and name not in TEMPERATURE_UNITS:
            raise CalculatorRefused(f"the identifier {name!r} is not in the unit table")
        return name

    def parse_expr(self) -> Node:
        node = self.parse_term()
        while True:
            token = self._peek()
            if token is not None and token[1] in ("+", "-"):
                op = token[1]
                self._advance()
                node = BinOp(op, node, self.parse_term())
            else:
                return node

    def parse_term(self) -> Node:
        node = self.parse_unary()
        while True:
            token = self._peek()
            if token is None:
                return node
            if token[0] == "floordiv":
                self._advance()
                node = BinOp("//", node, self.parse_unary())
            elif token[1] in ("*", "/", "%"):
                op = token[1]
                self._advance()
                node = BinOp(op, node, self.parse_unary())
            else:
                return node

    def parse_unary(self) -> Node:
        token = self._peek()
        if token is not None and token[1] == "-":
            self._advance()
            return Neg(self.parse_unary())
        return self.parse_power()

    def parse_power(self) -> Node:
        base = self.parse_atom()
        token = self._peek()
        if token is not None and token[0] == "pow":
            self._advance()
            return BinOp("**", base, self.parse_unary())
        return base

    def parse_atom(self) -> Node:
        token = self._peek()
        if token is None:
            raise CalculatorRefused("the expression ends where a value is expected")
        kind, text = token
        if kind == "number":
            self._advance()
            return Num(text)
        if text == "(":
            self._advance()
            self._enter_paren()
            inner = self.parse_expr()
            self._expect_punct(")")
            self._leave_paren()
            return inner
        if kind == "ident":
            self._advance()
            if text not in FUNCTION_TABLE:
                raise CalculatorRefused(f"the identifier {text!r} is not in the function table")
            self._expect_punct("(")
            self._enter_paren()
            args: list[Node] = []
            lookahead = self._peek()
            if lookahead is not None and lookahead != ("punct", ")"):
                args.append(self.parse_expr())
                lookahead = self._peek()
                while lookahead is not None and lookahead == ("punct", ","):
                    self._advance()
                    args.append(self.parse_expr())
                    lookahead = self._peek()
            self._expect_punct(")")
            self._leave_paren()
            return Call(text, tuple(args))
        raise CalculatorRefused(f"unexpected token {text!r}")


def _render(node: Node) -> str:
    if isinstance(node, Num):
        return node.text
    if isinstance(node, Neg):
        return f"-{_render(node.operand)}"
    if isinstance(node, BinOp):
        return f"({_render(node.left)} {node.op} {_render(node.right)})"
    return f"{node.name}({', '.join(_render(arg) for arg in node.args)})"


# --- evaluation ----------------------------------------------------------


def _require_arity(name: str, args: list[Decimal], count: int) -> None:
    if len(args) != count:
        raise CalculatorRefused(f"{name} takes {count} argument(s), not {len(args)}")


def _require_at_least(name: str, args: list[Decimal], count: int) -> None:
    if len(args) < count:
        raise CalculatorRefused(f"{name} takes at least {count} argument(s)")


def _eval_call(node: Call) -> Decimal:
    args = [_eval(arg) for arg in node.args]
    if node.name == "sqrt":
        _require_arity("sqrt", args, 1)
        if args[0] < 0:
            raise CalculatorRefused("sqrt of a negative value is refused")
        return args[0].sqrt()
    if node.name == "abs":
        _require_arity("abs", args, 1)
        return abs(args[0])
    if node.name == "round":
        if len(args) not in (1, 2):
            raise CalculatorRefused("round takes one value and an optional digit count")
        digits = args[1] if len(args) == 2 else Decimal(0)
        if digits != digits.to_integral_value():
            raise CalculatorRefused("round takes an integer digit count")
        quantum = Decimal(1).scaleb(-int(digits))
        return args[0].quantize(quantum, rounding=ROUND_HALF_EVEN)
    if node.name == "min":
        _require_at_least("min", args, 1)
        return min(args)
    if node.name == "max":
        _require_at_least("max", args, 1)
        return max(args)
    raise CalculatorRefused(f"the function {node.name!r} is not in the table")


def _eval_binop(node: BinOp) -> Decimal:
    left = _eval(node.left)
    right = _eval(node.right)
    try:
        if node.op == "+":
            return left + right
        if node.op == "-":
            return left - right
        if node.op == "*":
            return left * right
        if node.op == "/":
            return left / right
        if node.op == "//":
            return left // right
        if node.op == "%":
            return left % right
        if node.op == "**":
            if abs(right) > MAX_EXPONENT:
                raise CalculatorRefused(f"an exponent over {MAX_EXPONENT} is refused")
            return left**right
    except DivisionByZero:
        raise CalculatorRefused("division by zero is refused") from None
    except InvalidOperation as error:
        raise CalculatorRefused(f"the operation is undefined: {error}") from None
    raise CalculatorRefused(f"unrecognized operator {node.op!r}")


def _eval(node: Node) -> Decimal:
    if isinstance(node, Num):
        try:
            return Decimal(node.text)
        except InvalidOperation:
            raise CalculatorRefused(f"{node.text!r} is not a valid decimal literal") from None
    if isinstance(node, Neg):
        return -_eval(node.operand)
    if isinstance(node, Call):
        return _eval_call(node)
    return _eval_binop(node)


# --- unit conversion -------------------------------------------------------


def _to_celsius(unit: str, value: Decimal) -> Decimal:
    if unit == "c":
        return value
    if unit == "f":
        return (value - 32) * Decimal(5) / Decimal(9)
    return value - Decimal("273.15")  # k


def _from_celsius(unit: str, celsius: Decimal) -> Decimal:
    if unit == "c":
        return celsius
    if unit == "f":
        return celsius * Decimal(9) / Decimal(5) + 32
    return celsius + Decimal("273.15")  # k


def _convert(value: Decimal, unit_in: str, unit_out: str) -> Decimal:
    in_temperature = unit_in in TEMPERATURE_UNITS
    out_temperature = unit_out in TEMPERATURE_UNITS
    if in_temperature or out_temperature:
        if in_temperature != out_temperature:
            raise CalculatorRefused("a temperature unit converts only to another temperature unit")
        return _from_celsius(unit_out, _to_celsius(unit_in, value))
    in_dimension, in_factor = UNIT_TABLE[unit_in]
    out_dimension, out_factor = UNIT_TABLE[unit_out]
    if in_dimension != out_dimension:
        raise CalculatorRefused(f"{unit_in!r} and {unit_out!r} belong to different dimensions")
    return value * in_factor / out_factor


# --- entry point -----------------------------------------------------------


def evaluate(expression: str) -> Result:
    """Evaluate one expression, refusing what the tokenizer, the parser, and the caps reject."""
    if len(expression) > MAX_EXPRESSION_CHARS:
        raise CalculatorRefused(f"an expression over {MAX_EXPRESSION_CHARS} characters is refused")
    tokens = _tokenize(expression)
    if not tokens:
        raise CalculatorRefused("the expression carries no tokens")
    tree, unit_in, unit_out = _Parser(tokens).parse_statement()
    with localcontext(Context(prec=DECIMAL_PRECISION)):
        try:
            value = _eval(tree)
            if unit_in is not None and unit_out is not None:
                value = _convert(value, unit_in, unit_out)
        except CalculatorRefused:
            raise
        except DecimalException as error:
            raise CalculatorRefused(
                f"the arithmetic is undefined or exceeds {DECIMAL_PRECISION} digits: {error}"
            ) from None
    normalized = _render(tree)
    if unit_in is not None and unit_out is not None:
        normalized = f"{normalized} {unit_in} {TO_KEYWORD} {unit_out}"
    return Result(value=str(value), expression=normalized, unit_in=unit_in, unit_out=unit_out)


# --- HTTP route --------------------------------------------------------------


def session_refused(request: Request) -> bool:
    """The default session check: no session admits a call.

    Defaulting to refused rather than to admitted keeps this module's tests
    standing alone without widening what an unconfigured mount serves, the
    rule `web/artifacts.py`'s own `session_refused` states.
    """
    return False


@dataclass(frozen=True, slots=True)
class CalculatorSettings:
    """The injectable session check the route runs ahead of every evaluation."""

    session_admits: Callable[[Request], bool] = session_refused


def _body(request: Request) -> Mapping[str, object]:
    try:
        parsed: object = request.json()
    except ValueError:
        raise CalculatorRefused("the request body is not JSON") from None
    if not isinstance(parsed, dict):
        raise CalculatorRefused("the request body is not a JSON object")
    return cast(Mapping[str, object], parsed)


def _string(body: Mapping[str, object], key: str) -> str:
    value = body.get(key)
    if not isinstance(value, str) or not value:
        raise CalculatorRefused(f"{key} is absent or is not a nonempty string")
    return value


def _json(status: int, payload: object) -> Response:
    return Response(
        status,
        json.dumps(payload, separators=(",", ":")).encode("utf-8"),
        {
            "content-type": "application/json",
            "cache-control": "no-store",
            "x-content-type-options": "nosniff",
        },
    )


def calculate(settings: CalculatorSettings, request: Request) -> Response:
    """Evaluate one request's `expression`, behind the injectable session check."""
    if not settings.session_admits(request):
        return _json(401, {"error": "the request carries no admitted session"})
    try:
        body = _body(request)
        result = evaluate(_string(body, "expression"))
    except CalculatorRefused as refusal:
        return _json(400, {"error": refusal.message})
    return _json(
        200,
        {
            "value": result.value,
            "expression": result.expression,
            "unit_in": result.unit_in,
            "unit_out": result.unit_out,
        },
    )


def routes(settings: CalculatorSettings) -> tuple[Route, ...]:
    """The one calculator route, gated by its own settings' session check."""
    return (Route.make("POST", CALCULATOR_ROUTE, lambda request: calculate(settings, request)),)
