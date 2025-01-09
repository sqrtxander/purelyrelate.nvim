local util = require("purelyrelate.util")
local glyph_selector_6 = require("purelyrelate.glyph_selector_6")
local M = {}

M.options = { db = nil, mappings = {} }
M.state = {
    episode = 1,
    round_num = 1,
    start_team = 1,
    points = { 0, 0 },
}
M.round = {}

local get_round = function(round_num)
    if round_num <= 0 or round_num > 4 then
        error("PurelyRelate: invalid round number: " .. round_num)
        return
    end
    local success, round = pcall(require, "purelyrelate.round_" .. round_num)
    if success then
        round.setup(M)
        return round
    else
        error("PurelyRelate: failed to load round", round_num)
        return nil
    end
end

M.next = function()
    pcall(M.round.next)
    pcall(glyph_selector_6.next)
end

M.previous = function()
    pcall(M.round.previous)
    pcall(glyph_selector_6.previous)
end

M.team_1_buzz = function()
    pcall(M.round.buzz_in, 1)
end

M.team_2_buzz = function()
    pcall(M.round.buzz_in, 2)
end

M.continue = function()
    pcall(M.round.continue)
end

M.reveal = function()
    pcall(M.round.reveal)
end

M.left = function()
    pcall(M.round.left)
    pcall(glyph_selector_6.left)
end

M.down = function()
    pcall(M.round.down)
    pcall(glyph_selector_6.down)
end

M.up = function()
    pcall(M.round.up)
    pcall(glyph_selector_6.up)
end

M.right = function()
    pcall(M.round.right)
    pcall(glyph_selector_6.right)
end

M.select = function()
    pcall(M.round.toggle, M.round.state.pos)
    pcall(glyph_selector_6.select)
end

M.quit = function() end

local quit = function()
    pcall(require("purelyrelate.util").teardown, M.round)
end

M.setup = function(opts)
    opts = opts or {}

    -- db
    if opts.db == nil then
        error("PurelyRelate: db is required")
        return
    end

    -- mappings
    opts.mappings = opts.mappings or {}
    opts.mappings.i = opts.mappings.i or {}
    opts.mappings.n = opts.mappings.n or {}

    opts.mappings.n["`"] = opts.mappings.n["`"] or M.team_1_buzz
    opts.mappings.n["<BS>"] = opts.mappings.n["<BS>"] or M.team_2_buzz
    opts.mappings.n.n = opts.mappings.n.n or M.next
    opts.mappings.n.c = opts.mappings.n.c or M.continue
    opts.mappings.n.q = opts.mappings.n.q or function()
        M.quit()
    end
    opts.mappings.n.r = opts.mappings.n.r or M.reveal
    opts.mappings.n.h = opts.mappings.n.h or M.left
    opts.mappings.n.j = opts.mappings.n.j or M.down
    opts.mappings.n.k = opts.mappings.n.k or M.up
    opts.mappings.n.l = opts.mappings.n.l or M.right
    opts.mappings.n["<space>"] = opts.mappings.n["<space>"] or M.select

    opts.mappings.v = opts.mappings.v or {}
    opts.mappings.x = opts.mappings.x or {}

    M.options = opts

    vim.api.nvim_create_augroup("purelyrelate", {})

    -- highlight groups
    vim.api.nvim_set_hl(0, "purelyrelateBuzzBorder", { fg = "#ffffff" })
    vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup1", { fg = "#c81003" })
    vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup1Hover", { fg = "#fc554a" })
    vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup2", { fg = "#32cd32" })
    vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup2Hover", { fg = "#84e184" })
    vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup3", { fg = "#0892d0" })
    vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup3Hover", { fg = "#55c6f8" })
    vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup4", { fg = "#ffc40c" })
    vim.api.nvim_set_hl(0, "purelyrelateSurfaceGroup4Hover", { fg = "#ffdc6d" })
end

M.start = function(episode)
    M.state.round_num = 1
    M.state.episode = episode
    M.state.start_team = math.random(1, 2) -- randomise start team
    M.round = get_round(M.state.round_num)
    local show_cursor = util.hide_cursor()
    M.quit = function()
        quit()
        show_cursor()
    end
    M.round.start()
end

M.next_round = function()
    M.state.round_num = M.state.round_num + 1
    if M.state.round_num == 5 then
        M.state.round_num = 1
    end
    util.teardown(M.round)
    local success, round = pcall(get_round, M.state.round_num)
    M.round = round
    if not success then
        error("PurelyRelate: failed to load round " .. M.state.round_num)
        return
    end
    M.round.start()
end

return M
