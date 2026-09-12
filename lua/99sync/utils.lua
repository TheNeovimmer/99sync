local M = {}

--- @param str string
---@param word_count number
---@return string[]
function M.split_with_count(str, word_count)
  local out = {}
  local words = vim.split(str, "%s+", { trimempty = true })

  local count = math.min(word_count, #words)
  for i = 1, count do
    table.insert(out, words[i])
  end

  return out
end

function M.copy(t)
  assert(type(t) == "table", "passed in non table into table")
  local out = {}
  for k, v in pairs(t) do
    out[k] = v
  end
  for i, v in ipairs(t) do
    out[i] = v
  end
  return out
end

--- @param dir string
--- @return string
function M.random_file(dir)
  return string.format("%s/99-%d", dir, math.floor(math.random() * 10000))
end

--- @param dir string
--- @param name string
--- @return string
function M.named_tmp_file(dir, name)
  return string.format("%s/99-%s", dir, name)
end

--- @param path string
--- @return table | nil
function M.read_file_json_safe(path)
  local ok, fh = pcall(io.open, path, "r")
  if ok and fh then
    local ok2, content = pcall(fh.read, fh, "*a")
    pcall(fh.close, fh)
    if not ok2 then
      return nil
    end
    local ok3, obj = pcall(vim.json.decode, content)
    if ok3 and obj then
      return obj
    end
  end
end

--- @param obj table
---@param path string
function M.write_file_json_safe(obj, path)
  local ok, fh = pcall(io.open, path, "w")
  if not ok or not fh then
    return
  end

  local obj_str
  ok, obj_str = pcall(vim.json.encode, obj)
  if not ok then
    return
  end

  pcall(fh.write, fh, obj_str)
end

return M
