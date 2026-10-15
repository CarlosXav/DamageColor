-- Run from the repository root with Lua 5.1: lua tests/settings_test.lua
local frames, opened = {}, nil
local methods = {}
for _, name in ipairs({ "SetSize", "SetPoint", "SetAllPoints", "ClearAllPoints",
    "SetWidth", "SetJustifyH", "SetFrameStrata", "SetScrollChild",
    "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag" }) do
    methods[name] = function() end
end
function methods:SetFont(path, size, flags) self.fontPath, self.fontSize, self.fontFlags = path, size, flags; return true end
function methods:GetText() return self.text end
function methods:GetParent() return self.parent end
function methods:GetStringWidth() return #(self.text or "") * (self.fontSize or 12) * 0.6 end
function methods:GetStringHeight() return self.fontSize or 12 end
function methods:SetScale(scale) self.scale = scale end
function methods:SetMinMaxValues(low, high) self.minimum, self.maximum = low, high end
function methods:OverrideText(text) self.text = text end
function methods:SetupMenu(generator)
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
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        assert(name == "DamageColor")
        return { GetID = function() return 17 end }
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
local function loadAddon(saved)
    DamageColorDB = saved
    frames = {}
    local addon = {}
    for _, file in ipairs({ "Palette.lua", "TextEffects.lua", "NativeDamage.lua", "DamageColor.lua", "Settings.lua" }) do
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
click("Holy")
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
click("Holy")
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
    if frame.template == "OptionsSliderTemplate" and frame.maximum == 96 then slider = frame end
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
print("PASS: per-school outlines/glow/none, color cancel, thickness, layer cleanup, persistence, animation, AoE, death linger, and native visibility")
