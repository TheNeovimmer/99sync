local utils = require("99sync.utils")
local Agents = require("99sync.extensions.agents")
local Extensions = require("99sync.extensions")
local Tracking = require("99sync.state.tracking")
local Window = require("99sync.window")

local _99sync_STATE_FILE = "state"
local function default_completion()
  return { source = nil, custom_rules = {} }
end

--- @class _99sync.StateProps
--- @field model string
--- @field md_files string[]
--- @field prompts _99sync.Prompts
--- @field ai_stdout_rows number
--- @field display_errors boolean
--- @field auto_add_skills boolean
--- @field provider_override _99sync.Providers.BaseProvider | nil
--- @field __view_log_idx number
--- @field __tmp_dir string | nil

--- unanswered question -- will i need to queue messages one at a time or
--- just send them all...  So to prepare ill be sending around this state object
--- @class _99sync.State
--- @field completion _99sync.Completion
--- @field model string
--- @field md_files string[]
--- @field prompts _99sync.Prompts
--- @field ai_stdout_rows number
--- @field display_errors boolean
--- @field provider_override _99sync.Providers.BaseProvider?
--- @field provider_extra_args string[]
--- @field rules _99sync.Agents.Rules
--- @field tracking _99sync.State.Tracking
--- @field __tmp_dir string | nil
local State = {}
State.__index = State

--- @return _99sync.StateProps
local function create()
  return {
    model = "opencode/claude-fable-5-1",
    md_files = {},
    ai_stdout_rows = 3,
    display_errors = false,
    provider_override = nil,
    tmp_dir = nil,
  }
end

--- @param oos _99sync.Options | _99sync.State
local function get_tmp_dir(oos)
  local tmp_dir = oos.tmp_dir and type(oos.tmp_dir) == "string" and oos.tmp_dir
    or oos.__tmp_dir and oos.__tmp_dir
    or "./tmp"
  if tmp_dir then
    tmp_dir = vim.fn.expand(tmp_dir)
  end
  return tmp_dir
end

--- @param opts _99sync.Options
--- @return _99sync.State.Tracking.Serialized | nil
local function read_state_from_tmp(opts)
  local state_file = utils.named_tmp_file(get_tmp_dir(opts), _99sync_STATE_FILE)
  return utils.read_file_json_safe(state_file) --[[@as _99sync.State.Tracking.Serialized]]
end

--- @param opts _99sync.Options
--- @return _99sync.State
function State.new(opts)
  local props = create()
  local _99sync_state = setmetatable(props, State) --[[@as _99sync.State]]

  _99sync_state.provider_override = opts.provider
  _99sync_state.provider_extra_args = opts.provider_extra_args or {}
  _99sync_state.completion = opts.completion or default_completion()
  _99sync_state.completion.custom_rules = _99sync_state.completion.custom_rules or {}
  _99sync_state.completion.files = _99sync_state.completion.files or {}

  --- TODO: Prompt overrides would be a great thing, we just have to get there
  --- for now, i am going to have this as just a hardcoded ... thing
  _99sync_state.prompts = require("99sync.prompt-settings")

  local previous = read_state_from_tmp(opts)
  _99sync_state.tracking = Tracking.new(_99sync_state, previous)

  return _99sync_state
end

function State:sync()
  local tracking = self.tracking:serialize()
  local tmp = self:tmp_dir()
  local file = utils.named_tmp_file(tmp, _99sync_STATE_FILE)
  utils.write_file_json_safe(tracking, file)
end

--- @return string
function State:tmp_dir()
  return get_tmp_dir(self)
end

--- @return boolean
function State:active()
  _ = self
  if Window.has_active_window() then
    return true
  end

  local qf = vim.fn.getqflist({ winid = 0 })
  return qf.winid ~= 0
end

--- TODO: This is something to understand.  I bet that this is going to need
--- a lot of performance tuning.  I am just reading every file, and this could
--- take a decent amount of time if there are lots of rules.
---
--- Simple perfs:
--- 1. read 4096 bytes at a tiem instead of whole file and parse out lines
--- 2. don't show the docs
--- 3. do the operation once at setup instead of every time.
---    likely not needed to do this all the time.
function State:refresh_rules()
  self.rules = Agents.rules(self)
  Extensions.refresh(self)
end

return State
