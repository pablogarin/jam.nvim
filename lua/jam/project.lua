local M = {}

---Pure walk-up logic — injectable for unit tests.
---Checks each ancestor directory for pom.xml, build.gradle, or .git in that
---priority order. The first match wins; .git alone means tool="none".
---@param start_dir string Directory to begin the search from.
---@param stat_fn fun(path: string): any|nil Returns truthy when the path exists.
---@return {root: string, tool: "maven"|"gradle"|"none"}|nil
function M._find_root(start_dir, stat_fn)
  local dir = start_dir
  while true do
    if stat_fn(dir .. "/pom.xml") then
      return { root = dir, tool = "maven" }
    elseif stat_fn(dir .. "/build.gradle") then
      return { root = dir, tool = "gradle" }
    elseif stat_fn(dir .. "/.git") then
      return { root = dir, tool = "none" }
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      return nil
    end
    dir = parent
  end
end

---Find the project root and build tool starting from the active buffer's
---directory, falling back to cwd when no buffer path is available.
---@return {root: string, tool: "maven"|"gradle"|"none"}|nil
function M.find_root()
  local buf_path = vim.fn.expand("%:p:h")
  local start = (buf_path ~= "" and buf_path ~= ".") and buf_path or (vim.uv.cwd() or ".")
  return M._find_root(start, vim.uv.fs_stat)
end

return M
