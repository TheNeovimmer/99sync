local Agents = require("99sync.extensions.agents")
local Files = require("99sync.extensions.files")
local Completions = require("99sync.extensions.completions")

local DEBOUNCE_MS = 100

--- @param items CompletionItem[]
--- @return table[]
local function to_native_items(items)
  local out = {}
  for _, item in ipairs(items) do
    local info = ""
    if item.documentation then
      if type(item.documentation) == "string" then
        info = item.documentation
      elseif item.documentation.value then
        info = item.documentation.value
      end
    end
    table.insert(out, {
      word = item.insertText or item.label,
      abbr = item.label,
      info = info,
      icase = 1,
      dup = 0,
    })
  end
  return out
end

--- @param _99sync _99sync.State
local function register_providers(_99sync)
  Completions.register(Agents.completion_provider(_99sync))
  Completions.register(Files.completion_provider())
end

--- @param buf number
local function setup_completion_autocmd(buf)
  local timer = vim.uv.new_timer()
  local group = vim.api.nvim_create_augroup(
    "99_native_completion_" .. buf,
    { clear = true }
  )

  vim.api.nvim_create_autocmd("TextChangedI", {
    group = group,
    buffer = buf,
    callback = function()
      timer:stop()
      timer:start(
        DEBOUNCE_MS,
        0,
        vim.schedule_wrap(function()
          if vim.fn.mode() ~= "i" then
            return
          end

          if not vim.api.nvim_buf_is_valid(buf) then
            timer:stop()
            return
          end

          local line = vim.api.nvim_get_current_line()
          local col = vim.fn.col(".")
          local before = line:sub(1, col - 1)

          local trigger = nil
          local start_col = nil
          for _, char in ipairs(Completions.get_trigger_characters()) do
            local escaped = Completions.escape_pattern(char)
            local pattern = escaped .. "%S*$"
            local match_start = before:find(pattern)
            if match_start then
              trigger = char
              start_col = match_start
              break
            end
          end

          if not trigger or not start_col then
            return
          end

          local items = Completions.get_completions(trigger)
          if #items == 0 then
            return
          end

          local native_items = to_native_items(items)
          vim.fn.complete(start_col, native_items)
        end)
      )
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    callback = function()
      timer:stop()
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
end

--- @param buf number
local function setup_keymaps(buf)
  vim.keymap.set("i", "<Tab>", function()
    if vim.fn.pumvisible() == 1 then
      return "<C-n>"
    end
    return "<Tab>"
  end, { buffer = buf, expr = true, noremap = true })

  vim.keymap.set("i", "<S-Tab>", function()
    if vim.fn.pumvisible() == 1 then
      return "<C-p>"
    end
    return "<S-Tab>"
  end, { buffer = buf, expr = true, noremap = true })
end

--- @param _ _99sync.State
local function init_for_buffer(_)
  local buf = vim.api.nvim_get_current_buf()

  vim.bo[buf].filetype = "99syncprompt"
  vim.opt_local.completeopt = "menuone,noinsert,noselect,popup,fuzzy"

  setup_completion_autocmd(buf)
  setup_keymaps(buf)
end

--- @param _99sync _99sync.State
local function init(_99sync)
  local rule_dirs = {}
  if _99sync.completion and _99sync.completion.custom_rules then
    for _, dir in ipairs(_99sync.completion.custom_rules) do
      table.insert(rule_dirs, dir)
    end
  end

  if _99sync.completion and _99sync.completion.files then
    Files.setup(_99sync.completion.files, rule_dirs)
  else
    Files.setup({ enabled = true }, rule_dirs)
  end

  register_providers(_99sync)
end

--- @param _99sync _99sync.State
local function refresh_state(_99sync)
  register_providers(_99sync)
end

--- @type _99sync.Extensions.Source
return {
  init_for_buffer = init_for_buffer,
  init = init,
  refresh_state = refresh_state,
}
