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
                    local msg =  ("<c3>%s</c> <b>* r%s</b> (%s): %s [ <u>http://svn.apache.org/viewvc?view=rev&rev=%s</u> ]"):format(committer, id, mod, log, id)
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
            local prg = io.popen(("git --git-dir %s/.git log -n 5 --summary --raw --date=raw --reverse --pretty=format:\"%%H|%%h|%%ct|%%aN|%%ae|%%s|%%d\" --all"):format(repo), "r")
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
                local bigHash,hash,id,author,email,subject,refs = commit:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]*)")
                refs = (refs and refs:len() > 0) and refs or "origin/master"
                id = tonumber(id)
                if not id then
                    Xcommit.files = Xcommit.files or {}
                    if commit:match("^:") then 
                        table.insert(Xcommit.files, commit:match("%s+%S%s+(.+)") or "(unknown file)")
                    end
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
                        if commit.subject:len() > config.maxmessagesize then commit.subject = commit.subject:sub(1,config.maxmessagesize) .. "..." end
                        local mod = #commit.files .. " files"
                        if #commit.files == 1 then mod = commit.files[1] end
                        local msg1 =  ("<c3><%s></c> <b>%s * %s:</b> (%s)[ <u>http://apaste.info/ats=%s</u> ]"):format(commit.email, commit.ref, commit.hash, mod, commit.hash)
                        local msg2 =  ("<c3><%s></c> %s"):format(commit.email, commit.subject)
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

function lastGit(s, sender, channel, cmd)
    local chan, span = cmd:match("(%S+)%s*(%d*)$")
    chan = chan or channel
    span = tonumber(span or "5")
    local entry = {}
    for k, v in pairs(_G.channels) do
        if v.channel == chan then entry = v; break; end
    end
    if entry.git then
        say(s, channel or sender, ("Showing Git commits within %s seconds of the last commit:"):format(span or 1))
        local backLog = checkGit(entry, span or 500)
        for k, v in pairs(backLog) do
            say(s, channel or sender, v)
            os.execute("sleep 1")
        end
    else
        say(s, channel or sender, "No Git repository found for channel " .. (channel or "nil"))
    end
end

function lastSvn(s, sender, channel, cmd)
    local chan, span = cmd:match("(%S+)%s*(%d*)$")
    chan = chan or channel
    span = tonumber(span or "5")
    local entry = {}
    for k, v in pairs(_G.channels) do
        if v.channel == chan then entry = v; break; end
    end
    if entry.svn then
        say(s, channel or sender, ("Showing last Subversion commit:"):format(span or 1))
        local backLog = checkSvn(entry, 1)
        for k, v in pairs(backLog) do
            say(s, channel or sender, v)
            os.execute("sleep 1")
        end
    else
        say(s, channel or sender, "No Subversion repository found for channel " .. (channel or "nil"))
    end
end

function subscribe(s, sender, channel, cmd)
    if hasKarma(sender) then
        local what, url = cmd:match("^(%S+) (%S+)")
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
            end
            if what == "svn" then
                entry.svn = entry.svn or {}
                table.insert(entry.svn, url)
                say(s, channel or sender, ("Added %s to the list of subscribed Subversion repositories for %s"):format(url, channel))
            end
            if what == "jira" then
                entry.jira = entry.jira or {}
                table.insert(entry.jira, url)
                checkJIRA(entry, true)
                say(s, channel or sender, ("Added %s to the list of subscribed JIRA instances for %s"):format(url, channel))
            end
            if what ~= "git" and what ~= "svn" and what ~= "jira" then
                say(s, channel or sender, "I do not know that type of repo. I know: git + svn")
            end
        else
            say(s, channel or sender, "I am currently not in this channel...somehow :(")
        end
    end
end


function unsubscribe(s, sender, channel, cmd)
    if hasKarma(sender) then
        local what, url = cmd:match("^(%S+) (%S+)")
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
            end
            if what == "svn" then
                entry.svn = entry.svn or {}
                for k, v in pairs(entry.svn) do
                    if v == url or url == "*" then entry.svn[k] = nil end
                end
                say(s, channel or sender, ("Removed %s from the list of subscribed Subversion repositories for %s"):format(url, channel))
            end
            if what == "jira" then
                entry.jira = entry.jira or {}
                for k, v in pairs(entry.jira) do
                    if v == url or url == "*" then entry.jira[k] = nil end
                end
                say(s, channel or sender, ("Removed %s from the list of subscribed JIRA instances for %s"):format(url, channel))
            end
        else
            say(s, channel or sender, "I am currently not in this channel...somehow :(")
        end
    end
end

function listsubs(s, sender, channel, cmd)
    local who = cmd:match("(.+)") or "nil"
    local entry = {}
    for k, v in pairs(_G.channels) do
        if k == who then entry = v; break; end
    end
    say(s, channel or sender, "Subscribed repositories for " .. entry.channel .. ":")
    if entry.svn then
        local repos = table.concat(entry.svn, ", ")
        say(s, channel or sender, "SVN Repositories: " .. repos)
    end
    if entry.git then
        local repos = table.concat(entry.git, ", ")
        say(s, channel or sender, "Git Repositories: " .. repos)
    end
end

registerCallback("updateCommits", updateCommits, 90, true)
registerCommand("lastgit", lastGit)
registerCommand("lastsvn", lastSvn)
registerCommand("subscribe", subscribe)
registerCommand("unsubscribe", unsubscribe)
registerCommand("subs", listsubs)


