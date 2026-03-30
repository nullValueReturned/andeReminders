andeReminders = {}
local AR = andeReminders

AR.registeredModules = {} -- ordered list of { name, module, tabButton, contentFrame }

-- Register a reminder module. Called by module files at load time.
function AR:RegisterModule(name, module)
    table.insert(self.registeredModules, { name = name, module = module })
end

-- Initialize saved variables, then let each module set its own defaults.
function AR:InitDB()
    if not andeRemindersDB then
        andeRemindersDB = {}
    end
    AR.db = andeRemindersDB
    for _, entry in ipairs(AR.registeredModules) do
        if entry.module.InitDB then
            entry.module:InitDB(AR.db)
        end
    end
end

-- Settings window state
local settingsFrame
local activeTabIndex = 0

local function SelectTab(index)
    activeTabIndex = index
    for i, entry in ipairs(AR.registeredModules) do
        if entry.contentFrame then
            if i == index then
                entry.contentFrame:Show()
                entry.tabButton:SetBackdropColor(0.15, 0.35, 0.7, 1)
                entry.tabButton:SetBackdropBorderColor(0.5, 0.6, 0.9, 1)
            else
                entry.contentFrame:Hide()
                entry.tabButton:SetBackdropColor(0.05, 0.05, 0.05, 1)
                entry.tabButton:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
            end
        end
    end
end

function AR:CreateSettingsWindow()
    if settingsFrame then return settingsFrame end

    -- Main frame
    local f = CreateFrame("Frame", "andeRemindersSettings", UIParent, "BackdropTemplate")
    f:SetSize(540, 460)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile   = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:Hide()

    -- Title text
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("anDeReminders")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Divider below title
    local titleDiv = f:CreateTexture(nil, "ARTWORK")
    titleDiv:SetColorTexture(0.35, 0.35, 0.35, 0.8)
    titleDiv:SetHeight(1)
    titleDiv:SetPoint("TOPLEFT",  f, "TOPLEFT",  14, -37)
    titleDiv:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -37)

    -- Build a tab button for each registered module
    local tabX = 14
    local TAB_Y      = -40  -- offset from frame top
    local CONTENT_Y  = TAB_Y - 28

    for i, entry in ipairs(AR.registeredModules) do
        -- Tab button
        local tab = CreateFrame("Button", nil, f, "BackdropTemplate")
        tab:SetSize(100, 24)
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", tabX, TAB_Y)
        tab:SetBackdrop({
            bgFile   = "Interface/Buttons/WHITE8x8",
            edgeFile = "Interface/Buttons/WHITE8x8",
            edgeSize = 1,
        })
        tab:SetBackdropColor(0.05, 0.05, 0.05, 1)
        tab:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

        local tabText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tabText:SetAllPoints(tab)
        tabText:SetJustifyH("CENTER")
        tabText:SetText(entry.name)

        entry.tabButton = tab
        tabX = tabX + 104

        -- Content frame (shared area, show/hide on tab click)
        local content = CreateFrame("Frame", nil, f, "BackdropTemplate")
        content:SetPoint("TOPLEFT",     f, "TOPLEFT",     14, CONTENT_Y)
        content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
        content:SetBackdrop({
            bgFile   = "Interface/Buttons/WHITE8x8",
            edgeFile = "Interface/Buttons/WHITE8x8",
            edgeSize = 1,
        })
        content:SetBackdropColor(0.04, 0.04, 0.04, 0.92)
        content:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        content:Hide()

        entry.contentFrame = content

        -- Let the module populate its content frame
        if entry.module.BuildUI then
            entry.module:BuildUI(content, AR.db)
        end

        -- Tab hover highlight
        local tabIndex = i
        tab:SetScript("OnEnter", function(self)
            if activeTabIndex ~= tabIndex then
                self:SetBackdropColor(0.1, 0.2, 0.45, 1)
            end
        end)
        tab:SetScript("OnLeave", function(self)
            if activeTabIndex ~= tabIndex then
                self:SetBackdropColor(0.05, 0.05, 0.05, 1)
            end
        end)
        tab:SetScript("OnClick", function()
            SelectTab(tabIndex)
        end)
    end

    -- Show first tab by default
    if #AR.registeredModules > 0 then
        SelectTab(1)
    end

    settingsFrame = f
    return f
end

function AR:ToggleSettings()
    if not settingsFrame then
        self:CreateSettingsWindow()
    end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "andeReminders" then
        AR:InitDB()
        AR:CreateSettingsWindow()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Slash commands
SLASH_ANDEREMINDERS1 = "/ar"
SLASH_ANDEREMINDERS2 = "/andereminders"
SlashCmdList["ANDEREMINDERS"] = function()
    AR:ToggleSettings()
end
