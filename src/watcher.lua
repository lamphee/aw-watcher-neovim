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

GROUP_ID = vim.api.nvim_create_augroup(AUTOCMD_GROUP_NAME, { clear = true })

local function post_data(url, data)
	print("posting data")
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
		GROUP_ID = vim.api.nvim_create_augroup("activity-watcher-neovim", { clear = true })
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
		}, { callback = Heartbeat, group = GROUP_ID })
	end

	create_bucket()
	create_autogroup()

	create_heartbeat_event(GROUP_ID)
end

function Heartbeat()
	local heartbeat_data = {
		timestamp = vim.fn.strftime("%FT%H:%M:%S%z"),
		duration = 0,
		data = {
			file = vim.fn.expand("%:p"),
			project = vim.fn.getcwd(),
			language = vim.fn.expand("%:e"),
		},
	}

	return post_data(API_HEARTBEAT, heartbeat_data)
end

function Stop()
	if GROUP_ID == nil then
		return false
	end
	return vim.api.nvim_del_augroup_by_id(GROUP_ID)
end

vim.api.nvim_create_user_command("AWStart", Start, {})
vim.api.nvim_create_user_command("AWStop", Stop, {})
vim.api.nvim_create_user_command("AWHeartbeat", Heartbeat, {})
