local util = require("purelyrelate.util")
local M = {}

M.options = { db = nil, mappings = {} }
M.state = { episode = 1, round_num = 1, points = { 0, 0 } }
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
end

M.reveal = function()
    pcall(M.round.reveal)
end

M.continue = function()
    pcall(M.round.continue)
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
    opts.mappings.n = opts.mappings.n
        or {
            n = M.next,
            r = M.reveal,
            c = M.continue,
            q = function()
                M.quit()
            end,
        }
    opts.mappings.v = opts.mappings.v or {}
    opts.mappings.x = opts.mappings.x or {}

    M.options = opts
end

M.start = function(episode)
    M.state.round_num = 1
    M.round = get_round(M.state.round_num)
    M.state.episode = episode
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
    local old_round = M.round
    local success, round = pcall(get_round, M.state.round_num)
    M.round = round
    if not success then
        util.teardown(old_round)
        error("PurelyRelate: failed to load round " .. M.state.round_num)
        return
    end
    M.round.start()
    util.teardown(old_round)
end

return M
