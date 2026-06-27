-- Helper: stub all three vim.ui.select calls in sequence.
-- `choices` is a list indexed by call order.
local function stub_selects(choices)
  local call = 0
  vim.ui.select = function(_, _, cb)
    call = call + 1
    cb(choices[call])
  end
end

local function full_stub(select_choices)
  vim.ui.input = function(_, cb)
    cb("myapp")
  end
  stub_selects(select_choices)
  package.loaded["jam.fs"] = {
    ensure_project_dir = function()
      return true
    end,
    scaffold_maven = function()
      return true
    end,
    write_file = function()
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
end

local function reset()
  package.loaded["jam.create"] = nil
  package.loaded["jam.fs"] = nil
  package.loaded["jam.detect"] = nil
  vim.api.nvim_set_current_dir = function() end
  vim.cmd.edit = function() end
end

-- select order: 1=build tool, 2=inject Main.java, 3=git init
describe("T-13 | VCS and entry point toggles", function()
  before_each(reset)

  it("skips Main.java when 'No' is selected for inject toggle", function()
    local wrote_main = false
    full_stub({ "Maven (default)", "No", "Yes" })
    package.loaded["jam.fs"].write_file = function(path, _)
      if path:find("Main.java", 1, true) then
        wrote_main = true
      end
      return true
    end
    require("jam.create").create()
    expect(wrote_main).to_be(false)
  end)

  it("writes Main.java when 'Yes' is selected for inject toggle", function()
    local wrote_main = false
    full_stub({ "Maven (default)", "Yes", "No" })
    package.loaded["jam.fs"].write_file = function(path, _)
      if path:find("Main.java", 1, true) then
        wrote_main = true
      end
      return true
    end
    require("jam.create").create()
    expect(wrote_main).to_be_true()
  end)

  it("skips git init when 'No' is selected for VCS toggle", function()
    local git_called = false
    full_stub({ "Maven (default)", "Yes", "No" })
    package.loaded["jam.fs"].git_init = function(_, cb)
      git_called = true
      cb(true)
    end
    require("jam.create").create()
    expect(git_called).to_be(false)
  end)

  it("calls git init when 'Yes' is selected for VCS toggle", function()
    local git_called = false
    full_stub({ "Maven (default)", "Yes", "Yes" })
    package.loaded["jam.fs"].git_init = function(_, cb)
      git_called = true
      cb(true)
    end
    require("jam.create").create()
    expect(git_called).to_be_true()
  end)

  it("skips .gitignore when VCS toggle is 'No'", function()
    local wrote_gitignore = false
    full_stub({ "Maven (default)", "No", "No" })
    package.loaded["jam.fs"].write_file = function(path, _)
      if path:find(".gitignore", 1, true) then
        wrote_gitignore = true
      end
      return true
    end
    require("jam.create").create()
    expect(wrote_gitignore).to_be(false)
  end)

  it("cancelling inject_main prompt stops the wizard", function()
    local finished = false
    full_stub({ "Maven (default)", nil, "Yes" }) -- nil = cancel on inject prompt
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

  it("cancelling git_init prompt stops the wizard", function()
    local finished = false
    full_stub({ "Maven (default)", "Yes", nil }) -- nil = cancel on git prompt
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
