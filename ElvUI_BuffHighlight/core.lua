local E, L, V, P, G = unpack(ElvUI); 
local BH = E:NewModule('BuffHighlight', 'AceHook-3.0'); 
local EP = LibStub("LibElvUIPlugin-1.0") 
local UF = E:GetModule('UnitFrames')
local addon = ... 


--GLOBALS: hooksecurefunc
local select, pairs, unpack = select, pairs, unpack

local function isTracked(spellID)
	for id, spell in pairs(E.db.BH.spells) do
		if spellID == tonumber(id) then
			return spell.enabled
		end
	end
	return false
end

local function CheckBuff(unit)
	if not unit or not UnitCanAssist("player", unit) then return nil end
	local i = 1
	while true do
		local _, texture,_,_,_, expire, source,_,_, spellID = UnitAura(unit, i, "HELPFUL")
		if not texture then break end

		if(source == "player" and isTracked(spellID)) then
			return expire - GetTime(), spellID
		end
		i = i + 1
	end
end

local function AuraHighlighted(frame)
	if (not frame.AuraHighlight) then return false end
	
	local r, g, b, _ = frame.AuraHighlight:GetVertexColor()
	return r ~= 0 or g ~= 0 or b ~= 0
end

local function resetHealthBarColor(frame)
	local colors = E.db.unitframe.colors
	local r, g, b = colors.health.r, colors.health.g, colors.health.b
	frame:SetStatusBarColor(r, g, b, 1.0)

	if E.db.BH.colorBackdrop then
		local m = frame.bg.multiplier
		frame.bg:SetVertexColor(r * m, g * m, b * m)
	end
end

local function updateHealth(frame, spellID)
	if not E.db.BH.spells[spellID] then return end

	if E.db.BH.overwriteDBH and DebuffHighlighted(frame:GetParent()) then
		frame:GetParent().DebuffHighlight:SetVertexColor(0, 0, 0, 0)
		resetHealthBarColor(frame)
		return
	end

	if frame.BuffHighlightActive then
		local t = E.db.BH.spells[spellID].glowColor
		local r, g, b, a = t.r, t.g, t.b, t.a
		
		if E.db.BH.colorBackdrop then
			local m = frame.bg.multiplier
			frame.bg:SetVertexColor(r * m, g * m, b * m)
		end
		frame:SetStatusBarColor(r, g, b, a)
	elseif frame.BuffHighlightFaderActive then
		local t = E.db.BH.spells[spellID].fadeColor
		local r, g, b, a = t.r, t.g, t.b, t.a

		if E.db.BH.colorBackdrop then 
			local m = frame.bg.multiplier
			frame.bg:SetVertexColor(r * m, g * m, b * m)
		end
		frame:SetStatusBarColor(r, g, b, a)
	end
end

local function updateFrame(frame, unit)
	if not frame then return end
	
	if not E.db.BH.overwriteDBH and DebuffHighlighted(frame:GetParent()) then 
		frame.BuffHighlightActive = false
		frame.BuffHighlightFaderActive = false
		
		resetHealthBarColor(frame)
		return 
	end

	local buffDuration, spellID = CheckBuff(unit)
	if not buffDuration or buffDuration < 0 then 
		frame.BuffHighlightActive = false
		frame.BuffHighlightFaderActive = false

		resetHealthBarColor(frame)
		return
	end


	if not E.db.BH.spells[spellID] then return end
	if (buffDuration > E.db.BH.spells[spellID].fadeThreshold) or not E.db.BH.spells[spellID].fadeEnabled then
		frame.BuffHighlightActive = true
		frame.BuffHighlightFaderActive = false
	else
		frame.BuffHighlightActive = false
		frame.BuffHighlightFaderActive = true
	end

	updateHealth(frame, spellID)
end

local function usingClassColor()
	local val = E.db.unitframe.colors.healthclass
	if val ~= nil then
		return val
	end
end

function BH:Initialize()
	if not E.private.unitframe.enable or usingClassColor() then return end

	for name, header in pairs(UF.headers) do
		if name ~= "tank" and name ~= "assist" then
			for i = 1, header:GetNumChildren() do
				local group = select(i, header:GetChildren())
				for j = 1, group:GetNumChildren() do
					local frame = select(j, group:GetChildren())
					if frame and frame.Health and frame.unit then
						hooksecurefunc(frame.Health, "PostUpdateColor", function(self, unit, ...)
							updateFrame(self, unit) end)
					end
				end
			end
		end
	end

	if E.db.BH.enable and usingClassColor() then
		print("|cff1784d1ElvUI|r |cff00b3ffBuffHighlight|r: You are currently using class heath colors. Please disable this option in order to BuffHilight to work. (UnitFrames > General Options > Colors > Class Health)")
	end
	EP:RegisterPlugin(addon, BH.GetOptions) 
end

local function Update()
	if not E.db.BH.enable or usingClassColor() then return end
	for name, header in pairs(UF.headers) do
		if name ~= "tank" and name ~= "assist" then
			for i = 1, header:GetNumChildren() do
				local group = select(i, header:GetChildren())
				for j = 1, group:GetNumChildren() do
					local frame = select(j, group:GetChildren())
					if frame and frame.Health and frame.unit then
						updateFrame(frame.Health, frame.unit)
					end
				end
			end
		end
	end
end

local timeSinceLastUpdate, updateInterval = 0, 0.1;

local function BH_OnUpdate(self, elapsed)
	timeSinceLastUpdate = timeSinceLastUpdate + elapsed; 	
  
	while (timeSinceLastUpdate > updateInterval) do
		Update()
		timeSinceLastUpdate = timeSinceLastUpdate - updateInterval;
	end
end

local f = CreateFrame("Frame")
f:SetScript("OnUpdate", BH_OnUpdate)

E:RegisterModule(BH:GetName())
