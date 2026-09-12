local Files = require("99sync.extensions.files")

--- @class _99sync.Extensions.Source
--- @field init_for_buffer fun(_99sync: _99sync.State): nil
--- @field init fun(_99sync: _99sync.State): nil
--- @field refresh_state fun(_99sync: _99sync.State): nil

--- @param completion _99sync.Completion | nil
--- @return _99sync.Extensions.Source | nil
local function get_source(completion)
  local source = completion and completion.source or "native"

  if source == "native" then
    local ok, native = pcall(require, "99.extensions.native")
    if not ok then
      vim.notify("[99sync] Failed to load native completions", vim.log.levels.ERROR)
      return
    end
    return native
  end

  if source == "cmp" then
    local ok, cmp = pcall(require, "99.extensions.cmp")
    if not ok then
      vim.notify(
        '[99sync] nvim-cmp is not installed. Install hrsh7th/nvim-cmp or use source = "blink" or "native"',
        vim.log.levels.WARN
      )
      return
    end
    return cmp
  end
  if source == "blink" then
    local ok, _ = pcall(require, "blink.compat")
    if not ok then
      vim.notify(
        "[99sync] blink.compat is required for blink source. Install: { 'saghen/blink.compat', version = '2.*' }",
        vim.log.levels.ERROR
      )
      return
    end
    local cmp_ok, cmp = pcall(require, "99.extensions.cmp")
    if not cmp_ok then
      vim.notify(
        "[99sync] 99sync completion module failed to load",
        vim.log.levels.ERROR
      )
      return
    end
    return cmp
  end
end

return {
  --- @param _99sync _99sync.State
  init = function(_99sync)
    local source = get_source(_99sync.completion)
    if not source then
      return
    end
    source.init(_99sync)
  end,

  capture_project_root = function()
    local cwd = vim.fn.getcwd()
    local git_root = vim.fs.root(cwd, ".git")
    Files.set_project_root(git_root or cwd)
  end,

  --- @param _99sync _99sync.State
  setup_buffer = function(_99sync)
    local source = get_source(_99sync.completion)
    if not source then
      return
    end
    source.init_for_buffer(_99sync)
  end,

  --- @param _99sync _99sync.State
  refresh = function(_99sync)
    local source = get_source(_99sync.completion)
    if not source then
      return
    end
    source.refresh_state(_99sync)
  end,
}
