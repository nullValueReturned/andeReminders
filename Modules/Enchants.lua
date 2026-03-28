local AR = andeReminders

-- Slots that can receive enchants (mirrors NorthernSkyRaidTools logic)
local ENCHANTABLE_SLOTS = {
    { id = 1,  name = "Head"      },
    { id = 3,  name = "Shoulder"  },
    { id = 5,  name = "Chest"     },
    { id = 7,  name = "Legs"      },
    { id = 8,  name = "Feet"      },
    { id = 11, name = "Finger 1"  },
    { id = 12, name = "Finger 2"  },
    { id = 16, name = "Main Hand" },
    { id = 17, name = "Off Hand"  },
}

local EnchantModule = {}

-- Set default values for any slot not yet saved
function EnchantModule:InitDB(db)
    if not db.enchants then
        db.enchants = { slots = {} }
    end
    for _, slot in ipairs(ENCHANTABLE_SLOTS) do
        if not db.enchants.slots[slot.id] then
            db.enchants.slots[slot.id] = { enabled = true, minIlvl = 0 }
        end
    end
end

-- Build the settings UI inside the provided content frame
function EnchantModule:BuildUI(parent, db)
    local COL_NAME_X  = 12
    local COL_CHECK_X = 185
    local COL_LABEL_X = 230
    local COL_INPUT_X = 305
    local ROW_HEIGHT  = 30
    local HEADER_H    = 54  -- pixels used by title + column headers

    -- Section title
    local sectionTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sectionTitle:SetPoint("TOPLEFT", parent, "TOPLEFT", COL_NAME_X, -10)
    sectionTitle:SetText("Enchant Reminders")
    sectionTitle:SetTextColor(1, 0.82, 0)

    -- Column headers
    local hSlot = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hSlot:SetPoint("TOPLEFT", parent, "TOPLEFT", COL_NAME_X, -34)
    hSlot:SetText("Slot")
    hSlot:SetTextColor(0.6, 0.6, 0.6)

    local hRemind = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hRemind:SetPoint("TOPLEFT", parent, "TOPLEFT", COL_CHECK_X - 8, -34)
    hRemind:SetText("Remind")
    hRemind:SetTextColor(0.6, 0.6, 0.6)

    local hIlvl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hIlvl:SetPoint("TOPLEFT", parent, "TOPLEFT", COL_LABEL_X, -34)
    hIlvl:SetText("Min iLvl")
    hIlvl:SetTextColor(0.6, 0.6, 0.6)

    -- Divider below column headers
    local divider = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    divider:SetHeight(1)
    divider:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
    divider:SetBackdropColor(0.28, 0.28, 0.28, 1)
    divider:SetPoint("TOPLEFT",  parent, "TOPLEFT",  5, -HEADER_H + 2)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -HEADER_H + 2)

    -- One row per enchantable slot
    for i, slot in ipairs(ENCHANTABLE_SLOTS) do
        local slotData = db.enchants.slots[slot.id]
        local y = -(HEADER_H + (i - 1) * ROW_HEIGHT + 8)

        -- Slot name label
        local nameLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", COL_NAME_X, y)
        nameLabel:SetText(slot.name)

        -- Enabled checkbox
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", COL_CHECK_X, y + 3)
        cb:SetChecked(slotData.enabled)
        cb:SetScript("OnClick", function(self)
            slotData.enabled = self:GetChecked()
        end)

        -- "Min iLvl:" label
        local ilvlLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ilvlLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", COL_LABEL_X, y)
        ilvlLabel:SetText("Min iLvl:")

        -- Numeric edit box
        local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        editBox:SetSize(58, 20)
        editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", COL_INPUT_X, y + 3)
        editBox:SetAutoFocus(false)
        editBox:SetNumeric(true)
        editBox:SetMaxLetters(4)
        editBox:SetText(tostring(slotData.minIlvl or 0))

        local function SaveValue(self)
            slotData.minIlvl = tonumber(self:GetText()) or 0
        end
        editBox:SetScript("OnEnterPressed", function(self)
            SaveValue(self)
            self:ClearFocus()
        end)
        editBox:SetScript("OnEditFocusLost", SaveValue)
    end
end

-- Returns true if the given slot has an item but is missing an enchant.
-- Adapted from NorthernSkyRaidTools ReadyCheck.lua (EnchantCheck).
function EnchantModule:CheckSlot(slotId)
    local link = GetInventoryItemLink("player", slotId)
    if not link then return false end  -- nothing equipped

    -- Off-hand: skip enchant check for shields (armor classId == 4)
    if slotId == 17 then
        local _, _, _, _, _, _, _, _, _, _, _, classId = GetItemInfo(link)
        if classId == 4 then return false end
    end

    -- Item link format: item:ITEMID:ENCHANTID:...
    local _, enchantStr = link:match("item:(%d+):(%d+)")
    local enchantId = tonumber(enchantStr) or 0
    return enchantId == 0  -- true = enchant is missing
end

-- Returns the item level of an equipped item (0 if slot is empty or not yet cached).
function EnchantModule:GetSlotItemLevel(slotId)
    local link = GetInventoryItemLink("player", slotId)
    if not link then return 0 end
    local name, _, _, itemLevel = GetItemInfo(link)
    if not name then return 0 end  -- item not in cache yet
    return itemLevel or 0
end

-- Check all configured slots. Returns a list of slot names missing enchants.
function EnchantModule:CheckAll(db)
    local missing = {}
    for _, slot in ipairs(ENCHANTABLE_SLOTS) do
        local slotData = db.enchants.slots[slot.id]
        if slotData and slotData.enabled then
            local ilvl = self:GetSlotItemLevel(slot.id)
            if ilvl >= (slotData.minIlvl or 0) then
                if self:CheckSlot(slot.id) then
                    table.insert(missing, slot.name)
                end
            end
        end
    end
    return missing
end

AR:RegisterModule("Enchants", EnchantModule)
