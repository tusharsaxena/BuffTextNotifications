# CLAUDE.md — BuffTextNotifications

Single-file World of Warcraft retail addon. It reads the player's Cooldown Manager
tracked-spell sets via `C_CooldownViewer`, resolves them to spell names, and draws
the currently-active ones as text in a draggable frame.

## Standards compliance (read first)

**This addon is not yet on the Ka0s WoW Addon Standard.** Do not assume the
collection's usual shape here — there is no `libs/`, no `LibKa0s`, no Ace3, no
`tests/` harness, no `.luacheckrc`, no locale files, no module directory and no
`LICENSE`. Everything lives in `BuffTextNotifications.lua`.

Bringing it onto the standard is a migration, not a sync. Do not scaffold the
missing pieces piecemeal as a side effect of some other task; the gap is tracked as
a compliance finding for `/wow-addon:standards-audit`.

## Where things are

- `BuffTextNotifications.toc` — load order (one file), interface list, saved-variable name.
- `BuffTextNotifications.lua` — the whole addon, in five commented sections:
  constants and state, the `C_CooldownViewer` data layer, the display frame,
  the event handler, the slash commands.
- `docs/ARCHITECTURE.md` — module map, saved-variable shape, event and command tables,
  data flow, known limitations.
- `DEPENDENCIES.md` — what you need installed to run or work on this.
- `README.md` — the player-facing page.
- `TODO.md` — the author's open list.

## Hard rules for this addon

- **Everything is file-local.** The addon defines no addon table and exports nothing.
  Do not introduce a global for convenience; if a symbol needs sharing, it needs a
  reason first.
- **`RefreshDisplay` must stay defined above `CreateDisplayFrame`.** The `OnUpdate`
  closure captures it as an upvalue; moving it below turns that into a global lookup
  on every frame.
- **`trackedNames` is keyed by the literal category numbers `2` and `3`,** while
  `CATEGORY_DISPLAY` keys by `Enum.CooldownViewerCategory`. They agree today by
  coincidence. Any change to either must reconcile both.
- **Debug `print` calls are live.** Three of them fire in normal play. They are known
  and deliberate-for-now; removing or gating them is a code change, not a cleanup to
  fold into unrelated work.

## Green gate

There is no automated gate in this repo — no lint config, no test harness, no perf
or complexity suite. Verification is manual: load the addon in the client, confirm
the frame appears and tracks, and exercise `/btn`, `/btn reset` and `/btn toggle`.
Say plainly that a change is unverified rather than implying a suite passed.
