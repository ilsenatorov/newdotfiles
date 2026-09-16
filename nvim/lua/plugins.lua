-- lazy.nvim plugin spec. Kept to what earns its keep: treesitter, LSP via
-- mason, completion, fuzzy-find (reuses fd/rg from .zshrc), git signs.
return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter").setup({
				ensure_installed = { "lua", "bash", "python", "qmljs", "json", "markdown", "vim", "vimdoc" },
				highlight = { enable = true },
				indent = { enable = true },
			})
		end,
	},

	{
		"williamboman/mason.nvim",
		config = function() require("mason").setup() end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = { "lua_ls", "bashls", "pyright" },
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = { "mason-lspconfig.nvim" },
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()
			for _, server in ipairs({ "lua_ls", "bashls", "pyright" }) do
				vim.lsp.config(server, { capabilities = capabilities })
				vim.lsp.enable(server)
			end
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
			vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover docs" })
			vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
			vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
		end,
	},

	{
		"hrsh7th/nvim-cmp",
		dependencies = { "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer", "hrsh7th/cmp-path" },
		config = function()
			local cmp = require("cmp")
			cmp.setup({
				mapping = cmp.mapping.preset.insert({
					["<C-Space>"] = cmp.mapping.complete(),
					["<CR>"] = cmp.mapping.confirm({ select = true }),
					["<Tab>"] = cmp.mapping.select_next_item(),
					["<S-Tab>"] = cmp.mapping.select_prev_item(),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "path" },
				}, {
					{ name = "buffer" },
				}),
			})
		end,
	},

	{
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local builtin = require("telescope.builtin")
			vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
			vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
			vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
			vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
		end,
	},

	{
		"lewis6991/gitsigns.nvim",
		config = function() require("gitsigns").setup() end,
	},

	{ "windwp/nvim-autopairs", config = true },

	{
		"numToStr/Comment.nvim",
		config = function()
			require("Comment").setup()
			-- <C-_> is what terminals actually send for Ctrl+/ (0x1F); kitty's
			-- keyboard protocol delivers a real <C-/>. Map both.
			for _, key in ipairs({ "<C-/>", "<C-_>" }) do
				vim.keymap.set("n", key, "gcc", { desc = "Toggle comment" })
				vim.keymap.set("v", key, "gc", { desc = "Toggle comment" })
			end
		end,
	},
}
