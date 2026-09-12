local make_prompt = require("99sync.ops.make-prompt")
local CleanUp = require("99sync.ops.clean-up")
local QFixHelpers = require("99sync.ops.qfix-helpers")

local make_observer = CleanUp.make_observer

--- @param context _99sync.Prompt
--- @param response string
local function finish_vibe(context, response)
  local qf_list = QFixHelpers.create_qfix_entries(response)
  context.logger:set_area("vibe"):debug("qf_list created", "qf_list", qf_list)
  context.data = {
    type = "vibe",
    qfix_items = qf_list,
    response = response,
  }

  if #qf_list > 0 then
    require("99sync").open_qfix_for_request(context)
  else
    vim.notify("No search results found", vim.log.levels.INFO)
  end
end

--- @class _99sync.Search.Result
--- @field filename string
--- @field lnum number
--- @field col number
--- @field text string

--- @param context _99sync.Prompt
---@param opts _99sync.ops.Opts
local function vibe(context, opts)
  opts = opts or {}

  local logger = context.logger:set_area("vibe")
  logger:debug("vibe", "with opts", opts.additional_prompt)

  local prompt, refs =
    make_prompt(context, context._99sync.prompts.prompts.vibe(), opts)

  context:add_prompt_content(prompt)
  context:add_references(refs)

  --- TODO: part of the context request clean up there needs to be a refactoring of
  --- make observer... it really should just be within the context observer creation.
  --- same with cleanup.. that should just be clean_ups from context, instead of a
  --- once cleanup function wrapper.
  ---
  --- i think an interface, CleanUpI could be something that is worth it :)
  context:start_request(make_observer(context, function(status, response)
    if status == "cancelled" then
      logger:debug("request cancelled for search")
    elseif status == "failed" then
      logger:error(
        "request failed for search",
        "error response",
        response or "no response provided"
      )
    elseif status == "success" then
      finish_vibe(context, response)
      context._99sync:sync()
    end
  end))
end
return vibe
