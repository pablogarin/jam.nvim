local function reset()
  package.loaded["jam.output"] = nil
end

describe("T-35 | Floating output window", function()
  before_each(reset)

  it("M.open() creates a window with relative='editor'", function()
    local out = require("jam.output")
    local buf = out.get_or_create("[jam:t35-open]")
    out.open(buf)
    local wins = vim.api.nvim_list_wins()
    local found_win
    for _, w in ipairs(wins) do
      if vim.api.nvim_win_get_buf(w) == buf then
        found_win = w
        break
      end
    end
    expect(found_win ~= nil).to_be_true()
    local cfg = vim.api.nvim_win_get_config(found_win)
    expect(cfg.relative).to_be("editor")
  end)

  it("M.open() creates a window with a visible border", function()
    local out = require("jam.output")
    local buf = out.get_or_create("[jam:t35-border]")
    out.open(buf)
    local found_win
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == buf then
        found_win = w
        break
      end
    end
    local cfg = vim.api.nvim_win_get_config(found_win)
    local no_border = cfg.border == nil or cfg.border == "none" or cfg.border == ""
    expect(no_border).to_be(false)
  end)

  it("M.open() sets the title to the buffer name", function()
    local out = require("jam.output")
    local buf = out.get_or_create("[jam:t35-title]")
    out.open(buf)
    local wins = vim.api.nvim_list_wins()
    local found_win
    for _, w in ipairs(wins) do
      if vim.api.nvim_win_get_buf(w) == buf then
        found_win = w
        break
      end
    end
    local cfg = vim.api.nvim_win_get_config(found_win)
    local title_str = ""
    if type(cfg.title) == "table" then
      for _, part in ipairs(cfg.title) do
        title_str = title_str .. part[1]
      end
    else
      title_str = cfg.title or ""
    end
    expect(title_str:find("[jam:t35-title]", 1, true) ~= nil).to_be_true()
  end)

  it("a second M.open() call does not create a duplicate window", function()
    local out = require("jam.output")
    local buf = out.get_or_create("[jam:t35-dedup]")
    out.open(buf)
    local count_before = 0
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == buf then
        count_before = count_before + 1
      end
    end
    out.open(buf)
    local count_after = 0
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == buf then
        count_after = count_after + 1
      end
    end
    expect(count_before).to_be(1)
    expect(count_after).to_be(1)
  end)

  it("q keymap closes the window and clears _wins entry", function()
    local out = require("jam.output")
    local buf = out.get_or_create("[jam:t35-q]")
    out.open(buf)
    local found_win
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == buf then
        found_win = w
        break
      end
    end
    expect(found_win ~= nil).to_be_true()
    -- trigger the q keymap handler
    local keymaps = vim.api.nvim_buf_get_keymap(buf, "n")
    local q_map
    for _, km in ipairs(keymaps) do
      if km.lhs == "q" then
        q_map = km
        break
      end
    end
    expect(q_map ~= nil).to_be_true()
    -- call the callback directly
    q_map.callback()
    expect(vim.api.nvim_win_is_valid(found_win)).to_be(false)
    -- after close, a new open() should open a fresh window
    out.open(buf)
    local reopen_count = 0
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == buf then
        reopen_count = reopen_count + 1
      end
    end
    expect(reopen_count).to_be(1)
  end)

  it("M.scroll_to_end() positions cursor on the last line", function()
    local out = require("jam.output")
    local buf = out.get_or_create("[jam:t35-scroll]")
    out.open(buf)
    out.append(buf, { "first", "second", "third" })
    local found_win
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == buf then
        found_win = w
        break
      end
    end
    local cursor = vim.api.nvim_win_get_cursor(found_win)
    expect(cursor[1]).to_be(3)
  end)

  it("M.scroll_to_end() is a no-op when the window is closed", function()
    local out = require("jam.output")
    local buf = out.get_or_create("[jam:t35-scroll-noop]")
    -- do not open — scroll_to_end should not error
    local ok = pcall(out.scroll_to_end, buf)
    expect(ok).to_be_true()
  end)

  it("M.append() triggers auto-scroll to the last line", function()
    local out = require("jam.output")
    local buf = out.get_or_create("[jam:t35-autoscroll]")
    out.open(buf)
    out.append(buf, { "a", "b", "c", "d", "e" })
    local found_win
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == buf then
        found_win = w
        break
      end
    end
    local cursor = vim.api.nvim_win_get_cursor(found_win)
    expect(cursor[1]).to_be(5)
  end)
end)
