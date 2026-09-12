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

# 99sync
The AI Neovim experience

## _99sync
99sync is an agentic workflow that is meant to meld the current programmers ability
with the amazing powers of LLMs.  Instead of being a replacement, its meant to
augment the programmer.

As of now, the direction of 99sync is to progress into agentic programming and surfacing
of information.  In the beginning and the original youtube video was about replacing
specific pieces of code.  The more i use 99sync the more i realize the better use is
through `search` and `work`

### Basic Setup
```lua
	{
		"TheNeovimmer/99sync",
		config = function()
			local _99sync = require("99sync")

            -- For logging that is to a file if you wish to trace through requests
            -- for reporting bugs, i would not rely on this, but instead the provided
            -- logging mechanisms within 99sync.  This is for more debugging purposes
            local cwd = vim.uv.cwd()
            local basename = vim.fs.basename(cwd)
			_99sync.setup({
                -- provider = _99sync.Providers.ClaudeCodeProvider,  -- default: OpenCodeProvider
				logger = {
					level = _99sync.DEBUG,
					path = "/tmp/" .. basename .. ".99sync.debug",
					print_on_error = true,
				},
                -- When setting this to something that is not inside the CWD tools
                -- such as claude code or opencode will have permission issues
                -- and generation will fail refer to tool documentation to resolve
                -- https://opencode.ai/docs/permissions/#external-directories
                -- https://code.claude.com/docs/en/permissions#read-and-edit
                tmp_dir = "./tmp",

                --- Completions: #rules and @files in the prompt buffer
                completion = {
                    -- I am going to disable these until i understand the
                    -- problem better.  Inside of cursor rules there is also
                    -- application rules, which means i need to apply these
                    -- differently
                    -- cursor_rules = "<custom path to cursor rules>"

                    --- A list of folders where you have your own SKILL.md
                    --- Expected format:
                    --- /path/to/dir/<skill_name>/SKILL.md
                    ---
                    --- Example:
                    --- Input Path:
                    --- "scratch/custom_rules/"
                    ---
                    --- Output Rules:
                    --- {path = "scratch/custom_rules/vim/SKILL.md", name = "vim"},
                    --- ... the other rules in that dir ...
                    ---
                    custom_rules = {
                      "scratch/custom_rules/",
                    },

                    --- Configure @file completion (all fields optional, sensible defaults)
                    files = {
                        -- enabled = true,
                        -- max_file_size = 102400,     -- bytes, skip files larger than this
                        -- max_files = 5000,            -- cap on total discovered files
                        -- exclude = { ".env", ".env.*", "node_modules", ".git", ... },
                    },

                    --- What autocomplete you use.
                    source = "cmp" | "blink",
                },

                --- WARNING: if you change cwd then this is likely broken
                --- ill likely fix this in a later change
                ---
                --- md_files is a list of files to look for and auto add based on the location
                --- of the originating request.  That means if you are at /foo/bar/baz.lua
                --- the system will automagically look for:
                --- /foo/bar/AGENT.md
                --- /foo/AGENT.md
                --- assuming that /foo is project root (based on cwd)
				md_files = {
					"AGENT.md",
				},
			})

            -- take extra note that i have visual selection only in v mode
            -- technically whatever your last visual selection is, will be used
            -- so i have this set to visual mode so i dont screw up and use an
            -- old visual selection
            --
            -- likely ill add a mode check and assert on required visual mode
            -- so just prepare for it now
			vim.keymap.set("v", "<leader>9v", function()
				_99sync.visual()
			end)

            --- if you have a request you dont want to make any changes, just cancel it
			vim.keymap.set("n", "<leader>9x", function()
				_99sync.stop_all_requests()
			end)

			vim.keymap.set("n", "<leader>9s", function()
				_99sync.search()
			end)
		end,
	},
```

### Usage
I would highly recommend trying out `search` as its the direction the library is going

```lua
_99sync.search()
```

See search for more details

### Description
| Name | Type | Default Value |
| --- | --- | --- |
| `setup` | `fun(opts?: _99sync.Options): nil` | - |
| `search` | `fun(opts: _99sync.ops.SearchOpts): _99sync.TraceID` | - |
| `vibe` | `fun(opts?: _99sync.ops.Opts): _99sync.TraceID \| nil` | - |
| `open` | `fun(): nil` | - |
| `visual` | `fun(opts: _99sync.ops.Opts): _99sync.TraceID` | - |
| `view_logs` | `fun(): nil` | - |
| `stop_all_requests` | `fun(): nil` | - |
| `clear_previous_requests` | `fun(): nil` | - |
| `Extensions` | `_99sync.Extensions` | - |

### API

#### setup
Sets up _99sync.  Must be called for this library to work.  This is how we setup
in flight request spinners, set default values, get completion to work the
way you want it to.

#### search
Performs a search across your project with the prompt you provide and return out a list of
locations with notes that will be put into your quick fix list.

#### vibe
will ask opencode or whatever provider currently being used to perform a vibe
session.

#### open
Opens a selection window for you to select the last interaction to open
and display its contents in a way that makes sense for its type.  For
search and vibe, it will open the qfix window.  For tutorial, it will open
the tutorial window.

#### visual
takes your current selection and sends that along with the prompt provided and replaces
your visual selection with the results

#### view_logs
view_logs allows you to select the request you want to see and then you
get to see the logs.

#### stop_all_requests
stops all in flight requests.  this means that the underlying process will
be killed (OpenCode) and any result will be discared

#### clear_previous_requests
clears all previous search and visual operations

#### Extensions
check out Worker for cool abstraction on search and vibe

## _99sync.Extensions.Worker
A persistent way to keep track of work.

this will likely be where the most change and focus goes into.  I would like
to take this into worktree territory and be able to swap between stuff super
slick.

Until then, it is going to be a single bit of work that you can provide
the description and then use search to find what is left that needs to be done.

### Description
| Name | Type | Default Value |
| --- | --- | --- |
| `set_work` | `fun(opts?: _99sync.WorkOpts): nil` | - |
| `search` | `fun(): nil` | - |

### API

#### set_work
will set the work for the project.  If opts provide a description then no
input capture of work description will be required

#### search
will use _99sync.search to find what is left to be done for this work item to be
considered done

## _99sync.ops.Opts
The options that are used throughout all the interations with 99sync.  This
includes search, visual, and others

### Description
| Name | Type | Default Value |
| --- | --- | --- |
| `additional_prompt` | `string \| nil` | - |
| `additional_rules` | `_99sync.Agents.Rule[] \| nil` | - |

### API

#### additional_prompt
by providing `additional_prompt` you will not be required to provide a prompt.
this allows you to define actions based on remaps

```lua
remap("n", "<leader>9d", function()
  --- this function could be used to auto debug your project
  _99sync.search({
    additional_prompt = [[
run `make test` and debug the test failures and provide me a comprehensive set of steps where
the tests are breaking ]]
  })
end)
```

This would kick off a search job that will run your tests in the background.
the resulting failures would be diagnosed and search results would be transfered
into a quick fix list.

#### additional_rules
can be used to provide extra args.  If you have a skill called "cloudflare" you could
provide the rule for cloudflare and its context will be injected into your request

## _99sync.ops.SearchOpts
See `_99sync.opts.Opts` for more information.

There are no properties yet.  But i would like to tweek some behavior based on opts

### Description
| Name | Type | Default Value |
| --- | --- | --- |
| - | - | - |

### API

## _99sync.StatusWindow.Opts
this is pure a class for testing.   helps controls timings

### Description
| Name | Type | Default Value |
| --- | --- | --- |
| `throbber_opts` | `_99sync.Throbber.Opts \| nil` | - |
| `in_flight_interval` | `number \| nil` | - |
| `enable` | `boolean \| nil` | - |

### API

#### throbber_opts
options for the throbber in the top left

#### in_flight_interval
frequency in which the in-flight interval checks to see if it should be
displayed / removed

#### enable
defaults to true

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
