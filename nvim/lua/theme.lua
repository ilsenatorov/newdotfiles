-- Minimal colorscheme wired to the matugen output, so nvim never drifts from
-- the rest of the desktop (kitty/colors.conf, quickshell/Colors.qml, ...).
-- Every colour comes from nvim/colors.lua: the accent from the wallpaper, the
-- base/foreground/semantic colours from matugen/base.json (README "Theming").

local M = {}

function M.apply(colors)
	local base, fg, fg_bright = colors.bg, colors.fg, colors.fg_bright
	local dim, muted = colors.border, colors.muted
	local green, yellow = colors.green, colors.yellow

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
	hi("CursorLine", { bg = colors.bg_alt })
	hi("Visual", { bg = colors.accent_dim })
	hi("Search", { bg = colors.accent_dim, fg = fg_bright })
	hi("IncSearch", { bg = colors.accent, fg = base })
	hi("Pmenu", { fg = fg, bg = colors.bg_alt })
	hi("PmenuSel", { bg = colors.accent_dim, fg = fg_bright })
	hi("StatusLine", { fg = fg, bg = colors.bg_alt })
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
	hi("String", { fg = green })
	hi("Number", { fg = yellow })
	hi("Boolean", { fg = yellow })
	hi("Constant", { fg = yellow })
	hi("Type", { fg = colors.accent, italic = true })
	hi("Special", { fg = colors.accent_alt })
	hi("Error", { fg = colors.urgent })
	hi("Todo", { fg = base, bg = colors.accent })

	-- diagnostics
	hi("DiagnosticError", { fg = colors.urgent })
	hi("DiagnosticWarn", { fg = yellow })
	hi("DiagnosticInfo", { fg = colors.accent })
	hi("DiagnosticHint", { fg = muted })

	-- diff / git
	hi("DiffAdd", { fg = green })
	hi("DiffChange", { fg = yellow })
	hi("DiffDelete", { fg = colors.urgent })
	hi("GitSignsAdd", { fg = green })
	hi("GitSignsChange", { fg = yellow })
	hi("GitSignsDelete", { fg = colors.urgent })
end

return M
