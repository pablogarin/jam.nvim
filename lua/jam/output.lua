local M = {}

local _wins = {}

local function strip_ansi(s)
  return s:gsub("\27%[[0-9;]*[A-Za-z]", ""):gsub("\r", "")
end

---Return an existing scratch buffer with the given name, or create one.
---@param name string Buffer name, e.g. "[jam:build]".
---@return integer bufnr
function M.get_or_create(name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):find(name, 1, true) then
      return buf
    end
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].bufhidden = "hide"
  return buf
end

---Open the buffer in a centered floating window.
---If the buffer already has a valid window tracked in _wins, this is a no-op.
---@param buf integer
function M.open(buf)
  if _wins[buf] and vim.api.nvim_win_is_valid(_wins[buf]) then
    return
  end
  local name = vim.api.nvim_buf_get_name(buf)
  local width = math.max(40, math.floor(vim.o.columns * 0.8))
  local height = math.max(20, math.floor(vim.o.lines * 0.8))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. name .. " ",
    title_pos = "center",
  })
  _wins[buf] = win
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  local map_opts = { buffer = buf, nowait = true, silent = true }
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    _wins[buf] = nil
  end
  vim.keymap.set("n", "q", close, map_opts)
  vim.keymap.set("n", "<Esc>", close, map_opts)
end

---Move the cursor of the tracked window to the last line of the buffer.
---@param buf integer
function M.scroll_to_end(buf)
  local win = _wins[buf]
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local line_count = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_win_set_cursor(win, { line_count, 0 })
end

---Append lines to the buffer, stripping ANSI codes first.
---When the buffer contains only the single implicit empty line, the empty line
---is replaced rather than prepended.
---@param buf integer
---@param raw_lines string[]
function M.append(buf, raw_lines)
  local lines = {}
  for _, l in ipairs(raw_lines) do
    local stripped = strip_ansi(l)
    table.insert(lines, stripped)
  end
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  local existing = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #existing == 1 and existing[1] == "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  else
    vim.api.nvim_buf_set_lines(buf, #existing, -1, false, lines)
  end
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  M.scroll_to_end(buf)
end

---Remove all content from the buffer.
---@param buf integer
function M.clear(buf)
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M
