--[[
	TODO
		- Complete Option panel (priority over debuff, ...)
		- More reliable group scanning
		- Add raid 40 compatibility
]]

local E, L, V, P, G = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local GH = E:NewModule('GlimmerHighlight', 'AceHook-3.0', 'AceEvent-3.0', 'AceTimer-3.0'); --Create a plugin within ElvUI and adopt AceHook-3.0, AceEvent-3.0 and AceTimer-3.0. We can make use of these later.
local EP = LibStub("LibElvUIPlugin-1.0") --We can use this to automatically insert our GUI tables when ElvUI_Config is loaded.
local addonName, addonTable = ... --See http://www.wowinterface.com/forums/showthread.php?t=51502&p=304704&postcount=2

local UF = E:GetModule('UnitFrames')

local eps = 0.002

local function CheckBuff(unit)
	if not unit or not UnitCanAssist("player", unit) then return nil end
	local i = 1
	local trackedBuffID = E.db.GH.trackedBuffID
	while true do
		local _, texture,_,_,_, expire, source,_,_, spellID = UnitAura(unit, i, "HELPFUL")
		if not texture then break end

		if(spellID == trackedBuffID and source == "player") then
			return expire - GetTime()
		end
		i = i + 1
	end
end

local function DebuffHighlighted(object)
	local r, g, b, _ = object.DebuffHighlight:GetVertexColor()
	if r == 0 and g == 0 and b == 0 then return false end
	local d1 = math.abs(r - E.db.GH.buffColor.r) < eps 
				and math.abs(g - E.db.GH.buffColor.g) < eps 
				and math.abs(b - E.db.GH.buffColor.b) < eps

	local d2 = math.abs(r - E.db.GH.buffFadeColor.r) < eps 
				and math.abs(g - E.db.GH.buffFadeColor.g) < eps 
				and math.abs(b - E.db.GH.buffFadeColor.b) < eps
	return not (d1 or d2)
end

local function BuffUpdate(object, unit)
	if DebuffHighlighted(object) then return nil end

	local buffOn = CheckBuff(unit)
	if buffOn and (buffOn > E.db.GH.fadeThreshold or not E.db.GH.fadeEnable) then
		local r = E.db.GH.buffColor.r
		local g = E.db.GH.buffColor.g
		local b = E.db.GH.buffColor.b
		object.DebuffHighlight:SetVertexColor(r, g, b, 1.0)
	elseif buffOn and buffOn <= E.db.GH.fadeThreshold then
		local r = E.db.GH.buffFadeColor.r
		local g = E.db.GH.buffFadeColor.g
		local b = E.db.GH.buffFadeColor.b
		object.DebuffHighlight:SetVertexColor(r, g, b, 1.0)
	else
		object.DebuffHighlight:SetVertexColor(0, 0, 0, 0)
	end
end

-- Dirty code
local function UpdateInRaid()
	for num, frame in pairs(ElvUF_Raid.groups) do
		for i = 1, 5 do
			if ElvUF_Raid.groups[num][i] then
				local frame = ElvUF_Raid.groups[num][i]
				local unit = frame.unit
				if frame.DebuffHighlight then
					BuffUpdate(frame, unit)
				end
			end
		end
	end
end

-- Dirty code
local function UpdateInGroup()
	if ElvUF_Party.groups[1] then
		for i = 1, 5 do
			if ElvUF_Party.groups[1][i] then
				local frame = ElvUF_Party.groups[1][i]
				local unit = frame.unit
				if frame.DebuffHighlight then
					BuffUpdate(frame, unit)
				end
			end
		end
	end
end

local function Update()
	if not E.db.GH.enable then return nil end
	if IsInRaid() then UpdateInRaid()
	elseif IsInGroup() then UpdateInGroup() end
end

local function nameFromID(spellID)
	name, _, _, _, _, _, _ = GetSpellInfo(spellID)
	return name
end

local function retrieveID(spellNameOrID)
	name, _, _, _, _, _, spellID = GetSpellInfo(spellNameOrID)
	return spellID
end

local function retrieveIcon(spellName)
	_, _, icon, _, _, _, _ = GetSpellInfo(spellNameOrID)
	return icon
end

--Default options
P["GH"] = {
	["enable"] = true,
	["buffColor"] = {r = 0.1, g = 0.6, b = 0.3, a = 1.0},
	["fadeEnable"] = true,
	["buffFadeColor"] = {r = 0.0, g = 0.4, b = 0.1, a = 1.0},
	["fadeThreshold"] = 5,
	["trackedBuffID"] = 287280,
}

--This function inserts our GUI table into the ElvUI Config. You can read about AceConfig here: http://www.wowace.com/addons/ace3/pages/ace-config-3-0-options-tables/
function GH:InsertOptions()
	E.Options.args.GH = {
		order = 100,
		type = "group",
		name = "|cff00b3ffGlimmerHighlight|r",
		args = {
			title = {
				order = 1,
				type = "header",
				name = "Glimmer of Light Highlight",
			},
			gr1 = {
				order = 2,
				type = "group",
				name = "Main Options",
				guiInline = true,
				args = {
					enable = {
						order = 3,
						type = "toggle",
						name = "Enable",
						desc = "Enable/Disable the buff highlight",
						get = function(info)
							return E.db.GH.enable
						end,
						set = function(info, value)
							E.db.GH.enable = value
						end,
					},
					buffColor = {
						order = 4,
						type = "color",
						name = "Highlight Color",
						get = function(info)
							local r = E.db.GH.buffColor.r
							local g = E.db.GH.buffColor.g
							local b = E.db.GH.buffColor.b
							return r, g, b, 1.0
						end,
						set = function(info, r, g, b, a)
							E.db.GH.buffColor.r = r
							E.db.GH.buffColor.g = g
							E.db.GH.buffColor.b = b
						end,
					},
				},
			},
			gr2 = {
				order = 3,
				type = "group",
				name = "Fading Options",
				guiInline = true,
				args = {
					fadeEnable = {
						order = 7,
						type = "toggle",
						name = "Enable Fade",
						desc = "Enable/Disable the fading highlight",
						get = function(info)
							return E.db.GH.fadeEnable
						end,
						set = function(info, value)
							E.db.GH.fadeEnable = value
						end,
					},
					fc = {
						order = 8,
						type = "color",
						name = "Fade Color",
						get = function(info)
							local r = E.db.GH.buffFadeColor.r
							local g = E.db.GH.buffFadeColor.g
							local b = E.db.GH.buffFadeColor.b
							return r, g, b, 1.0
						end,
						set = function(info, r, g, b, a)
							E.db.GH.buffFadeColor.r = r
							E.db.GH.buffFadeColor.g = g
							E.db.GH.buffFadeColor.b = b
						end,
					},
					ft = {
						order = 9,
						type = "range",
						name = "Fading Threshold",
						desc = "Time remaining at which the buff will fade",
						min = 1,
						max = 29,
						step = 1,
						get = function(info)
							return E.db.GH.fadeThreshold
						end,
						set = function(info, value)
							E.db.GH.fadeThreshold = value
						end,
					}
				},
			},
			gr3 = {
				order = 3,
				type = "group",
				name = "Tracked spell",
				guiInline = true,
				args = {
					changeSpell = {
						order = 10,
						type = "input",
						name = "Buff ID",
						width = 100,
						get = function(info)
							local name = nameFromID(E.db.GH.trackedBuffID)
							local id = retrieveID(E.db.GH.trackedBuffID)
							return string.format("%s (%s)", name, id)
						end,
						set = function(info, data)
							newID = retrieveID(data)
							if newID then E.db.GH.trackedBuffID = newID end
						end,
					},
				},
			}
		},
	}
end

function GH:Initialize()
	--Register plugin so options are properly inserted when config is loaded
	EP:RegisterPlugin(addonName, GH.InsertOptions)
end

local f = CreateFrame("Frame")
f:SetScript("OnUpdate", Update)

E:RegisterModule(GH:GetName()) --Register the module with ElvUI. ElvUI will now call GH:Initialize() when ElvUI is ready to load our plugin.
