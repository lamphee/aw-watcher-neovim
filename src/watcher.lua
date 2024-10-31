api_url = '127.0.0.1'
api_port = '5600'

hostname = vim.fn.hostname()
event_type = 'app.editor.activity'
bucket_name = 'aw-watcher-nvim'
bucket_id = string.format('%s_%s', bucket_name, hostname)

api_base = string.format('http://%s:%s/api/0', api_url, api_port)
api_bucket = string.format('%s/buckets/%s', api_base, bucket_id)
api_heartbeat = string.format('%s/heartbeat?pulsetime=0', api_bucket)

group_id = nil

local function post_data(url, data)
	print("posting data")
	local post = {
		'curl',
		'-X', 'POST',
		'--header', 'Content-Type: application/json',
		'--header', 'Accept: application/json',
		'--data', vim.fn.json_encode(data),
		url
	}

	return vim.system(post)
end

function start()
	local function create_bucket()
		res = post_data(api_bucket,
		{client = bucket_name, hostname = hostname, type = event_type})
	end

	local function create_heartbeat_event(group_id)
		return vim.api.nvim_create_autocmd(
		{'BufNewFile', 'CursorMoved',
		'CursorMovedI', 'ModeChanged',
		'FocusGained', 'BufEnter',
		'CmdlineEnter', 'CmdlineChanged'}, { callback = heartbeat,
		group = group_id })
	end

	local function create_augroup()
		return vim.api.nvim_create_augroup('activity-watcher-neovim', {clear = false})
	end

	create_bucket()
	group_id = create_augroup()

	create_heartbeat_event(group_id)
end

function stop()
	if group_id == nil then
		return false
	end
	return vim.api.nvim_del_augroup_by_id(group_id)
end

-- Add debug prints (vim.fn.debug)
function heartbeat()
	heartbeat_data = {
		timestamp = vim.fn.strftime('%FT%H:%M:%S%z'),
		duration = 0,
		data = {
			file = vim.fn.expand('%:p'),
			project = vim.fn.getcwd(),
			language = vim.fn.expand('%:e')
		}
	}

	return post_data(api_heartbeat, heartbeat_data)
end

function debug_func(func_name)
	local function log(func)
		print(string.format("Executing func <%s>", vim.fn.string(func)))
		func()
		print(string.format("Execution of func <%s> ended", vim.fn.string({func})))
	end

	-- ??
	-- print(vim.fn.funcref(func_name))
	funcs = {
		AWStart = start,
		AWStop = stop,
		AWHeartbeat = heartbeat
	}


	ref = funcs[func_name]
	if ref == nil then
		print(string.format("Ref to <%s> is null", func_name))
		return
	end

	log(ref)
end

-- map user command to func that declares and starts autocommand
-- (autogroups for managing multiple references)
vim.api.nvim_create_user_command('AWStart', start, {})
vim.api.nvim_create_user_command('AWStop', stop, {})
vim.api.nvim_create_user_command('AWHeartbeat', heartbeat, {})

vim.api.nvim_create_user_command('AWDebug',
function(args) debug_func(args.args) end,
{nargs = 1})

