-- Entry point for the headless test suite.
-- Usage: nvim --headless --noplugin -u NONE -l tests/run.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
package.path = "./tests/?.lua;" .. package.path

local runner = require("runner")

-- Expose DSL as globals so spec files stay concise.
_G.describe = runner.describe
_G.before_each = runner.before_each
_G.it = runner.it
_G.expect = runner.expect

local specs = vim.fn.globpath("tests/spec", "*_spec.lua", false, true)
table.sort(specs)
for _, f in ipairs(specs) do
  dofile(f)
end

local ok = runner.summary()
os.exit(ok and 0 or 1)
