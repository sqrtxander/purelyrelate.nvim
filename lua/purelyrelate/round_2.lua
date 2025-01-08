local sqlite = require("sqlite")
local util = require("purelyrelate.util")

local M = {}
local ROUND_TITLE = "Round 2: Progressions"
local point_rewards = { 5, 3, 2, 1 }

local ascii_qmark = " #### \n##  ##\n    ##\n   ## \n  ##  \n      \n  ##  "
local client
local episode
local available_glyphs = {}

M.state = {
    floats = {},
    clues = {},
    flipped = 1,
    turn = 1,
    question_over = false,
    points_awarded = false,
}

local create_window_configurations = function(point_pos, turn)
    point_pos = point_pos or 1
    turn = turn or 1

    local width = vim.o.columns
    local height = vim.o.lines

    local padding_lr = math.floor(width * 0.1)
    local padding_m = math.floor(width * 0.05)

    local clue_width = math.floor((width - padding_lr * 2 - padding_m * 3) / 4)
    local clue_height = math.floor(height * 0.2)

    local answer_width = clue_width * 4 + padding_m * 3
    local answer_height = math.min(math.floor(height * 0.05), 3)

    local padding_tb = math.floor((height - clue_height - answer_height - padding_m) / 2)

    local team_turn_col = 0
    if turn == 2 then
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
            zindex = 1,
        },
        clue_1 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr,
            row = padding_tb,
            zindex = 2,
        },
        clue_2 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + clue_width + padding_m,
            row = padding_tb,
            zindex = 3,
        },
        clue_3 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_m) * 2,
            row = padding_tb,
            zindex = 4,
        },
        clue_4 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_m) * 3,
            row = padding_tb,
            zindex = 5,
        },
        answer = {
            relative = "editor",
            width = answer_width,
            height = answer_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr,
            row = padding_tb + clue_height + math.floor(padding_m / 2),
            zindex = 6,
        },
        round_title = {
            relative = "editor",
            width = answer_width,
            height = 1,
            style = "minimal",
            border = "rounded",
            col = padding_lr,
            row = 0,
            zindex = 7,
        },
        points_reward = {
            relative = "editor",
            width = clue_width,
            height = 1,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_m) * (point_pos - 1),
            row = padding_tb - 3,
            zindex = 8,
        },
        team_turn = {
            relative = "editor",
            width = 3,
            height = 2,
            style = "minimal",
            border = "rounded",
            col = team_turn_col,
            row = 3,
            zindex = 8,
        },
        points_1 = {
            relative = "editor",
            width = 3,
            height = 1,
            style = "minimal",
            border = "rounded",
            col = 0,
            row = 0,
            zindex = 9,
        },
        points_2 = {
            relative = "editor",
            width = 3,
            height = 1,
            style = "minimal",
            border = "rounded",
            col = width - 5,
            row = 0,
            zindex = 10,
        },
    }
end

local get_glyphs = function()
    local glyphs = sqlite.with_open(client.options.db, function(db)
        return db:select("connequences", {
            select = { "distinct glyph" },
            where = {
                kind = "sequence",
                match = episode,
            },
        })
    end)
    available_glyphs = {}
    for _, g in ipairs(glyphs) do
        table.insert(available_glyphs, g.glyph)
    end
    return available_glyphs
end

local update_points = function()
    local state = M.state
    vim.api.nvim_buf_set_lines(
        state.floats.points_1.buf,
        0,
        -1,
        false,
        { string.format("% 2d", client.state.points[1]) }
    )
    vim.api.nvim_buf_set_lines(
        state.floats.points_2.buf,
        0,
        -1,
        false,
        { string.format("% 2d", client.state.points[2]) }
    )
end

local update_title = function()
    util.center_text(M.state.floats.round_title, ROUND_TITLE)
end

local move_team_turn = function()
    local state = M.state
    local windows = create_window_configurations(state.flipped, state.turn)
    if state.turn == 2 then
        vim.api.nvim_win_set_config(state.floats.team_turn.win, windows.team_turn)
    else
        vim.api.nvim_win_set_config(state.floats.team_turn.win, windows.team_turn)
    end
end

local clear_answer = function()
    vim.api.nvim_buf_set_lines(M.state.floats.answer.buf, 0, -1, false, {})
end

local clear_clue = function(i)
    local state = M.state
    if state.floats["clue_" .. i] == nil then
        return
    end
    vim.api.nvim_buf_set_lines(state.floats["clue_" .. i].buf, 0, -1, false, {})
end

local get_question = function(match, glyph)
    local stuffs = sqlite.with_open(client.options.db, function(db)
        return db:select("connequences", {
            where = {
                kind = "sequence",
                match = match,
                glyph = glyph,
            },
        })
    end)[1]
    return stuffs
end

local set_clue = function(i)
    local state = M.state
    if state.floats["clue_" .. i] == nil then
        return
    end
    util.center_text(state.floats["clue_" .. i], state.clues[i])
end

local choose_question = function()
    local state = M.state
    if #available_glyphs == 0 then
        client.next_round()
        return
    end
    vim.ui.select(available_glyphs, { prompt = "Select a tetromino" }, function(glyph, _)
        if glyph == nil then
            error("Must select a tetromino")
            return
        end
        available_glyphs = vim.tbl_filter(function(t)
            return t ~= glyph
        end, available_glyphs)
        local question = get_question(episode, glyph)
        state.clues = vim.fn.json_decode(question.clues)
        state.answer = question.connection
        set_clue(1)
    end)
end

local move_points_rewarded = function()
    local state = M.state
    local windows = create_window_configurations(state.flipped, state.turn)
    vim.api.nvim_win_set_config(state.floats.points_reward.win, windows.points_reward)
    util.center_text(state.floats.points_reward, "Points: " .. point_rewards[state.flipped])
end

local foreach_float = function(cb)
    for name, float in pairs(M.state.floats) do
        cb(name, float)
    end
end

local reset = function()
    local state = M.state
    for i = 1, 3 do
        clear_clue(i)
    end
    clear_answer()
    local clue_4_height = vim.api.nvim_win_get_height(state.floats.clue_4.win)
    if clue_4_height >= 7 then
        util.center_text(state.floats.clue_4, ascii_qmark)
    else
        util.center_text(state.floats.clue_4, "?")
    end
    state.flipped = 1
    state.question_over = false
    state.points_awarded = false
    move_points_rewarded()
end

local change_team = function()
    local state = M.state
    state.turn = 3 - state.turn
    move_team_turn()
end

M.set_keymap = function(mode, key, callback)
    foreach_float(function(_, float)
        vim.keymap.set(mode, key, callback, {
            buffer = float.buf,
        })
    end)
end

M.next = function()
    local state = M.state
    if state.question_over or state.flipped >= 3 or state.flipped <= 0 then
        return
    end
    state.flipped = state.flipped + 1
    set_clue(state.flipped)
    move_points_rewarded()
end

M.continue = function()
    local state = M.state
    if not state.points_awarded then
        return
    end
    reset()
    change_team()
    choose_question()
end

M.reveal = function()
    local state = M.state
    if state.points_awarded then
        return
    end
    state.question_over = true
    util.confirm("Is the answer correct?", state.floats.background, function()
        client.state.points[state.turn] = client.state.points[state.turn] + point_rewards[state.flipped]
        update_points()
        for i = state.flipped + 1, 4 do
            set_clue(i)
        end
        util.center_text(state.floats.answer, state.answer)
        state.points_awarded = true
    end, function()
        for i = state.flipped + 1, 3 do
            set_clue(i)
        end
        state.flipped = 4
        move_points_rewarded()
        change_team()
        util.confirm("Is the answer correct?", state.floats.background, function()
            client.state.points[state.turn] = client.state.points[state.turn] + point_rewards[state.flipped]
            update_points()
            change_team()
            set_clue(4)
            util.center_text(state.floats.answer, state.answer)
            state.points_awarded = true
        end, function()
            change_team()
            set_clue(4)
            util.center_text(state.floats.answer, state.answer)
            state.points_awarded = true
        end)
    end)
end

M.setup = function(c)
    client = c
    episode = client.state.episode
    local state = M.state

    local windows = create_window_configurations()
    state.floats.background = util.create_floating_window(windows.background, true)
    state.floats.clue_1 = util.create_floating_window(windows.clue_1)
    state.floats.clue_2 = util.create_floating_window(windows.clue_2)
    state.floats.clue_3 = util.create_floating_window(windows.clue_3)
    state.floats.clue_4 = util.create_floating_window(windows.clue_4)
    state.floats.answer = util.create_floating_window(windows.answer)
    state.floats.round_title = util.create_floating_window(windows.round_title)
    state.floats.points_reward = util.create_floating_window(windows.points_reward)
    state.floats.points_1 = util.create_floating_window(windows.points_1)
    state.floats.points_2 = util.create_floating_window(windows.points_2)
    state.floats.team_turn = util.create_floating_window(windows.team_turn)

    -- keymaps
    for mode, mode_mappings in pairs(client.options.mappings) do
        for key, cb in pairs(mode_mappings) do
            M.set_keymap(mode, key, cb)
        end
    end
end

M.start = function()
    vim.api.nvim_buf_set_lines(M.state.floats.team_turn.buf, 0, -1, false, { " ^", " |" })

    available_glyphs = get_glyphs()

    -- local question

    -- start the game
    update_title()
    update_points()
    reset()
    choose_question()

    -- auto commands
    vim.api.nvim_create_autocmd("WinClosed", {
        group = vim.api.nvim_create_augroup("purelyrelate-winclosed", {}),
        callback = function(opts)
            foreach_float(function(_, float)
                if float.buf == opts.buf then
                    client.quit()
                    return
                end
            end)
        end,
    })

    vim.api.nvim_create_autocmd("VimResized", {
        group = vim.api.nvim_create_augroup("purelyrelate-resized", {}),
        callback = function()
            local state = M.state
            if not vim.api.nvim_win_is_valid(state.floats.background.win) or state.floats.background.win == nil then
                return
            end
            local windows = create_window_configurations(state.flipped, state.turn)
            foreach_float(function(name, _)
                vim.api.nvim_win_set_config(state.floats[name].win, windows[name])
            end)

            -- Re-calculates current state contents
            for i = 1, state.flipped do
                set_clue(i)
            end

            util.center_text(state.floats.points_reward, "Points: " .. point_rewards[state.flipped])
            util.center_text(state.floats.round_title, ROUND_TITLE)
            if state.question_over then
                util.center_text(state.floats.answer, state.answer)
            else
                local clue_4_height = vim.api.nvim_win_get_height(state.floats.clue_4.win)
                if clue_4_height >= 7 then
                    util.center_text(state.floats.clue_4, ascii_qmark)
                else
                    util.center_text(state.floats.clue_4, "?")
                end
            end
        end,
    })
end

return M
