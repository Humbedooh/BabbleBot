_G.config = {
    server = "irc.freenode.net",
    nick = "BabbleBot",
    password = "supersecretpassword",
    owner = "Humbedooh",
    username = "babble",
    realname = "BabbleBot",
    maxmessagesize = 256,
    gitfolder = "/var/git",
    svnfolder = "/var/svn"
}

_G.karma = {"Humbedooh"}

_G.channels = {
    test = {
        channel = "#commentstest", 
        svn = {"https://svn.apache.org/repos/asf/trafficserver/site/"},
        git = {
            "https://git-wip-us.apache.org/repos/asf/trafficserver.git",
            },
        },
}


