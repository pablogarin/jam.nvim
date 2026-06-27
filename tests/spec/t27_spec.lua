local function reset()
  package.loaded["jam.lsp"] = nil
  package.loaded["jdtls"] = nil
  -- Intercept require("jdtls") so it fails without consulting the real loader
  package.preload["jdtls"] = function()
    error("jdtls not installed (test stub)")
  end
end


describe("T-27 | nvim-jdtls detection and session warning", function()
  before_each(reset)

  it("check() returns false when jdtls is not installed", function()
    local ok, mod = require("jam.lsp").check()
    expect(ok).to_be(false)
    expect(mod).to_be_nil()
  end)

  it("check() returns true when jdtls is available", function()
    package.loaded["jdtls"] = { start_or_attach = function() end }
    local ok, mod = require("jam.lsp").check()
    expect(ok).to_be_true()
    expect(mod ~= nil).to_be_true()
  end)

  it("maybe_warn() returns false and emits WARN when jdtls is absent", function()
    local got_level = nil
    local orig = vim.notify
    vim.notify = function(_, level)
      got_level = level
    end
    local result = require("jam.lsp").maybe_warn()
    vim.notify = orig
    expect(result).to_be(false)
    expect(got_level).to_be(vim.log.levels.WARN)
  end)

  it("maybe_warn() emits WARN only once per session even when called twice", function()
    local warn_count = 0
    local orig = vim.notify
    vim.notify = function(_, level)
      if level == vim.log.levels.WARN then
        warn_count = warn_count + 1
      end
    end
    local lsp = require("jam.lsp")
    lsp.maybe_warn()
    lsp.maybe_warn()
    vim.notify = orig
    expect(warn_count).to_be(1)
  end)

  it("_reset_warned() allows the warning to fire again", function()
    local warn_count = 0
    local orig = vim.notify
    vim.notify = function(_, level)
      if level == vim.log.levels.WARN then
        warn_count = warn_count + 1
      end
    end
    local lsp = require("jam.lsp")
    lsp.maybe_warn()
    lsp._reset_warned()
    lsp.maybe_warn()
    vim.notify = orig
    expect(warn_count).to_be(2)
  end)

  it("maybe_warn() returns true and emits no warning when jdtls is present", function()
    package.loaded["jdtls"] = { start_or_attach = function() end }
    local warned = false
    local orig = vim.notify
    vim.notify = function(_, level)
      if level == vim.log.levels.WARN then
        warned = true
      end
    end
    local result = require("jam.lsp").maybe_warn()
    vim.notify = orig
    expect(result).to_be_true()
    expect(warned).to_be(false)
  end)

  it("maybe_warn() warning message contains install instruction", function()
    local got_msg = nil
    local orig = vim.notify
    vim.notify = function(msg, _)
      got_msg = msg
    end
    require("jam.lsp").maybe_warn()
    vim.notify = orig
    expect(got_msg:find("nvim-jdtls", 1, true) ~= nil).to_be_true()
    expect(got_msg:find("MasonInstall", 1, true) ~= nil).to_be_true()
  end)
end)
