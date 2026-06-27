local function reset()
  package.loaded["jam.create"] = nil
end

describe("T-04 | Project location resolution", function()
  before_each(reset)

  local function resolve(name, override)
    return require("jam.create")._resolve_location(name, override)
  end

  it("default path is cwd/name", function()
    local result = resolve("myapp")
    local expected = vim.uv.cwd() .. "/myapp"
    expect(result).to_be(expected)
  end)

  it("override path is used when provided", function()
    local result = resolve("myapp", "/tmp/projects/myapp")
    expect(result).to_be("/tmp/projects/myapp")
  end)

  it("expands ~ in override", function()
    local result = resolve("myapp", "~/projects/myapp")
    local home = vim.uv.os_homedir()
    expect(result).to_be(home .. "/projects/myapp")
  end)

  it("expands $HOME in override", function()
    local result = resolve("myapp", "$HOME/projects/myapp")
    local home = vim.uv.os_homedir()
    expect(result).to_be(home .. "/projects/myapp")
  end)

  it("default path changes with different project names", function()
    local r1 = resolve("alpha")
    local r2 = resolve("beta")
    expect(r1 == r2).to_be(false)
  end)
end)
