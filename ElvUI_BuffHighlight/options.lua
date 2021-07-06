local E, L, V, P, G = unpack(ElvUI);
local BH = E:GetModule('BuffHighlight');
local addonName, _ = ...

local selectedSpell, quickSearchText, spellList = nil, '', {}

local function GetSelectedSpell()
	if selectedSpell and selectedSpell ~= '' then
		local spell = strmatch(selectedSpell, " %((%d+)%)$") or selectedSpell
		if spell then
			return tonumber(spell) or spell
		end
	end
end

function BH:InsertOptions()
	local version = format('|cff1784d1v%s|r', GetAddOnMetadata(addonName, 'Version'))

	E.Options.args.BH = {
		order = 100,
		type = "group",
		name = "|cff00b3ffBuffHighlight|r",
		args = {
			title = {
				order = 1,
				type = "header",
				name = format('|cff00b3ffBuffHighlight|r [%s] by |cfff48cbaKaalos|r', version),
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
							if value then BH:enablePlugin()
							else BH:disablePlugin() end
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
					refreshRate = {
						order = 3,
						type = "range",
						name = "Refresh rate",
						desc = "Fade check refresh rate",
						min = 0.05,
						max = 1,
						step = 0.05,
						get = function(info)
							return E.db.BH.refreshRate
						end,
						set = function(info, value)
							E.db.BH.refreshRate = value
						end,
					},
				},
			},
			framesOptions = {
				order = 3,
				type = "group",
				name = "Frames Options",
				guiInline = true,
				args = {
					player = {
						order = 1,
						type = "toggle",
						name = "Player",
						desc = "Enable/Disable the buff highlight for the player frame",
						width = "half",
						get = function(info)
							return E.db.BH.trackedHeaders.player
						end,
						set = function(info, value)
							E.db.BH.trackedHeaders.player = value
							if not value then BH:resetHeader("player") end
						end,
					},
					target = {
						order = 2,
						type = "toggle",
						name = "Target",
						desc = "Enable/Disable the buff highlight for the target frame",
						width = "half",
						get = function(info)
							return E.db.BH.trackedHeaders.target
						end,
						set = function(info, value)
							E.db.BH.trackedHeaders.target = value
							if not value then BH:resetHeader("target") end
						end,
					},
					party = {
						order = 3,
						type = "toggle",
						name = "Party",
						desc = "Enable/Disable the buff highlight for the party frame",
						width = "half",
						get = function(info)
							return E.db.BH.trackedHeaders.party
						end,
						set = function(info, value)
							E.db.BH.trackedHeaders.party = value
							if not value then BH:resetHeader("party") end
						end,
					},
					raid = {
						order = 4,
						type = "toggle",
						name = "Raid",
						desc = "Enable/Disable the buff highlight for the raid frame",
						width = "half",
						get = function(info)
							return E.db.BH.trackedHeaders.raid
						end,
						set = function(info, value)
							E.db.BH.trackedHeaders.raid = value
							if not value then BH:resetHeader("raid") end
						end,
					},
					raid40 = {
						order = 5,
						type = "toggle",
						name = "Raid40",
						desc = "Enable/Disable the buff highlight for the raid40 frame",
						width = "half",
						get = function(info)
							return E.db.BH.trackedHeaders.raid40
						end,
						set = function(info, value)
							E.db.BH.trackedHeaders.raid40 = value
							if not value then BH:resetHeader("raid40") end
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
								desc = "|cFFFF0000 May be heavy on CPU !",
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
									if value then BH:disableOnAura()
									else BH:enableOnAura() end
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
