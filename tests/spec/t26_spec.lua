local function reset()
  package.loaded["jam.test"] = nil
  package.loaded["jam.fs"] = nil
  vim.cmd.edit = function() end
  vim.api.nvim_win_set_cursor = function() end
  vim.api.nvim_buf_get_lines = function(_, _, _, _)
    return {
      "package org.example;",
      "",
      "import org.junit.jupiter.api.Test;",
      "import static org.junit.jupiter.api.Assertions.*;",
      "",
      "class FooTest {",
      "",
      "    @Test",
      "    void exampleTest() {",
      "        // TODO: write test",
      "    }",
      "}",
    }
  end
end

describe("T-26 | _test_template content", function()
  before_each(reset)

  it("includes the correct package declaration", function()
    local t = require("jam.test")._test_template("org.example.app", "FooTest")
    expect(t:find("package org.example.app;", 1, true) ~= nil).to_be_true()
  end)

  it("includes JUnit 5 Test import", function()
    local t = require("jam.test")._test_template("org.example.app", "FooTest")
    expect(t:find("import org.junit.jupiter.api.Test;", 1, true) ~= nil).to_be_true()
  end)

  it("includes Assertions import", function()
    local t = require("jam.test")._test_template("org.example.app", "FooTest")
    expect(t:find("import static org.junit.jupiter.api.Assertions.*;", 1, true) ~= nil).to_be_true()
  end)

  it("uses the correct class name", function()
    local t = require("jam.test")._test_template("org.example.app", "FooTest")
    expect(t:find("class FooTest", 1, true) ~= nil).to_be_true()
  end)

  it("includes the TODO placeholder", function()
    local t = require("jam.test")._test_template("org.example.app", "FooTest")
    expect(t:find("// TODO: write test", 1, true) ~= nil).to_be_true()
  end)

  it("omits the package line when pkg is empty", function()
    local t = require("jam.test")._test_template("", "MainTest")
    expect(t:find("^package", 1, true)).to_be_nil()
  end)
end)

describe("T-26 | generate_test — file creation", function()
  before_each(reset)

  it("writes the file with the correct content", function()
    local written_path, written_content = nil, nil
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return true
      end,
      write_file = function(path, content)
        written_path = path
        written_content = content
        return true
      end,
    }
    require("jam.test").generate_test("/proj/src/test/java/org/example/FooTest.java", "org.example", "FooTest")
    expect(written_path).to_be("/proj/src/test/java/org/example/FooTest.java")
    expect(written_content:find("class FooTest", 1, true) ~= nil).to_be_true()
  end)

  it("emits INFO notification on success", function()
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return true
      end,
      write_file = function()
        return true
      end,
    }
    local got_level = nil
    local orig = vim.notify
    vim.notify = function(_, level)
      got_level = level
    end
    require("jam.test").generate_test("/proj/src/test/java/org/example/FooTest.java", "org.example", "FooTest")
    vim.notify = orig
    expect(got_level).to_be(vim.log.levels.INFO)
  end)

  it("positions cursor on the TODO line via cursor_fn", function()
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return true
      end,
      write_file = function()
        return true
      end,
    }
    local cursor_line = nil
    require("jam.test").generate_test(
      "/proj/src/test/java/org/example/FooTest.java",
      "org.example",
      "FooTest",
      function(line)
        cursor_line = line
      end
    )
    expect(cursor_line ~= nil).to_be_true()
    -- TODO line is line 10 in the mocked buffer content
    expect(cursor_line).to_be(10)
  end)

  it("emits ERROR when directory creation fails", function()
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return nil, "permission denied"
      end,
      write_file = function()
        return true
      end,
    }
    local got_level = nil
    local orig = vim.notify
    vim.notify = function(_, level)
      got_level = level
    end
    require("jam.test").generate_test("/proj/src/test/java/org/example/FooTest.java", "org.example", "FooTest")
    vim.notify = orig
    expect(got_level).to_be(vim.log.levels.ERROR)
  end)
end)
