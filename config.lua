_G.config = {
    server = "irc.freenode.net",
    nick = "BabbleBot",
    password = "somepassword",
    owner = "Humbedooh",
    username = "babble",
    realname = "BabbleBot",
    maxmessagesize = 256,
    gitfolder = "/var/git",
    svnfolder = "/var/svn"
}

_G.karma = {"YourNickHere"}

_G.channels = {
    test = {
        channel = "#commits", 
        svn = {},
        git = {
            "/var/git/someproject",
            },
        },
}


