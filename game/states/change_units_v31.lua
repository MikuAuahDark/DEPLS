-- Change Units (v3.1)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local timer = require("libs.hump.timer")
local cubicBezier = require("libs.cubic_bezier")

local async = require("async")
local color = require("color")
local setting = require("setting")
local util = require("util")
local mainFont = require("font")
local lily = require("lily")
local L = require("language")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local backgroundLoader = require("game.background_loader")

local glow = require("game.afterglow")
local ciButton = require("game.ui.circle_icon_button")

local mipmap = {mipmaps = true}
local materialInterpolation = cubicBezier(0.4, 0.0, 0.2, 1):getFunction()

local changeUnits = gamestate.create {
	images = {
		dummyUnit = {"assets/image/dummy.png", mipmap},
		navigateBack = {"assets/image/ui/over_the_rainbow/navigate_back.png", mipmap},
		keyboard = {"assets/image/ui/over_the_rainbow/keyboard.png", mipmap},
		save = {"assets/image/ui/over_the_rainbow/save.png", mipmap},
		revert = {"assets/image/ui/over_the_rainbow/revert.png", mipmap},
		unit = {"assets/image/ui/over_the_rainbow/perm_identity_24px.png", mipmap}
	},
	fonts = {},
	audios = {}
}

local idolPosition = {
	{816, 96 },
	{785, 249},
	{698, 378},
	{569, 465},
	{416, 496},
	{262, 465},
	{133, 378},
	{46 , 249},
	{16 , 96 },
}

local RECT_BLUR_OVERLAY = {250, 121, 460, 256}

local unmapableKeys = {
	-- Navigation Keys
	"up", "down", "left", "right",
	"home", "end",
	"pageup", "pagedown",
	-- Editing Keys
	"insert",
	"backspace",
	"tab",
	"clear",
	"return",
	"delete",
	-- Function Keys (some used specially by game)
	"f1", "f2", "f3", "f4",
	"f5", "f6", "f7", "f8",
	"f9", "f10", "f11", "f12",
	"f13", "f14", "f15", "f16",
	-- Modifier keys
	"numlock",
	"capslock",
	"scrolllock",
	"rshift", "lshift",
	"rctrl", "lctrl",
	"ralt", "lalt",
	"rgui", "lgui",
	"mode",
	-- Application Keys
	"www",
	"mail",
	"calculator",
	"computer",
	"appsearch",
	"apphome",
	"appback",
	"appforward",
	"apprefresh",
	"appbookmarks",
	-- Misc. Keys
	"pause",
	"escape",
	"help",
	"printscreen",
	"sysreq",
	"menu",
	"application",
	"power",
	"currencyunit",
	"undo",
}

local function showUnitList(self)
	for i = 1, 9 do
		local x = idolPosition[i]
		glow.addElement(self.data.dummyButtons[i], x[1], x[2])
	end
end

local function hideUnitList(self)
	for i = 1, 9 do
		glow.removeElement(self.data.dummyButtons[i])
	end
end

local function showSaveRevertButton(self)
	glow.addFixedElement(self.data.saveButton, 731, 524)
	glow.addFixedElement(self.data.revertButton, 827, 524)
	glow.addFixedElement(self.data.modeButton, 700, 4)
end

local function hideSaveRevertButton(self)
	glow.removeElement(self.data.saveButton)
	glow.removeElement(self.data.revertButton)
	glow.removeElement(self.data.modeButton)
end

local function applySetting(_, self)
	local uval, kval = {}, {}

	for i = 9, 1, -1 do
		uval[#uval + 1] = self.persist.unitList[i]
		kval[#kval + 1] = self.persist.keymap[i]
		self.persist.currentUnitList[i] = self.persist.unitList[i]
		self.persist.currentKeymap[i] = self.persist.keymap[i]
	end

	setting.set("IDOL_IMAGE", table.concat(uval, "\t"))
	setting.set("IDOL_KEYS", table.concat(kval, "\t"))
end

local function revertSetting(_, self)
	for i = 1, 9 do
		local unit = self.persist.currentUnitList[i]
		self.persist.unitList[i] = unit
		self.persist.keymap[i] = self.persist.currentKeymap[i]
		self.data.dummyButtons[i]:setImage(self.persist.unitImageList[unit])
	end
end

local function constructCenteredText(font, text)
	local t = love.graphics.newText(font)
	local h = font:getHeight()

	-- Text has horizontal padding of 32
	local textarea = RECT_BLUR_OVERLAY[3] - 64
	local wrap = select(2, font:getWrap(text, textarea))

	t:addf(
		text, textarea, "center",
		32 + RECT_BLUR_OVERLAY[1],
		(RECT_BLUR_OVERLAY[4] - #wrap * h) * 0.5 + RECT_BLUR_OVERLAY[2]
	)
	return t
end

local function updateCurrentMode(text, button, img, mode)
	if mode == "units" then
		mode = L"changeUnits:unitsMode"
	elseif mode == "keymap" then
		mode = L"changeUnits:keymapMode"
	else
		error("invalid mode")
	end

	text:clear()
	text:add(mode)
	button:setImage(img, 0.24)
end

local function setMode(_, self)
	local mimg

	if self.persist.mode == "units" then
		self.persist.mode = "keymap"
		mimg = self.assets.images.unit

		self.persist.timer:clear()
		self.persist.timer:tween(0.2, self.persist, {keymapOpacity = 1}, materialInterpolation)
	elseif self.persist.mode == "keymap" then
		self.persist.mode = "units"
		mimg = self.assets.images.keyboard

		self.persist.timer:clear()
		self.persist.timer:tween(0.2, self.persist, {keymapOpacity = 0}, materialInterpolation)
	else
		error("invalid mode")
	end

	updateCurrentMode(self.data.modeText, self.data.modeButton, mimg, self.persist.mode)
end

local function tryLeave(_, self)
	if self.persist.selectUnits > 0 then
		glow.removeFrame(self.persist.unitSelectFrame)
		self.persist.selectUnits = -1
		showUnitList(self)
		showSaveRevertButton(self)
	elseif self.persist.keymapIndex > 0 then
		self.persist.timer:clear()
		self.persist.timer:tween(0.2, self.persist, {keymapOverlayOpacity = 0}, materialInterpolation)
		self.persist.timer:after(0.2, function()
			showUnitList(self)
			showSaveRevertButton(self)
		end)
		self.persist.keymapIndex = -1
	else
		-- Check settings
		local isChanged = false

		for i = 1, 9 do
			if
				self.persist.keymap[i] ~= self.persist.currentKeymap[i] or
				self.persist.unitList[i] ~= self.persist.currentUnitList[i]
			then
				isChanged = true
				break
			end
		end

		if isChanged then
			local buttons = {
				L"dialog:no",
				L"dialog:yes",
				L"dialog:cancel",
				enterbutton = 2,
				exitbutton = 1
			}
			local r = love.window.showMessageBox(L"menu:changeUnits", L"changeUnits:exitConfirm", buttons, "warning")

			if r == 2 then
				applySetting(nil, self)
			elseif r == 3 then
				-- don't let it enter gamestate.leave
				return
			end
		end

		gamestate.leave(loadingInstance.getInstance())
	end
end

local function stencilTextPlacement()
	return love.graphics.rectangle(
		"fill",
		RECT_BLUR_OVERLAY[1],
		RECT_BLUR_OVERLAY[2],
		RECT_BLUR_OVERLAY[3],
		RECT_BLUR_OVERLAY[4]
	)
end

local function changeUnit(_, data)
	local self = data[1]
	local index = data[2]

	if self.persist.mode == "units" then
		self.persist.selectUnits = index
		glow.addFrame(self.persist.unitSelectFrame)
		hideUnitList(self)
		hideSaveRevertButton(self)
	elseif self.persist.mode == "keymap" then
		self.persist.keymapIndex = index

		self.persist.timer:clear()
		self.persist.timer:tween(0.2, self.persist, {keymapOverlayOpacity = 1}, materialInterpolation)
		hideUnitList(self)
		hideSaveRevertButton(self)
	end
end

local function selectedNewUnit(_, data)
	local self = data[1]

	if self.persist.selectUnits > 0 then
		local val = data[2]
		glow.removeFrame(self.persist.unitSelectFrame)
		showUnitList(self)
		showSaveRevertButton(self)
		self.persist.unitList[self.persist.selectUnits] = val[2]
		self.data.dummyButtons[self.persist.selectUnits]:setImage(val[3])
		self.persist.selectUnits = -1
	end
end

function changeUnits:load()
	local centeredInfoFont
	glow.clear()

	local function loadCenteredInfoFont()
		if not(centeredInfoFont) then
			centeredInfoFont = mainFont.get(18)
		end
	end

	if self.data.textShader == nil then
		self.data.textShader = love.graphics.newShader([[
			vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
			{
				return color * vec4(1.0, 1.0, 1.0, Texel(tex, tc).a);
			}
		]])
	end

	if self.data.titleText == nil then
		local f = mainFont.get(31)
		local t = love.graphics.newText(f)
		local l = L"menu:changeUnits"
		t:add(l, -0.5 * f:getWidth(l), 0)
		self.data.titleText = t
	end

	if self.data.keymapTitleText == nil then
		local f = mainFont.get(31)
		local t = love.graphics.newText(f)
		local l = L"changeUnits:keymapTitle"
		t:add(l, -0.5 * f:getWidth(l), 0)
		self.data.keymapTitleText = t
	end

	if self.data.keymapFont == nil then
		self.data.keymapFont = mainFont.get(18)
	end

	if self.data.changeUnitText == nil then
		loadCenteredInfoFont()
		self.data.changeUnitText = constructCenteredText(centeredInfoFont, L"changeUnits:unitsDesc")
	end

	if self.data.selectUnitsText == nil then
		self.data.selectUnitsText = love.graphics.newText(mainFont.get(31))
		self.data.selectUnitsText:add({color.hexFF4FAE, L"changeUnits:selectUnits"})
	end

	if self.data.keymapText == nil then
		loadCenteredInfoFont()
		self.data.keymapText = constructCenteredText(centeredInfoFont, L"changeUnits:keymapDesc")
	end

	if self.data.keymapSelectText == nil then
		loadCenteredInfoFont()
		self.data.keymapSelectText = constructCenteredText(centeredInfoFont, L"changeUnits:keymapSelectDesc")
	end

	if self.data.modeText == nil then
		loadCenteredInfoFont()
		self.data.modeText = love.graphics.newText(centeredInfoFont)
	end

	if self.data.modeButton == nil then
		self.data.modeButton = ciButton(color.hexFF4FAE, 36)
		self.data.modeButton:addEventListener("mousereleased", setMode)
		self.data.modeButton:setData(self)
	end
	glow.addFixedElement(self.data.modeButton, 700, 4)

	if self.data.saveButton == nil then
		self.data.saveButton = ciButton(color.hexFF4FAE, 45, self.assets.images.save, 0.16)
		self.data.saveButton:setShadow(32, math.pi, 6)
		self.data.saveButton:addEventListener("mousereleased", applySetting)
		self.data.saveButton:setData(self)
	end
	glow.addFixedElement(self.data.saveButton, 731, 524)

	if self.data.revertButton == nil then
		self.data.revertButton = ciButton(color.hexFF6854, 45, self.assets.images.revert, 0.16)
		self.data.revertButton:setShadow(32, math.pi, 6)
		self.data.revertButton:addEventListener("mousereleased", revertSetting)
		self.data.revertButton:setData(self)
	end
	glow.addFixedElement(self.data.revertButton, 827, 524)

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end

	-- Setup unit formation
	if self.data.dummyButtons == nil then
		local dummy = self.assets.images.dummyUnit
		self.data.dummyButtons = {
			ciButton(color.transparent, 64, dummy),
			ciButton(color.transparent, 64, dummy),
			ciButton(color.transparent, 64, dummy),
			ciButton(color.transparent, 64, dummy),
			ciButton(color.transparent, 64, dummy),
			ciButton(color.transparent, 64, dummy),
			ciButton(color.transparent, 64, dummy),
			ciButton(color.transparent, 64, dummy),
			ciButton(color.transparent, 64, dummy)
		}
	end
	for i = 1, 9 do
		local x = idolPosition[i]
		self.data.dummyButtons[i]:setData({self, i})
		self.data.dummyButtons[i]:addEventListener("mousereleased", changeUnit)
		glow.addElement(self.data.dummyButtons[i], x[1], x[2])
	end

	-- Nice effect but I usually used this sparingly
	if self.data.blurFramebuffer == nil then
		local c1, c2 = util.newCanvas(480, 320), util.newCanvas(480, 320)
		local s = love.graphics.newShader([[
			const vec2 resolution = vec2(1024.0, 1024.0);
			extern vec2 dir;

			// https://github.com/Jam3/glsl-fast-gaussian-blur
			vec4 blur9(Image image, vec2 uv, vec2 direction) {
				vec4 color = vec4(0.0);
				vec2 off1 = vec2(1.3846153846) * direction;
				vec2 off2 = vec2(3.2307692308) * direction;
				color += texture2D(image, uv) * 0.2270270270;
				color += texture2D(image, uv + (off1 / resolution)) * 0.3162162162;
				color += texture2D(image, uv - (off1 / resolution)) * 0.3162162162;
				color += texture2D(image, uv + (off2 / resolution)) * 0.0702702703;
				color += texture2D(image, uv - (off2 / resolution)) * 0.0702702703;
				return color;
			}

			vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
			{
				return blur9(tex, tc, dir) * color;
			}
		]])

		love.graphics.push("all")
		love.graphics.setColor(color.white)
		love.graphics.setCanvas(c1)
		love.graphics.clear()
		love.graphics.origin()
		love.graphics.setShader(s)
		s:send("dir", {1.5, 0});
		love.graphics.draw(self.data.background, 0, 0, 0, 0.5, 0.5)
		love.graphics.setCanvas(c2)
		love.graphics.clear()
		love.graphics.draw(c1)
		love.graphics.setCanvas(c1)
		love.graphics.clear()
		s:send("dir", {0, 1.5})
		love.graphics.draw(c2)
		love.graphics.setCanvas(c2)
		love.graphics.clear()
		love.graphics.draw(c1)
		love.graphics.setCanvas(c1)
		love.graphics.clear()
		love.graphics.draw(c2)
		love.graphics.pop()
		util.releaseObject(c2)
		util.releaseObject(s)
		self.data.blurFramebuffer = c1
	end

	if self.data.shadowGradient == nil then
		self.data.shadowGradient = util.gradient("vertical", color.black75PT, color.transparent)
	end

	if self.data.back == nil then
		self.data.back = ciButton(color.hexFF4FAE, 36, self.assets.images.navigateBack, 0.24)
		self.data.back:setData(self)
		self.data.back:addEventListener("mousereleased", tryLeave)
	end
	glow.addFixedElement(self.data.back, 32, 4)

	-- Units loading
	if self.persist.unitImageList == nil then
		local unitImageList = setmetatable({}, {
			__index = function()
				return self.assets.images.dummyUnit
			end
		})

		-- scan directory
		local unitLoad = {}
		local unitFilename = {}
		for _, file in ipairs(love.filesystem.getDirectoryItems("unit_icon")) do
			local path = "unit_icon/"..file
			if file:sub(-4) == ".png" and util.fileExists(path) then
				unitLoad[#unitLoad + 1] = {lily.newImage, path, mipmap}
				unitFilename[#unitFilename + 1] = file
			end
		end

		-- load (cannot use assetCache because it caches the image)
		local unitImage = lily.loadMulti(unitLoad)
		async.syncLily(unitImage):sync()

		local j = 1
		for i = 1, #unitFilename do
			local image = unitImage:getValues(i)
			local w, h = image:getDimensions()
			if w == 128 and h == 128 then
				local img = unitImage:getValues(i)
				unitImageList[unitFilename[i]] = img
				unitImageList[#unitImageList + 1] = {j, unitFilename[i], img}
				j = j + 1
			end
		end

		self.persist.unitImageList = unitImageList
	end
end

function changeUnits:start()
	self.persist.currentUnitList = {}
	self.persist.unitList = {}
	self.persist.currentKeymap = {}
	self.persist.keymap = {}
	self.persist.keymapIndex = -1
	self.persist.mode = "units"
	self.persist.selectUnits = -1
	self.persist.timer = timer.new()
	self.persist.keymapOpacity = 0
	self.persist.keymapOverlayOpacity = 0
	self.persist.keymapHighlightTime = 0

	updateCurrentMode(self.data.modeText, self.data.modeButton, self.assets.images.keyboard, self.persist.mode)

	-- load unit image name
	do
		local i = 9
		for w in setting.get("IDOL_IMAGE"):gmatch("[^\t]+") do
			self.persist.unitList[i] = w
			self.persist.currentUnitList[i] = w
			self.data.dummyButtons[i]:setImage(self.persist.unitImageList[w])
			i = i - 1
		end

		assert(i == 0, "improper idol image setting")
	end

	-- load keymap
	do
		local i = 9
		for w in setting.get("IDOL_KEYS"):gmatch("[^\t]+") do
			self.persist.keymap[i] = w
			self.persist.currentKeymap[i] = w
			i = i - 1
		end

		assert(i == 0, "improper keymap setting")
	end

	-- load unit select frame
	local frame = glow.frame(77, 266, 856, 372)
	for i, v in ipairs(self.persist.unitImageList) do
		local x = (i - 1) % 7
		local y = math.floor((i - 1) / 7)
		local button = ciButton(color.transparent, 54, v[3], 108/128)
		button:setData({self, v})
		button:addEventListener("mousereleased", selectedNewUnit)
		frame:addElement(button, x * 117, y * 117)
	end
	self.persist.unitSelectFrame = frame
end

function changeUnits:update(dt)
	self.persist.timer:update(dt)
	self.persist.unitSelectFrame:update(dt)

	if self.persist.keymapIndex > 0 then
		self.persist.keymapHighlightTime = (self.persist.keymapHighlightTime + dt) % 2
	end
end

function changeUnits:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.data.shadowGradient, -88, 77, 0, 1136, 8)
	love.graphics.setColor(color.hexFF4FAE)
	love.graphics.rectangle("fill", -88, 0, 1136, 80)
	love.graphics.setColor(color.white)
	love.graphics.setShader(self.data.textShader)
	if self.persist.mode == "units" then
		love.graphics.draw(self.data.titleText, 480, 24)
	elseif self.persist.mode == "keymap" then
		love.graphics.draw(self.data.keymapTitleText, 480, 24)
	end
	love.graphics.setShader()
	glow.draw()

	if self.persist.selectUnits > 0 then
		love.graphics.setColor(color.white)
		love.graphics.rectangle("fill", 26, 141, 908, 498)
		love.graphics.draw(self.data.selectUnitsText, 78, 177)
		self.persist.unitSelectFrame:draw()
	else
		love.graphics.setColor(color.white)

		if self.persist.keymapIndex <= 0 then
			love.graphics.draw(self.data.modeText, 780, 32)
		end

		if self.persist.keymapOpacity > 0 then
			if self.persist.keymapOverlayOpacity > 0 then
				-- Draw dummy units
				love.graphics.setColor(color.white)
				for i = 1, 9 do
					if i ~= self.persist.keymapIndex then
						local x = idolPosition[i]
						love.graphics.draw(self.persist.unitImageList[self.persist.unitList[i]], x[1], x[2])
					end
				end
			end

			-- Show key overlay
			love.graphics.setColor(color.compat(60, 57, 57, self.persist.keymapOpacity))

			for i = 1, 9 do
				if i ~= self.persist.keymapIndex then
					local x = idolPosition[i]
					love.graphics.rectangle("fill", x[1] - 5, x[2] + 88, 138, 32, 14, 14)
					love.graphics.rectangle("line", x[1] - 5, x[2] + 88, 138, 32, 14, 14)
				end
			end

			-- Show key text
			-- It's better to use love.graphics.printf(text, Font) variant here
			-- but that variant is only supported in 11.0 and later
			love.graphics.setFont(self.data.keymapFont)
			love.graphics.setColor(color.compat(255, 255, 255, self.persist.keymapOpacity))
			local h = self.data.keymapFont:getHeight() * 0.5
			for i = 1, 9 do
				if i ~= self.persist.keymapIndex then
					local x = idolPosition[i]
					local key = self.persist.keymap[i]
					love.graphics.printf(key:upper(), x[1] - 5, x[2] + 104 - h, 138, "center")
				end
			end

			if self.persist.keymapIndex > 0 then
				-- Draw gray rectangle
				love.graphics.setColor(color.compat(70, 69, 69, self.persist.keymapOverlayOpacity * 0.65))
				love.graphics.rectangle("fill", -88, -43, 1136, 726)

				-- Highlight the current selected unit
				local i = self.persist.keymapIndex
				local x = idolPosition[i]

				love.graphics.setColor(color.white)
				love.graphics.draw(self.persist.unitImageList[self.persist.unitList[i]], x[1], x[2])
				love.graphics.setColor(color.compat(60, 57, 57, self.persist.keymapOpacity))
				love.graphics.rectangle("fill", x[1] - 5, x[2] + 88, 138, 32, 14, 14)
				love.graphics.rectangle("line", x[1] - 5, x[2] + 88, 138, 32, 14, 14)
				love.graphics.setColor(color.compat(255, 255, 255, math.abs(1 - self.persist.keymapHighlightTime)))
				love.graphics.printf("PRESS KEY", x[1] - 5, x[2] + 104 - h, 138, "center")
			end
		end

		if self.persist.keymapOverlayOpacity < 1 then
			love.graphics.setColor(color.white)
			love.graphics.stencil(stencilTextPlacement, "replace", 2, true)
			love.graphics.setStencilTest("equal", 2)
			love.graphics.draw(self.data.blurFramebuffer, 0, 0, 0, 2, 2)
			love.graphics.setColor(color.compat(53, 53, 53, 0.5 + self.persist.keymapOverlayOpacity * 0.5))
			love.graphics.setStencilTest()
			stencilTextPlacement()
		else
			love.graphics.setColor(color.hex353535)
			stencilTextPlacement()
		end

		love.graphics.setColor(color.white)
		if self.persist.keymapIndex > 0 then
			love.graphics.draw(self.data.keymapSelectText)
		elseif self.persist.mode == "keymap" then
			love.graphics.draw(self.data.keymapText)
		else
			love.graphics.draw(self.data.changeUnitText)
		end
	end
end

changeUnits:registerEvent("keyreleased", function(self, key)
	if key == "escape" then
		tryLeave(nil, self)
	elseif self.persist.keymapIndex > 0 then
		-- unmappable keys means "cancel"
		for i = 1, #unmapableKeys do
			if unmapableKeys[i] == key then
				tryLeave(nil, self)
				return
			end
		end

		-- Key is mappable
		local kmap = self.persist.keymap
		-- check if it's same key
		if kmap[self.persist.keymapIndex] == key then
			-- cancel
			tryLeave(nil, self)
			return
		end

		-- Check if this key is already used by different unit
		for i = 1, 9 do
			if kmap[i] == key then
				-- swap keys
				kmap[i], kmap[self.persist.keymapIndex] = kmap[self.persist.keymapIndex], kmap[i]
				tryLeave(nil, self)
				return
			end
		end

		-- It's not used anywhere. Assign.
		kmap[self.persist.keymapIndex] = key
		tryLeave(nil, self)
	end
end)

return changeUnits