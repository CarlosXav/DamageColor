local _, addon = ...

-- WoW's native outline flags are black with fixed weights. Offset glyph copies
-- give us independent color/width; translucent concentric rings approximate glow.
local effects = {}
local glowOpacity = { 0.20, 0.10, 0.04 }
local directions = {
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
    { 0.7071, 0.7071 }, { -0.7071, 0.7071 },
    { 0.7071, -0.7071 }, { -0.7071, -0.7071 },
}
function addon.HideDamageText(text)
    text:Hide()
    local effect = effects[text]
    if effect then for _, layer in ipairs(effect.layers) do layer:Hide() end end
end
function addon.UpdateTextEffect(text, school, size, alpha)
    local style = addon.GetTextStyle(school)
    local count = style.mode == "none" and 0 or (style.mode == "glow" and 24 or 8)
    local effect = effects[text]
    if not effect then
        if count == 0 then return end
        effect = { layers = {} }
        effects[text] = effect
    end
    local r, g, b = unpack(style.color)
    local value = text:GetText() or ""
    local signature = table.concat({ addon.GetFont().path, size, style.mode, style.thickness, r, g, b, value }, "|")
    local changed = effect.signature ~= signature
    effect.signature = signature
    for i = 1, math.max(count, #effect.layers) do
        local layer = effect.layers[i]
        if i <= count then
            if not layer then
                layer = text:GetParent():CreateFontString(nil, "ARTWORK")
                effect.layers[i] = layer
                changed = true
            end
            local ring = math.floor((i - 1) / 8) + 1
            if changed then
                local direction = directions[(i - 1) % 8 + 1]
                local radius = style.thickness * (style.mode == "glow" and ring * 0.65 or 1)
                addon.ApplyFont(layer, size)
                layer:SetText(value)
                layer:SetTextColor(r, g, b)
                layer:ClearAllPoints()
                layer:SetPoint("CENTER", text, "CENTER", direction[1] * radius, direction[2] * radius)
            end
            local opacity = style.mode == "glow" and glowOpacity[ring] or 1
            layer:SetAlpha(alpha * opacity)
            layer:Show()
        elseif layer then
            layer:Hide()
        end
    end
end
