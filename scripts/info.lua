function whoami(s, sender, channel, cmd)
    say(s, channel or sender, "I am BabbleBot, running on bayern.awesomelysecure.org - feed me botsnacks!")
end

registerCommand("info", whoami)

