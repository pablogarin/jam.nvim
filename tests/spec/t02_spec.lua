local function reset()
  package.loaded["jam.create"] = nil
end

describe("T-02 | Project name prompt", function()
  before_each(reset)

  it("create() calls vim.ui.input", function()
    local called = false
    vim.ui.input = function(_, _)
      called = true
    end
    require("jam.create").create()
    expect(called).to_be_true()
  end)

  it("vim.ui.input is called with 'Project name: ' prompt", function()
    local captured_opts = nil
    vim.ui.input = function(opts, _)
      captured_opts = opts
    end
    require("jam.create").create()
    expect(captured_opts).not_to_be_nil()
    expect(captured_opts.prompt).to_be("Project name: ")
  end)

  it("cancelling (nil input) does not trigger downstream notify", function()
    local notified = false
    vim.ui.input = function(_, cb)
      cb(nil)
    end
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
    vim.ui.input = function(_, cb)
      cb("MyProject")
    end
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
