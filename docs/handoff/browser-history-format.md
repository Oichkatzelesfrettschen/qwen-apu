# Browser history format

`webui/index.html` is the whole authority for what a browser holds of a
conversation. This file names the stored shape by file:line reference and
defines the export document `src/qwen_apu/web/browser_import.py` reads,
because the page emits no export today.

## The three stores, one record shape

`webui/index.html:4081-4102` states the mechanism: three stores answer in
order, IndexedDB first, `localStorage` where IndexedDB refuses, an in-memory
`Map` where both refuse, and every one of them holds the same JSON-shaped
record keyed by conversation id. The record is a projection: role, content,
the served model id, tool call ids and arguments, and an artifact's digest,
provenance route, seed, and geometry. A broker grant, the session secret, and
the API key reach no projection, so a store dump authorizes nothing on its
own (`webui/index.html:4091-4099`).

### IndexedDB

- Database name `qwen-apu-conversations`, version 1
  (`webui/index.html:4103-4104`).
- One object store, `conversations`, key path `id`
  (`webui/index.html:4105`, `4163-4164`).
- `openConversationDatabase` (`webui/index.html:4156-4168`) creates the store
  on `upgradeneeded` if it is absent; it never runs a migration between
  versions because version 1 is the only version this page has shipped.
- `indexedDatabaseConversationStore` (`webui/index.html:4170-4224`) reads with
  `store.getAll()` for `list()` and `store.get(id)` for `read()`, and commits
  every write on `transaction.oncomplete` rather than on the request's own
  `onsuccess`, so a read racing a resolved write still sees the prior record
  until the transaction commits (`webui/index.html:4179-4184`).

### localStorage fallback

- One index entry per conversation under the key
  `qwen-apu-conversation-index`, a JSON array of
  `{id, title, updated}` (`webui/index.html:4106`, `4132-4138`,
  `4235-4248`).
- One full record per conversation under
  `qwen-apu-conversation:<id>` (`CONVERSATION_RECORD_PREFIX`,
  `webui/index.html:4107`, `4257-4261`).
- The currently open conversation id, if any, under
  `qwen-apu-conversation-selected` (`CONVERSATION_SELECTED_KEY`,
  `webui/index.html:4108`, `4406-4408`).
- A demotion marker, `qwen-apu-conversation-store-demoted`, a JSON array of
  store names (`indexeddb`, `localstorage`) this browser has proven refuse a
  write; it persists across reloads and is never itself conversation data
  (`webui/index.html:4304-4321`).
- Two credential-shaped keys share this same storage area and carry no
  conversation content: `qwen-apu-api-key` (`webui/index.html:371, 391, 443`)
  and `qwen-apu-broker-origin` (`webui/index.html:1508, 1513`). A dump of raw
  `localStorage` therefore is not itself the export format; the export format
  below carries only `CONVERSATION_RECORD_PREFIX` records.

### In-memory fallback

`memoryConversationStore` (`webui/index.html:4281-4291`) holds the same
record shape in a `Map` for the page's lifetime alone; nothing here survives
a reload, so it has no bearing on an import document, which by construction
reads what a browser persisted.

## The record

One record, `{id, title, updated, messages}`, built at save time
(`saveConversation`, `webui/index.html:4578-4600`):

| Field | Type | Note |
| --- | --- | --- |
| `id` | string, `/^[A-Za-z0-9_-]{1,64}$/` | `CONVERSATION_ID_PATTERN`, `webui/index.html:4110` |
| `title` | string | `conversationTitle`, capped at 60 characters at the point it is set (`CONVERSATION_TITLE_CHARACTER_CAP`, `webui/index.html:4109, 4419-4424`); falls back to `'untitled'` at save time (`webui/index.html:4587`) |
| `updated` | number | `Date.now()`, epoch milliseconds (`webui/index.html:4588`) |
| `messages` | array | `conversationMessages`, see below |

The record carries no `created` field. Nothing in `webui/index.html` records
when a conversation began; `updated` is rewritten on every save
(`webui/index.html:4588`) and is the only timestamp the record holds, at
conversation granularity. No message carries its own timestamp either --
`rememberUserMessage`, `rememberAssistantMessage`, and `rememberToolMessage`
(`webui/index.html:4410-4453`) write no time field into any entry.

### Message entries

`role` distinguishes the three entry shapes `conversationMessages` holds.

**`role: 'user'`** -- `rememberUserMessage`, `webui/index.html:4410-4426`:

| Field | Type | Note |
| --- | --- | --- |
| `content` | string | the durable text sent to the model; an image attachment is replaced by an inline omission note rather than carried as bytes (`webui/index.html:3953-3957`) |
| `shown` | string | display-only text, the typed prompt plus `[name]` per attachment (`webui/index.html:3949-3950`); `restoredUserText` prefers this over `content` for the log (`webui/index.html:4735-4751`) |
| `omitted_attachments` | array, optional | present only when an image was stripped; each entry is `{name, mime}` (`webui/index.html:4412-4417`) |

**`role: 'assistant'`** -- `rememberAssistantMessage`,
`webui/index.html:4428-4447`:

| Field | Type | Note |
| --- | --- | --- |
| `content` | string | the answer text, `''` where the model returned none |
| `model` | string | the served model id the response badge names |
| `reasoning` | string | reasoning text shown beside the answer, `''` where none was shown |
| `artifacts` | array | image records this entry owns, appended by `rememberArtifact` (`webui/index.html:4467-4491`); each is `{reference, sha256, provenanceUrl, prompt, seed, width, height, steps, profile}` |
| `tool_calls` | array, optional | present only when the model proposed calls; each is `{id, type: 'function', function: {name, arguments}}` (`webui/index.html:4436-4442`) |

**`role: 'tool'`** -- `rememberToolMessage`, `webui/index.html:4449-4453`:

| Field | Type | Note |
| --- | --- | --- |
| `tool_call_id` | string | the id the matching assistant entry's `tool_calls` proposed |
| `name` | string | the tool name |
| `content` | string | the tool result text |

## The credential this page never persists into a record

`webui/index.html:378-394` reads a one-time bearer from a URL fragment of the
form `#key=<bearer>`, decodes it, and assigns it to the in-memory `apiKey`
before dropping the fragment; the pattern is `/^#key=([^&#]+)/`
(`webui/index.html:385`). This value, and the API key `localStorage` also
caches under `qwen-apu-api-key` (`webui/index.html:371, 391, 443`), never
enter a conversation record: `saveConversation` writes only `id`, `title`,
`updated`, and `messages` (`webui/index.html:4585-4590`). An import document
that carries a string matching the fragment pattern, or a key named for a
bearer, token, secret, grant, API key, or cookie, is not a conversation
export this page produced and `browser_import.py` refuses it whole.

## The export path today

No export function exists. Every use of `Blob` and `URL.createObjectURL` in
`webui/index.html` builds a downloadable image artifact
(`webui/index.html:3337-3338, 3419-3424, 4679-4684`), never a conversation
document, and no `download`-attribute link, no menu item, and no route in
this file writes conversation JSON to the user. `WEBUI.md:212-218` describes
the same three stores and the same projection and names no export route
either. A user today reaches conversation JSON only by reading `localStorage`
or the IndexedDB inspector in the browser's own developer tools, by hand, one
`qwen-apu-conversation:<id>` key or one `conversations` object-store record
at a time.

## The minimal `Export history` document this page should emit

Until the page grows an `Export history` button, `browser_import.py` defines
and reads one JSON document shape carrying the IndexedDB records verbatim
under a version key:

```json
{
  "qwen_apu_browser_history_export": 1,
  "exported_utc": "2026-09-11T00:00:00Z",
  "conversations": [
    {
      "id": "c1a2b3",
      "title": "a short heading",
      "updated": 1757548800000,
      "messages": [
        {"role": "user", "content": "...", "shown": "..."},
        {"role": "assistant", "content": "...", "model": "qwen3.8-2b-distill",
         "reasoning": "", "artifacts": []}
      ]
    }
  ]
}
```

`qwen_apu_browser_history_export` names the version this document was written
under; `browser_import.py` reads version `1` and refuses any other value.
`exported_utc` is metadata about the export itself, not about any
conversation, and is optional. `conversations` is the array of records this
page's `conversationStore().list()` plus one `read(id)` per listed id would
produce were a button wired to walk it -- each entry is exactly the record
`saveConversation` already writes (`webui/index.html:4584-4590`), unmodified.
Building that button is `Export history`'s whole remaining work: serialize
`await Promise.all((await (await conversationStore()).list()).map(entry =>
(await conversationStore()).read(entry.id)))` into the `conversations` array
above and offer it through a `Blob`/`download` link, the same mechanism the
image artifact download already uses (`webui/index.html:3419-3424`).
