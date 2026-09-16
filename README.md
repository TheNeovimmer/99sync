# 99sync

Agentic AI workflow for Neovim. Search, vibe-code, and edit visually — without leaving your editor.

> Hand-coding stays the default. AI handles the boring traversal.

Maintained by [TheNeovimmer](https://github.com/TheNeovimmer). `TheNeovimmer/99sync`. MIT. Beta.

## Why 99sync

Most AI plugins replace your workflow. 99sync augments it:

- `search` first — ask about your codebase, get a quickfix list of locations + notes.
- `vibe` when you want the agent to make the edits, then you review the diff.
- `visual` when you want to replace exactly what you selected, nothing more.
- `Worker` to pin one unit of work while you `search` what is left.

No API keys in the plugin. 99sync shells out to the CLI you already authenticated (`opencode`, `claude`, `cursor-agent`, `kiro-cli`, `gemini`).

## How it works

| Operation | You do | You get |
|---|---|---|
| `search` | Ask a question | Quickfix locations + notes, jumpable with `:copen` |
| `vibe` | Describe the change | Edits applied in place, review with `git diff` |
| `visual` | Select code + prompt | Selection replaced with the result |
| `open` | Revisit history | Re-open quickfix for any prior `search` / `vibe` |

In-flight requests show a spinner. `stop_all_requests()` kills the CLI process and discards the result. `clear_previous_requests()` clears history.

## Requirements

- Neovim 0.10+ (`vim.system` API)
- One backend CLI for the provider you use: `opencode` (default), `claude`, `cursor-agent`, `kiro-cli`, or `gemini`
- Optional: `snacks.nvim` or `fzf-lua` for model/provider pickers (falls back to `vim.ui.select`)
- Optional: `nvim-cmp` or `blink.cmp` for `#` / `@` completion (zero-dep `native` built in)
- Optional: `plenary.nvim` for running tests

## Installation

Minimal (`native` completion, zero extra deps):

```lua
{
  "TheNeovimmer/99sync",
  keys = {
    { "<leader>9s", function() require("99sync").search() end, mode = "n", desc = "99sync: Search codebase" },
    { "<leader>9b", function() require("99sync").vibe() end,   mode = "n", desc = "99sync: Vibe" },
    { "<leader>9v", function() require("99sync").visual() end,  mode = "v", desc = "99sync: Work on selection" },
    { "<leader>9o", function() require("99sync").open() end,    mode = "n", desc = "99sync: Open last request" },
    { "<leader>9x", function() require("99sync").stop_all_requests() end,     mode = "n", desc = "99sync: Stop requests" },
    { "<leader>9c", function() require("99sync").clear_previous_requests() end, mode = "n", desc = "99sync: Clear requests" },
  },
  config = function()
    require("99sync").setup({ tmp_dir = "./tmp" })
  end,
}
```

> `tmp_dir` must stay inside the cwd — `opencode` / Claude refuse external dirs by default (see [opencode permissions](https://opencode.ai/docs/permissions/#external-directories)).

<details>
<summary>Full config with defaults</summary>

```lua
require("99sync").setup({
  provider = require("99sync").Providers.OpenCodeProvider, -- default; switch live with select_provider()
  -- model = "opencode/big-pickle", -- omit to use provider default (self-heals to first available)
  -- provider_extra_args = { "--no-session-persistence" }, -- appended to every provider command
  tmp_dir = "./tmp", -- keep inside cwd
  md_files = { "AGENT.md" }, -- auto-attached by walking up from the request file
  display_errors = true,
  auto_add_skills = true,
  completion = {
    source = "native", -- "native" | "cmp" | "blink"
    custom_rules = {}, -- dirs of <name>/SKILL.md for `#` completion
    files = {
      enabled = true,
      max_file_size = 102400,
      max_files = 5000,
      exclude = { ".git", ".env", ".env.*", "node_modules", "dist", "build", "target", ".next", ".turbo", "coverage", "vendor" },
    },
  },
  logger = {
    level = require("99sync").INFO, -- DEBUG for bug reports
    type = "file",
    path = vim.fn.stdpath("state") .. "/99sync.log",
    print_on_error = true,
    max_requests_cached = 20,
  },
  in_flight_options = { enable = true }, -- spinner for active requests
})
```

For `blink.cmp` add `{ "saghen/blink.compat", version = "2.*" }` to `dependencies` and set `source = "blink"`.

</details>

## Quickstart

1. Install + authenticate a backend, e.g. `opencode`.
2. `<leader>9s` → type a question → `:copen` to walk the quickfix results.
3. `<leader>9b` when you want edits applied, then `git diff` to review.
4. `v` + `<leader>9v` to replace only the visual selection.
5. `<leader>9x` cancels everything in flight. `<leader>9m` / `<leader>9p` switch model / provider live.

Skip the prompt window programmatically:

```lua
require("99sync").search({ additional_prompt = "run `make test` and explain failures" })
require("99sync").vibe({ additional_prompt = "fix the failing tests" })
```

## Worker: one thing at a time

Pin the work item, then repeatedly search what is left:

```lua
local Worker = require("99sync").Extensions.Worker
Worker.set_work({ description = "migrate auth to sessions" })
Worker.search() -- what is left for current work (diff + commits + tests aware)
Worker.vibe()   -- implement the next slice
```

`Worker.update_work()` re-opens the prompt to edit the item.

## Completions

In the prompt buffer:

- `#` completes rule/skill files from `completion.custom_rules` (each `<dir>/<name>/SKILL.md`).
- `@` fuzzy-finds project files (`git ls-files` in repos, filesystem scan otherwise) and injects content.

Works with `source = "native"`. Set `"cmp"` or `"blink"` for your completion framework.

## Providers

Set once in `setup`, or switch live (resets model to the new provider default for the session):

```lua
vim.keymap.set("n", "<leader>9m", function() require("99sync.extensions.snacks").select_model() end)
vim.keymap.set("n", "<leader>9p", function() require("99sync.extensions.snacks").select_provider() end)
-- fzf-lua variant: require("99sync.extensions.fzf_lua").select_model() / .select_provider()
-- both fall back to vim.ui.select when the picker plugin is absent
```

| Provider | CLI | Default model (Sep 2026) |
|---|---|---|
| `OpenCodeProvider` (default) | `opencode` | `opencode/big-pickle` |
| `ClaudeCodeProvider` | `claude` | `claude-fable-5-1` |
| `CursorAgentProvider` | `cursor-agent` | `grok-4.6` |
| `KiroProvider` | `kiro-cli` | `claude-fable-5-1` |
| `GeminiCLIProvider` | `gemini` | `gemini-3.8-flash` |

```lua
require("99sync").setup({
  provider = require("99sync").Providers.ClaudeCodeProvider,
  model = "claude-fable-5-1", -- optional override
})
```

Notes:

- `opencode` lists via `opencode models`, Cursor via `cursor-agent models`. Claude Code has no list endpoint, so its picker uses a curated list (`claude-fable-5-1`, `claude-mythos-5-1`).
- If the configured default model is missing, `setup()` falls back to the first listed model and notifies you.

## API

| Function | Purpose |
|---|---|
| `setup(opts?)` | Must be called once |
| `search(opts?)` / `vibe(opts?)` / `visual(opts?)` | Prompt (or pass `{ additional_prompt }` to skip it) |
| `open()` | Pick a prior `search` / `vibe` and reopen its quickfix |
| `view_logs()` | Pick a request and inspect per-request debug logs |
| `stop_all_requests()` / `clear_previous_requests()` | Cancel in-flight / clear history |
| `get_model()` / `set_model(m)` / `get_provider()` / `set_provider(p)` | Read/override model + backend |

## Troubleshooting

1. `:checkhealth 99sync` — fixes missing CLI, bad model, unwritable `tmp_dir`.
2. Repro with `logger.level = require("99sync").DEBUG`, then `:lua require("99sync").view_logs()` and open the failing request.
3. File an issue at `TheNeovimmer/99sync` with: what you ran, expected vs actual, backend version (`opencode --version`, …), model, and redacted logs (strip secrets).

## Status

Beta. Request lifecycle and prompt flow are stable; prompt text and minor APIs may still change. Pin a commit for reproducibility. Roadmap lives in [TODO.md](./TODO.md).

## License

MIT — see [LICENSE](./LICENSE).
