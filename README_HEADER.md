# 99sync

Agentic AI workflow for Neovim. Search, vibe-code, and edit visually without leaving your editor.

Maintained by [TheNeovimmer](https://github.com/TheNeovimmer). Repo: `TheNeovimmer/99sync`.

## Why 99sync

99sync melds traditional coding ("tradcoding") with LLMs. Instead of replacing you, it augments you:

- `search` first: ask a question about your codebase, get back quickfix locations with notes.
- `vibe` when you want the agent to make the edits.
- `visual` when you want to replace exactly what you selected.
- `Worker` to keep one unit of work pinned while you search what is left.

Hand-coding stays the default. AI handles the boring traversal.

## Features

- Project-wide `search` -> quickfix list with notes
- `vibe` sessions that apply edits you can review
- `visual` selection replace
- Persistent `Worker` (`set_work` + `search` what is left)
- `#rule` and `@file` completions in the prompt buffer (native, cmp, or blink)
- Multiple CLI backends: OpenCode (default), Claude Code, Cursor Agent, Kiro, Gemini CLI
- Telescope / fzf-lua pickers to switch model and provider live
- Request tracking, cancel-all, and per-request debug logs

## Requirements

- Neovim 0.10+ (`vim.system` API)
- One or more agent CLIs, depending on provider: `opencode`, `claude`, `cursor-agent`, `kiro-cli`, `gemini`
- Optional: `telescope.nvim` or `fzf-lua` for pickers, `nvim-cmp` or `blink.cmp` for completion
- Optional: `plenary.nvim` for running tests

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim) (lazy-loads on first keypress):

```lua
{
  "TheNeovimmer/99sync",
  keys = {
    { "<leader>9s", function() require("99sync").search() end, mode = "n", desc = "99sync: Search codebase" },
    { "<leader>9v", function() require("99sync").visual() end, mode = "v", desc = "99sync: Work on selection" },
    { "<leader>9b", function() require("99sync").vibe() end, mode = "n", desc = "99sync: Vibe" },
    { "<leader>9o", function() require("99sync").open() end, mode = "n", desc = "99sync: Open last request" },
    { "<leader>9x", function() require("99sync").stop_all_requests() end, mode = "n", desc = "99sync: Stop requests" },
    { "<leader>9c", function() require("99sync").clear_previous_requests() end, mode = "n", desc = "99sync: Clear requests" },
    { "<leader>9l", function() require("99sync").view_logs() end, mode = "n", desc = "99sync: View logs" },
    { "<leader>9m", function() require("99sync.extensions.telescope").select_model() end, mode = "n", desc = "99sync: Select model" },
    { "<leader>9p", function() require("99sync.extensions.telescope").select_provider() end, mode = "n", desc = "99sync: Select provider" },
  },
  dependencies = {
    { "saghen/blink.compat", version = "2.*" }, -- only needed for blink completion
  },
  config = function()
    local _99sync = require("99sync")
    _99sync.setup({
      provider = _99sync.Providers.OpenCodeProvider, -- default; switch live with <leader>9p
      tmp_dir = "./tmp", -- keep inside cwd to avoid CLI permission blocks
      md_files = { "AGENT.md" },
      completion = {
        source = "blink", -- "native" (zero-dep), "cmp", or "blink"
        custom_rules = {},
        files = {
          enabled = true,
          max_file_size = 102400,
          max_files = 5000,
          exclude = { ".git", ".env", ".env.*", "node_modules", "dist", "build", "target", ".next", ".turbo", "coverage", "vendor" },
        },
      },
      display_errors = true,
      auto_add_skills = true,
      logger = {
        level = _99sync.INFO,
        type = "file",
        path = vim.fn.stdpath("state") .. "/99sync.log",
        print_on_error = true,
        max_requests_cached = 20,
      },
      in_flight_options = { enable = true },
    })
  end,
}
```

Prefer zero dependencies? Set `completion.source = "native"` and drop `dependencies`.

## Quickstart

1. Install a backend, e.g. `opencode` and authenticate it.
2. Open a project, select code (for `visual`) or not (for `search`/`vibe`).
3. `<leader>9s` -> type your question -> quickfix list fills with locations + notes -> `:copen` to review.
4. `<leader>9b` (`vibe`) when you want edits applied, then review the diff.
5. `v` + `<leader>9v` to replace only the visual selection.
6. `<leader>9x` cancels all in-flight requests, `<leader>9c` clears history.
7. `<leader>9l` views logs, `<leader>9m` / `<leader>9p` switch model / provider live.

Programmatic, no prompt window:

```lua
_99sync.search({ additional_prompt = "run `make test` and explain failures" })
_99sync.vibe({ additional_prompt = "fix the failing tests" })
```

## Worker: one thing at a time

```lua
local Worker = require("99sync").Extensions.Worker
Worker.set_work({ description = "migrate auth to sessions" })
Worker.search() -- finds what is left for current work
```

## Status

Beta. The prompt flow and request lifecycle are stable; prompt text and minor APIs may still change. Pin a commit if you need reproducibility.

___DOCS___

## Completions

In the prompt buffer:

- `#` completes rule/skill files from `completion.custom_rules` (each `<dir>/<name>/SKILL.md`).
- `@` fuzzy-finds project files (`git ls-files` in git repos, filesystem scan otherwise) and injects content.

Works out of the box with `source = "native"`. For `nvim-cmp` set `source = "cmp"`, for `blink.cmp` set `source = "blink"`.

## Providers

99sync shells out to AI CLIs. Set `provider` in `setup`. If `model` is unset, the provider default below is used (current as of Sep 2026).

| Provider | CLI tool | Default model |
|---|---|---|
| `OpenCodeProvider` (default) | `opencode` | `opencode/big-pickle` |
| `ClaudeCodeProvider` | `claude` | `claude-fable-5-1` |
| `CursorAgentProvider` | `cursor-agent` | `grok-4.6` |
| `KiroProvider` | `kiro-cli` | `claude-fable-5-1` |
| `GeminiCLIProvider` | `gemini` | `gemini-3.8-flash` |

```lua
_99sync.setup({
  provider = _99sync.Providers.ClaudeCodeProvider,
  model = "claude-fable-5-1", -- optional override
})
```

Notes:

- OpenCode `fetch_models` shells `opencode models`; Cursor shells `cursor-agent models`. Claude Code has no list endpoint, so its picker uses a curated Sep 2026 list (`claude-fable-5-1`, `claude-mythos-5-1`, plus 4.x fallbacks).
- `provider_extra_args = { "--no-session-persistence" }` in `setup` appends raw flags to every provider command.

## Extensions

### Telescope

```lua
vim.keymap.set("n", "<leader>9m", function()
  require("99sync.extensions.telescope").select_model()
end)
vim.keymap.set("n", "<leader>9p", function()
  require("99sync.extensions.telescope").select_provider()
end)
```

### fzf-lua

```lua
vim.keymap.set("n", "<leader>9m", function()
  require("99sync.extensions.fzf_lua").select_model()
end)
vim.keymap.set("n", "<leader>9p", function()
  require("99sync.extensions.fzf_lua").select_provider()
end)
```

Switching provider resets the model to that provider default for the session.

## Troubleshooting and bug reports

1. Repro with debug logging on (`logger.level = _99sync.DEBUG`).
2. Run `:lua require("99sync").view_logs()`, pick the failing request.
3. Open an issue at `TheNeovimmer/99sync` with: what you ran, expected vs actual, backend (`opencode --version` etc.), model, and redacted logs (strip secrets/`query` if needed).

`stop_all_requests()` kills the underlying CLI process; the result is discarded. `clear_previous_requests()` clears history.
