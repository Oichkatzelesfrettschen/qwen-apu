# SearXNG and YaCy native install provenance

This file is a template. `remote/install-searxng.sh` and `remote/install-yacy.sh`
run on the laptop, not on the workstation this tree is edited from, so every
field below reads `-` until a laptop run fills it in. A field left `-` after a
run states that the run did not reach that check; it is never filled with an
assumed or predicted value.

## SearXNG

```text
upstream:            https://github.com/searxng/searxng.git
pinned commit:        a30b2d47492ab46ae82ce25ee62a31626565cf67
commit read date:     2026-08-28 (searxng/searxng carries no tags at that date)
install root:         -
installer log sha256: -
settings source:      remote/searxng-settings.yml
settings sha256:      -
installed settings:   /etc/searxng/settings.yml (0640 searxng:searxng)
listener:             -   (must read 127.0.0.1:8888 alone)
GET /search?q=test&format=json: -   (must read 200 with a parseable JSON body)
GET /config:          -   (must name every qwen-* category and its engines)
```

### Confirmed engine table (read from the pinned commit's own
`searx/settings.yml`, `searx/engines/*.py`, and `searx/engines/__init__.py`
before any file in this repository was written; every name below appears in
that tree)

| Category | Engine | Upstream default | This instance |
| --- | --- | --- | --- |
| qwen-open | mwmbl | disabled | enabled |
| qwen-open | wiby | disabled | enabled |
| qwen-open | wikipedia | enabled | enabled |
| qwen-open | wikidata | enabled | enabled |
| qwen-broad | google | disabled | enabled |
| qwen-broad | bing | disabled | enabled |
| qwen-broad | brave | enabled | enabled |
| qwen-broad | duckduckgo | enabled | enabled |
| qwen-broad | startpage | enabled | enabled |
| qwen-broad | qwant | disabled | enabled |
| qwen-broad | mojeek | disabled | enabled |
| qwen-academic | crossref | disabled | enabled |
| qwen-academic | arxiv | enabled | enabled |
| qwen-academic | pubmed | enabled | enabled |
| qwen-academic | wikipedia | enabled | enabled |
| qwen-news | reuters | enabled | enabled |
| qwen-news | google news | enabled | enabled |
| qwen-news | bing news | enabled | enabled |
| qwen-news | brave.news | enabled | enabled |
| qwen-yacy | yacy | disabled | disabled |

`braveapi` is a distinct, key-gated engine the pinned tree also ships; this
instance enables `brave` (the web engine) and leaves `braveapi` untouched at
its upstream default. Every engine name above was verified present in the
pinned tree; none were guessed.

### Live verification (`remote/install-searxng.sh` fills this after a real run)

```text
verified engine table:
-
```

## YaCy

```text
upstream:                   https://github.com/yacy/yacy_search_server.git
pinned tag:                 Release_1.941
pinned commit:               f0464e7fbcfcb69127f0325910f92f113ce23677
tag read date:               2026-08-28 (git ls-remote --tags --sort=-v:refname)
release tarball SHA-256:     -  (not confirmed; see "could not confirm" below)
install directory:           -
build command:                ant clean all
build log sha256:             -
yacy.conf sha256:             -
listener:                     -   (must read 127.0.0.1:8090 alone, after an
                                    explicit remote/yacy-control.sh start)
java major version measured:  -
```

## Could not confirm

- A published SHA-256 for a YaCy release tarball or binary distribution. YaCy
  publishes releases at `download.yacy.net`, which sits outside this task's
  network allowance of `github.com` and `docs.searxng.org`. `install-yacy.sh`
  pins the release tag's own commit (a git SHA-1, read from `github.com` with
  `git ls-remote --tags`) and builds from that pinned source with
  `ant clean all`, the path `yacy_search_server`'s own `README.md` documents,
  rather than downloading a tarball whose checksum this run never read. A
  tarball SHA-256 stays `-` above rather than an invented value.
- Any `reuters` API-key or subscription requirement at request time. The
  engine module `searx/engines/reuters.py` is present and enabled with no
  `disabled: true` in the pinned `searx/settings.yml`, which is what admits
  it to `qwen-news`; whether a live request against it succeeds without
  further credentials is unconfirmed until a laptop run's `GET /config` and a
  live search both return.

## Known interaction: crossref's per-engine timeout against max_request_timeout

`searx/search/__init__.py`'s `_get_requests` sets `actual_timeout =
min(default_timeout, max_request_timeout)`, where `default_timeout` is the
max of every selected engine's own `timeout`. `crossref`'s block in the
pinned `searx/settings.yml` carries `timeout: 30`, which this instance's
`max_request_timeout: 8.0` caps to 8 seconds regardless. A crossref query
that upstream expected to need up to 30 seconds routinely times out under
this instance's outgoing tuple; this is a consequence of the design facts
this file was built from, not a bug in `remote/searxng-settings.yml`, and a
laptop run's live search against `qwen-academic` should confirm whether 8
seconds is enough in practice.
