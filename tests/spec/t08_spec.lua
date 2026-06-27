local tmp = vim.uv.os_tmpdir() .. "/jam_t08_" .. tostring(os.time())

local function cleanup()
  vim.fn.delete(tmp, "rf")
end

local function reset()
  package.loaded["jam.fs"] = nil
  cleanup()
end

describe("T-08 | Maven directory scaffolding", function()
  before_each(reset)

  it("creates src/main/java/<pkg_path>", function()
    vim.fn.mkdir(tmp, "p")
    require("jam.fs").scaffold_maven(tmp, "org/example/myproject")
    expect(vim.uv.fs_stat(tmp .. "/src/main/java/org/example/myproject") ~= nil).to_be_true()
    cleanup()
  end)

  it("creates src/main/resources", function()
    vim.fn.mkdir(tmp, "p")
    require("jam.fs").scaffold_maven(tmp, "org/example/myproject")
    expect(vim.uv.fs_stat(tmp .. "/src/main/resources") ~= nil).to_be_true()
    cleanup()
  end)

  it("creates src/test/java", function()
    vim.fn.mkdir(tmp, "p")
    require("jam.fs").scaffold_maven(tmp, "org/example/myproject")
    expect(vim.uv.fs_stat(tmp .. "/src/test/java") ~= nil).to_be_true()
    cleanup()
  end)

  it("returns true on success", function()
    vim.fn.mkdir(tmp, "p")
    local ok, err = require("jam.fs").scaffold_maven(tmp, "org/example/app")
    expect(ok).to_be_true()
    expect(err).to_be_nil()
    cleanup()
  end)

  it("is idempotent when directories already exist", function()
    vim.fn.mkdir(tmp, "p")
    local fs = require("jam.fs")
    fs.scaffold_maven(tmp, "org/example/app")
    local ok, err = fs.scaffold_maven(tmp, "org/example/app")
    expect(ok).to_be_true()
    expect(err).to_be_nil()
    cleanup()
  end)
end)
