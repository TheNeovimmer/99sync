-- luacheck: globals describe it assert before_each after_each
---@diagnostic disable: undefined-field, need-check-nil
local Files = require("99sync.extensions.files")
local eq = assert.are.same

describe("files", function()
  local default_exclude = {
    ".env",
    ".env.*",
    "node_modules",
    ".git",
    "dist",
    "build",
    "*.log",
    ".DS_Store",
    "tmp",
    ".cursor",
  }

  before_each(function()
    Files.setup({ enabled = true, exclude = default_exclude }, {})
    Files.set_project_root(vim.uv.cwd())
  end)

  after_each(function()
    Files.set_project_root("")
  end)

  it("discover_files finds known files and excludes .git", function()
    local files = Files.discover_files()
    local paths = {}
    for _, f in ipairs(files) do
      paths[f.path] = f
    end

    assert.is_not_nil(paths["scratch/refresh.lua"])
    assert.is_not_nil(paths["scratch/test.ts"])
    eq("refresh.lua", paths["scratch/refresh.lua"].name)
    eq("test.ts", paths["scratch/test.ts"].name)

    for path, _ in pairs(paths) do
      assert.is_nil(
        path:match("^%.git/"),
        "expected .git to be excluded but found: " .. path
      )
    end
  end)

  it("discover_files returns sorted paths", function()
    local files = Files.discover_files()
    for i = 2, #files do
      assert.is_true(
        files[i - 1].path < files[i].path,
        "expected sorted order but "
          .. files[i - 1].path
          .. " >= "
          .. files[i].path
      )
    end
  end)

  it("is_project_file by path and name, rejects invalid", function()
    Files.discover_files()
    eq(true, Files.is_project_file("scratch/refresh.lua"))
    eq(true, Files.is_project_file("refresh.lua"))
    eq(false, Files.is_project_file("nonexistent/file.lua"))
    eq(false, Files.is_project_file(""))
  end)

  it("find_matches fuzzy matches non-contiguous characters", function()
    Files.discover_files()

    -- "rfrsh" should fuzzy match "refresh.lua" (r-f-r-s-h appear in order)
    local matches = Files.find_matches("rfrsh")
    local found = false
    for _, f in ipairs(matches) do
      if f.name == "refresh.lua" then
        found = true
      end
    end
    assert.is_true(found, "expected 'rfrsh' to fuzzy match refresh.lua")

    -- "zzzzz" should match nothing
    local no_matches = Files.find_matches("zzzzz")
    eq(0, #no_matches)
  end)

  it("read_file returns actual file content", function()
    local content = Files.read_file("scratch/refresh.lua")
    assert.is_not_nil(content)
    assert.is_true(#content > 0, "expected non-empty file content")
  end)

  it("read_file returns nil for missing file", function()
    eq(nil, Files.read_file("nonexistent/file.lua"))
  end)

  it("setup excludes configured patterns and keeps others", function()
    Files.setup(
      { enabled = true, exclude = { "scratch", ".git", "node_modules" } },
      {}
    )
    Files.set_project_root(vim.uv.cwd())
    local files = Files.discover_files()

    local has_non_scratch = false
    for _, f in ipairs(files) do
      assert.is_nil(
        f.path:match("^scratch"),
        "expected scratch excluded but found: " .. f.path
      )
      if not f.path:match("^scratch") then
        has_non_scratch = true
      end
    end
    assert.is_true(
      has_non_scratch,
      "expected non-scratch files to still be present"
    )
  end)

  it(
    "completion_provider get_items returns items with correct shape and values",
    function()
      Files.discover_files()
      local provider = Files.completion_provider()

      eq("@", provider.trigger)
      eq("files", provider.name)

      local items = provider.get_items()
      assert.is_true(#items > 0)

      -- find the refresh.lua item specifically and check every field
      local refresh_item = nil
      for _, item in ipairs(items) do
        if item.label == "refresh.lua" then
          refresh_item = item
        end
      end
      assert.is_not_nil(
        refresh_item,
        "expected to find refresh.lua in completion items"
      )
      eq("@scratch/refresh.lua", refresh_item.insertText)
      assert.is_true(
        refresh_item.filterText:match("refresh%.lua") ~= nil,
        "expected filterText to contain filename"
      )
      eq(17, refresh_item.kind) -- LSP CompletionItemKind.Reference
      eq("scratch/refresh.lua", refresh_item.detail)
      eq("markdown", refresh_item.documentation.kind)
    end
  )

  it(
    "completion_provider resolve wraps content in code fence with extension",
    function()
      local provider = Files.completion_provider()
      local content = provider.resolve("scratch/refresh.lua")
      assert.is_not_nil(content)

      assert.is_true(
        content:sub(1, 6) == "```lua",
        "expected code fence to start with ```lua"
      )
      assert.is_true(
        content:sub(-4) == "\n```",
        "expected code fence to end with ```"
      )
      assert.is_true(
        content:match("-- scratch/refresh%.lua") ~= nil,
        "expected path comment in fence"
      )
      local inner = content:match("```lua\n.-\n(.+)\n```$")
      assert.is_not_nil(inner, "expected non-empty content inside code fence")
    end
  )

  it("completion_provider resolve returns nil for missing file", function()
    local provider = Files.completion_provider()
    eq(nil, provider.resolve("does/not/exist.lua"))
  end)

  it("completion_provider resolve works with bare filename", function()
    Files.discover_files()
    local provider = Files.completion_provider()
    local content = provider.resolve("refresh.lua")
    assert.is_not_nil(content, "expected resolve to work with bare filename")
    assert.is_true(
      content:sub(1, 6) == "```lua",
      "expected code fence to start with ```lua"
    )
    assert.is_true(
      content:match("-- scratch/refresh%.lua") ~= nil,
      "expected full relative path in fence comment"
    )
  end)
end)

describe("files git integration", function()
  -- Mock storage
  local _mocks = {
    system_output = "",
    system_exit = 0,
    stat_type = nil,
    stat_exists = false,
    orig_system = nil,
    orig_stat = nil,
    orig_shell_error = nil,
    system_calls = {},
  }

  before_each(function()
    _mocks.orig_system = vim.fn.system
    _mocks.orig_stat = vim.uv.fs_stat

    _mocks.system_output = ""
    _mocks.system_exit = 0
    _mocks.stat_type = nil
    _mocks.stat_exists = false
    _mocks.system_calls = {}

    vim.fn.system = function(cmd)
      table.insert(_mocks.system_calls, cmd)

      pcall(function()
        rawset(vim.v, "shell_error", _mocks.system_exit)
      end)
      return _mocks.system_output
    end

    vim.uv.fs_stat = function(_path)
      if _mocks.stat_exists then
        return { type = _mocks.stat_type }
      end
      return nil
    end

    Files.set_project_root("/test/repo")
  end)

  after_each(function()
    vim.fn.system = _mocks.orig_system
    vim.uv.fs_stat = _mocks.orig_stat

    pcall(function()
      rawset(vim.v, "shell_error", 0)
    end)
    Files.set_project_root("")
  end)

  it(
    "detects git repo with .git directory and uses git-based discovery",
    function()
      _mocks.stat_exists = true
      _mocks.stat_type = "directory"
      _mocks.system_output = "README.md\n"
      _mocks.system_exit = 0

      local files = Files.discover_files()

      assert.is_true(
        #_mocks.system_calls > 0,
        "git command should have been called"
      )
      local git_called = false
      for _, cmd in ipairs(_mocks.system_calls) do
        if cmd:match("git.*ls%-files") then
          git_called = true
          break
        end
      end
      assert.is_true(git_called, "git ls-files should have been executed")

      assert.is_true(#files > 0, "should return files from git")
      eq("README.md", files[1].path)
    end
  )

  it(
    "detects git repo with .git file (worktree) and uses git-based discovery",
    function()
      _mocks.stat_exists = true
      _mocks.stat_type = "file"
      _mocks.system_output = "src/main.lua\ntest/file.lua\n"
      _mocks.system_exit = 0

      local files = Files.discover_files()

      assert.is_true(
        #_mocks.system_calls > 0,
        "git command should have been called for worktree"
      )
      local git_called = false
      for _, cmd in ipairs(_mocks.system_calls) do
        if cmd:match("git.*ls%-files") then
          git_called = true
          break
        end
      end
      assert.is_true(git_called, "should use git for worktree .git file")

      assert.are.equal(2, #files)
      eq("src/main.lua", files[1].path)
      eq("test/file.lua", files[2].path)
    end
  )

  it("returns files when git command succeeds", function()
    _mocks.stat_exists = true
    _mocks.stat_type = "directory"
    _mocks.system_output = "README.md\nsrc/init.lua\nsrc/utils.lua\n"
    _mocks.system_exit = 0

    local files = Files.discover_files()

    assert.are.equal(3, #files)
    eq("README.md", files[1].path)
    eq("src/init.lua", files[2].path)
    eq("src/utils.lua", files[3].path)

    for _, f in ipairs(files) do
      assert.is_not_nil(f.path, "file should have path")
      assert.is_not_nil(f.name, "file should have name")
      assert.is_not_nil(f.absolute_path, "file should have absolute_path")
    end
  end)

  it("returns empty table (not nil) for empty repo", function()
    _mocks.stat_exists = true
    _mocks.stat_type = "directory"
    _mocks.system_output = ""
    _mocks.system_exit = 0

    local files = Files.discover_files()

    assert.is_not_nil(files, "should return table, not nil")
    assert.are.equal(0, #files, "should return empty table for empty repo")

    for _, cmd in ipairs(_mocks.system_calls) do
      assert.is_true(
        cmd:match("git") ~= nil,
        "should only call git, not fs commands"
      )
    end
  end)

  it("returns nil on git command failure", function()
    _mocks.stat_exists = true
    _mocks.stat_type = "directory"
    _mocks.system_output = "fatal: not a git repository"
    _mocks.system_exit = 128 -- Git failure

    local orig_scandir = vim.uv.fs_scandir
    vim.uv.fs_scandir = function(_dir)
      return nil -- Empty directory
    end

    local files = Files.discover_files()

    vim.uv.fs_scandir = orig_scandir

    local git_failed = false
    for _, cmd in ipairs(_mocks.system_calls) do
      if cmd:match("git") and vim.v.shell_error ~= 0 then
        git_failed = true
        break
      end
    end
    assert.is_true(git_failed, "git should have been called and failed")
  end)

  it("applies manual excludes on top of git output", function()
    _mocks.stat_exists = true
    _mocks.stat_type = "directory"
    _mocks.system_output =
      "README.md\n.env\n.env.local\nnode_modules/package.json\nsrc/main.lua\n"
    _mocks.system_exit = 0

    Files.setup({
      enabled = true,
      exclude = { ".env", ".env.*", "node_modules" },
    }, {})

    local files = Files.discover_files()

    assert.are.equal(2, #files)
    eq("README.md", files[1].path)
    eq("src/main.lua", files[2].path)

    for _, f in ipairs(files) do
      assert.is_nil(f.path:match("%.env"), ".env files should be excluded")
      assert.is_nil(
        f.path:match("node_modules"),
        "node_modules should be excluded"
      )
    end
  end)

  it(
    "excludes files by filename (not just path) consistent with fs scanner",
    function()
      _mocks.stat_exists = true
      _mocks.stat_type = "directory"
      _mocks.system_output = "README.md\nsrc/builder.js\nsrc/build/config.lua\n"
      _mocks.system_exit = 0

      Files.setup({
        enabled = true,
        exclude = { "build" },
      }, {})

      local files = Files.discover_files()

      assert.are.equal(1, #files)
      eq("README.md", files[1].path)

      for _, f in ipairs(files) do
        assert.is_nil(
          f.name:match("^build"),
          "files starting with 'build' should be excluded"
        )
      end
    end
  )

  it("uses --deduplicate flag to handle merge conflict duplicates", function()
    _mocks.stat_exists = true
    _mocks.stat_type = "directory"

    _mocks.system_output = "README.md\nREADME.md\nREADME.md\n"
    _mocks.system_exit = 0

    local files = Files.discover_files()

    local has_deduplicate = false
    for _, cmd in ipairs(_mocks.system_calls) do
      if cmd:match("%-%-deduplicate") then
        has_deduplicate = true
        break
      end
    end
    assert.is_true(
      has_deduplicate,
      "git command should include --deduplicate flag"
    )
  end)

  it("uses git-based discovery in git repo", function()
    _mocks.stat_exists = true
    _mocks.stat_type = "directory"
    _mocks.system_output = "tracked.txt\n"
    _mocks.system_exit = 0

    Files.discover_files()

    local git_called = false
    for _, cmd in ipairs(_mocks.system_calls) do
      if cmd:match("git") then
        git_called = true
        break
      end
    end
    assert.is_true(git_called, "should use git ls-files in git repo")
  end)

  it("falls back to filesystem when not in git repo", function()
    _mocks.stat_exists = false
    local orig_scandir = vim.uv.fs_scandir
    local fs_called = false
    vim.uv.fs_scandir = function(_dir)
      fs_called = true
      return nil -- Empty
    end

    Files.discover_files()

    vim.uv.fs_scandir = orig_scandir

    for _, cmd in ipairs(_mocks.system_calls) do
      assert.is_nil(
        cmd:match("git"),
        "git should not be called in non-git repo"
      )
    end

    assert.is_true(fs_called, "filesystem fallback should be used")
  end)

  it("returns cached files on subsequent calls", function()
    _mocks.stat_exists = true
    _mocks.stat_type = "directory"
    _mocks.system_output = "file.txt\n"
    _mocks.system_exit = 0

    local first = Files.get_files()
    local first_call_count = #_mocks.system_calls

    local second = Files.get_files()
    local second_call_count = #_mocks.system_calls

    eq(first, second)

    assert.are.equal(
      first_call_count,
      second_call_count,
      "should not re-scan, use cache"
    )
  end)

  it("handles empty root gracefully", function()
    Files.set_project_root("")

    local files = Files.discover_files()

    assert.is_not_nil(files, "should return table")
    assert.are.equal(0, #files, "should return empty for empty root")
  end)
end)
