---@class JamConfig
---@field default_build_tool "maven"|"gradle"|"none"
---@field default_workspace string|nil
---@field git_init boolean
---@field inject_main boolean

local M = {}

---@type JamConfig
local default_config = {
  default_build_tool = "maven",
  default_workspace = nil,
  git_init = true,
  inject_main = true,
}

local subcommands = { "build", "create", "imports", "run", "test" }

---@param arglead string
---@return string[]
local function complete(arglead)
  return vim.tbl_filter(function(s)
    return s:find(arglead, 1, true) == 1
  end, subcommands)
end

---@param opts? JamConfig
function M.setup(opts)
  local _config = vim.tbl_deep_extend("force", default_config, opts or {})

  vim.api.nvim_create_user_command("Jam", function(args)
    local subcmd = args.fargs[1]
    if subcmd == "build" then
      require("jam.build").build()
    elseif subcmd == "run" then
      require("jam.build").run()
    elseif subcmd == "test" then
      local project = require("jam.project")
      local test_mod = require("jam.test")
      local ctx = project.find_root()
      if not ctx then
        vim.notify("[jam] no project root found (no pom.xml, build.gradle, or .git)", vim.log.levels.ERROR)
        return
      end
      local info, err = test_mod.map_to_test(ctx.root)
      if not info then
        vim.notify("[jam] " .. err, vim.log.levels.ERROR)
        return
      end
      if info.exists then
        test_mod.run_tests(ctx.root, ctx.tool, info)
      else
        test_mod.generate_test(info.test_path, info.pkg, info.class_name)
      end
    elseif subcmd == "imports" then
      require("jam.lsp").organize_imports()
    elseif subcmd == "create" then
      require("jam.create").create()
    else
      vim.notify("[jam] unknown subcommand: " .. (subcmd or ""), vim.log.levels.ERROR)
    end
  end, {
    nargs = "+",
    complete = function(arglead)
      return complete(arglead)
    end,
    desc = "Java administration for Neovim",
  })

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function(ev)
      require("jam.lsp").attach_if_project(ev.buf)
    end,
  })
end

M._complete = complete

return M
