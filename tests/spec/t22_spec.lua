local function reset()
  package.loaded["jam.build"] = nil
end

local function resolve(root, files, found_java)
  local result = nil
  local read_fn = function(path)
    return files[path]
  end
  local find_fn = function(_)
    return found_java
  end
  require("jam.build")._resolve_main_class(root, function(fqcn)
    result = fqcn
  end, read_fn, find_fn)
  return result
end

describe("T-22 | Main class resolution", function()
  before_each(reset)

  it("returns mainClass from .jam.json when present", function()
    local files = {
      ["/proj/.jam.json"] = '{"mainClass":"com.example.App"}',
    }
    local fqcn = resolve("/proj", files, nil)
    expect(fqcn).to_be("com.example.App")
  end)

  it(".jam.json takes priority over Main.java scan", function()
    local files = {
      ["/proj/.jam.json"] = '{"mainClass":"com.override.Entry"}',
      ["/proj/src/main/java/org/example/Main.java"] = "package org.example;\npublic class Main {}",
    }
    local fqcn = resolve("/proj", files, "/proj/src/main/java/org/example/Main.java")
    expect(fqcn).to_be("com.override.Entry")
  end)

  it("returns FQCN from Main.java package declaration when no .jam.json", function()
    local files = {
      ["/proj/src/main/java/org/example/myapp/Main.java"] = "package org.example.myapp;\npublic class Main {}",
    }
    local fqcn = resolve("/proj", files, "/proj/src/main/java/org/example/myapp/Main.java")
    expect(fqcn).to_be("org.example.myapp.Main")
  end)

  it("falls back to vim.ui.input when neither source provides a class", function()
    local prompted = false
    vim.ui.input = function(_, cb)
      prompted = true
      cb("io.custom.Runner")
    end
    local fqcn = resolve("/proj", {}, nil)
    expect(prompted).to_be_true()
    expect(fqcn).to_be("io.custom.Runner")
  end)

  it("returns nil when prompt is cancelled (nil input)", function()
    vim.ui.input = function(_, cb)
      cb(nil)
    end
    local fqcn = resolve("/proj", {}, nil)
    expect(fqcn).to_be_nil()
  end)

  it("returns nil when prompt is submitted empty", function()
    vim.ui.input = function(_, cb)
      cb("")
    end
    local fqcn = resolve("/proj", {}, nil)
    expect(fqcn).to_be_nil()
  end)

  it("ignores malformed .jam.json and falls through to scan", function()
    local files = {
      ["/proj/.jam.json"] = "not valid json {{{",
      ["/proj/src/main/java/org/app/Main.java"] = "package org.app;\npublic class Main {}",
    }
    local fqcn = resolve("/proj", files, "/proj/src/main/java/org/app/Main.java")
    expect(fqcn).to_be("org.app.Main")
  end)
end)
