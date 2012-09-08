function saveConfig()
    local karma = {}
    for k, v in pairs(_G.karma) do
        table.insert(karma, '"'..v..'"')
    end
    local channels = ""
    for k, v in pairs(_G.channels) do
        local git = {}
        local svn = {}
        for k, r in pairs(v.git or {}) do
            table.insert(git, '"'..r..'"')
        end
        for k, r in pairs(v.svn or {}) do
            table.insert(svn, '"'..r..'"')
        end
        channel = string.format([[
    {
        channel = "%s"
        git = {%s},
        svn = {%s}
    },
]], v.channel, table.concat(git, ", "), table.concat(svn, ", "))
        channels = channels .. channel
    end
    local f = io.open("config.lua", "w")
    if f then
        f:write(([[
_G.config = {
    server = "%s",
    nick = "%s",
    password = "%s",
    owner = "%s",
    username = "%s",
    realname = "%s",
    maxmessagesize = %u,
    gitfolder = "%s",
    svnfolder = "%s"
}

_G.karma = {%s}

_G.channels = {
%s
}
]]):format(
    _G.config.server,
    _G.config.nick,
    _G.config.password,
    _G.config.owner,
    _G.config.username,
    _G.config.realname,
    _G.config.maxmessagesize,
    _G.config.gitfolder or ".",
    _G.config.svnfolder or ".",
    table.concat(karma, ", "),
    channels
))
        f:close()
    end
end


function hasKarma(sender)
    for k, v in pairs(karma) do
        if v == sender then return true end
    end
    return false
end


