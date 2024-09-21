API_URL = "127.0.0.1"
API_PORT = "5600"
API_ROUTE = "/api"

-- Add general list of possible event changes (file save, buffer change,
-- file exit and so on) and react generically on every of them (
-- mayber to create lambda parameter in generic function that will
-- send and apply changes to AW client
--
-- reference vimscript source:
-- https://github.com/ActivityWatch/aw-watcher-vim/blob/master/plugin/activitywatch.vim

function postChanges()
	return
end

function postOnExit()
	return
end
