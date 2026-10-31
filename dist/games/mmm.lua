if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local cas = game:GetService("ContextActionService")
local uis = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local rs = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer
while not plr do task.wait() plr = Players.LocalPlayer end
plr:WaitForChild("PlayerGui")

local genv = getgenv and getgenv() or _G
if genv.__MMM_AUTOPLAY and genv.__MMM_AUTOPLAY.Destroy then
    pcall(genv.__MMM_AUTOPLAY.Destroy)
end

local BPUI = ...

local function focused()
    if type(isrbxactive) ~= "function" then return true end
    local s, v = pcall(isrbxactive)
    return not s or v ~= false
end

local function strip(txt)
    return (tostring(txt or ""):gsub("<[^>]+>", ""):gsub("%s+", " "))
end

local function actionName(lane) return lane .. "_FNF_Key" end

local function laneBinds(lane)
    local info = cas:GetBoundActionInfo(actionName(lane))
    local keys = {}
    if info and info.inputTypes then
        for _, k in ipairs(info.inputTypes) do
            if typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode
                and not k.Name:find("^Button") and not k.Name:find("^DPad") and not k.Name:find("^Thumbstick") then
                table.insert(keys, k.Name)
            end
        end
    end
    return keys, info ~= nil and info.inputTypes ~= nil
end

local inputObj
local function grabInput(input)
    if input.KeyCode ~= Enum.KeyCode.Unknown then inputObj = input end
end

local VK = {Space = 0x20, Semicolon = 0xBA, Quote = 0xDE, Comma = 0xBC, Period = 0xBE, Slash = 0xBF,
    LeftBracket = 0xDB, RightBracket = 0xDD, BackSlash = 0xDC, Minus = 0xBD, Equals = 0xBB}
for i = 0, 25 do VK[string.char(65 + i)] = 0x41 + i end
for i, n in ipairs({"Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"}) do
    VK[n] = 0x30 + i - 1
end
local hasKeypress = type(keypress) == "function" and type(keyrelease) == "function"

local lastPrime = -math.huge
local function primeInput()
    if inputObj or not hasKeypress or os.clock() - lastPrime < 2 or not focused() then return end
    lastPrime = os.clock()
    pcall(function()
        keypress(0x7C)
        task.wait(0.03)
        keyrelease(0x7C)
    end)
end

local function backupKey(lane)
    if not hasKeypress then return end
    for _, k in ipairs((laneBinds(lane))) do
        if VK[k] then return VK[k] end
    end
end

local auto = {
    enabled = false, offsetMs = 0, presses = 0, status = "off", unbound = nil, method = "-",
    humanize = false, missChance = 2, goodChance = 10, jitter = 50, autoStart = false,
    aim = false, aimTarget = 96,
}

local live = {misses = nil, acc = nil, title = ""}

local SICK, GOOD = 0.058, 0.1
local planVer = 0
local plans = setmetatable({}, {__mode = "k"})

local match = {speed = 1, extra = 0, last = -math.huge}
local function updateMatchInfo()
    if os.clock() - match.last < 3 then return end
    match.last = os.clock()
    local matches = rs:FindFirstChild("Matches")
    if not matches then return end
    for _, m in ipairs(matches:GetChildren()) do
        for _, role in ipairs({"Owner", "Participant", "Opponent"}) do
            local r = m:FindFirstChild(role)
            if r and r:IsA("ObjectValue") and r.Value == plr and not m:GetAttribute("Finished") then
                local ns = r:FindFirstChild("NoteSpeed")
                local am = m:FindFirstChild("AccuracyMode")
                match.speed = (1 + (ns and tonumber(ns.Value) or 1)) * 0.5
                match.extra = (am and am.Value == 1) and 0.029 or 0
                return
            end
        end
    end
end

local function toPixels(laneFrame, units)
    return (units + match.extra) * match.speed * laneFrame.AbsoluteSize.Y
end

local function getPlan(note, laneFrame)
    local p = plans[note]
    if p and p.ver == planVer then return p end
    p = {ver = planVer, px = 0}
    if auto.aim then

        local acc = live.acc
        if acc and acc > auto.aimTarget + 1.5 and math.random() < 0.25 then
            p.skip, p.why = true, "skipped on purpose (accuracy target)"
        elseif acc and acc > auto.aimTarget then
            p.px = toPixels(laneFrame, (SICK + GOOD) / 2)
        end
    elseif auto.humanize then
        local roll = math.random() * 100
        if roll < auto.missChance then
            p.skip, p.why = true, "skipped on purpose (humanize)"
        elseif roll < auto.missChance + auto.goodChance then
            p.px = toPixels(laneFrame, (SICK + GOOD) / 2)
        else
            p.px = (math.random() * 2 - 1) * auto.jitter / 100 * toPixels(laneFrame, SICK)
        end
    end
    plans[note] = p
    return p
end

local alive = true
local conns = {}
local lanes = {}
local lastY = setmetatable({}, {__mode = "k"})
local hit = setmetatable({}, {__mode = "k"})
local retried = setmetatable({}, {__mode = "k"})
local arrowGui, side

table.insert(conns, uis.InputBegan:Connect(grabInput))
table.insert(conns, uis.InputChanged:Connect(grabInput))

local function midY(g) return g.AbsolutePosition.Y + g.AbsoluteSize.Y / 2 end

local MISS_FILE = "MMMAutoplay/misses.txt"
local missLog = {entries = {}, events = {}, gui = nil, songStart = 0, lastMisses = 0, spikeAt = -math.huge, spikeMs = 0}
local flagged = setmetatable({}, {__mode = "k"})

local function noteEvent(lane, why)
    table.insert(missLog.events, {at = os.clock(), lane = lane, why = why})
    if #missLog.events > 40 then table.remove(missLog.events, 1) end
end

local function addMiss(text)
    table.insert(missLog.entries, text)
    if #missLog.entries > 200 then table.remove(missLog.entries, 1) end
    if type(appendfile) == "function" then
        pcall(function()
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("MMMAutoplay") then makefolder("MMMAutoplay") end
            appendfile(MISS_FILE, text .. "\n")
        end)
    end
end

local function readStats()
    local s = arrowGui and arrowGui:FindFirstChild("Stats")
    local t = s and strip(s.Text) or ""
    live.misses = tonumber(t:match("Misses:%s*(%d+)"))
    live.acc = tonumber(t:match("Accuracy:%s*([%d%.]+)"))
end

local function trackMisses(now)
    if missLog.gui ~= arrowGui then

        missLog.gui, missLog.songStart, missLog.lastMisses, missLog.events = arrowGui, now, live.misses or 0, {}
    end

    local t = arrowGui and arrowGui:FindFirstChild("Title")
    local title = t and (strip(t.Text):gsub("%s*%[[%d:]+%]%s*$", "")) or ""
    if title == "" then title = "?" end
    local m = live.misses
    if not m then return end
    if m < missLog.lastMisses then missLog.lastMisses = m end
    while missLog.lastMisses < m do
        missLog.lastMisses = missLog.lastMisses + 1
        local ev
        for i = #missLog.events, 1, -1 do
            local e = missLog.events[i]
            if not e.used and now - e.at < 0.6 then ev = e break end
        end
        if ev then ev.used = true end
        local why = ev and ev.why
        if not why and now - (missLog.blockedAt or -math.huge) < 1.5 then
            why = "roblox wasn't focused and the script had no input object yet, so it couldn't press"
        elseif not why and now - missLog.spikeAt < 1.5 then

            why = string.format("game froze for %d ms, notes went past before anything could press", missLog.spikeMs)
        end
        if why and now - (missLog.unfocusedAt or -math.huge) < 1.5 then why = why .. " (roblox was unfocused)" end
        local secs = now - missLog.songStart
        addMiss(string.format("%s  %d:%02d  miss %d  %s  %s", title, math.floor(secs / 60), math.floor(secs % 60),
            missLog.lastMisses, ev and ev.lane or "?", why or "no cause seen (the game called it a miss)"))
    end
end

local function send(lane, down)
    if inputObj then
        local s = pcall(function()
            cas:CallFunction(lane.action, down and Enum.UserInputState.Begin or Enum.UserInputState.End, inputObj)
        end)
        if s then auto.method = "direct (any bind)" return true end
    end
    if lane.vk then
        if down then keypress(lane.vk) else keyrelease(lane.vk) end
        auto.method = "key presses"
        return true
    end
    return false
end

local function release(lane)
    if lane.down then pcall(send, lane, false) end
    lane.down = false
end

local function releaseAll()
    for _, l in pairs(lanes) do release(l) end
end

local function press(lane)
    release(lane)
    lane.down = send(lane, true)
    lane.pressedAt = os.clock()
    return lane.down
end

local arrowCache, arrowCheck = nil, 0
local function findArrowGui()
    if arrowCache and arrowCache.Parent then return arrowCache end
    if os.clock() - arrowCheck < 0.5 then return nil end
    arrowCheck = os.clock()
    arrowCache = plr.PlayerGui:FindFirstChild("ArrowGui", true)
    return arrowCache
end

local function getSide(gui)
    local opp = gui:FindFirstChild("OpponentStats")
    local best, gap
    for _, n in ipairs({"Left", "Right"}) do
        local s = gui:FindFirstChild(n)
        if s and s:FindFirstChild("Notes") then
            local g = opp and math.abs(s.AbsolutePosition.X - opp.AbsolutePosition.X) or 0
            if not gap or g > gap then best, gap = s, g end
        end
    end
    return best
end

local function step(dt)

    if dt > 0.1 then missLog.spikeAt, missLog.spikeMs = os.clock(), math.floor(dt * 1000 + 0.5) end
    if not auto.enabled then return end
    if not arrowGui or not arrowGui.Parent then
        releaseAll()
        table.clear(lanes)
        auto.unbound = nil
        arrowGui, side = findArrowGui(), nil
        if not arrowGui then auto.status = "waiting for a song" return end
    end
    side = side or getSide(arrowGui)
    local receptors = side and side:FindFirstChild("MainArrowContainer")
    local notes = side and side:FindFirstChild("Notes")
    local holds = side and side:FindFirstChild("LongNotes")
    if not receptors or not notes then auto.status = "waiting for a song" return end

    if not focused() then missLog.unfocusedAt = os.clock() end
    if uis:GetFocusedTextBox() or (not inputObj and not focused()) then
        if not inputObj and not focused() then missLog.blockedAt = os.clock() end
        releaseAll()
        auto.status = uis:GetFocusedTextBox() and "paused (typing)" or "paused (click into roblox once, after that it works in the background)"
        return
    end
    auto.status = "playing"
    updateMatchInfo()
    local now = os.clock()
    readStats()
    trackMisses(now)
    local offset = auto.offsetMs / 1000

    for _, laneFrame in ipairs(notes:GetChildren()) do
        local name = laneFrame.Name
        local rec = receptors:FindFirstChild(name)
        local lane = lanes[name]
        if not lane then
            local _, bound = laneBinds(name)
            if bound then
                lane = {action = actionName(name), vk = backupKey(name), down = false, pressedAt = 0, holdUntil = 0}
                lanes[name] = lane
                if auto.unbound == name then auto.unbound = nil end
            else
                auto.unbound = name
            end
        end

        if rec and lane then
            local line = midY(rec)

            local window = math.max(rec.AbsoluteSize.Y * 0.35, toPixels(laneFrame, GOOD))

            local pressCount = 0

            for _, note in ipairs(laneFrame:GetChildren()) do
                if note:IsA("GuiObject") and note.Visible then
                    local y = midY(note)
                    local prev = lastY[note]
                    lastY[note] = y

                    if prev and math.abs(y - prev) > rec.AbsoluteSize.Y * 2 then
                        prev, hit[note], plans[note], retried[note], flagged[note] = nil, nil, nil, nil, nil
                    end
                    local p = getPlan(note, laneFrame)

                    local again = hit[note] and not retried[note] and now - hit[note] > 0.025
                    if prev and dt > 0 and (not hit[note] or again) and not p.skip then
                        local vel = (y - prev) / dt
                        local speed = math.abs(vel)
                        if speed > 5 then
                            local left = (line - y) * (vel > 0 and 1 or -1)
                            if left <= speed * dt * 0.5 + speed * offset + p.px and left > -window then
                                if again then retried[note] = true end
                                hit[note] = now
                                pressCount = pressCount + 1
                            end
                        end
                    end

                    if prev and dt > 0 and not flagged[note] then
                        local vel = (y - prev) / dt
                        if math.abs(vel) > 5 and (line - y) * (vel > 0 and 1 or -1) <= -window then
                            flagged[note] = true
                            local why
                            if p.skip then
                                why = p.why or "skipped on purpose"
                            elseif hit[note] then
                                why = "pressed, but the game didn't take it"
                            elseif dt > 0.05 then
                                why = string.format("went past during a lag spike (%d ms frame)", math.floor(dt * 1000 + 0.5))
                            else
                                why = "never pressed"
                            end
                            noteEvent(name, why)
                        end
                    end
                end
            end

            local holdLane = holds and holds:FindFirstChild(name)
            if holdLane then
                for _, piece in ipairs(holdLane:GetChildren()) do
                    if piece:IsA("GuiObject") and piece.Visible then
                        local top = piece.AbsolutePosition.Y
                        if top <= line + 4 and top + piece.AbsoluteSize.Y >= line - 4 then
                            lane.holdUntil = now + 0.06
                            break
                        end
                    end
                end
            end

            if pressCount > 0 then
                for _ = 1, pressCount do
                    if press(lane) then auto.presses = auto.presses + 1 end
                end
            elseif lane.down and now - lane.pressedAt > 0.04 and now > lane.holdUntil then
                release(lane)
            end
        end
    end
end

table.insert(conns, RunService.RenderStepped:Connect(function(dt)
    local s, err = pcall(step, dt)
    if not s then
        auto.status = "error: " .. tostring(err)
        releaseAll()
    end
end))

local lastStart = 0
local function autoStart()
    if not auto.autoStart or os.clock() - lastStart < 2 then return end
    if type(mousemoveabs) ~= "function" or type(mouse1click) ~= "function" or not focused() then return end
    local gui = arrowGui and arrowGui.Parent and arrowGui or findArrowGui()
    local btn = gui and gui:FindFirstChild("Start")
    if not btn or not btn:IsA("GuiButton") or not btn.Visible then return end
    local sg = btn:FindFirstAncestorOfClass("ScreenGui")
    local inset = (sg and sg.IgnoreGuiInset) and Vector2.zero or GuiService:GetGuiInset()
    local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2 + inset
    lastStart = os.clock()
    mousemoveabs(math.floor(pos.X), math.floor(pos.Y))
    task.wait(0.05)
    mouse1click()
end

local LOBBY = {PlayerType = 2, AccessType = 1, MatchType = 3, AccuracyMode = 2, ModChartsEnabled = false}
local lobby = {
    auto = false, pick = false, category = nil, song = nil, difficulty = nil,
    status = "off", lastCreate = -math.huge, idleSince = nil, picked = 0,
    closeResults = false, resultsDelay = 3,
}

local mods = {}
local function loadMods()
    if mods.noteGame and mods.class then return true end
    pcall(function()
        mods.noteGame = require(plr.PlayerScripts.Start.Menu.Freeplay.NoteGame)
        mods.effects = require(rs.Modules.CommonEffects)
        mods.songs = require(rs.Modules.Songs)
        if type(filtergc) == "function" then
            mods.class = filtergc("table", {Keys = {"_StartSongSelect", "_LoadSong"}}, true)
        end
    end)
    return mods.noteGame ~= nil and mods.class ~= nil
end

local function hiddenGuis() return rs.Assets:FindFirstChild("GUIs") end

local function songSelect()
    if not loadMods() then return end
    local fn = rawget(mods.class, "_StartSongSelect")
    local s, sel, frame, timer = pcall(function()
        return debug.getupvalue(fn, 3), debug.getupvalue(fn, 6), debug.getupvalue(fn, 23)
    end)
    if not s or type(sel) ~= "table" or typeof(frame) ~= "Instance" or type(timer) ~= "table" then return end
    return sel, frame, timer
end

local function myMatch()
    local matches = rs:FindFirstChild("Matches")
    local mine = matches and matches:FindFirstChild(tostring(plr.UserId))
    if mine and not mine:GetAttribute("Finished") then return mine, true end
    if matches then
        for _, m in ipairs(matches:GetChildren()) do
            if not m:GetAttribute("Finished") then
                for _, role in ipairs({"Owner", "Participant", "Opponent"}) do
                    local r = m:FindFirstChild(role)
                    if r and r:IsA("ObjectValue") and r.Value == plr then return m, false end
                end
            end
        end
    end
end

local function hasOpponent(m)
    local o = m and m:FindFirstChild("Opponent")
    return o ~= nil and o:IsA("ObjectValue") and o.Value ~= nil
end

local function makeLobby()
    if not loadMods() then lobby.status = "couldn't load the game's match code" return end
    lobby.lastCreate = os.clock()
    local canCreate = rs:FindFirstChild("Events") and rs.Events:FindFirstChild("CanCreateMatch")
    if canCreate then
        local s, allowed, wait = pcall(canCreate.InvokeServer, canCreate)
        if s and allowed == false then
            lobby.status = "game won't let you host yet (" .. tostring(wait) .. ")"
            return
        end
    end
    local s, ev = pcall(function() return mods.noteGame:CreateMatch(table.clone(LOBBY)) end)
    if not s then lobby.status = "create failed: " .. tostring(ev) return end

    pcall(function()
        ev:Connect(function(stage)
            if mods.effects and stage == mods.effects.BlackTransitionEvent.Halfway then
                local menu = plr.PlayerGui:FindFirstChild("FreeplayMenu", true)
                if menu then menu.Parent = hiddenGuis() end
            end
        end)
    end)
    lobby.status = "lobby created, waiting for a player"
end

local function pickedSong()
    local cat = mods.songs and lobby.category and mods.songs[lobby.category]
    local song = cat and cat.Songs and cat.Songs[lobby.song]
    if song and type(song.DifficultyInfo) == "table" and song.DifficultyInfo[lobby.difficulty] then
        return lobby.category, lobby.song, lobby.difficulty
    end
end

local answered = false
local function pickSong()
    if not lobby.pick then return end
    local sel, frame, timer = songSelect()
    if not sel then return end
    local open = frame.Parent ~= nil and frame.Parent ~= hiddenGuis()
    if not open then answered = false return end
    if answered then return end
    local m, owner = myMatch()
    if not m or not hasOpponent(m) then return end
    local cat, song, diff = pickedSong()
    if not cat then lobby.status = "pick a valid song first" return end
    answered = true
    task.wait(0.5)
    sel.Category, sel.Song, sel.Difficulty = cat, song, diff
    pcall(function() timer:Stop() end)
    lobby.picked = lobby.picked + 1
    lobby.status = "picked " .. song .. " (" .. diff .. ")" .. (owner and "" or " as a vote")
end

local resultsAt, lastClose = nil, -math.huge
local function closeResults()
    if not lobby.closeResults or type(getconnections) ~= "function" or not loadMods() then return end
    local s, gui = pcall(debug.getupvalue, rawget(mods.class, "_ToResults"), 3)
    if not s or typeof(gui) ~= "Instance" then return end
    if gui.Parent == nil or gui.Parent == hiddenGuis() then resultsAt = nil return end
    resultsAt = resultsAt or os.clock()
    if os.clock() - resultsAt < lobby.resultsDelay or os.clock() - lastClose < 5 then return end
    local btn = gui:FindFirstChild("Background") and gui.Background:FindFirstChild("Return")
    if not btn then return end
    lastClose, resultsAt = os.clock(), nil
    for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
        if c.Function then task.spawn(c.Function) end
    end
    lobby.status = "closed results"
end

local function lobbyTick()
    local m = myMatch()
    if m or findArrowGui() then
        lobby.idleSince = nil
        if lobby.auto and m and not hasOpponent(m) then lobby.status = "waiting for a player to join" end
        return
    end
    if not lobby.auto then lobby.status = "off" return end
    lobby.idleSince = lobby.idleSince or os.clock()
    if os.clock() - lobby.idleSince >= 4 and os.clock() - lobby.lastCreate >= 15 then
        lobby.status = "creating lobby..."
        makeLobby()
    else
        lobby.status = "creating a lobby shortly"
    end
end

local LOG_FILE = "MMMAutoplay/songs.txt"
local songLog = {}
local cur

local HttpService = game:GetService("HttpService")
local hook = {url = "", on = false, status = "off"}

local function validHook(url)
    return url:match("^https://[%w%.]*discord%.com/api/webhooks/%d+/[%w_%-]+$") ~= nil
        or url:match("^https://[%w%.]*discordapp%.com/api/webhooks/%d+/[%w_%-]+$") ~= nil
end

local function postResult(title, stats, judgements, why)
    local send = request or http_request or (syn and syn.request) or (http and http.request)
    if not send then hook.status = "this executor can't send web requests" return false end
    if not validHook(hook.url) then hook.status = "that isn't a discord webhook link" return false end
    local fields = {{name = "Judgements", value = judgements ~= "" and judgements or "-", inline = false}}
    if why and why ~= "" then table.insert(fields, {name = "Misses", value = why, inline = false}) end
    local body = HttpService:JSONEncode({
        username = "Catn Hub",
        embeds = {{
            title = title ~= "" and title or "Song finished",
            description = stats,
            color = 16747032,
            fields = fields,
            footer = {text = "MMM Autoplay"},
            timestamp = DateTime.now():ToIsoDate(),
        }},
    })
    local ok, res = pcall(send, {Url = hook.url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body})
    local code = ok and type(res) == "table" and res.StatusCode or nil
    if code and code >= 200 and code < 300 then
        hook.status = "sent " .. os.date("%H:%M")
        return true
    end
    hook.status = "discord refused it (" .. tostring(code or res) .. ")"
    return false
end

local function missSummary(title)
    local counts, order = {}, {}
    for _, line in ipairs(missLog.entries) do
        if line:sub(1, #title) == title then
            local why = line:match("miss %d+  %S+  (.+)$") or "?"
            if not counts[why] then counts[why] = 0 table.insert(order, why) end
            counts[why] = counts[why] + 1
        end
    end
    local out = {}
    for _, why in ipairs(order) do table.insert(out, counts[why] .. "x " .. why) end
    return table.concat(out, "\n")
end

local function saveSong()
    if not cur then return end
    if hook.on then
        local c = cur
        task.spawn(postResult, c.title, c.stats, c.judgements, missSummary(c.title))
    end
    local line = os.date("%m/%d %H:%M") .. "  " .. cur.title .. "  |  " .. cur.stats
        .. (cur.judgements ~= "" and ("  |  " .. cur.judgements) or "")
    table.insert(songLog, 1, line)
    if #songLog > 10 then table.remove(songLog) end
    if type(appendfile) == "function" and type(makefolder) == "function" then
        pcall(function()
            if type(isfolder) == "function" and not isfolder("MMMAutoplay") then makefolder("MMMAutoplay") end
            appendfile(LOG_FILE, line .. "\n")
        end)
    end
    cur = nil
end

local function watchSong()
    local gui = arrowGui and arrowGui.Parent and arrowGui or findArrowGui()
    local stats = gui and gui:FindFirstChild("Stats") and strip(gui.Stats.Text) or ""
    if stats:find("Score: %d") then
        cur = {
            title = strip(gui:FindFirstChild("Title") and gui.Title.Text):gsub("%s*%[[%d:]+%]%s*$", ""),
            stats = stats,
            judgements = strip(gui:FindFirstChild("Judgements") and gui.Judgements.Text):gsub("^Judgements: %-+ ", ""),
        }
    elseif cur then
        saveSong()
    end
end

local window = BPUI:CreateWindow({Version = "1.1.1",
    Title = "MMM Autoplay", Subtitle = "Monday Morning Misery",
    Icon = "zap", Theme = "Void", Accent = Color3.fromRGB(143, 112, 236),
    ToggleKey = Enum.KeyCode.RightShift, ShowSettings = true, ConfigFolder = "MMMAutoplay",
    Watermark = false, CloseBehavior = "Hide",
    OnDestroy = function()
        alive = false
        auto.enabled = false
        releaseAll()
        for _, c in ipairs(conns) do c:Disconnect() end
    end,
})

local state = {Auto = auto, MatchInfo = match, Lobby = lobby}
state.ResetPlans = function() planVer = planVer + 1 end
state.Destroy = function() pcall(function() window:Destroy() end) end
genv.__MMM_AUTOPLAY = state

local tab = window:CreateTab({Name = "Autoplay", Icon = "zap"})
local main = tab:CreateSection("Autoplay")
local toggle = main:AddToggle({Name = "Auto play", Default = false, Flag = "autoplay_enabled",
    Description = "Hits every note on your side, holds included.",
    Callback = function(v)
        auto.enabled = v == true and alive
        if not auto.enabled then releaseAll() auto.status = "off" end
    end})
main:AddKeybind({Name = "Keybind", Default = Enum.KeyCode.F1, Mode = "Press", Flag = "autoplay_key",
    Callback = function() toggle:Set(not auto.enabled) end})
local statusLbl = main:AddLabel({Text = "off", Style = "Sub"})
local songLbl = main:AddLabel({Text = "song: -", Style = "Sub"})
local statsLbl = main:AddLabel({Text = "-", Style = "Sub"})

local ctl = {}

local timing = tab:CreateSection("Timing")
ctl.offset = timing:AddSlider({Name = "Offset", Min = -50, Max = 50, Default = 0, Increment = 1, Suffix = " ms", Flag = "autoplay_offset",
    Description = "Positive presses earlier. Leave at 0 unless hits come out as Good.",
    Callback = function(v) auto.offsetMs = tonumber(v) or 0 end})

local aimSec = tab:CreateSection("Accuracy target")
local function changed() planVer = planVer + 1 end
ctl.aim = aimSec:AddToggle({Name = "Aim for an accuracy", Default = false, Flag = "autoplay_aim",
    Description = "Plays perfect while under the target and lets some notes slip while over it. Replaces Humanize while on.",
    Callback = function(v) auto.aim = v == true changed() end})
ctl.aimTarget = aimSec:AddSlider({Name = "Target", DependsOn = ctl.aim, Min = 80, Max = 100, Default = 96, Increment = 0.5, Suffix = " %", Flag = "autoplay_aim_target",
    Callback = function(v) auto.aimTarget = tonumber(v) or 96 changed() end})

local human = tab:CreateSection("Humanize")
ctl.humanize = human:AddToggle({Name = "Humanize", Default = false, Flag = "autoplay_humanize",
    Description = "Mixes in misses, Goods and small timing errors so it doesn't play perfectly.",
    Callback = function(v) auto.humanize = v == true changed() end})
ctl.miss = human:AddSlider({Name = "Miss chance", DependsOn = ctl.humanize, Min = 0, Max = 15, Default = 2, Increment = 1, Suffix = " %", Flag = "autoplay_miss",
    Callback = function(v) auto.missChance = tonumber(v) or 0 changed() end})
ctl.good = human:AddSlider({Name = "Good chance", DependsOn = ctl.humanize, Min = 0, Max = 40, Default = 10, Increment = 1, Suffix = " %", Flag = "autoplay_good",
    Callback = function(v) auto.goodChance = tonumber(v) or 0 changed() end})
ctl.jitter = human:AddSlider({Name = "Timing jitter", DependsOn = ctl.humanize, Min = 0, Max = 80, Default = 50, Increment = 5, Suffix = " %", Flag = "autoplay_jitter",
    Description = "Random error on normal hits, as a share of the Sick window, so they stay Sick.",
    Callback = function(v) auto.jitter = tonumber(v) or 0 changed() end})

local PRESET_FILE = "MMMAutoplay/presets.json"
local BUILT_IN = {
    {name = "Perfect", s = {offset = 0, humanize = false, aim = false}},
    {name = "Looks human", s = {offset = 0, humanize = true, miss = 2, good = 10, jitter = 50, aim = false}},
    {name = "Sloppy", s = {offset = 0, humanize = true, miss = 6, good = 25, jitter = 70, aim = false}},
    {name = "Aim for 95%", s = {offset = 0, aim = true, aimTarget = 95}},
}
local userPresets = {}
pcall(function()
    if type(isfile) == "function" and isfile(PRESET_FILE) then
        local data = HttpService:JSONDecode(readfile(PRESET_FILE))
        if type(data) == "table" then userPresets = data end
    end
end)

local function savePresets()
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("MMMAutoplay") then makefolder("MMMAutoplay") end
        writefile(PRESET_FILE, HttpService:JSONEncode(userPresets))
    end)
end

local function presetNames()
    local names = {}
    for _, p in ipairs(BUILT_IN) do table.insert(names, p.name) end
    local mine = {}
    for name in pairs(userPresets) do table.insert(mine, name) end
    table.sort(mine, function(a, b) return a:lower() < b:lower() end)
    for _, n in ipairs(mine) do table.insert(names, n) end
    return names
end

local function findPreset(name)
    for _, p in ipairs(BUILT_IN) do if p.name == name then return p.s, true end end
    return userPresets[name], false
end

local function currentSettings()
    return {offset = auto.offsetMs, humanize = auto.humanize, miss = auto.missChance, good = auto.goodChance,
        jitter = auto.jitter, aim = auto.aim, aimTarget = auto.aimTarget}
end

local function applySettings(s)
    if type(s) ~= "table" then return false end
    local function num(v, lo, hi) v = tonumber(v) return v and math.clamp(v, lo, hi) or nil end
    if num(s.offset, -50, 50) then ctl.offset:Set(num(s.offset, -50, 50)) end
    if num(s.miss, 0, 15) then ctl.miss:Set(num(s.miss, 0, 15)) end
    if num(s.good, 0, 40) then ctl.good:Set(num(s.good, 0, 40)) end
    if num(s.jitter, 0, 80) then ctl.jitter:Set(num(s.jitter, 0, 80)) end
    if num(s.aimTarget, 80, 100) then ctl.aimTarget:Set(num(s.aimTarget, 80, 100)) end
    if type(s.humanize) == "boolean" then ctl.humanize:Set(s.humanize) end
    if type(s.aim) == "boolean" then ctl.aim:Set(s.aim) end
    return true
end

local presetSec = tab:CreateSection("Presets")
local chosenPreset = "Perfect"
local presetDrop = presetSec:AddDropdown({Name = "Preset", Options = presetNames(), Default = "Perfect",
    Callback = function(v) chosenPreset = v end})
presetSec:AddButton({Name = "Use this preset", ButtonText = "Apply", Callback = function()
    local s = findPreset(chosenPreset)
    if applySettings(s) then window:Notify({Title = "Preset", Content = chosenPreset .. " applied.", Type = "Success", Duration = 3}) end
end})
local newName = ""
presetSec:AddInput({Name = "Name", Placeholder = "My preset", Callback = function(t) newName = tostring(t or "") end})
presetSec:AddButton({Name = "Save current settings", ButtonText = "Save", Callback = function()
    local name = newName:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then window:Notify({Title = "Preset", Content = "Type a name first.", Type = "Warning", Duration = 3}) return end
    local _, builtIn = findPreset(name)
    if builtIn then window:Notify({Title = "Preset", Content = "That name is taken by a built-in preset.", Type = "Warning", Duration = 3}) return end
    userPresets[name] = currentSettings()
    savePresets()
    presetDrop:Refresh(presetNames())
    window:Notify({Title = "Preset", Content = "Saved " .. name .. ".", Type = "Success", Duration = 3})
end})
presetSec:AddButton({Name = "Delete selected preset", ButtonText = "Delete", Style = "Danger", Callback = function()
    local _, builtIn = findPreset(chosenPreset)
    if builtIn or not userPresets[chosenPreset] then
        window:Notify({Title = "Preset", Content = "Built-in presets can't be deleted.", Type = "Warning", Duration = 3})
        return
    end
    userPresets[chosenPreset] = nil
    savePresets()
    presetDrop:Refresh(presetNames())
    window:Notify({Title = "Preset", Content = "Deleted " .. chosenPreset .. ".", Type = "Info", Duration = 3})
end})
presetSec:AddButton({Name = "Copy current settings as a code", ButtonText = "Copy", Callback = function()
    local code = "MMM:" .. HttpService:JSONEncode(currentSettings())
    if type(setclipboard) == "function" and pcall(setclipboard, code) then
        window:Notify({Title = "Preset", Content = "Code copied. Anyone can paste it below to get these settings.", Type = "Success", Duration = 4})
    else
        window:Notify({Title = "Preset", Content = code, Type = "Info", Duration = 12})
    end
end})
presetSec:AddInput({Name = "Paste a code", Placeholder = "MMM:{...}", Callback = function(t, enter)
    t = tostring(t or "")
    if not enter or t == "" then return end
    local ok, s = pcall(HttpService.JSONDecode, HttpService, (t:gsub("^%s*MMM:", "")))
    if ok and applySettings(s) then
        window:Notify({Title = "Preset", Content = "Settings from the code applied. Save them to keep them as a preset.", Type = "Success", Duration = 4})
    else
        window:Notify({Title = "Preset", Content = "That code doesn't look right.", Type = "Error", Duration = 3})
    end
end})

local extras = tab:CreateSection("Extras")
extras:AddToggle({Name = "Auto start", Default = false, Flag = "autoplay_autostart",
    Description = "Clicks Start when it shows up. Needs Roblox focused.",
    Callback = function(v) auto.autoStart = v == true end})

local lobbyTab = window:CreateTab({Name = "Lobby", Icon = "users"})
local lob = lobbyTab:CreateSection("Auto lobby")
lob:AddToggle({Name = "Auto create lobby", Default = false, Flag = "lobby_auto",
    Description = "Hosts a match whenever you're not in one: Right side, everyone can join, least misses.",
    Callback = function(v) lobby.auto = v == true lobby.idleSince = nil end})
lob:AddToggle({Name = "Auto pick song", Default = false, Flag = "lobby_pick",
    Description = "Picks the song below once another player joins and song select opens.",
    Callback = function(v) lobby.pick = v == true end})
local closeToggle = lob:AddToggle({Name = "Auto close results", Default = false, Flag = "lobby_close_results",
    Description = "Leaves the results screen after a match so a new lobby can be made.",
    Callback = function(v) lobby.closeResults = v == true end})
lob:AddSlider({Name = "Results delay", DependsOn = closeToggle, Min = 0, Max = 15, Default = 3, Increment = 1, Suffix = " s",
    Flag = "lobby_results_delay", Description = "How long to show the results before closing them.",
    Callback = function(v) lobby.resultsDelay = tonumber(v) or 3 end})
local lobbyLbl = lob:AddLabel({Text = "off", Style = "Sub"})
lob:AddLabel({Text = "auto start is ignored while auto lobby is on", Style = "Sub"})

local songSec = lobbyTab:CreateSection("Song")
loadMods()
local songs = mods.songs or {}

local function sortedKeys(t)
    local out = {}
    if type(t) == "table" then for k in pairs(t) do table.insert(out, tostring(k)) end end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

local cats = {}
for name, c in pairs(songs) do
    if type(c) == "table" and type(c.Songs) == "table" then table.insert(cats, name) end
end
table.sort(cats, function(a, b) return a:lower() < b:lower() end)

local songDrop, diffDrop
songSec:AddDropdown({Name = "Category", Options = cats, Flag = "lobby_category", Searchable = true,
    Callback = function(v)
        lobby.category = v
        if songDrop then songDrop:Refresh(sortedKeys(songs[v] and songs[v].Songs)) end
        lobby.song, lobby.difficulty = nil, nil
        if diffDrop then diffDrop:Refresh({}) end
    end})
songDrop = songSec:AddDropdown({Name = "Song", Options = {}, Flag = "lobby_song", Searchable = true,
    Callback = function(v)
        lobby.song = v
        local c = songs[lobby.category]
        local data = c and c.Songs and c.Songs[v]
        local diffs = sortedKeys(data and data.DifficultyInfo)
        if diffDrop then
            diffDrop:Refresh(diffs)
            if #diffs == 1 then diffDrop:Set(diffs[1]) end
        end
    end})
diffDrop = songSec:AddDropdown({Name = "Difficulty", Options = {}, Flag = "lobby_difficulty",
    Callback = function(v) lobby.difficulty = v end})
local songCheck = songSec:AddLabel({Text = "no song chosen", Style = "Sub"})

local logSec = tab:CreateSection("Song log")
local logText = logSec:AddParagraph({Title = "Last songs", Content = "none yet"})
logSec:AddLabel({Text = "also saved to workspace/" .. LOG_FILE, Style = "Sub"})

local bindSec = tab:CreateSection("Your binds")
local bindsLbl = bindSec:AddLabel({Text = "start a song to read them", Style = "Sub"})
local inputLbl = bindSec:AddLabel({Text = "input: -", Style = "Sub"})

local missTab = window:CreateTab({Name = "Miss log", Icon = "list"})
local missSec = missTab:CreateSection("Misses")
local missText = missSec:AddParagraph({Title = "Latest misses", Content = "none yet"})
missSec:AddButton({Name = "Copy miss log", Desc = "Paste it to whoever is fixing the script", ButtonText = "Copy", Callback = function()
    local text = #missLog.entries > 0 and table.concat(missLog.entries, "\n") or "no misses logged"
    if type(setclipboard) == "function" and pcall(setclipboard, text) then
        window:Notify({Title = "Miss log", Content = #missLog.entries .. " lines copied.", Type = "Success", Duration = 3})
    else
        window:Notify({Title = "Miss log", Content = "This executor can't copy. It's also saved to workspace/" .. MISS_FILE, Type = "Info", Duration = 6})
    end
end})
missSec:AddButton({Name = "Clear", ButtonText = "Clear", Callback = function()
    table.clear(missLog.entries)
    window:Notify({Title = "Miss log", Content = "Cleared.", Type = "Info", Duration = 2})
end})
missSec:AddLabel({Text = "each line: song, time into the song, miss number, lane, why. also saved to workspace/" .. MISS_FILE, Style = "Sub"})

local discordTab = window:CreateTab({Name = "Discord", Icon = "message-circle"})
local hookSec = discordTab:CreateSection("Post results")
hookSec:AddToggle({Name = "Post after each song", Default = false, Flag = "hook_on",
    Description = "Sends the song, score, accuracy, judgements and why any misses happened.",
    Callback = function(v) hook.on = v == true end})
hookSec:AddInput({Name = "Webhook link", Placeholder = "https://discord.com/api/webhooks/...", Flag = "hook_url",
    Callback = function(t)
        hook.url = (tostring(t or ""):gsub("%s", ""))
        hook.status = hook.url == "" and "no link yet" or (validHook(hook.url) and "ready" or "that isn't a discord webhook link")
    end})
hookSec:AddButton({Name = "Send a test", ButtonText = "Send", Callback = function()
    task.spawn(function()
        local ok = postResult("Test from MMM Autoplay", "If you can read this, results will show up here.", "", "")
        window:Notify({Title = "Discord", Content = ok and "Test sent." or hook.status, Type = ok and "Success" or "Error", Duration = 4})
    end)
end})
local hookLbl = hookSec:AddLabel({Text = "no link yet", Style = "Sub"})
hookSec:AddLabel({Text = "Server Settings > Integrations > Webhooks > New Webhook > Copy Webhook URL", Style = "Sub"})

local function laneOrder()
    local rec = side and side:FindFirstChild("MainArrowContainer")
    local list = {}
    if rec then
        for _, r in ipairs(rec:GetChildren()) do
            if r:IsA("GuiObject") then table.insert(list, r) end
        end
        table.sort(list, function(a, b) return a.Position.X.Scale < b.Position.X.Scale end)
    end
    local names = {}
    for _, r in ipairs(list) do table.insert(names, r.Name) end
    if #names == 0 then names = {"Left", "Down", "Up", "Right"} end
    return names
end

local function bindsText()
    local parts = {}
    for _, n in ipairs(laneOrder()) do
        local keys = laneBinds(n)
        if #keys > 0 then table.insert(parts, n .. ": " .. table.concat(keys, " / ")) end
    end
    return #parts > 0 and table.concat(parts, "   ") or "start a song to read them"
end

task.spawn(function()
    while alive do
        task.spawn(pcall, primeInput)
        pcall(watchSong)
        pcall(closeResults)
        pcall(lobbyTick)
        task.spawn(pcall, pickSong)
        if not lobby.auto then pcall(autoStart) end

        pcall(function()
            logText:SetContent(#songLog > 0 and table.concat(songLog, "\n") or "none yet")
            local last = {}
            for i = math.max(1, #missLog.entries - 7), #missLog.entries do table.insert(last, missLog.entries[i]) end
            missText:SetContent(#last > 0 and table.concat(last, "\n") or "none yet")
            hookLbl:Set(hook.status)
            lobbyLbl:Set(lobby.status .. (lobby.picked > 0 and ("  |  songs picked: " .. lobby.picked) or ""))
            local c, s, d = pickedSong()
            songCheck:Set(c and ("ready: " .. s .. " (" .. d .. ")") or "no song chosen")
        end)

        pcall(function()
            local txt = auto.enabled and auto.status or "off"
            if auto.unbound then txt = txt .. "  |  no usable key for lane " .. auto.unbound end
            statusLbl:Set(txt .. "  |  presses: " .. auto.presses)
            bindsLbl:Set(bindsText())
            inputLbl:Set("input: " .. (inputObj and "direct (works with any bind)" or "waiting for mouse movement")
                .. (auto.method ~= "-" and ("  |  last used: " .. auto.method) or ""))
            if arrowGui and arrowGui.Parent then
                songLbl:Set("song: " .. strip(arrowGui:FindFirstChild("Title") and arrowGui.Title.Text))
                local j = strip(arrowGui:FindFirstChild("Judgements") and arrowGui.Judgements.Text):gsub("^Judgements: %-+ ", "")
                statsLbl:Set(strip(arrowGui:FindFirstChild("Stats") and arrowGui.Stats.Text) .. "  |  " .. j)
            else
                songLbl:Set("song: -")
                statsLbl:Set("-")
            end
        end)

        task.wait(0.5)
    end
end)

window:SelectTab("Autoplay")
pcall(function()
    window:Notify({Title = "MMM Autoplay", Content = "loaded, F1 to toggle", Type = "Success", Duration = 4})
end)

return state
