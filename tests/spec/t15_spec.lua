local function reset()
  package.loaded["jam.create"] = nil
  package.loaded["jam.ui"] = nil
  package.loaded["jam.fs"] = nil
  package.loaded["jam.detect"] = nil
  vim.api.nvim_set_current_dir = function() end
  vim.cmd.edit = function() end
  vim.schedule = function(fn)
    fn()
  end
end

-- Prompt order: input[1]=name, input[2]=location, select[1]=build tool,
--               select[2]=inject_main, select[3]=git_init, input[3]=package
local function wizard_stub(inputs, selects)
  local input_n, select_n = 0, 0
  package.loaded["jam.ui"] = {
    input = function(_, cb)
      input_n = input_n + 1
      cb(inputs[input_n])
    end,
    select = function(_, _, cb)
      select_n = select_n + 1
      cb(selects[select_n])
    end,
  }
end

describe("T-15 | Gradle build file generation (content)", function()
  before_each(reset)

  local function bg(pkg, version)
    return require("jam.create")._build_gradle(pkg, version)
  end

  local function sg(artifact)
    return require("jam.create")._settings_gradle(artifact)
  end

  it("build.gradle applies the java plugin", function()
    expect(bg("org.example.app", 17):find("id 'java'", 1, true) ~= nil).to_be_true()
  end)

  it("build.gradle sets the group from the package root", function()
    expect(bg("org.example.myapp", 21):find("group = 'org.example'", 1, true) ~= nil).to_be_true()
  end)

  it("build.gradle sets version to 1.0-SNAPSHOT", function()
    expect(bg("org.example.app", 17):find("version = '1.0-SNAPSHOT'", 1, true) ~= nil).to_be_true()
  end)

  it("build.gradle sets sourceCompatibility to JDK version", function()
    expect(bg("org.example.app", 21):find("VERSION_21", 1, true) ~= nil).to_be_true()
  end)

  it("build.gradle includes mavenCentral repository", function()
    expect(bg("org.example.app", 17):find("mavenCentral()", 1, true) ~= nil).to_be_true()
  end)

  it("settings.gradle sets the root project name", function()
    expect(sg("myapp"):find("rootProject.name = 'myapp'", 1, true) ~= nil).to_be_true()
  end)

  it("settings.gradle uses the artifact id, not the package", function()
    expect(sg("cool-project"):find("cool-project", 1, true) ~= nil).to_be_true()
  end)
end)

describe("T-15 | Gradle scaffolding integration", function()
  before_each(reset)

  it("Gradle selection writes build.gradle and settings.gradle, not pom.xml", function()
    local written = {}
    wizard_stub({ "myapp", "", "" }, { "Gradle", "No", "No" })
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return true
      end,
      scaffold_maven = function()
        return true
      end,
      write_file = function(path, _)
        table.insert(written, path)
        return true
      end,
      git_init = function(_, cb)
        cb(true)
      end,
    }
    package.loaded["jam.detect"] = {
      find_java = function()
        return nil
      end,
      find_java_version = function()
        return 17
      end,
    }
    require("jam.create").create()

    local has_build_gradle, has_settings_gradle, has_pom = false, false, false
    for _, p in ipairs(written) do
      if p:find("build.gradle", 1, true) then
        has_build_gradle = true
      end
      if p:find("settings.gradle", 1, true) then
        has_settings_gradle = true
      end
      if p:find("pom.xml", 1, true) then
        has_pom = true
      end
    end
    expect(has_build_gradle).to_be_true()
    expect(has_settings_gradle).to_be_true()
    expect(has_pom).to_be(false)
  end)

  it("'No Build Tools' writes neither pom.xml nor build.gradle", function()
    local written = {}
    wizard_stub({ "myapp", "", "" }, { "No Build Tools", "No", "No" })
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return true
      end,
      scaffold_maven = function()
        return true
      end,
      write_file = function(path, _)
        table.insert(written, path)
        return true
      end,
      git_init = function(_, cb)
        cb(true)
      end,
    }
    package.loaded["jam.detect"] = {
      find_java = function()
        return nil
      end,
      find_java_version = function()
        return 17
      end,
    }
    require("jam.create").create()

    for _, p in ipairs(written) do
      expect(p:find("pom.xml", 1, true) == nil).to_be_true()
      expect(p:find("build.gradle", 1, true) == nil).to_be_true()
    end
  end)
end)
