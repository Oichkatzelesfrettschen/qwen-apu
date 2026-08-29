# The web provider capability contract

A search argument reaches the web MCP child through a human approval. The
dialog in `webui/index.html` names the query, the publication interval, both
domain lists, the result count, and whether `max_age_hours` of 0 forces a live
crawl, and `remote/web-mcp/authorize-broker.py` signs a single-use grant over
those exact fields. `enforce_search_authorization` in
`remote/web-mcp/server.py` compares the call's arguments against that claim
field by field, so the arguments the provider receives are the ones a person
read.

A backend that silently drops one of those fields answers a different question
than the one approved. `Provider` therefore declares five capability flags and
`refuse_unhonored_arguments` refuses an authorized argument the active provider
cannot carry, naming both the argument and the provider in an `isError` result.
The refusal runs in `call_search` after `select_provider` and `preflight` and
before `ledger.consume_search`, which is the same ordering every other local
configuration check takes: the grant's single use stays available to a
corrected call.

## The five flags

| Flag | What it states |
| --- | --- |
| `supports_exact_date_bounds` | `published_after` and `published_before` reach the request as a calendar interval. |
| `supports_freshness_max_age` | `max_age_hours` bounds the age of the copy served. `freshness_max_age_hours` narrows it to the values one backend expresses; None admits every value the argument's own bounds allow. |
| `supports_domain_filter` | `include_domains` and `exclude_domains` bound the sources. |
| `supports_num_results` | `max_results` bounds the returned count. |
| `supports_paging` | The backend returns further pages of one result set. |

A flag reads true where the argument is honored, whether the provider's own
request field carries it or the wrapper enforces it over the response.
`filter_by_domains` drops an off-domain record before the renderer signs a
Result ID for it, and `call_search` slices to the granted count, both over
whatever any provider returns, so `supports_domain_filter` and
`supports_num_results` read true for a backend whose request carries neither.

`supports_paging` gates no argument. `fetch_exa`'s `start_index` pages the
document snapshot the ledger stores, which is wrapper state rather than a
provider result page, so the flag records the surface a later argument would
consult.

| Provider | date bounds | freshness | domains | count | paging |
| --- | --- | --- | --- | --- | --- |
| `exa` | yes | yes, any value | yes | yes | no |
| `fake` | yes | yes, any value | yes | yes | no |
| `searxng` | no | four named windows | yes, in the wrapper | yes, in the wrapper | yes |

Exa keeps every field optional. Its Search API reads `startPublishedDate`,
`endPublishedDate`, `includeDomains`, `excludeDomains`, and `numResults` at the
request top level and `maxAgeHours` inside `contents`, so a grant naming any
combination reaches the provider unchanged and no capability refusal fires
against it. The fake provider answers from a fixture document and meets the
same wrapper enforcement, so a fixture run reaches the refusals a live run
reaches.

## SearXNG

`SearXNGProvider` issues `GET {base}/search?q=...&format=json` and reads the
`results` array. The response carries result metadata and no page text, so
`contents` retrieves the source itself over one GET of the exact canonical URL
a prior search signed into a Result ID.

### The time_range mapping

SearXNG expresses publication recency as one of four named windows, so an hour
count maps onto the window whose length it equals and every other value leaves
the contract:

| `max_age_hours` | `time_range` |
| --- | --- |
| 24 | `day` |
| 168 | `week` |
| 720 | `month` |
| 8760 | `year` |

`month` is the 30-day convention SearXNG applies and `year` is 365 days. A
value off those four -- including the 0 that means force a live crawl, which
the instance cannot express at all -- refuses the call naming the argument, the
provider, and the four admitted counts. An omitted `max_age_hours` sends no
`time_range` and leaves the instance's own ranking.

### The pinned engine set

`QWEN_WEB_PROVIDER=searxng` names one engine population: the independently
crawled indexes and the two Wikimedia sources, which serve their own data and
reach no commercial search API.

| Engine | What it is |
| --- | --- |
| `mwmbl` | Community-run crawler and index |
| `marginalia` | Independent crawler weighted toward non-commercial pages |
| `wiby` | Independent index of hand-submitted pages |
| `yacy` | Peer-to-peer index |
| `wikipedia` | Wikimedia article search |
| `wikidata` | Wikimedia structured-data search |

`QWEN_WEB_SEARXNG_ENGINES` narrows or reorders that set. An engine outside it
is refused by name, in `remote/build-web-presets.sh` where the operator sets it
and again in `SearXNGProvider.__init__` before the first request, because a
SearXNG instance also proxies scraper-backed engines and admitting one through
this provider would change what `searxng` means for every profile that already
names it. A broader engine population is a provider of its own --
`searxng-broad` -- with its own capability declaration and its own admission
record.

### Configuration

| Name | Effect |
| --- | --- |
| `QWEN_WEB_SEARXNG_URL` | The instance base URL. Required. |
| `QWEN_WEB_SEARXNG_ENGINES` | Comma list narrowing the pinned set. Default: the whole set. |
| `QWEN_WEB_SEARXNG_LANGUAGE` | `language` request field. Omitted where unset. |
| `QWEN_WEB_SEARXNG_SAFESEARCH` | `safesearch` request field, one of 0, 1, 2. Omitted where unset. |
| `QWEN_WEB_SEARXNG_ALLOW_REMOTE` | `1` admits an instance URL outside loopback. |

`require_loopback_endpoint` reads the base URL the way `require_public_host`
reads a result host and with the opposite polarity: the literal address and the
reserved `localhost` name classify it, no hostname resolves in the process, and
a host that is neither is refused. An SSH-forwarded loopback port therefore
reaches a remote instance while a bare hostname refuses, and
`QWEN_WEB_SEARXNG_ALLOW_REMOTE=1` is the operator's statement that the
model-authored query may leave the machine.

`remote/build-web-presets.sh` emits the required URL and each tuning name the
operator set, so an unset one leaves the child reading its own default rather
than an empty string. The `searxng` branch reads no key file, because the
instance is unauthenticated and this provider holds no secret at all.

### What the retrieval keeps and what it costs

Every wrapper guard applies unchanged. A SearXNG result is mapped into the
record shape the renderer already reads -- `url`, `title`, `publishedDate`, the
instance's `content` snippet as the single highlight, and `engine` -- so
`canonical_url` runs `require_public_host` over each URL before a Result ID is
signed, `issue_result_id` signs the same claim, `open_search` records the
profile's fetch allowance, and `reserve_fetch` meters the redemption. A
metasearch instance indexes what its engines return, so a result naming
loopback, an RFC 1918 address, or a legacy numeric spelling of one refuses the
search rather than issuing a fetchable reference for it.

`Engine:` is a new rendered line, placed after `Trust:` and before
`Highlights:`. The pinned llama-ui reads everything after `Highlights:` up to
the `---` separator as highlight text and `webui/index.html` reads the block for
`Result ID:` and the trailing separator, so the line sits outside both parse
regions. A record carrying no engine renders no line, which leaves an Exa block
byte-identical to what it was.

`contents` costs two things a page-text provider does not. The retrieval runs
through `PROVIDER_OPENER`, which ends a redirect at the response that requested
it, so a page that answers only behind a redirect fails: the Result ID is
signed over one canonical URL and following a redirect would return a document
from a host the signature never covered. The declared content type also decides
admission -- `text/html`, `application/xhtml+xml`, and `text/plain`, in UTF-8 or
ASCII -- so a PDF or a non-UTF-8 page is named by its type rather than reaching
the decode as a byte error. Both are limitations of this provider rather than
defects to work around.

`HtmlTextExtractor` reduces an HTML response to its readable text, dropping
`script`, `style`, `noscript`, `template`, `svg`, and `head` contents and
ending a line at each block element. A parser failure returns the raw document,
because the frame around the window already states that the content is
untrusted and a refusal there would let a broken page deny a fetch its Result ID
bought.

## Tool names

The tools stay `search_exa` and `fetch_exa`, which llama-server composes with
the MCP server name `web` into `web_search_exa` and `web_fetch_exa`. The
identifiers are written into `webui/index.html`, `remote/admit-web-router-fake.sh`,
and `evidence/web-admission-fake.md`, and the pinned llama-ui renders those two
natively, so a provider-neutral rename is a change across the page, the
admission harness, and two evidence records rather than a change in one place.
The names are a follow-up rather than part of the provider.

## What is unmeasured

No run of this provider against a live SearXNG instance is retained. Every
result here comes from `remote/web-mcp/test-web-mcp.py`, which stands a
standard-library HTTP server on loopback in the instance's place and in the
source page's place. That covers the request the provider composes, the mapping
it applies, every refusal the contract states, the deadline, and the wrapper
guards around a fetch; it establishes nothing about result quality, coverage,
or latency from the six engines, and nothing about how often a real page is
lost to the redirect refusal or the content-type gate.

`remote/admit-web-router-fake.sh` runs the router path on the appliance against
the fake provider and has not been run against `searxng`.
