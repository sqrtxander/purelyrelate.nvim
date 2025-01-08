vim.api.nvim_create_user_command("PurelyRelate", function(opts)
    if opts.fargs[1] == nil then
        print("Provide episode number")
        return
    end
    local episode = tonumber(opts.fargs[1])
    if episode == nil or episode <= 0 or episode > 5 then
        print("Provide a valid episode number i.e. \\in [1,5]")
        return
    end
    require("purelyrelate").start(episode)
end, { nargs = 1 })
