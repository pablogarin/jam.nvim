local function reset()
  package.loaded["jam.test"] = nil
end

local ROOT = "/home/user/myapp"

local function map(buf_path, exists_paths)
  local stat_fn = function(path)
    return (exists_paths or {})[path] or nil
  end
  return require("jam.test")._map_to_test(buf_path, ROOT, stat_fn)
end

describe("T-24 | Test file mapping", function()
  before_each(reset)

  it("returns error when file is outside src/main/java/", function()
    local result, err = map(ROOT .. "/src/test/java/org/example/FooTest.java", {})
    expect(result).to_be_nil()
    expect(err ~= nil).to_be_true()
  end)

  it("returns error for a non-.java file path", function()
    local result, err = map(ROOT .. "/src/main/java/org/example/README.md", {})
    expect(result).to_be_nil()
    expect(err ~= nil).to_be_true()
  end)

  it("maps a simple class to its Test counterpart", function()
    local result = map(ROOT .. "/src/main/java/org/example/app/Foo.java", {})
    expect(result ~= nil).to_be_true()
    expect(result.class_name).to_be("FooTest")
  end)

  it("test_path is in src/test/java/ with the same package", function()
    local result = map(ROOT .. "/src/main/java/org/example/app/Foo.java", {})
    expect(result.test_path).to_be(ROOT .. "/src/test/java/org/example/app/FooTest.java")
  end)

  it("fqcn combines package and test class name", function()
    local result = map(ROOT .. "/src/main/java/org/example/app/Foo.java", {})
    expect(result.fqcn).to_be("org.example.app.FooTest")
  end)

  it("exists is false when test file is not on disk", function()
    local result = map(ROOT .. "/src/main/java/org/example/app/Foo.java", {})
    expect(result.exists).to_be(false)
  end)

  it("exists is true when test file is present on disk", function()
    local test_path = ROOT .. "/src/test/java/org/example/app/FooTest.java"
    local result = map(ROOT .. "/src/main/java/org/example/app/Foo.java", {
      [test_path] = true,
    })
    expect(result.exists).to_be_true()
  end)

  it("handles a top-level class with no package subdirectory", function()
    local result = map(ROOT .. "/src/main/java/Main.java", {})
    expect(result ~= nil).to_be_true()
    expect(result.class_name).to_be("MainTest")
    expect(result.test_path).to_be(ROOT .. "/src/test/java/MainTest.java")
    expect(result.fqcn).to_be("MainTest")
  end)

  it("handles deeply nested packages", function()
    local result = map(ROOT .. "/src/main/java/com/corp/product/feature/Service.java", {})
    expect(result.fqcn).to_be("com.corp.product.feature.ServiceTest")
    expect(result.test_path).to_be(ROOT .. "/src/test/java/com/corp/product/feature/ServiceTest.java")
  end)
end)
