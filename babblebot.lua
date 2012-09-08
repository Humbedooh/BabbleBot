local socket = require "socket" -- Lua Socket
local lfs    = require "lfs" --luafilesystem
require "extensions"
require "config"

chatCommands = {}
idleFunctions = {}
callbacks = {}
scripts = {}

function say(s, recipient, msg)
    msg = msg:gsub("<b>", string.char(0x02))
    msg = msg:gsub("<u>", string.char(0x1f))
    msg = msg:gsub("</b>", string.char(0x0f))
    msg = msg:gsub("</u>", string.char(0x0f))
    msg = msg:gsub("<c([0-9,]*)>", function(a) return string.char(0x03)..(a or "") end)
    msg = msg:gsub("</c>", string.char(0x03) .. " ")
    if s then s:send( ("PRIVMSG %s :%s\r\n"):format(recipient, msg) ) end
end

function registerCommand(cmd, func)
    chatCommands[cmd] = { arg = cmd, func = func }
end

function registerCallback(cmd, func, timeout, runatstart)
    callbacks[cmd] = { func = func, timeout = timeout, lastCall = os.time(), atstart = runatstart or false }
end

function updateScripts(s)
    for filename in lfs.dir("./scripts") do
        if filename:match("%.lua$") then
            local path = "./scripts/" .. filename
            local stat = lfs.attributes(path)
            scripts[path] = scripts[path] or {size=0, modified=0}
            if stat and (stat.modification > scripts[path].modified or stat.size ~= scripts[path].size) then
                scripts[path] = {modified=stat.modification, size=stat.size}
                print("(re)loading "..path)
                say(s, config.owner, ("Script '%s' is modified/new, (re)loading..."):format(filename))
                local good, err = pcall(function() dofile(path) end)
                if err then
                    say(s, config.owner, "<b>Error:</b> " .. err)
                else
                    dofile(path)
                    say(s, config.owner, "Load successful.")
                end
            end
        end
    end
end

function runCallbacks(s, startingUp)
    local now = os.time()
    for k, v in pairs(callbacks) do
        v.lastCall = v.lastCall or now
        if (v.lastCall + v.timeout) <= now or (startingUp and v.atstart) then
            print(("Running callback %s (%u + %u <= %u)"):format(k, v.lastCall, v.timeout, now))
            if type(v.func) == "function" then
                local good, err = pcall(function() v.func(s) end)
                if err then
                    say(s, config.owner, "<b>Error in callback '"..k.."':</b> " .. err)
                end
            end
            v.lastCall = now
        end        
    end
end

function _G.handleMsg(s, line)
    if line then
        local sender = line:match("^:([^%!]+)")
        local channel = line:match("PRIVMSG (#%S+) :") or nil
        local cmd = nil
        local rec = nil
        if channel then rec, cmd = line:match("PRIVMSG #[^:]+:([^:,]+)[,:] (.+)") end
        if not channel then cmd = line:match("PRIVMSG %[^:]+:(.+)") end
        print(("chan=%s, rec=%s, cmd=%s"):format(channel or "??", rec or "??", cmd or "??"))
        if sender and cmd and rec == config.nick then
            local command = cmd:match("^(%S+)") or ""
            local params = cmd:sub(command:len()+2)
            command = command or ""
            for k, v in pairs(chatCommands) do
                if command:lower() == v.arg then
                    print("dispatching to function " .. k)
                    if v.func and type(v.func) == "function" then
                        v.func(s, sender, channel, params)
                    end
                end
            end
        end
    end
end

function readIRC(s)
    while true do
        local receive, err = s:receive('*l')
        local now = os.time()
        if receive then
            if string.find(receive, "PING :") then
                s:send("PONG :" .. string.sub(receive, (string.find(receive, "PING :") + 6)) .. "\r\n\r\n")
                print("ping? pong!")
            else
                if string.find(receive, "PRIVMSG") then
                    print(receive)
                    local good, err = pcall(function() handleMsg(s, receive) end)
                    if err then 
                        print("ERR: ", err)
                        local sender = receive:match("^:([^%!]+)")
                        local channel = receive:match("PRIVMSG (%S+) :")
                        say(s, channel or sender, "<b>Error:</b> " .. err)
                    end
                end
            end
        elseif err == "closed" then
            break
        end
        if (now - lastUpdate > 5) then
            updateScripts(s)
            runCallbacks(s)
            lastUpdate = os.time()
        end 
    end
end

function connectToIRC()
    print("Connecting to " .. config.server .. "\n")
    local s = socket.tcp()
    _G.s = s
    local success, err = s:connect(socket.dns.toip(config.server), 6667)
    if not success then
        print("Failed to connect: ".. err .. "\n")
        return false
    end
    print("Using nickname " .. config.nick .. "\n")
    s:send("USER " .. config.username .. " " .. " " .. config.nick .. " " .. config.nick .. " " .. ":" .. config.realname .. "\r\n\r\n")
    s:send("NICK " .. config.nick .. "\r\n\r\n")
    if config.password then 
        s:send("PRIVMSG nickserv :identify " .. config.password .. "\r\n\r\n");
    end
    print("Joining channels\n");
    for k, entry in pairs(channels) do
        s:send("JOIN " .. entry.channel .. "\r\n\r\n");
        print("Joined " .. entry.channel .. " ");
    end
    s:settimeout(4)
    return s
end

function joinChannel(s, sender, channel, params)
    say(s, channel or sender, "Joining " .. params)
    s:send("JOIN " .. params .. "\r\n\r\n");
    print("Joined " .. params .. " ");
end

registerCommand("join", joinChannel)

-- Start the program
_G.lastUpdate = os.time()
updateScripts(s)
runCallbacks(s, true)

-- Connect and idle
while true do
    local s = connectToIRC()
    if s then
        print "Idling..."
        readIRC(s)
    else
        print("Connection failed, retrying...")
        os.execute("sleep 5")
    end
end



