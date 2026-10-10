local QNAME = {
	[-1] = "Unknown",
	[0] = "Poor",
	[1] = "Common",
	[2] = "Uncommon",
	[3] = "Rare",
	[4] = "Epic",
	[5] = "Legendary",
	[6] = "Artifact",
}
local QCOLOR = {
	[-1] = "|cff9a8b78",
	[0] = "|cff9d9d9d",
	[1] = "|cffffffff",
	[2] = "|cff1eff00",
	[3] = "|cff0070dd",
	[4] = "|cffa335ee",
	[5] = "|cffff8000",
	[6] = "|cffe6cc80",
}
local SORTS = {
	{ "Item level", 3 },
	{ "Required level", 4 },
	{ "Rarity", 2 },
	{ "DPS", 10 },
	{ "Speed", 9 },
	{ "Armor", 8 },
	{ "Name", 1 },
}
local CHROME = {
	"AtlasLootDefaultFrame_Menu",
	"AtlasLootDefaultFrame_SubMenu",
	"AtlasLootDefaultFrame_Preset1",
	"AtlasLootDefaultFrame_Preset2",
	"AtlasLootDefaultFrame_Preset3",
	"AtlasLootDefaultFrame_Preset4",
	"AtlasLootDefaultFrameSearchBox",
	"AtlasLootDefaultFrameSearchButton",
	"AtlasLootDefaultFrameSearchOptionsButton",
	"AtlasLootDefaultFrameSearchClearButton",
	"AtlasLootDefaultFrameLastResultButton",
	"AtlasLootDefaultFrameWishListButton",
	"AtlasLootDefaultFrame_SelectedCategory",
	"AtlasLootDefaultFrame_SelectedTable",
	"AtlasLootDefaultFrame_Notice",
}

local showingItems = false
local qOn = {}
local matches = {}
local page = 1
local sortMode = 1
local PER = 12
local panel, rows, detail, status, pageLabel
local nameBox, effectBox
local ilMin, ilMax, rlMin, rlMax, spMin, spMax, dpsMin, dpsMax, acMin
local slotBtn, typeBtn, classBtn, statBtn, statBtn2, statMin, statMin2, sortBtn
local menu, catch
local origShowItems, origOnShow

local qi
for qi = -1, 6 do
	qOn[qi] = true
end

local function statAt(text, index)
	if not text or text == "" then return nil end
	local _, last = string.find(text, "," .. index .. ":", 1, true)
	if not last then return nil end
	local rest = string.sub(text, last + 1)
	local cut = string.find(rest, ",", 1, true)
	if cut then rest = string.sub(rest, 1, cut - 1) end
	return tonumber(rest)
end

local function readNum(edit)
	local text = edit:GetText()
	if not text or text == "" then return nil end
	return tonumber(text)
end

local function inRange(value, minv, maxv)
	if minv == nil and maxv == nil then return true end
	if value == nil or value < 0 then return false end
	if minv ~= nil and value < minv then return false end
	if maxv ~= nil and value > maxv then return false end
	return true
end

local function classOk(text, name)
	if not name or name == "" then return true end
	if not text or text == "" then return true end
	return string.find(text, "," .. name .. ",", 1, true) ~= nil
end

local function choiceText(labels, value, anyText)
	if not value or value == 0 then return anyText end
	return labels[value] or anyText
end

local function paintTabs()
	if showingItems then
		AtlasLootFilterLootButton:SetText("Loot")
		AtlasLootFilterItemsButton:SetText("|cffffd100Items|r")
	else
		AtlasLootFilterLootButton:SetText("|cffffd100Loot|r")
		AtlasLootFilterItemsButton:SetText("Items")
	end
end

local function setChrome(showLoot)
	local i
	for i = 1, getn(CHROME) do
		local frame = _G[CHROME[i]]
		if frame then
			if showLoot then frame:Show() else frame:Hide() end
		end
	end
	if showLoot then
		if AtlasLootItemsFrame and AtlasLootItemsFrame.refresh and origShowItems then
			origShowItems(AtlasLootItemsFrame.refresh[1], AtlasLootItemsFrame.refresh[2], AtlasLootItemsFrame.refresh[3])
		end
	elseif AtlasLootItemsFrame then
		AtlasLootItemsFrame:Hide()
	end
end

function AtlasLootFilter_ShowLoot()
	showingItems = false
	if menu then menu:Hide() end
	if catch then catch:Hide() end
	if panel then panel:Hide() end
	setChrome(true)
	paintTabs()
end

function AtlasLootFilter_ShowItems()
	showingItems = true
	if AtlasLootDefaultFrame and not AtlasLootDefaultFrame:IsShown() then
		AtlasLootDefaultFrame:Show()
	end
	setChrome(false)
	if panel then panel:Show() end
	paintTabs()
end

local function describe(item)
	local data = AtlasLootFilterData
	local lines = {}
	tinsert(lines, (QCOLOR[item[2]] or "|cff9a8b78") .. item[1] .. "|r")
	tinsert(lines, "Rarity: " .. (QNAME[item[2]] or "Unknown"))
	if item[3] >= 0 then tinsert(lines, "Item level: " .. item[3]) end
	if item[4] >= 0 then tinsert(lines, "Required level: " .. item[4]) end
	if item[5] > 0 then tinsert(lines, "Slot: " .. data.slot[item[5]]) end
	if item[6] > 0 then tinsert(lines, "Type: " .. data.type[item[6]]) end
	if item[7] > 0 then tinsert(lines, data.bind[item[7]]) end
	if item[13] ~= "" then tinsert(lines, "Class: " .. string.sub(item[13], 2, string.len(item[13]) - 1)) end
	if item[11] >= 0 or item[12] >= 0 then
		tinsert(lines, "Damage: " .. item[11] .. " - " .. item[12])
	end
	if item[9] >= 0 then tinsert(lines, "Speed: " .. item[9]) end
	if item[10] >= 0 then tinsert(lines, "DPS: " .. item[10]) end
	if item[8] >= 0 then tinsert(lines, "Armor: " .. item[8]) end
	local si
	for si = 1, getn(data.stat) do
		local value = statAt(item[14], si)
		if value then tinsert(lines, (data.statLabel[si] or data.stat[si]) .. " " .. value) end
	end
	if item[15] ~= "" then tinsert(lines, item[15]) end
	if item[16] > 0 then tinsert(lines, "Hover the name for the item tooltip.") end
	detail:SetText(table.concat(lines, "\n"))
end

local function showPage()
	local items = AtlasLootFilterData.item
	local total = getn(matches)
	local pages = math.ceil(total / PER)
	if pages < 1 then pages = 1 end
	if page > pages then page = pages end
	if page < 1 then page = 1 end
	status:SetText(total .. " items")
	pageLabel:SetText(page .. " / " .. pages)
	local start = (page - 1) * PER
	local i
	for i = 1, PER do
		local item = items[matches[start + i]]
		local row = rows[i]
		if item then
			local color = QCOLOR[item[2]] or "|cff9a8b78"
			local line = color .. item[1] .. "|r"
			if item[3] >= 0 then line = line .. "  |cffffd100" .. item[3] .. "|r" end
			if item[6] > 0 then line = line .. "  " .. AtlasLootFilterData.type[item[6]] end
			if item[9] >= 0 then line = line .. "  " .. item[9] .. " spd" end
			if item[10] >= 0 then line = line .. "  " .. item[10] .. " dps" end
			row.text:SetText(line)
			row.item = item
			row:Show()
		else
			row.item = nil
			row:Hide()
		end
	end
end

function AtlasLootFilter_Search()
	local data = AtlasLootFilterData
	local items = data.item
	local needle = string.lower(nameBox:GetText() or "")
	local effect = string.lower(effectBox:GetText() or "")
	local slot = slotBtn.value or 0
	local kind = typeBtn.value or 0
	local className = ""
	if classBtn.value and classBtn.value > 0 then className = data.class[classBtn.value] end
	local statA = statBtn.value or 0
	local statB = statBtn2.value or 0
	local needA = readNum(statMin)
	local needB = readNum(statMin2)
	local filters = {
		il = { readNum(ilMin), readNum(ilMax), 3 },
		rl = { readNum(rlMin), readNum(rlMax), 4 },
		sp = { readNum(spMin), readNum(spMax), 9 },
		dps = { readNum(dpsMin), readNum(dpsMax), 10 },
		ac = { readNum(acMin), nil, 8 },
	}
	matches = {}
	page = 1
	local i
	for i = 1, getn(items) do
		local item = items[i]
		if qOn[item[2]] then
			local ok = true
			if needle ~= "" and not string.find(string.lower(item[1]), needle, 1, true) then ok = false end
			if ok and effect ~= "" and not string.find(string.lower(item[15]), effect, 1, true) then ok = false end
			if ok and slot > 0 and item[5] ~= slot then ok = false end
			if ok and kind > 0 and item[6] ~= kind then ok = false end
			if ok and not classOk(item[13], className) then ok = false end
			if ok and not inRange(item[filters.il[3]], filters.il[1], filters.il[2]) then ok = false end
			if ok and not inRange(item[filters.rl[3]], filters.rl[1], filters.rl[2]) then ok = false end
			if ok and not inRange(item[filters.sp[3]], filters.sp[1], filters.sp[2]) then ok = false end
			if ok and not inRange(item[filters.dps[3]], filters.dps[1], filters.dps[2]) then ok = false end
			if ok and not inRange(item[filters.ac[3]], filters.ac[1], filters.ac[2]) then ok = false end
			if ok and statA > 0 and needA ~= nil then
				local have = statAt(item[14], statA)
				if not have or have < needA then ok = false end
			end
			if ok and statB > 0 and needB ~= nil then
				local have = statAt(item[14], statB)
				if not have or have < needB then ok = false end
			end
			if ok then tinsert(matches, i) end
		end
	end
	if sortMode ~= 1 then
		local field = SORTS[sortMode][2]
		table.sort(matches, function(a, b)
			local ia, ib = items[a], items[b]
			if field == 1 then return ia[1] < ib[1] end
			local av, bv = ia[field], ib[field]
			if av < 0 then av = -9999 end
			if bv < 0 then bv = -9999 end
			if av == bv then return ia[1] < ib[1] end
			return av > bv
		end)
	end
	if detail then detail:SetText("Click an item for its stats.") end
	showPage()
end

local function openMenu(anchor, labels)
	local count = getn(labels) + 1
	local i
	for i = 1, count do
		local button = menu.buttons[i]
		if not button then
			button = CreateFrame("Button", nil, menu)
			button:SetHeight(16)
			button:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -4 - (i - 1) * 16)
			button:SetPoint("RIGHT", menu, "RIGHT", -6, 0)
			button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			button.text:SetPoint("LEFT", button, "LEFT", 2, 0)
			button.text:SetJustifyH("LEFT")
			button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		button:SetScript("OnClick", function()
			this.owner.value = this.value
			this.owner:SetText(this.label)
			menu:Hide()
			catch:Hide()
		end)
			menu.buttons[i] = button
		end
		local value = i - 1
		local label = "Any"
		if value > 0 then label = labels[value] end
		button.owner = anchor
		button.value = value
		button.label = label
		button.text:SetText(label)
		button:Show()
	end
	if count > (menu.made or 0) then menu.made = count end
	for i = count + 1, menu.made or 0 do
		menu.buttons[i]:Hide()
	end
	menu:SetHeight(count * 16 + 8)
	menu:SetWidth(170)
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	menu:SetFrameLevel(panel:GetFrameLevel() + 30)
	catch:SetFrameLevel(panel:GetFrameLevel() + 20)
	catch:Show()
	menu:Show()
end

local function label(parent, text, x, y)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	fs:SetText(text)
	fs:SetTextColor(0.8, 0.7, 0.55)
	return fs
end

local editSeq = 0
local function editBox(parent, width, x, y)
	editSeq = editSeq + 1
	local box = CreateFrame("EditBox", "AtlasLootFilterBox" .. editSeq, parent, "InputBoxTemplate")
	box:SetAutoFocus(false)
	box:SetWidth(width)
	box:SetHeight(20)
	box:SetMaxLetters(40)
	box:SetTextInsets(2, 2, 0, 0)
	box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	box:SetScript("OnEnterPressed", function()
		this:ClearFocus()
		AtlasLootFilter_Search()
	end)
	return box
end

local pickSeq = 0
local function picker(parent, caption, x, y, labels)
	pickSeq = pickSeq + 1
	local button = CreateFrame("Button", "AtlasLootFilterPick" .. pickSeq, parent, "UIPanelButtonTemplate")
	button:SetWidth(148)
	button:SetHeight(22)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	button:SetText(caption)
	button.value = 0
	button.labels = labels
	button:SetScript("OnClick", function()
		openMenu(this, this.labels)
	end)
	return button
end

local function build()
	panel = CreateFrame("Frame", "AtlasLootFilterFrame", AtlasLootDefaultFrame)
	panel:SetPoint("TOPLEFT", AtlasLootDefaultFrame, "TOPLEFT", 12, -40)
	panel:SetPoint("BOTTOMRIGHT", AtlasLootDefaultFrame, "BOTTOMRIGHT", -12, 10)
	panel:EnableMouse(true)
	panel:SetFrameStrata("DIALOG")
	panel:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 14,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	panel:SetBackdropColor(0.07, 0.06, 0.05, 1)
	panel:Hide()

	label(panel, "Name", 16, -18)
	nameBox = editBox(panel, 180, 88, -12)
	label(panel, "Effect", 16, -52)
	effectBox = editBox(panel, 180, 88, -46)

	label(panel, "Rarity", 16, -84)
	local order = { 0, 1, 2, 3, 4, 5, 6, -1 }
	local qualityButtons = {}
	local n
	for n = 1, 8 do
		local q = order[n]
		local button = CreateFrame("Button", nil, panel)
		local col = math.mod(n - 1, 4)
		local row = math.floor((n - 1) / 4)
		button:SetWidth(66)
		button:SetHeight(18)
		button:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + col * 70, -102 - row * 20)
		button.q = q
		button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		button.text:SetPoint("LEFT", button, "LEFT", 2, 0)
		button.text:SetPoint("RIGHT", button, "RIGHT", -2, 0)
		button.text:SetJustifyH("CENTER")
		button.text:SetText(QCOLOR[q] .. QNAME[q])
		button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		button:SetScript("OnClick", function()
			qOn[this.q] = not qOn[this.q]
			if qOn[this.q] then this:SetAlpha(1) else this:SetAlpha(0.35) end
		end)
		qualityButtons[n] = button
	end

	label(panel, "Item level", 16, -158)
	ilMin = editBox(panel, 70, 88, -152)
	ilMax = editBox(panel, 70, 168, -152)
	label(panel, "Req level", 16, -192)
	rlMin = editBox(panel, 70, 88, -186)
	rlMax = editBox(panel, 70, 168, -186)
	label(panel, "Speed", 16, -226)
	spMin = editBox(panel, 70, 88, -220)
	spMax = editBox(panel, 70, 168, -220)
	label(panel, "DPS", 16, -260)
	dpsMin = editBox(panel, 70, 88, -254)
	dpsMax = editBox(panel, 70, 168, -254)
	label(panel, "Armor", 16, -294)
	acMin = editBox(panel, 70, 88, -288)

	slotBtn = picker(panel, "Any slot", 16, -328, AtlasLootFilterData.slot)
	typeBtn = picker(panel, "Any type", 16, -354, AtlasLootFilterData.type)
	classBtn = picker(panel, "Any class", 16, -380, AtlasLootFilterData.class)
	statBtn = picker(panel, "Any stat", 16, -412, AtlasLootFilterData.statLabel)
	statMin = editBox(panel, 70, 172, -410)
	statBtn2 = picker(panel, "Any stat", 16, -444, AtlasLootFilterData.statLabel)
	statMin2 = editBox(panel, 70, 172, -442)

	sortBtn = CreateFrame("Button", "AtlasLootFilterSort", panel, "UIPanelButtonTemplate")
	sortBtn:SetWidth(148)
	sortBtn:SetHeight(22)
	sortBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -478)
	sortBtn:SetText("Sort: Item level")
	sortBtn:SetScript("OnClick", function()
		sortMode = sortMode + 1
		if sortMode > getn(SORTS) then sortMode = 1 end
		this:SetText("Sort: " .. SORTS[sortMode][1])
		if getn(matches) > 0 then AtlasLootFilter_Search() end
	end)

	local search = CreateFrame("Button", "AtlasLootFilterSearch", panel, "UIPanelButtonTemplate")
	search:SetWidth(90)
	search:SetHeight(22)
	search:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -508)
	search:SetText("Search")
	search:SetScript("OnClick", AtlasLootFilter_Search)

	local reset = CreateFrame("Button", "AtlasLootFilterReset", panel, "UIPanelButtonTemplate")
	reset:SetWidth(70)
	reset:SetHeight(22)
	reset:SetPoint("LEFT", search, "RIGHT", 8, 0)
	reset:SetText("Reset")
	reset:SetScript("OnClick", function()
		nameBox:SetText("")
		effectBox:SetText("")
		ilMin:SetText("")
		ilMax:SetText("")
		rlMin:SetText("")
		rlMax:SetText("")
		spMin:SetText("")
		spMax:SetText("")
		dpsMin:SetText("")
		dpsMax:SetText("")
		acMin:SetText("")
		statMin:SetText("")
		statMin2:SetText("")
		slotBtn.value = 0
		slotBtn:SetText("Any slot")
		typeBtn.value = 0
		typeBtn:SetText("Any type")
		classBtn.value = 0
		classBtn:SetText("Any class")
		statBtn.value = 0
		statBtn:SetText("Any stat")
		statBtn2.value = 0
		statBtn2:SetText("Any stat")
		sortMode = 1
		sortBtn:SetText("Sort: Item level")
		local q
		for q = -1, 6 do qOn[q] = true end
		local k
		for k = 1, getn(qualityButtons) do
			qualityButtons[k]:SetAlpha(1)
		end
		AtlasLootFilter_Search()
	end)

	status = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	status:SetPoint("TOPLEFT", panel, "TOPLEFT", 300, -16)
	status:SetText("Press Search.")

	rows = {}
	local r
	for r = 1, PER do
		local button = CreateFrame("Button", nil, panel)
		button:SetWidth(260)
		button:SetHeight(20)
		button:SetPoint("TOPLEFT", panel, "TOPLEFT", 300, -40 - (r - 1) * 22)
		button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		button.text:SetPoint("LEFT", button, "LEFT", 4, 0)
		button.text:SetWidth(250)
		button.text:SetJustifyH("LEFT")
		button:SetScript("OnClick", function()
			if this.item then describe(this.item) end
		end)
		button:SetScript("OnEnter", function()
			if this.item and this.item[16] and this.item[16] > 0 then
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
				GameTooltip:SetHyperlink("item:" .. this.item[16] .. ":0:0:0")
				GameTooltip:Show()
			end
		end)
		button:SetScript("OnLeave", function() GameTooltip:Hide() end)
		button:Hide()
		rows[r] = button
	end

	local prev = CreateFrame("Button", "AtlasLootFilterPrev", panel, "UIPanelButtonTemplate")
	prev:SetWidth(70)
	prev:SetHeight(20)
	prev:SetPoint("TOPLEFT", panel, "TOPLEFT", 300, -312)
	prev:SetText("Prev")
	prev:SetScript("OnClick", function()
		if page > 1 then
			page = page - 1
			showPage()
		end
	end)
	local nextb = CreateFrame("Button", "AtlasLootFilterNext", panel, "UIPanelButtonTemplate")
	nextb:SetWidth(70)
	nextb:SetHeight(20)
	nextb:SetPoint("LEFT", prev, "RIGHT", 6, 0)
	nextb:SetText("Next")
	nextb:SetScript("OnClick", function()
		page = page + 1
		showPage()
	end)
	pageLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pageLabel:SetPoint("LEFT", nextb, "RIGHT", 8, 0)
	pageLabel:SetText("")

	detail = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	detail:SetPoint("TOPLEFT", panel, "TOPLEFT", 300, -348)
	detail:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)
	detail:SetJustifyH("LEFT")
	detail:SetJustifyV("TOP")
	detail:SetText("Click a result for its stats.\nHover a name for the item tooltip.")

	menu = CreateFrame("Frame", "AtlasLootFilterMenu", panel)
	menu:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	menu:SetFrameStrata("DIALOG")
	menu.buttons = {}
	menu:Hide()
	menu:SetScript("OnHide", function() if catch then catch:Hide() end end)

	catch = CreateFrame("Button", "AtlasLootFilterMenuCatch", panel)
	catch:SetAllPoints(panel)
	catch:SetScript("OnClick", function()
		menu:Hide()
		this:Hide()
	end)
	catch:Hide()
end

local function install()
	if AtlasLootFilterLootButton then return end
	local loot = CreateFrame("Button", "AtlasLootFilterLootButton", AtlasLootDefaultFrame, "UIPanelButtonTemplate")
	loot:SetWidth(72)
	loot:SetHeight(22)
	loot:SetPoint("TOPLEFT", AtlasLootDefaultFrame, "TOPLEFT", 128, -14)
	loot:SetFrameLevel(AtlasLootDefaultFrame:GetFrameLevel() + 8)
	loot:SetScript("OnClick", AtlasLootFilter_ShowLoot)

	local items = CreateFrame("Button", "AtlasLootFilterItemsButton", AtlasLootDefaultFrame, "UIPanelButtonTemplate")
	items:SetWidth(72)
	items:SetHeight(22)
	items:SetPoint("LEFT", loot, "RIGHT", 6, 0)
	items:SetFrameLevel(AtlasLootDefaultFrame:GetFrameLevel() + 8)
	items:SetScript("OnClick", AtlasLootFilter_ShowItems)

	build()
	paintTabs()

	origShowItems = AtlasLoot_ShowItemsFrame
	AtlasLoot_ShowItemsFrame = function(a, b, c)
		origShowItems(a, b, c)
		if showingItems and AtlasLootItemsFrame then
			AtlasLootItemsFrame:Hide()
		end
	end
	origOnShow = AtlasLootDefaultFrame_OnShow
	AtlasLootDefaultFrame_OnShow = function()
		origOnShow()
		if showingItems then
			setChrome(false)
			panel:Show()
		end
		paintTabs()
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function()
	if arg1 == "AtlasLootFilter" then
		install()
		this:UnregisterEvent("ADDON_LOADED")
	end
end)

SLASH_ATLASLOOTFILTER1 = "/alfilter"
SlashCmdList["ATLASLOOTFILTER"] = function()
	if not AtlasLootDefaultFrame then return end
	AtlasLootDefaultFrame:Show()
	AtlasLootFilter_ShowItems()
end
