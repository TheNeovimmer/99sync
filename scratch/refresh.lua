---@diagnostic disable-next-line: undefined-global
R("99sync")
local _99sync = require("99sync")
local Window = require("99sync.window")
_99sync.setup({
  completion = {
    custom_rules = {
      "~/personal/skills/skills",
    },
    source = "cmp",
  },
})

Window.capture_input("test", {
  cb = function(_, _)
    print("results")
  end,
  on_load = function()
    print("on_load")
    require("99sync.extensions").setup_buffer(require("99sync").__get_state())
  end,
  rules = _99sync.__get_state().rules,
})
