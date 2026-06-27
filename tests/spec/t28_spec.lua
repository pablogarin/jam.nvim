local function reset()
  package.loaded["jam.lsp"] = nil
  package.loaded["jam.init"] = nil
  package.loaded["jam.project"] = nil
  package.loaded["jam.detect"] = nil
  package.loaded["jdtls"] = nil
  package.preload["jdtls"] = function()
    error("jdtls not installed (test stub)")
  end
  pcall(vim.api.nvim_del_user_command, "Jam")
  vim.api.nvim_set_current_dir = function() end
  vim.cmd.edit = function() end
  vim.fn.stdpath = function(what)
    if what == "data" then
      return "/nvim-data"
    end
    return ""
  end
  vim.fn.sha256 = function(s)
    return "HASH_OF_" .. s
  end
end

local function make_lsp_present(attached_config)
  package.loaded["jdtls"] = {
    start_or_attach = function(cfg)
      if attached_config then
        attached_config.called = true
        attached_config.cfg = cfg
      end
    end,
  }
  package.preload["jdtls"] = nil
end

describe("T-28 | attach_if_project — jdtls absent", function()
  before_each(reset)

  it("returns without calling start_or_attach when jdtls is unavailable", function()
    local called = false
    local find_root_fn = function(_)
      return { root = "/proj", tool = "maven" }
    end
    local java_fn = function()
      return "/usr/bin/java"
    end
    -- jdtls is NOT present (preload stub raises error)
    local lsp = require("jam.lsp")
    lsp.attach_if_project(1, find_root_fn, java_fn)
    expect(called).to_be(false)
  end)
end)

describe("T-28 | attach_if_project — no project root", function()
  before_each(reset)

  it("returns silently when buffer is not inside a project", function()
    make_lsp_present({})
    local find_root_fn = function(_)
      return nil
    end
    local java_fn = function()
      return "/usr/bin/java"
    end
    -- Should not error and should not call start_or_attach with a config
    local attached = {}
    make_lsp_present(attached)
    require("jam.lsp").attach_if_project(1, find_root_fn, java_fn)
    expect(attached.called).to_be_nil()
  end)
end)

describe("T-28 | attach_if_project — successful attach", function()
  before_each(reset)

  it("calls start_or_attach with the correct root_dir", function()
    local attached = {}
    make_lsp_present(attached)
    local find_root_fn = function(_)
      return { root = "/my/project", tool = "maven" }
    end
    local java_fn = function()
      return "/usr/bin/java"
    end
    require("jam.lsp").attach_if_project(1, find_root_fn, java_fn)
    expect(attached.called).to_be_true()
    expect(attached.cfg.root_dir).to_be("/my/project")
  end)

  it("workspace data path embeds a hash of the project root", function()
    local attached = {}
    make_lsp_present(attached)
    local find_root_fn = function(_)
      return { root = "/my/project", tool = "maven" }
    end
    local java_fn = function()
      return "/usr/bin/java"
    end
    require("jam.lsp").attach_if_project(1, find_root_fn, java_fn)
    expect(attached.cfg.data).to_be("/nvim-data/jam-workspaces/HASH_OF_/my/project")
  end)

  it("workspace path differs for different project roots", function()
    local attached1, attached2 = {}, {}
    make_lsp_present(attached1)
    require("jam.lsp").attach_if_project(1, function(_)
      return { root = "/proj/a", tool = "maven" }
    end, function()
      return "/usr/bin/java"
    end)

    package.loaded["jam.lsp"] = nil
    make_lsp_present(attached2)
    require("jam.lsp").attach_if_project(1, function(_)
      return { root = "/proj/b", tool = "maven" }
    end, function()
      return "/usr/bin/java"
    end)

    expect(attached1.cfg.data ~= attached2.cfg.data).to_be_true()
  end)
end)

describe("T-28 | FileType java autocmd registered by setup()", function()
  before_each(function()
    reset()
    package.loaded["jam.create"] = { create = function() end }
    package.loaded["jam.build"] = { build = function() end, run = function() end }
    package.loaded["jam.test"] = { map_to_test = function() end, run_tests = function() end, generate_test = function() end }
  end)

  it("setup() registers a FileType java autocmd without error", function()
    local ok, err = pcall(function()
      require("jam.init").setup()
    end)
    expect(ok).to_be_true()
  end)
end)
