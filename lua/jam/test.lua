local M = {}

---Map a source file path to its test counterpart.
---@param buf_path string Absolute path to the source file.
---@param root string Project root (where pom.xml / build.gradle lives).
---@param stat_fn? fun(path: string): any|nil Injected for tests; defaults to vim.uv.fs_stat.
---@return {test_path: string, class_name: string, fqcn: string, exists: boolean}|nil result
---@return string|nil err
function M._map_to_test(buf_path, root, stat_fn)
  stat_fn = stat_fn or vim.uv.fs_stat

  local src_prefix = root .. "/src/main/java/"
  if buf_path:sub(1, #src_prefix) ~= src_prefix then
    return nil, "current file is not inside src/main/java/"
  end

  -- e.g. "org/example/app/UserService.java"
  local rel = buf_path:sub(#src_prefix + 1)

  -- Strip .java extension and get class name
  local rel_no_ext = rel:match("^(.+)%.java$")
  if not rel_no_ext then
    return nil, "current file is not a .java file"
  end

  -- Class name is the last path segment
  local class_name = rel_no_ext:match("([^/]+)$")
  local test_class = class_name .. "Test"

  -- Package from directory segments (everything except last segment)
  local pkg_path = rel_no_ext:match("^(.+)/[^/]+$") or ""
  local pkg = pkg_path:gsub("/", ".")
  local fqcn = (pkg ~= "" and (pkg .. "." .. test_class) or test_class)

  local test_rel = (pkg_path ~= "" and (pkg_path .. "/") or "") .. test_class .. ".java"
  local test_path = root .. "/src/test/java/" .. test_rel

  return {
    test_path = test_path,
    class_name = test_class,
    fqcn = fqcn,
    pkg = pkg,
    exists = stat_fn(test_path) ~= nil,
  },
    nil
end

---Map the active buffer's source file to its test counterpart.
---@param root string
---@return {test_path: string, class_name: string, fqcn: string, pkg: string, exists: boolean}|nil
---@return string|nil err
function M.map_to_test(root)
  local buf_path = vim.fn.expand("%:p")
  return M._map_to_test(buf_path, root)
end

---Resolve the argv for a test command.
---@param tool "maven"|"gradle"|"none"
---@param class_name string Simple class name, e.g. "FooTest".
---@param fqcn string Fully-qualified class name, e.g. "org.example.FooTest".
---@param root string Project root path.
---@return string cmd, string[] args
function M._test_argv(tool, class_name, fqcn, root)
  if tool == "maven" then
    return "mvn", { "test", "-Dtest=" .. class_name }
  elseif tool == "gradle" then
    return "gradle", { "test", "--tests", fqcn }
  else
    return "java",
      {
        "-cp",
        root .. "/target/classes:" .. root .. "/target/test-classes",
        "org.junit.platform.console.standalone.ConsoleLauncher",
        "--select-class=" .. fqcn,
      }
  end
end

---Run the test class described by `info`, streaming output to [jam:test].
---@param root string Project root path.
---@param tool "maven"|"gradle"|"none"
---@param info {class_name: string, fqcn: string} Mapping result from map_to_test.
function M.run_tests(root, tool, info)
  local output = require("jam.output")
  local buf = output.get_or_create("[jam:test]")
  output.open(buf)
  output.clear(buf)

  local cmd, args = M._test_argv(tool, info.class_name, info.fqcn, root)

  local stdout = vim.uv.new_pipe(false)
  local stderr = vim.uv.new_pipe(false)

  local handle
  handle = vim.uv.spawn(cmd, { args = args, cwd = root, stdio = { nil, stdout, stderr } }, function(exit_code)
    stdout:close()
    stderr:close()
    if handle then
      handle:close()
    end
    vim.schedule(function()
      if exit_code == 0 then
        vim.notify("[jam] Tests passed", vim.log.levels.INFO)
      elseif exit_code == 1 then
        vim.notify("[jam] Tests failed", vim.log.levels.WARN)
      else
        vim.notify(("[jam] Test runner error (exit %d)"):format(exit_code), vim.log.levels.ERROR)
      end
    end)
  end)

  if not handle then
    vim.notify(("[jam] failed to spawn '%s'"):format(cmd), vim.log.levels.ERROR)
    return
  end

  local function pipe_to_buf(pipe)
    vim.uv.read_start(pipe, function(err, data)
      if err or not data then
        return
      end
      local lines = vim.split(data, "\n", { plain = true, trimempty = false })
      vim.schedule(function()
        output.append(buf, lines)
      end)
    end)
  end

  pipe_to_buf(stdout)
  pipe_to_buf(stderr)
end

---Render a JUnit 5 test boilerplate string.
---@param pkg string Package name, e.g. "org.example.app" (may be empty for default pkg).
---@param test_class string Simple test class name, e.g. "FooTest".
---@return string
function M._test_template(pkg, test_class)
  local pkg_line = pkg ~= "" and ("package " .. pkg .. ";\n\n") or ""
  return pkg_line
    .. "import org.junit.jupiter.api.Test;\n"
    .. "import static org.junit.jupiter.api.Assertions.*;\n"
    .. "\n"
    .. "class "
    .. test_class
    .. " {\n"
    .. "\n"
    .. "    @Test\n"
    .. "    void exampleTest() {\n"
    .. "        // TODO: write test\n"
    .. "    }\n"
    .. "}\n"
end

---Create a JUnit 5 test file scaffold, open it, and position the cursor on
---the TODO line.
---@param test_path string Absolute path for the new test file.
---@param pkg string Package name (may be empty string for default package).
---@param test_class string Simple test class name, e.g. "FooTest".
---@param cursor_fn? fun(line: integer) Injected for tests instead of nvim_win_set_cursor.
function M.generate_test(test_path, pkg, test_class, cursor_fn)
  local fs = require("jam.fs")

  local dir = vim.fn.fnamemodify(test_path, ":h")
  local _, dir_err = fs.ensure_project_dir(dir)
  if dir_err then
    vim.notify("[jam] failed to create test directory: " .. dir_err, vim.log.levels.ERROR)
    return
  end

  local content = M._test_template(pkg, test_class)
  local _, write_err = fs.write_file(test_path, content)
  if write_err then
    vim.notify("[jam] failed to write test file: " .. write_err, vim.log.levels.ERROR)
    return
  end

  vim.cmd.edit(test_path)

  -- Find the TODO line (1-based) and position cursor there
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local todo_line = 1
  for i, line in ipairs(lines) do
    if line:find("// TODO", 1, true) then
      todo_line = i
      break
    end
  end

  if cursor_fn then
    cursor_fn(todo_line)
  else
    vim.api.nvim_win_set_cursor(0, { todo_line, 8 })
  end

  vim.notify("[jam] created test file: " .. test_path, vim.log.levels.INFO)
end

return M
