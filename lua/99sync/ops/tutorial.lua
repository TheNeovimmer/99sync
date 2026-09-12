local CleanUp = require("99sync.ops.clean-up")
local Window = require("99sync.window")
local make_prompt = require("99sync.ops.make-prompt")

local make_observer = CleanUp.make_observer

--- @param context _99sync.Prompt
---@param response string
---@return _99sync.Prompt.Data.Tutorial
local function open_tutorial(context, response)
  local content = vim.split(response, "\n")
  local win = Window.create_split(content)

  --- @type _99sync.Prompt.Data.Tutorial
  local data = {
    type = "tutorial",
    buffer = win.buffer,
    window = win.win,
    xid = context.xid,
    tutorial = content,
  }
  context.data = data
  return data
end

--- @param context _99sync.Prompt
---@param opts _99sync.ops.Opts
local function tutorial(context, opts)
  opts = opts or {}

  local logger = context.logger:set_area("tutorial")
  logger:debug("starting", "with opts", opts)

  local prompt, refs =
    make_prompt(context, context._99sync.prompts.prompts.tutorial(), opts)

  context:add_references(refs)
  context:add_prompt_content(prompt)

  context:start_request(make_observer(context, function(status, response)
    if status == "cancelled" then
      logger:debug("cancelled")
    elseif status == "failed" then
      logger:error(
        "failed",
        "error response",
        response or "no response provided"
      )
    elseif status == "success" then
      open_tutorial(context, response)
      context._99sync:sync()
    end
  end))
end
return tutorial
