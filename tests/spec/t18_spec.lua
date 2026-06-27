-- T-18: All user-facing messages must use vim.notify() at the correct log level.
--   INFO  — project created successfully
--   WARN  — non-fatal issues (missing JDK, git init failure, .gitignore write failure)
--   ERROR — validation failures that abort the wizard

local function reset()
  package.loaded["jam.create"] = nil
  package.loaded["jam.fs"] = nil
  package.loaded["jam.detect"] = nil
  vim.api.nvim_set_current_dir = function() end
  vim.cmd.edit = function() end
end

-- Collect every (message, level) pair emitted during a test.
local function capture_notifications(fn)
  local captured = {}
  local orig = vim.notify
  vim.notify = function(msg, level)
    table.insert(captured, { msg = msg, level = level })
  end
  fn()
  vim.notify = orig
  return captured
end

local function fs_ok()
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

local function detect_missing_jdk()
  package.loaded["jam.detect"] = {
    find_java = function()
      return nil
    end,
    find_java_version = function()
      return 17
    end,
  }
end

local function detect_jdk_present()
  package.loaded["jam.detect"] = {
    find_java = function()
      return "/usr/bin/javac"
    end,
    find_java_version = function()
      return 21
    end,
  }
end

-- Prompt order: input[1]=name, input[2]=location, select[1]=build tool,
--               select[2]=inject_main, select[3]=git_init, input[3]=package
local function stub(inputs, selects)
  local in_n, sel_n = 0, 0
  vim.ui.input = function(_, cb)
    in_n = in_n + 1
    cb(inputs[in_n])
  end
  vim.ui.select = function(_, _, cb)
    sel_n = sel_n + 1
    cb(selects[sel_n])
  end
end

describe("T-18 | vim.notify() log levels", function()
  before_each(reset)

  it("uses ERROR level when project name is empty", function()
    stub({ "", "" }, {})
    fs_ok()
    detect_missing_jdk()
    local msgs = capture_notifications(function()
      require("jam.create").create()
    end)
    local has_error = false
    for _, n in ipairs(msgs) do
      if n.level == vim.log.levels.ERROR then
        has_error = true
      end
    end
    expect(has_error).to_be_true()
  end)

  it("uses ERROR level when project name contains illegal characters", function()
    stub({ "bad name!", "" }, {})
    fs_ok()
    detect_missing_jdk()
    local msgs = capture_notifications(function()
      require("jam.create").create()
    end)
    local has_error = false
    for _, n in ipairs(msgs) do
      if n.level == vim.log.levels.ERROR then
        has_error = true
      end
    end
    expect(has_error).to_be_true()
  end)

  it("uses ERROR level when ensure_project_dir fails", function()
    stub({ "myapp", "" }, { "Maven (default)", "No", "No" })
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return nil, "permission denied"
      end,
    }
    detect_missing_jdk()
    local msgs = capture_notifications(function()
      require("jam.create").create()
    end)
    local has_error = false
    for _, n in ipairs(msgs) do
      if n.level == vim.log.levels.ERROR then
        has_error = true
      end
    end
    expect(has_error).to_be_true()
  end)

  it("uses WARN level when JDK is not found", function()
    stub({ "myapp", "", "" }, { "Maven (default)", "No", "No" })
    fs_ok()
    detect_missing_jdk()
    local msgs = capture_notifications(function()
      require("jam.create").create()
    end)
    local has_warn = false
    for _, n in ipairs(msgs) do
      if n.level == vim.log.levels.WARN and n.msg:find("JDK", 1, true) then
        has_warn = true
      end
    end
    expect(has_warn).to_be_true()
  end)

  it("does not emit a JDK warning when JDK is present", function()
    stub({ "myapp", "", "" }, { "Maven (default)", "No", "No" })
    fs_ok()
    detect_jdk_present()
    local msgs = capture_notifications(function()
      require("jam.create").create()
    end)
    local has_jdk_warn = false
    for _, n in ipairs(msgs) do
      if n.level == vim.log.levels.WARN and n.msg:find("JDK", 1, true) then
        has_jdk_warn = true
      end
    end
    expect(has_jdk_warn).to_be(false)
  end)

  it("uses INFO level for the success notification", function()
    stub({ "myapp", "", "" }, { "Maven (default)", "No", "No" })
    fs_ok()
    detect_jdk_present()
    local msgs = capture_notifications(function()
      require("jam.create").create()
    end)
    local has_info = false
    for _, n in ipairs(msgs) do
      if n.level == vim.log.levels.INFO then
        has_info = true
      end
    end
    expect(has_info).to_be_true()
  end)

  it("uses WARN level when git_init reports failure", function()
    stub({ "myapp", "", "" }, { "Maven (default)", "No", "Yes" })
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
        cb(false) -- git init failed
      end,
    }
    detect_jdk_present()
    local msgs = capture_notifications(function()
      require("jam.create").create()
    end)
    local has_git_warn = false
    for _, n in ipairs(msgs) do
      if n.level == vim.log.levels.WARN and n.msg:find("git", 1, true) then
        has_git_warn = true
      end
    end
    expect(has_git_warn).to_be_true()
  end)

  it("uses WARN level when .gitignore write fails", function()
    stub({ "myapp", "", "" }, { "Maven (default)", "No", "Yes" })
    package.loaded["jam.fs"] = {
      ensure_project_dir = function()
        return true
      end,
      scaffold_maven = function()
        return true
      end,
      write_file = function(path, _)
        if path:find(".gitignore", 1, true) then
          return nil, "disk full"
        end
        return true
      end,
      git_init = function(_, cb)
        cb(true)
      end,
    }
    detect_jdk_present()
    local msgs = capture_notifications(function()
      require("jam.create").create()
    end)
    local has_gitignore_warn = false
    for _, n in ipairs(msgs) do
      if n.level == vim.log.levels.WARN and n.msg:find("gitignore", 1, true) then
        has_gitignore_warn = true
      end
    end
    expect(has_gitignore_warn).to_be_true()
  end)
end)
