--[[
	TODO
		- Change plugin name
		- Complete Option panel (enable/disable fading, fading color, priority over debuff, ...)
		- Add raid 40 compatibility
]]

local E, L, V, P, G = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local MyPlugin = E:NewModule('MyPluginName', 'AceHook-3.0', 'AceEvent-3.0', 'AceTimer-3.0'); --Create a plugin within ElvUI and adopt AceHook-3.0, AceEvent-3.0 and AceTimer-3.0. We can make use of these later.
local EP = LibStub("LibElvUIPlugin-1.0") --We can use this to automatically insert our GUI tables when ElvUI_Config is loaded.
local addonName, addonTable = ... --See http://www.wowinterface.com/forums/showthread.php?t=51502&p=304704&postcount=2

local UF = E:GetModule('UnitFrames')

local eps = 0.001
local glimmerID = 287280
local glimmerColor = {r = 0.1, g = 0.6, b = 0.3, a = 1.0}
local glimmerFadeColor = {r = 0.0, g = 0.4, b = 0.1, a = 1.0}


local function CheckGlimmer(unit)
	if not unit or not UnitCanAssist("player", unit) then return nil end
	local i = 1
	while true do
		local _, texture,_,_,_, expire, source,_,_, spellID = UnitAura(unit, i, "HELPFUL")
		if not texture then break end

		if(spellID == glimmerID and source == "player") then
			return expire - GetTime()
		end
		i = i + 1
	end
end

local function DebuffHighlighted(object)
	local r, g, b, _ = object.DebuffHighlight:GetVertexColor()
	if r == 0 and g == 0 and b == 0 then return false end
	local d1 = math.abs(r - glimmerColor.r) < eps and math.abs(g - glimmerColor.g) < eps and math.abs(b - glimmerColor.b) < eps
	local d2 = math.abs(r - glimmerFadeColor.r) < eps and math.abs(g - glimmerFadeColor.g) < eps and math.abs(b - glimmerFadeColor.b) < eps
	return not (d1 or d2)
end

local function GlimmerUpdate(object, unit)
	if DebuffHighlighted(object) then return nil end
	local glimmerOn = CheckGlimmer(unit)
	if glimmerOn and glimmerOn > 5 then		
		object.DebuffHighlight:SetVertexColor(glimmerColor.r, glimmerColor.g, glimmerColor.b, glimmerColor.a)
	elseif glimmerOn and glimmerOn <= 5 then
		object.DebuffHighlight:SetVertexColor(glimmerFadeColor.r, glimmerFadeColor.g, glimmerFadeColor.b, glimmerColor.a)
	else
		object.DebuffHighlight:SetVertexColor(0, 0, 0, 0)
	end
end


local function UpdateInRaid()
	for num, frame in pairs(ElvUF_Raid.groups) do
		for i = 1, 5 do
			if ElvUF_Raid.groups[num][i] then
				local frame = ElvUF_Raid.groups[num][i]
				local unit = frame.unit
				if frame.DebuffHighlight then
					GlimmerUpdate(frame, unit)
				end
			end
		end
	end
end

local function UpdateInGroup()
	if ElvUF_Party.groups[1] then
		for i = 1, 5 do
			if ElvUF_Party.groups[1][i] then
				local frame = ElvUF_Party.groups[1][i]
				local unit = frame.unit
				if frame.DebuffHighlight then
					GlimmerUpdate(frame, unit)
				end
			end
		end
	end
end

local function Update()
	if not E.db.MyPlugin.enable then return nil end
	if IsInRaid() then UpdateInRaid()
	elseif IsInGroup() then UpdateInGroup() end
end


--Default options
P["MyPlugin"] = {
	["enable"] = true,
}


--This function inserts our GUI table into the ElvUI Config. You can read about AceConfig here: http://www.wowace.com/addons/ace3/pages/ace-config-3-0-options-tables/
function MyPlugin:InsertOptions()
	E.Options.args.MyPlugin = {
		order = 100,
		type = "group",
		name = "MyPlugin",
		args = {
			enable = {
				order = 1,
				type = "toggle",
				name = "MyToggle",
				get = function(info)
					return E.db.MyPlugin.enable
				end,
				set = function(info, value)
					E.db.MyPlugin.enable = value
					Update() --We changed a setting, call our Update function
				end,
			},
		},
	}
end

function MyPlugin:Initialize()
	--Register plugin so options are properly inserted when config is loaded
	EP:RegisterPlugin(addonName, MyPlugin.InsertOptions)
end

local f = CreateFrame("Frame")
f:SetScript("OnUpdate", Update)

E:RegisterModule(MyPlugin:GetName()) --Register the module with ElvUI. ElvUI will now call MyPlugin:Initialize() when ElvUI is ready to load our plugin.