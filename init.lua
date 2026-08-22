-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.o.number = true
vim.o.mouse = 'a'
vim.o.showmode = false
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.signcolumn = 'yes'
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.scrolloff = 10
vim.o.confirm = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.expandtab = true
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>cp', function()
  local path = vim.api.nvim_buf_get_name(0)
  vim.fn.setreg('+', path)
  vim.notify(path, vim.log.levels.INFO)
end, { desc = 'Copy file path' })
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- Shim for plugins that still call the removed ft_to_lang
if not vim.treesitter.language.ft_to_lang then
  vim.treesitter.language.ft_to_lang = vim.treesitter.language.get_lang
end

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- Colorscheme (Flexoki dark: matte warm-gray "ink" background, muted flat colors)
    {
      "kepano/flexoki-neovim",
      name = "flexoki",
      priority = 1000,
      config = function()
        vim.o.termguicolors = true
        vim.o.background = "dark"
        vim.cmd.colorscheme("flexoki-dark")
      end,
    },

    -- File tree
    {
      "nvim-tree/nvim-tree.lua",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1
        require("nvim-tree").setup({
          view = { width = 35 },
          filters = { dotfiles = false },
          actions = { open_file = { window_picker = { enable = false } } },
          filesystem_watchers = { enable = true },
          reload_on_bufenter = true,
        })
        -- Auto-open nvim-tree on startup, then focus back on the file
        vim.api.nvim_create_autocmd("VimEnter", {
          callback = function()
            require("nvim-tree.api").tree.open()
            vim.cmd("wincmd l")
          end,
        })
        vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
        vim.keymap.set("n", "<leader>fe", "<cmd>NvimTreeFindFile<CR>", { desc = "Find file in tree" })
      end,
    },

    -- Telescope (fuzzy finder)
    {
      "nvim-telescope/telescope.nvim",
      branch = "master",
      dependencies = {
        "nvim-lua/plenary.nvim",
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        "nvim-telescope/telescope-ui-select.nvim",
      },
      config = function()
        local telescope = require("telescope")
        telescope.setup({
          defaults = {
            file_ignore_patterns = {
              "%.git/",
              "node_modules/",
              "%.venv/",
              "__pycache__/",
              "%.pyc$",
              "%.egg%-info/",
              "%.ruff_cache/",
              "%.pytest_cache/",
              "cdk%.out/",
              "dist/",
              "build/",
              "%.lock$",
            },
          },
          extensions = {
            ["ui-select"] = { require("telescope.themes").get_dropdown() },
          },
        })
        pcall(telescope.load_extension, "fzf")
        pcall(telescope.load_extension, "ui-select")
        local builtin = require("telescope.builtin")
        vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
        vim.keymap.set("n", "<leader>fg", function()
          builtin.live_grep({ additional_args = { "--multiline" } })
        end, { desc = "Live grep" })
        vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
        vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
        vim.keymap.set("n", "<leader>fw", builtin.grep_string, { desc = "Grep word under cursor" })
        vim.keymap.set("n", "<leader>fs", function()
          builtin.grep_string({ search = "" })
        end, { desc = "Fuzzy search all content" })
        vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "Diagnostics" })
        vim.keymap.set("n", "<leader>fr", builtin.resume, { desc = "Resume last search" })
        vim.keymap.set("n", "<leader>fo", builtin.oldfiles, { desc = "Recent files" })
        vim.keymap.set("n", "<leader>/", builtin.current_buffer_fuzzy_find, { desc = "Fuzzy find in buffer" })
      end,
    },

    -- LSP manager (Mason) + LSP config
    { "williamboman/mason.nvim", opts = {} },
    {
      "williamboman/mason-lspconfig.nvim",
      dependencies = { "williamboman/mason.nvim" },
      opts = {
        ensure_installed = { "lua_ls", "basedpyright", "ruff", "ts_ls", "rust_analyzer", "clangd" },
        automatic_installation = true,
      },
    },
    {
      "neovim/nvim-lspconfig",
      dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
      config = function()
        -- Add Mason bin to PATH so servers are discoverable
        vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin" .. ":" .. vim.env.PATH

        local capabilities = vim.lsp.protocol.make_client_capabilities()
        local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
        if ok then
          capabilities = vim.tbl_deep_extend("force", capabilities, cmp_lsp.default_capabilities())
        end

        -- LSP keymaps via LspAttach autocmd
        vim.api.nvim_create_autocmd("LspAttach", {
          group = vim.api.nvim_create_augroup("lsp-attach-keymaps", { clear = true }),
          callback = function(event)
            local map = function(keys, func, desc)
              vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
            end
            map("gd", function()
              vim.cmd("vsplit")
              vim.lsp.buf.definition()
            end, "Go to definition (vsplit)")
            map("gD", vim.lsp.buf.definition, "Go to definition (same pane)")
            map("gr", vim.lsp.buf.references, "References")
            map("gi", vim.lsp.buf.implementation, "Go to implementation")
            map("K", vim.lsp.buf.hover, "Hover docs")
            map("<leader>ca", vim.lsp.buf.code_action, "Code action")
            map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
            map("<leader>ds", vim.lsp.buf.document_symbol, "Document symbols")
            map("<leader>ws", vim.lsp.buf.workspace_symbol, "Workspace symbols")
            map("<leader>cf", function() vim.lsp.buf.format({ async = true }) end, "Format file")
          end,
        })

        -- Auto-fix imports and format on save for Python (via ruff)
        vim.api.nvim_create_autocmd("BufWritePre", {
          group = vim.api.nvim_create_augroup("ruff-format-on-save", { clear = true }),
          pattern = "*.py",
          callback = function(ev)
            local clients = vim.lsp.get_clients({ bufnr = ev.buf, name = "ruff" })
            if #clients == 0 then return end
            local client = clients[1]
            -- Organize imports (synchronous via request)
            local params = {
              command = "ruff.applyOrganizeImports",
              arguments = { { uri = vim.uri_from_bufnr(ev.buf), version = vim.lsp.util.buf_versions[ev.buf] } },
            }
            client:request_sync("workspace/executeCommand", params, 3000, ev.buf)
            -- Format
            vim.lsp.buf.format({ async = false, name = "ruff" })
          end,
        })

        -- Diagnostic keymaps
        vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics quickfix list" })
        vim.keymap.set("n", "<leader>dd", vim.diagnostic.open_float, { desc = "Show diagnostic message" })
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })

        -- Walk up from a directory to find the nearest .venv
        local function find_python_path(start_dir)
          local dir = start_dir
          while dir and dir ~= "/" do
            local venv_python = dir .. "/.venv/bin/python"
            if vim.fn.executable(venv_python) == 1 then
              return venv_python
            end
            dir = vim.fn.fnamemodify(dir, ":h")
          end
          return vim.fn.exepath("python3") or "python3"
        end

        -- Configure LSP servers using vim.lsp.config (native Neovim 0.11+ API)
        vim.lsp.config("lua_ls", {
          capabilities = capabilities,
          settings = {
            Lua = {
              diagnostics = { globals = { "vim" } },
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
            },
          },
        })

        vim.lsp.config("basedpyright", {
          capabilities = capabilities,
          root_markers = { "pyproject.toml", ".git" },
          before_init = function(_, config)
            local root = config.root_dir or vim.fn.getcwd()
            config.settings.python = {
              pythonPath = find_python_path(root),
            }
          end,
        })

        vim.lsp.config("ruff", {
          capabilities = capabilities,
          on_attach = function(client, _)
            client.server_capabilities.hoverProvider = false
          end,
        })

        vim.lsp.config("ts_ls", { capabilities = capabilities })
        vim.lsp.config("rust_analyzer", { capabilities = capabilities })
        vim.lsp.config("clangd", {
          capabilities = capabilities,
          cmd = {
            -- Apple's clangd, not Mason's: the Mason build (22.1.6) fails to parse
            -- Homebrew GCC 16's libstdc++ headers, Apple's parses them cleanly
            "/usr/bin/clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            -- Allow clangd to query Homebrew GCC for its libstdc++ include paths/target,
            -- so projects compiled with g++-16 (e.g. C++26) resolve headers correctly
            "--query-driver=/opt/homebrew/**/g++-*,/opt/homebrew/**/gcc-*",
          },
          init_options = {
            -- Used only for files with no compile_commands.json entry
            fallbackFlags = { "-std=c++26" },
          },
        })

        -- Enable all configured servers
        vim.lsp.enable({ "lua_ls", "basedpyright", "ruff", "ts_ls", "rust_analyzer", "clangd" })
      end,
    },

    -- DAP (Debug Adapter Protocol)
    {
      "mfussenegger/nvim-dap",
      dependencies = {
        "rcarriga/nvim-dap-ui",
        "nvim-neotest/nvim-nio",
        "mfussenegger/nvim-dap-python",
      },
      config = function()
        local dap = require("dap")
        local dapui = require("dapui")

        dapui.setup()

        -- Auto open/close DAP UI
        dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
        dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
        dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

        -- debugpy adapter for attaching to Docker containers
        dap.adapters.debugpy_backend = {
          type = "server",
          host = "127.0.0.1",
          port = 5678,
        }

        dap.adapters.debugpy_erp = {
          type = "server",
          host = "127.0.0.1",
          port = 5679,
        }

        dap.configurations.python = {
          {
            type = "debugpy_backend",
            request = "attach",
            name = "Attach to Docker (backend :5678)",
            pathMappings = {
              { localRoot = vim.fn.getcwd() .. "/order-entry/backend", remoteRoot = "/app" },
            },
          },
          {
            type = "debugpy_erp",
            request = "attach",
            name = "Attach to Docker (erp-middleware :5679)",
            pathMappings = {
              { localRoot = vim.fn.getcwd(), remoteRoot = "/app" },
            },
          },
        }

        -- Keymaps
        vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
        vim.keymap.set("n", "<leader>dB", function()
          dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
        end, { desc = "Conditional breakpoint" })
        vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Debug continue" })
        vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "Debug step over" })
        vim.keymap.set("n", "<F8>", dap.step_over, { desc = "Debug step over" })
        vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Debug step into" })
        vim.keymap.set("n", "<F7>", dap.step_into, { desc = "Debug step into" })
        vim.keymap.set("n", "<leader>dO", dap.step_out, { desc = "Debug step out" })
        vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Debug REPL" })
        vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Toggle debug UI" })
        vim.keymap.set("n", "<leader>dx", dap.terminate, { desc = "Terminate debug session" })
      end,
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
        "rafamadriz/friendly-snippets",
      },
      config = function()
        local cmp = require("cmp")
        local luasnip = require("luasnip")
        require("luasnip.loaders.from_vscode").lazy_load()
        cmp.setup({
          snippet = {
            expand = function(args) luasnip.lsp_expand(args.body) end,
          },
          mapping = cmp.mapping.preset.insert({
            ["<C-n>"] = cmp.mapping.select_next_item(),
            ["<C-p>"] = cmp.mapping.select_prev_item(),
            ["<C-d>"] = cmp.mapping.scroll_docs(-4),
            ["<C-f>"] = cmp.mapping.scroll_docs(4),
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<CR>"] = cmp.mapping.confirm({ select = true }),
            ["<Tab>"] = cmp.mapping(function(fallback)
              if luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
              else fallback() end
            end, { "i", "s" }),
            ["<S-Tab>"] = cmp.mapping(function(fallback)
              if luasnip.jumpable(-1) then luasnip.jump(-1)
              else fallback() end
            end, { "i", "s" }),
          }),
          sources = {
            { name = "nvim_lsp" },
            { name = "luasnip" },
            { name = "buffer" },
            { name = "path" },
          },
        })
      end,
    },

    -- Treesitter (syntax highlighting + more)
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      config = function()
        local ensure = { "lua", "python", "javascript", "typescript", "rust", "c", "cpp", "json", "yaml", "html", "css", "bash", "markdown", "vimdoc" }
        -- Compiles any missing parsers (async, needs the tree-sitter CLI);
        -- no-op for parsers already installed
        require("nvim-treesitter").install(ensure)
        vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("treesitter-auto-install", { clear = true }),
          callback = function(event)
            pcall(vim.treesitter.start, event.buf)
          end,
        })
      end,
    },

    -- Statusline
    {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        -- Flat statusline built from the Flexoki dark palette: matte solid
        -- blocks, no powerline separators
        local p = {
          paper = "#100F0F", bg2 = "#1C1B1A", ui = "#282726",
          tx = "#CECDC3", tx2 = "#878580", tx3 = "#575653",
          green = "#879A39", purple = "#8B7EC8", red = "#D14D41", yellow = "#D0A215",
        }
        local flexoki_flat = {
          normal = {
            a = { fg = p.tx, bg = p.ui, gui = "bold" },
            b = { fg = p.tx2, bg = p.bg2 },
            c = { fg = p.tx2, bg = p.bg2 },
          },
          insert = { a = { fg = p.paper, bg = p.green, gui = "bold" } },
          visual = { a = { fg = p.paper, bg = p.purple, gui = "bold" } },
          replace = { a = { fg = p.paper, bg = p.red, gui = "bold" } },
          command = { a = { fg = p.paper, bg = p.yellow, gui = "bold" } },
          inactive = {
            a = { fg = p.tx3, bg = p.bg2 },
            b = { fg = p.tx3, bg = p.bg2 },
            c = { fg = p.tx3, bg = p.bg2 },
          },
        }
        require("lualine").setup({
          options = {
            theme = flexoki_flat,
            section_separators = "",
            component_separators = "",
          },
        })
      end,
    },

    -- Git signs in the gutter
    {
      "lewis6991/gitsigns.nvim",
      config = function()
        require("gitsigns").setup({
          on_attach = function(bufnr)
            local gs = require("gitsigns")
            local map = function(mode, l, r, desc)
              vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
            end
            map("n", "]h", gs.next_hunk, "Next hunk")
            map("n", "[h", gs.prev_hunk, "Previous hunk")
            map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
            map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
            map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
            map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
            map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle inline blame")
          end,
        })
      end,
    },

    -- Git merge conflict viewer (JetBrains-like 3-way merge)
    {
      "sindrets/diffview.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        require("diffview").setup()
        vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<CR>", { desc = "Open diff view" })
        vim.keymap.set("n", "<leader>gq", "<cmd>DiffviewClose<CR>", { desc = "Close diff view" })
        vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", { desc = "File history" })
      end,
    },

    -- Inline git conflict resolution
    {
      "akinsho/git-conflict.nvim",
      version = "*",
      config = function()
        require("git-conflict").setup()
      end,
    },

    -- Autopairs
    {
      "windwp/nvim-autopairs",
      event = "InsertEnter",
      config = function()
        require("nvim-autopairs").setup({})
      end,
    },

    -- GitHub Copilot
    {
      "github/copilot.vim",
      event = "InsertEnter",
    },

    -- Session management (remembers open files)
    {
      "rmagatti/auto-session",
      config = function()
        require("auto-session").setup({
          suppressed_dirs = { "~/", "~/Downloads", "/" },
          pre_save_cmds = { "NvimTreeClose" },
          post_restore_cmds = { "NvimTreeOpen" },
        })
      end,
    },

    -- Comment toggling
    { "numToStr/Comment.nvim", opts = {} },

    -- Which-key (shows pending keybinds)
    {
      "folke/which-key.nvim",
      event = "VeryLazy",
      config = function()
        local wk = require("which-key")
        wk.setup()
        wk.add({
          { "<leader>f", group = "Find" },
          { "<leader>h", group = "Git hunk" },
          { "<leader>c", group = "Code" },
          { "<leader>d", group = "Diagnostics/Debug" },
          { "<leader>r", group = "Rename" },
          { "<leader>w", group = "Workspace" },
        })
      end,
    },

    -- Indent guides
    {
      "lukas-reineke/indent-blankline.nvim",
      main = "ibl",
      opts = {},
    },

    -- Surround motions
    {
      "kylechui/nvim-surround",
      version = "*",
      event = "VeryLazy",
      opts = {},
    },

    -- Toggle terminal
    {
      "akinsho/toggleterm.nvim",
      version = "*",
      config = function()
        require("toggleterm").setup({
          size = 15,
          open_mapping = [[<C-\>]],
          direction = "horizontal",
          -- Shading darkens the terminal split, which clashes with a flat light theme
          shade_terminals = false,
        })
        vim.keymap.set("n", "<leader>t1", "<cmd>1ToggleTerm<CR>", { desc = "Terminal 1" })
        vim.keymap.set("n", "<leader>t2", "<cmd>2ToggleTerm<CR>", { desc = "Terminal 2" })
        vim.keymap.set("n", "<leader>t3", "<cmd>3ToggleTerm<CR>", { desc = "Terminal 3" })
      end,
    },

    -- Buffer tabs
    {
      "akinsho/bufferline.nvim",
      version = "*",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require("bufferline").setup({
          options = {
            offsets = {{ filetype = "NvimTree", text = "File Explorer", highlight = "Directory", separator = true }},
            diagnostics = "nvim_lsp",
          },
        })
        vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Previous buffer" })
        vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })
        vim.keymap.set("n", "<leader>bd", function()
          local win_type = vim.fn.win_gettype()
          if win_type == "quickfix" or win_type == "loclist" then
            vim.cmd("close")
            return
          end
          local buf = vim.api.nvim_get_current_buf()
          if vim.bo[buf].buflisted then
            vim.cmd("BufferLineCyclePrev")
            vim.cmd("bdelete " .. buf)
          else
            vim.cmd("close")
          end
        end, { desc = "Delete buffer" })
      end,
    },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "flexoki-dark" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})

