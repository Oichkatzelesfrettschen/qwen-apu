# The web research MCP server

`server.py` speaks MCP over stdio and offers two tools, `search_exa` and
`fetch_exa`. llama-server composes the configured server name with each tool
name, so the name `web` in `--mcp-servers-config` produces `web_search_exa` and
`web_fetch_exa`, which the pinned llama-ui renders natively from the
`Title:`/`URL:`/`Published:`/`Author:`/`Highlights:` block layout and the `---`
separator. A server named `exa` would produce `exa_web_search_exa` and reach the
generic renderer instead.

## Launch

`mcp-servers.example.json` carries the launch shape: command, args, env, cwd,
and `timeout_ms`, with placeholder paths for the two key files.

```sh
llama-server --mcp-servers-config /path/to/mcp-servers.json
```

`--provider`, `--exa-key-file`, `--token-key-file`, and `--fixtures` override
`QWEN_WEB_PROVIDER`, `QWEN_WEB_EXA_KEY_FILE`, `QWEN_WEB_TOKEN_KEY_FILE`, and
`QWEN_WEB_FAKE_FIXTURES`.

## The result identifier carries the state the process cannot

llama-server spawns the child to enumerate tools, kills it, and spawns it again
for each invocation, so nothing held in memory survives between two calls. A
search therefore signs each result into a token: base64url of a JSON claim
naming the canonical URL, provider, issue time, expiry, and search identifier,
followed by a dot and the base64url HMAC-SHA256 of that payload string under the
signing key. `fetch_exa` verifies the signature with `hmac.compare_digest`,
checks the expiry, and fetches the canonical URL the claim names. A URL the
model writes carries no signature and is refused, so the tool surface reaches
pages a prior search returned and nothing else.

The token lives 900 seconds. The child holds no registry, so the expiry is what
bounds replay of a leaked token, and the lifetime covers a reasoning turn while
staying short against a transcript that outlives the session. `search_id`
records which search issued a token and is provenance rather than an enforced
check, since a registry to check it against would need state the process lacks.

## Two key files, paths alone in the environment

The Exa API key and the HMAC signing key each live in a file that only its owner
reads, and the launch configuration passes the paths. Each file is read at call
time, so a replaced key takes effect on the next invocation, and the mode is
checked at the same moment: a file with any group or world bit set refuses the
call and reports its octal mode. The key contents reach the `x-api-key` header
and the HMAC alone, so they stay out of the argument vector, the environment
values, stderr, and every error message.

## Caps

Query 512 characters, results 1 to 10, each domain list 10 entries, fetch window
24000 characters with 12000 the default, and a request timeout of 20 seconds.
The 4 MiB cap is a document-size limit: the HTTP body is read to one byte past
it so an oversized response is refused during the read, and a content record
above it is refused rather than truncated, which puts a document larger than the
cap out of reach of `start_index` paging as well. A fetched body decodes as
strict UTF-8; anything else is refused rather than substituted.

## Fetched text is quarantined in its wrapper

`fetch_exa` returns the page text inside a fixed frame:

```text
UNTRUSTED WEB CONTENT
Source: <url>
Retrieved: <utc>
Content SHA-256: <hex>
<text>
END UNTRUSTED WEB CONTENT
```

The digest identifies the exact returned window, and the frame marks where
attacker-controlled text begins and ends. `search_exa` returns titles, URLs,
and highlights, and the page body reaches the model through the wrapper alone.

## Providers

`Provider` declares `search()` and `contents()`. `ExaProvider` posts to Exa's
`/search` and `/contents` JSON endpoints over urllib with the key in the
`x-api-key` header. `QWEN_WEB_PROVIDER=fake` selects `FakeProvider`, which
serves a fixture document named by `QWEN_WEB_FAKE_FIXTURES`, mapping a query to
a result list and a canonical URL to a content record. A content record supplies
`text`, or `text_base64` for a fixture that carries bytes which are invalid
UTF-8 while the fixture file stays a legal UTF-8 JSON document.

## Test

```sh
PYTHONDONTWRITEBYTECODE=1 python3 remote/web-mcp/test-web-mcp.py
```

The test spawns the server the way llama-server spawns it, writes its fixtures
into a temporary directory, and runs with the fake provider, so it needs no
network and no key of its own.
