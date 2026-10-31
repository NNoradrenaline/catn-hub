if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local plr = Players.LocalPlayer
while not plr do task.wait() plr = Players.LocalPlayer end

local genv = getgenv and getgenv() or _G
if genv.__FF_AUTOPLAY and genv.__FF_AUTOPLAY.Destroy then
    pcall(genv.__FF_AUTOPLAY.Destroy)
end

local BPUI = ...

local WORKER = [==[
local id = ...
local ch = get_comm_channel(id)

local started, startErr = pcall(function()
local RunService = game:GetService("RunService")
local env = getgenv and getgenv() or _G
if env.__FF_WORKER then pcall(env.__FF_WORKER) end

local cfg = {enabled = false, offsetMs = 0, humanize = false, missChance = 2, goodChance = 10, jitter = 15,
    aim = false, aimTarget = 96}
local fw
local conns = {}
local alive = true
local presses, status = 0, "off"
local plans = setmetatable({}, {__mode = "k"})
local planVer = 0

local held = {}
local lastField
local song

local pressedAt = setmetatable({}, {__mode = "k"})
local lastDt = 0
local missLog = {}

local function newSong(field)
    song = {field = field, acc = 0, judged = 0, misses = 0, combo = 0, best = 0, counts = {}, title = "-"}
    if not field then return end
    pcall(function()
        local data = fw.Songs.SongData[field.Game.Song]
        song.title = data and (data.Title or data.Name) or tostring(field.Game.Song)
    end)
end
newSong(nil)

local function framework()
    if not fw then
        fw = filtergc("table", {Keys = {"VSRG", "Configs"}}, true)
        if fw then

            pcall(function()
                table.insert(conns, fw.EventAction:Bind("ScoreCalculated"):Connect(function(field, note, score, value, ms, acc)
                    if field ~= song.field then return end
                    song.judged = song.judged + 1
                    song.acc = song.acc + (tonumber(acc) or 0)
                    local name = score and score.Name or "?"
                    song.counts[name] = (song.counts[name] or 0) + 1
                    if (tonumber(value) or 0) > 0 then
                        song.combo = song.combo + 1
                        if song.combo > song.best then song.best = song.combo end
                    else
                        song.misses = song.misses + 1
                        song.combo = 0
                        local p = note and plans[note]
                        local why
                        if p and p.skip then
                            why = "skipped on purpose"
                        elseif note and pressedAt[note] then
                            why = string.format("pressed, game judged %s ms", tostring(ms and math.floor(ms + 0.5)))
                        elseif lastDt > 0.05 then
                            why = string.format("never pressed, %d ms frame", math.floor(lastDt * 1000 + 0.5))
                        else
                            why = "never pressed"
                        end
                        local t = note and tonumber(note.Time)
                        table.insert(missLog, 1, string.format("%s  lane %s  %s", t and string.format("%d:%05.2f", math.floor(t / 60), t % 60) or "?",
                            tostring(note and note.LaneIndex or "?"), why))
                        if #missLog > 12 then table.remove(missLog) end
                    end
                end))
            end)
        end
    end
    return fw
end

local function currentAcc()
    return song.judged > 0 and song.acc / song.judged or 100
end

local function planFor(note)
    local p = plans[note]
    if p and p.ver == planVer then return p end
    p = {ver = planVer, ms = 0}
    local side = math.random() < 0.5 and -1 or 1
    if cfg.aim then
        local acc = currentAcc()
        if song.judged > 10 and acc > cfg.aimTarget + 1.5 and math.random() < 0.25 then
            p.skip = true
        elseif acc > cfg.aimTarget then
            p.ms = side * (60 + math.random() * 22)
        end
    elseif cfg.humanize then
        local roll = math.random() * 100
        if roll < cfg.missChance then
            p.skip = true
        elseif roll < cfg.missChance + cfg.goodChance then
            p.ms = side * (56 + math.random() * 26)
        else
            p.ms = (math.random() * 2 - 1) * cfg.jitter
        end
    end
    plans[note] = p
    return p
end

local function releaseAll(field)
    for i in pairs(held) do
        if field then pcall(field.HitLane, field, i, false, os.clock()) end
        held[i] = nil
    end
end

local function step(dt)
    lastDt = dt
    local f = framework()
    local gh = f and f.VSRG.GameHandler
    local field = gh and gh.Field
    local g = field and field.Game
    if not cfg.enabled then
        releaseAll(lastField)
        status = "off"
        return
    end
    if not f then status = "can't find the game's code yet" return end
    if not g or g.Ending or not field.Lanes then
        releaseAll(lastField)
        status = "waiting for a song"
        return
    end
    if field ~= lastField then
        releaseAll(lastField)
        lastField = field
        newSong(field)
        table.clear(missLog)
    end
    status = "playing"

    local cfgs = f.Configs.VSRG
    local ignored = cfgs.IgnoredNoteTypes or {}
    local pb = g.AdjustedPlayback or 1
    local clock = os.clock()

    local sample = g.TimePositionSample
    local now
    if sample and type(sample.Clock) == "number" then
        now = (sample.Position or 0) + math.clamp(clock - sample.Clock, -0.25, 0.25) * pb
    else
        now = g.TimePosition or 0
    end
    local hbo = 0
    pcall(function() hbo = (f.SettingsHandler:Get("HitboxOffset") or 0) / 1000 end)
    now = now + hbo

    local lead = (math.min(dt, 0.05) * 0.5 + cfg.offsetMs / 1000) * pb

    for i, h in pairs(held) do
        if (h.song and now >= h.song) or (h.clock and clock >= h.clock) then
            field:HitLane(i, false, clock)
            held[i] = nil
        end
    end

    for i, lane in pairs(field.Lanes) do
        local notes = lane.Notes
        if type(notes) == "table" then
            local due
            for _, note in pairs(notes) do
                local t = note.Time
                local kind = note.NoteData and note.NoteData.Type

                if type(t) == "number" and not note.Hit and not note.Cleaned and not pressedAt[note]
                    and not (kind and table.find(ignored, kind)) then
                    local p = planFor(note)

                    if not p.skip and now + lead >= t + p.ms / 1000 * pb and now - t < 0.195 * pb then
                        due = due or {}
                        table.insert(due, note)
                    end
                end
            end
            if due then
                table.sort(due, function(a, b) return a.Time < b.Time end)
                for _, note in ipairs(due) do
                    if held[i] then field:HitLane(i, false, clock) end
                    field:HitLane(i, true, clock)
                    pressedAt[note] = clock
                    presses = presses + 1
                    local len = tonumber(note.Length) or 0
                    if len > 0 then
                        held[i] = {song = note.Time + len - 0.02}
                    else
                        held[i] = {clock = clock + 0.03}
                    end
                end
            end
        end
    end
end

table.insert(conns, RunService.RenderStepped:Connect(function(dt)
    local s, err = pcall(step, dt)
    if not s then
        status = "error: " .. tostring(err)
        pcall(releaseAll, lastField)
    end
end))

table.insert(conns, ch.Event:Connect(function(kind, data)
    if kind == "cfg" and type(data) == "table" then
        for k, v in pairs(data) do cfg[k] = v end
        planVer = planVer + 1
    elseif kind == "stop" then
        if env.__FF_WORKER then env.__FF_WORKER() end
    end
end))

local function stop()
    alive = false
    pcall(releaseAll, lastField)
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    table.clear(conns)
    env.__FF_WORKER = nil
end
env.__FF_WORKER = stop

task.spawn(function()
    while alive do
        local counts = song.counts or {}
        pcall(function()
            ch:Fire("stat", {
                status = status, presses = presses, title = song.title or "-", playing = status == "playing",
                acc = currentAcc(), judged = song.judged or 0, misses = song.misses or 0,
                combo = song.combo or 0, best = song.best or 0,
                sick = counts.Sick or 0, good = counts.Good or 0, ok = counts.Ok or 0, bad = counts.Bad or 0,
                found = fw ~= nil, missLog = table.concat(missLog, "\n"),
            })
        end)
        task.wait(0.25)
    end
end)
end)
if not started then ch:Fire("stat", {status = "worker failed: " .. tostring(startErr), presses = 0}) end
]==]

local auto = {
    enabled = false, offsetMs = 0, humanize = false, missChance = 2, goodChance = 10, jitter = 15,
    aim = false, aimTarget = 96,
}
local live = {status = "starting", presses = 0, title = "-", playing = false, acc = 100, judged = 0, misses = 0,
    combo = 0, best = 0, sick = 0, good = 0, ok = 0, bad = 0, at = 0, missLog = ""}
local songLog = {}
local alive = true
local conns = {}
local channel, channelId, actor
local workerError

local function sendCfg()
    if channel then pcall(function() channel:Fire("cfg", table.clone(auto)) end) end
end

local function logSong(s)
    if not s or (s.judged or 0) < 10 then return end
    table.insert(songLog, 1, string.format("%s  %.2f%%  %d misses  best combo %d", s.title or "?", s.acc or 0, s.misses or 0, s.best or 0))
    if #songLog > 8 then table.remove(songLog) end
end

local function startWorker()
    if type(run_on_actor) ~= "function" or type(create_comm_channel) ~= "function" then
        workerError = "this executor can't run code inside the game's actor"
        return false
    end
    actor = plr:FindFirstChild("PlayerScripts") and plr.PlayerScripts:FindFirstChild("ClientActor")
    if not actor then
        workerError = "waiting for the game to load"
        return false
    end
    if not channel then
        channelId, channel = create_comm_channel()
        table.insert(conns, channel.Event:Connect(function(kind, data)
            if kind ~= "stat" or type(data) ~= "table" then return end
            if live.playing and live.title ~= data.title then logSong(live) end
            if live.playing and not data.playing then logSong(live) end
            for k, v in pairs(data) do live[k] = v end
            live.at = os.clock()
        end))
    end
    local s, err = pcall(run_on_actor, actor, WORKER, channelId)
    if not s then
        workerError = "couldn't start inside the game: " .. tostring(err)
        return false
    end
    workerError = nil
    live.at = os.clock()
    task.delay(0.3, sendCfg)
    return true
end

local function stopWorker()
    if channel then pcall(function() channel:Fire("stop") end) end
end

local window = BPUI:CreateWindow({Version = "1.0.2",
    Title = "Funky Friday", Subtitle = "Autoplay",
    Icon = "music", Theme = "Void", Accent = Color3.fromRGB(143, 112, 236),
    ToggleKey = Enum.KeyCode.RightShift, ShowSettings = true, ConfigFolder = "FFAutoplay",
    Watermark = false, CloseBehavior = "Hide",
    OnDestroy = function()
        alive = false
        auto.enabled = false
        stopWorker()
        for _, c in ipairs(conns) do c:Disconnect() end
    end,
})

local state = {Auto = auto, Live = live, Log = songLog}
state.Destroy = function() pcall(function() window:Destroy() end) end
state.Restart = startWorker
state.Problem = function() return workerError end
state.Window = window
genv.__FF_AUTOPLAY = state

local function set(key, value)
    auto[key] = value
    sendCfg()
end
state.Set = set

local tab = window:CreateTab({Name = "Autoplay", Icon = "music"})
local main = tab:CreateSection("Autoplay")
local toggle = main:AddToggle({Name = "Auto play", Default = false, Flag = "ff_enabled",
    Description = "Hits every note on your side, holds included, and leaves death and poison notes alone. Keeps playing with Roblox in the background.",
    Callback = function(v) set("enabled", v == true and alive) end})
main:AddKeybind({Name = "Key", Default = Enum.KeyCode.F1, Mode = "Press", Flag = "ff_key",
    Callback = function() toggle:Set(not auto.enabled) end})
local statusLbl = main:AddLabel({Text = "starting", Style = "Sub"})
local songLbl = main:AddLabel({Text = "song: -", Style = "Sub"})
local statsLbl = main:AddLabel({Text = "-", Style = "Sub"})

local ctl = {}

local timing = tab:CreateSection("Timing")
ctl.offset = timing:AddSlider({Name = "Offset", Min = -40, Max = 40, Default = 0, Increment = 1, Suffix = " ms", Flag = "ff_offset",
    Description = "Positive presses earlier. Leave it at 0: it already uses the game's own clock and your hitbox offset setting.",
    Callback = function(v) set("offsetMs", tonumber(v) or 0) end})

local aimSec = tab:CreateSection("Accuracy target")
ctl.aim = aimSec:AddToggle({Name = "Aim for an accuracy", Default = false, Flag = "ff_aim",
    Description = "Plays perfect while under the target and takes Goods, and the odd miss, while over it. Replaces Humanize while on.",
    Callback = function(v) set("aim", v == true) end})
ctl.aimTarget = aimSec:AddSlider({Name = "Target", DependsOn = ctl.aim, Min = 80, Max = 100, Default = 96, Increment = 0.5, Suffix = " %", Flag = "ff_aim_target",
    Callback = function(v) set("aimTarget", tonumber(v) or 96) end})

local human = tab:CreateSection("Humanize")
ctl.humanize = human:AddToggle({Name = "Humanize", Default = false, Flag = "ff_humanize",
    Description = "Mixes in misses, Goods and small timing errors so it doesn't play perfectly.",
    Callback = function(v) set("humanize", v == true) end})
ctl.miss = human:AddSlider({Name = "Miss chance", DependsOn = ctl.humanize, Min = 0, Max = 15, Default = 2, Increment = 1, Suffix = " %", Flag = "ff_miss",
    Callback = function(v) set("missChance", tonumber(v) or 0) end})
ctl.good = human:AddSlider({Name = "Good chance", DependsOn = ctl.humanize, Min = 0, Max = 40, Default = 10, Increment = 1, Suffix = " %", Flag = "ff_good",
    Callback = function(v) set("goodChance", tonumber(v) or 0) end})
ctl.jitter = human:AddSlider({Name = "Timing jitter", DependsOn = ctl.humanize, Min = 0, Max = 45, Default = 15, Increment = 1, Suffix = " ms", Flag = "ff_jitter",
    Description = "Random error on normal hits. Anything under 50 ms still counts as Sick.",
    Callback = function(v) set("jitter", tonumber(v) or 0) end})

local PRESET_FILE = "FFAutoplay/presets.json"
local BUILT_IN = {
    {name = "Perfect", s = {offset = 0, humanize = false, aim = false}},
    {name = "Looks human", s = {offset = 0, humanize = true, miss = 2, good = 10, jitter = 15, aim = false}},
    {name = "Sloppy", s = {offset = 0, humanize = true, miss = 6, good = 25, jitter = 35, aim = false}},
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
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("FFAutoplay") then makefolder("FFAutoplay") end
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
    if num(s.offset, -40, 40) then ctl.offset:Set(num(s.offset, -40, 40)) end
    if num(s.miss, 0, 15) then ctl.miss:Set(num(s.miss, 0, 15)) end
    if num(s.good, 0, 40) then ctl.good:Set(num(s.good, 0, 40)) end
    if num(s.jitter, 0, 45) then ctl.jitter:Set(num(s.jitter, 0, 45)) end
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
    if applySettings((findPreset(chosenPreset))) then
        window:Notify({Title = "Preset", Content = chosenPreset .. " applied.", Type = "Success", Duration = 3})
    end
end})
local presetName = ""
presetSec:AddInput({Name = "Save current as", Placeholder = "name", Flag = "ff_preset_name",
    Callback = function(v) presetName = tostring(v or "") end})
presetSec:AddButton({Name = "Save preset", ButtonText = "Save", Callback = function()
    local name = presetName:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then window:Notify({Title = "Preset", Content = "Type a name first.", Type = "Warning", Duration = 3}) return end
    local _, builtIn = findPreset(name)
    if builtIn then window:Notify({Title = "Preset", Content = "That name is taken by a built-in preset.", Type = "Warning", Duration = 3}) return end
    userPresets[name] = currentSettings()
    savePresets()
    pcall(function() presetDrop:Refresh(presetNames()) end)
    window:Notify({Title = "Preset", Content = "Saved " .. name .. ".", Type = "Success", Duration = 3})
end})
presetSec:AddButton({Name = "Delete preset", ButtonText = "Delete", Callback = function()
    local _, builtIn = findPreset(chosenPreset)
    if builtIn or not userPresets[chosenPreset] then
        window:Notify({Title = "Preset", Content = "Built-in presets can't be deleted.", Type = "Warning", Duration = 3})
        return
    end
    userPresets[chosenPreset] = nil
    savePresets()
    pcall(function() presetDrop:Refresh(presetNames()) end)
    window:Notify({Title = "Preset", Content = "Deleted " .. chosenPreset .. ".", Type = "Info", Duration = 3})
end})

local logSec = tab:CreateSection("Song log")
local logText = logSec:AddParagraph({Title = "Last songs", Content = "none yet"})
local missText = logSec:AddParagraph({Title = "Misses this song", Content = "none"})

task.spawn(function()
    startWorker()
    while alive do
        if not workerError and os.clock() - live.at > 3 then startWorker() end
        if workerError then
            task.wait(2)
            if alive then startWorker() end
        end
        pcall(function()
            local txt
            if workerError then
                txt = workerError
            elseif os.clock() - live.at > 1.5 then
                txt = "reconnecting"
            else
                txt = live.status
            end
            statusLbl:Set(txt .. "  |  presses: " .. tostring(live.presses))
            if live.playing then
                songLbl:Set("song: " .. tostring(live.title))
                statsLbl:Set(string.format("%.2f%%  |  misses %d  |  combo %d  |  sick %d  good %d  ok %d  bad %d",
                    live.acc, live.misses, live.combo, live.sick, live.good, live.ok, live.bad))
            else
                songLbl:Set("song: -")
                statsLbl:Set("-")
            end
            logText:SetContent(#songLog > 0 and table.concat(songLog, "\n") or "none yet")
            missText:SetContent((live.missLog and live.missLog ~= "") and live.missLog or "none")
        end)
        task.wait(0.5)
    end
end)

window:SelectTab("Autoplay")
pcall(function()
    window:Notify({Title = "Funky Friday", Content = "loaded, F1 to toggle", Type = "Success", Duration = 4})
end)

return state
