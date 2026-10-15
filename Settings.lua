local _, addon = ...

local canvas = CreateFrame("Frame", nil, UIParent)
canvas:Hide()
local scroll = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 0, 0)
scroll:SetPoint("BOTTOMRIGHT", -28, 0)
local panel = CreateFrame("Frame", nil, scroll)
panel:SetSize(560, 1058)
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
    { 20, "Frostfire" },
    { 0, "Other" },
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

local function openPicker(school, edge)
    if not ColorPickerFrame and C_AddOns then C_AddOns.LoadAddOn("Blizzard_ColorPicker") end
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
        print("DamageColor: The game color picker is unavailable.")
        return
    end
    closeOwnedPicker()
    local r, g, b = unpack(edge and addon.GetTextStyle(school).color or addon.colors[school])
    local function setColor(r, g, b)
        if edge then
            local style = addon.GetTextStyle(school)
            addon.SetTextStyle(school, style.mode, style.thickness, r, g, b)
        else
            addon.SetColor(school, r, g, b)
        end
    end
    local session = { active = true }
    pickerSession = session
    session.changed = function()
        if not session.active then return end
        setColor(ColorPickerFrame:GetColorRGB())
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b, hasOpacity = false,
        swatchFunc = session.changed,
        cancelFunc = function()
            if not session.active then return end
            session.active = false
            setColor(r, g, b)
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

local edgeSchool = 1
local edgeNames = { none = "None", outline = "Outline", glow = "Soft glow" }
local edgeTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
edgeTitle:SetPoint("TOPLEFT", 16, -624)
edgeTitle:SetText("Outline and glow")
local edgeSchoolDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
edgeSchoolDropdown:SetSize(350, 28)
edgeSchoolDropdown:SetPoint("TOPLEFT", 16, -656)
local edgeModeDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
edgeModeDropdown:SetSize(240, 28)
edgeModeDropdown:SetPoint("TOPLEFT", 16, -698)
local edgeWidthLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
edgeWidthLabel:SetPoint("TOPLEFT", 16, -742)
local edgeWidth = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
edgeWidth:SetSize(320, 18)
edgeWidth:SetPoint("TOPLEFT", 16, -770)
edgeWidth:SetMinMaxValues(1, 6)
edgeWidth:SetValueStep(0.25)
edgeWidth:SetObeyStepOnDrag(true)
local edgeColor = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
edgeColor:SetSize(240, 28)
edgeColor:SetPoint("TOPLEFT", 16, -812)
edgeColor:SetScript("OnClick", function() openPicker(edgeSchool, true) end)
local edgeSwatch = edgeColor:CreateTexture(nil, "OVERLAY")
edgeSwatch:SetSize(24, 20)
edgeSwatch:SetPoint("LEFT", edgeColor, "RIGHT", 12, 0)

local function setEdge(mode, width)
    local style = addon.GetTextStyle(edgeSchool)
    addon.SetTextStyle(edgeSchool, mode or style.mode, width or style.thickness, unpack(style.color))
end
edgeWidth:SetScript("OnValueChanged", function(_, value) setEdge(nil, value) end)

local sampleBox = CreateFrame("Frame", nil, panel)
sampleBox:SetSize(176, 100)
sampleBox:SetPoint("CENTER", edgeWidth, "RIGHT", 112, 0)
local sampleTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
sampleTitle:SetPoint("BOTTOM", sampleBox, "TOP", 0, 8)
sampleTitle:SetText("Number preview")
local sampleFrame = CreateFrame("Frame", nil, sampleBox)
sampleFrame:SetSize(1, 1)
sampleFrame:SetPoint("CENTER", sampleBox, "CENTER", 0, 0)
local sampleCritical = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
sampleCritical:SetSize(26, 26)
sampleCritical:SetPoint("TOPLEFT", sampleBox, "BOTTOMLEFT", 8, -8)
local criticalLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
criticalLabel:SetPoint("LEFT", sampleCritical, "RIGHT", 6, 0)
criticalLabel:SetText("Critical hit")
local numberSample = sampleFrame:CreateFontString(nil, "OVERLAY")
addon.ApplyFont(numberSample, addon.appearance.size)
numberSample:SetPoint("CENTER", sampleFrame, "CENTER", 0, 0)
numberSample:SetText("123")
local previewCritical = false

local function refresh()
    hideNative:SetChecked(addon.hideBlizzardDamage)
    fontDropdown:OverrideText(addon.GetFont().name)
    sizeLabel:SetText("Text size: " .. addon.appearance.size .. "   (critical: " .. addon.appearance.size * 2 .. ")")
    if sizeSlider:GetValue() ~= addon.appearance.size then sizeSlider:SetValue(addon.appearance.size) end
    local style = addon.GetTextStyle(edgeSchool)
    for _, school in ipairs(schools) do
        if school[1] == edgeSchool then
            edgeSchoolDropdown:OverrideText(school[2])
        end
    end
    edgeModeDropdown:OverrideText(edgeNames[style.mode])
    edgeWidthLabel:SetText("Thickness / glow radius: " .. style.thickness)
    if edgeWidth:GetValue() ~= style.thickness then edgeWidth:SetValue(style.thickness) end
    local er, eg, eb = unpack(style.color)
    edgeSwatch:SetColorTexture(er, eg, eb, 1)
    edgeColor:SetText(string.format("Edge color  #%02X%02X%02X", math.floor(er * 255 + 0.5), math.floor(eg * 255 + 0.5), math.floor(eb * 255 + 0.5)))
    for school, row in pairs(rows) do
        local r, g, b = unpack(addon.colors[school])
        row.swatch:SetColorTexture(r, g, b, 1)
        row.sample:SetTextColor(r, g, b)
        row.sample:SetText(string.format("123  #%02X%02X%02X",
            math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)))
    end
    local sampleSize = addon.appearance.size * (previewCritical and 2 or 1)
    addon.ApplyFont(numberSample, sampleSize)
    numberSample:SetTextColor(addon.GetColor(edgeSchool))
    addon.UpdateTextEffect(numberSample, edgeSchool, sampleSize, 1)
    -- Keep large critical samples inside the column; combat size is unchanged.
    local padding = style.thickness * 4
    local fit = math.min(1, 176 / math.max(1, numberSample:GetStringWidth() + padding),
        100 / math.max(1, numberSample:GetStringHeight() + padding))
    sampleFrame:SetScale(fit)
    sampleTitle:SetText(fit < 1 and "Number preview (scaled)" or "Number preview")
    numberSample:Show()
end
sampleCritical:SetScript("OnClick", function(self)
    previewCritical = self:GetChecked() == true
    refresh()
end)
edgeSchoolDropdown:SetupMenu(function(_, root)
    for _, school in ipairs(schools) do
        root:CreateRadio(school[2], function(key) return edgeSchool == key end,
            function(key) closeOwnedPicker(); edgeSchool = key; refresh() end, school[1])
    end
end)
edgeModeDropdown:SetupMenu(function(_, root)
    for _, mode in ipairs({ "none", "outline", "glow" }) do
        root:CreateRadio(edgeNames[mode], function(key) return addon.GetTextStyle(edgeSchool).mode == key end,
            function(key) setEdge(key) end, mode)
    end
end)
addon.OnPaletteChanged = function()
    refresh()
    addon.RefreshDisplayColors()
end
addon.OnAppearanceChanged = function()
    refresh()
    addon.RefreshTextAppearance()
end
addon.OnNativeDamageChanged = refresh
addon.OnTextStyleChanged = function()
    refresh()
    addon.RefreshDisplayColors()
    addon.RefreshTextAppearance()
end
panel:SetScript("OnShow", refresh)
canvas:SetScript("OnHide", closeOwnedPicker)

local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetSize(160, 28)
reset:SetPoint("TOPLEFT", 16, -904)
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
local resetEdge = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetEdge:SetSize(160, 28)
resetEdge:SetPoint("TOPLEFT", 16, -854)
resetEdge:SetText("Reset selected edge")
resetEdge:SetScript("OnClick", function()
    closeOwnedPicker()
    addon.ResetTextStyle(edgeSchool)
end)

local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
note:SetPoint("TOPLEFT", 16, -952)
note:SetWidth(520)
note:SetJustifyH("LEFT")
note:SetText("Choose a school under Outline and glow to customize its edge independently. Soft glow is a layered halo, rather than a shader blur. All attackers are included. Frostfire has its own settings; other mixed schools use Other.")

local category = Settings.RegisterCanvasLayoutCategory(canvas, "DamageColor")
Settings.RegisterAddOnCategory(category)
function addon.OpenSettings()
    Settings.OpenToCategory(category:GetID())
end
refresh()
