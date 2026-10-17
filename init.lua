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
-- Clang does not understand all of the C++26 features used by our projects.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('cpp-disable-diagnostics', { clear = true }),
  pattern = 'cpp',
  callback = function(event)
    vim.diagnostic.enable(false, { bufnr = event.buf })
  end,
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

-- CMake target selection, builds, and persistent run/debug settings.
local cpp = require('config.cpp')
cpp.setup()

vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
local windows = require('config.windows')
windows.setup()
require('config.terminal').setup()
require('config.format').setup()

local function rust_root()
  local file = vim.api.nvim_buf_get_name(0)
  local start = file ~= '' and vim.fs.dirname(file) or vim.fn.getcwd()
  return vim.fs.root(start, 'Cargo.toml') or vim.fs.root(start, 'rust-project.json') or start
end

-- Islands Dark, using CLion's bundled IslandSchemeDark.xml and UI palette.
-- https://github.com/JetBrains/intellij-community/tree/master/platform/platform-resources/src/themes/islands
-- :IslandsDark reapplies it, including plugin highlights after lazy.nvim loads.
local islands = {
  bg = '#191A1C', panel = '#191A1C', chrome = '#26282C', border = '#33353B',
  fg = '#BCBEC4', text = '#D1D3D9', muted = '#9FA2A8', comment = '#7A7E85',
  line = '#4B5059', cursorline = '#1F2024', selection = '#2A4371',
  orange = '#CF8E6D', green = '#6AAB73', blue = '#56A8F5', teal = '#2AACB8',
  purple = '#C77DBB', yellow = '#F2C55C', red = '#F75464', accent = '#71A1FE',
  added = '#73BD79', changed = '#70AEFF', deleted = '#E88F89',
}
local function islands_dark()
  local p = islands
  vim.o.termguicolors = true
  vim.o.background = 'dark'
  vim.cmd('highlight clear')
  vim.g.colors_name = 'islands-dark'
  local groups = {
    Normal = { fg = p.fg, bg = p.bg }, NormalNC = { fg = p.fg, bg = p.bg },
    NormalFloat = { fg = p.fg, bg = p.chrome },
    FloatBorder = { fg = p.border, bg = p.chrome }, FloatTitle = { fg = p.text, bg = p.chrome, bold = true },
    WinSeparator = { fg = p.border, bg = p.bg },
    Cursor = { fg = p.bg, bg = '#CED0D6' }, CursorLine = { bg = p.cursorline },
    CursorLineNr = { fg = '#A1A3AB' }, LineNr = { fg = p.line },
    SignColumn = { bg = p.bg }, FoldColumn = { fg = p.comment, bg = p.bg },
    Folded = { fg = p.comment, bg = p.chrome }, ColorColumn = { bg = p.chrome },
    NonText = { fg = p.border }, Whitespace = { fg = '#4E5157' }, EndOfBuffer = { fg = p.bg },
    Visual = { bg = p.selection }, Search = { bg = '#2D543F' },
    IncSearch = { fg = p.bg, bg = p.yellow }, CurSearch = { fg = p.bg, bg = p.yellow },
    MatchParen = { bg = '#43454A', bold = true },
    Pmenu = { fg = p.fg, bg = p.chrome }, PmenuSel = { fg = p.text, bg = p.selection },
    PmenuSbar = { bg = p.border }, PmenuThumb = { bg = '#5F6269' },
    StatusLine = { fg = p.text, bg = p.chrome }, StatusLineNC = { fg = p.muted, bg = p.chrome },
    TabLine = { fg = p.muted, bg = p.chrome }, TabLineFill = { bg = p.chrome },
    TabLineSel = { fg = p.text, bg = p.bg, bold = true },
    WinBar = { fg = p.text, bg = p.bg }, WinBarNC = { fg = p.muted, bg = p.bg },
    Directory = { fg = p.accent }, Title = { fg = p.text, bold = true },
    ErrorMsg = { fg = p.red }, WarningMsg = { fg = p.yellow }, MoreMsg = { fg = p.green },
    Question = { fg = p.accent }, ModeMsg = { fg = p.text },
    Comment = { fg = p.comment }, Constant = { fg = p.purple },
    String = { fg = p.green }, Character = { fg = p.green }, Number = { fg = p.teal },
    Boolean = { fg = p.orange }, Float = { fg = p.teal }, Identifier = { fg = p.fg },
    Function = { fg = p.blue }, Statement = { fg = p.orange }, Keyword = { fg = p.orange },
    Operator = { fg = p.fg }, PreProc = { fg = p.orange }, Type = { fg = p.fg },
    StorageClass = { fg = p.orange }, Structure = { fg = p.orange }, Typedef = { fg = p.orange },
    Special = { fg = p.orange }, Delimiter = { fg = p.fg },
    Underlined = { fg = p.accent, underline = true }, Ignore = { fg = p.comment },
    Error = { sp = p.red, undercurl = true }, Todo = { fg = '#8BB33D', italic = true },
    DiffAdd = { bg = '#203B2A' }, DiffChange = { bg = '#1B283F' },
    DiffText = { bg = '#2A4371' }, DiffDelete = { fg = p.deleted, bg = '#3F1E21' },
    LspReferenceText = { bg = '#373B39' }, LspReferenceRead = { bg = '#373B39' },
    LspReferenceWrite = { bg = '#402F33' }, LspSignatureActiveParameter = { fg = p.text, bold = true },
    LspInlayHint = { fg = '#868A91', bg = '#393B40' },
    ['@variable'] = { fg = p.fg }, ['@variable.builtin'] = { fg = p.orange },
    ['@variable.parameter'] = { fg = p.fg }, ['@variable.member'] = { fg = p.purple },
    ['@property'] = { fg = p.purple }, ['@type.builtin'] = { fg = p.orange },
    ['@constant.builtin'] = { fg = p.orange }, ['@constant.macro'] = { fg = '#B3AE60' },
    ['@function.macro'] = { fg = '#B3AE60' }, ['@string.escape'] = { fg = p.orange },
    ['@comment.documentation'] = { fg = '#5F826B', italic = true },
    ['@markup.heading'] = { fg = p.blue, bold = true }, ['@markup.raw'] = { fg = p.green },
    ['@markup.link'] = { fg = p.accent, underline = true },
    ['@markup.strong'] = { bold = true }, ['@markup.italic'] = { italic = true },
    ['@tag'] = { fg = '#D5B778' }, ['@tag.attribute'] = { fg = p.fg },
    ['@lsp.type.typeParameter'] = { fg = '#16BAAC' },
    ['@lsp.mod.deprecated'] = { strikethrough = true },
    NvimTreeNormal = { fg = p.text, bg = p.panel }, NvimTreeNormalNC = { fg = p.text, bg = p.panel },
    NvimTreeEndOfBuffer = { fg = p.panel, bg = p.panel },
    NvimTreeWinSeparator = { fg = p.border, bg = p.panel },
    NvimTreeRootFolder = { fg = p.text, bold = true }, NvimTreeFolderName = { fg = p.text },
    NvimTreeOpenedFolderName = { fg = p.text }, NvimTreeEmptyFolderName = { fg = p.muted },
    NvimTreeFolderIcon = { fg = p.muted }, NvimTreeIndentMarker = { fg = p.border },
    NvimTreeCursorLine = { bg = p.selection },
    NvimTreeExecFile = { fg = p.text }, NvimTreeSpecialFile = { fg = p.text },
    NvimTreeImageFile = { fg = p.text }, NvimTreeSymlink = { fg = p.text },
    NvimTreeModifiedFileHL = { fg = p.changed }, NvimTreeModifiedFolderHL = { fg = p.changed },
    NvimTreeModifiedIcon = { fg = p.changed },
    ['@lsp.typemod.variable.readonly'] = { fg = p.purple, italic = true },
    ['@lsp.typemod.property.static'] = { fg = p.purple, italic = true },
    ['@lsp.typemod.method.static'] = { fg = p.blue, italic = true },
    TelescopeNormal = { fg = p.fg, bg = p.chrome }, TelescopeBorder = { fg = p.border, bg = p.chrome },
    TelescopeTitle = { fg = p.text, bg = p.chrome, bold = true },
    TelescopeSelection = { bg = p.selection }, TelescopeMatching = { fg = p.accent, bold = true },
    TelescopePromptPrefix = { fg = p.accent },
    CmpItemAbbr = { fg = p.fg }, CmpItemAbbrMatch = { fg = p.accent, bold = true },
    CmpItemAbbrDeprecated = { fg = p.comment, strikethrough = true }, CmpItemMenu = { fg = p.comment },
    WhichKey = { fg = p.accent }, WhichKeyGroup = { fg = p.blue },
    WhichKeyDesc = { fg = p.fg }, WhichKeySeparator = { fg = p.comment },
    IblIndent = { fg = '#323438' }, IblScope = { fg = '#4E5157' },
    CopilotSuggestion = { fg = p.comment, italic = true },
    DapBreakpoint = { fg = p.red }, DapStopped = { fg = p.yellow, bg = '#273552' },
    DapUIVariable = { fg = p.fg }, DapUIScope = { fg = p.blue }, DapUIType = { fg = p.teal },
    DapUIValue = { fg = p.green }, DapUIFrameName = { fg = p.fg }, DapUIThread = { fg = p.green },
    DapUIStoppedThread = { fg = p.yellow }, DapUIBreakpointsPath = { fg = p.blue },
    DapUIBreakpointsInfo = { fg = p.green }, DapUIBreakpointsCurrentLine = { fg = p.yellow, bold = true },
    DapUILineNumber = { fg = p.accent }, DapUIDecoration = { fg = p.border },
  }
  for severity, color in pairs({ Error = p.red, Warn = p.yellow, Info = p.accent, Hint = p.muted, Ok = p.green }) do
    groups['Diagnostic' .. severity] = { fg = color }
    groups['DiagnosticUnderline' .. severity] = { sp = color, undercurl = true }
    groups['DiagnosticVirtualText' .. severity] = { fg = color }
  end
  for name, color in pairs({ Add = p.added, Change = p.changed, Delete = p.deleted }) do
    groups['GitSigns' .. name] = { fg = color }
  end
  -- Current nvim-tree uses separate icon/file/folder groups. Its old GitNew
  -- and GitDirty groups no longer color filenames.
  for status, color in pairs({ New = '#E88F89', Dirty = '#70AEFF', Staged = '#73BD79',
    Renamed = '#70AEFF', Deleted = '#6F737A', Ignored = '#D69A6B', Merge = '#DE6A66' }) do
    groups['NvimTreeGit' .. status .. 'Icon'] = { fg = color }
    groups['NvimTreeGitFile' .. status .. 'HL'] = { fg = color }
    groups['NvimTreeGitFolder' .. status .. 'HL'] = { fg = color }
  end
  local links = {
    ['@function'] = 'Function', ['@function.builtin'] = 'Function', ['@function.method'] = 'Function',
    ['@type'] = 'Type', ['@module'] = 'Identifier', ['@keyword'] = 'Keyword',
    ['@operator'] = 'Operator', ['@punctuation'] = 'Delimiter',
    ['@lsp.type.variable'] = '@variable', ['@lsp.type.parameter'] = '@variable.parameter',
    ['@lsp.type.property'] = '@variable.member', ['@lsp.type.enumMember'] = 'Constant',
    ['@lsp.type.function'] = 'Function', ['@lsp.type.method'] = 'Function',
    ['@lsp.type.class'] = 'Type', ['@lsp.type.struct'] = 'Type', ['@lsp.type.enum'] = 'Type',
    ['@lsp.type.interface'] = 'Type', ['@lsp.type.namespace'] = '@module',
    ['@lsp.type.macro'] = '@constant.macro',
    CmpItemAbbrMatchFuzzy = 'CmpItemAbbrMatch', CmpItemKind = 'Type',
    NvimTreeGitNew = 'GitSignsAdd', NvimTreeGitDirty = 'GitSignsChange', NvimTreeGitDeleted = 'GitSignsDelete',
    WhichKeyNormal = 'NormalFloat', WhichKeyBorder = 'FloatBorder',
    DapUIFloatBorder = 'FloatBorder', DapUIFloatNormal = 'NormalFloat',
  }
  for name, target in pairs(links) do groups[name] = { link = target } end
  for name, attrs in pairs(groups) do vim.api.nvim_set_hl(0, name, attrs) end
  local terminal = {
    p.bg, p.red, p.green, p.yellow, p.blue, p.purple, p.teal, p.fg,
    p.comment, '#FA6675', p.added, '#F4CD9A', p.accent, '#D6CDFB', '#8CC1BA', '#FFFFFF',
  }
  for i, color in ipairs(terminal) do vim.g['terminal_color_' .. (i - 1)] = color end
end
vim.o.winborder = 'rounded'
islands_dark()
vim.api.nvim_create_user_command('IslandsDark', function()
  islands_dark()
  vim.api.nvim_exec_autocmds('ColorScheme', { pattern = 'islands-dark' })
end, { desc = 'Apply the built-in Islands Dark palette' })

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- File tree
    {
      "nvim-tree/nvim-tree.lua",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1
        require("nvim-tree").setup({
          view = { width = 35 },
          filters = { dotfiles = false, git_ignored = false },
          git = { enable = true, show_on_dirs = true },
          modified = { enable = true, show_on_dirs = true },
          update_focused_file = { enable = true },
          renderer = {
            root_folder_label = ':t',
            highlight_git = 'name',
            highlight_modified = 'name',
            special_files = {},
            indent_markers = { enable = true },
            icons = { git_placement = 'after', modified_placement = 'after' },
          },
          actions = { open_file = { window_picker = {
            enable = true,
            picker = windows.editor,
          } } },
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
            get_selection_window = function() return windows.editor() end,
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
            },
          },
          extensions = {
            ["ui-select"] = { require("telescope.themes").get_dropdown() },
          },
        })
        pcall(telescope.load_extension, "fzf")
        pcall(telescope.load_extension, "ui-select")
        local builtin = require("telescope.builtin")
        local function search_opts(all)
          local args = { '--hidden', '--multiline', '--glob', '!.git/**' }
          if all then table.insert(args, '--no-ignore') end
          return {
            cwd = require('config.project').root(),
            additional_args = args,
            file_ignore_patterns = all and { '%.git/' } or nil,
          }
        end
        vim.keymap.set('n', '<leader>ff', function()
          builtin.find_files({ cwd = require('config.project').root(), hidden = true })
        end, { desc = 'Find project files (including dotfiles)' })
        vim.keymap.set('n', '<leader>fF', function()
          builtin.find_files({ cwd = require('config.project').root(), hidden = true,
            no_ignore = true, file_ignore_patterns = { '%.git/' }, prompt_title = 'All project files' })
        end, { desc = 'Find all project files (including ignored)' })
        vim.keymap.set("n", "<leader>fg", function()
          builtin.live_grep(search_opts(false))
        end, { desc = "Search project" })
        vim.keymap.set('n', '<leader>fG', function()
          builtin.live_grep(search_opts(true))
        end, { desc = 'Search all project files (including ignored)' })
        vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
        vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
        vim.keymap.set('n', '<leader>fw', function()
          builtin.grep_string(search_opts(false))
        end, { desc = 'Find word in project' })
        vim.keymap.set("n", "<leader>fs", function()
          builtin.grep_string(vim.tbl_extend('force', search_opts(false), { search = '' }))
        end, { desc = "Fuzzy search all content" })
        vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "Diagnostics" })
        vim.keymap.set("n", "<leader>fr", builtin.resume, { desc = "Resume last search" })
        vim.keymap.set("n", "<leader>fo", builtin.oldfiles, { desc = "Recent files" })
        vim.keymap.set("n", "<leader>/", builtin.current_buffer_fuzzy_find, { desc = "Fuzzy find in buffer" })
      end,
    },

    -- Review replacements across the project before applying them.
    {
      'MagicDuck/grug-far.nvim',
      cmd = { 'GrugFar', 'GrugFarWithin' },
      opts = {},
      keys = {
        { '<leader>rr', function()
          require('grug-far').open({ prefills = { paths = require('config.project').search_path() } })
        end, desc = 'Project search and replace' },
        { '<leader>rr', function()
          require('grug-far').with_visual_selection({ prefills = { paths = require('config.project').search_path() } })
        end, mode = 'x', desc = 'Replace selection across project' },
        { '<leader>rw', function()
          require('grug-far').open({ prefills = {
            paths = require('config.project').search_path(), search = vim.fn.expand('<cword>'),
          } })
        end, desc = 'Replace word across project' },
      },
    },

    -- Rust commands and indentation; rust-analyzer handles edition-aware formatting.
    {
      "rust-lang/rust.vim",
      ft = { "rust" },
      cmd = { "Cargo", "Cbuild", "Ccheck", "Crun", "Ctest", "Cdoc" },
      init = function()
        vim.g.rustfmt_autosave = 0
        vim.g.cargo_shell_command_runner = 'RustCargoTerminal'
        vim.api.nvim_create_autocmd('FileType', {
          group = vim.api.nvim_create_augroup('rust-workflow', { clear = true }),
          pattern = 'rust',
          callback = function(event)
            local commands = {
              b = { 'Cbuild', 'Cargo build' },
              c = { 'Ccheck', 'Cargo check' },
              r = { 'RustLsp runnables', 'Rust runnable targets' },
              R = { 'RustLsp! runnables', 'Repeat last Rust runnable' },
              t = { 'Ctest', 'Cargo test' },
              l = { 'Cargo clippy', 'Cargo Clippy' },
              d = { 'Cdoc --open', 'Cargo documentation' },
              D = { 'RustLsp debuggables', 'Rust debug targets' },
            }
            for key, command in pairs(commands) do
              vim.keymap.set('n', '<leader>m' .. key, '<cmd>' .. command[1] .. '<CR>',
                { buffer = event.buf, desc = command[2] })
            end
            vim.keymap.set('n', '<leader>mT', function()
              vim.cmd('wall')
              require('neotest').run.run()
            end, { buffer = event.buf, desc = 'Rust test under cursor' })
            require('which-key').add({ { '<leader>m', group = 'Rust / Cargo', buffer = event.buf } })
          end,
        })
      end,
      config = function()
        -- rust.vim supplies the Cargo arguments; run them without a shell, in the
        -- current crate, so opening a Rust file from another directory also works.
        vim.api.nvim_create_user_command('RustCargoTerminal', function(opts)
          if vim.fn.executable('cargo') ~= 1 then
            return vim.notify('Cargo is not installed', vim.log.levels.ERROR)
          end
          local root = rust_root()
          vim.cmd('wall')
          vim.cmd('botright 15new')
          vim.fn.jobstart(opts.fargs, { term = true, cwd = root })
          vim.cmd('startinsert')
        end, { nargs = '+', desc = 'Run Cargo in the current Rust project' })
      end,
    },

    -- Owns the Rust LSP client and discovers Cargo run/test/debug targets.
    {
      'mrcjkb/rustaceanvim',
      version = '^9',
      lazy = false,
      dependencies = { 'williamboman/mason.nvim', 'hrsh7th/cmp-nvim-lsp', 'mfussenegger/nvim-dap' },
      init = function()
        vim.g.rustaceanvim = function()
          return {
            tools = {
              test_executor = 'neotest',
              code_actions = { ui_select_fallback = true },
            },
            server = {
              cmd = { vim.fn.stdpath('data') .. '/mason/bin/rust-analyzer' },
              capabilities = require('cmp_nvim_lsp').default_capabilities(),
              default_settings = {
                ['rust-analyzer'] = {
                  cargo = { allTargets = true, buildScripts = { enable = true } },
                  procMacro = { enable = true },
                  checkOnSave = true,
                  check = { command = 'clippy' },
                },
              },
            },
            dap = {
              adapter = function() return require('dap').adapters.codelldb end,
            },
          }
        end
      end,
    },

    -- Test discovery, results, output, and debugging through rust-analyzer.
    {
      'nvim-neotest/neotest',
      ft = { 'rust' },
      dependencies = { 'nvim-neotest/nvim-nio', 'nvim-lua/plenary.nvim', 'mrcjkb/rustaceanvim' },
      keys = {
        { '<leader>tt', function() vim.cmd('wall'); require('neotest').run.run() end, desc = 'Run nearest test' },
        { '<leader>tf', function() vim.cmd('wall'); require('neotest').run.run(vim.api.nvim_buf_get_name(0)) end, desc = 'Test current file' },
        { '<leader>ta', function() vim.cmd('wall'); require('neotest').run.run({ suite = true }) end, desc = 'Run test suite' },
        { '<leader>td', function() vim.cmd('wall'); require('neotest').run.run({ strategy = 'dap' }) end, desc = 'Debug nearest test' },
        { '<leader>tl', function() vim.cmd('wall'); require('neotest').run.run_last() end, desc = 'Repeat last test' },
        { '<leader>ts', function() require('neotest').summary.toggle() end, desc = 'Test summary' },
        { '<leader>to', function() require('neotest').output.open({ enter = true }) end, desc = 'Test output' },
        { '<leader>tO', function() require('neotest').output_panel.toggle() end, desc = 'Test output panel' },
        { '<leader>tx', function() require('neotest').run.stop() end, desc = 'Stop test' },
      },
      config = function()
        require('neotest').setup({ adapters = { require('rustaceanvim.neotest') } })
      end,
    },

    -- Cargo dependency versions, features, documentation, and completion.
    {
      'saecki/crates.nvim',
      tag = 'stable',
      event = { 'BufReadPre Cargo.toml', 'BufNewFile Cargo.toml' },
      dependencies = { 'nvim-lua/plenary.nvim', 'hrsh7th/nvim-cmp' },
      config = function()
        local crates = require('crates')
        local function on_attach(bufnr)
          local map = function(key, action, desc)
            vim.keymap.set('n', '<leader>p' .. key, action, { buffer = bufnr, desc = desc })
          end
          map('v', crates.show_versions_popup, 'Crate versions')
          map('f', crates.show_features_popup, 'Crate features')
          map('d', crates.open_documentation, 'Crate documentation')
          map('u', crates.update_crate, 'Update crate within version requirement')
          map('U', crates.upgrade_crate, 'Upgrade crate version requirement')
          map('r', crates.reload, 'Refresh crate information')
          require('which-key').add({ { '<leader>p', group = 'Cargo dependencies', buffer = bufnr } })
          require('cmp').setup.buffer({ sources = {
            { name = 'crates' }, { name = 'nvim_lsp' }, { name = 'luasnip' },
            { name = 'buffer' }, { name = 'path' },
          } })
        end
        crates.setup({
          completion = { cmp = { enabled = true } },
          on_attach = on_attach,
        })
        -- crates.nvim attaches to existing manifests itself; include newly created ones.
        vim.api.nvim_create_autocmd('BufNewFile', {
          group = vim.api.nvim_create_augroup('crates-new-manifest', { clear = true }),
          pattern = 'Cargo.toml',
          callback = function(event)
            crates.update(event.buf)
            on_attach(event.buf)
          end,
        })
      end,
    },

    -- LSP manager (Mason) + LSP config
    { "williamboman/mason.nvim", opts = {} },
    {
      "williamboman/mason-lspconfig.nvim",
      dependencies = { "williamboman/mason.nvim" },
      opts = {
        ensure_installed = { "lua_ls", "basedpyright", "ruff", "ts_ls", "rust_analyzer", "taplo" },
        -- Rustaceanvim owns Rust; enable the other servers after their configurations are ready.
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
            map("<leader>cf", function() require('config.format').buffer() end, "Format file")
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
            if client and client.name == 'rust-analyzer' then
              map('K', '<cmd>RustLsp hover actions<CR>', 'Rust hover actions')
              map('<leader>ca', '<cmd>RustLsp codeAction<CR>', 'Rust code actions')
              map('<leader>cm', '<cmd>RustLsp expandMacro<CR>', 'Expand Rust macro')
              map('<leader>ce', '<cmd>RustLsp explainError<CR>', 'Explain Rust compiler error')
              map('<leader>cD', '<cmd>RustLsp renderDiagnostic<CR>', 'Full Rust compiler diagnostic')
              map('<leader>cR', '<cmd>RustLsp relatedTests<CR>', 'Find related Rust tests')
              map('<leader>cO', '<cmd>RustLsp openCargo<CR>', 'Open Cargo.toml')
              map('<leader>cK', '<cmd>RustLsp openDocs<CR>', 'Open Rust documentation')
              map('<leader>dt', '<cmd>RustLsp debug<CR>', 'Debug Rust target under cursor')
              map('<leader>cF', function()
                vim.b[event.buf].rust_format_on_save = vim.b[event.buf].rust_format_on_save == false
                vim.notify('Rust format on save: ' .. tostring(vim.b[event.buf].rust_format_on_save))
              end, 'Toggle format on save (buffer)')
            end
          end,
        })

        vim.api.nvim_create_autocmd('BufWritePre', {
          group = vim.api.nvim_create_augroup('rust-format-on-save', { clear = true }),
          callback = function(ev)
            if vim.bo[ev.buf].filetype ~= 'rust' or vim.b[ev.buf].rust_format_on_save == false then return end
            if #vim.lsp.get_clients({ bufnr = ev.buf, name = 'rust-analyzer' }) == 0 then return end
            vim.lsp.buf.format({ bufnr = ev.buf, name = 'rust-analyzer', timeout_ms = 3000 })
          end,
        })

        vim.api.nvim_create_autocmd('BufWritePre', {
          group = vim.api.nvim_create_augroup('toml-format-on-save', { clear = true }),
          callback = function(ev)
            if vim.bo[ev.buf].filetype ~= 'toml' then return end
            if #vim.lsp.get_clients({ bufnr = ev.buf, name = 'taplo' }) == 0 then return end
            vim.lsp.buf.format({ bufnr = ev.buf, name = 'taplo', timeout_ms = 3000 })
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
        vim.lsp.config("taplo", {
          capabilities = capabilities,
          root_markers = { '.taplo.toml', 'taplo.toml', 'Cargo.toml', '.git' },
        })
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
        vim.lsp.enable({ "lua_ls", "basedpyright", "ruff", "ts_ls", "taplo", "clangd" })
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

        -- Shared C/C++ and Rust adapter (:MasonInstall codelldb).
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
            program = function() return cpp.program() or dap.ABORT end,
            cwd = cpp.root,
            stopOnEntry = false,
            args = {},
          },
          {
            name = 'C/C++: attach to process',
            type = 'codelldb',
            request = 'attach',
            pid = require('dap.utils').pick_process,
            cwd = cpp.root,
          },
        }
        dap.configurations.c = vim.deepcopy(dap.configurations.cpp)
        dap.configurations.rust = {
          -- Rustaceanvim adds launch configurations for the current workspace.
          {
            name = 'Rust: attach to process',
            type = 'codelldb',
            request = 'attach',
            pid = require('dap.utils').pick_process,
            cwd = rust_root,
            sourceLanguages = { 'rust' },
          },
        }

        -- Keymaps
        local function debug_continue()
          if not dap.session() and vim.bo.filetype == 'cpp'
            and vim.fn.filereadable(cpp.root() .. '/CMakeLists.txt') == 1 then
            cpp.launch('debug', true)
          else dap.continue() end
        end
        vim.keymap.set('n', '<F5>', debug_continue, { desc = 'Debug start / continue' })
        vim.keymap.set({ 'n', 'x' }, '<leader>de', dapui.eval, { desc = 'Evaluate expression' })
        vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
        vim.keymap.set("n", "<leader>dB", function()
          dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
        end, { desc = "Conditional breakpoint" })
        vim.keymap.set("n", "<leader>dc", debug_continue, { desc = "Debug start / continue" })
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
          window = {
            completion = cmp.config.window.bordered({ winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None' }),
            documentation = cmp.config.window.bordered(),
          },
          snippet = {
            expand = function(args) luasnip.lsp_expand(args.body) end,
          },
          mapping = cmp.mapping.preset.insert({
            ["<C-n>"] = cmp.mapping.select_next_item(),
            ["<C-p>"] = cmp.mapping.select_prev_item(),
            ["<C-d>"] = cmp.mapping.scroll_docs(-4),
            ["<C-f>"] = cmp.mapping.scroll_docs(4),
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<Esc>"] = cmp.mapping.abort(),
            ["<CR>"] = cmp.mapping.confirm({ select = false }),
            ["<Tab>"] = cmp.mapping(function(fallback)
              if cmp.visible() then cmp.confirm({ select = true })
              elseif luasnip.expand_or_locally_jumpable() then luasnip.expand_or_jump()
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
        local ensure = { "lua", "python", "javascript", "typescript", "rust", "toml", "c", "cpp", "json", "yaml", "html", "css", "bash", "markdown", "vimdoc" }
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

    -- Structural selections, function/class motions, and argument swapping.
    {
      'nvim-treesitter/nvim-treesitter-textobjects',
      branch = 'main',
      dependencies = { 'nvim-treesitter/nvim-treesitter' },
      config = function()
        require('nvim-treesitter-textobjects').setup({
          select = {
            lookahead = true,
            selection_modes = { ['@function.outer'] = 'V', ['@class.outer'] = 'V' },
          },
          move = { set_jumps = true },
        })
        vim.api.nvim_create_autocmd('FileType', {
          group = vim.api.nvim_create_augroup('structural-editing', { clear = true }),
          callback = function(event)
            -- Apply after ftplugins, which may provide their own [m / ]m maps.
            vim.schedule(function()
              if not vim.api.nvim_buf_is_valid(event.buf) then return end
              local lang = vim.treesitter.language.get_lang(vim.bo[event.buf].filetype)
              if not lang or not pcall(vim.treesitter.get_parser, event.buf, lang) then return end
              local function map(modes, key, action, desc)
                vim.keymap.set(modes, key, action, { buffer = event.buf, desc = desc })
              end
              for key, capture in pairs({
                af = '@function.outer', ['if'] = '@function.inner',
                ac = '@class.outer', ic = '@class.inner',
                aa = '@parameter.outer', ia = '@parameter.inner',
              }) do
                map({ 'x', 'o' }, key, function()
                  require('nvim-treesitter-textobjects.select').select_textobject(capture, 'textobjects')
                end, 'Select ' .. capture:sub(2))
              end
              for key, spec in pairs({
                [']m'] = { 'goto_next_start', '@function.outer' },
                ['[m'] = { 'goto_previous_start', '@function.outer' },
                [']M'] = { 'goto_next_end', '@function.outer' },
                ['[M'] = { 'goto_previous_end', '@function.outer' },
                [']]'] = { 'goto_next_start', '@class.outer' },
                ['[['] = { 'goto_previous_start', '@class.outer' },
              }) do
                map({ 'n', 'x', 'o' }, key, function()
                  require('nvim-treesitter-textobjects.move')[spec[1]](spec[2], 'textobjects')
                end, spec[1]:gsub('_', ' ') .. ' ' .. spec[2]:sub(2))
              end
              map('n', '<leader>c>', function()
                require('nvim-treesitter-textobjects.swap').swap_next('@parameter.inner')
              end, 'Swap argument with next')
              map('n', '<leader>c<', function()
                require('nvim-treesitter-textobjects.swap').swap_previous('@parameter.inner')
              end, 'Swap argument with previous')
            end)
          end,
        })
      end,
    },

    -- Statusline
    {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        -- Match the Islands window chrome, with a small mode accent.
        local p = {
          paper = islands.bg, bg2 = islands.chrome, ui = islands.selection,
          tx = islands.text, tx2 = islands.muted, tx3 = islands.comment,
          green = islands.green, purple = islands.purple, red = islands.red, yellow = islands.yellow,
        }
        local islands_flat = {
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
            theme = islands_flat,
            section_separators = "",
            component_separators = "",
          },
          sections = {
            lualine_b = { 'branch', 'diff', {
              'diagnostics', cond = function() return vim.bo.filetype ~= 'cpp' end,
            } },
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

    -- Right-side overview of the viewport and Git changes.
    {
      'petertriho/nvim-scrollbar',
      event = { 'BufReadPost', 'BufNewFile' },
      dependencies = { 'lewis6991/gitsigns.nvim' },
      opts = {
        handle = { color = islands.border, blend = 0 },
        marks = {
          GitAdd = { text = '▎', color = islands.added },
          GitChange = { text = '▎', color = islands.changed },
          GitDelete = { text = '▁', color = islands.deleted },
        },
        excluded_buftypes = { 'terminal', 'nofile', 'prompt', 'quickfix' },
        -- Keep this overview focused on Git; C++ diagnostics are disabled above.
        handlers = { gitsigns = true, cursor = false, diagnostic = false },
      },
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

    -- Commit, branch, stash, and rebase using the existing diff viewer.
    {
      'NeogitOrg/neogit',
      cmd = 'Neogit',
      dependencies = { 'sindrets/diffview.nvim', 'nvim-telescope/telescope.nvim' },
      opts = { kind = 'tab', integrations = { diffview = true, telescope = true } },
      keys = {
        { '<leader>gg', function()
          require('neogit').open({ cwd = require('config.project').root() })
        end, desc = 'Git status / commits / branches' },
      },
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
      dependencies = { 'nvim-telescope/telescope.nvim' },
      config = function()
        require("auto-session").setup({
          suppressed_dirs = { "~/", "~/Downloads", "/" },
          pre_save_cmds = { "NvimTreeClose" },
          post_restore_cmds = { "NvimTreeOpen" },
          session_lens = { picker = 'telescope' },
        })
        vim.keymap.set('n', '<leader>wr', '<cmd>AutoSession search<CR>', { desc = 'Switch project session' })
        vim.keymap.set('n', '<leader>wS', '<cmd>AutoSession save<CR>', { desc = 'Save project session' })
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
          { "<leader>g", group = "Git" },
          { "<leader>c", group = "Code" },
          { "<leader>d", group = "Diagnostics/Debug" },
          { "<leader>r", group = "Rename / replace" },
          { "<leader>w", group = "Workspace" },
          { "<leader>m", group = "C++ build / run / test" },
          { "<leader>t", group = "Tests / terminals" },
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
          direction = "horizontal",
          autochdir = false,
          persist_size = true,
          persist_mode = true,
          close_on_exit = false,
          winbar = {
            enabled = true,
            name_formatter = function(term)
              return ('%d: %s'):format(term.id, require('config.terminal').display_name(term)):gsub('%%', '%%%%')
            end,
          },
          -- Keep terminal backgrounds consistent with the editor palette.
          shade_terminals = false,
          highlights = { Normal = { guibg = islands.bg, guifg = islands.fg } },
          on_open = function(term) windows.protect_terminal(term.window) end,
        })
        require('config.terminal').setup_tools()
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
            left_mouse_command = windows.open_buffer,
            custom_filter = function(buf) return vim.bo[buf].buftype ~= 'terminal' end,
            separator_style = 'thin',
            indicator = { style = 'underline' },
            offsets = {{ filetype = "NvimTree", text = "Project", highlight = "NvimTreeRootFolder", separator = true }},
            diagnostics = "nvim_lsp",
          },
          highlights = {
            fill = { bg = islands.chrome },
            background = { fg = islands.muted, bg = islands.chrome },
            buffer_visible = { fg = islands.fg, bg = islands.panel },
            buffer_selected = { fg = islands.text, bg = islands.bg, sp = islands.accent, bold = true, italic = false },
            numbers_selected = { fg = islands.muted, bg = islands.bg, sp = islands.accent },
            close_button_selected = { fg = islands.muted, bg = islands.bg, sp = islands.accent },
            modified_selected = { fg = islands.changed, bg = islands.bg, sp = islands.accent },
            diagnostic_selected = { fg = islands.muted, bg = islands.bg, sp = islands.accent },
            error_selected = { fg = islands.red, bg = islands.bg, sp = islands.accent },
            error_diagnostic_selected = { fg = islands.red, bg = islands.bg, sp = islands.accent },
            warning_selected = { fg = islands.yellow, bg = islands.bg, sp = islands.accent },
            warning_diagnostic_selected = { fg = islands.yellow, bg = islands.bg, sp = islands.accent },
            indicator_selected = { fg = islands.accent, bg = islands.bg, sp = islands.accent, underline = true },
            separator = { fg = islands.border, bg = islands.chrome },
            separator_selected = { fg = islands.border, bg = islands.bg },
            separator_visible = { fg = islands.border, bg = islands.panel },
          },
        })
        vim.keymap.set('n', '<S-h>', function()
          windows.focus_editor()
          vim.cmd.BufferLineCyclePrev()
        end, { desc = 'Previous buffer' })
        vim.keymap.set('n', '<S-l>', function()
          windows.focus_editor()
          vim.cmd.BufferLineCycleNext()
        end, { desc = 'Next buffer' })
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
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})
-- Restore the palette if lazy.nvim temporarily used its installation fallback.
vim.cmd.IslandsDark()
