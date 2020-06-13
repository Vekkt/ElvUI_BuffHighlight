local E, L, V, P, G = unpack(ElvUI);
local BH = E:GetModule('BuffHighlight');
local UF = E:GetModule('UnitFrames');
local addon = ...

local selectedSpell, quickSearchText, spellList = nil, '', {}

local function GetSelectedSpell()
	if selectedSpell and selectedSpell ~= '' then
		local spell = strmatch(selectedSpell, " %((%d+)%)$") or selectedSpell
		if spell then
			return tonumber(spell) or spell
		end
	end
end

function BH:GetOptions()
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
			addonOptions = {
				order = 2,
				type = "group",
				name = "Main Options",
				guiInline = true,
				args = {
					enable = {
						order = 1,
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
					colorBackdrop = {
						order = 2,
						type = "toggle",
						name = "Colored backdrop",
						get = function(info)
							return E.db.BH.colorBackdrop
						end,
						set = function(info, value)
							E.db.BH.colorBackdrop = value
						end,
					},
					overwriteDBH = {
						order = 3,
						type = "toggle",
						name = "Overwrite debuff highlight",
						get = function(info)
							return E.db.BH.overwriteDBH
						end,
						set = function(info, value)
							E.db.BH.overwriteDBH = value
						end,
					},
				},
			},
			selectGroup = {
				type = 'group',
				name = "Spells options",
				guiInline = true,
				order = 10,
				args = {
					addSpell = {
						order = 1,
						name = "Add Spell ID",
						desc = "Add a buff to highlight.",
						type = 'input',
						get = function(info) return "" end,
						set = function(info, value)
							value = tonumber(value)
							if not value then return end

							local spellName = GetSpellInfo(value)
							selectedSpell = (spellName and value) or nil
							if not selectedSpell then return end
							
							E.db.BH.spells[value] = {
								["enabled"] = true,
								["fadeEnabled"] = true,
								["fadeThreshold"] = 5,
								["glowColor"] = {r = 0.1, g = 0.6, b = 0.3, a = 1.0},
								["fadeColor"] = {r = 0.0, g = 0.4, b = 0.1, a = 1.0},
							}
						end,
					},
					quickSearch = {
						order = 2,
						name = "Filter Search",
						desc = "Search for a spell name inside of a filter.",
						type = "input",
						get = function() return quickSearchText end,
						set = function(info,value) quickSearchText = value end,
					},
					selectSpell = {
						name = "Select Spell",
						type = 'select',
						order = 10,
						width = "double",
						get = function(info) return selectedSpell or '' end,
						set = function(info, value)
							selectedSpell = (value ~= '' and value) or nil
						end,
						values = function()
							local list = E.db.BH.spells
	
							if not list then return end
							wipe(spellList)
	
							local searchText = quickSearchText:lower()
							for id, spell in pairs(list) do
								local spellName = tonumber(id) and GetSpellInfo(id)
								local name = (spellName and format("%s |cFF888888(%s)|r", spellName, id)) or tostring(id)
	
								if name:lower():find(searchText) then
									spellList[id] = name
								end
							end
	
							if not next(spellList) then
								spellList[''] = "NONE"
							end
	
							return spellList
						end,
					},
					removeSpell = {
						order = 11,
						name = "Remove Spell",
						desc = "Remove a highlighted buff.",
						type = 'execute',
						func = function()
							local value = GetSelectedSpell()
							if not value then return end
							selectedSpell = nil
	
							E.db.BH.spells[value] = nil
						end,
						disabled = function()
							local spell = GetSelectedSpell()
							if not spell then return true end
						end,
					},
				},
			},
			spellGroup = {
				type = "group",
				name = function()
					local spell = GetSelectedSpell()
					local spellName = spell and GetSpellInfo(spell)
					return (spellName and spellName..' |cFF888888('..spell..')|r') or spell or ' '
				end,
				hidden = function() return not selectedSpell end,
				order = -15,
				guiInline = true,
				args = {
					mainSpellOptions = {
						order = 0,
						type = "group",
						name = 'Glow options',
						guiInline = true,
						args = {
							enabled = {
								name = "Enable",
								order = 0,
								type = 'toggle',
								get = function(info)
									local spell = GetSelectedSpell()
									if not spell then return end
			
									return E.db.BH.spells[spell].enabled
								end,
								set = function(info, value)
									local spell = GetSelectedSpell()
									if not spell then return end
			
									E.db.BH.spells[spell].enabled = value
								end,
							},
							glowColor = {
								order = 1,
								type = "color",
								name = "Highlight Color",
								hasAlpha = true,
								get = function(info)
									local spell = GetSelectedSpell()
									local t = E.db.BH.spells[spell].glowColor
									if t then
										return t.r, t.g, t.b, t.a
									end
								end,
								set = function(info, r, g, b, a)
									local spell = GetSelectedSpell()
									local t = E.db.BH.spells[spell].glowColor
									if t then
										t.r, t.g, t.b, t.a = r, g, b, a
									end
								end,
							},
						},
					},
					fadeSpellOptions = {
						order = 1,
						type = "group",
						name = 'Fade options',
						guiInline = true,
						args = {
							fadeEnabled = {
								name = "Fade enable",
								order = 15,
								type = 'toggle',
								get = function(info)
									local spell = GetSelectedSpell()
									if not spell then return end
			
									return E.db.BH.spells[spell].fadeEnabled
								end,
								set = function(info, value)
									local spell = GetSelectedSpell()
									if not spell then return end
			
									E.db.BH.spells[spell].fadeEnabled = value
								end,
							},
							fadeThreshold = {
								order = 16,
								type = "range",
								name = "Fading Threshold",
								desc = "Time remaining at which the buff will fade",
								min = 1,
								max = 30,
								step = 1,
								get = function(info)
									local spell = GetSelectedSpell()
									if not spell then return end
									return E.db.BH.spells[spell].fadeThreshold
								end,
								set = function(info, value)
									local spell = GetSelectedSpell()
									if not spell then return end
									E.db.BH.spells[spell].fadeThreshold = value
								end,
							},
							fadeColor = {
								order = 4,
								type = "color",
								name = "Fade Color",
								hasAlpha = true,
								get = function(info)
									local spell = GetSelectedSpell()
									local t = E.db.BH.spells[spell].fadeColor
									if t then
										return t.r, t.g, t.b, t.a
									end
								end,
								set = function(info, r, g, b, a)
									local spell = GetSelectedSpell()
									local t = E.db.BH.spells[spell].fadeColor
									if t then
										t.r, t.g, t.b, t.a = r, g, b, a
									end
								end,
							},
						},
					},
				},
			}
		},
	}
end