local function reset()
  package.loaded["jam.ui"] = nil
end

local ITEMS = { "Maven (default)", "Gradle", "No Build Tools" }

describe("T-31 | _open_select_win — window properties", function()
  before_each(reset)

  it("returns a valid buffer and window", function()
    local ctx = require("jam.ui")._open_select_win(ITEMS, {})
    expect(vim.api.nvim_buf_is_valid(ctx.buf)).to_be_true()
    expect(vim.api.nvim_win_is_valid(ctx.win)).to_be_true()
    vim.api.nvim_win_close(ctx.win, true)
  end)

  it("window contains all items as lines", function()
    local ctx = require("jam.ui")._open_select_win(ITEMS, {})
    local lines = vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)
    expect(#lines).to_be(#ITEMS)
    expect(lines[1]).to_be("Maven (default)")
    expect(lines[2]).to_be("Gradle")
    expect(lines[3]).to_be("No Build Tools")
    vim.api.nvim_win_close(ctx.win, true)
  end)

  it("cursor starts on line 1", function()
    local ctx = require("jam.ui")._open_select_win(ITEMS, {})
    local row = vim.api.nvim_win_get_cursor(ctx.win)[1]
    expect(row).to_be(1)
    vim.api.nvim_win_close(ctx.win, true)
  end)

  it("window height equals item count", function()
    local ctx = require("jam.ui")._open_select_win(ITEMS, {})
    local cfg = vim.api.nvim_win_get_config(ctx.win)
    expect(cfg.height).to_be(#ITEMS)
    vim.api.nvim_win_close(ctx.win, true)
  end)

  it("window width fits the longest item", function()
    local ctx = require("jam.ui")._open_select_win(ITEMS, {})
    local cfg = vim.api.nvim_win_get_config(ctx.win)
    local max_len = 0
    for _, item in ipairs(ITEMS) do
      if #item > max_len then
        max_len = #item
      end
    end
    expect(cfg.width >= max_len).to_be_true()
    vim.api.nvim_win_close(ctx.win, true)
  end)

  it("buffer is not modifiable", function()
    local ctx = require("jam.ui")._open_select_win(ITEMS, {})
    local modifiable = vim.api.nvim_get_option_value("modifiable", { buf = ctx.buf })
    expect(modifiable).to_be(false)
    vim.api.nvim_win_close(ctx.win, true)
  end)
end)

describe("T-31 | _make_select_handlers — confirm, cancel, navigate", function()
  before_each(reset)

  local function open_select()
    local ctx = require("jam.ui")._open_select_win(ITEMS, {})
    return ctx.buf, ctx.win
  end

  it("confirm returns the item at cursor position", function()
    local buf, win = open_select()
    local result = "unchanged"
    local h = require("jam.ui")._make_select_handlers(win, ITEMS, function(item)
      result = item
    end)
    h.confirm()
    expect(result).to_be("Maven (default)")
    _ = buf
  end)

  it("confirm closes the window", function()
    local buf, win = open_select()
    local h = require("jam.ui")._make_select_handlers(win, ITEMS, function() end)
    h.confirm()
    expect(vim.api.nvim_win_is_valid(win)).to_be(false)
    _ = buf
  end)

  it("cancel calls callback with nil", function()
    local buf, win = open_select()
    local result = "unchanged"
    local h = require("jam.ui")._make_select_handlers(win, ITEMS, function(item)
      result = item
    end)
    h.cancel()
    expect(result).to_be(nil)
    _ = buf
  end)

  it("cancel closes the window", function()
    local buf, win = open_select()
    local h = require("jam.ui")._make_select_handlers(win, ITEMS, function() end)
    h.cancel()
    expect(vim.api.nvim_win_is_valid(win)).to_be(false)
    _ = buf
  end)

  it("calling confirm twice invokes callback only once", function()
    local buf, win = open_select()
    local count = 0
    local h = require("jam.ui")._make_select_handlers(win, ITEMS, function()
      count = count + 1
    end)
    h.confirm()
    h.confirm()
    expect(count).to_be(1)
    _ = buf
  end)

  it("move_down advances cursor to line 2", function()
    local buf, win = open_select()
    local h = require("jam.ui")._make_select_handlers(win, ITEMS, function() end)
    h.move_down()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    expect(row).to_be(2)
    vim.api.nvim_win_close(win, true)
    _ = buf
  end)

  it("confirm after move_down returns the second item", function()
    local buf, win = open_select()
    local result = nil
    local h = require("jam.ui")._make_select_handlers(win, ITEMS, function(item)
      result = item
    end)
    h.move_down()
    h.confirm()
    expect(result).to_be("Gradle")
    _ = buf
  end)

  it("move_up moves cursor back up", function()
    local buf, win = open_select()
    local h = require("jam.ui")._make_select_handlers(win, ITEMS, function() end)
    h.move_down()
    h.move_up()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    expect(row).to_be(1)
    vim.api.nvim_win_close(win, true)
    _ = buf
  end)

  it("move_down does not wrap past the last item", function()
    local buf, win = open_select()
    local h = require("jam.ui")._make_select_handlers(win, ITEMS, function() end)
    for _ = 1, #ITEMS + 5 do
      h.move_down()
    end
    local row = vim.api.nvim_win_get_cursor(win)[1]
    expect(row).to_be(#ITEMS)
    vim.api.nvim_win_close(win, true)
    _ = buf
  end)

  it("move_up does not wrap before the first item", function()
    local buf, win = open_select()
    local h = require("jam.ui")._make_select_handlers(win, ITEMS, function() end)
    for _ = 1, 5 do
      h.move_up()
    end
    local row = vim.api.nvim_win_get_cursor(win)[1]
    expect(row).to_be(1)
    vim.api.nvim_win_close(win, true)
    _ = buf
  end)
end)
