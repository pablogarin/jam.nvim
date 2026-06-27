local M = {}

---@alias JamBuildTool "maven"|"gradle"|"none"

---Resolve the argv for a build command.
---@param tool JamBuildTool
---@param root string Project root path.
---@return string[] cmd, string[] args
function M._build_argv(tool, root)
  if tool == "maven" then
    return "mvn", { "compile" }
  elseif tool == "gradle" then
    return "gradle", { "classes" }
  else
    -- Collect all .java files under src/ and compile to target/classes/
    local java_files = {}
    local function scan(dir)
      local handle = vim.uv.fs_scandir(dir)
      if not handle then
        return
      end
      while true do
        local name, ftype = vim.uv.fs_scandir_next(handle)
        if not name then
          break
        end
        local full = dir .. "/" .. name
        if ftype == "directory" then
          scan(full)
        elseif name:sub(-5) == ".java" then
          table.insert(java_files, full)
        end
      end
    end
    scan(root .. "/src")
    local args = vim.list_extend({ "-d", root .. "/target/classes" }, java_files)
    return "javac", args
  end
end

---Build the project, streaming output to the [jam:build] scratch buffer.
---Calls callback(ok, exit_code) when done; if callback is nil, emits a
---default vim.notify on completion.
---@param callback? fun(ok: boolean, exit_code: integer)
function M.build(callback)
  local project = require("jam.project")
  local output = require("jam.output")

  local ctx = project.find_root()
  if not ctx then
    vim.notify("[jam] no project root found (no pom.xml, build.gradle, or .git)", vim.log.levels.ERROR)
    return
  end

  local buf = output.get_or_create("[jam:build]")
  output.open(buf)
  output.clear(buf)

  local cmd, args = M._build_argv(ctx.tool, ctx.root)

  local stdout = vim.uv.new_pipe(false)
  local stderr = vim.uv.new_pipe(false)

  local handle
  handle = vim.uv.spawn(cmd, { args = args, cwd = ctx.root, stdio = { nil, stdout, stderr } }, function(exit_code)
    stdout:close()
    stderr:close()
    if handle then
      handle:close()
    end
    local ok = exit_code == 0
    vim.schedule(function()
      if callback then
        callback(ok, exit_code)
      elseif ok then
        vim.notify("[jam] Build succeeded", vim.log.levels.INFO)
      else
        vim.notify(("[jam] Build failed (exit %d)"):format(exit_code), vim.log.levels.ERROR)
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

---Pure main-class resolution logic — injectable for unit tests.
---Resolution order: .jam.json mainClass → first Main.java scan → vim.ui.input.
---@param root string Project root path.
---@param callback fun(fqcn: string|nil) Called with the FQCN, or nil if cancelled.
---@param read_fn? fun(path: string): string|nil Returns file content or nil.
---@param find_fn? fun(dir: string): string|nil Returns path of first Main.java found.
function M._resolve_main_class(root, callback, read_fn, find_fn)
  read_fn = read_fn
    or function(path)
      local fd = vim.uv.fs_open(path, "r", 292)
      if not fd then
        return nil
      end
      local stat = vim.uv.fs_stat(path)
      local data = vim.uv.fs_read(fd, stat and stat.size or 4096, 0)
      vim.uv.fs_close(fd)
      return data
    end

  find_fn = find_fn
    or function(dir)
      local function scan(d)
        local handle = vim.uv.fs_scandir(d)
        if not handle then
          return nil
        end
        while true do
          local name, ftype = vim.uv.fs_scandir_next(handle)
          if not name then
            break
          end
          local full = d .. "/" .. name
          if ftype == "directory" then
            local found = scan(full)
            if found then
              return found
            end
          elseif name == "Main.java" then
            return full
          end
        end
        return nil
      end
      return scan(dir)
    end

  -- 1. .jam.json
  local jam_json = read_fn(root .. "/.jam.json")
  if jam_json then
    local ok, decoded = pcall(vim.json.decode, jam_json)
    if ok and decoded and decoded.mainClass then
      callback(decoded.mainClass)
      return
    end
  end

  -- 2. First Main.java under src/main/java/
  local main_java = find_fn(root .. "/src/main/java")
  if main_java then
    local content = read_fn(main_java)
    if content then
      local pkg = content:match("^%s*package%s+([%w%.]+)%s*;")
      if pkg then
        callback(pkg .. ".Main")
        return
      end
    end
  end

  -- 3. Prompt the user
  vim.ui.input({ prompt = "Main class (fully qualified): " }, function(input)
    if input == nil or input == "" then
      callback(nil)
    else
      callback(input)
    end
  end)
end

---Resolve the main class for the project at `root`.
---@param root string
---@param callback fun(fqcn: string|nil)
function M.resolve_main_class(root, callback)
  M._resolve_main_class(root, callback)
end

---Resolve the argv for a run command.
---@param tool JamBuildTool
---@param root string Project root path.
---@param fqcn string Fully-qualified main class name.
---@return string cmd, string[] args
function M._run_argv(tool, root, fqcn)
  if tool == "maven" then
    return "mvn", { "exec:java", "-Dexec.mainClass=" .. fqcn }
  elseif tool == "gradle" then
    return "gradle", { "run" }
  else
    return "java", { "-cp", root .. "/target/classes", fqcn }
  end
end

---Build the project then, on success, run the main class.
---Streams all output to the [jam:build] scratch buffer.
function M.run()
  local project = require("jam.project")
  local output = require("jam.output")

  local ctx = project.find_root()
  if not ctx then
    vim.notify("[jam] no project root found (no pom.xml, build.gradle, or .git)", vim.log.levels.ERROR)
    return
  end

  M.build(function(build_ok, exit_code)
    if not build_ok then
      vim.notify(("[jam] Build failed (exit %d) — run aborted"):format(exit_code), vim.log.levels.ERROR)
      return
    end

    M.resolve_main_class(ctx.root, function(fqcn)
      if not fqcn then
        return
      end

      local buf = output.get_or_create("[jam:build]")
      output.clear(buf)

      local cmd, args = M._run_argv(ctx.tool, ctx.root, fqcn)
      local stdout = vim.uv.new_pipe(false)
      local stderr = vim.uv.new_pipe(false)

      local handle
      handle = vim.uv.spawn(cmd, { args = args, cwd = ctx.root, stdio = { nil, stdout, stderr } }, function(rc)
        stdout:close()
        stderr:close()
        if handle then
          handle:close()
        end
        vim.schedule(function()
          if rc ~= 0 then
            vim.notify(("[jam] Run exited with code %d"):format(rc), vim.log.levels.WARN)
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
    end)
  end)
end

return M
