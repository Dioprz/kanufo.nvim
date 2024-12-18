local M = {}

-- Helper function to check if a line starts with a completed task marker
local function is_completed_task(line)
  return string.match(line, '^%s*-%s*%[x%]') ~= nil
end

-- Helper function to check if a line is a task title
local function is_task_title(line)
  return string.match(line, '^%s*-%s*%[') ~= nil
end

-- Helper function to trim leading and trailing empty lines
local function trim_empty_lines(lines)
  local start, finish = 1, #lines
  while start <= #lines and lines[start] == '' do
    start = start + 1
  end
  while finish > start and lines[finish] == '' do
    finish = finish - 1
  end
  return { unpack(lines, start, finish) }
end

-- Helper function to extract the task title and description
local function extract_task_title_and_description(lines)
  local task_title = lines[1]
  local description = {}

  for i = 2, #lines do
    if is_task_title(lines[i]) then
      break
    end
    table.insert(description, lines[i])
  end

  description = trim_empty_lines(description)

  return task_title, description
end

-- Function to process a file and separate completed tasks
function M.process_file(file_path)
  local completed_tasks = {}
  local remaining_tasks = {}

  local current_task = {}
  for line in io.lines(file_path) do
    if is_task_title(line) and #current_task > 0 then
      local task_title, description = extract_task_title_and_description(current_task)
      if is_completed_task(task_title) then
        table.insert(completed_tasks, { task_title, description })
      else
        table.insert(remaining_tasks, { task_title, description })
      end
      current_task = {}
    end
    table.insert(current_task, line)
  end

  -- Process the last task if exists
  if #current_task > 0 then
    local task_title, description = extract_task_title_and_description(current_task)
    if is_completed_task(task_title) then
      table.insert(completed_tasks, { task_title, description })
    else
      table.insert(remaining_tasks, { task_title, description })
    end
  end

  return completed_tasks, remaining_tasks
end

-- Function to write tasks to a file
local function write_tasks_to_file(file_path, tasks)
  local file = io.open(file_path, 'a')
  if file then
    for _, task in ipairs(tasks) do
      file:write(task[1] .. '\n')
      for _, line in ipairs(task[2]) do
        file:write(line .. '\n')
      end
      file:write('\n') -- Add a single newline between tasks
    end
    file:close()
  end
end

-- Function to handle file saving
function M.on_file_save(file_path)
  local completed_tasks, remaining_tasks = M.process_file(file_path)

  -- Write remaining tasks back to the original file
  local file = io.open(file_path, 'w')
  if file then
    for _, task in ipairs(remaining_tasks) do
      file:write(task[1] .. '\n')
      for _, line in ipairs(task[2]) do
        file:write(line .. '\n')
      end
      file:write('\n') -- Add a single newline between tasks
    end
    file:close()
  end

  -- Write completed tasks to the "_done" file
  local done_file_path = file_path:gsub('%.typ$', '') .. '_done.typ'
  write_tasks_to_file(done_file_path, completed_tasks)
end

-- Helper function to find the nearest task title line
local function find_nearest_task_title()
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  for i = current_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
    if is_task_title(line) then
      return i, line
    end
  end
  return nil, nil
end

-- Function to toggle task completion
function M.toggle_task_completion()
  local task_line, task_content = find_nearest_task_title()
  if not task_line then
    vim.api.nvim_echo({ { 'No task found', 'WarningMsg' } }, false, {})
    return
  end

  local new_line
  if is_completed_task(task_content) then
    new_line = task_content:gsub('%[x%]', '[ ]')
  else
    new_line = task_content:gsub('%[ %]', '[x]')
  end

  vim.api.nvim_buf_set_lines(0, task_line - 1, task_line, false, { new_line })
end

-- Function to mark task as completed
function M.mark_task_completed()
  local task_line, task_content = find_nearest_task_title()
  if not task_line then
    vim.api.nvim_echo({ { 'No task found', 'WarningMsg' } }, false, {})
    return
  end

  if not is_completed_task(task_content) then
    local new_line = task_content:gsub('%[ %]', '[x]')
    vim.api.nvim_buf_set_lines(0, task_line - 1, task_line, false, { new_line })
  end
end

-- Function to mark task as uncompleted
function M.mark_task_uncompleted()
  local task_line, task_content = find_nearest_task_title()
  if not task_line then
    vim.api.nvim_echo({ { 'No task found', 'WarningMsg' } }, false, {})
    return
  end

  if is_completed_task(task_content) then
    local new_line = task_content:gsub('%[x%]', '[ ]')
    vim.api.nvim_buf_set_lines(0, task_line - 1, task_line, false, { new_line })
  end
end

-- Function to create a new task at the current line
function M.create_new_task()
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local new_task = '- [ ] '

  -- Insert the new task at the current line
  vim.api.nvim_buf_set_lines(0, current_line - 1, current_line - 1, false, { new_task })

  -- Move the cursor to the end of the new task
  vim.api.nvim_win_set_cursor(0, { current_line, #new_task })

  -- Enter insert mode
  vim.cmd('startinsert!')
end

return M
