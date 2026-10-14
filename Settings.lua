local _, addon = ...

local canvas = CreateFrame("Frame", nil, UIParent)
canvas:Hide()
local scroll = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 0, 0)
scroll:SetPoint("BOTTOMRIGHT", -28, 0)
local panel = CreateFrame("Frame", nil, scroll)
panel:SetSize(560, 710)
scroll:SetScrollChild(panel)
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("DamageColor")
local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
description:SetPoint("TOPLEFT", 16, -48)
description:SetWidth(520)
description:SetJustifyH("LEFT")
description:SetText("Choose your damage font, size, and colors. Changes apply immediately and are saved across reloads. Critical hits are twice the selected size.")

local fontLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fontLabel:SetPoint("TOPLEFT", 16, -100)
fontLabel:SetText("Font")
local fontDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
fontDropdown:SetSize(240, 28)
fontDropdown:SetPoint("TOPLEFT", 110, -92)
fontDropdown:SetupMenu(function(_, root)
    for _, font in ipairs(addon.fonts) do
        root:CreateRadio(font.name, function(key) return addon.appearance.font == key end,
            function(key) addon.SetAppearance(key, addon.appearance.size) end, font.key)
    end
end)

local sizeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
sizeLabel:SetPoint("TOPLEFT", 16, -142)
local sizeSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
sizeSlider:SetPoint("TOPLEFT", 16, -170)
sizeSlider:SetSize(320, 18)
sizeSlider:SetMinMaxValues(12, 96)
sizeSlider:SetValueStep(1)
sizeSlider:SetObeyStepOnDrag(true)
sizeSlider:SetScript("OnValueChanged", function(_, value)
    addon.SetAppearance(addon.appearance.font, value)
end)
local hideNative = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
hideNative:SetSize(26, 26)
hideNative:SetPoint("TOPLEFT", 16, -204)
local hideLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
hideLabel:SetPoint("LEFT", hideNative, "RIGHT", 6, 0)
hideLabel:SetText("Hide Blizzard damage")
hideNative:SetScript("OnClick", function(self) addon.SetHideBlizzardDamage(self:GetChecked() == true) end)

local schools = {
    { 1, "Physical / auto-attacks / bleeds" },
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
    row:SetPoint("TOPLEFT", 16, -264 - (i - 1) * 38)
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
    hideNative:SetChecked(addon.hideBlizzardDamage)
    fontDropdown:OverrideText(addon.GetFont().name)
    sizeLabel:SetText("Text size: " .. addon.appearance.size .. "   (critical: " .. addon.appearance.size * 2 .. ")")
    if sizeSlider:GetValue() ~= addon.appearance.size then sizeSlider:SetValue(addon.appearance.size) end
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
addon.OnAppearanceChanged = function()
    refresh()
    addon.RefreshTextAppearance()
end
addon.OnNativeDamageChanged = refresh
panel:SetScript("OnShow", refresh)
canvas:SetScript("OnHide", closeOwnedPicker)

local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetSize(160, 28)
reset:SetPoint("TOPLEFT", 16, -578)
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
local resetText = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetText:SetSize(160, 28)
resetText:SetPoint("LEFT", preview, "RIGHT", 12, 0)
resetText:SetText("Reset font / size")
resetText:SetScript("OnClick", function() addon.SetAppearance("default", 48) end)

local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
note:SetPoint("TOPLEFT", 16, -626)
note:SetWidth(520)
note:SetJustifyH("LEFT")
note:SetText("Numbers pop above visible enemy nameplates, including mouseover and AoE hits. All attackers are included. Hide Blizzard damage prevents duplicate native numbers; disabled by /dc off. Mixed schools, including Frostfire, use Other.")

local category = Settings.RegisterCanvasLayoutCategory(canvas, "DamageColor")
Settings.RegisterAddOnCategory(category)
function addon.OpenSettings()
    Settings.OpenToCategory(category:GetID())
end
refresh()
