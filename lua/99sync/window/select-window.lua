local Window = require("99sync.window")

--- @param lines string[]
---@param cb fun(idx: number): nil
local function select_window(lines, cb)
  Window.capture_select_input("Select", {
    content = lines,
    keymap = {
      enter = "select",
    },
    cb = function(success, result)
      if not success or result == "" then
        return
      end

      local idx = tonumber(vim.fn.matchstr(result, "^\\d\\+"))
      if idx == nil then
        return
      end
      local r = lines[idx]
      if not r then
        return
      end
      cb(idx)
    end,
  })
end

return select_window
