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
vim.o.updatetime = 250
vim.o.timeoutlen = 400
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }
vim.diagnostic.config({
  severity_sort = true,
  update_in_insert = false,
  float = { border = 'rounded', source = 'if_many' },
})
-- Copilot and LuaSnip otherwise compete for Tab.
vim.g.copilot_no_tab_map = true
vim.keymap.set('i', '<M-a>', 'copilot#Accept("")', {
  expr = true, replace_keycodes = false, desc = 'Accept Copilot suggestion',
})
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
-- macOS-style Option+Left/Right word movement. Depending on the terminal,
-- Option+arrow arrives as <M-Left>/<M-Right> or as Esc-b/Esc-f (<M-b>/<M-f>).
-- Option+Right lands after the end of the word, like macOS text fields.
for _, lhs in ipairs({ '<M-Left>', '<M-b>' }) do
  vim.keymap.set({ 'n', 'i', 'v', 'c' }, lhs, '<C-Left>', { desc = 'Move back a word' })
end
for _, lhs in ipairs({ '<M-Right>', '<M-f>' }) do
  vim.keymap.set({ 'n', 'v' }, lhs, 'e', { desc = 'Move to end of word' })
  vim.keymap.set('i', lhs, '<Esc>ea', { desc = 'Move to end of word' })
  vim.keymap.set('c', lhs, '<C-Right>', { desc = 'Move forward a word' })
end
-- macOS-style Option+Backspace: delete the previous word
vim.keymap.set({ 'i', 'c' }, '<M-BS>', '<C-w>', { desc = 'Delete previous word' })
vim.keymap.set('n', '<M-BS>', 'db', { desc = 'Delete previous word' })
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- Shim for plugins that still call the removed ft_to_lang
if not vim.treesitter.language.ft_to_lang then
  vim.treesitter.language.ft_to_lang = vim.treesitter.language.get_lang
end

-- C++ workflow settings. Existing CMake caches keep their compiler/toolchain.
local cpp = {
  compiler = vim.fn.executable('g++-16') == 1 and 'g++-16' or 'clang++',
  standard = 'c++26',
  build_dir = 'build',
  programs = {},
}
local function cpp_root()
  local file = vim.api.nvim_buf_get_name(0)
  local start = file ~= '' and vim.fs.dirname(file) or vim.fn.getcwd()
  local git = vim.fs.root(start, '.git')
  if git and vim.fn.filereadable(git .. '/CMakeLists.txt') == 1 then return git end
  return vim.fs.root(start, 'CMakeLists.txt') or git or start
end

-- Run without a shell: spaces in paths and compiler arguments remain intact.
-- Keep one task active so concurrent builds cannot overwrite the quickfix list.
local cpp_job
local function cpp_task(argv, root, on_success)
  if cpp_job then return vim.notify('A C++ task is running; use :CppStop first', vim.log.levels.WARN) end
  if vim.fn.executable(argv[1]) ~= 1 then
    return vim.notify('Executable not found: ' .. argv[1], vim.log.levels.ERROR)
  end
  vim.cmd('wall')
  local title = table.concat(argv, ' ')
  local efm = vim.o.errorformat
  vim.notify('Started: ' .. title)
  local ok, job = pcall(vim.system, argv, { cwd = root, text = true }, function(result)
    vim.schedule(function()
      cpp_job = nil
      -- Prefix the output with a directory marker so relative diagnostics resolve
      -- against the project, even if the editor's working directory changes.
      local lines = { 'Entering directory `' .. root .. "'" }
      vim.list_extend(lines, vim.split((result.stdout or '') .. '\n' .. (result.stderr or ''), '\n'))
      vim.fn.setqflist({}, ' ', { title = title, lines = lines, efm = "%DEntering directory `%f'," .. efm })
      if result.code ~= 0 then
        vim.cmd('botright copen')
        vim.notify('C++ task failed (exit ' .. result.code .. ')', vim.log.levels.ERROR)
      else
        vim.notify('Finished: ' .. title)
        if on_success then on_success() end
      end
    end)
  end)
  if ok then cpp_job = job else vim.notify(tostring(job), vim.log.levels.ERROR) end
end

vim.api.nvim_create_user_command('CppConfigure', function(opts)
  local root = cpp_root()
  if vim.fn.filereadable(root .. '/CMakeLists.txt') == 0 then
    return vim.notify('No CMakeLists.txt found', vim.log.levels.WARN)
  end
  local argv = { 'cmake', '-S', root, '-B', root .. '/' .. cpp.build_dir,
    '-DCMAKE_BUILD_TYPE=Debug', '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON' }
  vim.list_extend(argv, opts.fargs)
  cpp_task(argv, root)
end, { nargs = '*', desc = 'Configure CMake in build/ (extra CMake arguments allowed)' })

vim.api.nvim_create_user_command('CppBuild', function(opts)
  local root = cpp_root()
  local build = root .. '/' .. cpp.build_dir
  if vim.fn.filereadable(build .. '/CMakeCache.txt') == 0 then
    return vim.notify('Run :CppConfigure first, or use :CppBuildFile for a standalone file', vim.log.levels.WARN)
  end
  local argv = { 'cmake', '--build', build, '--config', 'Debug', '--parallel' }
  if #opts.fargs > 0 then
    table.insert(argv, '--target')
    vim.list_extend(argv, opts.fargs)
  end
  cpp_task(argv, root)
end, { nargs = '*', desc = 'Build CMake project (optional target names)' })

vim.api.nvim_create_user_command('CppBuildFile', function()
  local file = vim.api.nvim_buf_get_name(0)
  if vim.bo.filetype ~= 'cpp' or file == '' then
    return vim.notify('Open a named C++ source file first', vim.log.levels.WARN)
  end
  -- Cache binaries outside the source tree; hash the path to avoid name collisions.
  local dir = vim.fn.stdpath('cache') .. '/cpp/' .. vim.fn.sha256(file):sub(1, 16)
  vim.fn.mkdir(dir, 'p')
  local program = dir .. '/' .. vim.fn.fnamemodify(file, ':t:r')
  local root = cpp_root()
  cpp_task({ cpp.compiler, '-std=' .. cpp.standard, '-g', '-O0', '-Wall', '-Wextra',
    '-fdiagnostics-color=never', file, '-o', program }, root, function()
      cpp.programs[root] = program
    end)
end, { desc = 'Build current standalone C++ file with debug symbols and warnings' })

vim.api.nvim_create_user_command('CppTest', function(opts)
  local root = cpp_root()
  local argv = { 'ctest', '--test-dir', root .. '/' .. cpp.build_dir,
    '-C', 'Debug', '--output-on-failure', '--no-tests=error' }
  vim.list_extend(argv, opts.fargs)
  cpp_task(argv, root)
end, { nargs = '*', desc = 'Run CTest (extra arguments allowed, e.g. -R test_name)' })

vim.api.nvim_create_user_command('CppStop', function()
  if cpp_job then cpp_job:kill(15) end
end, { desc = 'Stop the active C++ task' })

local function cpp_program()
  local root = cpp_root()
  local path = vim.fn.input({ prompt = 'Executable: ',
    default = cpp.programs[root] or root .. '/' .. cpp.build_dir .. '/', completion = 'file' })
  if path == '' then return end
  path = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
  if vim.fn.isdirectory(path) == 1 or vim.fn.executable(path) ~= 1 then
    vim.notify('Not an executable file: ' .. path, vim.log.levels.ERROR)
    return
  end
  cpp.programs[root] = path
  return path
end

vim.api.nvim_create_user_command('CppRun', function()
  local root = cpp_root()
  local program = cpp_program()
  if not program then return end
  vim.cmd('botright 15new')
  vim.fn.jobstart({ program }, { term = true, cwd = root })
  vim.cmd('startinsert')
end, { desc = 'Run a C++ executable in an interactive terminal' })

for key, command in pairs({ c = 'CppConfigure', b = 'CppBuild', f = 'CppBuildFile',
  t = 'CppTest', r = 'CppRun', s = 'CppStop' }) do
  vim.keymap.set('n', '<leader>m' .. key, '<cmd>' .. command .. '<CR>', { desc = command })
end
vim.keymap.set('n', '<leader>mq', '<cmd>copen<CR>', { desc = 'Build output / quickfix' })
vim.keymap.set('n', ']q', '<cmd>cnext<CR>', { desc = 'Next quickfix item' })
vim.keymap.set('n', '[q', '<cmd>cprevious<CR>', { desc = 'Previous quickfix item' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

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
            if #vim.api.nvim_list_uis() == 0 or vim.o.diff then return end
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
        ensure_installed = { "lua_ls", "basedpyright", "ruff", "ts_ls", "rust_analyzer" },
        -- Enable only after our native configurations (including Apple clangd) are ready.
        automatic_enable = false,
      },
    },
    {
      "neovim/nvim-lspconfig",
      dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim", "hrsh7th/cmp-nvim-lsp" },
      config = function()
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
            map("<leader>ct", vim.lsp.buf.type_definition, "Go to type definition")
            map("<leader>ci", vim.lsp.buf.incoming_calls, "Incoming calls")
            map("<leader>co", vim.lsp.buf.outgoing_calls, "Outgoing calls")
            vim.keymap.set('i', '<C-k>', vim.lsp.buf.signature_help,
              { buffer = event.buf, desc = 'LSP: Signature help' })
            vim.keymap.set('x', '<leader>ca', vim.lsp.buf.code_action,
              { buffer = event.buf, desc = 'LSP: Code action' })

            local client = vim.lsp.get_client_by_id(event.data.client_id)
            if client and client:supports_method('textDocument/inlayHint') then
              map('<leader>ch', function()
                local filter = { bufnr = event.buf }
                vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
              end, 'Toggle inlay hints')
            end
            if client and client.name == 'clangd' then
              map('<leader>cs', '<cmd>LspClangdSwitchSourceHeader<CR>', 'Switch source/header')
              map('<leader>cF', function()
                vim.b[event.buf].cpp_format_on_save = not vim.b[event.buf].cpp_format_on_save
                vim.notify('C/C++ format on save: ' .. tostring(vim.b[event.buf].cpp_format_on_save))
              end, 'Toggle format on save (buffer)')
            end
          end,
        })

        -- Explicit opt-in per buffer; clangd uses the project's .clang-format.
        vim.api.nvim_create_autocmd('BufWritePre', {
          group = vim.api.nvim_create_augroup('cpp-format-on-save', { clear = true }),
          callback = function(ev)
            if vim.b[ev.buf].cpp_format_on_save then
              vim.lsp.buf.format({ bufnr = ev.buf, name = 'clangd', timeout_ms = 2000 })
            end
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
        vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics location list" })
        vim.keymap.set("n", "<leader>dd", vim.diagnostic.open_float, { desc = "Show diagnostic message" })
        vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next diagnostic" })
        vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Previous diagnostic" })

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
          root_markers = { '.clangd', 'compile_commands.json', 'compile_flags.txt', '.git', 'CMakeLists.txt' },
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

        -- CodeLLDB is already installed through Mason; retain the Python adapters.
        dap.adapters.codelldb = {
          type = 'server',
          port = '${port}',
          executable = {
            command = vim.fn.stdpath('data') .. '/mason/bin/codelldb',
            args = { '--port', '${port}' },
          },
        }
        dap.configurations.cpp = {
          {
            name = 'C/C++: launch executable',
            type = 'codelldb',
            request = 'launch',
            program = function() return cpp_program() or dap.ABORT end,
            cwd = cpp_root,
            stopOnEntry = false,
            args = {},
          },
          {
            name = 'C/C++: attach to process',
            type = 'codelldb',
            request = 'attach',
            pid = require('dap.utils').pick_process,
            cwd = cpp_root,
          },
        }
        dap.configurations.c = vim.deepcopy(dap.configurations.cpp)

        -- Keymaps
        vim.keymap.set('n', '<F5>', dap.continue, { desc = 'Debug start / continue' })
        vim.keymap.set({ 'n', 'x' }, '<leader>de', dapui.eval, { desc = 'Evaluate expression' })
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
          preselect = cmp.PreselectMode.None,
          snippet = {
            expand = function(args) luasnip.lsp_expand(args.body) end,
          },
          mapping = cmp.mapping.preset.insert({
            ["<C-n>"] = cmp.mapping.select_next_item(),
            ["<C-p>"] = cmp.mapping.select_prev_item(),
            ["<C-d>"] = cmp.mapping.scroll_docs(-4),
            ["<C-f>"] = cmp.mapping.scroll_docs(4),
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<CR>"] = cmp.mapping.confirm({ select = false }),
            ["<Tab>"] = cmp.mapping(function(fallback)
              if luasnip.expand_or_locally_jumpable() then luasnip.expand_or_jump()
              else fallback() end
            end, { "i", "s" }),
            ["<S-Tab>"] = cmp.mapping(function(fallback)
              if luasnip.locally_jumpable(-1) then luasnip.jump(-1)
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
          { "<leader>m", group = "C++ build / run / test" },
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
