# DEPENDENCIES

Everything needed to run, develop or release BuffTextNotifications. Install commands
are for WSL2 / Ubuntu. This file answers *what to install*; it does not restate how
to verify a change — for this addon that is manual, and `CLAUDE.md` describes it.

Every entry below traces to something in this repo. Where a tool the collection
normally uses is absent, that is stated as an absence rather than listed
speculatively.

## Runtime (in-game)

| Requirement | Evidence |
| --- | --- |
| World of Warcraft retail client, interface 120000 / 120001 / 120005 | `BuffTextNotifications.toc:1` |
| `C_CooldownViewer` client API | `BuffTextNotifications.lua:40,42` |
| `C_Spell.GetSpellName` | `BuffTextNotifications.lua:44` |
| `AuraUtil.FindAuraByName` | `BuffTextNotifications.lua:93,177` |
| `BackdropTemplate` frame template | `BuffTextNotifications.lua:115` |

**No library dependencies.** The TOC declares neither `## Dependencies` nor
`## OptionalDeps`, and the repo vendors no `libs/` directory. Nothing needs to be
installed alongside the addon.

## Development

**There is currently no development toolchain in this repo.** No `.luacheckrc`, no
`tests/` directory, no `Makefile`, no CI configuration. Nothing here requires
`lua`, `luacheck`, `lizard` or a headless harness, because there is nothing for
them to run against.

What that means in practice: changes are verified by loading the addon in the
client. The only tool genuinely required is a text editor and `git`.

| Tool | Install | Verify |
| --- | --- | --- |
| `git` | `sudo apt install git` | `git --version` |

If a lint config or a test harness is added later, the tools they need belong in
this section with the file that requires them cited alongside — not before.

## Release and assets

**None.** The repo has no `.pkgmeta`, no packaging script, no asset-regeneration
step and no generated files. A release is the repository contents as they stand.
