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
Manager categories, `TrackedBuff` and `TrackedBar`, and resolves each one to a spell
name. That list is the whole vocabulary of the addon.

On every refresh it checks which of those names are currently on you and prints the
ones that are, grouped under a coloured heading: green for Tracked Buff, gold for
Tracked Bar. A category with nothing active is not drawn at all, not even as an empty
heading, so the frame is usually shorter than you expect. Its height follows the
content up to 30 lines.

## Installing

Copy the `BuffTextNotifications` folder into `World of Warcraft/_retail_/Interface/AddOns/`
and restart the client (or `/reload`). Nothing else to do; there are no library
dependencies.

## Usage

The frame turns up on its own at login, sitting 200 px left and 200 px up from the
middle of the screen, a spot picked for being out of the way and not much else. Drag
it with the left mouse button. Where you drop it is written to the saved variable and
restored next time you log in, and it will not let you shove it past the edge of the
screen.

What you get is a titled box called Buffs with a line per active tracked buff, indented
under its category heading. Headings appear only when something under them is up. Past
30 lines the rest are silently dropped, and a name wider than the frame is cut off
rather than wrapped — neither is likely with a normal Cooldown Manager setup, but
that is what happens.

Two commands, and `/btn` on its own prints them both. `/btn toggle` hides the frame and
shows it again, which is the one to reach for when you want the screen clear for a
screenshot. `/btn reset` puts it back at that default offset from centre; use it when
the frame has ended up somewhere you cannot get at it. Note that hiding is not
remembered — position is the only thing saved, so a hidden frame comes back at the next
login.

The addon also talks to your chat frame constantly. Every aura change and every
one-second poll prints a `[BTN] …` line — leftover development instrumentation, with no
way to turn it off in this version.

There is nothing else to configure: this addon has no page under Settings → AddOns and
no slash form beyond `/btn`.

## How it refreshes

Two things drive the display. `UNIT_AURA` on the player refreshes it immediately when
your auras change, and a one-second `OnUpdate` poll runs underneath as a backstop for
anything the event misses.

The tracked-name list is a separate matter, rebuilt on `PLAYER_ENTERING_WORLD` and on
`COOLDOWN_VIEWER_DATA_LOADED`. Change your Cooldown Manager setup and the addon picks
it up without a reload.

## Known limitations

Most of these are the consequence of a first release that stopped at "it works".

- Debug output goes to chat unconditionally. `BuildTrackedNames`, the poll tick and
  every player `UNIT_AURA` each emit a `[BTN] …` line, with no toggle behind them.
- There is no settings panel. Frame size, line count, poll interval, colours and the
  choice of categories are all constants in the source.
- Only two categories are read, and `trackedNames` is keyed by the literal numbers `2`
  and `3` rather than by the `Enum.CooldownViewerCategory` values the same file uses a
  few lines later. They agree today. If Blizzard renumbers the enum they stop agreeing.
- Duration is not displayed. `FormatTime` exists and is correct, and nothing calls it.
- Nothing is localised — every string is hardcoded English.
- `AuraUtil.FindAuraByName(name, "player")` inspects you and only you, so a tracked
  buff active on anyone else is invisible here.

## Version History

| Version | Notes |
| --- | --- |
| 1.0.0 | - First release — Cooldown Manager-driven buff name list in a draggable frame, `/btn` with `reset` and `toggle`. |
