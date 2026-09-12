local _99sync = require("99sync")

local M = {}

local function is_selectable_provider(provider)
  return type(provider) == "table"
    and type(provider._get_provider_name) == "function"
    and type(provider._build_command) == "function"
end

--- @param provider _99sync.Providers.BaseProvider?
--- @param callback fun(models: string[], current: string): nil
function M.get_models(provider, callback)
  provider = provider or _99sync.get_provider()

  provider.fetch_models(function(models, err)
    if err then
      vim.notify("99sync: " .. err, vim.log.levels.ERROR)
      return
    end
    if not models or #models == 0 then
      vim.notify("99sync: No models available", vim.log.levels.WARN)
      return
    end
    callback(models, _99sync.get_model())
  end)
end

--- @return { names: string[], lookup: table<string, _99sync.Providers.BaseProvider>, current: string }
function M.get_providers()
  local names = {}
  local lookup = {}

  for name, provider in pairs(_99sync.Providers) do
    if is_selectable_provider(provider) then
      table.insert(names, name)
      lookup[name] = provider
    end
  end
  table.sort(names)
  local current = ""
  local current_provider = _99sync.get_provider()
  if is_selectable_provider(current_provider) then
    current = current_provider._get_provider_name()
  elseif #names > 0 then
    current = names[1]
  end

  return {
    names = names,
    lookup = lookup,
    current = current,
  }
end

--- @param model string
function M.on_model_selected(model)
  _99sync.set_model(model)
  vim.notify("99sync: Model set to " .. model)
end

--- @param name string
--- @param lookup table<string, _99sync.Providers.BaseProvider>
function M.on_provider_selected(name, lookup)
  local provider = lookup[name]
  if not provider then
    vim.notify(
      "99sync: Invalid provider selection: " .. tostring(name),
      vim.log.levels.ERROR
    )
    return
  end
  _99sync.set_provider(provider)
  vim.notify(
    "99sync: Provider set to " .. name .. " (model: " .. _99sync.get_model() .. ")"
  )
end

return M
