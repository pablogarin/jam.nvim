---@class RunnerState
local state = {
  pass = 0,
  fail = 0,
  suite = "",
  before_each_fn = nil,
}

local M = {}

---@param name string
---@param fn fun()
function M.describe(name, fn)
  state.suite = name
  state.before_each_fn = nil
  fn()
end

---@param fn fun()
function M.before_each(fn)
  state.before_each_fn = fn
end

---@param name string
---@param fn fun()
function M.it(name, fn)
  if state.before_each_fn then
    pcall(state.before_each_fn)
  end
  local ok, err = pcall(fn)
  if ok then
    state.pass = state.pass + 1
    print(("  PASS  %s > %s"):format(state.suite, name))
  else
    state.fail = state.fail + 1
    print(("  FAIL  %s > %s\n         %s"):format(state.suite, name, tostring(err)))
  end
end

---@param val any
---@return table
function M.expect(val)
  return {
    to_be = function(expected)
      if val ~= expected then
        error(("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(val)), 2)
      end
    end,
    to_be_true = function()
      if val ~= true then
        error(("expected true, got %s"):format(vim.inspect(val)), 2)
      end
    end,
    to_be_nil = function()
      if val ~= nil then
        error(("expected nil, got %s"):format(vim.inspect(val)), 2)
      end
    end,
    not_to_be_nil = function()
      if val == nil then
        error("expected non-nil value", 2)
      end
    end,
    to_contain = function(item)
      if type(val) ~= "table" then
        error("expected a table", 2)
      end
      for _, v in ipairs(val) do
        if v == item then
          return
        end
      end
      error(("expected table to contain %s"):format(vim.inspect(item)), 2)
    end,
  }
end

---Print summary and return true if all tests passed.
---@return boolean
function M.summary()
  local total = state.pass + state.fail
  print(("\n%d/%d passed"):format(state.pass, total))
  return state.fail == 0
end

return M
