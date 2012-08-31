local socket = require "socket" -- luasocket
local lfs    = require "lfs" --luafilesystem


function say(s, recipient, msg)
-- Legacy formatting
    msg = msg:gsub("%[bold%]", string.char(0x02))
    msg = msg:gsub("%[underline%]", string.char(0x1f))
    msg = msg:gsub("%[end%]", string.char(0x0f))
    msg = msg:gsub("%[c%]", string.char(0x03))

-- New stuff

    msg = msg:gsub("<b>", string.char(0x02))
    msg = msg:gsub("<u>", string.char(0x1f))
    msg = msg:gsub("</b>", string.char(0x0f))
    msg = msg:gsub("</u>", string.char(0x0f))
    msg = msg:gsub("<c(.*)>", function(a) return string.char(0x03)..(a or "") end)

    s:send( ("PRIVMSG %s :%s\r\n"):format(recipient, msg) )
end


function readIRC(s)
    while true do
        local receive, err = s:receive('*l')
        local now = os.time()
        if receive then
            if string.find(receive, "PING :") then
                s:send("PONG :" .. string.sub(receive, (string.find(receive, "PING :") + 6)) .. "\r\n\r\n")
            else
                if string.find(receive, "PRIVMSG") then
                    if handleMsg and type(handleMsg) == "function" then
                        local good, err = pcall(function() handleMsg(s, receive) end)
                        if err then 
                            print("ERR: ", err)
                            local sender = receive:match("^:([^%!]+)")
                            local channel = receive:match("PRIVMSG (%S+) :")
                            say(s, channel or sender, "[bold]Error:[end] " .. err)
                        end
                    end
                end	
            end
        elseif err == "closed" then
            break
        end
        if (now - lastUpdate > 5) then
            local stat = lfs.attributes("extensions.lua", "mode")
            if stat then
                dofile("extensions.lua")
            end
            if (now - lastCommitCheck) > 90 and type(updateCommits) == "function" then
                updateCommits(s, false)
                lastSVN = os.time()
            end
            if idle and type(idle) == "function" then
                idle(s)
            end
            lastUpdate = os.time()
        end 
    end
end

-- IRC Stuff goes here
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
    s:send("PRIVMSG nickserv :identify supersecretpassword\r\n\r\n");
    print("Joining channels\n");
    for k, entry in pairs(channels) do
        s:send("JOIN " .. entry.channel .. "\r\n\r\n");
        print("Joined " .. entry.channel .. " ");
    end
    s:settimeout(4)
    return s
end

dofile("config.lua")
dofile("extensions.lua")


-- Start the program
updateCommits(s, true)
_G.lastUpdate = os.time()
_G.lastCommitCheck = os.time()
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



