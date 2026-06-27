local function reset()
  package.loaded["jam.build"] = nil
  package.loaded["jam.project"] = nil
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
  package.loaded["jam.output"] = {
    get_or_create = function(_)
      return 1
    end,
    open = function() end,
    clear = function() end,
    append = function() end,
  }
end

local function stub_project(tool)
  package.loaded["jam.project"] = {
    find_root = function()
      return { root = "/proj", tool = tool or "maven" }
    end,
  }
end

describe("T-23 | :Jam run — argv selection", function()
  before_each(reset)

  it("maven uses 'mvn exec:java -Dexec.mainClass=<class>'", function()
    local cmd, args = require("jam.build")._run_argv("maven", "/proj", "org.example.Main")
    expect(cmd).to_be("mvn")
    expect(args[1]).to_be("exec:java")
    expect(args[2]).to_be("-Dexec.mainClass=org.example.Main")
  end)

  it("gradle uses 'gradle run'", function()
    local cmd, args = require("jam.build")._run_argv("gradle", "/proj", "org.example.Main")
    expect(cmd).to_be("gradle")
    expect(args[1]).to_be("run")
  end)

  it("none uses 'java -cp target/classes <class>'", function()
    local cmd, args = require("jam.build")._run_argv("none", "/proj", "org.example.Main")
    expect(cmd).to_be("java")
    expect(args[1]).to_be("-cp")
    expect(args[2]).to_be("/proj/target/classes")
    expect(args[3]).to_be("org.example.Main")
  end)
end)

describe("T-23 | :Jam run — build gate", function()
  before_each(reset)

  it("does not spawn run command when build fails", function()
    stub_output()
    stub_project("maven")

    local spawn_calls = {}
    vim.uv.spawn = function(cmd, _, cb)
      table.insert(spawn_calls, cmd)
      cb(1) -- build fails
      return { close = function() end }
    end

    -- Stub resolve_main_class so it would return a class if called
    local build = require("jam.build")
    build.resolve_main_class = function(_, cb)
      cb("org.example.Main")
    end

    build.run()
    -- Only the build spawn should have occurred, not the run spawn
    expect(#spawn_calls).to_be(1)
    expect(spawn_calls[1]).to_be("mvn")
  end)

  it("does not spawn run command when main class resolution returns nil", function()
    stub_output()
    stub_project("maven")

    local spawn_calls = {}
    vim.uv.spawn = function(cmd, _, cb)
      table.insert(spawn_calls, cmd)
      cb(0) -- build succeeds
      return { close = function() end }
    end

    local build = require("jam.build")
    build.resolve_main_class = function(_, cb)
      cb(nil) -- user cancelled
    end

    build.run()
    expect(#spawn_calls).to_be(1) -- only build, no run
  end)

  it("spawns run command after successful build", function()
    stub_output()
    stub_project("maven")

    local spawn_calls = {}
    vim.uv.spawn = function(cmd, _, cb)
      table.insert(spawn_calls, cmd)
      cb(0)
      return { close = function() end }
    end

    local build = require("jam.build")
    build.resolve_main_class = function(_, cb)
      cb("org.example.Main")
    end

    build.run()
    expect(#spawn_calls).to_be(2)
    expect(spawn_calls[2]).to_be("mvn") -- mvn exec:java
  end)
end)
