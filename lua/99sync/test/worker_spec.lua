-- luacheck: globals describe it assert before_each after_each
local _99sync = require("99sync")
local Window = require("99sync.window")
local Worker = require("99sync.extensions.work.worker")
local test_utils = require("99sync.test.test_utils")
local utils = require("99sync.utils")
local eq = assert.are.same

describe("worker", function()
  local previous_capture_input
  local captured_content
  local tmp_dir

  before_each(function()
    tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir, "p")

    local provider = test_utils.TestProvider.new()
    _99sync.setup(
      test_utils.get_test_setup_options({ tmp_dir = tmp_dir }, provider)
    )

    Worker.current_work_item = nil
    Worker.last_work_search = nil

    captured_content = nil
    previous_capture_input = Window.capture_input
    Window.capture_input = function(_, opts)
      captured_content = opts.content
    end
  end)

  after_each(function()
    Window.capture_input = previous_capture_input
    Worker.current_work_item = nil
    Worker.last_work_search = nil

    if tmp_dir then
      vim.fn.delete(tmp_dir, "rf")
    end
  end)

  it("set_work preloads existing persisted work", function()
    local work_path = utils.named_tmp_file(tmp_dir, "work-item")
    local file = assert(io.open(work_path, "w"))
    file:write("fix flaky tests")
    file:close()

    Worker.set_work()

    eq({ "fix flaky tests" }, captured_content)
  end)

  it("set_work shows default when no persisted work exists", function()
    Worker.set_work()

    eq(
      { "Put in the description of the work you want to complete" },
      captured_content
    )
  end)
end)
