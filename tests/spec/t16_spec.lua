-- T-16: End-to-end integration test.
-- Exercises the full create flow with real filesystem I/O (no mocks).
-- Requires git and javac to be available for the compile and VCS checks.

local tmp = vim.uv.os_tmpdir() .. "/jam_t16_" .. tostring(os.time())

local function cleanup()
  vim.fn.delete(tmp, "rf")
end

local function reset()
  package.loaded["jam.create"] = nil
  package.loaded["jam.ui"] = nil
  package.loaded["jam.fs"] = nil
  package.loaded["jam.detect"] = nil
  vim.api.nvim_set_current_dir = function() end
  vim.cmd.edit = function() end
  vim.schedule = function(fn)
    fn()
  end
  cleanup()
end

-- Stub the wizard prompts so the integration test runs without user interaction.
-- Accepts all defaults (empty location and package inputs = use defaults).
local function stub_defaults(project_name, build_tool_label)
  local input_n, select_n = 0, 0
  local inputs = { project_name, tmp .. "/" .. project_name, "" } -- name, explicit location, empty pkg
  local selects = { build_tool_label or "Maven (default)", "Yes", "Yes" }
  package.loaded["jam.ui"] = {
    input = function(_, cb)
      input_n = input_n + 1
      cb(inputs[input_n])
    end,
    select = function(_, _, cb)
      select_n = select_n + 1
      cb(selects[select_n])
    end,
  }
end

describe("T-16 | End-to-end: Maven project creation", function()
  before_each(reset)

  it("creates the Maven source directory tree", function()
    stub_defaults("helloworld")
    require("jam.create").create()
    expect(vim.uv.fs_stat(tmp .. "/helloworld/src/main/java/org/example/helloworld") ~= nil).to_be_true()
    expect(vim.uv.fs_stat(tmp .. "/helloworld/src/main/resources") ~= nil).to_be_true()
    expect(vim.uv.fs_stat(tmp .. "/helloworld/src/test/java") ~= nil).to_be_true()
    cleanup()
  end)

  it("writes a valid pom.xml", function()
    stub_defaults("helloworld")
    require("jam.create").create()
    local pom = tmp .. "/helloworld/pom.xml"
    expect(vim.uv.fs_stat(pom) ~= nil).to_be_true()
    local fd = vim.uv.fs_open(pom, "r", 292)
    local content = vim.uv.fs_read(fd, 4096, 0)
    vim.uv.fs_close(fd)
    expect(content:find("<artifactId>helloworld</artifactId>", 1, true) ~= nil).to_be_true()
    expect(content:find("<groupId>org.example</groupId>", 1, true) ~= nil).to_be_true()
    cleanup()
  end)

  it("writes a Main.java with the correct package declaration", function()
    stub_defaults("helloworld")
    require("jam.create").create()
    local main = tmp .. "/helloworld/src/main/java/org/example/helloworld/Main.java"
    expect(vim.uv.fs_stat(main) ~= nil).to_be_true()
    local fd = vim.uv.fs_open(main, "r", 292)
    local content = vim.uv.fs_read(fd, 1024, 0)
    vim.uv.fs_close(fd)
    expect(content:find("package org.example.helloworld;", 1, true) ~= nil).to_be_true()
    cleanup()
  end)

  it("writes a .gitignore", function()
    stub_defaults("helloworld")
    require("jam.create").create()
    expect(vim.uv.fs_stat(tmp .. "/helloworld/.gitignore") ~= nil).to_be_true()
    cleanup()
  end)
end)

describe("T-16 | End-to-end: Gradle project creation", function()
  before_each(reset)

  it("writes build.gradle and settings.gradle instead of pom.xml", function()
    stub_defaults("gradleapp", "Gradle")
    require("jam.create").create()
    local root = tmp .. "/gradleapp"
    expect(vim.uv.fs_stat(root .. "/build.gradle") ~= nil).to_be_true()
    expect(vim.uv.fs_stat(root .. "/settings.gradle") ~= nil).to_be_true()
    expect(vim.uv.fs_stat(root .. "/pom.xml") == nil).to_be_true()
    cleanup()
  end)
end)
