-- Custom Beatmap Festival Beatmap Loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")
local love = require("love")
local bit = require("bit")
local util = require("util")
local log = require("logging")
local setting = require("setting")
local baseLoader = require("game.beatmap.base")

local function imageCache(link)
	return setmetatable({}, {
		__index = function(v, var)
			local val = love.image.newImageData(link[var])
			rawset(v, var, val)
			return val
		end,
		__mode = "v"
	})
end

local positionTranslate = {L4 = 9, L3 = 8, L2 = 7, L1 = 6, C = 5, R1 = 4, R2 = 3, R3 = 2, R4 = 1}
local cbfUnitIcon = imageCache {
	HONOKA_POOL = "assets/image/cbf/01_pool_unidolized_game_4.png",
	HONOKA_POOL_IDOL = "assets/image/cbf/01_pool_idolized_game_3.png",
	KOTORI_POOL = "assets/image/cbf/01_pool_unidolized_game_3.png",
	KOTORI_POOL_IDOL = "assets/image/cbf/01_pool_idolized_game_2.png",
	MAKI_CIRCUS = "assets/image/cbf/02_circus_unidolized_game.png",
	MAKI_CIRCUS_IDOL = "assets/image/cbf/02_circus_idolized_game.png",
	HANAMARU_SWIMSUIT = "assets/image/cbf/01_Swimsuit_Unidolized_game.png",
	HANAMARU_SWIMSUIT_IDOL = "assets/image/cbf/01_Swimsuit_Idolized_game.png",
	HANAMARU_INITIAL = "assets/image/cbf/01_Initial_Unidolized_game.png",
	HANAMARU_INITIAL_IDOL = "assets/image/cbf/01_Initial_Idolized_game.png",
	ELI_THIEF = "assets/image/cbf/02_thief_unidolized_game.png",
	ELI_THIEF_IDOL = "assets/image/cbf/02_thief_idolized_game.png",
	RIN_ARABIAN = "assets/image/cbf/01_arabianSet_unidolized_game.png",
	RIN_ARABIAN_IDOL = "assets/image/cbf/01_arabianSet_idolized_game.png",
	NOZOMI_IDOLSET = "assets/image/cbf/01_idolCostumeSet_unidolized_game.png",
	NOZOMI_IDOLSET_IDOL = "assets/image/cbf/01_idolCostumeSet_idolized_game.png",
	NICO_DEVIL = "assets/image/cbf/01_devil_unidolized_game.png",
	NICO_DEVIL_IDOL = "assets/image/cbf/01_devil_idolized_game.png",
	UMI_DEVIL = "assets/image/cbf/01_devil_unidolized_game_2.png",
	HANAYO_TAISHOROMAN = "assets/image/cbf/01_taishoRoman_unidolized_game.png",
	HANAYO_TAISHOROMAN_IDOL = "assets/image/cbf/01_taishoRoman_idolized_game.png",
	ELI_POOL = "assets/image/cbf/01_pool_unidolized_game.png",
	KANAN_YUKATA = "assets/image/cbf/01_yukata_unidolized_game.png",
	KANAN_YUKATA_IDOL = "assets/image/cbf/01_yukata_idolized_game.png",
	YOSHIKO_YUKATA = "assets/image/cbf/01_yukata_unidolized_game_2.png",
	YOSHIKO_YUKATA_IDOL = "assets/image/cbf/01_yukata_idolized_game_3.png",
	YOU_YUKATA = "assets/image/cbf/01_yukata_unidolized_game_3.png",
	YOU_YUKATA_IDOL = "assets/image/cbf/01_yukata_idolized_game_2.png",
	MAKI_POOL = "assets/image/cbf/01_pool_unidolized_game_2.png",
	MAKI_POOL_IDOL = "assets/image/cbf/01_pool_idolized_game.png",
	RUBY_GOTHIC = "assets/image/cbf/01_gothic_unidolized_game.png",
	RUBY_GOTHIC_IDOL = "assets/image/cbf/01_gothic_idolized_game.png",
	YOSHIKO_HALLOWEEN = "assets/image/cbf/01_halloween_unidolized_game.png",
	YOSHIKO_HALLOWEEN_IDOL = "assets/image/cbf/01_halloween_idolized_game_2.png",
	MARI_HALLOWEEN_IDOL = "assets/image/cbf/01_halloween_idolized_game.png",
	RIKO_HALLOWEEN_IDOL = "assets/image/cbf/01_halloween_idolized_game_3.png",
	HANAMARU_YUKATA = "assets/image/cbf/02_yukata_unidolized_game.png"
}

local cbfUnitIconFrame = {
	None = {
		UR = imageCache {
			"assets/image/cbf/star4circleUREmpty.png",
			"assets/image/cbf/star4foreURSmile_empty.png"
		},
		["UR (Old)"] = imageCache {
			"assets/image/cbf/star4circleURCustom_Old.png",
			"assets/image/cbf/star4foreURSmile_empty.png"
		},
		SR = imageCache {
			"assets/image/cbf/star4circleSR_Custom.png",
			"assets/image/cbf/star4circleSR_Custom_fore.png"
		},
		R = imageCache {
			"assets/image/cbf/star4circleR_Custom.png",
			"assets/image/cbf/star4circleR_Custom_fore.png"
		},
	},
	Smile = {
		UR = imageCache {
			"assets/image/cbf/star4circleURSmile.png",
			"assets/image/cbf/star4foreURSmile.png"
		},
		["UR (Old)"] = imageCache {
			"assets/image/cbf/star4circleURSmile_Old.png",
			"assets/image/cbf/star4foreURSmile.png"
		},
		SSR = imageCache {
			"assets/image/cbf/star4circleSSRSmile.png",
			"assets/image/cbf/star4foreSRSmileIdolized.png"
		},
		SR = imageCache {
			"assets/image/cbf/star4circleSRSmile.png",
			"assets/image/cbf/star4foreSRSmileIdolized.png"
		},
	},
	Pure = {
		UR = imageCache {
			"assets/image/cbf/star4circleURPure.png",
			"assets/image/cbf/star4foreURPure.png"
		},
		["UR (Old)"] = imageCache {
			"assets/image/cbf/star4circleURPure_Old.png",
			"assets/image/cbf/star4foreURPure.png"
		},
		SSR = imageCache {
			"assets/image/cbf/star4circleSSRPure.png",
			"assets/image/cbf/star4foreSRPureIdolized.png"
		},
		SR = imageCache {
			"assets/image/cbf/star4circleSRPure.png",
			"assets/image/cbf/star4foreSRPureIdolized.png"
		},
	},
	Cool = {
		UR = imageCache {
			"assets/image/cbf/star4circleURCool.png",
			"assets/image/cbf/star4foreURCool.png"
		},
		["UR (Old)"] = imageCache {
			"assets/image/cbf/star4circleURCool_Old.png",
			"assets/image/cbf/star4foreURCool.png"
		},
		SSR = imageCache {
			"assets/image/cbf/star4circleSSRCool.png",
			"assets/image/cbf/star4foreSRCoolIdolized.png"
		},
		SR = imageCache {
			"assets/image/cbf/star4circleSRCool.png",
			"assets/image/cbf/star4foreSRCoolIdolized.png"
		},
	},
}

local cbfCompositionThread = Luaoop.class("beatmap.CBF.UnitComposition")

cbfCompositionThread.code = [[
local love = require("love")
local div = love._version >= "11.0" and 1/255 or 1
require("love.image")

local dummyImage, chan = ...

-- a over b method
local function blend(ca, aa, cb, ab)
	return (ca*aa+cb*ab*(1-aa))/(aa+ab*(1-aa))
end

-- start receive
while true do
	local dst = chan:demand()
	if dst == dummyImage then return end -- done

	local astart = chan:demand()
	local aend = chan:demand()
	local imageCount = chan:demand()
	local inputs = {}

	for i = 1, imageCount do
		local t = {}
		t.image = chan:demand()
		local color = chan:demand()
		-- for sake of simplicity, use 0..1 range
		t.color = {
			(color[1] or 255) * div,
			(color[2] or 255) * div,
			(color[3] or 255) * div,
			(color[4] or 255) * div
		}
		inputs[i] = t
	end

	for i = astart, aend do
		local x = i % 128
		local y = math.floor(i / 128)
		local c = {0, 0, 0, 0}

		-- enum all images
		for _, v in ipairs(inputs) do
			local r, g, b, a = v.image:getPixel(x, y)
			r, g = r * div * v.color[1], g * div * v.color[2]
			b, a = b * div * v.color[3], a * div * v.color[4]

			-- blend
			c[1] = blend(r, a, c[1], c[4])
			c[2] = blend(g, a, c[2], c[4])
			c[3] = blend(b, a, c[3], c[4])
			c[4] = a + c[4] * (1 - a)
		end

		dst:setPixel(x, y, c[1] / div, c[2] / div, c[3] / div, c[4] / div)
	end

	chan:demand() -- dummy
end
]]

function cbfCompositionThread:__construct()
	self.threadCount = love.system.getProcessorCount()
	self.threads = {}
	self.dummyImage = love.image.newImageData(1, 1)

	for i = 1, self.threadCount do
		local t = {
			love.thread.newThread(cbfCompositionThread.code),
			love.thread.newChannel()
		}
		self.threads[i] = t
		t[1]:start(self.dummyImage, t[2])
	end
end

local function splitIntoParts(whole, parts)
	local arr = {}
	local remain = whole
	local partsLeft = parts

	while partsLeft > 0 do
		local size = math.floor((remain + partsLeft - 1) / partsLeft)
		arr[#arr + 1] = size
		remain = remain - size
		partsLeft = partsLeft - 1
	end

	return arr
end

local white = {255, 255, 255, 255}
function cbfCompositionThread:compose(decl)
	-- decl example:
	-- {ImageData, 255, 255, 255, 255}
	-- ImageData (default to white)
	local dest = love.image.newImageData(128, 128)
	local pushIn = {} -- inputs
	local chunkPerThread = splitIntoParts(128 * 128, self.threadCount)
	local parts = 0

	-- push list
	for i = 1, #decl do
		local v = decl[i]

		if type(v) == "table" then
			pushIn[#pushIn + 1] = v[1]
			pushIn[#pushIn + 1] = {v[2] or 255, v[3] or 255, v[4] or 255, v[5] or 255}
		else
			pushIn[#pushIn + 1] = v
			pushIn[#pushIn + 1] = white
		end
	end

	-- Push to thread
	for i = 1, #self.threads do
		local t = self.threads[i]

		t[2]:push(dest)
		t[2]:push(parts)
		t[2]:push(parts + chunkPerThread[i] - 1)
		t[2]:push(#decl)
		for j = 1, #pushIn do
			t[2]:push(pushIn[j])
		end
		t[2]:push(0) -- dummy

		parts = parts + chunkPerThread[i]
	end

	-- synchronize
	for i = 1, #self.threads do
		local t = self.threads[i]
		while t[2]:getCount() > 0 do
			love.timer.sleep(0.01)
		end
	end

	return dest
end

function cbfCompositionThread:__destruct()
	for i = 1, #self.threads do
		local t = self.threads[i]
		t[2]:push(self.dummyImage)
		t[1]:wait()
	end
end

do
	local inst = cbfCompositionThread()
	function cbfCompositionThread.getInstance()
		return inst
	end
end

------------------------
-- CBF Beatmap Loader --
------------------------

local cbfLoader = Luaoop.class("beatmap.CBF", baseLoader)

function cbfLoader:__construct(path)
	local internal = cbfLoader^self

	if util.fileExists(path.."projectConfig.txt") and util.fileExists(path.."beatmap.txt") then
		-- load conf
		local conf = {}
		for key, value in love.filesystem.read(path.."projectConfig.txt"):gmatch("%[([^%]]+)%];([^;]+);") do
			conf[key] = tonumber(value) or value
		end

		internal.config = conf
		internal.path = path

		-- check for unit icon loading strategy
		internal.loadUnitMethods = {
			util.directoryExist(path.."Cards"),
			util.directoryExist(path.."Custom Cards") and util.fileExists(path.."Custom Cards/list.txt")
		}
	else
		error("directory is not CBF project")
	end
end

function cbfLoader.getFormatName()
	return "Custom Beatmap Festival", "cbf"
end

local function parseNote(str)
	local values = {}
	local curidx = 1
	local nextidx = str:find("/", 1, true)

	while nextidx do
		values[#values + 1] = str:sub(curidx, nextidx - 1)
		curidx = nextidx + 1
		nextidx = str:find("/", curidx, true)
	end

	local lastval = str:sub(curidx)
	if lastval:sub(-1) == ";" then
		lastval = lastval:sub(1, -2)
	end
	values[#values + 1] = lastval

	return unpack(values)
end

function cbfLoader:getNotesList()
	local internal = cbfLoader^self
	local notesData = {}
	local attribute

	if internal.config.SONG_ATTRIBUTE == "Smile" then
		attribute = 1
	elseif internal.config.SONG_ATTRIBUTE == "Pure" then
		attribute = 2
	elseif internal.config.SONG_ATTRIBUTE == "Cool" then
		attribute = 3
	else
		attribute = setting.get("LLP_SIFT_DEFATTR")
	end

	local readNotesData = {}
	local lineCount = 1
	for line in love.filesystem.lines(internal.path.."beatmap.txt") do
		if #line > 0 then
			readNotesData[#readNotesData + 1] = line
		else
			log.warning("noteloader.cbf", string.format("empty line at line %d ignored", lineCount))
		end

		lineCount = lineCount + 1
	end

	-- sort first
	table.sort(readNotesData, function(a, b)
		return tonumber(a:match("([^/]+)/")) < tonumber(b:match("([^/]+)/"))
	end)

	-- parse (very confusing code)
	local holdNoteQueue = {}
	for _, line in ipairs(readNotesData) do
		local time, pos, _, isHold, isRel, _, _, isStar, colInfo = parseNote(line)
		local r, g, b, isCustomcol = colInfo:match("([^,]+),([^,]+),([^,]+),([True|False]+)")

		if time and pos and isHold and isRel and isStar and r and g and b and isCustomcol then
			local numPos = positionTranslate[pos]
			local attr = attribute
			time = tonumber(time)

			if isCustomcol == "True" then
				-- CBF extension attribute as explained in livesim2 beatmap spec
				attr = bit.bor(
					bit.bor(
						bit.lshift(math.floor(tonumber(r) * 255), 23),
						bit.lshift(math.floor(tonumber(g) * 255), 14)
					),
					bit.bor(bit.lshift(math.floor(tonumber(b) * 255), 5), 31)
				)
			end

			if isRel == "True" then
				local last = assert(holdNoteQueue[numPos], "unbalanced release note")
				last.effect_value = time - last.timing_sec
				holdNoteQueue[numPos] = nil
			elseif isHold == "True" then
				local val = {
					timing_sec = time,
					notes_attribute = attr,
					notes_level = 1,
					effect = 3,
					effect_value = 0,
					position = numPos
				}

				assert(holdNoteQueue[numPos] == nil, "overlapped hold note")
				holdNoteQueue[numPos] = val
				notesData[#notesData + 1] = val
			else
				notesData[#notesData + 1] = {
					timing_sec = time,
					notes_attribute = attr,
					notes_level = 1,
					effect = isStar == "True" and 4 or 1,
					effect_value = 2,
					position = numPos
				}
			end
		else
			log.warning("noteloader.cbf", "ignored: "..line)
		end
	end

	-- sort again
	table.sort(notesData, function(a, b) return a.timing_sec < b.timing_sec end)
	return notesData
end

function cbfLoader:getName()
	local internal = cbfLoader^self
	return tostring(internal.config.SONG_NAME)
end

local supportedImages = {".png", ".jpg", ".jpeg", ".bmp"}
function cbfLoader:getCoverArt()
	local internal = cbfLoader^self
	local file = util.substituteExtension(internal.path.."cover", supportedImages)

	if file then
		return {
			title = tostring(internal.config.SONG_NAME),
			info = internal.config.COVER_COMMENT,
			image = love.filesystem.newFileData(file)
		}
	end

	return nil
end

function cbfLoader:getDifficultyString()
	local internal = cbfLoader^self
	return internal.config.DIFFICULTY_TEMPLATE
end

function cbfLoader:getAudioPathList()
	local internal = cbfLoader^self
	return {internal.path.."songFile"}
end

local function getUnitByID(id, path, s1, s2)
	-- Try pre-defined one
	if cbfUnitIcon[id] then
		return cbfUnitIcon[id]
	end

	-- Try stategy 1: look at "Cards" folder for custom cards
	if s1 then
		local a = path.."Cards/"..id..".png"
		if util.fileExists(a) then
			return love.image.newImageData(a)
		end
	end

	-- Try strategy 2: look at "Custom Cards" folder
	if s2 then
		if s2[id] then
			local a = path.."Custom Cards/"..s2[id]..".png"
			if util.fileExists(a) then
				return love.image.newImageData(a)
			end
		end
	end

	-- Try current beatmap directory
	local a = path..id..".png"
	if util.fileExists(a) then
		return love.image.newImageData(a)
	end

	-- Try "unit_icon" directory
	a = "unit_icon/"..var..".png"
	if util.fileExists(a) then
		return love.image.newImageData(a)
	end

	-- nope
	return nil
end

-- implementing this one can be harder
function cbfLoader:getCustomUnitInformation()
	local internal = cbfLoader^self
	local unitData = {}

	-- TODO
	-- if util.fileExists(internal.path.."characterPositions.txt") then
	-- end

	return unitData
end

return cbfLoader, "folder"
