local Completions = require("99sync.extensions.completions")
local Agents = require("99sync.extensions.agents")

--- @param context _99sync.Prompt
--- @param prompt string
--- @param opts _99sync.ops.Opts
--- @return string, _99sync.Reference[]
return function(context, prompt, opts)
  local user_prompt = opts.additional_prompt
  assert(
    user_prompt and type(user_prompt) == "string" and #user_prompt > 0,
    "you must add a prompt to you request"
  )

  local full_prompt = prompt
  full_prompt = context._99sync.prompts.prompts.prompt(user_prompt, full_prompt)

  local refs = Completions.parse(user_prompt)
  local additional_rules = opts.additional_rules
  if additional_rules then
    for _, r in ipairs(additional_rules) do
      local content = Agents.get_rule_content(r)
      if content then
        table.insert(refs, {
          content = content,
        })
      end
    end
  end

  return full_prompt, refs
end
