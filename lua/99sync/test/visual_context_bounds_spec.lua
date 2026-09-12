-- luacheck: globals describe it assert after_each
local prompt_settings = require("99sync.prompt-settings")
local test_utils = require("99sync.test.test_utils")
local geo = require("99sync.geo")

local eq = assert.are.same
local Range = geo.Range
local Point = geo.Point

local function make_lines(count, overrides)
  local out = {}
  for i = 1, count do
    out[i] = overrides[i] or string.format("line %04d", i)
  end
  return out
end

local function range_for_line(buffer, row)
  return Range:new(
    buffer,
    Point:from_1_based(row, 1),
    Point:from_1_based(row, 1)
  )
end

local function prompt_context_lines(range)
  local prompt = prompt_settings.prompts.visual_selection(range)
  local context = prompt:match(
    "<SURROUNDING_CONTEXT>\n(.-)\n</SURROUNDING_CONTEXT>"
  )

  assert.is_not_nil(context)
  if context == "" then
    return {}
  end

  return vim.split(context, "\n", { plain = true })
end

describe("visual context", function()
  after_each(function()
    test_utils.clean_files()
  end)

  it("should handle selections at the top of a file", function()
    local buffer = test_utils.create_file(
      make_lines(1000, {
        [1] = "selected line",
        [101] = "last line in context",
        [901] = "line that should not appear",
        [1000] = "bottom of file",
      }),
      "lua",
      1,
      0
    )

    local context = prompt_context_lines(range_for_line(buffer, 1))

    eq(101, #context)
    eq("selected line", context[1])
    eq("last line in context", context[#context])
    assert.is_false(vim.tbl_contains(context, "line that should not appear"))
  end)

  it("should keep context around middle selections", function()
    local buffer = test_utils.create_file(
      make_lines(1000, {
        [400] = "first line in context",
        [500] = "selected line",
        [600] = "last line in context",
      }),
      "lua",
      500,
      0
    )

    local context = prompt_context_lines(range_for_line(buffer, 500))

    eq(201, #context)
    eq("first line in context", context[1])
    eq("selected line", context[101])
    eq("last line in context", context[#context])
  end)

  it("should keep small files whole", function()
    local content = {
      "first available line",
      "selected middle line",
      "last available line",
    }
    local buffer = test_utils.create_file(content, "lua", 2, 0)

    local context = prompt_context_lines(range_for_line(buffer, 2))

    eq(content, context)
  end)
end)
