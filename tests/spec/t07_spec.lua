local function reset()
  package.loaded["jam.create"] = nil
end

describe("T-07 | Package name inference", function()
  before_each(reset)

  local function infer(name)
    return require("jam.create")._infer_package(name)
  end

  local function to_path(pkg)
    return require("jam.create")._package_to_path(pkg)
  end

  -- infer_package
  it("lowercases the project name", function()
    expect(infer("MyProject")).to_be("org.example.myproject")
  end)

  it("strips hyphens", function()
    expect(infer("my-project")).to_be("org.example.myproject")
  end)

  it("strips underscores", function()
    expect(infer("my_project")).to_be("org.example.myproject")
  end)

  it("strips dots", function()
    expect(infer("my.project")).to_be("org.example.myproject")
  end)

  it("preserves digits in the middle", function()
    expect(infer("project2")).to_be("org.example.project2")
  end)

  it("prepends 'p' when sanitized segment starts with a digit", function()
    expect(infer("2cool")).to_be("org.example.p2cool")
  end)

  it("falls back to 'app' when all characters are stripped", function()
    expect(infer("---")).to_be("org.example.app")
  end)

  it("always prepends org.example.", function()
    local result = infer("hello")
    expect(result:sub(1, 11)).to_be("org.example")
  end)

  -- package_to_path
  it("converts dots to slashes", function()
    expect(to_path("org.example.myproject")).to_be("org/example/myproject")
  end)

  it("handles a single-segment package", function()
    expect(to_path("mypackage")).to_be("mypackage")
  end)

  it("handles two-segment package", function()
    expect(to_path("com.example")).to_be("com/example")
  end)
end)
