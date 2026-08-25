# BuffTextNotifications

A small World of Warcraft addon that lists the buffs you currently have, as plain
text, in a draggable frame. It reads its list of "interesting" buffs from the
client's own Cooldown Manager, so whatever you have set up there is what shows up
here — no per-spell configuration to maintain.

- **Version:** 1.0.0
- **Interface:** 120000, 120001, 120005
- **Saved variables:** `BuffTextNotificationsDB`

## What it does

The addon asks `C_CooldownViewer` for the spells you have placed in two Cooldown
Manager categories, `TrackedBuff` and `TrackedBar`, and resolves each to a spell
name. Every refresh it checks which of those names are currently active on you and
prints the active ones under a coloured category heading:

- **Tracked Buff** — green heading
- **Tracked Bar** — gold heading

Categories with nothing active are omitted entirely, and the frame's height shrinks
and grows to fit whatever is on screen, up to 30 lines.

## Installing

Copy the `BuffTextNotifications` folder into `World of Warcraft/_retail_/Interface/AddOns/`
and restart the client (or `/reload`). There is nothing else to install — the addon
has no library dependencies.

## Using it

The frame appears automatically at login, offset 200 px left and 200 px up from the
centre of the screen. Drag it with the left mouse button; where you drop it is saved
and restored on the next login.

### Slash commands

| Command | What it does |
| --- | --- |
| `/btn` | Prints the command list |
| `/btn reset` | Returns the frame to its default position |
| `/btn toggle` | Shows or hides the frame |

## How it refreshes

Two things drive the display:

- `UNIT_AURA` for the player — an immediate refresh whenever your auras change.
- A one-second `OnUpdate` poll, as a backstop for durations and for anything the
  event misses.

The tracked-name list itself is rebuilt on `PLAYER_ENTERING_WORLD` and on
`COOLDOWN_VIEWER_DATA_LOADED`, so changing your Cooldown Manager setup is picked up
without a reload.

## Known limitations

- **The addon prints debug output to chat.** `BuildTrackedNames`, the one-second
  poll tick and every player `UNIT_AURA` each emit a `[BTN] …` line. This is
  development instrumentation that has not been removed or put behind a toggle yet.
- **There is no settings panel.** Frame size, line count, poll interval, colours and
  which categories are shown are all constants in the source.
- **Only two categories are read.** `trackedNames` is keyed by the literal numbers
  `2` and `3` rather than by the `Enum.CooldownViewerCategory` values used elsewhere
  in the same file; if Blizzard renumbers the enum the two will disagree.
- **Duration is not displayed.** `FormatTime` exists and is correct, but nothing
  calls it — only buff names are drawn.
- **Nothing is localised.** Every string is hardcoded English.
- **Only the player is inspected.** `AuraUtil.FindAuraByName(name, "player")` means
  a tracked buff active on anyone else is invisible here.

## Version History

| Version | Notes |
| --- | --- |
| 1.0.0 | First release — Cooldown Manager-driven buff name list in a draggable frame, `/btn` with `reset` and `toggle`. |
