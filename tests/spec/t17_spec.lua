-- T-17: After a successful project creation, cd into the root and open Main.java.

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

local function fs_stub()
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
  package.loaded["jam.ui"] = nil
  package.loaded["jam.fs"] = nil
  package.loaded["jam.detect"] = nil
  vim.api.nvim_set_current_dir = function() end
  vim.cmd.edit = function() end
  vim.schedule = function(fn)
    fn()
  end
end

describe("T-17 | Post-creation: cd and open Main.java", function()
  before_each(reset)

  it("calls nvim_set_current_dir with cwd/name by default", function()
    local cwd_called_with = nil
    vim.api.nvim_set_current_dir = function(path)
      cwd_called_with = path
    end
    wizard_stub({ "myapp", "", "" }, { "Maven (default)", "No", "No" })
    fs_stub()
    detect_stub()
    require("jam.create").create()
    expect(cwd_called_with).to_be(vim.uv.cwd() .. "/myapp")
  end)

  it("calls nvim_set_current_dir with the custom location when overridden", function()
    local cwd_called_with = nil
    vim.api.nvim_set_current_dir = function(path)
      cwd_called_with = path
    end
    wizard_stub({ "myapp", "/tmp/custom_t17", "" }, { "Maven (default)", "No", "No" })
    fs_stub()
    detect_stub()
    require("jam.create").create()
    expect(cwd_called_with).to_be("/tmp/custom_t17")
  end)

  it("emits an INFO notification containing the project name on success", function()
    local got_msg, got_level = nil, nil
    local orig = vim.notify
    vim.notify = function(msg, level)
      if level == vim.log.levels.INFO then
        got_msg, got_level = msg, level
      end
    end
    wizard_stub({ "myapp", "", "" }, { "Maven (default)", "No", "No" })
    fs_stub()
    detect_stub()
    require("jam.create").create()
    vim.notify = orig
    expect(got_level).to_be(vim.log.levels.INFO)
    expect(got_msg:find("myapp", 1, true) ~= nil).to_be_true()
  end)

  it("calls vim.cmd.edit with the Main.java path when inject_main is Yes", function()
    local edit_path = nil
    vim.cmd.edit = function(path)
      edit_path = path
    end
    wizard_stub({ "myapp", "", "" }, { "Maven (default)", "Yes", "No" })
    fs_stub()
    detect_stub()
    require("jam.create").create()
    expect(edit_path ~= nil).to_be_true()
    expect(edit_path:find("Main.java", 1, true) ~= nil).to_be_true()
    expect(edit_path:find("org/example/myapp", 1, true) ~= nil).to_be_true()
  end)

  it("does not call vim.cmd.edit when inject_main is No", function()
    local edit_called = false
    vim.cmd.edit = function(_)
      edit_called = true
    end
    wizard_stub({ "myapp", "", "" }, { "Maven (default)", "No", "No" })
    fs_stub()
    detect_stub()
    require("jam.create").create()
    expect(edit_called).to_be(false)
  end)

  it("cds into the root even when git init runs (async callback path)", function()
    local cwd_called_with = nil
    vim.api.nvim_set_current_dir = function(path)
      cwd_called_with = path
    end
    wizard_stub({ "myapp", "", "" }, { "Maven (default)", "No", "Yes" })
    fs_stub()
    detect_stub()
    require("jam.create").create()
    expect(cwd_called_with).to_be(vim.uv.cwd() .. "/myapp")
  end)
end)
