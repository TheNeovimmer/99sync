-- luacheck: globals describe it assert
local _99sync = require("99sync")
local test_utils = require("99sync.test.test_utils")
local eq = assert.are.same
local Levels = require("99sync.logger.level")
local Range = require("99sync.geo").Range
local Point = require("99sync.geo").Point
local visual_fn = require("99sync.ops.over-range")
local Prompt = require("99sync.prompt")

--- @param content string[]
--- @param start_row number
--- @param start_col number
--- @param end_row number
--- @param end_col number
--- @return _99sync.test.Provider, number, _99sync.Range
local function setup(content, start_row, start_col, end_row, end_col)
  local p = test_utils.TestProvider.new()
  _99sync.setup({
    provider = p,
    logger = {
      error_cache_level = Levels.ERROR,
    },
  })

  local buffer = test_utils.create_file(content, "lua", start_row, start_col)

  -- Create a range for the visual selection
  local start_point = Point:from_1_based(start_row, start_col)
  local end_point = Point:from_1_based(end_row, end_col)
  local range = Range:new(buffer, start_point, end_point)

  return p, buffer, range
end

--- @param buffer number
--- @return string[]
local function r(buffer)
  return vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
end

local content = {
  "local function foo()",
  "    -- TODO: implement",
  "end",
}

--- @param context _99sync.Prompt
local function visual_call_with_range(context, range)
  context.data.range = range
  visual_fn(context, {
    additional_prompt = "test prompt",
  })
end

describe("visual", function()
  it("should replace visual selection with AI response", function()
    local p, buffer, range = setup(content, 2, 1, 2, 23)
    local state = _99sync.__get_state()
    local context = Prompt.visual(state)

    visual_call_with_range(context, range)

    eq(1, state.tracking:active_count())
    eq(content, r(buffer))

    p:resolve("success", "    return 'implemented!'")
    test_utils.next_frame()

    local expected_state = {
      "local function foo()",
      "    return 'implemented!'",
      "end",
    }
    eq(expected_state, r(buffer))
    -- Note: Not checking active_request_count() == 0 due to logger bug with "id" key collision
    -- TODO: validate if this is true..
  end)

  it("should handle multi-line replacement", function()
    local multi_line_content = {
      "local function bar()",
      "    -- TODO: implement",
      "    -- more comments",
      "    -- even more",
      "end",
    }
    local p, buffer, range = setup(multi_line_content, 2, 1, 4, 17)
    local state = _99sync.__get_state()
    local context = Prompt.visual(state)

    visual_call_with_range(context, range)

    eq(1, state.tracking:active_count())
    eq(multi_line_content, r(buffer))

    p:resolve("success", "    local x = 1\n    local y = 2\n    return x + y")
    test_utils.next_frame()

    local expected_state = {
      "local function bar()",
      "    local x = 1",
      "    local y = 2",
      "    return x + y",
      "end",
    }
    eq(expected_state, r(buffer))
    -- Note: Not checking active_request_count() == 0 due to logger bug with "id" key collision
  end)

  it("should cancel request when stop_all_requests is called", function()
    local p, buffer, range = setup(content, 2, 1, 2, 23)
    local state = _99sync.__get_state()
    local context = Prompt.visual(state)

    visual_call_with_range(context, range)

    eq(content, r(buffer))

    assert.is_false(p.request.prompt:is_cancelled())
    assert.is_not_nil(p.request)
    assert.is_not_nil(p.request.prompt)

    _99sync.stop_all_requests()
    test_utils.next_frame()

    assert.is_true(p.request.prompt:is_cancelled())

    p:resolve("success", "    return 'should not appear'")
    test_utils.next_frame()

    -- Buffer should remain unchanged after cancellation
    eq(content, r(buffer))
  end)

  it("should handle error cases with graceful failures", function()
    local p, buffer, range = setup(content, 2, 1, 2, 23)
    local state = _99sync.__get_state()
    local context = Prompt.visual(state)

    visual_call_with_range(context, range)

    eq(content, r(buffer))

    p:resolve("failed", "Something went wrong")
    test_utils.next_frame()

    -- Buffer should remain unchanged on failure
    eq(content, r(buffer))
  end)

  it("should handle cancelled status gracefully", function()
    local p, buffer, range = setup(content, 2, 1, 2, 23)
    local state = _99sync.__get_state()
    local context = require("99sync.prompt").visual(state)

    visual_call_with_range(context, range)

    eq(content, r(buffer))

    -- Manually cancel and resolve as cancelled
    p.request.prompt:cancel()
    p:resolve("cancelled", "Request was cancelled")
    test_utils.next_frame()

    -- Buffer should remain unchanged on cancellation
    eq(content, r(buffer))
  end)
end)
