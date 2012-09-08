function twitterStatus(entry, bl)
    local backlog = {}
    entry.twitter = entry.twitter or {}
    for k, tag in pairs(entry.twitter) do
        local data = ""
        local f = io.popen(([[curl --silent "http://search.twitter.com/search.rss?q=%s&rpp=5&include_entities=true&with_twitter_user_id=true&result_type=mixed"]]):format(tag.tag), "r")
        if f then data = f:read("*a") f:close() end
        local tweets = {}
        for item in data:gmatch("<item>(.-)</item>") do
            local link = item:match("<link>(.-)</link>") or "??"
            local desc = item:match("<description>(.-)</description>") or "??"
            desc = desc:gsub("&lt;.-&gt;", "")
            table.insert(tweets, ("Tweet: %s [ %s ]"):format(desc, link) )
        end
        local i = 0
        for k, tweet in pairs(tweets) do
            i = i + 1
            if tweet == tag.lastTweet and not (bl and bl > i) then
                break
            end
            table.insert(backlog, tweet)
        end
        if #tweets > 0 then
            tag.lastTweet = tweets[1]
        end
    end
    return backlog
end

function updateTwitter(s)
    for k, entry in pairs(_G.channels) do
        local backlog = twitterStatus(entry)
        for k, tweet in pairs(backlog) do
            say(s, entry.channel, tweet)
            os.execute("sleep 1")
        end
    end
end

function addTag(s, sender, channel, tag)
    local entry = nil
    for k, v in pairs(_G.channels) do
        if v.channel == channel then entry = v; break; end
    end
    if not entry then
        channels[channel] = {channel=channel}
        entry = channels[channel]
    end
    if entry then
        entry.twitter = entry.twitter or {}
        entry.twitter[tag] = {tag = tag, lastUpdate = os.time(), lastTweet = ""}
        say(s, channel or sender, ("Added tag '%s' to twitter search."):format(tag))
    end
end


function getTweets(s, sender, channel, tag)
    local entry = nil
    for k, v in pairs(_G.channels) do
        if v.channel == channel then entry = v; break; end
    end
    if not entry then
        _G.channels[channel or "??"] = {channel=channel}
        entry = _G.channels[channel]
    end
    if entry then
        say(s, channel or sender, "Last tweets: ")
        local backlog = twitterStatus(entry, 3)
        for k, tweet in pairs(backlog) do
            say(s, channel or sender, tweet)
            os.execute("sleep 1")
        end
    end
end

registerCommand("gettweets", getTweets)
registerCommand("addtag", addTag)
registerCallback("tweets", updateTwitter, 15)

