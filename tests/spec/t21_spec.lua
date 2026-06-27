local function reset()
  package.loaded["jam.build"] = nil
  package.loaded["jam.project"] = nil
  package.loaded["jam.output"] = nil
  vim.api.nvim_set_current_dir = function() end
end

local function stub_output()
  local opened = false
  local cleared = false
  package.loaded["jam.output"] = {
    get_or_create = function(_)
      return 1
    end,
    open = function(_)
      opened = true
    end,
    clear = function(_)
      cleared = true
    end,
    append = function() end,
  }
  return function()
    return opened, cleared
  end
end

describe("T-21 | :Jam build — argv selection", function()
  before_each(reset)

  it("maven tool uses 'mvn compile'", function()
    local cmd, args = require("jam.build")._build_argv("maven", "/tmp/proj")
    expect(cmd).to_be("mvn")
    expect(args[1]).to_be("compile")
  end)

  it("gradle tool uses 'gradle classes'", function()
    local cmd, args = require("jam.build")._build_argv("gradle", "/tmp/proj")
    expect(cmd).to_be("gradle")
    expect(args[1]).to_be("classes")
  end)

  it("none tool uses 'javac' with -d target/classes", function()
    local cmd, args = require("jam.build")._build_argv("none", "/tmp/proj")
    expect(cmd).to_be("javac")
    expect(args[1]).to_be("-d")
    expect(args[2]).to_be("/tmp/proj/target/classes")
  end)
end)

describe("T-21 | :Jam build — notifications", function()
  before_each(reset)

  local function run_build_with_exit(exit_code)
    local spawned_cmd = nil
    stub_output()
    package.loaded["jam.project"] = {
      find_root = function()
        return { root = "/tmp/proj", tool = "maven" }
      end,
    }
    vim.uv.spawn = function(cmd, _, cb)
      spawned_cmd = cmd
      cb(exit_code)
      return { close = function() end }
    end
    vim.uv.new_pipe = function()
      return {
        close = function() end,
        read_start = function() end,
      }
    end
    vim.uv.read_start = function() end
    vim.schedule = function(fn)
      fn()
    end

    local got_level = nil
    local orig = vim.notify
    vim.notify = function(_, level)
      got_level = level
    end
    require("jam.build").build()
    vim.notify = orig
    return got_level, spawned_cmd
  end

  it("emits INFO notification on exit code 0", function()
    local level = run_build_with_exit(0)
    expect(level).to_be(vim.log.levels.INFO)
  end)

  it("emits ERROR notification on non-zero exit code", function()
    local level = run_build_with_exit(1)
    expect(level).to_be(vim.log.levels.ERROR)
  end)

  it("spawns the correct command for the detected tool", function()
    local _, cmd = run_build_with_exit(0)
    expect(cmd).to_be("mvn")
  end)
end)

describe("T-21 | :Jam build — no project root", function()
  before_each(reset)

  it("emits ERROR and does not spawn when no project root is found", function()
    stub_output()
    package.loaded["jam.project"] = {
      find_root = function()
        return nil
      end,
    }
    local spawned = false
    vim.uv.spawn = function()
      spawned = true
    end

    local got_level = nil
    local orig = vim.notify
    vim.notify = function(_, level)
      got_level = level
    end
    require("jam.build").build()
    vim.notify = orig

    expect(got_level).to_be(vim.log.levels.ERROR)
    expect(spawned).to_be(false)
  end)
end)
