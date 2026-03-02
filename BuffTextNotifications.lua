-------------------------------------------------------------------------------
-- BuffTextNotifications
-- Displays active buff names as text in a draggable frame
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Section 1: Constants & State
-------------------------------------------------------------------------------
local ADDON_NAME = "BuffTextNotifications"
local FRAME_WIDTH = 300
local FRAME_HEIGHT = 300
local LINE_HEIGHT = 14
local MAX_LINES = 30
local DEFAULT_X = -200
local DEFAULT_Y = 200

local function FormatTime(seconds)
    if seconds <= 0 then return "0s" end
    if seconds < 60 then return string.format("%ds", math.floor(seconds)) end
    return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

local trackedNames = { [2] = {}, [3] = {} }

local CATEGORY_DISPLAY = {
    { cat = Enum.CooldownViewerCategory.TrackedBuff, label = "Tracked Buff", r = 0.2, g = 1,   b = 0.2 },
    { cat = Enum.CooldownViewerCategory.TrackedBar,  label = "Tracked Bar",  r = 1,   g = 0.82,b = 0   },
}

-------------------------------------------------------------------------------
-- Section 2: C_CooldownViewer Data Layer
-------------------------------------------------------------------------------
local function BuildTrackedNames()
    trackedNames[2] = {}
    trackedNames[3] = {}
    for category = 2, 3 do
        local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category) or {}
        for _, cooldownID in ipairs(cooldownIDs) do
            local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
            if info and info.spellID then
                local name = C_Spell.GetSpellName(info.spellID)
                if name then
                    trackedNames[category][#trackedNames[category] + 1] = name
                end
            end
        end
        table.sort(trackedNames[category])
    end
end

-------------------------------------------------------------------------------
-- Section 3: Display Frame (UI Layer)
-------------------------------------------------------------------------------
local frame
local fontStrings = {}
local titleString

-- RefreshDisplay is defined before CreateDisplayFrame so the OnUpdate closure
-- inside CreateDisplayFrame captures it as an upvalue rather than a global lookup.
local function RefreshDisplay()
    if not frame or not frame:IsShown() then return end

    -- Hide all lines first
    for i = 1, MAX_LINES do
        fontStrings[i]:Hide()
    end

    local line = 0

    -- Helper: set a line of text; returns false when full
    local function SetLine(text, r, g, b)
        line = line + 1
        if line > MAX_LINES then return false end
        fontStrings[line]:SetText(text)
        fontStrings[line]:SetTextColor(r, g, b, 1)
        fontStrings[line]:Show()
        return true
    end

    -- Player buffs by category
    for _, entry in ipairs(CATEGORY_DISPLAY) do
        local names = trackedNames[entry.cat]
        if names and #names > 0 then
            if not SetLine(entry.label, entry.r, entry.g, entry.b) then break end
            local stop = false
            for _, name in ipairs(names) do
                if not SetLine("  " .. name, 1, 1, 1) then stop = true break end
            end
            if stop then break end
        end
    end

    -- Resize frame height dynamically
    local usedLines = math.min(line, MAX_LINES)
    local contentHeight = math.max(60, 30 + (usedLines * LINE_HEIGHT))
    frame:SetHeight(contentHeight)
end

local function CreateDisplayFrame()
    frame = CreateFrame("Frame", "BuffTextNotificationsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, DEFAULT_Y)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.7)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

    -- Title
    titleString = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleString:SetPoint("TOP", frame, "TOP", 0, -8)
    titleString:SetText("Buffs")
    titleString:SetTextColor(1, 0.82, 0, 1)

    -- Pre-allocate font string pool
    for i = 1, MAX_LINES do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -(22 + (i - 1) * LINE_HEIGHT))
        fs:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:Hide()
        fontStrings[i] = fs
    end

    -- Drag handlers
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if BuffTextNotificationsDB then
            BuffTextNotificationsDB.point = point
            BuffTextNotificationsDB.relPoint = relPoint
            BuffTextNotificationsDB.x = x
            BuffTextNotificationsDB.y = y
        end
    end)

end

-------------------------------------------------------------------------------
-- Section 4: Event Handler
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= ADDON_NAME then return end

        -- Init SavedVariables
        if not BuffTextNotificationsDB then
            BuffTextNotificationsDB = {}
        end

        -- Create the display frame
        CreateDisplayFrame()

        -- Restore saved position
        local db = BuffTextNotificationsDB
        if db.point then
            frame:ClearAllPoints()
            frame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        BuildTrackedNames()
        RefreshDisplay()

    elseif event == "COOLDOWN_VIEWER_DATA_LOADED" then
        BuildTrackedNames()
        RefreshDisplay()

    end
end)

-------------------------------------------------------------------------------
-- Section 5: Slash Commands
-------------------------------------------------------------------------------
SLASH_BUFFTEXTNOTIFICATIONS1 = "/btn"

SlashCmdList["BUFFTEXTNOTIFICATIONS"] = function(msg)
    local cmd = strlower(strtrim(msg))

    if cmd == "reset" then
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, DEFAULT_Y)
            BuffTextNotificationsDB.point = "CENTER"
            BuffTextNotificationsDB.relPoint = "CENTER"
            BuffTextNotificationsDB.x = DEFAULT_X
            BuffTextNotificationsDB.y = DEFAULT_Y
            print("|cff00ff00BuffTextNotifications:|r Frame position reset.")
        end

    elseif cmd == "toggle" then
        if frame then
            if frame:IsShown() then
                frame:Hide()
                print("|cff00ff00BuffTextNotifications:|r Frame hidden.")
            else
                frame:Show()
                RefreshDisplay()
                print("|cff00ff00BuffTextNotifications:|r Frame shown.")
            end
        end

    else
        print("|cff00ff00BuffTextNotifications|r commands:")
        print("  /btn reset  - Reset frame position")
        print("  /btn toggle - Show/hide frame")
    end
end
