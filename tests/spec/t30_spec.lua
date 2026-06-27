-- Captured at load time (before t26's mock runs) so reset() can restore it.
local _real_buf_get_lines = vim.api.nvim_buf_get_lines

local function reset()
  package.loaded["jam.ui"] = nil
  vim.schedule = function(fn)
    fn()
  end
  vim.api.nvim_buf_get_lines = _real_buf_get_lines
end

-- Extract the string text from a win config title, which Neovim returns as
-- either a plain string or a list of {text, hl} pairs.
local function title_text(cfg)
  local t = cfg.title
  if type(t) == "string" then
    return t
  end
  if type(t) == "table" and t[1] then
    local first = t[1]
    return type(first) == "string" and first or (type(first) == "table" and first[1] or "")
  end
  return ""
end

describe("T-30 | _open_input_win — window properties", function()
  before_each(reset)

  it("returns a valid buffer and window", function()
    local ctx = require("jam.ui")._open_input_win({ prompt = "Test:" })
    expect(vim.api.nvim_buf_is_valid(ctx.buf)).to_be_true()
    expect(vim.api.nvim_win_is_valid(ctx.win)).to_be_true()
    vim.api.nvim_win_close(ctx.win, true)
  end)

  it("window is relative to the editor", function()
    local ctx = require("jam.ui")._open_input_win({ prompt = "Test:" })
    local cfg = vim.api.nvim_win_get_config(ctx.win)
    expect(cfg.relative).to_be("editor")
    vim.api.nvim_win_close(ctx.win, true)
  end)

  it("window has a border set", function()
    local ctx = require("jam.ui")._open_input_win({ prompt = "Test:" })
    local cfg = vim.api.nvim_win_get_config(ctx.win)
    expect(cfg.border ~= nil).to_be_true()
    -- A border of "none" is returned as the empty string; any other value means a border is visible
    local no_border = cfg.border == "none" or cfg.border == ""
    expect(no_border).to_be(false)
    vim.api.nvim_win_close(ctx.win, true)
  end)

  it("window title contains the prompt text", function()
    local ctx = require("jam.ui")._open_input_win({ prompt = "Enter project name:" })
    local cfg = vim.api.nvim_win_get_config(ctx.win)
    expect(title_text(cfg):find("Enter project name:", 1, true) ~= nil).to_be_true()
    vim.api.nvim_win_close(ctx.win, true)
  end)

  it("window height is 1 (single input line)", function()
    local ctx = require("jam.ui")._open_input_win({ prompt = "Name:" })
    local cfg = vim.api.nvim_win_get_config(ctx.win)
    expect(cfg.height).to_be(1)
    vim.api.nvim_win_close(ctx.win, true)
  end)
end)

describe("T-30 | _make_handlers — confirm and cancel", function()
  before_each(reset)

  local function open_scratch()
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, false, {
      relative = "editor",
      width = 40,
      height = 1,
      row = 5,
      col = 5,
      border = "rounded",
    })
    return buf, win
  end

  it("confirm calls callback with the buffer's first line", function()
    local buf, win = open_scratch()
    local result = nil
    local h = require("jam.ui")._make_handlers(buf, win, function(text)
      result = text
    end)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello world" })
    h.confirm()
    expect(result).to_be("hello world")
  end)

  it("cancel calls callback with nil", function()
    local buf, win = open_scratch()
    local result = "unchanged"
    local h = require("jam.ui")._make_handlers(buf, win, function(text)
      result = text
    end)
    h.cancel()
    expect(result).to_be(nil)
  end)

  it("confirm closes the window", function()
    local buf, win = open_scratch()
    local h = require("jam.ui")._make_handlers(buf, win, function() end)
    h.confirm()
    expect(vim.api.nvim_win_is_valid(win)).to_be(false)
  end)

  it("cancel closes the window", function()
    local buf, win = open_scratch()
    local h = require("jam.ui")._make_handlers(buf, win, function() end)
    h.cancel()
    expect(vim.api.nvim_win_is_valid(win)).to_be(false)
  end)

  it("calling confirm twice invokes callback only once", function()
    local buf, win = open_scratch()
    local count = 0
    local h = require("jam.ui")._make_handlers(buf, win, function()
      count = count + 1
    end)
    h.confirm()
    h.confirm()
    expect(count).to_be(1)
  end)

  it("calling cancel then confirm invokes callback only once", function()
    local buf, win = open_scratch()
    local count = 0
    local h = require("jam.ui")._make_handlers(buf, win, function()
      count = count + 1
    end)
    h.cancel()
    h.confirm()
    expect(count).to_be(1)
  end)
end)
