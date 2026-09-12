local M = {}

--- @return string
local function nvim_version_string()
  if vim.version == nil then
    return "unknown"
  end
  local v = vim.version()
  return string.format("%d.%d.%d", v.major, v.minor, v.patch)
end

function M.check()
  vim.health.start("99sync")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim " .. nvim_version_string() .. " (>= 0.10)")
  else
    vim.health.error("Neovim 0.10+ required, found " .. nvim_version_string())
  end

  local backends = {
    { provider = "OpenCodeProvider (default)", cmd = "opencode" },
    { provider = "ClaudeCodeProvider", cmd = "claude" },
    { provider = "CursorAgentProvider", cmd = "cursor-agent" },
    { provider = "KiroProvider", cmd = "kiro-cli" },
    { provider = "GeminiCLIProvider", cmd = "gemini" },
  }
  for _, backend in ipairs(backends) do
    if vim.fn.executable(backend.cmd) == 1 then
      vim.health.ok(backend.cmd .. " found (" .. backend.provider .. ")")
    else
      vim.health.warn(
        backend.cmd .. " not on PATH (only needed for " .. backend.provider .. ")"
      )
    end
  end

  local ok_mod, mod = pcall(require, "99sync")
  if not ok_mod then
    vim.health.error("could not require 99sync")
    return
  end
  local ok_state, state = pcall(mod.__get_state)
  if not ok_state or state == nil then
    vim.health.warn("setup() has not run yet; open Neovim normally, then re-run")
    return
  end

  vim.health.ok(
    "provider: " .. mod.get_provider()._get_provider_name() .. ", model: " .. mod.get_model()
  )

  local tmp_dir = state:tmp_dir()
  if vim.fn.isdirectory(tmp_dir) == 1 and vim.fn.filewritable(tmp_dir) == 2 then
    vim.health.ok("tmp_dir writable: " .. tmp_dir)
  else
    vim.health.warn(
      "tmp_dir missing or not writable: " .. tmp_dir .. " (requests will fail)"
    )
  end

  local optional = {
    { mod = "snacks", label = "snacks.nvim (pickers)" }
    { mod = "fzf_lua", label = "fzf-lua (pickers)" },
    { mod = "blink.compat", label = "blink.compat (blink source)" },
    { mod = "cmp", label = "nvim-cmp (cmp source)" },
  }
  for _, dep in ipairs(optional) do
    if pcall(require, dep.mod) then
      vim.health.ok(dep.label .. " found")
    else
      vim.health.info(dep.label .. " not found (optional)")
    end
  end
end

return M
