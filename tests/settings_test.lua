-- Run from the repository root with Lua 5.1: lua tests/settings_test.lua
local frames, opened = {}, nil
local methods = {}
for _, name in ipairs({ "SetSize", "SetPoint", "SetAllPoints", "ClearAllPoints",
    "SetFont", "SetWidth", "SetJustifyH", "SetAlpha" }) do
    methods[name] = function() end
end
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
    local frame = setmetatable({ scripts = {}, events = {}, template = template }, { __index = methods })
    frames[#frames + 1] = frame
    return frame
end
function methods:CreateFontString() return CreateFrame("FontString") end
function methods:CreateTexture() return CreateFrame("Texture") end
UIParent = CreateFrame("Frame")
STANDARD_TEXT_FONT = "test-font"
SlashCmdList = {}
C_Timer = { After = function() end }
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
    for _, file in ipairs({ "Palette.lua", "DamageColor.lua", "Settings.lua" }) do
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
rgb({ addon.GetColor(1, true) }, 1, 1, 1) -- Auto-attacks stay white.
click("Holy")
local staleCancel = ColorPickerFrame.info.cancelFunc
click("Reset colors")
staleCancel()
rgb(addon.colors[2], 1, 0.95, 0.60)
rgb(DamageColorDB.colors[0], 1, 1, 0)

-- The live path uses chosen colors and still excludes physical damage.
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
for _, frame in ipairs(frames) do assert(frame.text ~= "789", "Physical damage must remain native") end

addon = loadAddon({ colors = { [2] = { 0/0, 1, 1 }, [4] = { 1, -1, 0 }, [8] = "bad" } })
rgb(addon.colors[2], 1, 0.95, 0.60)
rgb(addon.colors[4], 1, 0.50, 0.10)
rgb(addon.colors[8], 0.25, 1, 0.30)
addon.SetColor(2, math.huge, 0, 0)
rgb(addon.colors[2], 1, 0.95, 0.60)
print("PASS: settings, cancel, persistence, fallback, reset, invalid colors, live color updates, and native physical damage")
