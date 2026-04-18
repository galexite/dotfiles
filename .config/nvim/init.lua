-- =============================================================================
-- init.lua — Neovim configuration
-- Package manager : lazy.nvim
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Leader key (must be set before lazy / any plugin loads)
-- ---------------------------------------------------------------------------
vim.g.mapleader      = " "
vim.g.maplocalleader = " "

-- ---------------------------------------------------------------------------
-- 2. Bootstrap lazy.nvim
-- ---------------------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ---------------------------------------------------------------------------
-- 3. Plugin specifications
-- ---------------------------------------------------------------------------
require("lazy").setup({

  -- -------------------------------------------------------------------------
  -- which-key: display available keybindings in a popup
  -- -------------------------------------------------------------------------
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",   -- "classic" | "modern" | "helix"
      delay  = 300,        -- ms before popup appears
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)

      -- Register top-level group prefixes so the popup is more descriptive
      wk.add({
        { "<leader>c", group = "code / lsp" },
        { "<leader>f", group = "find"       },
        { "<leader>g", group = "git"        },
        { "<leader>w", group = "workspace"  },
      })
    end,
  },

  -- -------------------------------------------------------------------------
  -- nvim-cmp: completion engine + sources
  -- -------------------------------------------------------------------------
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",   -- LSP completions
      "hrsh7th/cmp-buffer",     -- words in current buffer
      "hrsh7th/cmp-path",       -- filesystem paths
      "hrsh7th/cmp-cmdline",    -- : and / command-line completions
    },
    config = function()
      local cmp = require("cmp")

      -- Helper: check whether there are words before the cursor (for <Tab>)
      local has_words_before = function()
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        return col ~= 0
          and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
               :sub(col, col)
               :match("%s") == nil
      end

      cmp.setup({
        -- No snippet engine required — remove this block if you add one later
        snippet = {
          expand = function(args)
            -- Fallback: expand with the built-in snippet engine (Neovim 0.10+)
            vim.snippet.expand(args.body)
          end,
        },

        window = {
          completion    = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },

        mapping = cmp.mapping.preset.insert({
          ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
          ["<C-f>"]     = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"]     = cmp.mapping.abort(),
          ["<CR>"]      = cmp.mapping.confirm({ select = false }),

          -- <Tab> to select next item, <S-Tab> for previous
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif has_words_before() then
              cmp.complete()
            else
              fallback()
            end
          end, { "i", "s" }),

          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),

        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "path"     },
        }, {
          { name = "buffer", keyword_length = 3 },
        }),

        formatting = {
          format = function(entry, item)
            -- Show the completion source in the menu column
            local source_labels = {
              nvim_lsp = "[LSP]",
              buffer   = "[Buf]",
              path     = "[Path]",
              cmdline  = "[Cmd]",
            }
            item.menu = source_labels[entry.source.name] or ""
            return item
          end,
        },
      })

      -- `/` search-mode completions (current buffer words)
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })

      -- `:` command-line completions (paths + vim commands)
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources(
          { { name = "path"    } },
          { { name = "cmdline" } }
        ),
      })
    end,
  },

  -- -------------------------------------------------------------------------
  -- nvim-lspconfig: ships default LSP server configs that vim.lsp.config
  -- extends. The lspconfig *module* is deprecated — we use the new
  -- vim.lsp.config() / vim.lsp.enable() API (Neovim 0.11+) instead.
  -- -------------------------------------------------------------------------
  {
    "neovim/nvim-lspconfig",
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local cmp_lsp = require("cmp_nvim_lsp")

      -- Extend the default Neovim LSP capabilities with cmp completions.
      -- Applied globally via vim.lsp.config('*', ...) so every server picks
      -- them up without needing to be listed individually.
      local capabilities = cmp_lsp.default_capabilities()

      vim.lsp.config("*", {
        capabilities = capabilities,
      })

      -- -----------------------------------------------------------------------
      -- Python — pyright
      -- Install: pip install pyright  OR  npm i -g pyright
      -- -----------------------------------------------------------------------
      vim.lsp.config("pyright", {
        settings = {
          python = {
            analysis = {
              typeCheckingMode       = "basic",
              autoSearchPaths        = true,
              useLibraryCodeForTypes = true,
            },
          },
        },
      })

      -- -----------------------------------------------------------------------
      -- Deno (TypeScript / JavaScript via Deno's built-in LSP)
      -- Install: https://deno.land/#installation
      -- Note: restrict root_markers so it won't attach in Node projects.
      -- -----------------------------------------------------------------------
      vim.lsp.config("denols", {
        root_markers = { "deno.json", "deno.jsonc" },
        settings = {
          deno = {
            enable  = true,
            suggest = { imports = { hosts = { ["https://deno.land"] = true } } },
          },
        },
      })

      -- -----------------------------------------------------------------------
      -- C / C++ — clangd
      -- Install: apt install clangd  /  brew install llvm  /  winget …
      -- -----------------------------------------------------------------------
      vim.lsp.config("clangd", {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--completion-style=detailed",
          "--function-arg-placeholders",
        },
      })

      -- -----------------------------------------------------------------------
      -- Rust — rust-analyzer
      -- Install: rustup component add rust-analyzer
      -- -----------------------------------------------------------------------
      vim.lsp.config("rust_analyzer", {
        settings = {
          ["rust-analyzer"] = {
            checkOnSave = { command = "clippy" },
            cargo       = { allFeatures = true },
            procMacro   = { enable = true },
          },
        },
      })

      -- -----------------------------------------------------------------------
      -- Enable the configured servers. vim.lsp.enable() registers them so
      -- Neovim will auto-start them based on filetype / root_markers.
      -- -----------------------------------------------------------------------
      vim.lsp.enable({ "pyright", "denols", "clangd", "rust_analyzer" })

      -- -----------------------------------------------------------------------
      -- LspAttach autocmd: set up buffer-local keymaps whenever a server
      -- attaches. This replaces the old per-server `on_attach` callback.
      -- -----------------------------------------------------------------------
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
        callback = function(args)
          local bufnr = args.buf
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
          end

          -- Navigation
          map("gd",         vim.lsp.buf.definition,      "Go to Definition")
          map("gD",         vim.lsp.buf.declaration,     "Go to Declaration")
          map("gi",         vim.lsp.buf.implementation,  "Go to Implementation")
          map("gr",         vim.lsp.buf.references,      "List References")
          map("K",          vim.lsp.buf.hover,           "Hover Documentation")
          map("<C-k>",      vim.lsp.buf.signature_help,  "Signature Help")

          -- Code actions
          map("<leader>cr", vim.lsp.buf.rename,          "Rename Symbol")
          map("<leader>ca", vim.lsp.buf.code_action,     "Code Action")
          map("<leader>cf", function()
            vim.lsp.buf.format({ async = true })
          end, "Format Buffer")

          -- Diagnostics
          map("<leader>cd", vim.diagnostic.open_float,   "Line Diagnostics")
          map("[d",         vim.diagnostic.goto_prev,    "Previous Diagnostic")
          map("]d",         vim.diagnostic.goto_next,    "Next Diagnostic")

          -- Workspace
          map("<leader>wa", vim.lsp.buf.add_workspace_folder,    "Add Workspace Folder")
          map("<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove Workspace Folder")
          map("<leader>wl", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
          end, "List Workspace Folders")
        end,
      })

      -- -----------------------------------------------------------------------
      -- Diagnostic display settings
      -- -----------------------------------------------------------------------
      vim.diagnostic.config({
        virtual_text     = { prefix = "●" },
        underline        = true,
        update_in_insert = false,
        severity_sort    = true,
        float = {
          border = "rounded",
          source = "always",   -- always show the source (e.g. "pyright")
        },
        -- New-style diagnostic signs (replaces sign_define on 0.10+)
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN]  = " ",
            [vim.diagnostic.severity.HINT]  = "󰌶 ",
            [vim.diagnostic.severity.INFO]  = " ",
          },
        },
      })
    end,
  },

}, {
  -- lazy.nvim UI options
  ui = { border = "rounded" },
  checker = { enabled = true, notify = false },   -- auto-check for updates silently
})

-- ---------------------------------------------------------------------------
-- 4. General Neovim options (sensible defaults)
-- ---------------------------------------------------------------------------
local opt = vim.opt

opt.number         = true    -- absolute line numbers
opt.relativenumber = true    -- relative line numbers
opt.signcolumn     = "yes"   -- always show sign column (prevents layout shift)
opt.cursorline     = true
opt.wrap           = false
opt.scrolloff      = 8
opt.sidescrolloff  = 8

opt.expandtab      = true
opt.tabstop        = 4
opt.shiftwidth     = 4
opt.smartindent    = true

opt.ignorecase     = true
opt.smartcase      = true
opt.hlsearch       = true
opt.incsearch      = true

opt.splitright     = true
opt.splitbelow     = true

opt.termguicolors  = true
opt.updatetime     = 200     -- faster CursorHold events (used by LSP)
opt.timeoutlen     = 500     -- which-key popup delay ceiling

opt.undofile       = true    -- persistent undo across sessions
opt.swapfile       = false
opt.backup         = false

opt.clipboard      = "unnamedplus"   -- sync with system clipboard

-- ---------------------------------------------------------------------------
-- 5. Convenience keymaps (non-LSP)
-- ---------------------------------------------------------------------------
local map = vim.keymap.set

-- Clear search highlights
map("n", "<Esc>",      "<cmd>nohlsearch<CR>",          { desc = "Clear Search Highlight" })

-- Quick window navigation
map("n", "<C-h>",      "<C-w>h",                       { desc = "Window Left"  })
map("n", "<C-l>",      "<C-w>l",                       { desc = "Window Right" })
map("n", "<C-j>",      "<C-w>j",                       { desc = "Window Down"  })
map("n", "<C-k>",      "<C-w>k",                       { desc = "Window Up"    })

-- Move selected lines in visual mode
map("v", "J",          ":m '>+1<CR>gv=gv",             { desc = "Move Line Down" })
map("v", "K",          ":m '<-2<CR>gv=gv",             { desc = "Move Line Up"   })

-- Keep cursor centred when scrolling / searching
map("n", "<C-d>",      "<C-d>zz")
map("n", "<C-u>",      "<C-u>zz")
map("n", "n",          "nzzzv")
map("n", "N",          "Nzzzv")

-- Paste without clobbering the register
map("x", "<leader>p",  [["_dP]],                       { desc = "Paste (keep register)" })

-- Save shortcut
map({ "n", "i" }, "<C-s>", "<cmd>w<CR>",               { desc = "Save File" })
