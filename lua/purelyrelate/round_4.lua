local sqlite = require("sqlite")
local util = require("purelyrelate.util")

local M = {}
local ROUND_TITLE = "Round 4: Consonants Only"

local client = {}
local episode

M.state = {
    floats = {},
    sets = {},
    sets_idx = 1,
    question_idx = 1,
    question_over = false,
    points_awarded = false,
}

local create_window_configurations = function()
    local width = vim.o.columns
    local height = vim.o.lines

    local padding_lr = math.floor(width * 0.1)
    local padding_m = math.floor(width * 0.05)

    local clue_width = math.floor((width - padding_lr * 2 - padding_m * 3) / 4)
    local clue_height = math.floor(height * 0.2)

    local answer_width = clue_width * 4 + padding_m * 3
    local answer_height = math.max(math.floor(height * 0.05), 1)

    local padding_tb = math.floor((height - clue_height - answer_height - padding_m) / 2)

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
        relation = {
            relative = "editor",
            width = answer_width,
            height = answer_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr,
            row = padding_tb,
        },
        clue = {
            relative = "editor",
            width = answer_width,
            height = answer_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr,
            row = padding_tb + answer_height + math.floor(padding_m / 2),
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

local get_sets = function(match)
    return sqlite.with_open(client.options.db, function(db)
        local sets = {}
        local relations = db:select("vowel_sets", {
            where = {
                match = match,
            },
            order_by = { asc = "id" },
        })
        for _, relation in ipairs(relations) do
            local clues = db:select("vowel_clues", {
                where = {
                    ["[set]"] = relation.id,
                },
                order_by = { asc = "id" },
            })
            local questions = {
                relation = relation.category,
                questions = {},
            }
            for _, clue in ipairs(clues) do
                table.insert(questions.questions, {
                    clue = clue.clue,
                    answer = clue.solution,
                })
            end
            table.insert(sets, questions)
        end
        return sets
    end)
end

local foreach_float = function(cb)
    for name, float in pairs(M.state.floats) do
        cb(name, float)
    end
end

local show_relation = function()
    local state = M.state
    local set = state.sets[state.sets_idx]
    util.center_text(state.floats.relation, set.relation)
end

local show_question = function()
    local state = M.state
    if state.question_idx == 0 then
        util.clear_text(state.floats.clue)
        return
    end
    local set = state.sets[state.sets_idx]
    local question = set.questions[state.question_idx]
    util.center_text(state.floats.clue, question.clue)
end

local show_answer = function()
    local state = M.state
    if state.question_idx == 0 then
        util.clear_text(state.floats.clue)
        return
    end
    local set = state.sets[state.sets_idx]
    local question = set.questions[state.question_idx]
    util.center_text(state.floats.clue, question.answer)
end

M.set_keymap = function(mode, key, callback)
    foreach_float(function(_, float)
        vim.keymap.set(mode, key, callback, {
            buffer = float.buf,
        })
    end)
end

M.next = function() end

M.continue = function() -- todo better and points awarding
    local state = M.state
    if not state.points_awarded and state.question_idx ~= 0 then
        return
    end
    state.question_idx = state.question_idx + 1
    if state.question_idx > #state.sets[state.sets_idx].questions then
        state.sets_idx = state.sets_idx + 1
        state.question_idx = 0
        if state.sets_idx > #state.sets then
            client.quit()
            return
        end
        show_relation()
    end
    state.question_over = false
    state.points_awarded = false
    show_question()
end

M.buzz_in = function(team)
    local state = M.state
    if team ~= 1 and team ~= 2 then
        return
    end
    if state.question_over or state.question_idx == 0 then
        return
    end
    local team_float = state.floats["points_" .. team]
    local prev_winhighlight = vim.api.nvim_get_option_value("winhighlight", { win = team_float.win })
    vim.api.nvim_set_option_value("winhighlight", "FloatBorder:purelyrelateBuzzBorder", { win = team_float.win })

    local opponent = 3 - team
    state.question_over = true

    local end_all = function()
        update_points()
        show_answer()
        state.points_awarded = true
        vim.api.nvim_set_option_value("winhighlight", prev_winhighlight, { win = team_float.win })
    end

    util.confirm("Team " .. team .. " buzzed in!, is their answer correct?", state.floats.background, function()
        client.state.points[team] = client.state.points[team] + 1
        end_all()
    end, function()
        client.state.points[team] = client.state.points[team] - 1
        util.confirm("Is team " .. opponent .. "'s answer correct?", state.floats.background, function()
            client.state.points[opponent] = client.state.points[opponent] + 1
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
    state.floats.relation = util.create_floating_window(windows.relation)
    state.floats.clue = util.create_floating_window(windows.clue)
    state.floats.round_title = util.create_floating_window(windows.round_title)
    state.floats.points_1 = util.create_floating_window(windows.points_1)
    state.floats.points_2 = util.create_floating_window(windows.points_2)

    -- keymaps
    for mode, mode_mappings in pairs(client.options.mappings) do
        for key, cb in pairs(mode_mappings) do
            M.set_keymap(mode, key, cb)
        end
    end
end

M.start = function()
    local state = M.state
    -- start the game
    update_title()
    update_points()
    state.sets = get_sets(episode)
    state.sets_idx = 1
    state.question_idx = 0
    state.question_over = false
    state.points_awarded = false
    show_relation()
    show_question()

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
            if not vim.api.nvim_win_is_valid(state.floats.background.win) or state.floats.background.win == nil then
                return
            end
            local windows = create_window_configurations()
            foreach_float(function(name, _)
                vim.api.nvim_win_set_config(state.floats[name].win, windows[name])
            end)

            util.center_text(state.floats.round_title, ROUND_TITLE)
            util.center_text(state.floats.relation, state.sets[state.sets_idx].relation)
            if state.points_awarded then
                util.center_text(state.floats.clue, state.sets[state.q_idx].answer)
            else
                util.center_text(state.floats.clue, state.sets[state.q_idx].clue)
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
--                 r = M.reveal,
--                 q = function()
--                     util.teardown(M)
--                 end,
--             },
--         },
--     },
--     state = {
--         points = { 0, 0 },
--         episode = 1,
--         round_num = 4,
--     },
--     next_round = function()
--         client.quit()
--         print("Going to the next round")
--     end,
--     quit = function()
--         util.teardown(M)
--     end,
-- }
-- vim.api.nvim_set_hl(0, "purelyrelateBuzzBorder", {  fg = "white" })
-- M.setup(client)
-- M.start()

return M
