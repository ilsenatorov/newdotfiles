-- Minimal colorscheme wired to the matugen accent, so nvim never drifts from
-- the rest of the desktop (kitty/colors.conf, quickshell/Colors.qml, ...).
-- Background/foreground are the same hand-written values every other config
-- uses (README "Theming"): #141C21 / #93A1A1 -- only the accent is generated.

local M = {}

local base = "#141C21"
local fg = "#93A1A1"
local fg_bright = "#CDD6D6"
local dim = "#3C4449"
local muted = "#617878"

function M.apply(colors)
	vim.cmd("hi clear")
	if vim.fn.exists("syntax_on") == 1 then
		vim.cmd("syntax reset")
	end
	vim.o.background = "dark"
	vim.g.colors_name = "dots"

	local hi = function(group, opts)
		vim.api.nvim_set_hl(0, group, opts)
	end

	-- editor chrome
	hi("Normal", { fg = fg, bg = base })
	hi("NormalFloat", { fg = fg, bg = base })
	hi("SignColumn", { bg = base })
	hi("LineNr", { fg = dim })
	hi("CursorLineNr", { fg = colors.accent, bold = true })
	hi("CursorLine", { bg = "#1E262B" })
	hi("Visual", { bg = colors.accent_dim })
	hi("Search", { bg = colors.accent_dim, fg = fg_bright })
	hi("IncSearch", { bg = colors.accent, fg = base })
	hi("Pmenu", { fg = fg, bg = "#1E262B" })
	hi("PmenuSel", { bg = colors.accent_dim, fg = fg_bright })
	hi("StatusLine", { fg = fg, bg = "#1E262B" })
	hi("VertSplit", { fg = dim })
	hi("WinSeparator", { fg = dim })
	hi("Comment", { fg = muted, italic = true })
	hi("MatchParen", { fg = colors.accent, bold = true })

	-- syntax
	hi("Identifier", { fg = fg_bright })
	hi("Function", { fg = colors.accent })
	hi("Keyword", { fg = colors.accent_alt })
	hi("Statement", { fg = colors.accent_alt })
	hi("Conditional", { fg = colors.accent_alt })
	hi("Repeat", { fg = colors.accent_alt })
	hi("String", { fg = "#61C766" })
	hi("Number", { fg = "#FDD835" })
	hi("Boolean", { fg = "#FDD835" })
	hi("Constant", { fg = "#FDD835" })
	hi("Type", { fg = colors.accent, italic = true })
	hi("Special", { fg = colors.accent_alt })
	hi("Error", { fg = colors.urgent })
	hi("Todo", { fg = base, bg = colors.accent })

	-- diagnostics
	hi("DiagnosticError", { fg = colors.urgent })
	hi("DiagnosticWarn", { fg = "#FDD835" })
	hi("DiagnosticInfo", { fg = colors.accent })
	hi("DiagnosticHint", { fg = muted })

	-- diff / git
	hi("DiffAdd", { fg = "#61C766" })
	hi("DiffChange", { fg = "#FDD835" })
	hi("DiffDelete", { fg = colors.urgent })
	hi("GitSignsAdd", { fg = "#61C766" })
	hi("GitSignsChange", { fg = "#FDD835" })
	hi("GitSignsDelete", { fg = colors.urgent })
end

return M
