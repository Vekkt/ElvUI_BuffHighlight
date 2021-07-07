--Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local E, L, V, P, G = unpack(ElvUI)
local BH = E:NewModule('BuffHighlight', 'AceEvent-3.0', 'AceHook-3.0')
local UF = E:GetModule('UnitFrames')
local EP = LibStub("LibElvUIPlugin-1.0")

local addonName, Engine = ...
local GetAddOnMetadata  = GetAddOnMetadata

-- Highlighted group frames
HEADERS = {
	"party",
	"raid",
	"raid40"
}

-- Checks wether the specified spell
-- is tracked by the user
local function isTracked(spellID)
	for id, spell in pairs(E.db.BH.spells) do
		if spellID == tonumber(id) then
			return spell.enabled
		end
	end
	return false
end

-- Check if a tracked buff is currently on the unit
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

-- Check wether ElvUI is already highlighting an aura
local function AuraHighlighted(frame)
	if (not frame.AuraHighlight) then return false end
	
	local r, g, b, _ = frame.AuraHighlight:GetVertexColor()
	return r ~= 0 or g ~= 0 or b ~= 0
end

-- Resets the health color with default ElvUI colors
local function resetHealthBarColor(frame)
	-- Get default color
	local colors = E.db.unitframe.colors
	local r, g, b = colors.health.r, colors.health.g, colors.health.b

	-- Reset health brackdrop color
	if E.db.BH.colorBackdrop then
		local m = frame.bg.multiplier
		frame.bg:SetVertexColor(r * m, g * m, b * m)
	end
	-- Reset health color
	frame:SetStatusBarColor(r, g, b, 1.0)
end

function BH:resetHeader(name)
	if name == "player" then
		resetHealthBarColor(UF.player.Health)
	elseif name == "target" then
		resetHealthBarColor(UF.target.Health)
	else
		local header = UF.headers[name]
		for i = 1, header:GetNumChildren() do
			local group = select(i, header:GetChildren())
			for j = 1, group:GetNumChildren() do
				local frame = select(j, group:GetChildren())
				if frame and frame.unit and frame.Health then
					resetHealthBarColor(frame.Health)
				end
			end
		end
	end
end

function BH:resetAllHeaders()
	for _, name in pairs(HEADERS) do
		BH:resetHeader(name)
	end
	BH:resetHeader("player")
	BH:resetHeader("target")
end


-- Update the health color for the frame 
-- and the buff specified.
local function updateHealth(health, spellID)
	if not E.db.BH.spells[spellID] then return end

	if health.BuffHighlightActive then
		-- Get highlight color for the spell
		local t = E.db.BH.spells[spellID].glowColor
		local r, g, b, a = t.r, t.g, t.b, t.a
		
		-- Highlight the health backdrop if enabled
		if E.db.BH.colorBackdrop then
			local m = health.bg.multiplier
			health.bg:SetVertexColor(r * m, g * m, b * m)
		end
		-- Update the health color
		health:SetStatusBarColor(r, g, b, a)
	elseif health.BuffHighlightFaderActive then
		-- Get fade color for the spell
		local t = E.db.BH.spells[spellID].fadeColor
		local r, g, b, a = t.r, t.g, t.b, t.a

		-- Highlight the health backdrop if enabled
		if E.db.BH.colorBackdrop then 
			local m = health.bg.multiplier
			health.bg:SetVertexColor(r * m, g * m, b * m)
		end
		-- Update the health color
		health:SetStatusBarColor(r, g, b, a)
	end
end

-- Update the health. Check if a buff is applied
-- or if the fade effect should be displayed
-- for this frame health. Clears any buff highlight
-- if an aura is already highlighted by ElvUI
-- to avoid conflicts.
local function updateFrame(health, unit)
	-- Check if an aura is already highlighted
	if AuraHighlighted(health:GetParent()) then
		health.BuffHighlightActive = false
		health.BuffHighlightFaderActive = false

		resetHealthBarColor(health)
		return
	end

	-- Check if a buff is on the unit
	local buffDuration, spellID = CheckBuff(unit)
	-- If not, disabled the buff highlight if there was any
	if ((health.BuffHighlightActive or health.BuffHighlightFaderActive)
		and (not buffDuration or buffDuration < 0)) then
			health.BuffHighlightActive = false
			health.BuffHighlightFaderActive = false

			resetHealthBarColor(health)
			return
	end

	-- Enable the buff highlight or fade effect for this frame
	if not E.db.BH.spells[spellID] then return end
	if ((buffDuration > E.db.BH.spells[spellID].fadeThreshold) 
		or not E.db.BH.spells[spellID].fadeEnabled) then
			health.BuffHighlightActive = true
			health.BuffHighlightFaderActive = false
	else
			health.BuffHighlightActive = false
			health.BuffHighlightFaderActive = true
	end

	-- Update the health color
	updateHealth(health, spellID)
end

--  Check wether class colors unitframes are
--  enabled or not. If yes, then do not enable the plugin
local function usingClassColor()
	local val = E.db.unitframe.colors.healthclass
	if val ~= nil then
		return val
	end
end

-- Update function. Cycles through all unitframes
-- in party, raid and raid 40 groups. 
-- Roughly called every 0.1s
-- For better performances, it should be called on
-- the event "AURA_APPLIED". But the fading effect won't work
local function Update()
	for _, name in pairs(HEADERS) do
		if E.db.BH.trackedHeaders[name] then
			local header = UF.headers[name]
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

	if E.db.BH.trackedHeaders.player then
		updateFrame(UF.player.Health, UF.player.unit)
	end
	if E.db.BH.trackedHeaders.target then
		updateFrame(UF.target.Health, UF.target.unit)
	end
end

local timeSinceLastUpdate = 0

-- Called on every frame... not really efficient
-- but I have not found a better solution to make
-- the fade effect work
local function BH_OnUpdate(self, elapsed)
	timeSinceLastUpdate = timeSinceLastUpdate + elapsed; 	
	UPDATE_INTERVAL = E.db.BH.refreshRate
	while (timeSinceLastUpdate > UPDATE_INTERVAL) do
		Update()
		timeSinceLastUpdate = timeSinceLastUpdate - UPDATE_INTERVAL;
	end
end

function BH:Initialize()
	if not E.private.unitframe.enable then 
		return 
	end
	if  usingClassColor() then
		print([[
			|cff1784d1ElvUI|r |cff00b3ffBuffHighlight|r: 
			You are currently using class heath colors. Please 
			disable this option in order to BuffHilight to work. 
			(UnitFrames > General Options > Colors > Class Health)
		]])
		return
	end

	for _, name in pairs(HEADERS) do
		local header = UF.headers[name]
		for i = 1, header:GetNumChildren() do
			local group = select(i, header:GetChildren())
			for j = 1, group:GetNumChildren() do
				local frame = select(j, group:GetChildren())
				if frame and frame.Health and frame.unit then
					hooksecurefunc(
						frame.Health,
						"PostUpdateColor",
						function(self, unit, ...) updateFrame(self, unit) end
					)
				end
			end
		end
	end

	hooksecurefunc(
		UF.player.Health,
		"PostUpdateColor",
		function(self, unit, ...) updateFrame(self, unit) end
	)
	
	hooksecurefunc(
		UF.target.Health,
		"PostUpdateColor",
		function(self, unit, ...) updateFrame(self, unit) end
	)

	EP:RegisterPlugin(addonName, BH:InsertOptions())
end

local f = CreateFrame("Frame")

f:SetScript("OnEvent", function(self, event, ...)
	if (event == "UNIT_AURA") then Update() end
end)

function BH:disablePlugin()
	f:SetScript("OnUpdate", nil)
end

function BH:enablePlugin()
	f:SetScript("OnUpdate", BH_OnUpdate)
end

function BH:enableOnAura()
	BH:disablePlugin()
	f:RegisterEvent('UNIT_AURA')
	BH:resetAllHeaders()
end

function BH:disableOnAura()
	f:UnregisterEvent('UNIT_AURA')
	BH:enablePlugin()
	BH:resetAllHeaders()
end

BH:enablePlugin()

E:RegisterModule(BH:GetName())
