local M = {}

M.DB_URL = "~/Documents/pr/purely-relate.db"

-- stolen from oil.nvim
M.hide_cursor = function()
    vim.api.nvim_set_hl(0, "PurelyrelateHiddenCursor", { nocombine = true, blend = 100 })
    local original_guicursor = vim.go.guicursor
    vim.go.guicursor = "a:PurelyrelateHiddenCursor/PurelyrelateHiddenCursor"

    return function()
        -- HACK: see https://github.com/neovim/neovim/issues/21018
        vim.go.guicursor = "a:"
        vim.cmd.redrawstatus()
        vim.go.guicursor = original_guicursor
    end
end

M.create_floating_window = function(config, enter)
    enter = enter or false

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, enter or false, config)
    vim.api.nvim_set_option_value("filetype", "purelyrelate", { buf = buf })
    -- vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    return { buf = buf, win = win }
end

local create_confirm_window_configuration = function()
    local width = math.floor(vim.o.columns / 2)
    local height = 1
    local col = math.floor((vim.o.columns - width) / 2)
    local row = vim.o.lines - height

    return {
        relative = "editor",
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        col = col,
        row = row,
        zindex = 100,
    }
end

M.get_centered_text = function(lines, width, height)
    height = height or 1
    if height == 1 then
        if #lines > 1 then
            print("Text is too tall to fit in the float")
            return lines
        end
        local padding = string.rep(" ", math.floor((width - #lines[1]) / 2))
        return { padding .. lines[1] }
    end
    -- fit the text to the width
    local fits = false
    while not fits do
        fits = true
        local new_lines = {}
        for i = 1, #lines do
            if #lines[i] > width then
                fits = false
                local line = lines[i]
                local cut_idx = width
                while cut_idx > 0 and line:sub(cut_idx, cut_idx) ~= " " do
                    cut_idx = cut_idx - 1
                end
                if cut_idx == 0 then
                    print("Text is too wide to fit in the float")
                    cut_idx = width
                end
                local first = line:sub(1, cut_idx)
                local second = line:sub(cut_idx + 1)
                table.insert(new_lines, first)
                table.insert(new_lines, second)
            else
                table.insert(new_lines, lines[i])
            end
        end
        lines = new_lines
        if #lines > height then
            print("Text is too tall to fit in the float")
            return lines
        end
    end
    for i = 1, #lines do
        local padding = string.rep(" ", math.floor((width - #lines[i]) / 2))
        lines[i] = padding .. lines[i]
    end
    local v_padding = {}
    for _ = 1, math.floor((height - #lines) / 2) do
        table.insert(v_padding, "")
    end
    lines = vim.list_extend(v_padding, lines)
    return lines
end

M.center_text = function(float, text)
    local lines = vim.split(text, "\n")
    local width = vim.api.nvim_win_get_width(float.win)
    local height = vim.api.nvim_win_get_height(float.win)
    lines = M.get_centered_text(lines, width, height)
    vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, lines)
end

M.confirm = function(prompt, return_float, onyes, onno)
    vim.api.nvim_set_current_win(return_float.win)
    local config = create_confirm_window_configuration()
    local confirm_float = M.create_floating_window(config, true)
    M.center_text(confirm_float, prompt .. " [y] [n]")
    vim.keymap.set("n", "y", function()
        onyes()
        pcall(vim.api.nvim_win_close, confirm_float.win, true)
    end, { buffer = confirm_float.buf, nowait = true })
    vim.keymap.set("n", "n", function()
        onno()
        pcall(vim.api.nvim_win_close, confirm_float.win, true)
    end, { buffer = confirm_float.buf, nowait = true })
end

M.teardown = function(round)
    for _, float in pairs(round.state.floats) do
        pcall(vim.api.nvim_win_close, float.win, true)
    end
    round.state.floats = {}
end

return M
