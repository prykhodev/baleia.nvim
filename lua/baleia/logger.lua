local nvim = require("baleia.nvim")

local function do_nothing() end

local LEVELS = {
	ERROR = { priority = 10, color = "DarkRed" },
	WARN = { priority = 20, color = "DarkYellow" },
	INFO = { priority = 30, color = "DarkGreen" },
	DEBUG = { priority = 40, color = "DarkGrey" },
}

--- @type Logger
local NULL_LOGGER = {
	show = function()
		print("Baleia logs are disabled.")
	end,
	info = do_nothing,
	warn = do_nothing,
	error = do_nothing,
	debug = do_nothing,
}

---@param hlgroup string
---@return buffer
local function create(hlgroup)
	local bufname = "baleia-log-" .. vim.fn.strftime("%s000")
	local buffer = vim.fn.bufadd(bufname)

	nvim.buffer.set_options(NULL_LOGGER, buffer, {
		modifiable = false,
		buftype = "nofile",
		bufhidden = "hide",
		swapfile = false,
	})

	for name, level in pairs(LEVELS) do
		nvim.buffer.create_highlight(NULL_LOGGER, hlgroup .. name, {
			foreground = level.color,
			ctermfg = level.color,
			bold = true,
		})
	end

	return buffer
end

---@param n integer
---@param char string
---@param text string
---@return table<string>
local function prefix(n, char, text)
	local begining = string.rep(char, n)

	local lines = {}
	for line in text:gmatch("([^\n]*)\n?") do
		if line ~= "" then
			table.insert(lines, begining .. "| " .. line)
		end
	end

	return lines
end

---@param buffer buffer
---@param name string
---@param namespace integer
---@param level string
---@param message string
---@param data table
local function raw_log(buffer, name, namespace, level, message, data)
	local start_row = nvim.buffer.last_row(buffer)
	local end_row = start_row == 0 and 1 or start_row
	local hlgroup = name .. level

	local lines = { level .. " " .. message }
	if data then
		local textlines = prefix(#level - 1, " ", vim.inspect(data))
		for _, line in ipairs(textlines) do
			table.insert(lines, line)
		end

		table.insert(lines, "")
	end

	nvim.buffer.with_options(NULL_LOGGER, buffer, { modifiable = true }, function()
		nvim.buffer.set_lines(NULL_LOGGER, buffer, start_row, end_row, true, lines)
	end)

	nvim.buffer.add_highlight(NULL_LOGGER, buffer, namespace, hlgroup, start_row, 0, #level)
	for row = start_row + 1, start_row + #lines do
		nvim.buffer.add_highlight(NULL_LOGGER, buffer, namespace, hlgroup, row, #level - 1, #level)
	end

	nvim.window.do_in(buffer, function(window)
		nvim.window.set_cursor(NULL_LOGGER, window, {
			row = start_row + #lines,
			column = 0,
		})
	end)
end

---@param buffer buffer
local function show(buffer)
	local bufname = nvim.buffer.get_name(buffer)
	nvim.execute(NULL_LOGGER, "vertical split " .. bufname)
	nvim.window.do_in(buffer, function(window)
		nvim.window.set_cursor(NULL_LOGGER, window, {
			row = nvim.buffer.last_row(buffer),
			column = 0,
		})
	end)
end

local logger = {}

-- Creates a logger that does not log anything.
--
--- @return Logger
function logger.null()
	return NULL_LOGGER
end

-- Creates a logger that logs only levels equal or more severe then {level}.
--
-- Parameters: ~
--   • {hlgroup}      Highlight group name
--   • {hlnamespace}  Highlight group namespace
--   • {level}        Log level
---@param hlgroup string
---@param hlnamespace integer
---@param level string
---@return Logger
function logger.new(hlgroup, hlnamespace, level)
	local buffer = create(hlgroup)
	local current_priority = LEVELS[level].priority

	local do_log = function(l)
		if LEVELS[l].priority > current_priority then
			return do_nothing
		end

		return function(message, data)
			vim.schedule(function()
				raw_log(buffer, hlgroup, hlnamespace, l, message, data)
			end)
		end
	end

	return {
		show = function()
			show(buffer)
		end,

		error = do_log("ERROR"),
		warn = do_log("WARN"),
		info = do_log("INFO"),
		debug = do_log("DEBUG"),
	}
end

return logger
