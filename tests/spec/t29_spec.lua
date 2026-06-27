local function reset()
  package.loaded["jam.lsp"] = nil
  package.loaded["jdtls"] = nil
  package.preload["jdtls"] = function()
    error("jdtls not installed (test stub)")
  end
  vim.lsp = vim.lsp or {}
  vim.lsp.buf = vim.lsp.buf or {}
  vim.lsp.buf.code_action = function() end
end

local function stub_code_action(recorded)
  vim.lsp.buf.code_action = function(opts)
    recorded.called = true
    recorded.opts = opts
  end
end

describe("T-29 | organize_imports — filetype guard", function()
  before_each(reset)

  it("emits ERROR when filetype is not java", function()
    local got_level = nil
    local orig = vim.notify
    vim.notify = function(_, level)
      got_level = level
    end
    require("jam.lsp").organize_imports(
      function(_)
        return { { name = "jdtls" } }
      end,
      function()
        return "lua"
      end
    )
    vim.notify = orig
    expect(got_level).to_be(vim.log.levels.ERROR)
  end)

  it("error message says 'not a Java file'", function()
    local got_msg = nil
    local orig = vim.notify
    vim.notify = function(msg, _)
      got_msg = msg
    end
    require("jam.lsp").organize_imports(
      function(_)
        return { { name = "jdtls" } }
      end,
      function()
        return "kotlin"
      end
    )
    vim.notify = orig
    expect(got_msg:find("not a Java file", 1, true) ~= nil).to_be_true()
  end)
end)

describe("T-29 | organize_imports — jdtls client guard", function()
  before_each(reset)

  it("emits ERROR when no jdtls client is attached", function()
    local got_level = nil
    local orig = vim.notify
    vim.notify = function(_, level)
      got_level = level
    end
    require("jam.lsp").organize_imports(
      function(_)
        return {}
      end,
      function()
        return "java"
      end
    )
    vim.notify = orig
    expect(got_level).to_be(vim.log.levels.ERROR)
  end)

  it("error message mentions jdtls not attached and install hint", function()
    local got_msg = nil
    local orig = vim.notify
    vim.notify = function(msg, _)
      got_msg = msg
    end
    require("jam.lsp").organize_imports(
      function(_)
        return {}
      end,
      function()
        return "java"
      end
    )
    vim.notify = orig
    expect(got_msg:find("jdtls not attached", 1, true) ~= nil).to_be_true()
    expect(got_msg:find("nvim-jdtls", 1, true) ~= nil).to_be_true()
  end)
end)

describe("T-29 | organize_imports — code action dispatch", function()
  before_each(reset)

  it("calls vim.lsp.buf.code_action when filetype is java and jdtls is attached", function()
    local recorded = {}
    stub_code_action(recorded)
    require("jam.lsp").organize_imports(
      function(_)
        return { { name = "jdtls" } }
      end,
      function()
        return "java"
      end
    )
    expect(recorded.called).to_be_true()
  end)

  it("code_action is called with source.organizeImports in the only list", function()
    local recorded = {}
    stub_code_action(recorded)
    require("jam.lsp").organize_imports(
      function(_)
        return { { name = "jdtls" } }
      end,
      function()
        return "java"
      end
    )
    local only = recorded.opts and recorded.opts.context and recorded.opts.context.only
    expect(only ~= nil).to_be_true()
    local found = false
    for _, v in ipairs(only) do
      if v == "source.organizeImports" then
        found = true
      end
    end
    expect(found).to_be_true()
  end)
end)
