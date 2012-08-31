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

function updateSvn(entry)
    if entry.svn then
        if type(entry.svn) == "string" then
            entry.svn = {entry.svn}
        end
        entry.svnRepos = entry.svnRepos or {}
        for k, repo in pairs(entry.svn) do
            if not repo:match("https?://") then
                print("Processing Svn repository " .. repo)
                os.execute(("svn up %s"):format(repo))
            else
                print("Skipping external repo " .. repo)
            end
        end
    end
end


function checkSvn(entry, getLast)
    local backlog = {}
    if entry.svn then
        if type(entry.svn) == "string" then
            entry.svn = {entry.svn}
        end
        entry.svnRepos = entry.svnRepos or {}
        for k, repo in pairs(entry.svn) do
            entry.svnRepos[repo] = entry.svnRepos[repo] or {lastCommit=-1}
            local repoData = entry.svnRepos[repo]
            repoData.lastLog = data
            repoData.lastCommit = repoData.lastCommit or -1
            if getLast then repoData.lastCommit = repoData.lastCommit - 1 end

            local prg = io.popen( ("svn log -l 5 -v %s"):format(repo), "r")
            local data = prg:read("*a")
            prg:close()
            local ids = {}
            for commit in data:gmatch("%-%-%-+\r?\n(.-)\r?\n%-%-%-%-+") do
                local id = tonumber(commit:match("^r(%d+)") or 0)
                if repoData.lastCommit < 0 then 
                    repoData.lastCommit = id
                end
                local committer = commit:match("r%d+ | ([^| ]+)") or "unknown"
                local changed, log = commit:match("(.+)\r?\n\r?\n(.+)")
                local files = {}
                for file in commit:gmatch("   [MADCU] ([^\r\n]+)") do
                    table.insert(files, file)
                end
                local mod = #files .. " files changed"
                if #files > 1 then
                    local prefix = ""
                    for i = 2, files[1]:len() do
                        local valid = true
                        xprefix = files[1]:sub(1,i)
                        for k, v in pairs(files) do
                            if (v:len() < i or not (v:sub(1,i) == xprefix)) then
                                valid = false
                                break
                            end
                        end
                        if valid then
                            prefix = xprefix
                        else
                            break
                        end 
                    end
                    if prefix:len() > 2 then
                        if prefix:sub(prefix:len()) ~= "/" then prefix = prefix .. "*" end
                        mod = prefix .. " (" .. #files .. " files)"
                    end
                end
                if #files == 1 then mod = files[1] end
                if committer and log and id > repoData.lastCommit then
                    if log:len() > config.rssmessagesize then log = log:sub(1,config.rssmessagesize) .. "..." end
                    log = log:gsub("\r?\n", "  ")
                    local msg =  ("[c]3%s[c] [bold]* r%s[end] (%s): %s [ [underline]http://svn.apache.org/viewvc?view=rev&rev=%s[end] ]"):format(committer, id, mod, log, id)
                    table.insert(backlog, msg)
                end
                table.insert(ids, id)
            end
            for k, id in pairs(ids) do
                if id > repoData.lastCommit then repoData.lastCommit = id end
            end
        end
    end
    return backlog
end





function updateGit(entry)
    if entry.git then
        if type(entry.git) == "string" then
            entry.git = {entry.git}
        end
        entry.gitRepos = entry.gitRepos or {}
        for k, repo in pairs(entry.git) do
            if not repo:match("https?://") then
                print("Processing Git repository " .. repo)
                os.execute(("git --git-dir %s/.git pull"):format(repo))
            else
                print("Skipping external repository " .. repo)
            end
        end
    end
end

function checkGit(entry, getLast)
    local backlog = {}
    if entry.git then
        if type(entry.git) == "string" then
            entry.git = {entry.git}
        end
        entry.gitRepos = entry.gitRepos or {}
        for k, repo in pairs(entry.git) do
            local prg = io.popen(("git --git-dir %s/.git log -n 5 --summary --raw --date=raw --reverse --pretty=format:\"%%H|%%h|%%at|%%aN|%%ae|%%s|%%d\" --all"):format(repo), "r")
            local data = prg:read("*a")
            prg:close()
            entry.gitRepos[repo] = entry.gitRepos[repo] or {lastCommit=-1}
            local repoData = entry.gitRepos[repo]
            repoData.lastLog = data
            repoData.lastCommit = repoData.lastCommit or -1
            if getLast then repoData.lastCommit = repoData.lastCommit - 1 end
            local commits = {}
            local Xcommit = {files={}}
            for commit in data:gmatch("([^\r\n]+)") do
                local bigHash,hash,id,author,email,subject,refs = commit:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)")
                
                id = tonumber(id)
                if not id then
                    Xcommit.files = Xcommit.files or {}
                    table.insert(Xcommit.files, commit:match("%s+%S%s+(.+)") or "(unknown file)")
                else
                    local ref = refs:match("([^%s/]+/[^%s/,]+)") or refs or "(nil)"
                    Xcommit = { hash=hash,id=id,author=author,email=email,subject=subject,ref=ref,files={}}
                    table.insert(commits, Xcommit)
                end
            end
            for k, commit in pairs(commits) do
                if commit.id then
                    if repoData.lastCommit < 0 then 
                        repoData.lastCommit = commit.id
                    end
                    if commit.author and commit.subject and commit.email and commit.id > repoData.lastCommit then
                        if commit.subject:len() > config.rssmessagesize then commit.subject = commit.subject:sub(1,config.rssmessagesize) .. "..." end
                        local mod = #commit.files .. " files"
                        if #commit.files == 1 then mod = commit.files[1] end
                        local msg1 =  ("[c]3<%s>[c] [bold]%s * %s:[end] (%s)[ [underline]http://apaste.info/ats=%s[end] ]"):format(commit.email, commit.ref, commit.hash, mod, commit.hash)
                        local msg2 =  ("[c]3<%s>[c] %s"):format(commit.email, commit.subject)
                        if not ignore and not entry.muted then 
                            table.insert(backlog, msg1)
                            table.insert(backlog, msg2)
                        end
                    end
                    if commit.id >= repoData.lastCommit then repoData.lastCommit = commit.id end
                end
            end
        end
    end
    return backlog
end


function updateCommits(s, ignore)
    if not s then s = _G.s end
    for site, entry in pairs(channels) do
        if entry.channel then
            print("--------------------\nProcessing " .. site)
            updateGit(entry)
            updateSvn(entry)
            local gitLog = checkGit(entry) -- Get Git backlog
            local svnLog = checkSvn(entry) -- Get Svn backlog
            if not ignore then
                for k, v in pairs(gitLog) do
                    say(s, entry.channel, v)
                    os.execute("sleep 1")
                end
                for k, v in pairs(svnLog) do
                    say(s, entry.channel, v)
                    os.execute("sleep 1")
                end
            end
        end
    end
end

function _G.handleMsg(s, line)
    if line then
        local sender = line:match("^:([^%!]+)")
        local channel = line:match("PRIVMSG (%S+) :") or ""
        local cmd = nil
        if channel then cmd = line:match("PRIVMSG #[^:]+:BabbleBot[,:] (.+)") end
        if not channel then cmd = line:match("PRIVMSG :(.+)") end
        if sender and cmd then
            if cmd == "mute" and hasKarma(sender) then
                for k, v in pairs(channels) do
                    if v.channel == channel then
                        v.muted = true
                    end
                end
                say(s,channel or sender, "Shutting up on [bold]" .. (channel or "(nil)") .. "[end]")                
            end
            if cmd == "unmute" and hasKarma(sender) then
                for k, v in pairs(channels) do
                    if v.channel == channel then
                        v.muted = false
                    end
                end
                say(s,channel or sender, "Notifying on [bold]" .. (channel or "(nil)") .. "[end]")                
            end

            if cmd == "karma" and hasKarma(sender) then
                say(s, channel or sender, "The following people have karma: " .. table.concat(karma, ", "))
            end
            if cmd:match("karma (%S+) (%S+)") and hasKarma(sender) then
                local add, user = cmd:match("karma (%S+) (%S+)")
                if not add or not user then return end
                local found = false
                if add == "remove" then
                    for k, v in pairs(karma) do
                        if v == user then
                            found = true
                            karma[k] = nil;
                            collectgarbage()
                        end
                    end
                    if found then
                        say(s, channel or sender, ("Removed karma from [bold]%s[end]"):format(user) )                
                    else
                        say(s, channel or sender, ("[bold]%s[end] doesn't have karma"):format(user) )                
                    end
                end
                if add == "add" then
                    table.insert(karma, user)
                    say(s, channel or sender, ("Gave karma to [bold]%s[end]"):format(user) )                
                end
            end
            if cmd:match("segfault") and sender == "Humbedooh" then
                s:send("QUIT :Oh noes, I accidentally the code\r\n\r\n")
                s:close()
                os.exit()
            end
            if cmd:match("messagesize (%d+)") and hasKarma(sender) then
                config.rssmessagesize = tonumber(cmd:match("messagesize (%d+)"))
                say(s, channel or sender, ("Set message size to [bold]%s bytes[end]."):format(config.rssmessagesize) )                
            end
            if cmd:match("help (.+)") then
                local what = cmd:match("help (.+)")
                if what == "karma" then say(s, channel or sender, "Usage: karma [add/remove] [user] - Adds or removes karma for a person.") end
            end
            if cmd == "help" then
                say(s, channel or sender, "Usage: help [command]")
                say(s, channel or sender, "[c]9Available commands:[c] lastgit lastsvn karma mute unmute subs subscribe unsubscribe stats")
            end
            if cmd == "stats" then
                local chans = {}
                for k, v in pairs(_G.channels) do
                    table.insert(chans, v.channel or "#nil")
                end
                say(s, channel or sender, "I am subscribed to the following channels: " .. table.concat(chans, ","))
            end
            if cmd:match("^join") and hasKarma(sender) then
                local chan = cmd:match("join (.+)") 
                if chan then
                    say(s, channel or sender, "Joining  " .. chan)
                    _G.channels[channel] = _G.channels[channel] or {}
                    s:send("JOIN " .. chan .. "\r\n\r\n");
                    saveConfig()
                end
            end
            if cmd:match("lastgit") then
                local chan = cmd:match("lastgit (.+)") or channel
                local entry = {}
                for k, v in pairs(_G.channels) do
                    if v.channel == chan then entry = v; break; end
                end
                if entry.git then
                    local backLog = checkGit(entry, true)
                    for k, v in pairs(backLog) do
                        say(s, channel or sender, v)
                        os.execute("sleep 1")
                    end
                else
                    say(s, channel or sender, "No Git repository found for channel " .. (channel or "nil"))
                end
            end
            if cmd:match("lastsvn") then
                local chan = cmd:match("lastsvn (.+)") or channel
                local entry = {}
                for k, v in pairs(_G.channels) do
                    if v.channel == chan then entry = v; break; end
                end
                if entry.svn then
                    local backLog = checkSvn(entry, true)
                    if backLog and #backLog > 0 then
                        for k, v in pairs(backLog) do
                            say(s, channel or sender, v)
                            os.execute("sleep 1")
                        end
                    else
                        say(s, channel or sender, "No SVN backlog found for channel " .. (chan or "nil"))
                    end
                else
                    say(s, channel or sender, "No SVN repository found for channel " .. (chan or "nil"))
                end
            end
            if cmd:match("subs") then
                local who = cmd:match("subs (.+)") or "nil"
                local entry = {}
                for k, v in pairs(_G.channels) do
                    if k == who then entry = v; break; end
                end
                if entry.svn then
                    local repos = table.concat(entry.svn, ", ")
                    say(s, channel or sender, "SVN Repositories: " .. repos)
                end
                if entry.git then
                    local repos = table.concat(entry.git, ", ")
                    say(s, channel or sender, "Git Repositories: " .. repos)
                end
            end
            if cmd:match("^subscribe") and hasKarma(sender) then
                local what, url = cmd:match("^subscribe (%S+) (%S+)")
                local subbed = false
                local entry = nil
                for k, v in pairs(_G.channels) do
                    if v.channel == channel then entry = v; break; end
                end
                if entry and url then
                    if what == "git" then
                        entry.git = entry.git or {}
                        table.insert(entry.git, url)
                        say(s, channel or sender, ("Added %s to the list of subscribed Git repositories for %s"):format(url, channel))
                        saveConfig()
                    end
                    if what == "svn" then
                        entry.svn = entry.svn or {}
                        table.insert(entry.svn, url)
                        say(s, channel or sender, ("Added %s to the list of subscribed Subversion repositories for %s"):format(url, channel))
                        saveConfig()
                    end
                    if what ~= "git" and what ~= "svn" then
                        say(s, channel or sender, "I do not know that type of repo. I know: git + svn")
                    end
                else
                    say(s, channel or sender, "I am currently not in this channel...somehow :(")
                end
            end
            if cmd:match("^unsubscribe") and hasKarma(sender) then
                local what, url = cmd:match("^unsubscribe (%S+) (%S+)")
                local subbed = false
                local entry = nil
                for k, v in pairs(_G.channels) do
                    if v.channel == channel then entry = v; break; end
                end
                if entry and url then
                    if what == "git" then
                        entry.git = entry.git or {}
                        for k, v in pairs(entry.git) do
                            if v == url then entry.git[k] = nil break end
                        end
                        say(s, channel or sender, ("Removed %s from the list of subscribed Git repositories for %s"):format(url, channel))
                        saveConfig()
                    end
                    if what == "svn" then
                        entry.svn = entry.svn or {}
                        for k, v in pairs(entry.svn) do
                            if v == url then entry.svn[k] = nil break end
                        end
                        say(s, channel or sender, ("Removed %s from the list of subscribed Subversion repositories for %s"):format(url, channel))
                        saveConfig()
                    end
                else
                    say(s, channel or sender, "I am currently not in this channel...somehow :(")
                end
            end
        end
    end
end

