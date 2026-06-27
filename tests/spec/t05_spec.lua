local tmp = vim.uv.os_tmpdir() .. "/jam_t05_" .. tostring(os.time())

local function cleanup(path)
  vim.fn.delete(path, "rf")
end

local function reset()
  package.loaded["jam.fs"] = nil
  cleanup(tmp)
end

describe("T-05 | Project location validation & creation", function()
  before_each(reset)

  it("returns error when path already exists", function()
    vim.fn.mkdir(tmp, "p")
    local ok, err = require("jam.fs").ensure_project_dir(tmp)
    expect(ok).to_be_nil()
    expect(err:find("already exists", 1, true) ~= nil).to_be_true()
  end)

  it("creates a directory that does not yet exist", function()
    local target = tmp .. "/myproject"
    local ok, err = require("jam.fs").ensure_project_dir(target)
    expect(err).to_be_nil()
    expect(ok).to_be_true()
    expect(vim.uv.fs_stat(target) ~= nil).to_be_true()
    cleanup(tmp)
  end)

  it("creates nested directories that do not exist", function()
    local target = tmp .. "/a/b/c/project"
    local ok, err = require("jam.fs").ensure_project_dir(target)
    expect(err).to_be_nil()
    expect(ok).to_be_true()
    expect(vim.uv.fs_stat(target) ~= nil).to_be_true()
    cleanup(tmp)
  end)

  it("returns error when path is a regular file", function()
    vim.fn.mkdir(tmp, "p")
    local file = tmp .. "/conflict"
    -- write a plain file at the target path
    local fd = vim.uv.fs_open(file, "w", 420)
    vim.uv.fs_close(fd)
    local ok, err = require("jam.fs").ensure_project_dir(file)
    expect(ok).to_be_nil()
    expect(err).not_to_be_nil()
    cleanup(tmp)
  end)
end)
