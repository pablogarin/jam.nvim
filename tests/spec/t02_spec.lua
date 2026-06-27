local function reset()
  package.loaded["jam.create"] = nil
  package.loaded["jam.ui"] = nil
  vim.schedule = function(fn)
    fn()
  end
end

describe("T-02 | Project name prompt", function()
  before_each(reset)

  it("create() calls jam.ui.input", function()
    local called = false
    package.loaded["jam.ui"] = {
      input = function(_, _)
        called = true
      end,
      select = function() end,
    }
    require("jam.create").create()
    expect(called).to_be_true()
  end)

  it("jam.ui.input is called with 'Project name: ' prompt", function()
    local captured_opts = nil
    package.loaded["jam.ui"] = {
      input = function(opts, _)
        captured_opts = opts
      end,
      select = function() end,
    }
    require("jam.create").create()
    expect(captured_opts).not_to_be_nil()
    expect(captured_opts.prompt).to_be("Project name: ")
  end)

  it("cancelling (nil input) does not trigger downstream notify", function()
    local notified = false
    package.loaded["jam.ui"] = {
      input = function(_, cb)
        cb(nil)
      end,
      select = function() end,
    }
    local orig = vim.notify
    vim.notify = function()
      notified = true
    end
    require("jam.create").create()
    vim.notify = orig
    expect(notified).to_be(false)
  end)

  it("a provided name is passed downstream", function()
    local captured_msg = nil
    local input_n, select_n = 0, 0
    package.loaded["jam.ui"] = {
      input = function(_, cb)
        input_n = input_n + 1
        cb(input_n == 1 and "MyProject" or "")
      end,
      select = function(_, _, cb)
        select_n = select_n + 1
        -- build_tool=Maven, inject_main=No, git_init=No
        cb(select_n == 1 and "Maven (default)" or "No")
      end,
    }
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
    }
    package.loaded["jam.detect"] = {
      find_java = function()
        return "/usr/bin/java"
      end,
      find_java_version = function()
        return 17
      end,
    }
    vim.api.nvim_set_current_dir = function() end
    vim.cmd.edit = function() end
    local orig = vim.notify
    vim.notify = function(msg, _)
      captured_msg = msg
    end
    require("jam.create").create()
    vim.notify = orig
    expect(captured_msg).not_to_be_nil()
    expect(captured_msg:find("MyProject", 1, true) ~= nil).to_be_true()
  end)
end)
