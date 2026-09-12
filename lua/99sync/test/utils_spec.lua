-- luacheck: globals describe it assert
local Utils = require("99sync.utils")
local eq = assert.are.same

describe("utils", function()
  it("split_with_count handles 0, 1, 5, and N + 2 words", function()
    local str = "alpha\tbeta gamma\ndelta epsilon zeta eta"
    local words = vim.split(str, "%s+", { trimempty = true })
    local n = #words

    eq({}, Utils.split_with_count(str, 0))
    eq({ "alpha" }, Utils.split_with_count(str, 1))
    eq(
      { "alpha", "beta", "gamma", "delta", "epsilon" },
      Utils.split_with_count(str, 5)
    )
    eq(words, Utils.split_with_count(str, n + 2))
  end)
end)
