-- luacheck: globals describe it assert
local _99sync = require("99sync")
local test_utils = require("99sync.test.test_utils")
local Prompt = require("99sync.prompt")
local eq = assert.are.same

describe("prompt", function()
  it("should deserialize a serialized prompt", function()
    local provider = test_utils.TestProvider.new()
    _99sync.setup(test_utils.get_test_setup_options({}, provider))

    local state = _99sync.__get_state()
    local prompt = Prompt.deserialize(state, {
      user_prompt = "find important changes",
      data = {
        type = "search",
        qfix_items = {},
        response = "",
      },
    })

    eq("search", prompt.operation)
    eq("search", prompt.data.type)
    eq("find important changes", prompt.user_prompt)
    eq("search: find important changes", prompt:summary())
  end)
end)
