# Architecture — BuffTextNotifications

## Overview

BuffTextNotifications is a single-file addon with no libraries and no addon table.
It has one job: turn the player's Cooldown Manager tracked-spell sets into a live
text list of which of those buffs are currently on the player.

The pipeline is short:

```
C_CooldownViewer category set (2, 3)
        -> cooldown IDs
        -> C_CooldownViewer.GetCooldownViewerCooldownInfo -> info.spellID
        -> C_Spell.GetSpellName                           -> name
        -> trackedNames[category]  (sorted)
                                                     |
UNIT_AURA (player) ---+                              v
1s OnUpdate poll -----+--> RefreshDisplay --> AuraUtil.FindAuraByName(name, "player")
                                                     |
                                                     v
                                        font-string pool (30 lines), frame resized
```

Name resolution and aura checking are deliberately separated. The name list is
expensive-ish and changes rarely, so it is rebuilt only on world entry and on
`COOLDOWN_VIEWER_DATA_LOADED`. The aura check is cheap and runs on every refresh.

The addon initialises from a bare `CreateFrame("Frame")` event listener — no Ace3,
no `LibStub`, no `NewAddon`.

## Module map

There are no modules. The single file is divided into five commented sections.

| Section | Lines | Contents |
| --- | --- | --- |
| 1 — Constants & State | `BuffTextNotifications.lua:6-31` | Frame geometry, `MAX_LINES`, poll interval, `FormatTime`, `trackedNames`, `CATEGORY_DISPLAY` |
| 2 — `C_CooldownViewer` data layer | `BuffTextNotifications.lua:33-55` | `BuildTrackedNames` |
| 3 — Display frame | `BuffTextNotifications.lua:57-189` | `RefreshDisplay`, `CreateDisplayFrame`, drag handlers, `OnUpdate` poll |
| 4 — Event handler | `BuffTextNotifications.lua:191-236` | The single `OnEvent` dispatcher |
| 5 — Slash commands | `BuffTextNotifications.lua:238-274` | `/btn` and its subcommands |

**Ordering constraint:** `RefreshDisplay` is defined before `CreateDisplayFrame` so
that the `OnUpdate` closure captures it as an upvalue rather than performing a
global lookup each tick. Moving it invalidates that.

Every function is `local`. The addon exports nothing and defines no global other
than the saved-variable table, the named frame `BuffTextNotificationsFrame`, and the
two slash-command globals.

## Settings schema

There is no `Schema.lua` and no options database. The saved variable is a flat
global table written directly.

`BuffTextNotificationsDB` — global scope (not per-character, not per-profile):

| Key | Type | Written | Read |
| --- | --- | --- | --- |
| `point` | string | `OnDragStop` (`:160`), `/btn reset` (`:250`) | `ADDON_LOADED` (`:215-217`) |
| `relPoint` | string | `OnDragStop` (`:161`), `/btn reset` (`:251`) | `ADDON_LOADED` (`:217`) |
| `x` | number | `OnDragStop` (`:162`), `/btn reset` (`:252`) | `ADDON_LOADED` (`:217`) |
| `y` | number | `OnDragStop` (`:163`), `/btn reset` (`:253`) | `ADDON_LOADED` (`:217`) |

Frame position is the only persisted state. Everything else a user might want to
change — `FRAME_WIDTH`, `FRAME_HEIGHT`, `LINE_HEIGHT`, `MAX_LINES`, `POLL_INTERVAL`,
`DEFAULT_X`, `DEFAULT_Y` and the per-category colours in `CATEGORY_DISPLAY` — is a
source constant.

## Message bus

None. The addon sends and receives no messages; there is no `AceEvent`, no
`SendMessage`, no callback registry. All coordination is direct function calls
inside the one file.

## Slash commands

Registered as `SLASH_BUFFTEXTNOTIFICATIONS1 = "/btn"` (`:241`) with a single
handler in `SlashCmdList` (`:243`). Dispatch is an `if`/`elseif` chain on the
lower-cased, trimmed argument — there is no `COMMANDS` table.

| Command | Handler | Effect |
| --- | --- | --- |
| `/btn reset` | `:246-255` | Re-points the frame to `CENTER` + (`DEFAULT_X`, `DEFAULT_Y`) and persists that to the saved variable |
| `/btn toggle` | `:257-267` | Hides the frame, or shows it and forces a refresh |
| `/btn` (anything else) | `:269-273` | Prints the two-line command list |

Both `reset` and `toggle` are guarded on `frame` being non-nil, so they are inert
before `ADDON_LOADED` has run.

## Event subscriptions

One frame, four events, one `OnEvent` handler (`:194-236`).

| Event | Filter | Action |
| --- | --- | --- |
| `ADDON_LOADED` | own addon name only | Initialise `BuffTextNotificationsDB`, build the frame, restore saved position |
| `PLAYER_ENTERING_WORLD` | — | `BuildTrackedNames` then `RefreshDisplay` |
| `COOLDOWN_VIEWER_DATA_LOADED` | — | `BuildTrackedNames` then `RefreshDisplay` |
| `UNIT_AURA` | `unitToken == "player"` | Debug print, then `RefreshDisplay` |

Plus the frame's own scripts: `OnDragStart`, `OnDragStop`, and `OnUpdate` (a
one-second accumulator that emits a debug line and calls `RefreshDisplay`).

Note that the addon does not unregister `PLAYER_ENTERING_WORLD`, so the name list is
rebuilt on every zone change and instance transition, not only at login.

## Taint notes

Nothing here touches protected state. The addon creates only its own unsecured
frame, calls no protected API, and hooks nothing Blizzard owns. `SetClampedToScreen`
and the drag scripts are all unprotected. There is no taint surface to document.

## Known limitations

- **Unconditional debug output.** Three `print` calls run in normal play:
  `BuildTrackedNames` (`:51`), the poll tick (`:184`, once per second while the frame
  is shown) and every player `UNIT_AURA` (`:231`). There is no debug flag to turn
  them off.
- **`FormatTime` is dead code.** Defined at `:20-24`, correct, and called from
  nowhere. Durations are not displayed. It is either the start of an unfinished
  feature or a leftover.
- **Category numbers are hardcoded twice.** `trackedNames` is initialised as
  `{ [2] = {}, [3] = {} }` (`:26`) and `BuildTrackedNames` loops `for category = 2, 3`
  (`:39`), while `CATEGORY_DISPLAY` (`:28-31`) keys off
  `Enum.CooldownViewerCategory.TrackedBuff` / `.TrackedBar`. The literal and the enum
  agree today by coincidence.
- **`AuraUtil.FindAuraByName` is player-only and name-matched.** It cannot
  distinguish two auras sharing a name, and it is the reason the addon shows nothing
  for other units. `TODO.md` records the intent to replace it.
- **The poll comment contradicts the poll.** `POLL_INTERVAL` is `1` second; the
  comment on `:17` says "default: 5/second".
- **No localisation.** Every user-visible string — `"Buffs"`, `"Tracked Buff"`,
  `"Tracked Bar"`, all slash-command output — is hardcoded English with no locale
  table.
- **Overflow is silent.** Past `MAX_LINES` (30) `SetLine` returns false and the
  remaining buffs are dropped with no indication.
- **The frame is created at a fixed 300x300** and only its height is managed
  afterwards; width never adapts to the longest name, and long names are truncated
  rather than wrapped (`SetWordWrap(false)`, `:146`).

## Documentation map

Every `.md` in this repo, and the standard's docs that are absent.

### Present

| Path | Purpose |
| --- | --- |
| `README.md` | Player-facing page |
| `CLAUDE.md` | Agent brief stub |
| `DEPENDENCIES.md` | Toolchain contract |
| `docs/ARCHITECTURE.md` | This file |
| `TODO.md` | Author's open list (not a standard doc; pre-existing) |

### Canonical trio and Tier 1 — absent

These are unconditional under the standard and are **missing**. They are recorded
here as compliance findings for `/wow-addon:standards-audit`, not stubbed.

| Path | Status |
| --- | --- |
| `docs/testing.md` | Missing — no test process exists to document yet |
| `docs/smoke-tests.md` | Missing |
| `docs/scope.md` | Missing |
| `docs/module-map.md` | Missing |
| `docs/schema.md` | Missing |
| `docs/settings-panel.md` | Missing — no settings panel exists (`TODO.md`) |
| `docs/data-flow.md` | Missing |
| `docs/common-tasks.md` | Missing |

### Verification and record stores — absent

| Path | Status |
| --- | --- |
| `docs/test-cases.md` | Not applicable — generated by a test harness; no harness in this repo |
| `docs/performance.md` | Not applicable — no perf suite |
| `docs/perf-analysis/` | Not applicable — no in-game capture has been recorded |
| `docs/automated-tests/` | Not applicable — no automated-test battery exists |

No Tier 2 trigger has fired: the addon has no settings panel, no locale files, no
vendored libraries, no data broker and no combat-log parsing. There are no Tier 3
docs.
