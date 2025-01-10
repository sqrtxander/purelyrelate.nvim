local util = require("purelyrelate.util")

local M = {}
local blank_border_hl
local client
local callback

M.state = {
    floats = {},
    pos = { row = 1, col = 1 },
    dims = { width = 3, height = 2 },
    turn = 1,
    selected = false,
}

local floatorder = { "O", "L", "I", "T", "J", "Z" }
local tetrominoes = {
    O = "##\n##",
    L = "# \n# \n##",
    I = "#\n#\n#\n#",
    T = "###\n # ",
    J = " #\n #\n##",
    Z = "## \n ##",
}

local create_window_configurations = function()
    local width = vim.o.columns
    local height = vim.o.lines

    local padding_lr = math.floor(width * 0.1)
    local padding_hm = math.floor(width * 0.05)
    local padding_vm = math.floor(padding_hm / 2)

    local clue_width = math.floor((width - padding_lr * 2 - padding_hm * 3) / 4)
    local clue_height = math.floor((height - padding_vm) * 0.2)

    padding_lr = math.floor((width - clue_width * 3 - padding_hm * 2) / 2)
    local padding_tb = math.floor((height - clue_height * 2 - padding_vm) / 2)

    local title_width = clue_width * 4 + padding_hm * 3
    local title_padding_lr = math.floor((width - title_width) / 2)

    local team_turn_col = 0
    if M.state.turn == 2 then
        team_turn_col = width - 5
    end

    return {
        background = {
            relative = "editor",
            width = width,
            height = height,
            style = "minimal",
            col = 0,
            row = 0,
            zindex = 100,
        },
        glyph_O = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr,
            row = padding_tb,
            zindex = 101,
        },
        glyph_L = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + clue_width + padding_hm,
            row = padding_tb,
            zindex = 101,
        },
        glyph_I = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_hm) * 2,
            row = padding_tb,
            zindex = 101,
        },
        glyph_T = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr,
            row = padding_tb + clue_height + padding_vm,
            zindex = 101,
        },
        glyph_J = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + clue_width + padding_hm,
            row = padding_tb + clue_height + padding_vm,
            zindex = 101,
        },
        glyph_Z = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_hm) * 2,
            row = padding_tb + clue_height + padding_vm,
            zindex = 101,
        },
        round_title = {
            relative = "editor",
            width = title_width,
            height = 1,
            style = "minimal",
            border = "rounded",
            col = title_padding_lr,
            row = 0,
            zindex = 101,
        },
        team_turn = {
            relative = "editor",
            width = 3 + 2,
            height = 2,
            style = "minimal",
            border = "none",
            col = team_turn_col,
            row = 3,
            zindex = 101,
        },
        points_1 = {
            relative = "editor",
            width = 3,
            height = 1,
            style = "minimal",
            border = "rounded",
            col = 0,
            row = 0,
            zindex = 101,
        },
        points_2 = {
            relative = "editor",
            width = 3,
            height = 1,
            style = "minimal",
            border = "rounded",
            col = width - 5,
            row = 0,
            zindex = 101,
        },
    }
end

local update_points = function()
    local state = M.state
    vim.api.nvim_buf_set_lines(
        state.floats.points_1.buf,
        0,
        -1,
        false,
        { string.format("% 2d", client.state.teams[1].points) }
    )
    vim.api.nvim_buf_set_lines(
        state.floats.points_2.buf,
        0,
        -1,
        false,
        { string.format("% 2d", client.state.teams[2].points) }
    )
end

local pos_to_glyph = function(pos)
    local state = M.state
    return floatorder[1 + (pos.col - 1) % state.dims.width + (pos.row - 1) * state.dims.width]
end

local foreach_float = function(cb)
    for name, float in pairs(M.state.floats) do
        cb(name, float)
    end
end

local set_keymap = function(mode, key, cb)
    foreach_float(function(_, float)
        vim.keymap.set(mode, key, cb, {
            buffer = float.buf,
            nowait = true,
        })
    end)
end

local highlight_pos = function(pos, group)
    local state = M.state
    local float = state.floats["glyph_" .. pos_to_glyph(pos)]
    if float == nil then
        return
    end
    vim.api.nvim_set_option_value("winhighlight", group, { win = float.win })
end

local post_move = function(old_pos, new_pos)
    highlight_pos(old_pos, blank_border_hl)
    highlight_pos(new_pos, "FloatBorder:purelyrelateBuzzBorder")
end

local is_valid = function(pos)
    if pos.row < 1 or pos.row > M.state.dims.height then
        return false
    end
    if pos.col < 1 or pos.col > M.state.dims.width then
        return false
    end
    if M.state.floats["glyph_" .. pos_to_glyph(pos)] == nil then
        return false
    end
    return true
end

M.previous = function()
    if M.state.selected then
        return
    end
    local state = M.state
    local old_pos = { row = state.pos.row, col = state.pos.col }
    state.pos.col = state.pos.col - 1
    if state.pos.col < 1 then
        state.pos.col = state.dims.width
        state.pos.row = state.pos.row - 1
    end
    if state.pos.row < 1 then
        state.pos.row = state.dims.height
    end
    while not is_valid(state.pos) do
        state.pos.col = state.pos.col - 1
        if state.pos.col < 1 then
            state.pos.col = state.dims.width
            state.pos.row = state.pos.row - 1
        end
        if state.pos.row < 1 then
            state.pos.row = state.dims.height
        end
    end
    post_move(old_pos, state.pos)
end

M.next = function()
    if M.state.selected then
        return
    end
    local state = M.state
    local old_pos = { row = state.pos.row, col = state.pos.col }
    state.pos.col = state.pos.col + 1
    if state.pos.col > state.dims.width then
        state.pos.col = 1
        state.pos.row = state.pos.row + 1
    end
    if state.pos.row > state.dims.height then
        state.pos.row = 1
    end
    while not is_valid(state.pos) do
        state.pos.col = state.pos.col + 1
        if state.pos.col > state.dims.width then
            state.pos.col = 1
            state.pos.row = state.pos.row + 1
        end
        if state.pos.row > state.dims.height then
            state.pos.row = 1
        end
    end
    post_move(old_pos, state.pos)
end

M.down = function()
    if M.state.selected then
        return
    end
    local state = M.state
    if state.pos.row >= state.dims.height then
        M.next()
        return
    end
    local old_pos = { row = state.pos.row, col = state.pos.col }
    state.pos.row = state.pos.row + 1
    while not is_valid(state.pos) do
        state.pos.row = state.pos.row + 1
        if state.pos.row > state.dims.height then
            state.pos.row = old_pos.row
            M.next()
            return
        end
    end
    post_move(old_pos, state.pos)
end

M.up = function()
    if M.state.selected then
        return
    end
    local state = M.state
    if state.pos.row <= 1 then
        M.previous()
        return
    end
    local old_pos = { row = state.pos.row, col = state.pos.col }
    state.pos.row = state.pos.row - 1
    while not is_valid(state.pos) do
        state.pos.row = state.pos.row - 1
        if state.pos.row < 1 then
            state.pos.row = old_pos.row
            M.previous()
            return
        end
    end
    post_move(old_pos, state.pos)
end

M.left = function()
    if M.state.selected then
        return
    end
    local state = M.state
    if state.pos.col <= 1 then
        M.previous()
        return
    end
    local old_pos = { row = state.pos.row, col = state.pos.col }
    state.pos.col = state.pos.col - 1
    while not is_valid(state.pos) do
        state.pos.col = state.pos.col - 1
        if state.pos.col < 1 then
            state.pos.col = old_pos.col
            M.previous()
            return
        end
    end
    post_move(old_pos, state.pos)
end

M.right = function()
    if M.state.selected then
        return
    end
    local state = M.state
    if state.pos.col >= state.dims.width then
        M.next()
        return
    end
    local old_pos = { row = state.pos.row, col = state.pos.col }
    state.pos.col = state.pos.col + 1
    while not is_valid(state.pos) do
        state.pos.col = state.pos.col + 1
        if state.pos.col > state.dims.width then
            state.pos.col = old_pos.col
            M.next()
            return
        end
    end
    post_move(old_pos, state.pos)
end

M.select = function()
    if M.state.selected then
        return
    end
    local state = M.state
    local glyph = pos_to_glyph(state.pos)
    state.selected = true
    callback(glyph)
    util.teardown(M)
end

M.setup = function(c, available_tetrominoes, callb)
    if #available_tetrominoes == 0 then
        error("No tetrominoes available")
        return
    end
    local state = M.state
    state.selected = false
    client = c
    callback = callb
    state.turn = client.round.state.turn
    local windows = create_window_configurations()
    state.floats.background = util.create_floating_window(windows.background, true)
    state.floats.round_title = util.create_floating_window(windows.round_title)
    state.floats.team_turn = util.create_floating_window(windows.team_turn)
    state.floats.points_1 = util.create_floating_window(windows.points_1)
    state.floats.points_2 = util.create_floating_window(windows.points_2)

    for _, glyph in ipairs(available_tetrominoes) do
        local str = "glyph_" .. glyph
        state.floats[str] = util.create_floating_window(windows[str])
        util.center_text(state.floats[str], tetrominoes[glyph])
    end

    update_points()
    util.center_text(M.state.floats.team_turn, "^\n|")

    util.center_text(state.floats.round_title, client.state.teams[state.turn].name .. ", please choose a tetromino")
    blank_border_hl = vim.api.nvim_get_option_value("winhighlight", { win = state.floats.round_title.win })

    state.pos = { row = 1, col = 1 }
    while not is_valid(state.pos) do
        M.next()
    end
    highlight_pos(state.pos, "FloatBorder:purelyrelateBuzzBorder")

    -- keymaps
    for mode, mode_mappings in pairs(client.options.mappings) do
        for key, cb in pairs(mode_mappings) do
            set_keymap(mode, key, cb)
        end
    end

    -- autocmds
    vim.api.nvim_create_autocmd("WinClosed", {
        group = client.augroup,
        callback = function(opts)
            foreach_float(function(_, float)
                if float.buf == opts.buf then
                    util.teardown(M)
                    return
                end
            end)
        end,
    })

    vim.api.nvim_create_autocmd("VimResized", {
        group = client.augroup,
        callback = function()
            if
                state.floats.background == nil
                or not vim.api.nvim_win_is_valid(state.floats.background.win)
                or state.floats.background.win == nil
            then
                return
            end
            windows = create_window_configurations()
            foreach_float(function(name, _)
                vim.api.nvim_win_set_config(state.floats[name].win, windows[name])
            end)

            for _, glyph in ipairs(available_tetrominoes) do
                local str = "glyph_" .. glyph
                if state.floats[str] ~= nil then
                    util.center_text(state.floats[str], tetrominoes[glyph])
                end
            end

            -- Re-calculates current state contents
            util.center_text(
                state.floats.round_title,
                client.state.teams[state.turn].name .. ", please choose a tetromino"
            )
            if state.question_over then
                util.center_text(state.floats.answer, state.answer)
            end
        end,
    })
end

-- debug
-- client = {
--     options = {
--         db = "~/Documents/pr/purely-relate.db",
--         mappings = {
--             n = {
--                 ["<space>"] = M.select,
--                 k = M.up,
--                 j = M.down,
--                 h = M.left,
--                 l = M.right,
--                 n = M.next,
--                 p = M.previous,
--                 c = M.continue,
--                 r = M.reveal,
--                 q = function()
--                     util.teardown(M)
--                 end,
--             },
--         },
--     },
--     augroup = vim.api.nvim_create_augroup("purelyrelate_glyph_selector", {}),
--     state = {
--         points = { 5, 2 },
--         episode = 1,
--         round_num = 1,
--     },
--     round = {
--         state = {
--             turn = 1,
--         },
--     },
--     next_round = function()
--         client.quit()
--         print("Going to the next round")
--     end,
--     quit = function()
--         util.teardown(M)
--     end,
-- }
-- vim.api.nvim_set_hl(0, "purelyrelateBuzzBorder", { fg = "#ffffff" })
-- M.setup(client, { "O", "Z" }, function(glyph)
--     print("Selected " .. glyph)
-- end)

return M
