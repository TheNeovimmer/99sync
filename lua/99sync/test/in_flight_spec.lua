-- luacheck: globals describe it assert after_each
local _99sync = require("99sync")
local Prompt = require("99sync.prompt")
local Window = require("99sync.window")
local test_utils = require("99sync.test.test_utils")
local eq = assert.are.same

local content = {
  "local function foo()",
  "  return 1",
  "end",
}

--- You have to override this or else things will crash since the ui itself
--- does not exist.  this is a headless test so i fake it by returning a very
--- simple ui of 120x40
local original_nvim_list_uis = vim.api.nvim_list_uis
local function nvim_list_uis()
  return {
    { width = 120, height = 40 },
  }
end

describe("in_flight window", function()
  local WAIT_TIME = 10
  before_each(function()
    vim.api.nvim_list_uis = nvim_list_uis
  end)
  after_each(function()
    vim.api.nvim_list_uis = original_nvim_list_uis
  end)
  it("shows active requests and clears when request completes", function()
    local provider = test_utils.test_setup(content, 2, 4)
    local state = _99sync.__get_state()
    local context = Prompt.search(state)

    context:start_request()
    vim.wait(WAIT_TIME * 2, function() end)

    eq(1, #Window.active_windows)

    local win = Window.active_windows[1]
    vim.api.nvim_win_close(win.win_id, true)

    vim.wait(WAIT_TIME * 2, function() end)
    local next_win = Window.active_windows[1]

    eq(true, win.win_id ~= next_win.win_id)

    provider:resolve("success", "results are in")

    vim.wait(WAIT_TIME * 2, function() end)
    eq(0, #Window.active_windows)
  end)

  it("enable false == do not show in flight", function()
    local provider = test_utils.test_setup(content, 2, 4, "lua", {
      in_flight_options = { enable = false },
    })
    local state = _99sync.__get_state()
    local context = Prompt.search(state)

    context:start_request()
    vim.wait(WAIT_TIME * 2, function() end)

    eq(0, #Window.active_windows)
    provider:resolve("success", "results are in")
    vim.wait(WAIT_TIME * 2, function() end)
    eq(0, #Window.active_windows)
  end)
end)
