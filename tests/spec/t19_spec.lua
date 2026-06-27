local function reset()
  package.loaded["jam.project"] = nil
end

-- Build a stat_fn that returns truthy only for paths in the provided set.
local function make_stat(existing)
  return function(path)
    return existing[path] or nil
  end
end

describe("T-19 | Project root and build tool detection", function()
  before_each(reset)

  local function find(start, existing)
    return require("jam.project")._find_root(start, make_stat(existing))
  end

  it("returns maven when pom.xml is found in the start directory", function()
    local result = find("/home/user/myapp", { ["/home/user/myapp/pom.xml"] = true })
    expect(result ~= nil).to_be_true()
    expect(result.root).to_be("/home/user/myapp")
    expect(result.tool).to_be("maven")
  end)

  it("returns gradle when build.gradle is found in the start directory", function()
    local result = find("/home/user/myapp", { ["/home/user/myapp/build.gradle"] = true })
    expect(result ~= nil).to_be_true()
    expect(result.root).to_be("/home/user/myapp")
    expect(result.tool).to_be("gradle")
  end)

  it("returns none when only .git is found", function()
    local result = find("/home/user/myapp", { ["/home/user/myapp/.git"] = true })
    expect(result ~= nil).to_be_true()
    expect(result.root).to_be("/home/user/myapp")
    expect(result.tool).to_be("none")
  end)

  it("returns nil when no marker is found anywhere", function()
    local result = find("/home/user/myapp", {})
    expect(result).to_be_nil()
  end)

  it("walks up to a parent directory to find the marker", function()
    local result = find("/home/user/myapp/src/main/java", {
      ["/home/user/myapp/pom.xml"] = true,
    })
    expect(result ~= nil).to_be_true()
    expect(result.root).to_be("/home/user/myapp")
    expect(result.tool).to_be("maven")
  end)

  it("pom.xml takes priority over build.gradle in the same directory", function()
    local result = find("/home/user/myapp", {
      ["/home/user/myapp/pom.xml"] = true,
      ["/home/user/myapp/build.gradle"] = true,
    })
    expect(result.tool).to_be("maven")
  end)

  it("build.gradle takes priority over .git in the same directory", function()
    local result = find("/home/user/myapp", {
      ["/home/user/myapp/build.gradle"] = true,
      ["/home/user/myapp/.git"] = true,
    })
    expect(result.tool).to_be("gradle")
  end)

  it("stops at the closest ancestor, not the farthest", function()
    local result = find("/home/user/myapp/sub", {
      ["/home/user/myapp/sub/build.gradle"] = true,
      ["/home/user/myapp/pom.xml"] = true,
    })
    expect(result.root).to_be("/home/user/myapp/sub")
    expect(result.tool).to_be("gradle")
  end)
end)
