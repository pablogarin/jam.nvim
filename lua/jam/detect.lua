local M = {}

---@type string|nil
local _java_bin = nil
local _resolved = false

---Pure resolution logic — injectable for unit tests.
---@param java_home string|nil Value of $JAVA_HOME (or nil if unset).
---@param stat_fn fun(path: string): any|nil Returns truthy when path exists.
---@param exepath_fn fun(name: string): string Returns binary path or "".
---@return string|nil
function M._resolve_java(java_home, stat_fn, exepath_fn)
  if java_home then
    local candidate = java_home .. "/bin/javac"
    if stat_fn(candidate) then
      return candidate
    end
  end
  local found = exepath_fn("javac")
  if found and found ~= "" then
    return found
  end
  return nil
end

---T-06: Return the path to javac, or nil if no JDK is available.
---Result is cached after the first call.
---@return string|nil
function M.find_java()
  if _resolved then
    return _java_bin
  end
  _java_bin = M._resolve_java(vim.uv.os_getenv("JAVA_HOME"), vim.uv.fs_stat, vim.fn.exepath)
  _resolved = true
  return _java_bin
end

---Reset the internal cache (for tests only).
function M._reset()
  _java_bin = nil
  _resolved = false
end

---T-09: Return the JDK major version integer for use in pom.xml.
---Tries to extract the version from the javac binary path; falls back to 17.
---@return integer
function M.find_java_version()
  local path = M.find_java() or ""
  local major = path:match("java%-(%d+)") or path:match("jdk%-(%d+)") or path:match("jdk(%d+)")
  if major then
    return tonumber(major)
  end
  return 17
end

return M
