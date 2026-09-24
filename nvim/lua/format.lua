local M = {}

function M.buffer()
	local ft = vim.bo.filetype
	if ft ~= "sh" and ft ~= "qml" then
		vim.lsp.buf.format({ async = false, timeout_ms = 5000 })
		return
	end

	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local input = table.concat(lines, "\n") .. "\n"
	local qmlformat = vim.fn.executable("/usr/lib/qt6/bin/qmlformat") == 1
		and "/usr/lib/qt6/bin/qmlformat" or "qmlformat"
	local command = ft == "sh" and { "shfmt", "-i", "1", "-ci" } or { qmlformat }
	if vim.fn.executable(command[1]) ~= 1 then
		vim.notify(command[1] .. " is not installed", vim.log.levels.ERROR)
		return
	end

	-- qmlformat accepts filenames, not stdin. Never format the on-disk buffer
	-- directly: unsaved edits must be included and the result must be undoable.
	local temporary
	if ft == "qml" then
		temporary = vim.fn.tempname() .. ".qml"
		vim.fn.writefile(lines, temporary)
		command[#command + 1] = temporary
	end
	local result = vim.system(command, { stdin = input, text = true }):wait(5000)
	if temporary then vim.fn.delete(temporary) end
	if result.code ~= 0 then
		vim.notify(result.stderr ~= "" and result.stderr or "Formatting failed", vim.log.levels.ERROR)
		return
	end

	local view = vim.fn.winsaveview()
	local formatted = vim.split(result.stdout:gsub("\n$", ""), "\n", { plain = true })
	if not vim.deep_equal(lines, formatted) then
		vim.api.nvim_buf_set_lines(0, 0, -1, false, formatted)
	end
	vim.fn.winrestview(view)
end

return M
