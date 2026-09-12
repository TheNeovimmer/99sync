-- luacheck: globals describe it assert
local eq = assert.are.same
local Providers = require("99sync.providers")

describe("providers", function()
  describe("OpenCodeProvider", function()
    it("builds correct command with model", function()
      local request = { model = "anthropic/claude-fable-5-1" }
      local cmd =
        Providers.OpenCodeProvider._build_command(nil, "test query", request)
      eq({
        "opencode",
        "run",
        "--agent",
        "build",
        "-m",
        "anthropic/claude-fable-5-1",
        "test query",
      }, cmd)
    end)

    it("has correct default model", function()
      eq(
        "opencode/big-pickle",
        Providers.OpenCodeProvider._get_default_model()
      )
    end)
  end)

  describe("ClaudeCodeProvider", function()
    it("builds correct command with model", function()
      local request = { model = "anthropic/claude-fable-5-1" }
      local cmd =
        Providers.ClaudeCodeProvider._build_command(nil, "test query", request)
      eq({
        "claude",
        "--dangerously-skip-permissions",
        "--model",
        "anthropic/claude-fable-5-1",
        "--print",
        "test query",
      }, cmd)
    end)

    it("has correct default model", function()
      eq("claude-fable-5-1", Providers.ClaudeCodeProvider._get_default_model())
    end)
  end)

  describe("CursorAgentProvider", function()
    it("builds correct command with model", function()
      local request = { model = "anthropic/claude-fable-5-1" }
      local cmd =
        Providers.CursorAgentProvider._build_command(nil, "test query", request)
      eq({
        "cursor-agent",
        "--trust",
        "--force",
        "--model",
        "anthropic/claude-fable-5-1",
        "--print",
        "test query",
      }, cmd)
    end)

    it("has correct default model", function()
      eq("grok-4.6", Providers.CursorAgentProvider._get_default_model())
    end)
  end)

  describe("GeminiCLIProvider", function()
    it("builds correct command with model", function()
      local request = { model = "gemini-3.8-flash" }
      local cmd =
        Providers.GeminiCLIProvider._build_command(nil, "test query", request)
      eq({
        "gemini",
        "--approval-mode",
        "auto_edit",
        "--model",
        "gemini-3.8-flash",
        "--prompt",
        "test query",
      }, cmd)
    end)

    it("has correct default model", function()
      eq("gemini-3.8-flash", Providers.GeminiCLIProvider._get_default_model())
    end)
  end)

  describe("provider integration", function()
    it("can be set as provider override", function()
      local _99sync = require("99sync")

      _99sync.setup({ provider = Providers.ClaudeCodeProvider })
      local state = _99sync.__get_state()
      eq(Providers.ClaudeCodeProvider, state.provider_override)
    end)

    it(
      "uses OpenCodeProvider default model when no provider or model specified",
      function()
        local _99sync = require("99sync")

        _99sync.setup({})
        local state = _99sync.__get_state()
        eq("opencode/big-pickle", state.model)
      end
    )

    it(
      "uses ClaudeCodeProvider default model when provider specified but no model",
      function()
        local _99sync = require("99sync")

        _99sync.setup({ provider = Providers.ClaudeCodeProvider })
        local state = _99sync.__get_state()
        eq("claude-fable-5-1", state.model)
      end
    )

    it(
      "uses CursorAgentProvider default model when provider specified but no model",
      function()
        local _99sync = require("99sync")

        _99sync.setup({ provider = Providers.CursorAgentProvider })
        local state = _99sync.__get_state()
        eq("grok-4.6", state.model)
      end
    )

    it(
      "uses GeminiCLIProvider default model when provider specified but no model",
      function()
        local _99sync = require("99sync")

        _99sync.setup({ provider = Providers.GeminiCLIProvider })
        local state = _99sync.__get_state()
        eq("gemini-3.8-flash", state.model)
      end
    )

    it("uses custom model when both provider and model specified", function()
      local _99sync = require("99sync")

      _99sync.setup({
        provider = Providers.ClaudeCodeProvider,
        model = "custom-model",
      })
      local state = _99sync.__get_state()
      eq("custom-model", state.model)
    end)
  end)

  describe("provider_extra_args", function()
    it("stores provider_extra_args on state", function()
      local _99sync = require("99sync")
      _99sync.setup({
        provider_extra_args = { "--no-session-persistence" },
      })
      local state = _99sync.__get_state()
      eq({ "--no-session-persistence" }, state.provider_extra_args)
    end)

    it("defaults provider_extra_args to empty table", function()
      local _99sync = require("99sync")
      _99sync.setup({})
      local state = _99sync.__get_state()
      eq({}, state.provider_extra_args)
    end)
  end)

  describe("BaseProvider", function()
    it("all providers have make_request", function()
      eq("function", type(Providers.OpenCodeProvider.make_request))
      eq("function", type(Providers.ClaudeCodeProvider.make_request))
      eq("function", type(Providers.CursorAgentProvider.make_request))
      eq("function", type(Providers.GeminiCLIProvider.make_request))
    end)
  end)
end)
