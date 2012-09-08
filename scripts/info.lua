function whoami(s, sender, channel, cmd)
    say(s, channel or sender, "I am BabbleBot, running on bayern.awesomelysecure.org - feed me botsnacks!")
end

function grantKarma(s, sender, channel, cmd)
    if type(karma) ~= "table" then karma = {} end
    if not (hasKarma(sender) or sender == config.owner) then return end
    local add, user = cmd:match("(%S+) (%S+)")
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
            say(s, channel or sender, ("<b>%s</b> doesn't have karma"):format(user) )                
        end
    end
    if add == "add" then
        table.insert(karma, user)
        say(s, channel or sender, ("Gave karma to <b>%s</b>"):format(user) )                
    end
    if add == "list" then
        say(s, channel or sender, ("People with karma: %s"):format(table.concat(karma, ", ")) )                
    end
end

registerCommand("info", whoami)
registerCommand("karma", grantKarma)

