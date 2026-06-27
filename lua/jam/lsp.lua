local M = {}

local _warned = false

---Check whether nvim-jdtls is available.
---@return boolean ok, table|nil mod
function M.check()
  local ok, mod = pcall(require, "jdtls")
  return ok, ok and mod or nil
end

---Emit a single WARN notification per session if nvim-jdtls is absent.
---Returns true when jdtls is available, false otherwise.
---@return boolean
function M.maybe_warn()
  local ok = M.check()
  if not ok and not _warned then
    _warned = true
    vim.notify(
      "[jam] LSP features require nvim-jdtls.\n"
        .. "Install via Mason: :MasonInstall jdtls  (plugin: mfussenegger/nvim-jdtls)\n"
        .. "LSP will not be started until it is installed.",
      vim.log.levels.WARN
    )
  end
  return ok
end

---Reset the session-level warning flag (for tests only).
function M._reset_warned()
  _warned = false
end

---Execute java.action.organizeImports via the attached jdtls LSP client.
---Emits ERROR when the current buffer is not a Java file or jdtls is not attached.
---@param get_clients_fn? fun(opts: table): table[] Injected for tests; defaults to vim.lsp.get_clients.
---@param filetype_fn? fun(): string Injected for tests; defaults to reading &filetype.
function M.organize_imports(get_clients_fn, filetype_fn)
  filetype_fn = filetype_fn or function()
    return vim.bo.filetype
  end
  get_clients_fn = get_clients_fn or function(opts)
    return vim.lsp.get_clients(opts)
  end

  if filetype_fn() ~= "java" then
    vim.notify("[jam] imports: not a Java file", vim.log.levels.ERROR)
    return
  end

  local clients = get_clients_fn({ name = "jdtls" })
  if not clients or #clients == 0 then
    vim.notify(
      "[jam] imports: jdtls not attached — is nvim-jdtls installed and are you inside a project root?",
      vim.log.levels.ERROR
    )
    return
  end

  vim.lsp.buf.code_action({
    apply = true,
    context = {
      only = { "source.organizeImports" },
    },
    filter = function(action)
      return action.title == "java.action.organizeImports" or action.kind == "source.organizeImports"
    end,
  })
end

---Attempt to attach jdtls to a Java buffer if a project root can be found.
---@param buf integer Buffer handle.
---@param find_root_fn? fun(dir: string): {root: string, tool: string}|nil Injected for tests.
---@param java_fn? fun(): string|nil Injected for tests.
function M.attach_if_project(buf, find_root_fn, java_fn)
  if not M.maybe_warn() then
    return
  end

  local buf_name = vim.api.nvim_buf_get_name(buf)
  local buf_dir = vim.fn.fnamemodify(buf_name, ":h")

  find_root_fn = find_root_fn
    or function(dir)
      return require("jam.project")._find_root(dir, vim.uv.fs_stat)
    end
  java_fn = java_fn or function()
    return require("jam.detect").find_java()
  end

  local ctx = find_root_fn(buf_dir)
  if not ctx then
    return
  end

  local data_path = vim.fn.stdpath("data") .. "/jam-workspaces/" .. vim.fn.sha256(ctx.root)

  local _, jdtls_mod = M.check()
  jdtls_mod.start_or_attach({
    cmd = { java_fn() or "java", "-jar", "jdtls.jar" },
    root_dir = ctx.root,
    data = data_path,
  })
end

return M
