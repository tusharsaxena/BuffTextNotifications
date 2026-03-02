update the addon to do the following:
1. For the categories TrackedBuff and TrackedBar, also show the stack count, time remaining and total time of the buff in the frame next to every buff name
2. For the categories Essential and Utility, show the charge count and remaining cooldown time of the spell in the frame next to every spell

----------------------------------------

Perfect! I've found the complete API documentation for all the functions you asked about. Here's the confirmed information for WoW 11.x (The War Within):

1. C_Spell.GetSpellCooldown(spellID) Returns:

SpellCooldownInfo table with these fields:
- startTime (number) - When cooldown started; 0 if no cooldown; current time if isEnabled is false
- duration (number) - Cooldown duration in seconds if active; 0 if inactive
- isEnabled (boolean) - False if cooldown is on hold (e.g., cooldowns that only start after canceling an active spell)
- modRate (number) - Rate at which the cooldown UI updates

✅ Your field list is correct!

2. C_Spell.GetSpellCharges(spellID) Returns:

SpellChargeInfo table with these fields:
- currentCharges (number) - Number of charges currently available
- maxCharges (number) - Max charges that can be accumulated
- cooldownStartTime (number) - When the most recent charge cooldown began; 0 if not active
- cooldownDuration (number) - Duration in seconds to generate one charge
- chargeModRate (number) - Rate at which cooldown UI should update

✅ Your field list is correct! Note: Returns nil if spell is not found or not charge-based.

3. C_Spell.GetSpellName(spellID) vs GetSpellInfo(spellID):

- C_Spell.GetSpellName(spellID) - Returns just the spell name as a string (or nil if not found)
- GetSpellInfo(spellID) - This function was REMOVED in Patch 11.0.0
- C_Spell.GetSpellInfo(spellID) - This is the modern replacement (added in 11.0.0), returns a full SpellInfo table with fields like: name, castTime, minRange, maxRange, spellID, iconID, originalIconID

✅ Use C_Spell.GetSpellName() for just the name, or C_Spell.GetSpellInfo() for comprehensive data.

4. C_UnitAuras.GetAuraDataByIndex() Returns:

AuraData table with these confirmed fields:
- duration (number) - Total duration of the aura
- expirationTime (number) - GetTime()-based timestamp when the aura expires
- Plus many other fields: applications, auraInstanceID, charges, dispelName, icon, isHarmful, isHelpful, isStealable, name, sourceUnit, spellId, etc.

✅ Both duration and expirationTime are confirmed present with the meanings you specified!

Sources:

- https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellCooldown
- https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellCharges
- https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellName
- https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellInfo
- https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByIndex
- https://warcraft.wiki.gg/wiki/API_GetSpellInfo

----------------------------------------

Updated plan
  ⎿  Added 58 lines, removed 86 lines
        1 -# Show all 4 Cooldown Viewer categories in separate sections
        1 +# Add timers, stacks, charges & cooldown info to each category
        2
        3  ## Context
        4 -The addon currently only filters by `TrackedBuff` and `TrackedBar` categories, but only TrackedBar actually works. The likely cause is that for TrackedBuff entries, `auraData.spellId` may match a `linkedSpellIDs` entry
          - rather than the top-level `spellID`. The fix is to also index `linkedSpellIDs` into the lookup table. Additionally, the user wants all 4 categories (Essential, Utility, TrackedBuff, TrackedBar) shown in separate label
          -ed sections.
        4 +The addon currently shows buff names grouped by category but with no timing or charge data. The user wants:
        5 +- **TrackedBuff / TrackedBar**: show stack count, time remaining, and total duration next to each buff
        6 +- **Essential / Utility**: show charge count and remaining cooldown next to each spell
        7
        6 -## API Reference
        7 -- `C_CooldownViewer.GetCooldownViewerCategorySet(category)` → `number[]` cooldownIDs
        8 -- `C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)` → table with: `spellID`, `overrideSpellID`, `linkedSpellIDs`, `selfAura`, `hasAura`, `isKnown`, `category`, `flags`
        9 -- `Enum.CooldownViewerCategory`: Essential (0), Utility (1), TrackedBuff (2), TrackedBar (3)
        8 +This requires two architectural additions:
        9 +1. Store aura timing data (`duration`, `expirationTime`) in the aura cache
       10 +2. Track Essential/Utility spells separately (they're cooldowns, not auras) and query `C_Spell` APIs at render time
       11 +3. Add an `OnUpdate` timer to refresh the display every ~0.1s so countdown timers tick live
       12
       13  ## File
       14  `/mnt/d/Profile/Documents/GIT/BuffTextNotifications/BuffTextNotifications.lua`
       15
       16 +## API Reference (confirmed for retail 11.x)
       17 +- `C_Spell.GetSpellCooldown(spellID)` → `{ startTime, duration, isEnabled, modRate }`
       18 +- `C_Spell.GetSpellCharges(spellID)` → `{ currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate }` or nil
       19 +- `C_Spell.GetSpellName(spellID)` → string name
       20 +- `auraData.duration` — total buff duration; `auraData.expirationTime` — GetTime()-based expiry timestamp
       21 +
       22  ## Changes
       23
       16 -### 1. Replace single `trackedSpellIDs` with per-category tables (Section 1)
       17 -Replace `local trackedSpellIDs = {}` with:
       24 +### 1. Add time formatting helper (Section 1, after constants)
       25  ```lua
       19 -local categorySpellIDs = {
       20 -    [Enum.CooldownViewerCategory.Essential] = {},
       21 -    [Enum.CooldownViewerCategory.Utility] = {},
       22 -    [Enum.CooldownViewerCategory.TrackedBuff] = {},
       23 -    [Enum.CooldownViewerCategory.TrackedBar] = {},
       24 -}
       25 -local spellToCategory = {}  -- spellID → category (for fast aura filtering)
       26 +local function FormatTime(seconds)
       27 +    if seconds <= 0 then return "" end
       28 +    if seconds < 60 then return string.format("%ds", seconds) end
       29 +    return string.format("%d:%02d", seconds / 60, seconds % 60)
       30 +end
       31  ```
       32
       28 -### 2. Rewrite `BuildTrackedSet` (Section 2)
       29 -- Iterate all 4 categories
       30 -- For each cooldownID, get info and store `spellID`, `overrideSpellID`, **and all `linkedSpellIDs`** into both `categorySpellIDs[cat]` and `spellToCategory`
       31 -- This fixes the TrackedBuff bug — those entries likely use `linkedSpellIDs` to map to actual aura spell IDs
       32 -
       33 +### 2. Add cooldown spell cache (Section 1, after `spellToCategory`)
       34 +A table mapping spellID → name for Essential/Utility spells, built during `BuildTrackedSet`:
       35  ```lua
       34 -local function BuildTrackedSet()
       35 -    for cat, _ in pairs(categorySpellIDs) do
       36 -        categorySpellIDs[cat] = {}
       37 -    end
       38 -    spellToCategory = {}
       39 -    for _, cat in ipairs({
       40 -        Enum.CooldownViewerCategory.Essential,
       41 -        Enum.CooldownViewerCategory.Utility,
       42 -        Enum.CooldownViewerCategory.TrackedBuff,
       43 -        Enum.CooldownViewerCategory.TrackedBar,
       44 -    }) do
       45 -        local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat) or {}
       46 -        for _, cooldownID in ipairs(ids) do
       47 -            local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
       48 -            if info then
       49 -                categorySpellIDs[cat][info.spellID] = true
       50 -                spellToCategory[info.spellID] = cat
       51 -                if info.overrideSpellID then
       52 -                    categorySpellIDs[cat][info.overrideSpellID] = true
       53 -                    spellToCategory[info.overrideSpellID] = cat
       54 -                end
       55 -                if info.linkedSpellIDs then
       56 -                    for _, linked in ipairs(info.linkedSpellIDs) do
       57 -                        categorySpellIDs[cat][linked] = true
       58 -                        spellToCategory[linked] = cat
       59 -                    end
       60 -                end
       61 -            end
       62 -        end
       63 -    end
       64 -end
       36 +local cooldownSpells = {}  -- { [cat] = { {spellID=id, name=name}, ... } }
       37  ```
       38
       67 -### 3. Update aura filtering (Section 2)
       68 -- In `ScanAllAuras`, `ProcessAuraUpdate` addedAuras, and updatedAuras: replace `trackedSpellIDs[auraData.spellId]` checks with `spellToCategory[auraData.spellId]`
       69 -- Store the category in the cache entry: `category = spellToCategory[auraData.spellId]`
       39 +### 3. Update `BuildTrackedSet` — populate `cooldownSpells` (Section 2)
       40 +For Essential and Utility categories, after building `categorySpellIDs`, also store `{spellID, name}` entries (using `C_Spell.GetSpellName`) into `cooldownSpells[cat]` so we can iterate them at render time without need
          +ing auras. Sort each list by name for stable display order.
       41
       71 -### 4. Update `GetSortedBuffNames` → new helper `GetSortedBuffsByCategory` (Section 2)
       72 -Replace with a function that returns a table keyed by category, each containing sorted buff names:
       42 +### 4. Store aura timing in cache (Section 2)
       43 +In `ScanAllAuras` and `ProcessAuraUpdate` (addedAuras + updatedAuras), add `duration` and `expirationTime` fields to the cached entry:
       44  ```lua
       74 -local function GetSortedBuffsByCategory(unit)
       75 -    local byCategory = {}
       76 -    for _, info in pairs(auraCache[unit] or {}) do
       77 -        local cat = info.category
       78 -        if cat then
       79 -            if not byCategory[cat] then byCategory[cat] = {} end
       80 -            local display = info.name
       81 -            if info.stacks and info.stacks > 1 then
       82 -                display = display .. " (" .. info.stacks .. ")"
       83 -            end
       84 -            byCategory[cat][#byCategory[cat] + 1] = display
       85 -        end
       86 -    end
       87 -    for _, names in pairs(byCategory) do
       88 -        table.sort(names)
       89 -    end
       90 -    return byCategory
       91 -end
       45 +duration = auraData.duration,
       46 +expirationTime = auraData.expirationTime,
       47  ```
       48
       94 -### 5. Update `RefreshDisplay` (Section 3)
       95 -Display 4 sections with colored headers. Define category display order and labels:
       49 +### 5. Rewrite `GetSortedBuffsByCategory` → `GetDisplayEntries` (Section 2)
       50 +Returns a table keyed by category, each containing sorted display strings:
       51 +
       52 +- **TrackedBuff / TrackedBar entries** (from aura cache): format as `"Name (3) 1:30/3:00"` — name, stacks if >1, remaining/total if duration >0
       53 +- **Essential / Utility entries** (from `cooldownSpells`): for each spell, query `C_Spell.GetSpellCharges` and `C_Spell.GetSpellCooldown`:
       54 +  - If charges exist and maxCharges > 1: show `"Name 2/3 45s"` (currentCharges/maxCharges + per-charge CD remaining)
       55 +  - If on cooldown (no charges or 1 max charge): show `"Name 45s"`
       56 +  - If ready: show `"Name Ready"`
       57 +
       58 +### 6. Add OnUpdate ticker (Section 3, in `CreateDisplayFrame`)
       59 +Register an `OnUpdate` handler on the main frame that calls `RefreshDisplay()` throttled to every 0.1 seconds. This keeps countdown timers live.
       60  ```lua
       97 -local CATEGORY_DISPLAY = {
       98 -    { cat = Enum.CooldownViewerCategory.Essential,   label = "Essential",    r = 1,   g = 0.2, b = 0.2 },
       99 -    { cat = Enum.CooldownViewerCategory.Utility,     label = "Utility",      r = 0.2, g = 0.6, b = 1   },
      100 -    { cat = Enum.CooldownViewerCategory.TrackedBuff,  label = "Tracked Buff", r = 0.2, g = 1,   b = 0.2 },
      101 -    { cat = Enum.CooldownViewerCategory.TrackedBar,   label = "Tracked Bar",  r = 1,   g = 0.82,b = 0   },
      102 -}
       61 +local elapsed = 0
       62 +frame:SetScript("OnUpdate", function(self, dt)
       63 +    elapsed = elapsed + dt
       64 +    if elapsed >= 0.1 then
       65 +        elapsed = 0
       66 +        RefreshDisplay()
       67 +    end
       68 +end)
       69  ```
      104 -Loop through each category in order, print the header if there are buffs, then list the buff names.
       70
       71 +### 7. Widen frame (Section 1)
       72 +Increase `FRAME_WIDTH` from 220 to 300 to accommodate the extra timing text.
       73 +
       74 +### 8. Increase MAX_LINES (Section 1)
       75 +Increase from 20 to 30 since we're now showing cooldown spells that aren't aura-dependent.
       76 +
       77  ## Verification
      107 -1. `/reload` — buffs should appear under all 4 category headers
      108 -2. Buffs from TrackedBuff should now appear (fixed by indexing `linkedSpellIDs`)
      109 -3. Frame drag/position persistence still works
       78 +1. `/reload` — TrackedBuff/TrackedBar entries should show countdown timers ticking live
       79 +2. Essential/Utility spells should appear with charge counts and cooldown timers
       80 +3. Cooldown timers should count down smoothly (~10 updates/sec)
       81 +4. Frame drag/position persistence still works

----------------------------------------

Generate CLAUDE.md and README.md

----------------------------------------

Do you need to use ScanAllAuras()? Specifically C_UnitAuras.GetAuraDataByIndex()? 

----------------------------------------

8x ...dOns/BuffTextNotifications/BuffTextNotifications.lua:115: attempt to perform boolean test on field 'isHelpful' (a secret boolean value tainted by 'BuffTextNotifications')
[BuffTextNotifications/BuffTextNotifications.lua]:115: in function <...dOns/BuffTextNotifications/BuffTextNotifications.lua:88>
[BuffTextNotifications/BuffTextNotifications.lua]:298: in function <...dOns/BuffTextNotifications/BuffTextNotifications.lua:265>

----------------------------------------

