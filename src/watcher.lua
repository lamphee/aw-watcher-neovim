API_URL = "127.0.0.1"
API_PORT = "5600"

HOSTNAME = vim.fn.hostname()

EVENT_TYPE = "app.editor.activity"
BUCKET_NAME = "aw-watcher-nvim"
BUCKET_ID = string.format("%s_%s", BUCKET_NAME, HOSTNAME)

API_BASE = string.format("http://%s:%s/api/0", API_URL, API_PORT)
API_BUCKET = string.format("%s/buckets/%s", API_BASE, BUCKET_ID)
API_HEARTBEAT = string.format("%s/heartbeat?pulsetime=0", API_BUCKET)

AUTOCMD_GROUP_NAME = "activity-watcher-neovim"

GROUP_ID = nil

local logging_enabled = false
local log_stack = {}

-- TODO: Replace level and caller_name with opts
--
--- @param msg string - message to be logged
--- @param level? integer - logging level from vim.log.levels
--- @param caller_name? string - the function name from which it's called
--- @see debug.getinfo
local function log(msg, level, caller_name)
	if not logging_enabled then
		return
	end

	if caller_name ~= nil then
		vim.notify(string.format("* Called from: %s *", caller_name), vim.log.levels.DEBUG)
	end

	local localtime = vim.fn.strftime("%c")
	local log_msg = string.format("%s: %s", localtime, msg)

	-- TODO: Add opts param to specify boolean flag
	table.insert(log_stack, log_msg)

	vim.notify(log_msg, level)
end

--- @param url string
--- @param data table
--- @return vim.SystemObj - result of vim.system operation on 'curl'
--- @see vim.system
local function post_data(url, data)
	local post = {
		"curl",
		"-X",
		"POST",
		"--header",
		"Content-Type: application/json",
		"--header",
		"Accept: application/json",
		"--data",
		vim.fn.json_encode(data),
		url,
	}

	return vim.system(post)
end

function Start()
	local function create_bucket()
		return post_data(API_BUCKET, { client = BUCKET_NAME, hostname = HOSTNAME, type = EVENT_TYPE })
	end

	local function create_autogroup()
		GROUP_ID = vim.api.nvim_create_augroup(AUTOCMD_GROUP_NAME, { clear = true })
	end

	local function create_heartbeat_event(GROUP_ID)
		return vim.api.nvim_create_autocmd({
			"BufNewFile",
			"CursorMoved",
			"CursorMovedI",
			"ModeChanged",
			"FocusGained",
			"BufEnter",
			"CmdlineEnter",
			"CmdlineChanged",
		}, {
			callback = function(args)
				Heartbeat(args)
			end,
			group = GROUP_ID,
		})
	end

	create_bucket()
	create_autogroup()

	return create_heartbeat_event(GROUP_ID)
end

function Heartbeat(args)
	log(string.format("Recieved event [%s]", args.event), vim.log.levels.INFO, debug.getinfo(1, "n").name)

	local heartbeat_data = {
		timestamp = vim.fn.strftime("%FT%H:%M:%S%z"),
		duration = 0,
		data = {
			file = vim.fn.expand("%:p"),
			project = vim.fn.getcwd(),
			language = vim.fn.expand("%:e"),
		},
	}

	log(string.format("Sending data (%s)", table.concat(heartbeat_data)))
	--vim.notify("fuck of", vim.log.levels.DEBUG)

	return post_data(API_HEARTBEAT, heartbeat_data)
end

function Stop()
	if GROUP_ID == nil then
		log("The group is nil", vim.log.levels.INFO, debug.getinfo(1, "n").name)
		return false
	end
	GROUP_ID = vim.api.nvim_del_augroup_by_id(GROUP_ID)
	log("The group was cleared", vim.log.levels.INFO, debug.getinfo(1, "n").name)
end

function ToggleLogging()
	if logging_enabled then
		print("Enabling logging")
	else
		print("Disabling logging...")
	end
	logging_enabled = not logging_enabled
end

function ViewLogs()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, log_stack)
	vim.api.nvim_set_current_buf(buf)
end

vim.api.nvim_create_user_command("AWStart", Start, {})
vim.api.nvim_create_user_command("AWStop", Stop, {})
vim.api.nvim_create_user_command("AWHeartbeat", Heartbeat, {})
vim.api.nvim_create_user_command("AWToggleLogging", ToggleLogging, {})
vim.api.nvim_create_user_command("AWViewLogs", ViewLogs, {})
