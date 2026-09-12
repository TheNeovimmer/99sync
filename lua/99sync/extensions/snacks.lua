local pickers_util = require("99sync.extensions.pickers")

local M = {}

--- @param items string[]
--- @param prompt string
--- @param on_choice fun(item?: string)
local function pick_one(items, prompt, on_choice)
  local ok_snacks, Snacks = pcall(require, "snacks")
  if ok_snacks and Snacks and Snacks.picker and Snacks.picker.select then
    Snacks.picker.select(items, { prompt = prompt }, on_choice)
  else
    vim.ui.select(items, { prompt = prompt }, on_choice)
  end
end

--- @param provider _99sync.Providers.BaseProvider?
function M.select_model(provider)
  pickers_util.get_models(provider, function(models, current)
    pick_one(models, "99sync: Select Model (current: " .. current .. ")", function(item)
      if not item then
        return
      end
      pickers_util.on_model_selected(item)
    end)
  end)
end

function M.select_provider()
  local info = pickers_util.get_providers()
  pick_one(
    info.names,
    "99sync: Select Provider (current: " .. info.current .. ")",
    function(item)
      if not item then
        return
      end
      pickers_util.on_provider_selected(item, info.lookup)
    end
  )
end

return M
