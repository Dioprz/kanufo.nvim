local M = {}

M.options = {
  default_dir = '',
  profiles = {},
}

M.current_profile = nil
M.profile_buffers = {}

local function ends_with_slash(str)
  return str:match('/$') ~= nil
end

local function path_normalizer(path)
  path = vim.fn.expand(path)
  if not ends_with_slash(path) then
    path = path .. '/'
  end
  return path
end

function M.setup(opts)
  opts.default_dir = path_normalizer(opts.default_dir)
  M.options = vim.tbl_deep_extend('force', M.options, opts or {})
end

return M
