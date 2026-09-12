-- luacheck: globals describe it assert
local _99sync = require("99sync")
local test_utils = require("99sync.test.test_utils")
local Prompt = require("99sync.prompt")
local eq = assert.are.same

local content = {
  "local function foo()",
  "    -- TODO: implement",
  "end",
}

describe("request test", function()
  it("should replace visual selection with AI response", function()
    local p = test_utils.test_setup(content, 2, 1, "lua")
    local state = _99sync.__get_state()

    local context = Prompt.search(state)
    context:finalize()

    local finished_called = false
    local finished_status = nil

    eq("ready", context.state)

    eq(0, state.tracking:active_count())
    context:start_request({
      on_start = function()
        print("on_start")
      end,
      on_complete = function(status, _)
        finished_called = true
        finished_status = status
      end,
      on_stdout = function() end,
      on_stderr = function() end,
    })
    test_utils.next_frame()
    eq(1, state.tracking:active_count())

    eq("requesting", context.state)

    p:resolve("success", "    return 'implemented!'")
    assert.is_true(finished_called)

    eq(0, state.tracking:active_count())
    eq("success", context.state)
    eq("success", finished_status)
  end)
end)
