-- Run from the repository root with Lua 5.1: lua tests/settings_test.lua
local frames, opened = {}, nil
local methods = {}
for _, name in ipairs({ "SetSize", "SetPoint", "SetAllPoints", "ClearAllPoints",
    "SetWidth", "SetJustifyH", "SetFrameStrata", "SetScrollChild",
    "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag" }) do
    methods[name] = function() end
end
function methods:SetFont(path, size, flags) self.fontPath, self.fontSize, self.fontFlags = path, size, flags; return true end
function methods:GetScript(name) return self.scripts[name] end
function methods:GetText() return self.text end
function methods:SetAutoFocus() end
function methods:SetEnabled(value) self.enabled = value end
function methods:SetMaxLetters() end
function methods:ClearFocus() end
StaticPopupDialogs = {}
CANCEL = "Cancel"
local lastPopup
function StaticPopup_Show(key, name, _, data) lastPopup = { key = key, name = name, data = data } end
function methods:GetParent() return self.parent end
function methods:GetStringWidth() return #(self.text or "") * (self.fontSize or 12) * 0.6 end
function methods:GetStringHeight() return self.fontSize or 12 end
function methods:SetScale(scale) self.scale = scale end
function methods:SetMinMaxValues(low, high) self.minimum, self.maximum = low, high end
function methods:OverrideText(text) self.text = text end
function methods:SetupMenu(generator)
    self.menuGenerator = generator
    self.choices = {}
    local choices = self.choices
    generator(self, { CreateRadio = function(_, name, selected, selectFont, key)
        choices[key] = function() selectFont(key) end
    end })
end
function methods:GetValue() return self.value end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetValue(value)
    if self.minimum then value = math.max(self.minimum, math.min(self.maximum, value)) end
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:SetPoint(...) self.point = { ... } end
function methods:GetCenter() return self.x, self.y end
function methods:GetTop()
    if type(self.y) ~= "number" then return self.y end
    return self.y + 10
end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:GetHeight() return self.height or 1080 end
function methods:IsForbidden() return self.forbidden or false end
function methods:IsVisible() return self.shown end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:RegisterUnitEvent(event, unit) self.events[event] = unit end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:SetText(value)
    if self.kind == "FontString" then assert(self.fontPath, "FontString:SetText(): Font not set") end
    self.text = value
end
function methods:SetTextColor(...) self.color = { ... } end
function methods:SetColorTexture(...) self.color = { ... } end
function methods:Show()
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({ scripts = {}, events = {}, template = template, parent = parent, kind = kind }, { __index = methods })
    frames[#frames + 1] = frame
    return frame
end
function methods:CreateFontString(_, layer, fontObject)
    local text = CreateFrame("FontString", nil, self)
    text.drawLayer = layer
    if fontObject then text.fontPath = "inherited-font" end
    return text
end
function methods:CreateTexture() return CreateFrame("Texture") end
UIParent = CreateFrame("Frame")
UIParent.scale = 0.8
local plate = CreateFrame("Frame")
plate.x, plate.y, plate.scale, plate.shown = 400, 300, 0.6, true
C_NamePlate = { GetNamePlateForUnit = function(unit) assert(unit == "target"); return plate end }
STANDARD_TEXT_FONT = "test-font"
SlashCmdList = {}
local timers = {}
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay, callback } end }
local function runRemovalTimers()
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do if timer[1] == 0.5 then timer[2]() end end
end
local cvars, denyCVarWrites = { floatingCombatTextCombatDamage_v2 = "1" }, false
C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, value)
        if denyCVarWrites then error("restricted in combat") end
        cvars[name] = value
    end,
}
local submenus = {}
local rootCategory
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        assert(name == "DamageColor")
        rootCategory = { GetID = function() return 17 end }
        return rootCategory
    end,
    RegisterCanvasLayoutSubcategory = function(parent, canvas, name)
        assert(parent == rootCategory, "Submenus must belong to DamageColor")
        submenus[name] = canvas
        return { GetID = function() return name end }
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) opened = id end,
}
ColorPickerFrame = CreateFrame("Frame")
function ColorPickerFrame:SetupColorPickerAndShow(info)
    self.info, self.swatchFunc = info, info.swatchFunc
    self.rgb = { info.r, info.g, info.b }
    self:Show()
end
function ColorPickerFrame:GetColorRGB() return unpack(self.rgb) end
local function rgb(color, r, g, b)
    assert(color[1] == r and color[2] == g and color[3] == b, "Unexpected color")
end
local function click(label)
    for _, frame in ipairs(frames) do
        if frame.text == label and frame.scripts.OnClick then
            frame.scripts.OnClick(frame)
            return
        end
    end
    error("Missing button: " .. label)
end
local function editTextColor(school)
    for _, frame in ipairs(frames) do
        if frame.choices and frame.choices[school] then frame.choices[school](); break end
    end
    for _, frame in ipairs(frames) do
        if type(frame.text) == "string" and frame.text:find("Text color", 1, true) and frame.scripts.OnClick then
            frame.scripts.OnClick(frame); return
        end
    end
    error("Missing selected-type text color control")
end
local function loadAddon(saved)
    DamageColorDB = saved
    frames = {}
    local addon = {}
    for _, file in ipairs({ "Palette.lua", "TextEffects.lua", "NativeDamage.lua", "NativeDamageTaken.lua", "Presets.lua", "Profiles.lua", "DamageColor.lua", "Settings.lua" }) do
        assert(loadfile(file))("DamageColor", addon)
    end
    for _, frame in ipairs(frames) do
        if frame.events.ADDON_LOADED then frame.scripts.OnEvent(frame, "ADDON_LOADED", "DamageColor") end
    end
    return addon
end

local addon = loadAddon(nil)
rgb(addon.colors[2], 1, 0.95, 0.60)
SlashCmdList.DAMAGECOLOR("")
assert(opened == 17, "Slash command must open the settings category")
editTextColor(2)
ColorPickerFrame.rgb = { 0.1, 0.2, 0.3 }
ColorPickerFrame.info.swatchFunc()
rgb(DamageColorDB.colors[2], 0.1, 0.2, 0.3)
ColorPickerFrame.info.cancelFunc()
rgb(addon.colors[2], 1, 0.95, 0.60)
rgb(DamageColorDB.colors[2], 1, 0.95, 0.60)

addon.SetColor(2, 0.1, 0.2, 0.3)
addon = loadAddon(DamageColorDB)
rgb(addon.colors[2], 0.1, 0.2, 0.3) -- Reload preserves the saved color.
local r, g, b = addon.GetColor(2)
rgb({ r, g, b }, 0.1, 0.2, 0.3)
addon.SetColor(0, 0.4, 0.5, 0.6)
rgb({ addon.GetColor(6) }, 0.4, 0.5, 0.6) -- Other mixed-school fallback.
addon.SetColor(20, 0.9, 0.3, 0.6)
rgb({ addon.GetColor(20) }, 0.9, 0.3, 0.6)
rgb({ addon.GetColor(6) }, 0.4, 0.5, 0.6) -- Frostfire changes must not affect Other.
rgb({ addon.GetColor(1) }, 1, 0.20, 0.20) -- Physical hits, including swings, share red.
editTextColor(2)
local staleCancel = ColorPickerFrame.info.cancelFunc
click("Reset colors")
staleCancel()
rgb(addon.colors[2], 1, 0.95, 0.60)
rgb(DamageColorDB.colors[0], 1, 1, 0)

-- The live path uses chosen colors and snapshots the nameplate's UI position.
local damageFrame
for _, frame in ipairs(frames) do
    if frame.events.UNIT_COMBAT == "target" then damageFrame = frame end
end
assert(damageFrame, "Missing live target listener")
addon.SetColor(2, 0.2, 0.3, 0.4)
damageFrame.scripts.OnEvent(damageFrame, "UNIT_COMBAT", "target", "WOUND", "", 456, 2)
local liveNumber
for _, frame in ipairs(frames) do
    if frame.text == "456" and frame.drawLayer == "OVERLAY" then liveNumber = frame end
end
assert(liveNumber and liveNumber.shown, "Holy damage must create a live number")
rgb(liveNumber.color, 0.2, 0.3, 0.4)
addon.SetColor(2, 0.5, 0.6, 0.7)
rgb(liveNumber.color, 0.5, 0.6, 0.7)
damageFrame.scripts.OnEvent(damageFrame, "UNIT_COMBAT", "target", "WOUND", "", 789, 1)
local physical
for _, frame in ipairs(frames) do if frame.text == "789" and frame.drawLayer == "OVERLAY" then physical = frame end end
assert(physical and physical.shown, "Physical hits must appear on the overlay")
rgb(physical.color, 1, 0.20, 0.20)
local originalX, originalY = physical.point[4], physical.point[5]
assert(originalY >= 286.5, "Impact position must stay above the scaled nameplate")
local function separated(a, b, sizeA, sizeB)
    local width = (#a.text * sizeA * 1.1 * 0.6 + #b.text * sizeB * 1.1 * 0.6) / 2
    local height = (sizeA + sizeB) * 1.1 / 2
    return math.abs(a.point[4] - b.point[4]) >= width
        or math.abs(a.point[5] - b.point[5]) >= height
end
assert(separated(physical, liveNumber, 48, 48), "Consecutive hits must leave room for their settled size")
assert(math.abs(physical.point[4] - liveNumber.point[4]) < 180
    and math.abs(physical.point[5] - liveNumber.point[5]) < 120,
    "Consecutive normal hits must stay close together")
local burst = { physical, liveNumber }
for i = 1, 6 do
    local critical = i % 2 == 0
    damageFrame.scripts.OnEvent(damageFrame, "UNIT_COMBAT", "target", "WOUND",
        critical and "CRITICAL" or "", 8800 + i, 1)
    local added
    for _, frame in ipairs(frames) do
        if frame.text == tostring(8800 + i) and frame.drawLayer == "OVERLAY" then added = frame end
    end
    assert(added and added.shown)
    for _, previous in ipairs(burst) do
        assert(separated(added, previous, critical and 96 or 48, previous.testSize or 48),
            "Burst hits, including criticals, must avoid existing numbers")
    end
    added.testSize = critical and 96 or 48
    burst[#burst + 1] = added
end
local live = physical.parent
plate.x, plate.y = 800, 600 -- Old hits must not jump to a new target/nameplate position.
live.scripts.OnUpdate(live, 0.08)
assert(math.abs(physical.fontSize - 72) < 0.001, "Normal hit must pop to 150% of its doubled base size")
assert(physical.point[4] == originalX and math.abs(physical.point[5] - originalY - 0.96) < 0.001)
live.scripts.OnUpdate(live, 0.16)
assert(math.abs(physical.fontSize - 48) < 0.001, "Normal hit must settle to doubled size")
live.scripts.OnUpdate(live, 1.31)
assert(physical.alpha > 0 and physical.alpha < 1, "Hit must fade")
live.scripts.OnUpdate(live, 0.25)
assert(not physical.shown, "Hit must expire")

local function assertSkipped(amount)
    damageFrame.scripts.OnEvent(damageFrame, "UNIT_COMBAT", "target", "WOUND", "", amount, 2)
    for _, frame in ipairs(frames) do assert(frame.text ~= tostring(amount), "Inaccessible plate must skip the hit") end
end
plate.shown = false
assertSkipped(901)
plate.shown, plate.forbidden = true, true
assertSkipped(902)
plate.forbidden = false
local savedLookup = C_NamePlate.GetNamePlateForUnit
C_NamePlate.GetNamePlateForUnit = function() error("restricted") end
assertSkipped(903)
C_NamePlate.GetNamePlateForUnit = savedLookup

-- Accessible frames with secret geometry must still render by direct anchor.
local secretPosition = {}
issecretvalue = function(value) return value == secretPosition end
plate.x, plate.y = secretPosition, secretPosition
damageFrame.scripts.OnEvent(damageFrame, "UNIT_COMBAT", "target", "WOUND", "", 904, 1)
local anchored
for _, frame in ipairs(frames) do if frame.text == "904" and frame.drawLayer == "OVERLAY" then anchored = frame end end
assert(anchored and anchored.shown, "Secret geometry must not discard a readable damage event")
assert(anchored.point[2] == plate, "Secret geometry must use a direct frame anchor")
damageFrame.scripts.OnEvent(damageFrame, "PLAYER_TARGET_CHANGED")
assert(anchored.shown, "Target changes must not truncate an existing damage number")
plate.x, plate.y = 400, 300
issecretvalue = nil

-- Mouseover and AoE hits are delivered through each visible nameplate token.
local second = CreateFrame("Frame")
second.x, second.y, second.shown = 700, 400, true
local friendly = CreateFrame("Frame")
friendly.x, friendly.y, friendly.shown = 100, 100, true
local plates = { nameplate1 = plate, nameplate2 = second, nameplate3 = friendly }
plate.namePlateUnitToken, second.namePlateUnitToken = "nameplate1", "nameplate2"
C_NamePlate.GetNamePlateForUnit = function(unit)
    if unit == "target" then return plate end
    return plates[unit]
end
C_NamePlate.GetNamePlates = function() return { plate, second } end
UnitCanAttack = function(_, unit) return unit ~= "nameplate3" end
damageFrame.scripts.OnEvent(damageFrame, "PLAYER_ENTERING_WORLD")
damageFrame.scripts.OnEvent(damageFrame, "NAME_PLATE_UNIT_ADDED", "nameplate3")
local function listener(unit)
    for _, frame in ipairs(frames) do
        if frame.events.UNIT_COMBAT == unit then return frame end
    end
    error("Missing nameplate listener: " .. unit)
end
local function hit(unit, amount, flags, school)
    local frame = listener(unit)
    frame.scripts.OnEvent(frame, "UNIT_COMBAT", unit, "WOUND", flags or "", amount, school or 4)
end
local function number(amount)
    for _, frame in ipairs(frames) do if frame.text == tostring(amount) and frame.drawLayer == "OVERLAY" then return frame end end
end
hit("nameplate2", 1001)
assert(number(1001) and number(1001).shown, "Off-target mouseover damage must display")
assert(number(1001).point[4] > 800, "Off-target hit must be positioned at its own plate")
hit("nameplate1", 1002)
hit("nameplate2", 1003)
assert(number(1002).shown and number(1003).shown, "AoE must display on both enemies")
hit("nameplate3", 1004)
assert(not number(1004), "Known friendly units must not display damage")
damageFrame.scripts.OnEvent(damageFrame, "UNIT_COMBAT", "target", "WOUND", "", 1005, 4)
assert(not number(1005), "Target alias must not duplicate its subscribed nameplate")
hit("nameplate1", 1005)
assert(number(1005).shown, "Canonical nameplate hit must still display")
second.x, second.y = secretPosition, secretPosition
issecretvalue = function(value) return value == secretPosition end
hit("nameplate2", 1006)
assert(number(1006).point[2] == second and number(1006).point[3] == "TOP",
    "Secret geometry fallback must anchor above the correct plate")
assert(number(1006).point[5] >= 36, "Direct anchor must clear the nameplate")
damageFrame.scripts.OnEvent(damageFrame, "PLAYER_TARGET_CHANGED")
assert(number(1006).shown, "Changing targets must not hide off-target damage")
damageFrame.scripts.OnEvent(damageFrame, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
assert(number(1006).shown, "Removing another plate must not hide this enemy's hits")
damageFrame.scripts.OnEvent(damageFrame, "NAME_PLATE_UNIT_REMOVED", "nameplate2")
assert(number(1006).shown and number(1006).point[2] == UIParent,
    "Dying enemy's anchored damage must detach and linger at its cached position")
second.shown = false
hit("nameplate2", 1007, "", 1)
hit("nameplate2", 1008, "CRITICAL", 2)
assert(number(1007).shown and number(1008).shown, "Late auto-attack and skill killing blows must display")
rgb(number(1007).color, 1, 0.20, 0.20)
local deathX = number(1007).point[4]
second.x, second.y = 900, 700
live.scripts.OnUpdate(live, 1.4)
assert(number(1007).shown and number(1008).shown, "Killing blows must linger beyond one second")
assert(number(1007).point[4] == deathX, "Killing blow must not move with a recycled plate")
live.scripts.OnUpdate(live, 0.41)
assert(not number(1007).shown and not number(1008).shown, "Killing blows must eventually expire")
runRemovalTimers()
for _, frame in ipairs(frames) do assert(frame.events.UNIT_COMBAT ~= "nameplate2", "Removed plate must unsubscribe") end
hit("nameplate3", 2000) -- Friendly damage remains filtered.
plate.x, plate.y = 400, 300
damageFrame.scripts.OnEvent(damageFrame, "NAME_PLATE_UNIT_ADDED", "nameplate1")
damageFrame.scripts.OnEvent(damageFrame, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
damageFrame.scripts.OnEvent(damageFrame, "NAME_PLATE_UNIT_ADDED", "nameplate1")
runRemovalTimers()
assert(listener("nameplate1"), "Old grace timer must not unsubscribe a reused nameplate")
hit("nameplate1", 2001, "CRITICAL")
hit("nameplate1", 2002)
local crit, normal = number(2001), number(2002)
assert(crit and normal and math.abs(crit.fontSize - 2 * normal.fontSize) < 0.001,
    "Critical must start at twice normal size")
live.scripts.OnUpdate(live, 0.08)
assert(math.abs(crit.fontSize - 144) < 0.001 and math.abs(normal.fontSize - 72) < 0.001,
    "Critical must remain twice normal size during the pop")
live.scripts.OnUpdate(live, 0.16)
assert(math.abs(crit.fontSize - 96) < 0.001 and math.abs(normal.fontSize - 48) < 0.001,
    "Critical must settle at 96 versus normal 48")
-- Reuse the critical slot and ensure a normal hit does not inherit its size.
for amount = 2101, 2164 do hit("nameplate1", amount) end
assert(math.abs(crit.fontSize - 48 * 0.85) < 0.001, "Reused slots must reset critical sizing")
issecretvalue, UnitCanAttack = nil, nil

-- Reproduce the user's trace: a plate whose coordinates were NEVER readable.
local secretPlate = CreateFrame("Frame")
secretPlate.x, secretPlate.y, secretPlate.shown = secretPosition, secretPosition, true
plates.nameplate4 = secretPlate
issecretvalue = function(value) return value == secretPosition end
damageFrame.scripts.OnEvent(damageFrame, "NAME_PLATE_UNIT_ADDED", "nameplate4")
hit("nameplate4", 2901, "", 1)
hit("nameplate4", 2902, "CRITICAL", 2)
secretPlate.shown = false
damageFrame.scripts.OnEvent(damageFrame, "NAME_PLATE_UNIT_REMOVED", "nameplate4")
assert(number(2901).shown and number(2902).shown, "Secret-only death must not clear existing auto/skill hits")
assert(number(2902).parent == live and number(2902).point[2] == secretPlate,
    "Lingering text must have an independent parent and retain only a frame anchor")
hit("nameplate4", 2903, "", 1)
assert(number(2903).shown, "Late killing blow must render even without any coordinate cache")
runRemovalTimers()
live.scripts.OnUpdate(live, 1.4)
assert(number(2901).shown and number(2902).shown and number(2903).shown,
    "Hidden-anchor numbers must survive listener cleanup and linger beyond one second")
secretPlate.shown = true
damageFrame.scripts.OnEvent(damageFrame, "NAME_PLATE_UNIT_ADDED", "nameplate4")
assert(not number(2901).shown and not number(2903).shown, "Reusing a secret-only plate must clear its old hits")
hit("nameplate4", 2904)
secretPlate.shown = false
damageFrame.scripts.OnEvent(damageFrame, "NAME_PLATE_UNIT_REMOVED", "nameplate4")
live.scripts.OnUpdate(live, 1.81)
assert(not number(2904).shown, "Hidden-anchor hits must expire normally without plate reuse")
issecretvalue = nil

-- Settings controls apply font and size immediately and preserve crit scaling.
local dropdown, slider
for _, frame in ipairs(frames) do
    if frame.choices and frame.choices.arial then dropdown = frame end
    if frame.template == "OptionsSliderTemplate" and frame.minimum == 12 and frame.maximum == 96 then slider = frame end
end
assert(dropdown and slider, "Missing font or size control")
dropdown.choices.arial()
slider:SetValue(32)
assert(addon.appearance.font == "arial" and addon.appearance.size == 32)
assert(DamageColorDB.appearance.font == "arial" and DamageColorDB.appearance.size == 32)
hit("nameplate1", 3001, "CRITICAL")
hit("nameplate1", 3002)
assert(number(3001).fontPath == "Fonts\\ARIALN.TTF")
assert(math.abs(number(3001).fontSize - 2 * number(3002).fontSize) < 0.001)
slider:SetValue(40)
assert(math.abs(number(3001).fontSize - 80 * 0.85) < 0.001, "Active crit must resize immediately")
assert(math.abs(number(3002).fontSize - 40 * 0.85) < 0.001, "Active normal hit must resize immediately")
addon = loadAddon(DamageColorDB)
assert(addon.appearance.font == "arial" and addon.appearance.size == 40, "Appearance must survive reload")
addon.SetAppearance("missing", 30)
addon.SetAppearance("arial", 0/0)
addon.SetAppearance("arial", 1000)
assert(addon.appearance.size == 40, "Invalid appearance changes must be rejected")
click("Reset font / size")
assert(addon.appearance.font == "default" and addon.appearance.size == 48)
addon = loadAddon({ appearance = { font = "missing", size = -10 } })
assert(addon.appearance.font == "default" and addon.appearance.size == 48, "Invalid saved appearance must recover")

addon = loadAddon({ colors = { [2] = { 0/0, 1, 1 }, [4] = { 1, -1, 0 }, [8] = "bad" } })
rgb(addon.colors[2], 1, 0.95, 0.60)
rgb(addon.colors[4], 1, 0.50, 0.10)
rgb(addon.colors[8], 0.25, 1, 0.30)
addon.SetColor(2, math.huge, 0, 0)
rgb(addon.colors[2], 1, 0.95, 0.60)

-- Hide-native setting defaults on, restores prior values, and survives reload.
addon = loadAddon(nil)
rgb({ addon.GetColor(20) }, 0.55, 0.85, 1)
assert(addon.GetTextStyle(20).mode == "outline")
rgb(addon.GetTextStyle(20).color, 1, 0.5, 0.1)
addon.ResetTextStyle(20)
assert(addon.GetTextStyle(20).mode == "outline", "Frostfire reset must restore its orange outline")
addon = loadAddon({ colors = { [20] = { 1, 1, 0 } }, textStyles = {
    [20] = { mode = "none", thickness = 1.5, color = { 1, 1, 1 } },
}, textStyleDefaultsVersion = 3 })
rgb({ addon.GetColor(20) }, 0.55, 0.85, 1)
assert(addon.GetTextStyle(20).mode == "outline", "Previous inherited Frostfire defaults must migrate")
addon.SetColor(20, 0.2, 0.3, 0.4)
addon.SetTextStyle(20, "none", 2, 0.7, 0.1, 0.1)
addon = loadAddon(DamageColorDB)
rgb({ addon.GetColor(20) }, 0.2, 0.3, 0.4)
assert(addon.GetTextStyle(20).mode == "none", "Explicit Frostfire customizations must survive reload")
-- Each school's edge is independent, saved, and can be completely removed.
local edgeMode, edgeSchool, edgeWidth
for _, frame in ipairs(frames) do
    if frame.choices and frame.choices.glow then edgeMode = frame end
    if frame.choices and frame.choices[2] then edgeSchool = frame end
    if frame.template == "OptionsSliderTemplate" and frame.maximum == 6 then edgeWidth = frame end
end
assert(edgeMode and edgeSchool and edgeWidth, "Missing per-school edge controls")
edgeSchool.choices[2]()
edgeMode.choices.glow()
edgeWidth:SetValue(3)
addon.SetTextStyle(2, "glow", 3, 0.2, 0.4, 0.8)
assert(addon.GetTextStyle(1).mode == "none", "Changing Holy must not affect Physical")
for _, frame in ipairs(frames) do
    if type(frame.text) == "string" and frame.text:find("Edge color", 1, true) and frame.scripts.OnClick then
        frame.scripts.OnClick(frame)
        break
    end
end
ColorPickerFrame.rgb = { 1, 0, 0 }
ColorPickerFrame.info.swatchFunc()
rgb(addon.GetTextStyle(2).color, 1, 0, 0)
ColorPickerFrame.info.cancelFunc()
rgb(addon.GetTextStyle(2).color, 0.2, 0.4, 0.8)
local effectText = UIParent:CreateFontString(nil, "OVERLAY")
addon.ApplyFont(effectText, 48)
effectText:SetText("12345")
effectText:Show()
addon.UpdateTextEffect(effectText, 2, 48, 0.5)
local function effectLayers()
    local list = {}
    for _, frame in ipairs(frames) do
        if frame.drawLayer == "ARTWORK" and frame.point and frame.point[2] == effectText then list[#list + 1] = frame end
    end
    return list
end
local layers = effectLayers()
assert(#layers == 24 and effectText.fontFlags == "", "Glow must have layered glyphs without a native black outline")
rgb(layers[1].color, 0.2, 0.4, 0.8)
assert(layers[1].alpha > layers[24].alpha and layers[1].alpha < 0.5, "Glow must soften outward and follow fade alpha")
addon.SetTextStyle(2, "none", 3, 0.2, 0.4, 0.8)
addon.UpdateTextEffect(effectText, 2, 48, 1)
for _, layer in ipairs(layers) do assert(not layer.shown, "None must remove all edge layers") end
addon.SetTextStyle(2, "outline", 2, 0.8, 0.1, 0.3)
addon.UpdateTextEffect(effectText, 2, 96, 0.4)
local shown = 0
for _, layer in ipairs(layers) do if layer.shown then
    shown = shown + 1
    assert(layer.fontSize == 96 and layer.alpha == 0.4, "Outline must match animated font size and fade")
end end
assert(shown == 8 and layers[1].point[4] == 2, "Outline must use selected thickness")
addon.HideDamageText(effectText)
for _, layer in ipairs(layers) do assert(not layer.shown, "Pooled text must hide its edge layers") end
addon = loadAddon(DamageColorDB)
assert(addon.GetTextStyle(2).mode == "outline" and addon.GetTextStyle(2).thickness == 2)
rgb(addon.GetTextStyle(2).color, 0.8, 0.1, 0.3)
addon.SetTextStyle(2, "invalid", 1, 0, 0, 0)
assert(addon.GetTextStyle(2).thickness == 2, "Invalid edge styles must be rejected")
addon = loadAddon({ textStyles = { [2] = { mode = "glow", thickness = 0/0, color = { 1, 1, 1 } } } })
assert(addon.GetTextStyle(2).mode == "none" and addon.GetTextStyle(2).thickness == 1.5,
    "Malformed saved edge settings must recover to defaults")
rgb(addon.GetTextStyle(2).color, 1, 1, 1)
addon = loadAddon({ textStyles = {
    [1] = { mode = "outline", thickness = 1, color = { 0, 0, 0 } },
    [2] = { mode = "outline", thickness = 2, color = { 0.8, 0.1, 0.3 } },
} })
assert(addon.GetTextStyle(1).mode == "none", "Previous default must migrate to no edge")
rgb(addon.GetTextStyle(1).color, 1, 1, 1)
assert(addon.GetTextStyle(2).mode == "outline" and addon.GetTextStyle(2).thickness == 2,
    "Customized edges must survive default migration")
addon.SetTextStyle(1, "outline", 1, 0, 0, 0)
addon = loadAddon(DamageColorDB)
assert(addon.GetTextStyle(1).mode == "outline", "Migration must not repeat after a deliberate selection")
addon.ResetTextStyle(1)
assert(addon.GetTextStyle(1).mode == "none" and addon.GetTextStyle(1).thickness == 1.5)

addon = loadAddon({ textStyleDefaultsVersion = 2, textStyles = {
    [1] = { mode = "glow", thickness = 1.5, color = { 1, 1, 1 } },
    [2] = { mode = "glow", thickness = 3, color = { 1, 0.5, 0 } },
} })
assert(addon.GetTextStyle(1).mode == "none", "Previous default white glow must become None")
assert(addon.GetTextStyle(2).mode == "glow", "Custom glow must be preserved")
cvars = { floatingCombatTextCombatDamage_v2 = "1" }
addon = loadAddon(nil)
assert(addon.hideBlizzardDamage and cvars.floatingCombatTextCombatDamage_v2 == "0")
local checkbox
for _, frame in ipairs(frames) do
    if frame.template == "UICheckButtonTemplate" then checkbox = frame end
end
assert(checkbox and checkbox:GetChecked(), "Hide-native checkbox must default on")
checkbox:SetChecked(false)
checkbox.scripts.OnClick(checkbox)
assert(cvars.floatingCombatTextCombatDamage_v2 == "1", "Unchecking must restore native damage")
addon = loadAddon(DamageColorDB)
assert(not addon.hideBlizzardDamage and cvars.floatingCombatTextCombatDamage_v2 == "1", "Unchecked preference must persist")
addon.SetHideBlizzardDamage(true)
assert(cvars.floatingCombatTextCombatDamage_v2 == "0")
addon = loadAddon(DamageColorDB)
addon.SetHideBlizzardDamage(false)
assert(cvars.floatingCombatTextCombatDamage_v2 == "1", "Reload while hidden must retain the original baseline")
addon.SetHideBlizzardDamage(true)
SlashCmdList.DAMAGECOLOR("off")
assert(cvars.floatingCombatTextCombatDamage_v2 == "1", "/dc off must restore native damage")
SlashCmdList.DAMAGECOLOR("on")
assert(cvars.floatingCombatTextCombatDamage_v2 == "0", "/dc on must reapply hiding")
local function lifecycle(event)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.scripts.OnEvent(frame, event) end
    end
end
denyCVarWrites = true
addon.SetHideBlizzardDamage(false)
assert(DamageColorDB.nativeDamageRestore, "Failed restoration must keep its baseline for retry")
denyCVarWrites = false
lifecycle("PLAYER_REGEN_ENABLED")
assert(cvars.floatingCombatTextCombatDamage_v2 == "1" and not DamageColorDB.nativeDamageRestore)
addon.SetHideBlizzardDamage(true)
lifecycle("PLAYER_LOGOUT")
assert(cvars.floatingCombatTextCombatDamage_v2 == "1", "Logout must restore the baseline")
assert(DamageColorDB.hideBlizzardDamage, "Restoring on logout must preserve the checkbox preference")
cvars = { floatingCombatTextCombatDamage = "1" }
addon = loadAddon(nil)
assert(cvars.floatingCombatTextCombatDamage == "0", "Legacy CVar fallback must work")
addon.SetHideBlizzardDamage(false)
assert(cvars.floatingCombatTextCombatDamage == "1")
cvars = { floatingCombatTextCombatDamage_v2 = "0" }
addon = loadAddon(nil)
addon.SetHideBlizzardDamage(false)
assert(cvars.floatingCombatTextCombatDamage_v2 == "0", "An originally hidden native display must stay hidden")
local output, originalPrint = {}, print
print = function(message) output[#output + 1] = message end
GetBuildInfo = function() return "1.60.1", "70374", "Oct 12 2026", 16001 end
SlashCmdList.DAMAGECOLOR("watch")
for _, frame in ipairs(frames) do
    if frame.events.UNIT_COMBAT == "target" then
        frame.scripts.OnEvent(frame, "UNIT_COMBAT", "target", "WOUND", "", 4321, 1)
    end
    if frame.events.NAME_PLATE_UNIT_REMOVED then
        frame.scripts.OnEvent(frame, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
    end
end
SlashCmdList.DAMAGECOLOR("report")
print = originalPrint
local report = table.concat(output, "\n")
assert(report:find("LIVE_EVENT", 1, true) and report:find("RAW_TARGET", 1, true)
    and report:find("PLATE_REMOVED", 1, true), "Report must expose both feeds and removal order")
assert(not report:find("4321", 1, true), "Trace must not record damage amounts")
-- A blocked-action popup cannot be prevented by pcall. Watch must never
-- attempt combat-log registration or read its restricted payload.
local register = methods.RegisterEvent
local forbiddenCalls = 0
methods.RegisterEvent = function(self, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" or event == "COMBAT_LOG_EVENT" then
        forbiddenCalls = forbiddenCalls + 1
        error("Blizzard-only action")
    end
    return register(self, event)
end
CombatLogGetCurrentEventInfo = function()
    forbiddenCalls = forbiddenCalls + 1
    error("Blizzard-only reader")
end
SlashCmdList.DAMAGECOLOR("watch")
SlashCmdList.DAMAGECOLOR("stop")
assert(forbiddenCalls == 0, "Watch must not invoke Blizzard-only combat-log APIs")
methods.RegisterEvent = register
-- Profile snapshots must be independent from working settings and survive reloads.
addon = loadAddon({})
assert(addon.activeProfile == "Default" and not addon.ProfileIsDirty())
assert(DamageColorDB.profiles.Default.textStyles[20].mode == "outline")
assert(DamageColorDB.profiles["Power Glow"].textStyles[1].mode == "glow")
assert(DamageColorDB.profiles["Power Glow"].textStyles[4].thickness == 6)
addon.SetColor(1, 0.2, 0.3, 0.4)
addon.SetAppearance("skurri", 60)
addon.SetHideBlizzardDamage(false)
assert(addon.ProfileIsDirty())
assert(not addon.SaveProfile("Default"), "Factory defaults must remain fixed")
assert(not addon.SaveProfile(" ") and not addon.SaveProfile("bad|name"))
assert(addon.SaveProfile(" My style ") and addon.activeProfile == "My style")
assert(not addon.ProfileIsDirty())
addon.SetColor(1, 0.5, 0.6, 0.7)
assert(DamageColorDB.profiles["My style"].colors[1][1] == 0.2, "Editing must not mutate saved profiles")
local savedProfiles = DamageColorDB
addon = loadAddon(savedProfiles)
assert(addon.activeProfile == "My style" and addon.ProfileIsDirty(), "Unsaved working edits survive reloads")
local profileMenu
for _, frame in ipairs(frames) do
    if frame.text == "Profile: My style" then profileMenu = frame end
end
assert(profileMenu)
profileMenu:SetupMenu(profileMenu.menuGenerator)
profileMenu.choices.Default()
assert(addon.activeProfile == "My style" and addon.colors[1][1] == 0.5,
    "Selecting a preview must not load the profile or discard edits")
click("Load profile")
assert(lastPopup and lastPopup.data == "Default", "Loading must display the discard warning")
assert(addon.activeProfile == "My style" and addon.colors[1][1] == 0.5,
    "Opening or cancelling the warning must preserve edits")
StaticPopupDialogs.DAMAGECOLOR_LOAD_PROFILE.OnAccept(nil, lastPopup.data)
assert(addon.activeProfile == "Default" and not addon.ProfileIsDirty())
assert(addon.appearance.size == 48 and addon.hideBlizzardDamage == true)
assert(addon.LoadProfile("My style") and addon.appearance.font == "skurri" and addon.appearance.size == 60)
assert(addon.colors[1][1] == 0.2 and addon.hideBlizzardDamage == false)
assert(addon.LoadProfile("Power Glow") and addon.GetTextStyle(1).thickness == 5)
assert(addon.colors[1][1] == 0.3137255012989044 and not addon.ProfileIsDirty())
addon.SetTextStyle(1, "outline", 2, 1, 1, 1)
assert(addon.SaveProfile("Power Glow"))
addon = loadAddon(DamageColorDB)
assert(addon.GetTextStyle(1).mode == "outline" and not addon.ProfileIsDirty(), "Saved preset edits must persist")
addon = loadAddon({ profiles = { Broken = { colors = false, appearance = { size = 0 / 0 } } } })
assert(addon.LoadProfile("Broken") and addon.appearance.size == 48, "Invalid saved values must fall back safely")
-- Miss/resist events need neither a damage amount nor a trustworthy school.
local outcomePlate = C_NamePlate.GetNamePlateForUnit("target")
outcomePlate.shown, outcomePlate.forbidden, outcomePlate.x, outcomePlate.y = true, false, 400, 300
local outcomeListener
for _, frame in ipairs(frames) do
    if frame.events.UNIT_COMBAT == "target" then outcomeListener = frame end
end
local inaccessible = {}
issecretvalue = function(v) return v == inaccessible end
addon.SetColor(-1, 0.6, 0.7, 0.8)
addon.SetTextStyle(-1, "glow", 2, 1, 1, 1)
local function outcomeWord(word)
    local count, found = 0
    for _, frame in ipairs(frames) do
        if frame.drawLayer == "OVERLAY" and frame.text == word and frame.shown
            and frame.parent.scripts.OnUpdate then
            count, found = count + 1, frame
        end
    end
    return count, found
end
outcomeListener.scripts.OnEvent(outcomeListener, "UNIT_COMBAT", "target", "MISS", "CRITICAL", inaccessible, inaccessible)
local count, miss = outcomeWord("Miss")
assert(count == 1 and math.abs(miss.fontSize - 48 * 0.85) < 0.001,
    "Miss must render at normal size even without readable amount or school")
rgb(miss.color, 0.6, 0.7, 0.8)
outcomeListener.scripts.OnEvent(outcomeListener, "UNIT_COMBAT", "target", "RESIST", "", 0, 2)
assert(outcomeWord("Resisted") == 1, "Explicit resists must render automatically")
assert(outcomeWord("Miss / Resist") == 0, "Ambiguous events must use only Miss")
assert(addon.SaveProfile("Outcomes"))
addon.LoadProfile("Default")
rgb(addon.colors[-1], 1, 1, 1)
assert(addon.LoadProfile("Outcomes") and addon.GetTextStyle(-1).mode == "glow")
rgb(addon.colors[-1], 0.6, 0.7, 0.8)
miss.parent.scripts.OnUpdate(miss.parent, 1.8)
assert(outcomeWord("Miss") == 0 and outcomeWord("Resisted") == 0, "Outcome messages must expire")
issecretvalue = nil
addon = loadAddon({})
assert(DamageColorDB.profiles["Power Glow (Lightning)"], "Lightning preset must be seeded on fresh installs")
local names = addon.GetProfileNames()
assert(#names == 5 and names[1] == "Default", "All five built-in profiles must be available")
assert(addon.LoadProfile("White Outline"))
assert(addon.GetTextStyle(1).mode == "outline" and addon.GetTextStyle(1).thickness == 1.25)
rgb(addon.GetTextStyle(1).color, 1, 1, 1)
assert(addon.LoadProfile("Default (Lightning)"))
rgb(addon.colors[8], 0.21176470816135409, 0.17647059261798859, 1)
assert(addon.LoadProfile("Power Glow"))
assert(addon.GetTextStyle(-1).mode == "glow" and addon.GetTextStyle(-1).thickness == 2.25,
    "Updated Power Glow must include the saved outcome styling")
assert(addon.LoadProfile("Power Glow (Lightning)") and not addon.ProfileIsDirty())
assert(addon.GetTextStyle(8).mode == "glow" and addon.GetTextStyle(8).thickness == 6)
rgb(addon.GetTextStyle(8).color, 0.16078431904315951, 0.28235295414924622, 1)
addon.SetColor(8, 0.1, 0.2, 0.3)
assert(addon.SaveProfile("Power Glow (Lightning)"))
addon = loadAddon(DamageColorDB)
rgb(DamageColorDB.profiles["Power Glow (Lightning)"].colors[8], 0.1, 0.2, 0.3)
assert(not addon.ProfileIsDirty(), "Lightning preset edits must survive reloads without being overwritten")
-- Settings submenu navigation and previews must not mutate the active style.
addon = loadAddon({})
assert(submenus.Font and submenus.Style and submenus.Profiles and not submenus.General)
for _, frame in ipairs(frames) do
    assert(not (frame.scripts.OnClick and (frame.text == "General" or frame.text == "Style" or frame.text == "Profiles")),
        "Navigation must use Settings submenus rather than buttons")
end
local generalPage, stylePage, profilesPage, profileSelector
for _, frame in ipairs(frames) do
    if frame.choices and frame.choices.arial then generalPage = frame.parent end
    if frame.choices and frame.choices.glow then stylePage = frame.parent end
    if frame.text == "Profile: Default" then profileSelector, profilesPage = frame, frame.parent end
end
local hideOption
for _, frame in ipairs(frames) do
    if frame.template == "UICheckButtonTemplate" then hideOption = frame end
end
assert(hideOption and hideOption.parent ~= generalPage, "Native-damage checkbox belongs on the root screen")
submenus.Style:Show()
editTextColor(2)
local cancelledAfterTab = ColorPickerFrame.info.cancelFunc
submenus.Style:Hide()
submenus.Font:Show()
addon.SetColor(2, 0.2, 0.3, 0.4)
cancelledAfterTab()
rgb(addon.colors[2], 0.2, 0.3, 0.4)
addon.SetAppearance("arial", 96)
addon.SetTextStyle(2, "glow", 3, 0.1, 0.2, 0.3)
assert(addon.SaveProfile("Preview test"))
addon.SetColor(2, 0.3, 0.4, 0.5)
addon.SetTextStyle(2, "none", 3, 1, 1, 1)
submenus.Font:Hide()
submenus.Profiles:Show()
profileSelector:SetupMenu(profileSelector.menuGenerator)
profileSelector.choices.Default()
assert(addon.activeProfile == "Preview test" and addon.appearance.size == 96 and addon.ProfileIsDirty())
rgb(addon.colors[2], 0.3, 0.4, 0.5)
local previewCount = 0
for _, frame in ipairs(frames) do
    if frame.drawLayer == "OVERLAY" and frame.parent and frame.parent.parent
        and frame.parent.parent.parent == profilesPage then
        previewCount = previewCount + 1
        assert(frame.fontSize == 48 and frame.fontPath == STANDARD_TEXT_FONT,
            "Selected saved profile must supply its own font/size")
    end
end
assert(previewCount == 10, "Profile preview must compare all ten number types side by side")
profileSelector.choices["Preview test"]()
local savedGlowLayers = 0
for _, frame in ipairs(frames) do
    if frame.drawLayer == "OVERLAY" and frame.parent and frame.parent.parent
        and frame.parent.parent.parent == profilesPage then
        assert(frame.fontSize == 96 and frame.fontPath == addon.fonts[3].path)
    end
    if frame.drawLayer == "ARTWORK" and frame.shown and frame.color and frame.color[1] == 0.1
        and frame.parent and frame.parent.parent and frame.parent.parent.parent == profilesPage then
        savedGlowLayers = savedGlowLayers + 1
        assert(frame.fontSize == 96 and frame.fontPath == addon.fonts[3].path)
    end
end
assert(savedGlowLayers == 24, "Saved-profile preview must render its glow independently of the current style")
assert(addon.GetTextStyle(2).mode == "none", "Previewing saved glow must leave working edges unchanged")
print("PASS: per-school outlines/glow/none, color cancel, thickness, layer cleanup, persistence, animation, AoE, death linger, and native visibility")

-- Incoming hits share styles, but keep independent size and placement in profiles.
addon = loadAddon({ appearance = { font = "default", size = 61 }, profiles = {
    Legacy = { appearance = { font = "default", size = 73 } },
} })
assert(addon.damageTaken.size == 30.5 and addon.hideBlizzardDamageTaken)
assert(addon.GetProfile("Legacy").damageTaken.size == 36.5)
for _, name in ipairs(addon.GetProfileNames()) do
    local p = addon.GetProfile(name)
    assert(p.damageTaken.size == p.appearance.size / 2)
    assert(p.damageTaken.x == 0 and p.damageTaken.y == -250)
end
assert(submenus["Damage Taken"])
addon.SetDamageTaken(19, 125, -75)
addon.SetHideBlizzardDamageTaken(false)
assert(addon.SaveProfile("Incoming"))
addon.LoadProfile("Default")
assert(addon.damageTaken.size == 24 and addon.hideBlizzardDamageTaken)
addon.LoadProfile("Incoming")
assert(addon.damageTaken.size == 19 and addon.damageTaken.x == 125 and addon.damageTaken.y == -75)
assert(not addon.hideBlizzardDamageTaken and not addon.ProfileIsDirty())
addon = loadAddon(DamageColorDB)
assert(addon.damageTaken.size == 19 and addon.damageTaken.x == 125)
local incomingListener
for _, frame in ipairs(frames) do
    if frame.events.UNIT_COMBAT == "player" then incomingListener = frame end
end
assert(incomingListener)
incomingListener.scripts.OnEvent(incomingListener, "UNIT_COMBAT", "player", "WOUND", "CRITICAL", 98765, 4)
local incomingText
for _, frame in ipairs(frames) do
    if frame.drawLayer == "OVERLAY" and frame.text == "98765" then incomingText = frame end
end
assert(incomingText and incomingText.shown and incomingText.point[3] == "CENTER")
assert(math.abs(incomingText.fontSize - 19 * 2 * 0.85) < 0.001)
rgb(incomingText.color, unpack(addon.colors[4]))
addon.SetAppearance("arial", 80)
assert(addon.damageTaken.size == 19 and incomingText.fontSize == 19 * 2 * 0.85)
local oldX = incomingText.point[4]
addon.SetDamageTaken(19, 225, -75)
assert(incomingText.point[4] == oldX + 100)
incomingText.parent.scripts.OnUpdate(incomingText.parent, 1.8)
assert(not incomingText.shown)
local restricted = {}
issecretvalue = function(v) return v == restricted end
incomingListener.scripts.OnEvent(incomingListener, "UNIT_COMBAT", "player", "WOUND", "", restricted, 4)
issecretvalue = nil
-- Native handlers must stay installed and execute exclusively through the
-- simulated engine, never through an addon wrapper. Post-hooks run afterward.
CombatText = CreateFrame("Frame")
CombatText.activeFontStrings = {}
local nativeCalls, engineDispatch = 0, false
local function addNativeMessage(self)
    local text = self:CreateFontString(nil, "OVERLAY")
    addon.ApplyFont(text, 24)
    text:SetText("native")
    text:Show()
    self.activeFontStrings[#self.activeFontStrings + 1] = text
end
CombatText.AddMessage = addNativeMessage
local secureHooks = {}
hooksecurefunc = function(object, name, callback)
    assert(object == CombatText and name == "AddMessage")
    secureHooks[#secureHooks + 1] = callback
end
local postScripts = {}
function CombatText:HookScript(name, callback)
    postScripts[name] = postScripts[name] or {}
    table.insert(postScripts[name], callback)
end
local nativeHandler = function(self, event, kind, skip)
    assert(engineDispatch, "Blizzard OnEvent must never be invoked from addon code")
    nativeCalls = nativeCalls + 1
    if event == "COMBAT_TEXT_UPDATE" and not skip then
        self:AddMessage()
        for _, hook in ipairs(secureHooks) do hook(self) end
    end
end
CombatText:SetScript("OnEvent", nativeHandler)
CombatText.SetScript = function() error("Addon must never replace Blizzard scripts") end
local function nativeEvent(event, kind, skip)
    engineDispatch = true
    CombatText:GetScript("OnEvent")(CombatText, event, kind, skip)
    engineDispatch = false
    for _, hook in ipairs(postScripts.OnEvent or {}) do hook(CombatText, event, kind, skip) end
    return CombatText.activeFontStrings[#CombatText.activeFontStrings]
end
addon.hideBlizzardDamageTaken = true
lifecycle("ADDON_LOADED")
assert(addon.nativeDamageTakenStatus == "hidden", "Late Blizzard loading must install suppression")
assert(CombatText:GetScript("OnEvent") == nativeHandler)
assert(not nativeEvent("COMBAT_TEXT_UPDATE", "DAMAGE").shown)
assert(not nativeEvent("COMBAT_TEXT_UPDATE", "SPELL_DAMAGE_CRIT").shown)
local heal = nativeEvent("COMBAT_TEXT_UPDATE", "HEAL")
assert(heal.shown, "Native incoming healing must remain visible")
nativeEvent("COMBAT_TEXT_UPDATE", "DAMAGE", true)
assert(heal.shown, "Skipped damage must not hide an earlier healing message")
nativeEvent("UNIT_POWER_UPDATE", "player")
nativeEvent("UNIT_HEALTH", "player")
assert(CombatText:GetScript("OnEvent") == nativeHandler, "Health/power handlers must remain untouched")
addon.SetHideBlizzardDamageTaken(false)
assert(nativeEvent("COMBAT_TEXT_UPDATE", "DAMAGE").shown)
addon.SetHideBlizzardDamageTaken(true)
SlashCmdList.DAMAGECOLOR("off")
assert(nativeEvent("COMBAT_TEXT_UPDATE", "DAMAGE").shown)
SlashCmdList.DAMAGECOLOR("on")
assert(not nativeEvent("COMBAT_TEXT_UPDATE", "DAMAGE").shown)
lifecycle("PLAYER_LOGOUT")
assert(nativeEvent("COMBAT_TEXT_UPDATE", "DAMAGE").shown)
assert(#secureHooks == 1 and #postScripts.OnEvent == 1, "Toggles must not stack hooks")
CombatText = nil
hooksecurefunc = nil
print("PASS: incoming migration, profiles, placement, and native suppression without replacing Blizzard handlers")

addon = loadAddon({ damageTaken = { size = 24, x = 1200, y = -1000 } })
assert(addon.damageTaken.x == 1200 and addon.damageTaken.y == -1000,
    "Opening settings must preserve existing placement outside the new slider range")
local sliderCount, placementCount = 0, 0
for _, slider in ipairs(frames) do
    if slider.kind == "Slider" then
        sliderCount = sliderCount + 1
        local left, right
        for _, button in ipairs(frames) do
            if button.kind == "Button" and button.point and button.point[2] == slider then
                if button.text == "<" then left = button end
                if button.text == ">" then right = button end
            end
        end
        assert(left and right, "Every slider needs both arrows")
        if slider.minimum < 0 then
            placementCount = placementCount + 1
            assert(slider.minimum == -500 and slider.maximum == 500)
        end
        slider:SetValue(slider.minimum)
        left.scripts.OnClick(left)
        assert(slider:GetValue() == slider.minimum, "Left arrow must stop at the minimum")
        right.scripts.OnClick(right)
        assert(slider:GetValue() == slider.minimum + 1, "Right arrow must add exactly one unit")
        left.scripts.OnClick(left)
        assert(slider:GetValue() == slider.minimum, "Left arrow must subtract exactly one unit")
        slider:SetValue(slider.maximum)
        right.scripts.OnClick(right)
        assert(slider:GetValue() == slider.maximum, "Right arrow must stop at the maximum")
    end
end
assert(sliderCount == 5 and placementCount == 2)
print("PASS: all slider arrows, one-unit increments, bounds, and preserved saved placement")

-- High nameplates and dense critical bursts must remain below the screen top,
-- including peak animation size, glow, drift, and a resized UIParent.
C_NamePlate.GetNamePlateForUnit = function() return plate end
plate.x, plate.y, plate.scale, plate.shown = 400, 1500, 0.6, true
addon = loadAddon(nil)
addon.SetTextStyle(1, "glow", 6, 1, 1, 1)
local highListener
for _, frame in ipairs(frames) do
    if frame.events.UNIT_COMBAT == "target" then highListener = frame end
end
for i = 1, 12 do
    highListener.scripts.OnEvent(highListener, "UNIT_COMBAT", "target", "WOUND", "CRITICAL", 99000 + i, 1)
end
local highLive
local function assertBelowTop()
    local count = 0
    for _, frame in ipairs(frames) do
        if frame.drawLayer == "OVERLAY" and frame.shown and tonumber(frame.text)
            and tonumber(frame.text) > 99000 then
            count = count + 1
            highLive = frame.parent
            assert(frame.point[5] + frame.fontSize / 2 + 6 * 1.95 <= UIParent:GetHeight() - 8 + 0.001,
                "Outgoing critical text and glow must stay below the screen ceiling")
        end
    end
    assert(count == 12, "Clamping must preserve every hit")
end
assertBelowTop()
highLive.scripts.OnUpdate(highLive, 0.08)
assertBelowTop()
UIParent.height = 720
highLive.scripts.OnUpdate(highLive, 1.3)
assertBelowTop()
UIParent.height = nil
print("PASS: outgoing screen ceiling, critical pops, glow, bursts, drift, and resizing")
