--[[
	TODO
		- Complete Option panel (priority over debuff, ...)
]]

local E, L, V, P, G = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local BH = E:NewModule('BuffHighlight', 'AceHook-3.0', 'AceEvent-3.0', 'AceTimer-3.0'); 
local EP = LibStub("LibElvUIPlugin-1.0") 
local addonName, addonTable = ... 
local UF = E:GetModule('UnitFrames')


local abs = math.abs
local format = string.format

local eps = 0.002

local function isTracked(spellID)
	for id, name in pairs(E.db.BH.trackedBuffsID) do
		if name and spellID == tonumber(id) then return true end
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
			return expire - GetTime()
		end
		i = i + 1
	end
end

local function resetHealthBarColor(object)
	local colors = E.db.unitframe.colors
	local r, g, b = colors.health.r, colors.health.g, colors.health.b
	object.Health:SetStatusBarColor(r, g, b, 1.0)
end

local function DebuffHighlighted(object)
	local r, g, b, _ = object.DebuffHighlight:GetVertexColor()
	if r == 0 and g == 0 and b == 0 then return false end
	local d1 = abs(r - E.db.BH.buffColor.r) < eps 
				and abs(g - E.db.BH.buffColor.g) < eps 
				and abs(b - E.db.BH.buffColor.b) < eps

	local d2 = abs(r - E.db.BH.buffFadeColor.r) < eps 
				and abs(g - E.db.BH.buffFadeColor.g) < eps 
				and abs(b - E.db.BH.buffFadeColor.b) < eps
	return not (d1 or d2)
end

local function BuffUpdate(object)
	local buffOn = CheckBuff(object.unit)
	if DebuffHighlighted(object) then 
		if buffOn then resetHealthBarColor(object) end
		return nil 
	end

	if buffOn and (buffOn > E.db.BH.fadeThreshold or not E.db.BH.fadeEnable) then
		local r = E.db.BH.buffColor.r
		local g = E.db.BH.buffColor.g
		local b = E.db.BH.buffColor.b
		local a = E.db.BH.buffColor.a
		
		if E.db.BH.colorBackdrop then 
			object.DebuffHighlight:SetVertexColor(r, g, b, a)
		else
			object.Health:SetStatusBarColor(r, g, b, a)
		end
	elseif buffOn and buffOn <= E.db.BH.fadeThreshold then
		local r = E.db.BH.buffFadeColor.r
		local g = E.db.BH.buffFadeColor.g
		local b = E.db.BH.buffFadeColor.b
		local a = E.db.BH.buffFadeColor.a

		if E.db.BH.colorBackdrop then 
			object.DebuffHighlight:SetVertexColor(r, g, b, a)
		else
			object.Health:SetStatusBarColor(r, g, b, a)
		end
	else
		if E.db.BH.colorBackdrop then 
			object.DebuffHighlight:SetVertexColor(0, 0, 0, 0)
		else
			resetHealthBarColor(object)
		end
	end
end

local function Update()
	if E.db.BH.enable then
		for name, header in pairs(UF.headers) do
			if name ~= "tank" and name ~= "assist" then
				for i = 1, header:GetNumChildren() do
					local group = select(i, header:GetChildren())
					for j = 1, group:GetNumChildren() do
						local frame = select(j, group:GetChildren())
						if frame and frame.Health and frame.unit then
							BuffUpdate(frame)
						end
					end
				end
			end
		end
	end
end

local function getBuffList()
	local str = "\nCurrently tracked buffs:\n"
	if not E.db.BH.trackedBuffsID then return str end
	for id, name in pairs(E.db.BH.trackedBuffsID) do
		if name then 
			str = str..format("    - %s (%s)\n", name, id)
		end
	end
	return str
end

local function updateBuffList()
	E.db.BH.buffList = getBuffList()
	E.Options.args.BH.args.gr3.args.trackedSpells.name = E.db.BH.buffList
end

--Default options
P["BH"] = {
	["enable"] = true,
	["buffColor"] = {r = 0.1, g = 0.6, b = 0.3, a = 1.0},
	["colorBackdrop"] = false,
	["fadeEnable"] = true,
	["buffFadeColor"] = {r = 0.0, g = 0.4, b = 0.1, a = 1.0},
	["fadeThreshold"] = 5,
	["trackedBuffsID"] = { ["287280"] = "Glimmer of Light", },
	["buffList"] = "\nCurrently tracked buffs:\n    - Glimmer of Light (287280)\n",
}

--This function inserts our GUI table into the ElvUI Config. You can read about AceConfig here: http://www.wowace.com/addons/ace3/pages/ace-config-3-0-options-tables/
function BH:InsertOptions()
	E.Options.args.BH = {
		order = 100,
		type = "group",
		name = "|cff00b3ffBuffHighlight|r",
		args = {
			title = {
				order = 1,
				type = "header",
				name = "Buff Highlight",
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
							return E.db.BH.enable
						end,
						set = function(info, value)
							E.db.BH.enable = value
						end,
					},
					buffColor = {
						order = 4,
						type = "color",
						name = "Highlight Color",
						hasAlpha = true,
						get = function(info)
							local r = E.db.BH.buffColor.r
							local g = E.db.BH.buffColor.g
							local b = E.db.BH.buffColor.b
							local a = E.db.BH.buffColor.a
							return r, g, b, a
						end,
						set = function(info, r, g, b, a)
							E.db.BH.buffColor.r = r
							E.db.BH.buffColor.g = g
							E.db.BH.buffColor.b = b
							E.db.BH.buffColor.a = a
						end,
					},
					colorBackdrop = {
						order = 5,
						type = "toggle",
						name = "Colored backdrop",
						get = function(info)
							return E.db.BH.colorBackdrop
						end,
						set = function(info, value)
							E.db.BH.colorBackdrop = value
							Update()
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
							return E.db.BH.fadeEnable
						end,
						set = function(info, value)
							E.db.BH.fadeEnable = value
						end,
					},
					fc = {
						order = 8,
						type = "color",
						name = "Fade Color",
						hasAlpha = true,
						get = function(info)
							local r = E.db.BH.buffFadeColor.r
							local g = E.db.BH.buffFadeColor.g
							local b = E.db.BH.buffFadeColor.b
							local a = E.db.BH.buffFadeColor.a
							return r, g, b, a
						end,
						set = function(info, r, g, b, a)
							E.db.BH.buffFadeColor.r = r
							E.db.BH.buffFadeColor.g = g
							E.db.BH.buffFadeColor.b = b
							E.db.BH.buffFadeColor.a = a
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
							return E.db.BH.fadeThreshold
						end,
						set = function(info, value)
							E.db.BH.fadeThreshold = value
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
					addSpell = {
						order = 10,
						type = "input",
						name = "Add Buff ID",
						width = 10,
						get = function(info)
							return "Buff ID"
						end,
						set = function(info, data)
							local newName, _, _, _, _, _, newID = GetSpellInfo(data)
							if newID and newName then 
								E.db.BH.trackedBuffsID[tostring(newID)] = newName
							end
							updateBuffList()
						end,
					},
					delSpell = {
						order = 12,
						type = "input",
						name = "Remove Buff ID",
						width = 10,
						get = function(info)
							return "Buff ID"
						end,
						set = function(info, data)
							E.db.BH.trackedBuffsID[tostring(data)] = nil
							updateBuffList()
						end,
					},
					trackedSpells = {
						order = 14,
						type = "description",
						name = E.db.BH.buffList,
					}
				},
			}
		},
	}
end

function BH:Initialize()
	--Register plugin so options are properly inserted when config is loaded
	EP:RegisterPlugin(addonName, BH.InsertOptions)
end

local f = CreateFrame("Frame")
f:SetScript("OnUpdate", Update)

E:RegisterModule(BH:GetName()) --Register the module with ElvUI. ElvUI will now call BH:Initialize() when ElvUI is ready to load our plugin.
