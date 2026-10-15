local _, addon = ...

local canvas = CreateFrame("Frame", nil, UIParent)
canvas:Hide()
local scroll = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 0, 0)
scroll:SetPoint("BOTTOMRIGHT", -28, 0)
local panel = CreateFrame("Frame", nil, scroll)
panel:SetSize(560, 300)
scroll:SetScrollChild(panel)
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("DamageColor")
local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
description:SetPoint("TOPLEFT", 16, -48)
description:SetWidth(520)
description:SetJustifyH("LEFT")
description:SetText("Choose Font, Style, or Profiles from the DamageColor submenus to customize your numbers.")

local pages, pageCanvases = {}, {}
for _, name in ipairs({ "Font", "Style", "Profiles" }) do
    local pageCanvas = CreateFrame("Frame", nil, UIParent)
    pageCanvas:Hide()
    local pageScroll = CreateFrame("ScrollFrame", nil, pageCanvas, "UIPanelScrollFrameTemplate")
    pageScroll:SetPoint("TOPLEFT", 0, 0)
    pageScroll:SetPoint("BOTTOMRIGHT", -28, 0)
    local page = CreateFrame("Frame", nil, pageScroll)
    page:SetSize(560, 640)
    pageScroll:SetScrollChild(page)
    local heading = pageCanvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetText(name)
    pageScroll:SetPoint("TOPLEFT", 0, -56)
    pages[name], pageCanvases[name] = page, pageCanvas
end
local general, stylePanel, profilesPanel = pages.Font, pages.Style, pages.Profiles

local fontLabel = general:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fontLabel:SetPoint("TOPLEFT", 16, -20)
fontLabel:SetText("Font")
local fontDropdown = CreateFrame("DropdownButton", nil, general, "WowStyle1DropdownTemplate")
fontDropdown:SetSize(240, 28)
fontDropdown:SetPoint("TOPLEFT", 90, -12)
fontDropdown:SetupMenu(function(_, root)
    for _, font in ipairs(addon.fonts) do
        root:CreateRadio(font.name, function(key) return addon.appearance.font == key end,
            function(key) addon.SetAppearance(key, addon.appearance.size) end, font.key)
    end
end)

local sizeLabel = general:CreateFontString(nil, "ARTWORK", "GameFontNormal")
sizeLabel:SetPoint("TOPLEFT", 16, -100)
local sizeSlider = CreateFrame("Slider", nil, general, "OptionsSliderTemplate")
sizeSlider:SetPoint("TOPLEFT", 16, -128)
sizeSlider:SetSize(320, 18)
sizeSlider:SetMinMaxValues(12, 96)
sizeSlider:SetValueStep(1)
sizeSlider:SetObeyStepOnDrag(true)
sizeSlider:SetScript("OnValueChanged", function(_, value)
    addon.SetAppearance(addon.appearance.font, value)
end)
local hideNative = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
hideNative:SetSize(26, 26)
hideNative:SetPoint("TOPLEFT", 16, -100)
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
    { -1, "Miss / resist text" },
}

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

local edgeSchool = 1
local edgeNames = { none = "None", outline = "Outline", glow = "Soft glow" }
local edgeTitle = stylePanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
edgeTitle:SetPoint("TOPLEFT", 16, -16)
edgeTitle:SetText("Number type")
local edgeSchoolDropdown = CreateFrame("DropdownButton", nil, stylePanel, "WowStyle1DropdownTemplate")
edgeSchoolDropdown:SetSize(350, 28)
edgeSchoolDropdown:SetPoint("TOPLEFT", 16, -48)
local edgeModeDropdown = CreateFrame("DropdownButton", nil, stylePanel, "WowStyle1DropdownTemplate")
edgeModeDropdown:SetSize(240, 28)
edgeModeDropdown:SetPoint("TOPLEFT", 16, -138)
local edgeWidthLabel = stylePanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
edgeWidthLabel:SetPoint("TOPLEFT", 16, -180)
local edgeWidth = CreateFrame("Slider", nil, stylePanel, "OptionsSliderTemplate")
edgeWidth:SetSize(320, 18)
edgeWidth:SetPoint("TOPLEFT", 16, -208)
edgeWidth:SetMinMaxValues(1, 6)
edgeWidth:SetValueStep(0.25)
edgeWidth:SetObeyStepOnDrag(true)
local edgeColor = CreateFrame("Button", nil, stylePanel, "UIPanelButtonTemplate")
edgeColor:SetSize(240, 28)
edgeColor:SetPoint("TOPLEFT", 16, -250)
edgeColor:SetScript("OnClick", function() openPicker(edgeSchool, true) end)
local edgeSwatch = edgeColor:CreateTexture(nil, "OVERLAY")
edgeSwatch:SetSize(24, 20)
edgeSwatch:SetPoint("LEFT", edgeColor, "RIGHT", 12, 0)

local function setEdge(mode, width)
    local style = addon.GetTextStyle(edgeSchool)
    addon.SetTextStyle(edgeSchool, mode or style.mode, width or style.thickness, unpack(style.color))
end
edgeWidth:SetScript("OnValueChanged", function(_, value) setEdge(nil, value) end)

local sampleBox = CreateFrame("Frame", nil, stylePanel)
sampleBox:SetSize(176, 100)
sampleBox:SetPoint("CENTER", edgeWidth, "RIGHT", 112, 0)
local sampleTitle = stylePanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
sampleTitle:SetPoint("BOTTOM", sampleBox, "TOP", 0, 8)
sampleTitle:SetText("Number preview")
local sampleFrame = CreateFrame("Frame", nil, sampleBox)
sampleFrame:SetSize(1, 1)
sampleFrame:SetPoint("CENTER", sampleBox, "CENTER", 0, 0)
local sampleCritical = CreateFrame("CheckButton", nil, stylePanel, "ChatConfigCheckButtonTemplate")
sampleCritical:SetSize(26, 26)
sampleCritical:SetPoint("TOPLEFT", sampleBox, "BOTTOMLEFT", 8, -8)
local criticalLabel = stylePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
criticalLabel:SetPoint("LEFT", sampleCritical, "RIGHT", 6, 0)
criticalLabel:SetText("Critical hit")
local numberSample = sampleFrame:CreateFontString(nil, "OVERLAY")
addon.ApplyFont(numberSample, addon.appearance.size)
numberSample:SetPoint("CENTER", sampleFrame, "CENTER", 0, 0)
numberSample:SetText("123")
local previewCritical = false

local textColor = CreateFrame("Button", nil, stylePanel, "UIPanelButtonTemplate")
textColor:SetSize(240, 28)
textColor:SetPoint("TOPLEFT", 16, -94)
textColor:SetScript("OnClick", function() openPicker(edgeSchool) end)
local textSwatch = textColor:CreateTexture(nil, "OVERLAY")
textSwatch:SetSize(24, 20)
textSwatch:SetPoint("LEFT", textColor, "RIGHT", 12, 0)
local fontSampleFrame = CreateFrame("Frame", nil, general)
fontSampleFrame:SetSize(1, 1)
fontSampleFrame:SetPoint("CENTER", general, "TOPLEFT", 450, -66)
local fontSample = fontSampleFrame:CreateFontString(nil, "OVERLAY")
addon.ApplyFont(fontSample, addon.appearance.size)
fontSample:SetPoint("CENTER", fontSampleFrame, "CENTER", 0, 0)
fontSample:SetText("123")
fontSample:SetTextColor(1, 1, 1)
local fontPreviewLabel = general:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fontPreviewLabel:SetPoint("TOPLEFT", 380, -8)
fontPreviewLabel:SetText("Font preview")
local refreshProfiles
local function refresh()
    if refreshProfiles then refreshProfiles() end
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
    local r, g, b = unpack(addon.colors[edgeSchool])
    textSwatch:SetColorTexture(r, g, b, 1)
    textColor:SetText(string.format("Text color  #%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)))
    addon.ApplyFont(fontSample, addon.appearance.size)
    fontSampleFrame:SetScale(math.min(1, 176 / math.max(1, fontSample:GetStringWidth()), 100 / math.max(1, fontSample:GetStringHeight())))
    local sampleSize = addon.appearance.size * (previewCritical and edgeSchool ~= -1 and 2 or 1)
    addon.ApplyFont(numberSample, sampleSize)
    numberSample:SetText(edgeSchool == -1 and "Miss" or "123")
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

local profileDropdown = CreateFrame("DropdownButton", nil, profilesPanel, "WowStyle1DropdownTemplate")
profileDropdown:SetSize(240, 28)
profileDropdown:SetPoint("TOPLEFT", 16, -24)
local profileName = CreateFrame("EditBox", nil, profilesPanel, "InputBoxTemplate")
profileName:SetSize(240, 28)
profileName:SetPoint("TOPLEFT", 22, -84)
profileName:SetAutoFocus(false)
profileName:SetMaxLetters(40)
profileName:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
profileName:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
local profileNameLabel = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
profileNameLabel:SetPoint("TOPLEFT", 16, -64)
profileNameLabel:SetText("Save current settings as")
local saveProfile = CreateFrame("Button", nil, profilesPanel, "UIPanelButtonTemplate")
saveProfile:SetSize(160, 28)
saveProfile:SetPoint("TOPLEFT", 280, -84)
saveProfile:SetText("Save profile")
local profileStatus = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
profileStatus:SetPoint("TOPLEFT", 16, -128)
profileStatus:SetWidth(520)
profileStatus:SetJustifyH("LEFT")
local selectedProfile
local profileSamples = {}
local profilePreviewTitle = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
profilePreviewTitle:SetPoint("TOPLEFT", 16, -184)
profilePreviewTitle:SetText("Saved profile preview (scaled to fit)")
for i, school in ipairs(schools) do
    local cell = CreateFrame("Frame", nil, profilesPanel)
    cell:SetSize(100, 120)
    cell:SetPoint("TOPLEFT", 16 + ((i - 1) % 5) * 106, -216 - math.floor((i - 1) / 5) * 140)
    local label = cell:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOP", cell, "TOP", 0, 0)
    label:SetWidth(100)
    label:SetText(school[1] == 1 and "Physical" or (school[1] == -1 and "Miss / Resist" or school[2]))
    local holder = CreateFrame("Frame", nil, cell)
    holder:SetSize(1, 1)
    holder:SetPoint("CENTER", cell, "CENTER", 0, -8)
    local text = holder:CreateFontString(nil, "OVERLAY")
    addon.ApplyFont(text, addon.appearance.size)
    text:SetPoint("CENTER", holder, "CENTER", 0, 0)
    text:SetText(school[1] == -1 and "Miss" or "123")
    profileSamples[school[1]] = { text = text, holder = holder }
end
refreshProfiles = function()
    local name = selectedProfile or addon.activeProfile or "Default"
    profileDropdown:OverrideText("Profile: " .. name)
    profileStatus:SetText("Active: " .. (addon.activeProfile or "Default") .. ". " .. (addon.ProfileIsDirty()
        and "Unsaved changes. Save to keep them before loading another profile."
        or "Saved. Enter a new name to save a copy. Default stays fixed."))
    local profile = addon.GetProfile(name) or addon.GetDefaultProfile()
    local path = STANDARD_TEXT_FONT
    for _, font in ipairs(addon.fonts) do
        if font.key == profile.appearance.font then path = font.path end
    end
    for school, sample in pairs(profileSamples) do
        local style, size = profile.textStyles[school], profile.appearance.size
        if sample.text:SetFont(path, size, "") == false then sample.text:SetFont(STANDARD_TEXT_FONT, size, "") end
        sample.text:SetTextColor(unpack(profile.colors[school]))
        addon.UpdateTextEffect(sample.text, school, size, 1, style, path)
        local padding = style.mode == "none" and 0 or style.thickness * 4
        sample.holder:SetScale(math.min(1, 92 / math.max(1, sample.text:GetStringWidth() + padding),
            88 / math.max(1, sample.text:GetStringHeight() + padding)))
        sample.text:Show()
    end
end
addon.OnProfilesChanged = function()
    selectedProfile = addon.activeProfile
    profileName:SetText(addon.activeProfile or "Default")
    refreshProfiles()
end
StaticPopupDialogs.DAMAGECOLOR_LOAD_PROFILE = {
    text = "Load profile %s? All changes not saved to a profile will be lost.",
    button1 = "Load profile", button2 = CANCEL,
    OnAccept = function(_, name)
        closeOwnedPicker()
        addon.LoadProfile(name)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
profileDropdown:SetupMenu(function(_, root)
    for _, name in ipairs(addon.GetProfileNames()) do
        root:CreateRadio(name, function(key) return (selectedProfile or addon.activeProfile) == key end,
            function(key) selectedProfile = key; refreshProfiles() end, name)
    end
end)
local loadProfile = CreateFrame("Button", nil, profilesPanel, "UIPanelButtonTemplate")
loadProfile:SetSize(160, 28)
loadProfile:SetPoint("TOPLEFT", 280, -24)
loadProfile:SetText("Load profile")
loadProfile:SetScript("OnClick", function()
    local name = selectedProfile or addon.activeProfile or "Default"
    StaticPopup_Show("DAMAGECOLOR_LOAD_PROFILE", name, nil, name)
end)
saveProfile:SetScript("OnClick", function()
    closeOwnedPicker()
    local _, message = addon.SaveProfile(profileName:GetText())
    print("DamageColor: " .. message)
end)
profileName:SetText(addon.activeProfile or "Default")

local reset = CreateFrame("Button", nil, stylePanel, "UIPanelButtonTemplate")
reset:SetSize(160, 28)
reset:SetPoint("TOPLEFT", 16, -350)
reset:SetText("Reset colors")
reset:SetScript("OnClick", function()
    closeOwnedPicker()
    addon.ResetColors()
end)
local preview = CreateFrame("Button", nil, stylePanel, "UIPanelButtonTemplate")
preview:SetSize(160, 28)
preview:SetPoint("LEFT", reset, "RIGHT", 12, 0)
preview:SetText("Preview colors")
preview:SetScript("OnClick", function() addon.ShowPreview() end)
local resetText = CreateFrame("Button", nil, general, "UIPanelButtonTemplate")
resetText:SetSize(160, 28)
resetText:SetPoint("TOPLEFT", 16, -180)
resetText:SetText("Reset font / size")
resetText:SetScript("OnClick", function() addon.SetAppearance("default", 48) end)
local resetEdge = CreateFrame("Button", nil, stylePanel, "UIPanelButtonTemplate")
resetEdge:SetSize(160, 28)
resetEdge:SetPoint("TOPLEFT", 16, -300)
resetEdge:SetText("Reset selected edge")
resetEdge:SetScript("OnClick", function()
    closeOwnedPicker()
    addon.ResetTextStyle(edgeSchool)
end)

local note = stylePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
note:SetPoint("TOPLEFT", 16, -404)
note:SetWidth(520)
note:SetJustifyH("LEFT")
note:SetText("Choose a number type to customize its text and edge together. Soft glow is a layered halo, rather than a shader blur. All attackers are included. Frostfire has its own settings; other mixed schools use Other.")

local category = Settings.RegisterCanvasLayoutCategory(canvas, "DamageColor")
Settings.RegisterAddOnCategory(category)
for _, name in ipairs({ "Font", "Style", "Profiles" }) do
    local pageCanvas = pageCanvases[name]
    Settings.RegisterCanvasLayoutSubcategory(category, pageCanvas, name)
    pageCanvas:SetScript("OnShow", refresh)
    pageCanvas:SetScript("OnHide", closeOwnedPicker)
end
function addon.OpenSettings()
    Settings.OpenToCategory(category:GetID())
end
refresh()
