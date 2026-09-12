# 99sync roadmap

Owned by TheNeovimmer. Community-focused: trust first, then workflow power.

## Shipped

- [x] Rebrand `99` -> `99sync` (`TheNeovimmer/99sync`, all requires, queries, syntax, docs)
- [x] Sep 2026 provider defaults (`opencode/big-pickle`, `claude-fable-5-1`, `grok-4.6`, `gemini-3.8-flash`)
- [x] Default-model self-heal on `setup()` + stderr tail in failure messages
- [x] Completion path fix (`99sync.extensions.*`), blink fallback to `native`
- [x] `snacks.nvim` picker replaces Telescope (`Snacks.picker.select` + `vim.ui.select` fallback)
- [x] `:checkhealth 99sync`, MIT LICENSE, CI (`lua_lint` + `lua_test`), tags `v0.1.0` / `v0.2.0`
- [x] Slim static README (no generated API dump)

## Next — trust killers (do these first)

- [ ] Quiet failures: downgrade CLI `fatal` assert to notification + quickfix with stderr tail
- [ ] Retry once on empty-stderr non-zero exit (crashed CLI vs bad prompt)
- [ ] `:checkhealth` follow-ups: verify `opencode models` actually lists the configured model
- [ ] `doc/99sync.txt` vimdoc (`:help 99sync`) generated from README sections
- [ ] 30s demo GIF in README (`search` -> quickfix -> jump)

## Workflow power (in order)

- [ ] Vibe diff preview before apply (git diff hunk under cursor, toggle)
- [ ] Editable search results (`[x]` done / delete line, reflected in Worker)
- [ ] `next("search" | "vibe" | "visual")` navigation + per-type history
- [ ] Persist `_99sync_state` fully across restarts (tracking serialize exists, finish restore UX)
- [ ] Failed/cancelled prompt recall (autofill last text for same operation)
- [ ] Action queue: if a non-status window is open, queue `copen` until it closes
- [ ] `open` picker filtering (`filter_keymap` -> index subset, keep original list)
- [ ] Search qfix notes as marks (smarter mark lifecycle per request)
- [ ] Follow-up sessions via `opencode serve --attach` + `--session` (replace one-shot `run`)
  - Default model for follow-ups: `opencode/big-pickle`
  - `opencode run --attach http://127.0.0.1:4096 --format json "prompt"`
  - `opencode run --attach ... --session ses_... --format json "follow-up"`

## Code health

- [ ] Slim `lua/99sync/init.lua` (~530 lines): extract setup example to `doc/`
- [ ] Fake-CLI test for `providers.make_request` failure path (asserts stderr tail surfaces)
- [ ] Decide `tutorial` op: document or cut (dead surface confuses contributors)
- [ ] `state of state`: finish JSON restore UX on top of existing `Tracking.serialize`
- [ ] Prompt via `prompt()` not raw string pass-through in provider

## Later / exploratory

- [ ] Vibe Work: `search` -> partial select -> `vibe`
- [ ] Vibe edits described to tmpfile -> quickfix list, live diff toggle
- [ ] Worktrees: parallel requests on mergeable worktrees instead of one cwd
- [ ] Marks + qfix truth: rebuild qfix from marks on every `open`, survive shifts + deserialize
