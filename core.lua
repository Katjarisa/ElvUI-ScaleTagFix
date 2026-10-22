local E = unpack(ElvUI)
local EP = LibStub("LibElvUIPlugin-1.0")
local ElvUF = E.oUF
local Tags = ElvUF.Tags

local format, floor, find, gsub = string.format, math.floor, string.find, string.gsub
local pairs, ipairs, type, tonumber, tostring = pairs, ipairs, type, tonumber, tostring

local ADDON = "ElvUI_ScaleTagFix"
local PC = {}
local pendingTagInfo = {}
local tagInfoAdded = {}

-------------------------------------------------------------------------
-- Saved settings (account-wide)
-------------------------------------------------------------------------
local DEFAULTS = {
	fromScale = 0.59,
	toScale = E.global and E.global.general and E.global.general.UIScale or 0.71,
	doMovers = true,
	doSizes = true,
	doFonts = true,
	addTags = true,
	stripTags = false,
	fixPetBattle = true,
	hidePetBar = false,
}
ElvUIScaleTagFixDB = ElvUIScaleTagFixDB or {}
local DB = ElvUIScaleTagFixDB
for k, v in pairs(DEFAULTS) do if DB[k] == nil then DB[k] = v end end

-------------------------------------------------------------------------
-- 1) Retail-style tags (registered at load, only if enabled)
-------------------------------------------------------------------------
local function Hex(r, g, b)
	return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function QueueTagInfo(name, category, description)
	-- E:AddTagInfo also updates ElvUI's options metadata. On the 3.3.5
	-- backport that must wait until the options plugin callback runs.
	if not tagInfoAdded[name] then
		pendingTagInfo[name] = { category = category, description = description }
	end
end

local function RegisterTag(name, events, func, category, description)
	if Tags.Methods[name] then return end -- never override an existing tag
	Tags.Events[name] = events
	Tags.Methods[name] = func
	QueueTagInfo(name, category, description)
end

local function ClassColor(unit)
	if unit and UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local c = class and ElvUF.colors.class[class]
		if c then return Hex(c[1], c[2], c[3]) end
	end
	return ""
end

local scanTip
local function NPCTitle(unit)
	if UnitIsPlayer(unit) then return end
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", "ElvUIScaleTagFixTip", nil, "GameTooltipTemplate")
		scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	end
	scanTip:ClearLines()
	scanTip:SetUnit(unit)
	local line = _G["ElvUIScaleTagFixTipTextLeft2"]
	local text = line and line:GetText()
	if not text then return end
	local lvl = gsub(TOOLTIP_UNIT_LEVEL or "Level %s", "%%s", ".+")
	if find(text, lvl) or find(text, "^%d+") then return end -- that's the level line, not a title
	return text
end

-- Tags confirmed to exist in retail ElvUI (tukui-org wiki / DeepWiki tag docs):
-- classcolor, classcolor:target, reactioncolor, npctitle, name:first, name:last,
-- and ":shortvalue" variants of health/power/mana tags.
function PC:RegisterTags()
	if PC.tagsDone then return end
	PC.tagsDone = true

	RegisterTag("classcolor", "UNIT_NAME_UPDATE UNIT_FACTION", ClassColor,
		"Colors", "Colors text by player class (retail-style tag)")

	RegisterTag("classcolor:target", "UNIT_TARGET", function(unit) return ClassColor(unit .. "target") end,
		"Colors", "Colors text by the unit's target's class (retail-style tag)")

	RegisterTag("reactioncolor", "UNIT_NAME_UPDATE UNIT_FACTION", function(unit)
		local reaction = UnitReaction(unit, "player")
		local c = reaction and ElvUF.colors.reaction[reaction]
		if c then return Hex(c[1], c[2], c[3]) end
		return ""
	end, "Colors", "Colors text by the unit's reaction toward you (retail-style tag)")

	RegisterTag("npctitle", "UNIT_NAME_UPDATE", NPCTitle,
		"Names", "Displays the NPC subtitle, e.g. <Blacksmith> (retail-style tag)")

	RegisterTag("name:first", "UNIT_NAME_UPDATE", function(unit)
		local name = UnitName(unit)
		return name and name:match("^(%S+)") or ""
	end, "Names", "Displays only the first part of the name (retail-style tag)")

	RegisterTag("name:last", "UNIT_NAME_UPDATE", function(unit)
		local name = UnitName(unit)
		return name and name:match("(%S+)$") or ""
	end, "Names", "Displays only the last part of the name (retail-style tag)")

	-- Common newer-ElvUI tags that are safe to emulate with the 3.3.5 API.
	-- Never replace a tag already supplied by this ElvUI backport.
	RegisterTag("class", "UNIT_NAME_UPDATE UNIT_LEVEL", function(unit)
		local _, class = UnitClass(unit)
		return class or ""
	end, "Names", "Displays the unit's class token")

	RegisterTag("race", "UNIT_NAME_UPDATE", function(unit)
		local race = UnitRace(unit)
		return race or ""
	end, "Names", "Displays the unit's race")

	RegisterTag("level", "UNIT_LEVEL PLAYER_LEVEL_UP", function(unit)
		local level = UnitLevel(unit)
		if not level or level < 0 then return "??" end
		return tostring(level)
	end, "Stats", "Displays the unit's level")

	RegisterTag("guild", "UNIT_NAME_UPDATE PLAYER_GUILD_UPDATE", function(unit)
		local guild = GetGuildInfo(unit)
		return guild or ""
	end, "Names", "Displays the unit's guild name")

	RegisterTag("realm", "UNIT_NAME_UPDATE", function(unit)
		local _, realm = UnitName(unit)
		if realm and realm ~= "" then return realm end
		return ""
	end, "Names", "Displays the unit's realm when available")

	RegisterTag("name:realm", "UNIT_NAME_UPDATE", function(unit)
		local name, realm = UnitName(unit)
		if not name then return "" end
		if realm and realm ~= "" then return name .. "-" .. realm end
		return name
	end, "Names", "Displays name with realm when available")

	-- Profile-specific tags reported by the unknown-tag scanner.
	-- [mouseover] displays a short label when this unit is the current mouseover.
	RegisterTag("mouseover", "UPDATE_MOUSEOVER_UNIT UNIT_NAME_UPDATE", function(unit)
		if UnitIsUnit and UnitIsUnit(unit, "mouseover") then return "Mouseover" end
		return ""
	end, "Names", "Displays 'Mouseover' when this unit is the current mouseover")

	-- Retail has absorb-aware health display; WotLK 3.3.5 may not expose an
	-- absorb API. Fall back to ordinary health percentage when unavailable.
	RegisterTag("health:percent-with-absorbs", "UNIT_HEALTH UNIT_MAXHEALTH UNIT_HEALTH_FREQUENT", function(unit)
		local maxHealth = UnitHealthMax(unit)
		if not maxHealth or maxHealth <= 0 then return "0%" end
		local health = UnitHealth(unit) or 0
		local absorbs = 0
		if UnitGetTotalAbsorbs then
			local value = UnitGetTotalAbsorbs(unit)
			if type(value) == "number" then absorbs = value end
		end
		return tostring(floor(((health + absorbs) / maxHealth) * 100 + 0.5)) .. "%"
	end, "Health", "Displays health percent including absorbs when the client API supports it; otherwise displays health percent")

	-- ":shortvalue" aliases. In this backport the health/power/mana tags already
	-- abbreviate numbers (E:ShortValue), so retail's "x:shortvalue" == "x" here.
	local names = {}
	for name in pairs(Tags.Methods) do
		if type(name) == "string"
			and (find(name, "^health:") or find(name, "^power:") or find(name, "^mana:"))
			and not find(name, ":name") and not find(name, "shortvalue", 1, true) then
			names[#names + 1] = name
		end
	end
	for _, name in ipairs(names) do
		local alias = name .. ":shortvalue"
		if not Tags.Methods[alias] then
			Tags.Events[alias] = Tags.Events[name]
			Tags.Methods[alias] = Tags.Methods[name]
			QueueTagInfo(alias, "Health", "Same as [" .. name .. "] (retail ':shortvalue' spelling)")
		end
	end
end

if DB.addTags then PC:RegisterTags() end

-------------------------------------------------------------------------
-- 2) Scale conversion
-------------------------------------------------------------------------
local INCLUDE = { "width", "height", "size", "spacing", "offset" }
local EXCLUDE = { "border", "scale", "alpha", "number", "num", "max", "min" }

local function Matches(key, withFonts)
	if type(key) ~= "string" then return false end
	local k = key:lower()
	local isFont = find(k, "font", 1, true)
	if isFont and not withFonts then return false end
	if not isFont then
		for _, w in ipairs(EXCLUDE) do
			if find(k, w, 1, true) then return false end
		end
	end
	for _, w in ipairs(INCLUDE) do
		if find(k, w, 1, true) then return true end
	end
	return false
end

local function Round(n) return n >= 0 and floor(n + 0.5) or -floor(-n + 0.5) end

local function DeepCopy(t)
	local c = {}
	for k, v in pairs(t) do c[k] = type(v) == "table" and DeepCopy(v) or v end
	return c
end

local function ScaleMovers(movers, ratio, stats)
	for name, str in pairs(movers) do
		if type(str) == "string" then
			local p, parent, rp, x, y = strsplit(",", str)
			x, y = tonumber(x), tonumber(y)
			if p and parent and rp and x and y then
				movers[name] = format("%s,%s,%s,%d,%d", p, parent, rp, Round(x * ratio), Round(y * ratio))
				stats.movers = stats.movers + 1
			end
		end
	end
end

local function ScaleWalk(t, ratio, stats)
	for key, val in pairs(t) do
		if type(val) == "table" then
			ScaleWalk(val, ratio, stats)
		elseif type(val) == "number" and Matches(key, DB.doFonts) then
			local isFont = find(key:lower(), "font", 1, true)
			if (isFont and DB.doFonts) or (not isFont and DB.doSizes) then
				local nv = Round(val * ratio)
				if isFont and nv < 8 then nv = 8 end
				t[key] = nv
				stats.sizes = stats.sizes + 1
			end
		end
	end
end

-------------------------------------------------------------------------
-- 3) Unknown tags (scan / strip). Macro "visibility" strings are skipped.
-------------------------------------------------------------------------
local function IsKnown(name)
	return Tags.Methods[name] ~= nil
end

local function TagName(tag)
	local name = tag:match("%$>(.-)<%$") or tag
	return (gsub(name, "{.-}", ""))
end

local function WalkStrings(t, path, fn)
	for k, v in pairs(t) do
		local p = path .. "." .. tostring(k)
		if type(v) == "table" then
			WalkStrings(v, p, fn)
		elseif type(v) == "string" and find(v, "[", 1, true)
			and not (type(k) == "string" and find(k:lower(), "visibility", 1, true)) then
			local nv = fn(t, k, v, p)
			if nv then t[k] = nv end
		end
	end
end

local function EachTextTree(fn)
	if E.db.unitframe then WalkStrings(E.db.unitframe, "unitframe", fn) end
	if E.db.nameplates then WalkStrings(E.db.nameplates, "nameplates", fn) end
end

function PC:ScanUnknownTags()
	local unknown, count = {}, 0
	EachTextTree(function(_, _, v, path)
		for tag in v:gmatch("%[([^%[%]]+)%]") do
			local name = TagName(tag)
			if name ~= "" and not IsKnown(name) and not unknown[name] then
				unknown[name] = path
				count = count + 1
			end
		end
	end)
	if count == 0 then
		E:Print("ScaleTagFix: no unknown tags found in unit frame / nameplate text.")
	else
		E:Print(format("ScaleTagFix: %d unknown tag(s) (send me this list to add them):", count))
		for name, path in pairs(unknown) do print(format("  [%s]  in  %s", name, path)) end
	end
end

local function StripUnknown(stats)
	EachTextTree(function(_, _, v)
		local nv = gsub(v, "%[([^%[%]]+)%]", function(tag)
			local name = TagName(tag)
			if name ~= "" and not IsKnown(name) then
				stats.stripped = stats.stripped + 1
				return ""
			end
		end)
		if nv ~= v then return nv end
	end)
end


-------------------------------------------------------------------------
-- 3b) Retail-only macro conditionals in "visibility" strings, e.g.
--     "[petbattle] hide; show"  (3.3.5 has no [petbattle])
-------------------------------------------------------------------------
local function CleanVisibility(str)
	local out = {}
	for clause in (str .. ";"):gmatch("([^;]*);") do
		local trimmed = strtrim(clause)
		if trimmed ~= "" then
			local rest, groups, anyBad, alwaysTrue = trimmed, {}, false, false
			while true do
				local inner, after = rest:match("^%s*%[([^%]]*)%](.*)$")
				if not inner then break end
				rest = after
				local keep, dropGroup = {}, false
				for tok in inner:gmatch("[^,]+") do
					local t = strtrim(tok)
					local base = (t:match("^(%a+)") or ""):lower()
					if base == "petbattle" then
						dropGroup, anyBad = true, true      -- can never be true on 3.3.5
					elseif base == "nopetbattle" then
						anyBad = true                         -- always true on 3.3.5, so drop the token
					else
						keep[#keep + 1] = t
					end
				end
				if not dropGroup then
					if #keep > 0 then groups[#groups + 1] = "[" .. table.concat(keep, ",") .. "]"
					else alwaysTrue = true end
				end
			end
			local action = strtrim(rest)
			if not anyBad then
				out[#out + 1] = trimmed
			elseif alwaysTrue then
				out[#out + 1] = action                         -- unconditional now
			elseif #groups > 0 then
				out[#out + 1] = table.concat(groups, "") .. " " .. action
			end                                                -- else: clause could never match, drop it
		end
	end
	local result = table.concat(out, "; ")
	if result == "" then result = "show" end
	return result
end
PC.CleanVisibility = CleanVisibility

local function FixPetBattle(stats)
	local function walk(t)
		for k, v in pairs(t) do
			if type(v) == "table" then
				walk(v)
			elseif type(v) == "string" and type(k) == "string" and find(k:lower(), "visibility", 1, true)
				and find(v:lower(), "petbattle", 1, true) then
				local nv = CleanVisibility(v)
				if nv ~= v then t[k] = nv; stats.petbattle = stats.petbattle + 1 end
			end
		end
	end
	for _, name in ipairs({ "actionbar", "unitframe", "nameplates", "bags", "general" }) do
		if type(E.db[name]) == "table" then walk(E.db[name]) end
	end
end

-------------------------------------------------------------------------
-- 4) Apply / Undo
-------------------------------------------------------------------------
function PC:Apply()
	local from, to = tonumber(DB.fromScale), tonumber(DB.toScale)
	if not E.db then E:Print("ScaleTagFix: no profile loaded.") return end

	DB.backup = DeepCopy(E.db) -- backup of the whole current profile
	local stats = { movers = 0, sizes = 0, stripped = 0, petbattle = 0 }

	if from and to and from > 0 and to > 0 and from ~= to then
		local ratio = from / to
		if DB.doMovers and E.db.movers then ScaleMovers(E.db.movers, ratio, stats) end
		if DB.doSizes or DB.doFonts then
			for k, v in pairs(E.db) do
				if k ~= "movers" and type(v) == "table" then ScaleWalk(v, ratio, stats) end
			end
		end
	end

	if DB.stripTags then StripUnknown(stats) end
	if DB.fixPetBattle then FixPetBattle(stats) end

	if DB.hidePetBar and E.db.actionbar and E.db.actionbar.barPet then
		E.db.actionbar.barPet.enabled = false
	end

	DB.lastRun = format("%s: %.3f -> %.3f (%d movers, %d sizes, %d tags removed, %d [petbattle] fixed)%s", date("%Y-%m-%d"),
		from or 0, to or 0, stats.movers, stats.sizes, stats.stripped, stats.petbattle, DB.hidePetBar and ", pet bar off" or "")
	E:Print("ScaleTagFix: " .. DB.lastRun .. ". Reloading...")
	ReloadUI()
end

function PC:Undo()
	if not DB.backup then E:Print("ScaleTagFix: nothing to undo.") return end
	for k in pairs(E.db) do E.db[k] = nil end
	for k, v in pairs(DB.backup) do E.db[k] = type(v) == "table" and DeepCopy(v) or v end
	DB.backup, DB.lastRun = nil, nil
	E:Print("ScaleTagFix: profile restored. Reloading...")
	ReloadUI()
end

-------------------------------------------------------------------------
-- 5) Options tab
-------------------------------------------------------------------------
local function InsertOptions()
	-- Add tag descriptions only after ElvUI_OptionsUI has finished building
	-- its option tree. Calling E:AddTagInfo during addon load can break the
	-- WotLK backport's options categories.
	for name, info in pairs(pendingTagInfo) do
		if not tagInfoAdded[name] then
			E:AddTagInfo(name, info.category, info.description)
			tagInfoAdded[name] = true
		end
	end
	pendingTagInfo = {}

	E.Options.args.scaleTagFix = {
		order = 99,
		type = "group",
		name = "Scale & Tag Fix",
		args = {
			header = { order = 1, type = "header", name = "Scale & Tag Fix" },
			info = {
				order = 2, type = "description", fontSize = "medium",
				name = "Import a profile first, pick what to fix, then press |cff1784d1Apply & Reload|r. Run once per import. A backup is saved so you can undo.",
			},
			scaleGroup = {
				order = 10, type = "group", guiInline = true, name = "UI scale",
				args = {
					fromScale = {
						order = 1, type = "input", name = "Profile was made for scale",
						desc = "Example: 0.59",
						get = function() return tostring(DB.fromScale) end,
						set = function(_, v) DB.fromScale = tonumber(v) or DB.fromScale end,
					},
					toScale = {
						order = 2, type = "input", name = "Convert to my scale",
						desc = "Example: 0.71",
						get = function() return tostring(DB.toScale) end,
						set = function(_, v) DB.toScale = tonumber(v) or DB.toScale end,
					},
					doMovers = {
						order = 3, type = "toggle", name = "Frame positions",
						get = function() return DB.doMovers end,
						set = function(_, v) DB.doMovers = v end,
					},
					doSizes = {
						order = 4, type = "toggle", name = "Frame sizes / spacing",
						get = function() return DB.doSizes end,
						set = function(_, v) DB.doSizes = v end,
					},
					doFonts = {
						order = 5, type = "toggle", name = "Font sizes (min 8)",
						get = function() return DB.doFonts end,
						set = function(_, v) DB.doFonts = v end,
					},
				},
			},
			tagGroup = {
				order = 20, type = "group", guiInline = true, name = "Tags and extras",
				args = {
					addTags = {
						order = 1, type = "toggle", name = "Add retail tags",
						desc = "classcolor, classcolor:target, reactioncolor, npctitle, name:first, name:last and ':shortvalue' spellings. Takes effect after reload.",
						get = function() return DB.addTags end,
						set = function(_, v) DB.addTags = v end,
					},
					stripTags = {
						order = 2, type = "toggle", name = "Remove tags this ElvUI can't show",
						desc = "Deletes unknown [tags] from unit frame / nameplate text so they don't show as raw text. Use 'Scan' first to see what would go.",
						get = function() return DB.stripTags end,
						set = function(_, v) DB.stripTags = v end,
					},
					hidePetBar = {
						order = 3, type = "toggle", name = "Disable pet action bar",
						get = function() return DB.hidePetBar end,
						set = function(_, v) DB.hidePetBar = v end,
					},
					fixPetBattle = {
						order = 4, type = "toggle", name = "Fix retail pet-battle visibility conditions",
						desc = "Removes the retail-only [petbattle] macro condition from profile visibility strings for WotLK 3.3.5.",
						get = function() return DB.fixPetBattle end,
						set = function(_, v) DB.fixPetBattle = v end,
					},
					scan = {
						order = 5, type = "execute", name = "Scan for unknown tags",
						desc = "Lists tags used in your unit frame / nameplate text that this ElvUI doesn't have.",
						func = function() PC:ScanUnknownTags() end,
					},
				},
			},
			actions = {
				order = 30, type = "group", guiInline = true, name = "Run",
				args = {
					last = {
						order = 0, type = "description", width = "full",
						name = function() return DB.lastRun and ("Last run: " .. DB.lastRun) or "Not run yet." end,
					},
					apply = {
						order = 1, type = "execute", name = "Apply & Reload",
						confirm = true, confirmText = "Fix the current profile and reload the UI?",
						func = function() PC:Apply() end,
					},
					undo = {
						order = 2, type = "execute", name = "Undo last run",
						disabled = function() return not DB.backup end,
						confirm = true, confirmText = "Restore the profile from before the last run?",
						func = function() PC:Undo() end,
					},
				},
			},
		},
	}
end

-- Always register as a native ElvUI options plugin; there is no standalone UI.
EP:RegisterPlugin(ADDON, InsertOptions)


-------------------------------------------------------------------------
-- Native ElvUI plugin only (no separate standalone window)
-------------------------------------------------------------------------
-------------------------------------------------------------------------
-- 6) Debug helper:  /stf keys | /stf tags on|off
-------------------------------------------------------------------------
SLASH_SCALETAGFIX1 = "/stf"
SlashCmdList["SCALETAGFIX"] = function(msg)
	local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(%S*)$")
	if cmd == "keys" then
		if not (E.Options and E.Options.args) then E:Print("ScaleTagFix: open /ec first.") return end
		local list = {}
		for k, v in pairs(E.Options.args) do
			local hid = v.hidden
			if type(hid) == "function" then
				local ok, res = pcall(hid, { options = E.Options, option = v })
				hid = ok and ("fn->" .. tostring(res)) or "fn->ERROR"
			end
			list[#list + 1] = format("%s  type=%s order=%s hidden=%s", tostring(k), tostring(v.type), tostring(v.order), tostring(hid))
		end
		table.sort(list)
		E:Print("ScaleTagFix: " .. #list .. " top-level option entries:")
		for _, line in ipairs(list) do print("  " .. line) end
	elseif cmd == "tags" and (arg == "on" or arg == "off") then
		DB.addTags = (arg == "on")
		E:Print(format("ScaleTagFix: tags %s. Type /reload to apply.", arg))
	elseif cmd == "" then
		E:Print("ScaleTagFix is an ElvUI plugin. Open /ec and select 'Scale & Tag Fix'.")
	else
		print("/stf  - show plugin location")
		print("/stf keys  - list ElvUI option tabs (open /ec first)")
		print("/stf tags on|off  - retail tags on/off (then /reload)")
	end
end
