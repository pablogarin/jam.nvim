local function reset()
  package.loaded["jam"] = nil
  package.loaded["jam.create"] = nil
  pcall(vim.api.nvim_del_user_command, "Jam")
end

describe("T-01 | :Jam command registration", function()
  before_each(reset)

  it("setup() registers the :Jam user command", function()
    require("jam").setup()
    local cmds = vim.api.nvim_get_commands({})
    expect(cmds["Jam"]).not_to_be_nil()
  end)

  it(":Jam is registered with nargs='+'", function()
    require("jam").setup()
    local cmds = vim.api.nvim_get_commands({})
    expect(cmds["Jam"].nargs).to_be("+")
  end)

  it(":Jam create delegates to jam.create.create()", function()
    local called = false
    package.loaded["jam.create"] = {
      create = function()
        called = true
      end,
    }
    require("jam").setup()
    vim.cmd("Jam create")
    expect(called).to_be_true()
  end)

  it(":Jam <unknown> emits vim.notify at ERROR level", function()
    local captured_level = nil
    local orig = vim.notify
    vim.notify = function(_, level)
      captured_level = level
    end
    require("jam").setup()
    vim.cmd("Jam nonexistent")
    vim.notify = orig
    expect(captured_level).to_be(vim.log.levels.ERROR)
  end)

  it("_complete('') returns all subcommands", function()
    local results = require("jam")._complete("")
    expect(results).to_contain("create")
  end)

  it("_complete('cr') includes 'create'", function()
    local results = require("jam")._complete("cr")
    expect(results).to_contain("create")
  end)

  it("_complete('xyz') returns empty list", function()
    local results = require("jam")._complete("xyz")
    expect(#results).to_be(0)
  end)
end)
