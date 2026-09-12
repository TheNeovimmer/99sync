local Window = require("99sync.window")
local Consts = require("99sync.consts")
local Throbber = require("99sync.ops.throbber")

--- @alias _99sync.StatusWindow.State "init" | "running"

--- @class _99sync.StatusWindow.Opts
--- this is pure a class for testing.   helps controls timings
--- @docs include
--- @field throbber_opts _99sync.Throbber.Opts | nil
--- options for the throbber in the top left
--- @field in_flight_interval number | nil
--- frequency in which the in-flight interval checks to see if it should be
--- displayed / removed
--- @field enable boolean | nil
--- defaults to true

--- @param opts _99sync.StatusWindow.Opts | nil
--- @return _99sync.StatusWindow.Opts
local function default_opts(opts)
  opts = opts or {}
  opts.throbber_opts = opts.throbber_opts
    or {
      throb_time = Consts.throbber_throb_time,
      cooldown_time = Consts.throbber_cooldown_time,
      tick_time = Consts.throbber_tick_time,
    }
  opts.in_flight_interval = opts.in_flight_interval
    or Consts.show_in_flight_requests_loop_time
  opts.enable = opts.enable == nil and true or opts.enable
  return opts
end

--- @class _99sync.StatusWindow
--- @field opts _99sync.StatusWindow.Opts
--- @field state _99sync.StatusWindow.State
--- @field win _99sync.window.Window | nil
--- @field throbber _99sync.Throbber | nil
--- @field _99sync _99sync.State
local StatusWindow = {}
StatusWindow.__index = StatusWindow

--- @param _99sync _99sync.State
--- @param opts _99sync.StatusWindow.Opts | nil
function StatusWindow.new(_99sync, opts)
  return setmetatable({
    opts = default_opts(opts),
    state = "init",
    _99sync = _99sync,
  }, StatusWindow)
end

function StatusWindow:_shutdown_status_window()
  if self.throbber then
    self.throbber:stop()
  end

  local win = self.win
  if win ~= nil then
    Window.close(win)
  end
  self.win = nil
  self.throbber = nil
end

function StatusWindow:_run_loop()
  if self.state ~= "running" then
    self:_shutdown_status_window()
    return
  end
  vim.defer_fn(function()
    self:_run_loop()
  end, self.opts.in_flight_interval)

  Window.refresh_active_windows()
  local current_win = self.win
  if current_win ~= nil and not Window.is_active_window(current_win) then
    self:_shutdown_status_window()
  end

  local active_window = Window.has_active_status_window()
  local active_other_window = Window.has_active_windows()
  local active_requests = self._99sync.tracking:active_count()
  if
    active_window == false and active_other_window
    or active_window and active_requests > 0
    or active_window == false and active_requests == 0
  then
    return
  end

  if current_win == nil then
    local ok, win = pcall(Window.status_window)
    if not ok then
      --- TODO: There needs to be a way to display logs for "all active requests"
      --- this is its own activity and should not be added to any work set
      return
    end

    local throb = Throbber.new(function(throb)
      local count = self._99sync.tracking:active_count()
      local win_valid = Window.valid(win)

      if count == 0 or not win_valid then
        return self:_shutdown_status_window()
      end

      --- @type string[]
      local lines = {
        throb .. " requests(" .. tostring(count) .. ") " .. throb,
      }

      for _, c in ipairs(self._99sync.tracking:active()) do
        if c.state == "requesting" then
          table.insert(lines, c.operation)
        end
      end

      Window.resize(win, #lines[1], #lines)
      vim.api.nvim_buf_set_lines(win.buf_id, 0, -1, false, lines)
    end, self.opts.throbber_opts)

    self.win = win
    self.throbber = throb

    throb:start()
  end
end

function StatusWindow:start()
  if not self.opts.enable then
    return
  end

  assert(
    self.state == "init",
    "you cannot start an inflight request if we are not in init state: "
      .. self.state
  )

  self.state = "running"
  self:_run_loop()
end

function StatusWindow:stop()
  if not self.opts.enable then
    return
  end
  assert(
    self.state == "running",
    "you cannot stop a running status window if its not running"
  )
  self.state = "init"
end

return StatusWindow
