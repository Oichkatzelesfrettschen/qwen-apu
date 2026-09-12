# The served page's layout

`static/index.html` and `static/app.css` carry the whole presentation. The
gateway serves them under `script-src 'self'; style-src 'self'`, so the page
holds one module script, one stylesheet link, no inline block, and no `style`
attribute, and `tests/test_static_page.py` is what keeps that true.

## Before

One header row carried the brand, four status sentences, the pairing field, the
three toggles, and a New conversation button, wrapping across the full width.
Two tab buttons sat under it as an underlined bar. The conversation rail held
four stacked full-width buttons above the list. The composer was a flat row of
attach, textarea, and a rectangular send button pinned to the bottom of the
window. The llama.cpp UI tab opened three explanatory paragraphs. An unpaired
page stated `health returned HTTP 401` beside a sentence asking for a pairing
code.

## After

| Region | Element | What binds it |
| --- | --- | --- |
| Rail | `aside#conversation-panel` | `renderConversationList` writes `.conversation-row` entries into `#conversation-list`; `initConversationPanel` binds `#conversation-new` and `#conversation-temporary`; `initHistoryExport` binds `#conversation-export`; `deleteAllSavedConversations` binds `#conversation-delete-all` |
| Status band | `header#topbar` | `probeHealth` writes `#health`, `boot` and `selectRequestModel` write `#model`, `#model-tier`, and `#ctx`; `selectTab` sets `aria-selected` on `#tab-chat` and `#tab-llama`; `initChatControls` binds `#clear` as the plus |
| Pairing card | `div#pair-card` | `applySessionModeToUi` hides the card and the three controls inside it from one fact, `session.paired === false` |
| Thread | `div#thread` | `#greeting` shows while `#log` is empty; `chat.js` and `conversations.js` append `.turn` elements to `#log` |
| Composer | `footer#composer` | `initAttachments` binds `#file` and writes `#attached`; `initChatControls` binds `#input`, `#send`, and `#reasoning`; `initToolToggles` clears `#web-tools` and `#image-tools`; `initModelPicker` fills `#model-picker` |

The rail is a fixed 16 rem dark column: a brand line, New conversation and
Temporary as the two top actions, a Recent conversations heading over the
scrolling list, and an export and delete-all footer beside the storage and
export status lines. The main column is a flex column: the status band, then
whichever tab is open.

The greeting is CSS rather than script. `#log` carries no whitespace between
its tags, so `#thread:has(#log:empty)` matches exactly while the transcript is
empty; that selector centers the column and reveals `What should we work on?`
above the composer, and the first appended turn ends both. A browser without
`:has()` shows the composer docked at the foot of the column with no greeting,
which is the same page minus one line.

The composer is one pill. The plus menu is a `details` element, so it opens
from the keyboard and closes on a second activation with no script, and the
file input sits inside it behind an `Add files` label. The three toggles are
compact chips, the model picker is an inline `select`, and send is a round
button carrying an inline SVG arrow with `aria-label="Send"`.

Transcript styling follows the llama.cpp UI reference the appliance already
serves: a centered 48 rem column, the user turn in a rounded bubble, the
per-turn statistics `chat.js` already writes (`tok/s prefill`, `tok/s decode`,
token counts) as the dim `.meta` line beneath the turn, and reasoning folded
under the existing `details.think` summary above the answer.

## Status, pairing, and tabs

The four status sentences collapse into one wrapping line of health, model,
tier badge, and context. The line wraps rather than truncating because `#model`
and `#health` are error channels: `pairing refused: <reason>` and
`health unreachable: <message>` are written there, and an ellipsis would hide
the only text naming the fault. The static Raven2 sentence leaves the page; the
README and the doctrine carry it.

Pairing becomes one card shown while unpaired, holding the heading, the hint
naming where the code prints, the labelled field, and one button. `probeHealth`
answers a 401 with `not paired yet`, since 401 is the session gate rather than
the model.

The two tabs become a segmented control in the status band keyed off
`aria-selected`, which `selectTab` already sets. The llama.cpp UI note is two
paragraphs naming the gateway, `/api/chat`, and the three surfaces this page
alone carries.

## Accessibility

Every input carries a label, visually hidden where the placeholder already
names it. `:focus-visible` draws a 2 px ring on every control. The three
tabs carry `role="tablist"` and `role="tab"` over the `aria-selected`
`selectTab` already writes, with each tab naming the panel it opens, and the
three toggles carry `role="switch"` on the checkbox itself: the modules read and
write `.checked` on those three ids, so they stay checkboxes, and a switch
checkbox reports its state as native `aria-checked` with no script. An
`aria-pressed` attribute on the enclosing label would require `role="button"`
on the label, which costs the `.checked` property three modules depend on, so
the switch role is what carries the pressed semantic instead.

## Contracts

Every id the modules query and the tests read stays. Seven ids are added:
`#pair-card`, `#status-line`, `#greeting`, `#chat-band`, `#thread`,
`#rail-brand`, and `#rail-footer`. Two module edits carry the layout:
`applySessionModeToUi` hides `#pair-card` beside the three controls, guarded so
a page without the card still pairs, and `probeHealth` names the 401.
`test-ui-switch.mjs` reads the markup by byte, so `<section class="notice"
id="llama-ui-panel"` stays verbatim and the notice stays the only `section` in
the file.

## Scope cuts

The reference UI's per-message action row (copy, edit, regenerate, delete) is
behavior rather than layout and reaches `chat.js` and the conversation record;
it is not delivered here. The plus menu's Off/Low/Medium/High/Max reasoning
submenu needs a level field on `POST /api/chat` and a server that reads it;
until a route carries a level, a five-level menu over a boolean would display a
setting the request never sends, so the honest boolean chip stays. Sidebar
Search and Settings entries name no route this gateway answers.
