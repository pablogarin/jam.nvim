local M = {}

---Recursively create `path` and any missing ancestor directories.
---@param path string
---@return true|nil, string|nil err
local function mkdir_p(path)
  if vim.uv.fs_stat(path) then
    return true
  end
  local parent = vim.fn.fnamemodify(path, ":h")
  if parent ~= path then
    local ok, err = mkdir_p(parent)
    if not ok then
      return nil, err
    end
  end
  -- 493 == 0755 octal
  local ok, err = vim.uv.fs_mkdir(path, 493)
  if not ok then
    return nil, err
  end
  return true
end

---T-05: Validate and create a new project directory.
---Aborts if the path already exists.
---Checks write permission on the deepest existing ancestor before creating.
---@param path string Absolute path for the new project root.
---@return true|nil, string|nil err
function M.ensure_project_dir(path)
  if vim.uv.fs_stat(path) then
    return nil, ("path already exists: %s"):format(path)
  end

  -- Walk up to the deepest ancestor that already exists.
  local ancestor = vim.fn.fnamemodify(path, ":h")
  while ancestor ~= vim.fn.fnamemodify(ancestor, ":h") and not vim.uv.fs_stat(ancestor) do
    ancestor = vim.fn.fnamemodify(ancestor, ":h")
  end

  if not vim.uv.fs_access(ancestor, 2) then
    return nil, ("no write permission on: %s"):format(ancestor)
  end

  local ok, err = mkdir_p(path)
  if not ok then
    return nil, ("cannot create '%s': %s"):format(path, err or "unknown error")
  end
  return true
end

---T-08: Create the standard Maven source tree inside an existing project root.
---@param root string Absolute path of the project root (must already exist).
---@param pkg_path string Package segments as a path, e.g. "org/example/myproject".
---@return true|nil, string|nil err
function M.scaffold_maven(root, pkg_path)
  local dirs = {
    root .. "/src/main/java/" .. pkg_path,
    root .. "/src/main/resources",
    root .. "/src/test/java",
  }
  for _, dir in ipairs(dirs) do
    local ok, err = mkdir_p(dir)
    if not ok then
      return nil, ("failed to create '%s': %s"):format(dir, err or "unknown error")
    end
  end
  return true
end

---T-10/T-09: Write `content` to `path`, creating the file (mode 0644).
---@param path string
---@param content string
---@return true|nil, string|nil err
function M.write_file(path, content)
  local fd, err = vim.uv.fs_open(path, "w", 420) -- 420 == 0644 octal
  if not fd then
    return nil, err
  end
  local nbytes, werr = vim.uv.fs_write(fd, content, -1)
  vim.uv.fs_close(fd)
  if not nbytes then
    return nil, werr
  end
  return true
end

---T-11: Run `git init` in `dir` asynchronously.
---Calls `callback(true)` on success, `callback(false)` on failure or if git is absent.
---@param dir string
---@param callback fun(ok: boolean)
function M.git_init(dir, callback)
  local handle
  handle = vim.uv.spawn("git", { args = { "init" }, cwd = dir }, function(code, _signal)
    handle:close()
    vim.schedule(function()
      callback(code == 0)
    end)
  end)
  if not handle then
    vim.schedule(function()
      callback(false)
    end)
  end
end

return M
