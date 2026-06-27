local function reset()
  package.loaded["jam.detect"] = nil
end

describe("T-06 | JDK detection", function()
  before_each(reset)

  local function resolve(java_home, stat_fn, exepath_fn)
    return require("jam.detect")._resolve_java(java_home, stat_fn, exepath_fn)
  end

  it("returns JAVA_HOME/bin/javac when it exists", function()
    local result = resolve("/usr/lib/jvm/java-21", function(p)
      return p == "/usr/lib/jvm/java-21/bin/javac"
    end, function(_)
      return ""
    end)
    expect(result).to_be("/usr/lib/jvm/java-21/bin/javac")
  end)

  it("falls back to exepath when JAVA_HOME binary is missing", function()
    local result = resolve("/usr/lib/jvm/java-21", function(_)
      return nil
    end, function(_)
      return "/usr/bin/javac"
    end)
    expect(result).to_be("/usr/bin/javac")
  end)

  it("uses exepath directly when JAVA_HOME is nil", function()
    local result = resolve(nil, function(_)
      return nil
    end, function(_)
      return "/usr/local/bin/javac"
    end)
    expect(result).to_be("/usr/local/bin/javac")
  end)

  it("returns nil when neither JAVA_HOME nor exepath finds javac", function()
    local result = resolve(nil, function(_)
      return nil
    end, function(_)
      return ""
    end)
    expect(result).to_be_nil()
  end)

  it("returns nil when JAVA_HOME binary missing and exepath empty", function()
    local result = resolve("/nonexistent", function(_)
      return nil
    end, function(_)
      return ""
    end)
    expect(result).to_be_nil()
  end)

  it("find_java() caches result on second call", function()
    local detect = require("jam.detect")
    local call_count = 0
    -- override _resolve_java to count invocations
    local orig = detect._resolve_java
    detect._resolve_java = function(...)
      call_count = call_count + 1
      return orig(...)
    end
    detect.find_java()
    detect.find_java()
    detect._resolve_java = orig
    expect(call_count).to_be(1)
  end)

  it("_reset() clears the cache so find_java() re-resolves", function()
    local detect = require("jam.detect")
    local call_count = 0
    local orig = detect._resolve_java
    detect._resolve_java = function(...)
      call_count = call_count + 1
      return orig(...)
    end
    detect.find_java()
    detect._reset()
    detect.find_java()
    detect._resolve_java = orig
    expect(call_count).to_be(2)
  end)
end)
