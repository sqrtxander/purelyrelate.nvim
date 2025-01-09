local sqlite = require("sqlite")
local util = require("purelyrelate.util")

local M = {}
local ROUND_TITLE = "Round 3: Relating Surfaces"
local client
local episode
local available_glyphs = {}
local blank_border_hl

M.state = {
    floats = {},
    surface = {},
    selected = {},
    pos = 1,
    points = 0,
    groups_found = 0,
    lives = 3,
    turn = 1,
    answer_upto = 0,
    playing = false,
    question_over = false,
    points_awarded = false,
}

local create_window_configurations = function()
    local width = vim.o.columns
    local height = vim.o.lines

    local padding_lr = math.floor(width * 0.1)
    local padding_hm = math.floor(width * 0.05)

    local padding_tb = math.floor(height * 0.2)
    local padding_vm = math.floor(padding_hm / 2)

    local clue_width = math.floor((width - padding_lr * 2 - padding_hm * 3) / 4)
    local answer_width = clue_width * 4 + padding_hm * 3
    local answer_height = math.max(math.floor(height * 0.05), 1)
    local clue_height = math.floor((height - padding_tb * 2 - padding_vm * 3 - answer_height - 1) / 4)

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
            col = padding_lr + clue_width + padding_hm,
            row = padding_tb,
            zindex = 3,
        },
        clue_3 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_hm) * 2,
            row = padding_tb,
            zindex = 4,
        },
        clue_4 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_hm) * 3,
            row = padding_tb,
            zindex = 5,
        },
        clue_5 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr,
            row = padding_tb + clue_height + padding_vm,
            zindex = 2,
        },
        clue_6 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + clue_width + padding_hm,
            row = padding_tb + clue_height + padding_vm,
            zindex = 3,
        },
        clue_7 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_hm) * 2,
            row = padding_tb + clue_height + padding_vm,
            zindex = 4,
        },
        clue_8 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_hm) * 3,
            row = padding_tb + clue_height + padding_vm,
            zindex = 5,
        },
        clue_9 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr,
            row = padding_tb + (clue_height + padding_vm) * 2,
            zindex = 2,
        },
        clue_10 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + clue_width + padding_hm,
            row = padding_tb + (clue_height + padding_vm) * 2,
            zindex = 3,
        },
        clue_11 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_hm) * 2,
            row = padding_tb + (clue_height + padding_vm) * 2,
            zindex = 4,
        },
        clue_12 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_hm) * 3,
            row = padding_tb + (clue_height + padding_vm) * 2,
            zindex = 5,
        },
        clue_13 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr,
            row = padding_tb + (clue_height + padding_vm) * 3,
            zindex = 2,
        },
        clue_14 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + clue_width + padding_hm,
            row = padding_tb + (clue_height + padding_vm) * 3,
            zindex = 3,
        },
        clue_15 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_hm) * 2,
            row = padding_tb + (clue_height + padding_vm) * 3,
            zindex = 4,
        },
        clue_16 = {
            relative = "editor",
            width = clue_width,
            height = clue_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr + (clue_width + padding_hm) * 3,
            row = padding_tb + (clue_height + padding_vm) * 3,
            zindex = 5,
        },
        lives = {
            relative = "editor",
            width = 9,
            height = 1,
            style = "minimal",
            border = "none",
            col = padding_lr,
            row = padding_tb + (clue_height + padding_vm) * 4,
            zindex = 6,
        },
        answer = {
            relative = "editor",
            width = answer_width,
            height = answer_height,
            style = "minimal",
            border = "rounded",
            col = padding_lr,
            row = padding_tb + (clue_height + padding_vm) * 4 + 1,
            zindex = 7,
        },
        round_title = {
            relative = "editor",
            width = answer_width,
            height = 1,
            style = "minimal",
            border = "rounded",
            col = padding_lr,
            row = 0,
            zindex = 8,
        },
        group_pointer = {
            relative = "editor",
            width = 2,
            height = clue_height,
            style = "minimal",
            border = "none",
            col = padding_lr - 2,
            row = padding_tb + (clue_height + padding_vm) * (M.state.answer_upto - 1) + 1,
            zindex = 9,
        },
    }
end

local get_glyphs = function()
    local glyphs = sqlite.with_open(client.options.db, function(db)
        return db:select("walls", {
            select = { "distinct glyph" },
            where = {
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

local get_surface = function(glyph)
    return sqlite.with_open(client.options.db, function(db)
        local wall_id = db:select("walls", {
            where = {
                match = episode,
                glyph = glyph,
            },
        })[1].id
        local groups = db:select("wall_groups", {
            where = {
                wall = wall_id,
            },
        })
        local surface = {}
        for _, busy_group in ipairs(groups) do
            local group = {}
            group.id = busy_group.id
            group.connection = busy_group.connection
            local clues = vim.fn.json_decode(busy_group.clues)
            group.clues = clues
            table.insert(surface, group)
        end
        return surface
    end)
end

local shuffle = function(surface)
    for i = #surface, 2, -1 do
        local j = math.random(i)
        surface[i], surface[j] = surface[j], surface[i]
    end
end

local set_clue = function(pos)
    local state = M.state
    if pos == nil or pos <= 0 or pos > #state.surface then
        return
    end
    local clue = state.surface[pos].clue
    util.center_text(state.floats["clue_" .. pos], clue)
end

local choose_surface = function()
    local state = M.state
    if #available_glyphs == 0 then
        client.next_round()
        return
    end
    vim.ui.select(available_glyphs, { prompt = "Select a tetromino" }, function(glyph, _)
        if glyph == nil then
            print("Must select a tetromino")
            return
        end
        available_glyphs = vim.tbl_filter(function(t)
            return t ~= glyph
        end, available_glyphs)
        state.surface = {}
        local question = get_surface(glyph)
        for _, group in ipairs(question) do
            for _, clue in ipairs(group.clues) do
                table.insert(state.surface, {
                    clue = clue,
                    id = group.id,
                    answer = group.connection,
                    solved = false,
                })
            end
        end
        shuffle(state.surface)
        for i = 1, #state.surface do
            set_clue(i)
        end
        state.playing = true
    end)
end

local show_pointer = function()
    local state = M.state
    local float = state.floats.group_pointer
    util.center_text(float, "->")
end

local is_group = function()
    local state = M.state
    local group = {}
    for pos, _ in pairs(state.selected) do
        table.insert(group, state.surface[pos].id)
    end
    if #group ~= 4 then
        return false
    end
    local first = group[1]
    for _, g in ipairs(group) do
        if g ~= first then
            return false
        end
    end
    return true
end

local update_title = function()
    util.center_text(M.state.floats.round_title, ROUND_TITLE)
end

local foreach_float = function(cb)
    for name, float in pairs(M.state.floats) do
        cb(name, float)
    end
end

local change_team = function()
    local state = M.state
    state.turn = 3 - state.turn
end

local show_lives = function()
    local state = M.state
    -- repeat text
    local lives = string.rep("<3 ", state.lives)
    vim.api.nvim_buf_set_lines(state.floats.lives.buf, 0, -1, false, { lives })
end

local is_over = function()
    local state = M.state
    return state.groups_found == 4 or state.lives == 0
end

local is_hovering = function(pos)
    local state = M.state
    return state.pos == pos and not is_over()
end

local highlight_pos = function(pos, group)
    local state = M.state
    local float = state.floats["clue_" .. pos]
    if float == nil then
        return
    end
    if group == nil then
        if state.selected[pos] then
            if is_hovering(pos) then
                group = "purelyrelateSurfaceGroup" .. state.groups_found + 1 .. "Hover"
            else
                group = "purelyrelateSurfaceGroup" .. state.groups_found + 1
            end
        else
            if is_hovering(pos) then
                group = "purelyrelateBuzzBorder"
            else
                vim.api.nvim_set_option_value("winhighlight", blank_border_hl, { win = float.win })
                return
            end
        end
    end
    vim.api.nvim_set_option_value("winhighlight", "FloatBorder:" .. group, { win = float.win })
end

local post_move = function(old_pos, new_pos)
    highlight_pos(new_pos)
    highlight_pos(old_pos)
end

local reset = function()
    local state = M.state
    state.selected = {}
    state.playing = false
    state.pos = 1
    state.groups_found = 0
    state.lives = 3
    state.answer_upto = 0
    state.question_over = false
    state.points_awarded = false

    util.clear_text(state.floats.lives)
    util.clear_text(state.floats.answer)
    util.clear_text(state.floats.group_pointer)

    for i = 1, 16 do
        util.clear_text(state.floats["clue_" .. i])
        highlight_pos(i)
    end
end

local manage_group
manage_group = function()
    local state = M.state
    for pos, _ in pairs(state.selected) do
        state.surface[pos].solved = true
    end
    local idx = state.groups_found * 4 + 1
    local selected = {}
    for pos, _ in pairs(state.selected) do
        table.insert(selected, pos)
    end
    state.selected = {}

    table.sort(selected)

    for _, pos in ipairs(selected) do
        highlight_pos(pos)
        state.surface[pos], state.surface[idx] = state.surface[idx], state.surface[pos]
        idx = idx + 1
    end

    for i = 1, #state.surface do
        set_clue(i)
    end

    for i = state.groups_found * 4 + 1, state.groups_found * 4 + 4 do
        highlight_pos(i, "purelyrelateSurfaceGroup" .. state.groups_found + 1)
    end
    if state.pos <= state.groups_found * 4 + 4 then
        M.down()
        highlight_pos(state.pos - 4, "purelyrelateSurfaceGroup" .. state.groups_found + 1)
    end

    state.groups_found = state.groups_found + 1

    if state.groups_found == 2 then
        show_lives()
    end

    if state.groups_found == 3 then
        for pos = 13, 16 do
            state.surface[pos].solved = true
            highlight_pos(pos, "purelyrelateSurfaceGroup4")
        end
        state.groups_found = 4
        state.playing = false
        state.question_over = true
    end
end

M.set_keymap = function(mode, key, callback)
    foreach_float(function(_, float)
        vim.keymap.set(mode, key, callback, {
            buffer = float.buf,
            nowait = true,
        })
    end)
end

M.toggle = function(pos)
    local state = M.state
    if not state.playing then
        return
    end
    if state.question_over then
        return
    end
    if pos <= state.groups_found * 4 then
        return
    end
    if state.selected[pos] then
        state.selected[pos] = nil
        highlight_pos(pos)
        return
    end

    state.selected[pos] = true
    if is_hovering(pos) then
        highlight_pos(pos)
    else
        highlight_pos(pos)
    end

    if vim.tbl_count(state.selected) ~= 4 then
        return
    end

    if is_group() then
        manage_group()
        return
    end

    if state.groups_found >= 2 then
        state.lives = state.lives - 1
        show_lives()
        if state.lives == 0 then
            state.playing = false
            state.question_over = true
            return vim.defer_fn(function()
                for p, _ in pairs(state.selected) do
                    state.selected[p] = nil
                    highlight_pos(p)
                end
            end, 500)
        end
    end
    state.playing = false
    vim.defer_fn(function()
        for p, _ in pairs(state.selected) do
            state.selected[p] = nil
            highlight_pos(p)
        end
        state.playing = true
    end, 500)
end

M.up = function()
    local state = M.state
    if is_over() or state.pos <= state.groups_found * 4 + 4 then
        return
    end
    state.pos = state.pos - 4

    post_move(state.pos + 4, state.pos)
end

M.down = function()
    local state = M.state
    if is_over() or state.pos > #state.surface - 4 then
        return
    end
    state.pos = state.pos + 4

    post_move(state.pos - 4, state.pos)
end

M.left = function()
    local state = M.state
    if is_over() or state.pos % 4 == 1 then
        return
    end
    state.pos = state.pos - 1

    post_move(state.pos + 1, state.pos)
end

M.right = function()
    local state = M.state
    if is_over() or state.pos % 4 == 0 then
        return
    end
    state.pos = state.pos + 1

    post_move(state.pos - 1, state.pos)
end

M.next = function()
    local state = M.state
    if not state.question_over or state.points_awarded then
        return
    end
    if state.answer_upto >= state.groups_found then
        return
    end

    util.clear_text(state.floats.answer)
    if state.answer_upto == 0 then
        state.points = state.groups_found
        show_pointer()
    end

    state.answer_upto = state.answer_upto + 1

    local windows = create_window_configurations()
    vim.api.nvim_win_set_config(state.floats.group_pointer.win, windows.group_pointer)

    local answer = state.surface[state.answer_upto * 4].answer
    local end_all = function()
        util.center_text(state.floats.answer, answer)
        if state.answer_upto == 4 then
            state.points_awarded = true
            return
        end
    end
    util.confirm("Is team " .. state.turn .. "'s answer correct?", state.floats.background, function()
        state.points = state.points + 1
        end_all()
    end, function()
        end_all()
    end)
end

M.continue = function()
    local state = M.state
    if not state.points_awarded then
        return
    end
    if state.points == 8 then
        state.points = 10
    end
    client.state.points[state.turn] = client.state.points[state.turn] + state.points

    change_team()
    reset()
    choose_surface()
end

M.reveal = function() -- solve the surface
    local state = M.state
    if not state.question_over then
        return
    end
    if state.answer_upto < state.groups_found then
        return
    end
    while state.groups_found < 4 do
        local idx = state.groups_found * 4 + 1
        local group_id = state.surface[idx].id
        state.selected = { [idx] = true }
        for pos = idx + 1, 16 do
            if state.surface[pos].id == group_id then
                state.selected[pos] = true
            end
            if vim.tbl_count(state.selected) == 4 then
                break
            end
        end
        manage_group()
    end
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
    state.floats.clue_5 = util.create_floating_window(windows.clue_5)
    state.floats.clue_6 = util.create_floating_window(windows.clue_6)
    state.floats.clue_7 = util.create_floating_window(windows.clue_7)
    state.floats.clue_8 = util.create_floating_window(windows.clue_8)
    state.floats.clue_9 = util.create_floating_window(windows.clue_9)
    state.floats.clue_10 = util.create_floating_window(windows.clue_10)
    state.floats.clue_11 = util.create_floating_window(windows.clue_11)
    state.floats.clue_12 = util.create_floating_window(windows.clue_12)
    state.floats.clue_13 = util.create_floating_window(windows.clue_13)
    state.floats.clue_14 = util.create_floating_window(windows.clue_14)
    state.floats.clue_15 = util.create_floating_window(windows.clue_15)
    state.floats.clue_16 = util.create_floating_window(windows.clue_16)
    state.floats.lives = util.create_floating_window(windows.lives)
    state.floats.answer = util.create_floating_window(windows.answer)
    state.floats.round_title = util.create_floating_window(windows.round_title)
    state.floats.group_pointer = util.create_floating_window(windows.group_pointer)

    state.turn = 3 - client.state.start_team

    blank_border_hl = vim.api.nvim_get_option_value("winhighlight", { win = state.floats.clue_1.win })
    -- keymaps
    for mode, mode_mappings in pairs(client.options.mappings) do
        for key, cb in pairs(mode_mappings) do
            M.set_keymap(mode, key, cb)
        end
    end

    available_glyphs = get_glyphs()
end

M.start = function()
    -- start the game
    update_title()
    reset()
    choose_surface()

    -- auto commands
    vim.api.nvim_create_autocmd("WinClosed", {
        group = client.augroup,
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
        group = client.augroup,
        callback = function()
            local state = M.state
            if not vim.api.nvim_win_is_valid(state.floats.background.win) or state.floats.background.win == nil then
                return
            end
            local windows = create_window_configurations()
            foreach_float(function(name, _)
                vim.api.nvim_win_set_config(state.floats[name].win, windows[name])
            end)

            util.center_text(state.floats.round_title, ROUND_TITLE)
            for i = 1, #state.surface do
                set_clue(i)
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
--                 ["<space>"] = function()
--                     M.toggle(M.state.pos)
--                 end,
--                 ["k"] = M.up,
--                 ["j"] = M.down,
--                 ["h"] = M.left,
--                 ["l"] = M.right,
--                 n = M.next,
--                 c = M.continue,
--                 r = M.reveal,
--                 q = function()
--                     util.teardown(M)
--                 end,
--             },
--         },
--     },
--     augroup = vim.api.nvim_create_augroup("purelyrelate_round_3", {}),
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
-- vim.api.nvim_set_hl(0, "purelyrelateBuzzBorder", { fg = "#ffffff" })
-- vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup1", { fg = "#c81003" })
-- vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup1Hover", { fg = "#fc554a" })
-- vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup2", { fg = "#32cd32" })
-- vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup2Hover", { fg = "#84e184" })
-- vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup3", { fg = "#0892d0" })
-- vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup3Hover", { fg = "#55c6f8" })
-- vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup4", { fg = "#ffc40c" })
-- vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup4Hover", { fg = "#ffdc6d" })
-- M.setup(client)
-- M.start()

return M
