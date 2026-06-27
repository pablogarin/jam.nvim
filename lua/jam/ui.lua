local M = {}

local function center_win(width, height)
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))
  return row, col
end

---Open a centered floating window for text input.
---@param opts {prompt?: string}
---@return {buf: integer, win: integer}
function M._open_input_win(opts)
  local prompt = (opts and opts.prompt) or ""
  local width = math.min(math.max(40, #prompt + 6), vim.o.columns - 4)
  local row, col = center_win(width, 1)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. prompt .. " ",
    title_pos = "center",
  })

  return { buf = buf, win = win }
end

---Build confirm/cancel handlers for a floating input window.
---Exposed for unit tests so keypresses need not be simulated.
---@param buf integer
---@param win integer
---@param callback fun(text: string|nil)
---@return {confirm: fun(), cancel: fun()}
function M._make_handlers(buf, win, callback)
  local done = false
  local function finish(text)
    if done then
      return
    end
    done = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    callback(text)
  end
  return {
    confirm = function()
      local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
      finish(line)
    end,
    cancel = function()
      finish(nil)
    end,
  }
end

---Show a floating text-input dialog.
---Same signature as vim.ui.input.
---@param opts {prompt?: string}
---@param callback fun(text: string|nil)
function M.input(opts, callback)
  local ctx = M._open_input_win(opts)
  local h = M._make_handlers(ctx.buf, ctx.win, callback)
  vim.keymap.set("i", "<CR>", h.confirm, { buffer = ctx.buf, nowait = true, silent = true })
  vim.keymap.set({ "i", "n" }, "<Esc>", h.cancel, { buffer = ctx.buf, nowait = true, silent = true })
  pcall(vim.cmd, "startinsert")
end

---Open a centered floating window populated with selectable items.
---@param items string[]
---@param opts {prompt?: string}
---@return {buf: integer, win: integer}
function M._open_select_win(items, opts)
  local title = (opts and opts.prompt) or ""
  local max_len = #title
  for _, item in ipairs(items) do
    if #item > max_len then
      max_len = #item
    end
  end
  local width = math.min(math.max(30, max_len + 2), vim.o.columns - 4)
  local height = #items
  local row, col = center_win(width, height)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, items)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }
  if title ~= "" then
    win_opts.title = " " .. title .. " "
    win_opts.title_pos = "center"
  end

  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_set_option_value("cursorline", true, { win = win })

  return { buf = buf, win = win }
end

---Build confirm/cancel/navigate handlers for a floating selection window.
---Exposed for unit tests so keypresses need not be simulated.
---@param win integer
---@param items string[]
---@param callback fun(item: string|nil)
---@return {confirm: fun(), cancel: fun(), move_down: fun(), move_up: fun()}
function M._make_select_handlers(win, items, callback)
  local done = false
  local function finish(item)
    if done then
      return
    end
    done = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    callback(item)
  end
  local function move_down()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    if row < #items then
      vim.api.nvim_win_set_cursor(win, { row + 1, 0 })
    end
  end
  local function move_up()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    if row > 1 then
      vim.api.nvim_win_set_cursor(win, { row - 1, 0 })
    end
  end
  return {
    confirm = function()
      if done then
        return
      end
      local row = vim.api.nvim_win_get_cursor(win)[1]
      finish(items[row])
    end,
    cancel = function()
      finish(nil)
    end,
    move_down = move_down,
    move_up = move_up,
  }
end

---Show a floating selection dialog.
---Same signature as vim.ui.select.
---@param items string[]
---@param opts {prompt?: string}
---@param callback fun(item: string|nil)
function M.select(items, opts, callback)
  if not items or #items == 0 then
    callback(nil)
    return
  end
  local ctx = M._open_select_win(items, opts)
  local h = M._make_select_handlers(ctx.win, items, callback)
  local map_opts = { buffer = ctx.buf, nowait = true, silent = true }
  vim.keymap.set("n", "<CR>", h.confirm, map_opts)
  vim.keymap.set("n", "<Esc>", h.cancel, map_opts)
  vim.keymap.set("n", "q", h.cancel, map_opts)
  vim.keymap.set("n", "j", h.move_down, map_opts)
  vim.keymap.set("n", "<Down>", h.move_down, map_opts)
  vim.keymap.set("n", "k", h.move_up, map_opts)
  vim.keymap.set("n", "<Up>", h.move_up, map_opts)
end

return M
