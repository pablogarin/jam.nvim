local M = {}

---Return an existing scratch buffer with the given name, or create one.
---The buffer is configured as nofile/noswap so it never prompts for saves.
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

---Open the buffer in a bottom split, reusing the window if already visible.
---@param buf integer
function M.open(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  vim.cmd("botright split")
  vim.api.nvim_set_current_buf(buf)
end

---Append lines to the buffer.
---When the buffer contains only the single implicit empty line (i.e. it is
---effectively blank), the empty line is replaced rather than prepended.
---@param buf integer
---@param lines string[]
function M.append(buf, lines)
  local existing = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #existing == 1 and existing[1] == "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  else
    vim.api.nvim_buf_set_lines(buf, #existing, -1, false, lines)
  end
end

---Remove all content from the buffer.
---@param buf integer
function M.clear(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
end

return M
