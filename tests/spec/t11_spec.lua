local tmp = vim.uv.os_tmpdir() .. "/jam_t11_" .. tostring(os.time())

local function cleanup()
  vim.fn.delete(tmp, "rf")
end

local function reset()
  package.loaded["jam.fs"] = nil
  package.loaded["jam.create"] = nil
  cleanup()
end

describe("T-11 | .gitignore content", function()
  before_each(reset)

  local function gitignore()
    return require("jam.create")._GITIGNORE
  end

  it("includes target/", function()
    expect(gitignore():find("target/", 1, true) ~= nil).to_be_true()
  end)

  it("includes *.class", function()
    expect(gitignore():find("*.class", 1, true) ~= nil).to_be_true()
  end)

  it("includes *.jar", function()
    expect(gitignore():find("*.jar", 1, true) ~= nil).to_be_true()
  end)

  it("includes .idea/", function()
    expect(gitignore():find(".idea/", 1, true) ~= nil).to_be_true()
  end)

  it("includes build/", function()
    expect(gitignore():find("build/", 1, true) ~= nil).to_be_true()
  end)

  it("includes .gradle/", function()
    expect(gitignore():find(".gradle/", 1, true) ~= nil).to_be_true()
  end)
end)

describe("T-11 | write_file", function()
  before_each(reset)

  it("creates a file with the given content", function()
    vim.fn.mkdir(tmp, "p")
    local path = tmp .. "/test.txt"
    local ok, err = require("jam.fs").write_file(path, "hello")
    expect(ok).to_be_true()
    expect(err).to_be_nil()
    local fd = vim.uv.fs_open(path, "r", 292)
    local data = vim.uv.fs_read(fd, 5, 0)
    vim.uv.fs_close(fd)
    expect(data).to_be("hello")
    cleanup()
  end)

  it("overwrites an existing file", function()
    vim.fn.mkdir(tmp, "p")
    local path = tmp .. "/test.txt"
    local fs = require("jam.fs")
    fs.write_file(path, "first")
    fs.write_file(path, "second")
    local fd = vim.uv.fs_open(path, "r", 292)
    local data = vim.uv.fs_read(fd, 6, 0)
    vim.uv.fs_close(fd)
    expect(data).to_be("second")
    cleanup()
  end)

  it("returns error when parent directory does not exist", function()
    local ok, err = require("jam.fs").write_file("/nonexistent_jam_dir/file.txt", "x")
    expect(ok).to_be_nil()
    expect(err).not_to_be_nil()
  end)
end)

describe("T-11 | git_init", function()
  before_each(reset)

  it("calls vim.uv.spawn with 'git' and 'init'", function()
    local captured = nil
    local orig = vim.uv.spawn
    vim.uv.spawn = function(cmd, opts, _cb)
      captured = { cmd = cmd, opts = opts }
      -- return a fake closeable handle and fake pid
      return { close = function() end }, 999
    end
    require("jam.fs").git_init("/tmp/fakedir", function() end)
    vim.uv.spawn = orig
    expect(captured).not_to_be_nil()
    expect(captured.cmd).to_be("git")
    expect(captured.opts.args).to_contain("init")
  end)

  it("sets cwd to the given directory", function()
    local captured_cwd = nil
    local orig = vim.uv.spawn
    vim.uv.spawn = function(_cmd, opts, _cb)
      captured_cwd = opts.cwd
      return { close = function() end }, 999
    end
    require("jam.fs").git_init("/tmp/myproject", function() end)
    vim.uv.spawn = orig
    expect(captured_cwd).to_be("/tmp/myproject")
  end)

  it("calls callback(false) when spawn returns nil (git not found)", function()
    local result = nil
    local orig = vim.uv.spawn
    vim.uv.spawn = function(_cmd, _opts, _cb)
      return nil -- simulate binary not found
    end
    -- vim.schedule is synchronous in headless tests when nothing is pending
    local orig_schedule = vim.schedule
    vim.schedule = function(fn)
      fn()
    end
    require("jam.fs").git_init("/tmp/fakedir", function(ok)
      result = ok
    end)
    vim.uv.spawn = orig
    vim.schedule = orig_schedule
    expect(result).to_be(false)
  end)
end)
