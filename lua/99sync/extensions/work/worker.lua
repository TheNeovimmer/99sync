local Window = require("99sync.window")
local utils = require("99sync.utils")

--- @class _99sync.Extensions.Worker
--- A persistent way to keep track of work.
---
--- this will likely be where the most change and focus goes into.  I would like
--- to take this into worktree territory and be able to swap between stuff super
--- slick.
---
--- Until then, it is going to be a single bit of work that you can provide
--- the description and then use search to find what is left that needs to be done.
--- @docs base
--- @field set_work fun(opts?: _99sync.WorkOpts): nil
--- will set the work for the project.  If opts provide a description then no
--- input capture of work description will be required
--- @field search fun(): nil
--- will use _99sync.search to find what is left to be done for this work item to be
--- considered done
local M = {}

local DEFAULT_WORK_DESCRIPTION =
  "Put in the description of the work you want to complete"

--- @class _99sync.WorkOpts
--- @docs included
--- @field description string | nil

--- @return string
local function get_work_item_file()
  local _99sync = require("99sync")
  local state = _99sync.__get_state()
  local tmp = state:tmp_dir()
  return utils.named_tmp_file(tmp, "work-item")
end

--- @return string | nil
local function read_work_item()
  local ok, file = pcall(io.open, get_work_item_file(), "r")
  if not ok or not file then
    return nil
  end
  --- @type string
  local contents
  ok, contents = pcall(file.read, file, "*a")
  pcall(file.close, file)

  if not ok then
    return nil
  end
  return contents
end

--- @return string | nil
local function hydrate_current_work_item()
  if M.current_work_item == nil then
    M.current_work_item = read_work_item()
  end
  return M.current_work_item or DEFAULT_WORK_DESCRIPTION
end

--- @param success boolean
---@param result string
local function set_work_item_cb(success, result)
  if not success then
    return
  end
  M.current_work_item = result

  local file = io.open(get_work_item_file(), "w")
  if file then
    file:write(result)
    file:close()
  else
    error("unable to save work item")
  end
end

function M.update_work()
  local work = hydrate_current_work_item()
  Window.capture_input(" Work ", {
    cb = set_work_item_cb,
    content = vim.split(work, "\n"),
  })
end

--- @param opts _99sync.WorkOpts | nil
function M.set_work(opts)
  opts = opts or {}
  local description = opts.description
  if description then
    set_work_item_cb(true, description)
  else
    local work = hydrate_current_work_item()
    Window.capture_input(" Work ", {
      cb = set_work_item_cb,
      content = { work },
    })
  end

  -- i think this makes sense.  last work search should be cleared
  M.last_work_search = nil
end

--- craft_prompt can be overridden so you can create your own prompt
--- @param worker _99sync.Extensions.Worker
--- @return string
function M.craft_prompt(worker)
  return string.format(
    [[
## Description
%s

## You must complete the checklist
[ ] - Inspect and understand all changed code
 [ ] - git diff
 [ ] - git diff --staged
 [ ] - commits that have not been pushed to remote
[ ] - Take the current pending and commited changes and figure out what is left
      to change to complete the work item. The work item is described in <Description>
[ ] - Carefully review all the changes and <Description> before you respond.
      respond with proper Search Format described in <Rule> and an example in <Output>
[ ] - If you see bugs, also report those
[ ] - if there are tests, run the tests

]],
    worker.current_work_item
  )
end

function M.search()
  local _99sync = require("99sync")
  hydrate_current_work_item()

  assert(
    M.current_work_item,
    'you must call "set_work" and set your current work item before calling this'
  )

  M.last_work_search = _99sync.search({
    additional_prompt = M.craft_prompt(M),
  })
end

function M.vibe()
  local _99sync = require("99sync")
  hydrate_current_work_item()

  assert(
    M.current_work_item,
    'you must call "set_work" and set your current work item before calling this'
  )

  M.last_work_search = _99sync.vibe({
    additional_prompt = M.craft_prompt(M),
  })
end

return M
