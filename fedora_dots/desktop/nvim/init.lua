-- ==========================================
-- SINGLE FILE NEOVIM CONFIG (RELZ FIXED)
-- ==========================================
-- 1. BOOTSTRAP LAZY.NVIM
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
-- 2. SETTINGS
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
-- 3. PLUGINS
require("lazy").setup({
  -- Color Scheme
  { 
    "folke/tokyonight.nvim", 
    lazy = false, 
    priority = 1000, 
    config = function() 
      vim.cmd([[colorscheme tokyonight-night]]) 
      vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
      vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
      vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
      vim.api.nvim_set_hl(0, "LineNr", { bg = "none" })
      vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "none" })
    end 
  },
  -- File Explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
    keys = { { "<leader>e", ":Neotree toggle float<CR>", desc = "Toggle Explorer" } },
  },
  -- Fuzzy Finder
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find File" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Find Text" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Find Buffer" },
    },
  },
  -- Syntax Highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local status, configs = pcall(require, "nvim-treesitter.configs")
      if not status then return end
      
      configs.setup({
        ensure_installed = { "c", "lua", "vim", "python", "bash", "json", "markdown", "markdown_inline" },
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end
  },
  -- Status Line
  { "nvim-lualine/lualine.nvim", opts = { options = { theme = "tokyonight" } } },
  -- Mason (LSP installer)
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "pyright" },
      })
    end
  },
  -- Autocompletion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
      })
    end
  },
  -- Markdown rendering
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown" },
    config = function()
      require("render-markdown").setup({
        heading = {
          enabled = true,
          icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " },
        },
        code = {
          enabled = true,
          style = "full",
        },
        bullet = {
          enabled = true,
          icons = { "●", "○", "◆", "◇" },
        },
      })
    end
  },
})
-- 4. LSP SETUP (new nvim 0.11+ API)
vim.lsp.config.pyright = {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
}
vim.lsp.enable("pyright")
-- 5. LSP KEYMAPS
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
  end,
})
-- 6. KEYMAPS
local keymap = vim.keymap.set
keymap("n", "<leader>w", ":w<CR>", { desc = "Save" })
keymap("n", "<leader>q", ":q<CR>", { desc = "Quit" })
keymap("n", "<leader>h", ":nohlsearch<CR>", { desc = "Clear highlights" })
keymap("n", "<leader>r", ":!python %<CR>", { desc = "Run Python file" })
