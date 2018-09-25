-- Logging
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local log = {level = 2}

-- loglevel
-- 0 = no log message
-- 1 = error
-- 2 = warn (default)
-- 3 = info
-- 4 = debug
log.level = tonumber(os.getenv("LIVESIM2_LOGLEVEL"))
if not(log.level) or (log.level < 0 or log.level > 4) then
	log.level = tonumber((love.filesystem.read("LIVESIM2_LOGLEVEL")))
	if not(log.level) or (log.level < 0 or log.level > 4) then
		log.level = 2
	end
end

-- Default implementation
local function infoImpl(tag, text)
	io.stderr:write("I[", tag, "] ", text, "\n")
end
local function warnImpl(tag, text)
	io.stderr:write("W[", tag, "] ", text, "\n")
end
local function errorImpl(tag, text)
	io.stderr:write("E[", tag, "] ", text, "\n")
end
local function debugImpl(tag, text)
	io.stderr:write("D[", tag, "] ", text, "\n")
end

-- Codepath used if ANSI color code is supported
local function setupANSICode()
	local function m(n)
		return string.format("\27[%dm", n)
	end

	function warnImpl(tag, text)
		io.stderr:write(m(1), m(33), "W[", tag, "] ", text, m(0), "\n")
	end

	function errorImpl(tag, text)
		io.stderr:write(m(31), "E[", tag, "] ", text, m(0), "\n")
	end

	function debugImpl(tag, text)
		io.stderr:write(m(1), m(37), "D[", tag, "] ", text, m(0), "\n")
	end
end

if love._os == "Windows" then
	-- Windows can have many options depending on Windows version
	-- * if "ANSICON" environment variable is present, then ANSI color code is used
	-- * if it's possible to set VT100 mode to console (Windows 10 Anniv+), then ANSI color code is used
	-- * otherwise, use Console API for setting color (Windows 10 RTM or older)
	if os.getenv("ANSICON") then
		setupANSICode()
	else
		local hasFFI, ffi = pcall(require, "ffi")
		if hasFFI then
			local bit = require("bit")
			local Kernel32 = ffi.C -- cache namespace
			ffi.cdef [[
				// coord structure
				typedef struct logging_Coord {
					int16_t x, y;
				} logging_Coord;
				// small rect structure
				typedef struct logging_SmallRect {
					int16_t l, t, r, b;
				} logging_SmallRect;
				// CSBI structure
				typedef struct logging_CSBI {
					logging_Coord csbiSize;
					logging_Coord cursorPos;
					int16_t attributes;
					logging_SmallRect windowRect;
					logging_Coord maxWindowSize;
				} logging_CSBI;
				void * __stdcall GetStdHandle(uint32_t );
				int SetConsoleMode(void *, uint32_t );
				int GetConsoleMode(void *, uint32_t *);
				int __stdcall GetConsoleScreenBufferInfo(void *, logging_CSBI *);
				int __stdcall SetConsoleTextAttribute(void *, int16_t );
			]]
			local stderr = Kernel32.GetStdHandle(-12)

			-- Try to use VT100 processing if it's available
			-- Reference: https://bugs.php.net/bug.php?id=72768
			local cmode = ffi.new("uint32_t[1]")
			Kernel32.GetConsoleMode(stderr, cmode);
			-- Try to enable ENABLE_VIRTUAL_TERMINAL_PROCESSING (0x4)
			if Kernel32.SetConsoleMode(stderr, bit.bor(cmode[0], 4)) > 0 then
				-- ENABLE_VIRTUAL_TERMINAL_PROCESSING is supported. Use ANSI color codes
				setupANSICode()
			else
				-- ENABLE_VIRTUAL_TERMINAL_PROCESSING is not supported. Fallback to Console APIs
				local csbi = ffi.new("logging_CSBI[1]")
				local function pushMode(mode)
					Kernel32.GetConsoleScreenBufferInfo(stderr, csbi)
					local m = csbi.attributes
					Kernel32.SetConsoleTextAttribute(stderr, mode)
					return m
				end
				local function popMode(mode)
					Kernel32.SetConsoleTextAttribute(stderr, mode)
					ffi.fill(csbi, ffi.sizeof("logging_CSBI"), 0)
				end

				function warnImpl(tag, text)
					local m = pushMode(0x0004+0x0002+0x0008) -- bright yellow
					io.stderr:write("W[", tag, "] ", text, "\n")
					io.stderr:flush()
					popMode(m)
				end

				function errorImpl(tag, text)
					local m = pushMode(0x0004) -- red
					io.stderr:write("E[", tag, "] ", text, "\n")
					io.stderr:flush()
					popMode(m)
				end

				function debugImpl(tag, text)
					local m = pushMode(0x0004+0x0002+0x0001+0x0008) -- bright white
					io.stderr:write("D[", tag, "] ", text, "\n")
					io.stderr:flush()
					popMode(m)
				end
			end
		end
	end
elseif love._os == "Linux" or love._os == "OS X" then
	-- Well does macOS support this?
	setupANSICode()
elseif love._os == "Android" then
	-- Screw this, use print and hope for the best
	function infoImpl(tag, text)
		print("I["..tag.."] "..text.."\n")
	end
	function warnImpl(tag, text)
		print("W["..tag.."] "..text.."\n")
	end
	function errorImpl(tag, text)
		print("E["..tag.."] "..text.."\n")
	end
	function debugImpl(tag, text)
		print("D["..tag.."] "..text.."\n")
	end
end

function infoImplMutex(_, tag, text)
	return infoImpl(tag, text)
end

function warnImplMutex(_, tag, text)
	return warnImpl(tag, text)
end

function errorImplMutex(_, tag, text)
	return errorImpl(tag, text)
end

function debugImplMutex(_, tag, text)
	return debugImpl(tag, text)
end

local function initMutex()
	if not(log.mutex) and love.thread then
		-- Lock
		log.mutex = love.thread.getChannel("logging.lock")
	end

	return not(not(log.mutex))
end

function log.info(tag, text)
	if log.level >= 3 then
		if initMutex() then
			return log.mutex:performAtomic(infoImplMutex, tag, text)
		else
			return infoImpl(tag, text)
		end
	end
end

function log.infof(tag, text, ...)
	return log.info(tag, string.format(text, ...))
end

function log.warning(tag, text)
	if log.level >= 2 then
		if initMutex() then
			return log.mutex:performAtomic(warnImplMutex, tag, text)
		else
			return warnImpl(tag, text)
		end
	end
end
log.warn = log.warning

function log.warningf(tag, text, ...)
	return log.warning(tag, string.format(text, ...))
end
log.warnf = log.warningf

function log.error(tag, text)
	if log.level >= 1 then
		if initMutex() then
			return log.mutex:performAtomic(errorImplMutex, tag, text)
		else
			return errorImpl(tag, text)
		end
	end
end

function log.errorf(tag, text, ...)
	return log.error(tag, string.format(text, ...))
end

function log.debug(tag, text)
	if log.level >= 4 then
		if initMutex() then
			return log.mutex:performAtomic(debugImplMutex, tag, text)
		else
			return debugImpl(tag, text)
		end
	end
end

function log.debugf(tag, text, ...)
	return log.debug(tag, string.format(text, ...))
end

return log
