local function reset()
  package.loaded["jam.test"] = nil
  package.loaded["jam.output"] = nil
  vim.schedule = function(fn)
    fn()
  end
  vim.uv.new_pipe = function()
    return { close = function() end }
  end
  vim.uv.read_start = function() end
end

local function stub_output()
  local opened = false
  package.loaded["jam.output"] = {
    get_or_create = function(_)
      return 1
    end,
    open = function(_)
      opened = true
    end,
    clear = function() end,
    append = function() end,
  }
  return function()
    return opened
  end
end

local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR

describe("T-25 | run_tests — argv per tool", function()
  before_each(reset)

  it("maven: 'mvn test -Dtest=<ClassName>'", function()
    local cmd, args = require("jam.test")._test_argv("maven", "FooTest", "org.example.FooTest", "/proj")
    expect(cmd).to_be("mvn")
    expect(args[1]).to_be("test")
    expect(args[2]).to_be("-Dtest=FooTest")
  end)

  it("gradle: 'gradle test --tests <fqcn>'", function()
    local cmd, args = require("jam.test")._test_argv("gradle", "FooTest", "org.example.FooTest", "/proj")
    expect(cmd).to_be("gradle")
    expect(args[1]).to_be("test")
    expect(args[2]).to_be("--tests")
    expect(args[3]).to_be("org.example.FooTest")
  end)

  it("none: java ConsoleLauncher --select-class=<fqcn>", function()
    local cmd, args = require("jam.test")._test_argv("none", "FooTest", "org.example.FooTest", "/proj")
    expect(cmd).to_be("java")
    expect(args[#args]).to_be("--select-class=org.example.FooTest")
  end)
end)

describe("T-25 | run_tests — exit-code notification levels", function()
  before_each(reset)

  local function run_with_exit(exit_code)
    stub_output()
    vim.uv.spawn = function(_, _, cb)
      cb(exit_code)
      return { close = function() end }
    end
    local got_level = nil
    local orig = vim.notify
    vim.notify = function(_, level)
      got_level = level
    end
    require("jam.test").run_tests("/proj", "maven", { class_name = "FooTest", fqcn = "org.example.FooTest" })
    vim.notify = orig
    return got_level
  end

  it("exit 0 → INFO notification", function()
    expect(run_with_exit(0)).to_be(INFO)
  end)

  it("exit 1 → WARN notification (test failures)", function()
    expect(run_with_exit(1)).to_be(WARN)
  end)

  it("exit 2 → ERROR notification (runner error)", function()
    expect(run_with_exit(2)).to_be(ERROR)
  end)

  it("opens the output buffer", function()
    local opened = stub_output()
    vim.uv.spawn = function(_, _, cb)
      cb(0)
      return { close = function() end }
    end
    require("jam.test").run_tests("/proj", "maven", { class_name = "FooTest", fqcn = "org.example.FooTest" })
    expect(opened()).to_be_true()
  end)
end)

describe("T-25 | :Jam test handler — routing", function()
  before_each(function()
    reset()
    package.loaded["jam.project"] = nil
    package.loaded["jam.test"] = nil
    package.loaded["jam.init"] = nil
    pcall(vim.api.nvim_del_user_command, "Jam")
    vim.api.nvim_set_current_dir = function() end
    vim.cmd.edit = function() end
  end)

  it("emits ERROR when no project root is found", function()
    package.loaded["jam.project"] = {
      find_root = function()
        return nil
      end,
    }
    package.loaded["jam.test"] = {
      map_to_test = function()
        return nil, "not in src/main/java/"
      end,
      run_tests = function() end,
      generate_test = function() end,
    }
    require("jam.init").setup()
    local got_level = nil
    local orig = vim.notify
    vim.notify = function(_, level)
      got_level = level
    end
    vim.api.nvim_exec_autocmds("CmdlineEnter", {})
    vim.cmd("Jam test")
    vim.notify = orig
    expect(got_level).to_be(ERROR)
  end)

  it("emits ERROR when buffer is outside src/main/java/", function()
    package.loaded["jam.project"] = {
      find_root = function()
        return { root = "/proj", tool = "maven" }
      end,
    }
    local run_called = false
    package.loaded["jam.test"] = {
      map_to_test = function()
        return nil, "current file is not inside src/main/java/"
      end,
      run_tests = function()
        run_called = true
      end,
      generate_test = function() end,
    }
    require("jam.init").setup()
    local got_level = nil
    local orig = vim.notify
    vim.notify = function(_, level)
      got_level = level
    end
    vim.cmd("Jam test")
    vim.notify = orig
    expect(got_level).to_be(ERROR)
    expect(run_called).to_be(false)
  end)
end)
