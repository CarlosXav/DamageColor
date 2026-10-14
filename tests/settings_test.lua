-- Run from the repository root with Lua 5.1: lua tests/settings_test.lua
local frames, opened = {}, nil
local methods = {}
for _, name in ipairs({ "SetSize", "SetPoint", "SetAllPoints", "ClearAllPoints",
    "SetWidth", "SetJustifyH", "SetFrameStrata", "SetScrollChild",
    "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag" }) do
    methods[name] = function() end
end
function methods:SetFont(path, size) self.fontPath, self.fontSize = path, size; return true end
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
function methods:SetText(value) self.text = value end
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
    local frame = setmetatable({ scripts = {}, events = {}, template = template, parent = parent }, { __index = methods })
    frames[#frames + 1] = frame
    return frame
end
function methods:CreateFontString() return CreateFrame("FontString", nil, self) end
function methods:CreateTexture() return CreateFrame("Texture") end
UIParent = CreateFrame("Frame")
UIParent.scale = 0.8
local plate = CreateFrame("Frame")
plate.x, plate.y, plate.scale, plate.shown = 400, 300, 0.6, true
C_NamePlate = { GetNamePlateForUnit = function(unit) assert(unit == "target"); return plate end }
STANDARD_TEXT_FONT = "test-font"
SlashCmdList = {}
C_Timer = { After = function() end }
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
    for _, file in ipairs({ "Palette.lua", "NativeDamage.lua", "DamageColor.lua", "Settings.lua" }) do
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
rgb({ addon.GetColor(20) }, 0.4, 0.5, 0.6) -- Frostfire fallback.
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
    if frame.text == "456" then liveNumber = frame end
end
assert(liveNumber and liveNumber.shown, "Holy damage must create a live number")
rgb(liveNumber.color, 0.2, 0.3, 0.4)
addon.SetColor(2, 0.5, 0.6, 0.7)
rgb(liveNumber.color, 0.5, 0.6, 0.7)
damageFrame.scripts.OnEvent(damageFrame, "UNIT_COMBAT", "target", "WOUND", "", 789, 1)
local physical
for _, frame in ipairs(frames) do if frame.text == "789" then physical = frame end end
assert(physical and physical.shown, "Physical hits must appear on the overlay")
rgb(physical.color, 1, 0.20, 0.20)
local originalX, originalY = physical.point[4], physical.point[5]
assert(math.abs(originalX - 300) < 0.001 and math.abs(originalY - 286.5) < 0.001,
    "Impact position must account for nameplate and UI scales")
local live = physical.parent
plate.x, plate.y = 800, 600 -- Old hits must not jump to a new target/nameplate position.
live.scripts.OnUpdate(live, 0.08)
assert(math.abs(physical.fontSize - 72) < 0.001, "Normal hit must pop to 150% of its doubled base size")
assert(physical.point[4] == originalX and math.abs(physical.point[5] - originalY - 0.96) < 0.001)
live.scripts.OnUpdate(live, 0.16)
assert(math.abs(physical.fontSize - 48) < 0.001, "Normal hit must settle to doubled size")
live.scripts.OnUpdate(live, 0.61)
assert(physical.alpha > 0 and physical.alpha < 1, "Hit must fade")
live.scripts.OnUpdate(live, 0.15)
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
for _, frame in ipairs(frames) do if frame.text == "904" then anchored = frame end end
assert(anchored and anchored.shown, "Secret geometry must not discard a readable damage event")
assert(anchored.point[2] == plate, "Secret geometry must use a direct frame anchor")
damageFrame.scripts.OnEvent(damageFrame, "PLAYER_TARGET_CHANGED")
assert(not anchored.shown, "Anchored numbers must clear before the plate can be reused")
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
local function hit(unit, amount, flags)
    local frame = listener(unit)
    frame.scripts.OnEvent(frame, "UNIT_COMBAT", unit, "WOUND", flags or "", amount, 4)
end
local function number(amount)
    for _, frame in ipairs(frames) do if frame.text == tostring(amount) then return frame end end
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
assert(not number(1006).shown, "Removing the owning plate must clear anchored hits")
for _, frame in ipairs(frames) do assert(frame.events.UNIT_COMBAT ~= "nameplate2", "Removed plate must unsubscribe") end
hit("nameplate3", 2000) -- Friendly damage remains filtered.
plate.x, plate.y = 400, 300
damageFrame.scripts.OnEvent(damageFrame, "NAME_PLATE_UNIT_ADDED", "nameplate1")
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

-- Settings controls apply font and size immediately and preserve crit scaling.
local dropdown, slider
for _, frame in ipairs(frames) do
    if frame.template == "WowStyle1DropdownTemplate" then dropdown = frame end
    if frame.template == "OptionsSliderTemplate" then slider = frame end
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
print("PASS: appearance, crits, colors, AoE, native checkbox/default/persistence, restoration, logout, retry, and legacy CVar")
