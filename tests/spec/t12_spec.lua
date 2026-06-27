local function reset()
  package.loaded["jam.create"] = nil
  package.loaded["jam.fs"] = nil
  package.loaded["jam.detect"] = nil
  vim.api.nvim_set_current_dir = function() end
  vim.cmd.edit = function() end
end

describe("T-12 | Build tool selection prompt", function()
  before_each(reset)

  it("BUILD_TOOL_ITEMS contains exactly three entries", function()
    expect(#require("jam.create")._BUILD_TOOL_ITEMS).to_be(3)
  end)

  it("BUILD_TOOL_ITEMS includes 'Maven (default)'", function()
    expect(require("jam.create")._BUILD_TOOL_ITEMS).to_contain("Maven (default)")
  end)

  it("BUILD_TOOL_ITEMS includes 'Gradle'", function()
    expect(require("jam.create")._BUILD_TOOL_ITEMS).to_contain("Gradle")
  end)

  it("BUILD_TOOL_ITEMS includes 'No Build Tools'", function()
    expect(require("jam.create")._BUILD_TOOL_ITEMS).to_contain("No Build Tools")
  end)

  it("'Maven (default)' maps to 'maven'", function()
    expect(require("jam.create")._LABEL_TO_TOOL["Maven (default)"]).to_be("maven")
  end)

  it("'Gradle' maps to 'gradle'", function()
    expect(require("jam.create")._LABEL_TO_TOOL["Gradle"]).to_be("gradle")
  end)

  it("'No Build Tools' maps to 'none'", function()
    expect(require("jam.create")._LABEL_TO_TOOL["No Build Tools"]).to_be("none")
  end)

  it("create() calls vim.ui.select after vim.ui.input", function()
    local calls = {}
    vim.ui.input = function(_, cb)
      table.insert(calls, "input")
      cb("myapp")
    end
    vim.ui.select = function(_, _, cb)
      table.insert(calls, "select")
      cb(nil) -- cancel to stop the flow early
    end
    -- stub out downstream modules
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return true
      end,
    }
    package.loaded["jam.detect"] = {
      find_java = function()
        return nil
      end,
    }
    require("jam.create").create()
    expect(calls).to_contain("input")
    expect(calls).to_contain("select")
  end)

  it("cancelling the build tool prompt stops the wizard", function()
    local notified = false
    vim.ui.input = function(_, cb)
      cb("myapp")
    end
    vim.ui.select = function(_, _, cb)
      cb(nil) -- user cancels
    end
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return true
      end,
    }
    package.loaded["jam.detect"] = {
      find_java = function()
        return nil
      end,
    }
    local orig = vim.notify
    vim.notify = function(msg, level)
      if level == vim.log.levels.INFO then
        notified = true
      end
    end
    require("jam.create").create()
    vim.notify = orig
    expect(notified).to_be(false)
  end)

  it("selecting 'No Build Tools' skips pom.xml generation", function()
    local wrote_pom = false
    vim.ui.input = function(_, cb)
      cb("myapp")
    end
    vim.ui.select = function(_, _, cb)
      cb("No Build Tools")
    end
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return true
      end,
      scaffold_maven = function()
        return true
      end,
      write_file = function(path, _)
        if path:find("pom.xml", 1, true) then
          wrote_pom = true
        end
        return true
      end,
      git_init = function(_, cb)
        cb(true)
      end,
    }
    package.loaded["jam.detect"] = {
      find_java = function()
        return nil
      end,
      find_java_version = function()
        return 17
      end,
    }
    require("jam.create").create()
    expect(wrote_pom).to_be(false)
  end)

  it("selecting 'Maven (default)' writes pom.xml", function()
    local wrote_pom = false
    vim.ui.input = function(_, cb)
      cb("myapp")
    end
    vim.ui.select = function(_, _, cb)
      cb("Maven (default)")
    end
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return true
      end,
      scaffold_maven = function()
        return true
      end,
      write_file = function(path, _)
        if path:find("pom.xml", 1, true) then
          wrote_pom = true
        end
        return true
      end,
      git_init = function(_, cb)
        cb(true)
      end,
    }
    package.loaded["jam.detect"] = {
      find_java = function()
        return nil
      end,
      find_java_version = function()
        return 17
      end,
    }
    require("jam.create").create()
    expect(wrote_pom).to_be_true()
  end)
end)
