local _, addon = ...

local panel = CreateFrame("Frame", nil, UIParent)
panel:Hide()
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("DamageColor")
local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
description:SetPoint("TOPLEFT", 16, -48)
description:SetWidth(520)
description:SetJustifyH("LEFT")
description:SetText("Choose your damage colors. Changes apply immediately and are saved across reloads. Auto-attacks remain native white.")

local schools = {
    { 1, "Physical skills / bleeds (preview only)" },
    { 64, "Arcane" }, { 4, "Fire" }, { 32, "Shadow" },
    { 16, "Frost" }, { 8, "Nature" }, { 2, "Holy" },
    { 0, "Other / mixed schools" },
}
local rows = {}
local pickerSession
local function closeOwnedPicker()
    if not pickerSession then return end
    pickerSession.active = false
    if ColorPickerFrame and ColorPickerFrame.swatchFunc == pickerSession.changed then
        ColorPickerFrame:Hide()
    end
    pickerSession = nil
end

local function openPicker(school)
    if not ColorPickerFrame and C_AddOns then C_AddOns.LoadAddOn("Blizzard_ColorPicker") end
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
        print("DamageColor: The game color picker is unavailable.")
        return
    end
    closeOwnedPicker()
    local r, g, b = unpack(addon.colors[school])
    local session = { active = true }
    pickerSession = session
    session.changed = function()
        if not session.active then return end
        addon.SetColor(school, ColorPickerFrame:GetColorRGB())
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b, hasOpacity = false,
        swatchFunc = session.changed,
        cancelFunc = function()
            if not session.active then return end
            session.active = false
            addon.SetColor(school, r, g, b)
        end,
    })
end

for i, school in ipairs(schools) do
    local key = school[1]
    local row = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    row:SetSize(360, 28)
    row:SetPoint("TOPLEFT", 16, -108 - (i - 1) * 38)
    row:SetText(school[2])
    row:SetScript("OnClick", function() openPicker(key) end)
    local swatch = row:CreateTexture(nil, "OVERLAY")
    swatch:SetSize(24, 20)
    swatch:SetPoint("LEFT", row, "RIGHT", 12, 0)
    local sample = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sample:SetPoint("LEFT", swatch, "RIGHT", 12, 0)
    rows[key] = { swatch = swatch, sample = sample }
end

local function refresh()
    for school, row in pairs(rows) do
        local r, g, b = unpack(addon.colors[school])
        row.swatch:SetColorTexture(r, g, b, 1)
        row.sample:SetTextColor(r, g, b)
        row.sample:SetText(string.format("123  #%02X%02X%02X",
            math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)))
    end
end
addon.OnPaletteChanged = function()
    refresh()
    addon.RefreshDisplayColors()
end
panel:SetScript("OnShow", refresh)
panel:SetScript("OnHide", closeOwnedPicker)

local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetSize(160, 28)
reset:SetPoint("TOPLEFT", 16, -422)
reset:SetText("Reset colors")
reset:SetScript("OnClick", function()
    closeOwnedPicker()
    addon.ResetColors()
end)
local preview = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
preview:SetSize(160, 28)
preview:SetPoint("LEFT", reset, "RIGHT", 12, 0)
preview:SetText("Preview colors")
preview:SetScript("OnClick", function() addon.ShowPreview() end)

local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
note:SetPoint("TOPLEFT", 16, -470)
note:SetWidth(520)
note:SetJustifyH("LEFT")
note:SetText("Physical skill colors apply to the preview only; live physical numbers remain unchanged. Mixed schools, including Frostfire, use Other. Magic numbers include all attackers on your target.")

local category = Settings.RegisterCanvasLayoutCategory(panel, "DamageColor")
Settings.RegisterAddOnCategory(category)
function addon.OpenSettings()
    Settings.OpenToCategory(category:GetID())
end
refresh()
