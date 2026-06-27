local function reset()
  package.loaded["jam.create"] = nil
  package.loaded["jam.detect"] = nil
end

describe("T-09 | pom.xml generation", function()
  before_each(reset)

  local function pom(artifact, pkg, version)
    return require("jam.create")._pom_xml(artifact, pkg, version)
  end

  it("contains the correct groupId", function()
    local xml = pom("myproject", "org.example.myproject", 17)
    expect(xml:find("<groupId>org.example</groupId>", 1, true) ~= nil).to_be_true()
  end)

  it("contains the correct artifactId", function()
    local xml = pom("myproject", "org.example.myproject", 17)
    expect(xml:find("<artifactId>myproject</artifactId>", 1, true) ~= nil).to_be_true()
  end)

  it("contains version 1.0-SNAPSHOT", function()
    local xml = pom("myproject", "org.example.myproject", 17)
    expect(xml:find("<version>1.0-SNAPSHOT</version>", 1, true) ~= nil).to_be_true()
  end)

  it("sets maven.compiler.source to the detected JDK version", function()
    local xml = pom("myproject", "org.example.myproject", 21)
    expect(xml:find("<maven.compiler.source>21</maven.compiler.source>", 1, true) ~= nil).to_be_true()
  end)

  it("sets maven.compiler.target to the detected JDK version", function()
    local xml = pom("myproject", "org.example.myproject", 21)
    expect(xml:find("<maven.compiler.target>21</maven.compiler.target>", 1, true) ~= nil).to_be_true()
  end)

  it("includes UTF-8 source encoding property", function()
    local xml = pom("myproject", "org.example.myproject", 17)
    expect(xml:find("UTF-8", 1, true) ~= nil).to_be_true()
  end)

  it("uses only the root segments of the package as groupId", function()
    local xml = pom("demo", "com.acme.demo", 11)
    expect(xml:find("<groupId>com.acme</groupId>", 1, true) ~= nil).to_be_true()
  end)
end)

describe("T-09 | JDK version detection (detect.find_java_version)", function()
  before_each(reset)

  local function version_from_path(path)
    -- temporarily override find_java to return a custom path
    local detect = require("jam.detect")
    local orig = detect.find_java
    detect.find_java = function()
      return path
    end
    local v = detect.find_java_version()
    detect.find_java = orig
    return v
  end

  it("extracts version from 'java-21' in path", function()
    expect(version_from_path("/usr/lib/jvm/java-21/bin/javac")).to_be(21)
  end)

  it("extracts version from 'jdk-17' in path", function()
    expect(version_from_path("/opt/jdk-17.0.1/bin/javac")).to_be(17)
  end)

  it("extracts version from 'jdk11' in path", function()
    expect(version_from_path("/usr/local/jdk11/bin/javac")).to_be(11)
  end)

  it("falls back to 17 when no version found in path", function()
    expect(version_from_path("/usr/bin/javac")).to_be(17)
  end)

  it("falls back to 17 when path is nil (no JDK found)", function()
    expect(version_from_path(nil)).to_be(17)
  end)
end)
