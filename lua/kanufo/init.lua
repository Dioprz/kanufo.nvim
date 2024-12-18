local config = require('kanufo.config')
local tz = require('true-zen.minimalist')

local M = {}

local function get_file_path(file)
  if vim.fn.filereadable(file) == 1 then
    return file
  elseif vim.fn.filereadable(config.options.default_dir .. file) == 1 then
    return config.options.default_dir .. file
  end
  return nil
end

local function close_current_profile(force)
  if config.current_profile then
    local unsaved_buffers = {}
    for _, bufnr in ipairs(config.profile_buffers) do
      if vim.fn.getbufinfo(bufnr)[1].changed == 1 then
        table.insert(unsaved_buffers, bufnr)
      end
    end

    if #unsaved_buffers > 0 and not force then
      local choice =
        vim.fn.confirm('There are unsaved buffers. Save changes?', '&Yes\n&No\n&Cancel', 1)
      if choice == 1 then
        for _, bufnr in ipairs(unsaved_buffers) do
          vim.cmd(string.format('buffer %d | write', bufnr))
        end
      elseif choice == 3 then
        return false -- Cancel, keep the current profile
      end
    end

    for _, bufnr in ipairs(config.profile_buffers) do
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    config.profile_buffers = {}
    config.current_profile = nil
  end

  return true -- Proceed with the profile switch
end

function M.open_profile(profile_name)
  vim.o.number = false -- Disable line numbers
  vim.o.relativenumber = false -- Disable relative line numbers
  vim.o.foldcolumn = '0' -- Set fold column width to 0
  vim.o.signcolumn = 'no' -- Disable the signcolumn

  local should_proceed = close_current_profile(false)
  if not should_proceed then
    return -- Cancel the profile switch
  end

  if not config.options.profiles[profile_name] then
    vim.notify("Profile '" .. profile_name .. "' not found", vim.log.levels.ERROR)
    return
  end

  local files = config.options.profiles[profile_name]
  local valid_files = {}

  for _, file in ipairs(files) do
    local file_path = get_file_path(file)
    if file_path then
      table.insert(valid_files, file_path)
    else
      vim.notify('File not found: ' .. file, vim.log.levels.WARN)
    end
  end

  local num_files = #valid_files
  if num_files == 0 then
    vim.notify("No valid files found in profile '" .. profile_name .. "'", vim.log.levels.WARN)
    return
  end

  vim.cmd('silent only')

  vim.o.winminwidth = 0
  for i, file in ipairs(valid_files) do
    if i > 1 then
      vim.cmd('vsplit')
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(file))
    table.insert(config.profile_buffers, vim.api.nvim_get_current_buf())
  end

  vim.cmd('wincmd =')
  config.current_profile = profile_name

  vim.schedule(function()
    if not tz.running then
      tz.toggle()
    end
  end)
end

function M.close_current_profile()
  close_current_profile(false)
  vim.o.number = true -- Disable line numbers
  vim.o.relativenumber = true -- Disable relative line numbers
  vim.o.foldcolumn = 'auto' -- Set fold column width to 0
  vim.o.signcolumn = 'yes' -- Disable the signcolumn
end

function M.setup(opts)
  config.setup(opts)
  -- local fileprocessor = require('kanufo.fileprocessor')
  -- fileprocessor.setup(config.options.default_dir) -- Pass the default_dir option

  local processor_on_save = require('kanufo.fileprocessor').on_file_save
  local default_dir = config.options.default_dir

  vim.api.nvim_create_augroup('KanufoFileProcessing', { clear = true })
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = 'KanufoFileProcessing',
    pattern = default_dir .. '*', -- Only process files within the default_dir
    callback = function()
      local file_path = vim.api.nvim_buf_get_name(0)
      if file_path:match(default_dir) then -- Double check if the file is within the default_dir
        processor_on_save(file_path)

        -- Refresh the buffer after your processor function finishes
        vim.api.nvim_command('checktime')

        -- Using a function FOR CONSISTENCY WITH PREVIOUS EXAMPLE
        local function RefreshBuffer()
          if vim.api.nvim_buf_get_option(0, 'modified') then
            vim.api.nvim_command('silent! edit!')
          end
        end
        RefreshBuffer()
      end
    end,
  })

  vim.api.nvim_create_user_command('KanufoOpenProfile', function(args)
    M.open_profile(args.args)
  end, {
    nargs = 1,
    complete = function(_, _, _)
      return vim.tbl_keys(config.options.profiles)
    end,
  })

  vim.api.nvim_create_user_command('KanufoCloseCurrentProfile', function()
    M.close_current_profile()
    if tz.running then
      tz.toggle()
    end
  end, {
    nargs = 0,
  })

  vim.api.nvim_create_user_command('KanufoToggleTask', function()
    require('kanufo.fileprocessor').toggle_task_completion()
  end, {
    nargs = 0,
  })

  vim.api.nvim_create_user_command('KanufoMarkTaskCompleted', function()
    require('kanufo.fileprocessor').mark_task_completed()
  end, {
    nargs = 0,
  })

  vim.api.nvim_create_user_command('KanufoMarkTaskUncompleted', function()
    require('kanufo.fileprocessor').mark_task_uncompleted()
  end, {
    nargs = 0,
  })
  vim.api.nvim_create_user_command('KanufoNewTask', function()
    require('kanufo.fileprocessor').create_new_task()
  end, {
    nargs = 0,
  })
end

return M
