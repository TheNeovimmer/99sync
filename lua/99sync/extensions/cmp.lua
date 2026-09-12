local Agents = require("99sync.extensions.agents")
local Files = require("99sync.extensions.files")
local Completions = require("99sync.extensions.completions")
local SOURCE = "99sync"

--- @class CmpSource
--- @field _99sync _99sync.State
local CmpSource = {}
CmpSource.__index = CmpSource

--- @param _99sync _99sync.State
function CmpSource.new(_99sync)
  return setmetatable({
    _99sync = _99sync,
  }, CmpSource)
end

function CmpSource.is_available()
  return true
end

function CmpSource.get_debug_name()
  return SOURCE
end

function CmpSource.get_keyword_pattern()
  return Completions.get_keyword_pattern()
end

function CmpSource.get_trigger_characters()
  return Completions.get_trigger_characters()
end

function CmpSource.complete(_, params, callback)
  local before = params.context.cursor_before_line or ""

  -- Find which trigger is active
  local trigger = nil
  for _, char in ipairs(Completions.get_trigger_characters()) do
    local pattern = Completions.escape_pattern(char) .. "%S*$"
    if before:match(pattern) then
      trigger = char
      break
    end
  end

  if not trigger then
    callback({ items = {}, isIncomplete = false })
    return
  end

  local items = Completions.get_completions(trigger)
  callback({ items = items, isIncomplete = false })
end

function CmpSource.resolve(_, completion_item, callback)
  callback(completion_item)
end

function CmpSource.execute(_, completion_item, callback)
  callback(completion_item)
end

--- @type CmpSource | nil
local source = nil

--- @param _ _99sync.State
local function init_for_buffer(_)
  local buf = vim.api.nvim_get_current_buf()

  -- Set filetype for syntax highlighting
  vim.bo[buf].filetype = "99syncprompt"

  local cmp = require("cmp")
  cmp.setup.buffer({
    sources = { { name = SOURCE } },
    window = {
      completion = { zindex = 1001 },
      documentation = { zindex = 1001 },
    },
  })
end

--- @param _99sync _99sync.State
local function register_providers(_99sync)
  Completions.register(Agents.completion_provider(_99sync))
  Completions.register(Files.completion_provider())
end

--- @param _99sync _99sync.State
local function init(_99sync)
  assert(
    source == nil,
    "the source must be nil when calling init on an completer"
  )

  -- Collect rule directories to exclude from file search
  local rule_dirs = {}
  if _99sync.completion then
    if _99sync.completion.custom_rules then
      for _, dir in ipairs(_99sync.completion.custom_rules) do
        table.insert(rule_dirs, dir)
      end
    end
  end

  if _99sync.completion and _99sync.completion.files then
    Files.setup(_99sync.completion.files, rule_dirs)
  else
    Files.setup({ enabled = true }, rule_dirs)
  end

  register_providers(_99sync)

  local cmp = require("cmp")
  source = CmpSource.new(_99sync)
  cmp.register_source(SOURCE, source)
end

--- @param _99sync _99sync.State
local function refresh_state(_99sync)
  if not source then
    return
  end
  register_providers(_99sync)
end

--- @type _99sync.Extensions.Source
local source_wrapper = {
  init_for_buffer = init_for_buffer,
  init = init,
  refresh_state = refresh_state,
}
return source_wrapper
