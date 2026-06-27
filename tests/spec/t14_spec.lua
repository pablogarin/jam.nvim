-- Prompt order: input[1]=name, input[2]=location, select[1]=build tool,
--               select[2]=inject_main, select[3]=git_init, input[3]=package

---@param inputs string[] Ordered return values for vim.ui.input calls.
---@param selects string[] Ordered return values for vim.ui.select calls.
local function wizard_stub(inputs, selects)
  local input_n, select_n = 0, 0
  vim.ui.input = function(_, cb)
    input_n = input_n + 1
    cb(inputs[input_n])
  end
  vim.ui.select = function(_, _, cb)
    select_n = select_n + 1
    cb(selects[select_n])
  end
end

local function fs_stub(captured)
  package.loaded["jam.fs"] = {
    ensure_project_dir = function()
      return true
    end,
    scaffold_maven = function(_, pkg_path)
      captured.pkg_path = pkg_path
      return true
    end,
    write_file = function(path, _)
      if path:find("pom.xml", 1, true) then
        captured.pom_path = path
      end
      if path:find("Main.java", 1, true) then
        captured.main_path = path
      end
      if path:find(".gitignore", 1, true) then
        captured.gitignore_path = path
      end
      return true
    end,
    git_init = function(_, cb)
      cb(true)
    end,
  }
end

local function detect_stub()
  package.loaded["jam.detect"] = {
    find_java = function()
      return nil
    end,
    find_java_version = function()
      return 17
    end,
  }
end

local function reset()
  package.loaded["jam.create"] = nil
  package.loaded["jam.fs"] = nil
  package.loaded["jam.detect"] = nil
  vim.api.nvim_set_current_dir = function() end
  vim.cmd.edit = function() end
end

describe("T-14 | Custom location and package name overrides", function()
  before_each(reset)

  it("empty location input uses the default (cwd/name)", function()
    local captured = {}
    wizard_stub(
      { "myapp", "", "myapp" }, -- name, empty location (=default), empty package (=default)
      { "Maven (default)", "No", "No" }
    )
    fs_stub(captured)
    detect_stub()
    require("jam.create").create()
    local expected = vim.uv.cwd() .. "/myapp"
    expect(captured.pom_path).to_be(expected .. "/pom.xml")
  end)

  it("non-empty location input overrides the project root", function()
    local captured = {}
    wizard_stub(
      { "myapp", "/tmp/custom_loc", "" }, -- custom location
      { "Maven (default)", "No", "No" }
    )
    fs_stub(captured)
    detect_stub()
    require("jam.create").create()
    expect(captured.pom_path).to_be("/tmp/custom_loc/pom.xml")
  end)

  it("empty package input uses the inferred default", function()
    local captured = {}
    wizard_stub(
      { "myapp", "", "" }, -- empty package = use default
      { "Maven (default)", "Yes", "No" }
    )
    fs_stub(captured)
    detect_stub()
    require("jam.create").create()
    -- infer_package("myapp") = "org.example.myapp" → path "org/example/myapp"
    expect(captured.pkg_path).to_be("org/example/myapp")
  end)

  it("non-empty package input overrides the package name", function()
    local captured = {}
    wizard_stub(
      { "myapp", "", "com.acme.demo" }, -- custom package
      { "Maven (default)", "Yes", "No" }
    )
    fs_stub(captured)
    detect_stub()
    require("jam.create").create()
    expect(captured.pkg_path).to_be("com/acme/demo")
  end)

  it("custom package is reflected in Main.java path", function()
    local captured = {}
    wizard_stub({ "myapp", "", "io.example.custom" }, { "Maven (default)", "Yes", "No" })
    fs_stub(captured)
    detect_stub()
    require("jam.create").create()
    expect(captured.main_path:find("io/example/custom/Main.java", 1, true) ~= nil).to_be_true()
  end)

  it("cancelling location prompt aborts the wizard", function()
    local finished = false
    wizard_stub(
      { "myapp", nil }, -- nil = Esc on location prompt
      {}
    )
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return true
      end,
    }
    detect_stub()
    local orig = vim.notify
    vim.notify = function(_, level)
      if level == vim.log.levels.INFO then
        finished = true
      end
    end
    require("jam.create").create()
    vim.notify = orig
    expect(finished).to_be(false)
  end)

  it("cancelling package prompt aborts the wizard", function()
    local finished = false
    wizard_stub(
      { "myapp", "", nil }, -- nil = Esc on package prompt
      { "Maven (default)", "No", "No" }
    )
    local captured = {}
    fs_stub(captured)
    detect_stub()
    local orig = vim.notify
    vim.notify = function(_, level)
      if level == vim.log.levels.INFO then
        finished = true
      end
    end
    require("jam.create").create()
    vim.notify = orig
    expect(finished).to_be(false)
  end)
end)
