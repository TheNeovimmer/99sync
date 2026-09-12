--- @class _99sync.ops.Opts
--- The options that are used throughout all the interations with 99sync.  This
--- includes search, visual, and others
---
--- @docs included
--- @field additional_prompt? string
--- by providing `additional_prompt` you will not be required to provide a prompt.
--- this allows you to define actions based on remaps
---
--- ```lua
--- remap("n", "<leader>9d", function()
---   --- this function could be used to auto debug your project
---   _99sync.search({
---     additional_prompt = [[
--- run `make test` and debug the test failures and provide me a comprehensive set of steps where
--- the tests are breaking ]]
---   })
--- end)
--- ```
---
--- This would kick off a search job that will run your tests in the background.
--- the resulting failures would be diagnosed and search results would be transfered
--- into a quick fix list.
--- @field additional_rules? _99sync.Agents.Rule[]
--- can be used to provide extra args.  If you have a skill called "cloudflare" you could
--- provide the rule for cloudflare and its context will be injected into your request

--- @class _99sync.ops.SearchOpts : _99sync.ops.Opts
--- See `_99sync.opts.Opts` for more information.
---
--- There are no properties yet.  But i would like to tweek some behavior based on opts
--- @docs included

return {
  search = require("99sync.ops.search"),
  tutorial = require("99sync.ops.tutorial"),
  over_range = require("99sync.ops.over-range"),
  vibe = require("99sync.ops.vibe"),
}
