local sqlite = require("sqlite")
local util = require("purelyrelate.util")

local M = {}
local ROUND_TITLE = "Round 1: Relations"
local point_rewards = { 5, 3, 2, 1 }

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
                kind = "connection",
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

local clear_content = function(i)
    local state = M.state
    if i == 5 and state.floats.answer ~= nil then
        vim.api.nvim_buf_set_lines(state.floats.answer.buf, 0, -1, false, {})
        return
    end
    if state.floats["clue_" .. i] == nil then
        return
    end
    vim.api.nvim_buf_set_lines(state.floats["clue_" .. i].buf, 0, -1, false, {})
end

local get_question = function(match, glyph)
    local stuffs = sqlite.with_open(client.options.db, function(db)
        return db:select("connequences", {
            where = {
                kind = "connection",
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
    for i = 1, 5 do
        clear_content(i)
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
    if state.question_over or state.flipped >= 4 or state.flipped <= 0 then
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

M.buzz_in = function(team)
    local state = M.state
    if team ~= 1 and team ~= 2 then
        return
    end
    if state.points_awarded or team ~= state.turn then
        return
    end
    local team_float = state.floats["points_" .. team]
    local prev_winhighlight = vim.api.nvim_get_option_value("winhighlight", { win = team_float.win })
    vim.api.nvim_set_option_value("winhighlight", "FloatBorder:purelyrelateBuzzBorder", { win = team_float.win })

    local opponent = 3 - team
    state.question_over = true

    local end_all = function()
        update_points()
        util.center_text(state.floats.answer, state.answer)
        state.points_awarded = true
        vim.api.nvim_set_option_value("winhighlight", prev_winhighlight, { win = team_float.win })
    end

    util.confirm("Is team " .. team .. "'s answer correct?", state.floats.background, function()
        client.state.points[state.turn] = client.state.points[state.turn] + point_rewards[state.flipped]
        for i = state.flipped + 1, 4 do
            set_clue(i)
        end
        state.flipped = 4
        end_all()
    end, function()
        for i = state.flipped + 1, 4 do
            set_clue(i)
        end
        state.flipped = 4
        move_points_rewarded()
        util.confirm("Is team " .. opponent .. "'s answer correct?", state.floats.background, function()
            client.state.points[opponent] = client.state.points[opponent] + point_rewards[state.flipped]
            end_all()
        end, function()
            end_all()
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
--                 ["`"] = function()
--                     M.buzz_in(1)
--                 end,
--                 ["<BS>"] = function()
--                     M.buzz_in(2)
--                 end,
--                 n = M.next,
--                 c = M.continue,
--                 q = function()
--                     util.teardown(M)
--                 end,
--             },
--         },
--     },
--     state = {
--         points = { 0, 0 },
--         episode = 1,
--         round_num = 1,
--     },
--     hl_ns = vim.api.nvim_create_namespace("purelyrelate"),
--     quit = function()
--         util.teardown(M)
--     end,
-- }
-- vim.api.nvim_set_hl(client.hl_ns, "purelyrelateBuzzBorder", { bg = "white", fg = "black" })
-- M.setup(client)
-- M.start()

return M
