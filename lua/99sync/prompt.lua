local BaseProvider = require("99sync.providers")
local Logger = require("99sync.logger.logger")
local utils = require("99sync.utils")
local random_file = utils.random_file
local copy = utils.copy
local get_id = require("99sync.id")
local Range = require("99sync.geo").Range
local Time = require("99sync.time")

--- you can only set those marks after the visual selection is removed
local function set_selection_marks()
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
    "x",
    false
  )
end

local filetype_map = {
  typescriptreact = "typescript",
}

-- luacheck: ignore
--- @alias _99sync.Prompt.Data _99sync.Prompt.Data.Search | _99sync.Prompt.Data.Tutorial | _99sync.Prompt.Data.Visual | _99sync.Prompt.Data.Vibe
--- @alias _99sync.Prompt.Operation "visual" | "tutorial" | "search" | "vibe"
--- @alias _99sync.Prompt.QFixOperation "search" | "vibe"
--- @alias _99sync.Prompt.EndingState "failed" | "success" | "cancelled"
--- @alias _99sync.Prompt.State "ready" | "requesting" | _99sync.Prompt.EndingState
--- @alias _99sync.Prompt.Cleanup fun(): nil

--- @class _99sync.Prompt.Serialized
--- @field data _99sync.Prompt.Data
--- @field user_prompt string
--- @class _99sync.Prompt.Data.Search
--- @field type "search"
--- @field qfix_items _99sync.Search.Result[]
--- @field response string

--- @class _99sync.Prompt.Data.Vibe
--- @field type "vibe"
--- @field response string
--- @field qfix_items _99sync.Search.Result[]

--- @class _99sync.Prompt.Data.Visual
--- @field type "visual"
--- @field buffer number
--- @field file_type string
--- @field range _99sync.Range

--- @class _99sync.Prompt.Data.Tutorial
--- @field type "tutorial"
--- @field buffer number
--- @field window number
--- @field xid number TODO: we should probably get rid of this.  The request pattern is not quite correct
--- @field tutorial string[]

--- @class _99sync.Prompt
--- @field md_file_names string[]
--- @field model string
--- @field user_prompt string
--- @field operation _99sync.Prompt.Operation
--- @field state _99sync.Prompt.State
--- @field full_path string
--- @field started_at number
--- @field data _99sync.Prompt.Data
--- @field agent_context string[]
--- @field tmp_file string
--- @field marks table<string, _99sync.Mark>
--- @field logger _99sync.Logger
--- @field xid number
--- @field clean_ups (fun(): nil)[]
--- @field _99sync _99sync.State
---@diagnostic disable-next-line: undefined-doc-name
--- @field _proc vim.SystemObj?
local Prompt = {}
Prompt.__index = Prompt

--- @type _99sync.Prompt[]
Prompt.__previous_contexts = {}

--- @type table<number, _99sync.Prompt>
Prompt.__context_by_id = {}

--- @param context  _99sync.Prompt
--- @param _99sync _99sync.State
local function set_defaults(context, _99sync)
  local xid = get_id()
  local full_path = vim.api.nvim_buf_get_name(0)

  context.state = "ready"
  context._99sync = _99sync
  context.user_prompt = ""
  context.clean_ups = {}
  context.md_file_names = copy(_99sync.md_files)
  context.model = _99sync.model
  context.agent_context = {}
  context.tmp_file = random_file(_99sync:tmp_dir())
  context.logger = Logger:set_id(xid)
  context.xid = xid
  context.full_path = full_path
  context.marks = {}
  context.started_at = Time.now()
end

--- TODO: Work item for "TODO implementation"
function Prompt.todo(_99sync)
  _ = _99sync
  assert(false, "not implemented")
end

--- @param _99sync _99sync.State
--- @param data _99sync.Prompt.Serialized
--- @return _99sync.Prompt
function Prompt.deserialize(_99sync, data)
  local prompt = setmetatable({
    _99sync = _99sync,
    data = data.data,
    operation = data.data.type,
    user_prompt = data.user_prompt,
    started_at = Time.now(),

    --- we should only sync successful requests
    state = "success",

    xid = get_id(),
  }, Prompt)
  assert(prompt:valid(), "prompt is not valid from data")
  return prompt
end

--- @return _99sync.Prompt.Serialized
function Prompt:serialize()
  assert(self.state == "success", "you can only serialize successful prompts")
  return {
    data = self.data,
    user_prompt = self.user_prompt,
  }
end

--- @param _99sync _99sync.State
--- @return _99sync.Prompt
function Prompt.vibe(_99sync)
  _99sync:refresh_rules()

  --- @type _99sync.Prompt
  local context = setmetatable({}, Prompt)
  set_defaults(context, _99sync)
  context.operation = "vibe"
  context.data = {
    type = "vibe",
    response = "",
    qfix_items = {},
  }
  context.logger:debug("99 Request", "method", "vibe")

  return context
end

--- @param _99sync _99sync.State
--- @return _99sync.Prompt
function Prompt.visual(_99sync)
  _99sync:refresh_rules()

  set_selection_marks()
  local range = Range.from_visual_selection()

  local file_type = vim.bo[0].ft
  local buffer = vim.api.nvim_get_current_buf()
  file_type = filetype_map[file_type] or file_type

  local mds = {}
  for _, md in ipairs(_99sync.md_files) do
    table.insert(mds, md)
  end

  --- @type _99sync.Prompt
  local context = setmetatable({}, Prompt)
  set_defaults(context, _99sync)
  context.operation = "visual"
  context.data = {
    type = "visual",
    buffer = buffer,
    file_type = file_type,
    range = range,
  }
  context.logger:debug("99 Request", "method", "visual")

  return context
end

--- @return string
function Prompt:summary()
  local prompt_str = utils.split_with_count(self.user_prompt, 8)
  return string.format("%s: %s", self.operation, table.concat(prompt_str, " "))
end

--- @param _99sync _99sync.State
--- @return _99sync.Prompt
function Prompt.tutorial(_99sync)
  _99sync:refresh_rules()

  --- @type _99sync.Prompt
  local context = setmetatable({}, Prompt)
  set_defaults(context, _99sync)
  context.operation = "tutorial"
  context.data = {
    type = "tutorial",
    xid = context.xid, -- TODO: i want to get rid of this when i implement rehydration of the data.
    buffer = 0,
    window = 0,
    tutorial = {},
  }
  context.logger:debug("99 Request", "method", "tutorial")

  return context
end

--- @param _99sync _99sync.State
--- @return _99sync.Prompt
function Prompt.search(_99sync)
  _99sync:refresh_rules()

  --- @type _99sync.Prompt
  local context = setmetatable({}, Prompt)
  set_defaults(context, _99sync)
  context.operation = "search"
  context.data = {
    type = "search",
    qfix_items = {},
    response = "",
  }
  context.logger:debug("99 Request", "method", "search")

  return context
end

--- @param obs _99sync.Providers.Observer | nil
function Prompt:_observer(obs)
  return {
    on_start = function()
      self.state = "requesting"
      self._99sync.tracking:track(self)

      if obs then
        obs.on_start()
      end
    end,
    on_complete = function(status, res)
      self.state = status
      if obs then
        obs.on_complete(status, res)
      end
    end,
    on_stderr = function(line)
      if obs then
        obs.on_stderr(line)
      end
    end,
    on_stdout = function(line)
      if obs then
        obs.on_stdout(line)
      end
    end,
  }
end

local allowed_context_types = {
  "visual",
  "search",
  "tutorial",
  "vibe",
}
--- @return boolean
function Prompt:valid()
  local t = self.data.type
  for _, allowed in ipairs(allowed_context_types) do
    if t == allowed then
      return true
    end
  end
  return false
end

--- @param observer _99sync.Providers.Observer?
function Prompt:start_request(observer)
  local l = self.logger
  l:assert(
    self.state == "ready",
    'state is not "ready" when attempting to start a request'
  )

  local ok = self:finalize()
  l:assert(ok, "context failed to finalize")

  --- TODO: create a prompt context class that can actually organize.
  --- do not do this during the request context refactoring, but next
  local prompt = table.concat(self.agent_context, "\n")
  local obs = self:_observer(observer)
  local provider = self._99sync.provider_override or BaseProvider.OpenCodeProvider

  self:save_prompt(prompt)
  l:debug("start", "prompt", prompt)

  provider:make_request(prompt, self, obs)
end

function Prompt:is_cancelled()
  return self.state == "cancelled"
end

function Prompt:is_completed()
  return self.state == "success" or self.state == "failed"
end

---@diagnostic disable-next-line: undefined-doc-name
--- @param proc vim.SystemObj?
function Prompt:_set_process(proc)
  self._proc = proc
end

function Prompt:cancel()
  if self:is_cancelled() or self:is_completed() then
    return
  end

  self.state = "cancelled"
  local proc = self._proc
  ---@diagnostic disable-next-line: undefined-field
  if proc and proc.pid then
    self._proc = nil
    pcall(function()
      local sigterm = (vim.uv and vim.uv.constants and vim.uv.constants.SIGTERM)
        or 15
      ---@diagnostic disable-next-line: undefined-field
      proc:kill(sigterm)
    end)
  end
end

--- @return _99sync.Prompt.Data.Visual
function Prompt:visual_data()
  assert(
    self.data.type == "visual",
    "you cannot get visual data if its not type visual"
  )
  return self.data --[[@as _99sync.Prompt.Data.Visual]]
end

--- @return _99sync.Prompt.Data.Tutorial
function Prompt:tutorial_data()
  assert(
    self.data.type == "tutorial",
    "you cannot get tutorial data if its not type tutorial"
  )
  return self.data --[[@as _99sync.Prompt.Data.Tutorial]]
end

--- @return _99sync.Prompt.Data.Search
function Prompt:search_data()
  assert(
    self.data.type == "search",
    "you cannot get search data if its not type search"
  )
  return self.data --[[@as _99sync.Prompt.Data.Search]]
end

--- @return _99sync.Search.Result[]
function Prompt:qfix_data()
  assert(
    self.data.type == "search" or self.data.type == "vibe",
    "data type is not search or vibe: " .. self.data.type
  )
  return self.data.qfix_items
end

function Prompt:stop()
  self:cancel()
  self:clear_marks()

  for _, cb in ipairs(self.clean_ups) do
    cb()
  end
end

--- @param clean_up fun(): nil
function Prompt:add_clean_up(clean_up)
  table.insert(self.clean_ups, clean_up)
end

--- @param md_file_name string
--- @return self
function Prompt:add_md_file_name(md_file_name)
  table.insert(self.md_file_names, md_file_name)
  return self
end

--- @param content string
--- @return self
function Prompt:add_prompt_content(content)
  table.insert(self.agent_context, content)
  return self
end

--- @param refs _99sync.Reference[]
function Prompt:add_references(refs)
  for _, ref in ipairs(refs) do
    self.logger:debug("adding reference to context")
    table.insert(self.agent_context, ref.content)
  end
end

function Prompt:_read_md_files()
  local cwd = vim.uv.cwd()
  local dir = vim.fn.fnamemodify(self.full_path, ":h")

  while dir:find(cwd, 1, true) == 1 do
    for _, md_file_name in ipairs(self.md_file_names) do
      local md_path = dir .. "/" .. md_file_name
      local file = io.open(md_path, "r")
      if file then
        local content = file:read("*a")
        file:close()
        self.logger:info(
          "Context#adding md file to the context",
          "md_path",
          md_path
        )
        table.insert(self.agent_context, content)
      end
    end

    if dir == cwd then
      break
    end

    dir = vim.fn.fnamemodify(dir, ":h")
  end
end

--- @return string[]
function Prompt:content()
  return self.agent_context
end

--- @return boolean
function Prompt:_ready_request_files()
  local response_file = self.tmp_file
  local prompt_file = self.tmp_file .. "-prompt"

  local dir = vim.fs.dirname(prompt_file)

  if dir and not vim.uv.fs_stat(dir) then
    vim.fn.mkdir(dir, "p")
  end

  local files = { prompt_file, response_file }
  for _, f in ipairs(files) do
    local file = io.open(f, "w")
    if file then
      file:write("")
      file:close()
    else
      self.logger:error("unable to create prompt file")
      return false
    end
  end
  return true
end

--- @param prompt string
function Prompt:save_prompt(prompt)
  local prompt_file = self.tmp_file .. "-prompt"
  local file = io.open(prompt_file, "w")
  if file then
    file:write(prompt)
    file:close()
    self.logger:debug("saved prompt to file", "path", prompt_file)
  else
    self.logger:error("failed to save prompt", "path", prompt_file)
  end
end

--- @return boolean, self
function Prompt:finalize()
  if self:_ready_request_files() == false then
    return false, self
  end
  self:_read_md_files()

  local ok, visual_data = pcall(self.visual_data, self)
  if ok then
    local f_loc =
      self._99sync.prompts.get_file_location(self.full_path, visual_data.range)
    table.insert(self.agent_context, f_loc)
    table.insert(
      self.agent_context,
      self._99sync.prompts.get_range_text(visual_data.range)
    )
  end
  table.insert(
    self.agent_context,
    self._99sync.prompts.tmp_file_location(self.tmp_file)
  )

  if
    self.operation == "visual"
    or self.operation == "tutorial"
    or self.operation == "search"
  then
    table.insert(self.agent_context, self._99sync.prompts.only_tmp_file_change())
  end

  return true, self
end

function Prompt:clear_marks()
  for _, mark in pairs(self.marks) do
    mark:delete()
  end
end

return Prompt
