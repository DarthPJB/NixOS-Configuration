local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- both optional
  "Avi-D-coder/vim-bufkill",
  { "RRethy/vim-illuminate", lazy = true, event = "VeryLazy" },

  { "miikanissi/modus-themes.nvim", priority = 1000 },

  -- useful
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        -- A list of parser names, or "all" (the five listed parsers should always be installed)
        ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "rust" },

        sync_install = false,
        auto_install = false,

        highlight = {
          enable = true,

          -- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
          -- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
          -- the name of the parser)
          -- list of language that will be disabled
          -- disable = { "c", "rust" },
          -- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
          disable = function(lang, buf)
            local max_filesize = 100 * 1024 -- 100 KB
            local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
            if ok and stats and stats.size > max_filesize then
              return true
            end
          end,

          -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
          -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
          -- Using this option may slow down your editor, and you may see some duplicate highlights.
          -- Instead of true it can also be a list of languages
          additional_vim_regex_highlighting = false,
        },
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    lazy = true,
    event = "VeryLazy",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("treesitter-context").setup({
        enable = true,
        -- How many lines the window should span. Values <= 0 mean no limit.
        max_lines = 0,
        -- Minimum editor window height to enable context. Values <= 0 mean no limit.
        min_window_height = 0,
        line_numbers = true,
        -- Maximum number of lines to show for a single context
        multiline_threshold = 1,
        -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
        trim_scope = "outer",
        -- Line used to calculate context. Choices: 'cursor', 'topline'
        mode = "cursor",
        -- Separator between context and content. Should be a single character string, like '-'.
        -- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
        separator = nil,
        zindex = 20, -- The Z-index of the context window
        on_attach = nil, -- (fun(buf: integer): boolean) return false to disable attaching
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    lazy = true,
    event = "BufRead",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-treesitter.configs").setup({
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
        },
      })
    end,
  },

  -- needed
  "wsdjeg/vim-fetch",

  -- unneeded
  {
    "mg979/vim-visual-multi",
    lazy = false,
    config = function()
      vim.g.VM_mouse_mappings = 1
      vim.g.VM_default_mappings = 1
      vim.g.VM_leader = "\\"
    end,
  },

  {

  },
  {
    "tpope/vim-surround",
    lazy = false,
    init = function()
      vim.g.surround_no_mappings = 1
      vim.keymap.set("n", "dx", "<Plug>Dsurround")
      vim.keymap.set("n", "cx", "<Plug>Csurround")
      vim.keymap.set("n", "cX", "<Plug>CSurround")
      vim.keymap.set("n", "yx", "<Plug>Ysurround")
      vim.keymap.set("n", "yX", "<Plug>YSurround")
      vim.keymap.set("n", "yxs", "<Plug>Yssurround")
      vim.keymap.set("n", "yXs", "<Plug>YSsurround")
      vim.keymap.set("n", "yXS", "<Plug>YSsurround")
      vim.keymap.set("x", "X", "<Plug>VSurround")
      vim.keymap.set("x", "gX", "<Plug>VgSurround")
    end,
  },
  { "tpope/vim-fugitive", lazy = false },
  { "tpope/vim-repeat", lazy = false },
  { "tpope/vim-sleuth", lazy = false },

  -- get this
  {
    "ggandor/leap.nvim",
    lazy = false,
    dependencies = { "nvim-treesitter/nvim-treesitter", "tpope/vim-repeat" },
    config = function()
      -- require('leap').create_default_mappings()
      vim.keymap.set({ "n", "x", "o" }, "s", "<Plug>(leap-forward)")
      vim.keymap.set({ "n", "x", "o" }, "S", "<Plug>(leap-backward)")
      vim.keymap.set({ "n", "x", "o" }, "gs", "<Plug>(leap-from-window)")

      local api = vim.api
      local ts = vim.treesitter

      local function get_ts_nodes()
        if not pcall(ts.get_parser) then
          return
        end
        local wininfo = vim.fn.getwininfo(api.nvim_get_current_win())[1]
        -- Get current node, and then its parent nodes recursively.
        local cur_node = ts.get_node()
        if not cur_node then
          return
        end
        local nodes = { cur_node }
        local parent = cur_node:parent()
        while parent do
          table.insert(nodes, parent)
          parent = parent:parent()
        end
        -- Create Leap targets from TS nodes.
        local targets = {}
        local startline, startcol
        for _, node in ipairs(nodes) do
          startline, startcol, endline, endcol = node:range() -- (0,0)
          local startpos = { startline + 1, startcol + 1 }
          local endpos = { endline + 1, endcol + 1 }
          -- Add both ends of the node.
          if startline + 1 >= wininfo.topline then
            table.insert(targets, { pos = startpos, altpos = endpos })
          end
          if endline + 1 <= wininfo.botline then
            table.insert(targets, { pos = endpos, altpos = startpos })
          end
        end
        if #targets >= 1 then
          return targets
        end
      end

      local function select_node_range(target)
        local mode = api.nvim_get_mode().mode
        -- Force going back to Normal from Visual mode.
        if not mode:match("no?") then
          vim.cmd("normal! " .. mode)
        end
        vim.fn.cursor(unpack(target.pos))
        local v = mode:match("V") and "V" or mode:match("�") and "�" or "v"
        vim.cmd("normal! " .. v)
        vim.fn.cursor(unpack(target.altpos))
      end

      local function leap_ts()
        require("leap").leap({
          target_windows = { api.nvim_get_current_win() },
          targets = get_ts_nodes,
          action = select_node_range,
        })
      end

      vim.keymap.set({ "n", "x", "o" }, "<Space>s", leap_ts)
    end,
  },

  -- get this
  {
    "sbdchd/neoformat",
    lazy = true,
    cmd = "Neoformat",
    event = "BufRead",
    config = function()
      vim.g.neoformat_basic_format_align = 1
      vim.g.neoformat_basic_format_retab = 1
      vim.g.neoformat_basic_format_trim = 1
      vim.g.neoformat_enabled_markdown = { "remark" }
    end,
  },

  "kana/vim-textobj-user",
  { "kana/vim-textobj-syntax", lazy = false, dependencies = { "kana/vim-textobj-user" } },
  { "Julian/vim-textobj-variable-segment", lazy = false, dependencies = { "kana/vim-textobj-user" } },

  {
    "mbbill/undotree",
    lazy = false,
    init = function()
      if vim.fn.has("persistent_undo") == 1 then
        local target_path = vim.fn.expand("~/.undodir")

        -- Create the directory and any parent directories
        -- if the location does not exist.
        if vim.fn.isdirectory(target_path) == 0 then
          vim.fn.mkdir(target_path, "p", 0700)
        end

        vim.o.undodir = target_path
        vim.o.undofile = true

        vim.keymap.set("n", "<F5>", ":TSContextToggle<CR>:UndotreeToggle<CR>")
      end
    end,
  },

  {
    "preservim/nerdcommenter",
    lazy = false,
    config = function()
      -- Add spaces after comment delimiters by default
      vim.g.NERDSpaceDelims = 1

      -- Use compact syntax for prettified multi-line comments
      vim.g.NERDCompactSexyComs = 1

      -- Align line-wise comment delimiters flush left instead of following code indentation
      vim.g.NERDDefaultAlign = "left"

      -- Enable trimming of trailing whitespace when uncommenting
      vim.g.NERDTrimTrailingWhitespace = 1

      -- Set a keymap for toggling comments
      vim.keymap.set(
        { "n", "v" },
        "<C-/>",
        ':call nerdcommenter#Comment("n", "toggle")<CR>',
        { noremap = true, silent = true }
      )
    end,
  },

  -- needed for lsp
  {
    "hrsh7th/nvim-cmp",
    lazy = true,
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-nvim-lsp-signature-help",
      "L3MON4D3/LuaSnip",
    },
    config = function()
      -- Setup nvim-cmp.
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      local has_words_before = function()
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
      end

      local feedkey = function(key, mode)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), mode, true)
      end

      cmp.setup({
        completion = { completeopt = "menu,menuone,noselect" },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
          -- documentation = null,
        },

        get_trigger_characters = function(trigger_characters)
          return trigger_characters .. ".:"
        end,
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-d>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["\\:~\\ctrl+space"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.close(),
          ["<CR>"] = cmp.mapping.confirm({
            -- behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          }),

          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            elseif has_words_before() then
              cmp.complete()
            else
              fallback()
            end
          end, { "i", "s" }),

          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.get_active_entry() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sorting = {
          priority_weight = 2,
          comparators = {

            -- Below is the default comparitor list and order for nvim-cmp
            cmp.config.compare.offset,
            -- cmp.config.compare.scopes, --this is commented in nvim-cmp too
            cmp.config.compare.exact,
            cmp.config.compare.score,
            cmp.config.compare.recently_used,
            cmp.config.compare.locality,
            cmp.config.compare.kind,
            cmp.config.compare.sort_text,
            cmp.config.compare.length,
            cmp.config.compare.order,
          },
        },
        preselect = cmp.PreselectMode.None,
        sources = {
          { name = "nvim_lsp" },
          { name = "crates" },
          { name = "nvim_lsp_signature_help" },
        },
        experimental = {
          ghost_text = false, -- this feature conflict with copilot.vim's preview.
        },
      })
    end,
  },

  -- needed for lsp
  {
    "neovim/nvim-lspconfig",
    dependencies = { "hrsh7th/nvim-cmp" },
    lazy = true,
    event = "FileType nix",

    config = function()
      local lspconfig = require("lspconfig")

      local capabilities = vim.tbl_deep_extend(
        "force",
        vim.lsp.protocol.make_client_capabilities(),
        require("cmp_nvim_lsp").default_capabilities()
      )

      -- lspconfig.nil_ls.setup({
      --   capabilities = capabilities,
      -- })

      require("lspconfig").nixd.setup({
        capabilities = capabilities,
      })
    end,
  },
  -- needed for lsp
  {
    "mrcjkb/rustaceanvim",
    version = "^4", -- Recommended
    lazy = false, -- This plugin is already lazy
    init = function()
      vim.g.rustaceanvim = {
        server = {
          -- logfile = "/tmp/rustaceanvim.log",
          on_attach = function(_, bufnr)
            vim.keymap.set("n", "<Space>a", function()
              vim.cmd.RustLsp("codeAction")
            end, { silent = true, buffer = bufnr })

            vim.keymap.set("n", "<C-.>", function()
              vim.cmd.RustLsp("codeAction")
            end, { silent = true, buffer = bufnr })

            vim.keymap.set("n", "J", function()
              vim.cmd.RustLsp("joinLines")
            end, { buffer = bufnr })
            vim.keymap.set("n", "<Space>S", function()
              vim.cmd.RustLsp("ssr")
            end, { buffer = bufnr })
            vim.keymap.set("n", "<Space>E", function()
              vim.cmd.RustLsp("expandMacro")
            end, { buffer = bufnr })
            vim.keymap.set("n", "<Space>t", function()
              vim.cmd.RustLsp({ "testables", bang = true })
            end, { buffer = bufnr })
            vim.keymap.set("n", "<Space>T", function()
              vim.cmd.RustLsp("testables")
            end, { buffer = bufnr })
            vim.keymap.set("v", "K", function()
              vim.cmd.RustLsp({ "hover", "range" })
            end, { buffer = bufnr })
            vim.keymap.set("n", "<Space><Space>", function()
              -- vim.cmd.RustLsp("renderDiagnostic")
              vim.diagnostic.open_float()
            end, { buffer = bufnr })
            vim.keymap.set("n", "<Space>pm", function()
              vim.cmd.RustLsp("parentModule")
            end, { buffer = bufnr })
            vim.keymap.set("n", "gO", function()
              vim.cmd.RustLsp("openDocs")
            end, { buffer = bufnr })
          end,

          default_settings = {
            ["rust-analyzer"] = {
              -- buildScripts = { enable = false },
              procMacro = {
                enable = true,
                attributes = { enable = true },
                ignored = {
                  ["async-trait"] = { "async_trait" },
                  ["napi-derive"] = { "napi" },
                  ["async-recursion"] = { "async_recursion" },
                  ["rasn-derive"] = { "AsnType" },
                },
              },
              lru = { capacity = 512 },
              completion = { privateEditable = { enable = true } },
              cargo = {
                allFeatures = false,
                loadOutDirsFromCheck = true,
                runBuildScripts = true,
                sysrootQueryMetadata = false,

                -- extraEnv = {},
                -- noDefaultFeatures = false,
                -- features = [ "default", "serde", ],
              },
              checkOnSave = { command = "clippy" },
              -- checkOnSave = false,
              diagnostics = { styleLints = { enable = true } },
            },
          },
        },
      }
    end,
  },
  {
    "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    config = function()
      require("lsp_lines").setup()

      vim.diagnostic.config({ virtual_text = true, virtual_lines = false })
      local function toggle_virtual_diagnostics_fmt()
        local current_config = vim.diagnostic.config()

        vim.diagnostic.config({
          virtual_text = not current_config.virtual_text,
          virtual_lines = not current_config.virtual_lines,
        })
      end

      vim.keymap.set("", "<leader>l", toggle_virtual_diagnostics_fmt, {
        desc = "Toggle between lsp_lines and diagnostic virtual text/lines",
      })
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.6",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      local telescope = require("telescope")

      telescope.setup({
        extensions = {
          fzf = {
            fuzzy = true, -- false will only do exact matching
            override_generic_sorter = true, -- override the generic sorter
            override_file_sorter = true, -- override the file sorter
            case_mode = "smart_case", -- or "ignore_case" or "respect_case"
            -- the default case_mode is "smart_case"
          },
        },
      })

      require("telescope").load_extension("fzf")

      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "gr", builtin.lsp_references, {})
      vim.keymap.set("n", "gd", builtin.lsp_definitions, {})
      vim.keymap.set("n", "gy", builtin.lsp_type_definitions, {})
      vim.keymap.set("n", "gi", builtin.lsp_implementations, {})

      vim.keymap.set("n", "<Space>f", builtin.find_files, {})
      vim.keymap.set("n", "<Space>b", builtin.buffers, {})
      vim.keymap.set("n", "<Space>d", function()
        builtin.diagnostics({ bufnr = 0 })
      end, {})
      vim.keymap.set("n", "<Space>D", builtin.diagnostics, {})
      local grep_visual_selection = function()
        local cword = nil
        if vim.fn.mode() == "v" then
          vim.cmd('noau normal! "vy"')
          cword = vim.fn.getreg("v")
        else
          cword = vim.fn.expand("<cword>")
        end

        require("telescope.builtin").live_grep({
          default_text = cword,
        })
      end

      vim.keymap.set({ "n", "x" }, "<Space>g", grep_visual_selection)

      vim.api.nvim_create_user_command("Rg", function(opts)
        if opts.args == "" then
          builtin.live_grep()
        else
          builtin.grep_string({ search = opts.args })
        end
      end, { nargs = "?" })
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    lazy = true,
    event = "VeryLazy",
    cond = not vim.g.vscode,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          icons_enabled = true,
          -- theme = "solarized_dark",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = {
            statusline = {},
            winbar = {},
          },
          ignore_focus = {},
          always_divide_middle = true,
          globalstatus = false,
          refresh = {
            statusline = 1000,
            tabline = 1000,
            winbar = 1000,
          },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = {},
          lualine_y = {},
          lualine_z = { "location" },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = {},
          lualine_y = {},
          lualine_z = { "location" },
        },
        tabline = {},
        winbar = {},
        inactive_winbar = {},
        extensions = {},
      })
    end,
  },
}, {
  diff = {
    cmd = "browser",
  },
})

-- common

local function setup_command_alias(from, to)
  vim.cmd(string.format(
    [[
    cnoreabbrev <expr> %s
    \ ((getcmdtype() == ":" && getcmdline() == "%s")
    \ ? ("%s") : ("%s"))
  ]],
    from,
    from,
    to,
    from
  ))
end

setup_command_alias("W", "w")
setup_command_alias("Wq", "wq")
setup_command_alias("Q", "q")
setup_command_alias("Bd", "bd")
setup_command_alias("B", "b")
setup_command_alias("Vsp", "vsp")
setup_command_alias("neoformat", "Neoformat")

-- Vim Options
-- vim.o.background = "dark"
-- vim.cmd.colorscheme("solarized")
vim.opt.termguicolors = true

vim.opt.clipboard = "unnamedplus"

vim.opt.showmatch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.tabstop = 2
vim.opt.smarttab = true

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.mouse = "nv"

vim.opt.number = true

vim.opt.wildmenu = true
vim.opt.wildmode = "full"

vim.opt.inccommand = "nosplit"
vim.opt.incsearch = true
vim.opt.wrapscan = true

vim.opt.hidden = true

vim.opt.signcolumn = "yes"

vim.opt.scrolloff = 5

-- common keybindings
vim.keymap.set("n", "<Space>r", ":%s//g<Left><Left>")
vim.keymap.set("v", "<Space>r", ":s/\\%V/g<Left><Left>")

vim.keymap.set("t", "<Leader><Esc>", "<C-\\><C-n>")

-- Space hjkl to move between panes
vim.keymap.set("n", "<Space>h", "<C-w>h")
vim.keymap.set("n", "<Space>j", "<C-w>j")
vim.keymap.set("n", "<Space>k", "<C-w>k")
vim.keymap.set("n", "<Space>l", "<C-w>l")

vim.keymap.set("n", "<F1>", ":set spell!<CR>")

-- enable spell check for git and markdown
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "gitcommit", "markdown" },
  command = "setlocal spell",
})

vim.api.nvim_create_autocmd({ "VimResized" }, {
  pattern = "*",
  command = "wincmd =",
})

if vim.g.vscode then
  local vscode = require("vscode-neovim")
  -- VSCode extension
  vim.keymap.set("n", "gy", function()
    vscode.action("editor.action.goToTypeDefinition")
  end)
  vim.keymap.set("n", "gD", function()
    vscode.action("editor.action.goToDeclaration")
  end)
  vim.keymap.set("n", "gi", function()
    vscode.action("editor.action.goToImplementation")
  end)
  vim.keymap.set("n", "gr", function()
    vscode.action("editor.action.goToReferences")
  end)

  vim.keymap.set("n", "<C-s>", function()
    vscode.action("workbench.action.files.save")
  end)
else
  -- ordinary Neovim
  vim.keymap.set("i", "jk", "<ESC>")
  vim.keymap.set("n", "<C-s>", ":w<CR>")

  local opts = { noremap = true, silent = true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  vim.keymap.set("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
  -- vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
  vim.keymap.set("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
  -- vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  vim.keymap.set("i", "<C-h>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
  vim.keymap.set("n", "<space>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
  vim.keymap.set("n", "<space>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
  vim.keymap.set("n", "<space>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
  vim.keymap.set("n", "<f2>", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
  vim.keymap.set("n", "<space>", "<cmd>lua vim.diagnostic.open_float()<CR>", opts)
  vim.keymap.set("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
  vim.keymap.set("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)
  vim.keymap.set(
    "n",
    "<C-s>",
    "<cmd>lua vim.lsp.buf.format { async = false }<CR>:w<CR>",
    { noremap = true, silent = true }
  )
end

function DiffAgainstFileOnDisk()
  vim.cmd("w! /tmp/working_copy")
  vim.cmd("terminal delta /tmp/working_copy %")
end

vim.api.nvim_create_user_command("DiffAgainstFileOnDisk", function()
  DiffAgainstFileOnDisk()
end, {})

-- Relative numbering
local function number_toggle()
  if vim.wo.relativenumber == true then
    vim.wo.relativenumber = false
    vim.wo.number = true
  else
    vim.wo.relativenumber = true
  end
end

-- Toggle between normal and relative numbering
vim.keymap.set("n", "<leader>r", number_toggle, { noremap = true, silent = true })

-- Start in relativenumber mode
number_toggle()
