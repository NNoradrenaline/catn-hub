local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer
assert(player, "Run this script after Roblox has finished joining.")
assert(type(loadstring) == "function", "Catn Hub needs loadstring.")

local env = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then env = value end
end
local KEY = "__BP_HUB_ABA"
for _, key in ipairs({KEY, "__ABA_BLACK_FLASH_BPUI_V1", "__ABA_SPIRIT_GUN_ALL_TARGETS"}) do
    local previous = env[key]
    if type(previous) == "table" and type(previous.Destroy) == "function" then pcall(previous.Destroy) end
end

local BPUI = ... or loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/ui.lua"))()

local executor = "Unknown executor"
if type(identifyexecutor) == "function" then
    local ok, name, version = pcall(identifyexecutor)
    if ok then executor = tostring(name) .. (version and (" " .. tostring(version)) or "") end
end
local click = type(mouse1click) == "function" and mouse1click or nil
local holdClick = type(mouse1press) == "function" and type(mouse1release) == "function"
local canKeyClick = type(keyclick) == "function"
local canAimMouse = type(mousemoveabs) == "function"
local canCheckOwner = type(isnetworkowner) == "function"
local focusCheck
for _, name in ipairs({"isrbxactive", "isgameactive", "iswindowactive"}) do
    local fn = env[name] or getfenv()[name]
    if type(fn) == "function" then focusCheck = fn break end
end
local correctGame = game.PlaceId == 1458767429
local supported = click ~= nil and correctGame

local alive = true
local connections = {}
local cleanups = {}
local state = {executor = executor}
local window

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    connections[#connections + 1] = connection
    return connection
end

local function onCleanup(fn) cleanups[#cleanups + 1] = fn end

local function cleanup()
    if not alive then return end
    alive = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    for index = #cleanups, 1, -1 do pcall(cleanups[index]) end
    table.clear(cleanups)
    if env[KEY] == state then env[KEY] = nil end
end

state.Destroy = function()
    cleanup()
    if window then pcall(function() window:Destroy() end) end
end
env[KEY] = state

local windowFocused = nil
connect(UIS.WindowFocused, function() windowFocused = true end)
connect(UIS.WindowFocusReleased, function() windowFocused = false end)

local function isFocused()
    if focusCheck then
        local ok, value = pcall(focusCheck)
        if ok and type(value) == "boolean" then return value end
    end
    return windowFocused == true
end

local function canInput() return isFocused() and UIS:GetFocusedTextBox() == nil end

local function hideWindow() if window then pcall(function() window:Hide() end) end end

local function hiddenGuiParent()
    if type(gethui) == "function" then
        local ok, value = pcall(gethui)
        if ok and typeof(value) == "Instance" then return value end
    end
    return game:GetService("CoreGui")
end

local function gameAction(name)
    local scripts = player:FindFirstChild("PlayerScripts")
    local context = scripts and scripts:FindFirstChild("BaseContext")
    local action = context and context:FindFirstChild(name)
    if action and action:IsA("InputAction") then return action end
end

local function tapAction(name)
    local action = gameAction(name)
    if not action then return false end
    action:Fire(true)
    task.wait(0.03)
    action:Fire(false)
    return true
end

local function make(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end

local timing = {frame = 1 / 60, frameJitter = 0, ping = 0.02, pingJitter = 0}
connect(RunService.Heartbeat, function(dt)
    if dt <= 0 or dt > 1 then return end
    timing.frameJitter = timing.frameJitter + (0.12 * (math.abs(dt - timing.frame) - timing.frameJitter))
    timing.frame = timing.frame + (0.12 * (dt - timing.frame))
end)

local function samplePing()
    local ok, value = pcall(function() return player:GetNetworkPing() end)
    local measured = (ok and type(value) == "number" and value >= 0 and value < 2) and value or 0.02
    timing.ping = timing.ping + (0.2 * (measured - timing.ping))
    timing.pingJitter = timing.pingJitter + (0.2 * (math.abs(measured - timing.ping) - timing.pingJitter))
    return measured
end

local Game = {}

function Game.aliveRoot(model)
    if not model or not model.Parent then return nil end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    if humanoid and root and humanoid.Health > 0 then return root, humanoid end
    return nil
end

function Game.ownRoot() return Game.aliveRoot(player.Character) end

local OWNER_KEYS = {"Owner", "Creator", "Summoner", "Master", "Player"}
function Game.ownerOf(model)
    local owner = Players:GetPlayerFromCharacter(model)
    if owner then return owner end
    owner = Players:FindFirstChild(model.Name)
    if owner and owner:IsA("Player") then return owner end
    for _, key in ipairs(OWNER_KEYS) do
        local value = model:FindFirstChild(key)
        if value and value:IsA("ObjectValue") and value.Value then
            local found = value.Value:IsA("Player") and value.Value or Players:GetPlayerFromCharacter(value.Value)
            if found then return found end
        elseif value and value:IsA("StringValue") then
            local found = Players:FindFirstChild(value.Value)
            if found and found:IsA("Player") then return found end
        end
        local attribute = model:GetAttribute(key)
        if type(attribute) == "string" then
            local found = Players:FindFirstChild(attribute)
            if found and found:IsA("Player") then return found end
        elseif type(attribute) == "number" then
            local found = Players:GetPlayerByUserId(attribute)
            if found then return found end
        end
    end
    return nil
end

function Game.onAfkTeam(targetPlayer)
    local team = targetPlayer.Team
    return team ~= nil and string.find(string.lower(team.Name), "afk", 1, true) ~= nil
end

function Game.sameTeam(targetPlayer)
    if player.Team == nil or targetPlayer.Neutral then return false end
    if targetPlayer.Team == player.Team then return true end
    return targetPlayer.Team == nil and targetPlayer.TeamColor == player.TeamColor
end

function Game.teamAllows(targetPlayer, mode)
    if mode == "off" then return true end
    local same = Game.sameTeam(targetPlayer)
    if mode == "sameTeam" then return same end
    return not same
end

Game.teamModes = {["Enemies only"] = "enemies", ["Same team only"] = "sameTeam", Off = "off"}
Game.teamModeOptions = {"Enemies only", "Same team only", "Off"}

function Game.chargeFraction(targetPlayer)
    local charge = targetPlayer:FindFirstChild("Charge")
    if not charge then return 0 end
    local ok, value = pcall(function() return charge.Value / math.max(charge.MaxValue, 1) end)
    return ok and math.clamp(value, 0, 1) or 0
end

function Game.stat(targetPlayer, name)
    local stats = targetPlayer:FindFirstChild("Stats")
    local value = stats and stats:FindFirstChild(name)
    return value and value:IsA("ValueBase") and tonumber(value.Value) or 0
end

function Game.isBlocking(character)
    local blocking = character and character:FindFirstChild("Blocking")
    return blocking ~= nil and blocking:IsA("BoolValue") and blocking.Value
end

function Game.untouchable(character)
    if not character then return false end
    local root = character:FindFirstChild("HumanoidRootPart")
    if root and root.Anchored then return true end
    return character:FindFirstChild("i") ~= nil or character:FindFirstChild("FORCEFIELD") ~= nil
        or character:FindFirstChild("NoTarg") ~= nil
end

function Game.usingSkill(character)
    local skill = character and character:FindFirstChild("UsingSkill")
    if skill and skill:IsA("StringValue") then
        local name = skill.Value:match("^%s*(.-)%s*$")
        if name ~= "" then return name end
    end
    return nil
end

function Game.characterName(targetPlayer)
    local character = targetPlayer.Character
    return (character and character:GetAttribute("LastLoadedChar"))
        or targetPlayer:GetAttribute("LastLoadedChar") or "none"
end

local function moveSlot(move)
    local moveConfig = move:FindFirstChild(".Config")
    if not moveConfig then return nil end
    for _, child in ipairs(moveConfig:GetChildren()) do
        local number = tonumber(string.match(child.Name, "^Slot(%d+)$"))
        if number then return number end
    end
    return nil
end

local function moveProgress(move)
    local value = move:GetAttribute("COOLDOWN")
    return type(value) == "number" and math.clamp(value / 20, 0, 1) or 1
end

function Game.moves(targetPlayer)
    local backpack = targetPlayer:FindFirstChildOfClass("Backpack")
    local list = {}
    if not backpack then return list end
    for _, move in ipairs(backpack:GetChildren()) do
        if move:IsA("Configuration") then
            local progress = moveProgress(move)
            list[#list + 1] = {name = move.Name, slot = moveSlot(move) or 99, progress = progress, ready = progress >= 1}
        end
    end
    table.sort(list, function(a, b)
        if a.slot ~= b.slot then return a.slot < b.slot end
        return a.name < b.name
    end)
    return list
end

function Game.ownMoveReady(index)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return true end
    for _, move in ipairs(backpack:GetChildren()) do
        if move:IsA("Configuration") and moveSlot(move) == index then return moveProgress(move) >= 1 end
    end
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local button = playerGui and playerGui:FindFirstChild("HUD") and playerGui.HUD:FindFirstChild("Moves")
        and playerGui.HUD.Moves:FindFirstChild(tostring(index))
    local moveName = button and button:GetAttribute("MoveName")
    local move = type(moveName) == "string" and backpack:FindFirstChild(moveName)
    return not move or moveProgress(move) >= 1
end

local yuji = {
    blackFlash = supported, blackFlashLast = "waiting for move 2", blackFlashClicks = 0,
    divergent = supported, divergentLast = "waiting for move 1", divergentClicks = 0,
    skull = false, skullLast = "off", skullClicks = 0,
}
state.Yuji = yuji

local function divergentDelay()
    local measured = samplePing()
    local frameOverhead = math.max(0, timing.frame - 1 / 60)
    local delay = math.clamp(0.22 + timing.ping * 0.5 + timing.pingJitter * 0.5
        + frameOverhead + timing.frameJitter * 0.5, 0.18, 0.36)
    return delay, measured
end

local function humanDelay(maxMs) return math.random() * maxMs / 1000 end

local hitChance = {blackFlash = 100, yuji = 100, nanami = 100, kokushibo = 100}
state.HitChance = hitChance
local function rollHit(key) return math.random() * 100 < (hitChance[key] or 100) end

local characterConnections = {}
local function bindYuji(character)
    for _, connection in ipairs(characterConnections) do connection:Disconnect() end
    table.clear(characterConnections)
    local function hook(signal, callback) characterConnections[#characterConnections + 1] = signal:Connect(callback) end

    local divergentToken = 0
    hook(character:GetAttributeChangedSignal("UsingDivergentBlow"), function()
        divergentToken = divergentToken + 1
        local token = divergentToken
        if character:GetAttribute("UsingDivergentBlow") ~= true or not yuji.divergent then return end
        hideWindow()
        local delay, ping = divergentDelay()
        delay = delay + humanDelay(30) - 0.015
        yuji.divergentLast = string.format("timing %.0fms (ping %.0fms)", delay * 1000, ping * 1000)
        task.delay(delay, function()
            if not alive or not yuji.divergent or player.Character ~= character or token ~= divergentToken
                or character:GetAttribute("UsingDivergentBlow") ~= true or not Game.aliveRoot(character) then return end
            if not canInput() then yuji.divergentLast = "skipped (roblox not focused)" return end
            if not rollHit("yuji") then yuji.divergentLast = "left to you (hit chance)" return end
            local ok, reason = pcall(function()
                if holdClick then
                    mouse1press()
                    task.delay(0.12, function() pcall(mouse1release) end)
                else
                    click()
                end
            end)
            if ok then
                yuji.divergentClicks = yuji.divergentClicks + 1
                yuji.divergentLast = string.format("clicked after %.0fms (ping %.0fms)", delay * 1000, ping * 1000)
            else
                yuji.divergentLast = "click failed: " .. tostring(reason)
            end
        end)
    end)

    local blackFlashArmed, blackFlashToken, skullToken = false, 0, 0
    hook(character.ChildAdded, function(child)
        if child.Name == "UsingSkill" and child:IsA("StringValue") then
            local skill = Game.usingSkill(character)
            blackFlashToken = blackFlashToken + 1
            blackFlashArmed = skill == "Black Flash"
            if blackFlashArmed then
                if yuji.blackFlash then hideWindow() end
                local token = blackFlashToken
                task.delay(1.2, function() if token == blackFlashToken then blackFlashArmed = false end end)
            end
            if skill == "Skull Smash" and yuji.skull and supported then
                skullToken = skullToken + 1
                local token = skullToken
                yuji.skullLast = "timing (1.5s)"
                hideWindow()
                task.delay(1.5 + humanDelay(40), function()
                    if not alive or not yuji.skull or token ~= skullToken or player.Character ~= character
                        or Game.usingSkill(character) ~= "Skull Smash" or not Game.aliveRoot(character) then return end
                    if not canInput() then yuji.skullLast = "skipped (roblox not focused)" return end
                    if not rollHit("yuji") then yuji.skullLast = "left to you (hit chance)" return end
                    local ok, reason = pcall(click)
                    if ok then yuji.skullClicks = yuji.skullClicks + 1 yuji.skullLast = "clicked"
                    else yuji.skullLast = "click failed: " .. tostring(reason) end
                end)
            end
        elseif child.Name == "Action" and blackFlashArmed then
            blackFlashArmed = false
            if not alive or not yuji.blackFlash or not supported or player.Character ~= character
                or Game.usingSkill(character) ~= "Black Flash" or not Game.aliveRoot(character) then return end
            if not canInput() then yuji.blackFlashLast = "skipped (roblox not focused)" return end
            if not rollHit("yuji") then yuji.blackFlashLast = "left to you (hit chance)" return end
            local wait = humanDelay(35)
            task.delay(wait, function()
                if not alive or not yuji.blackFlash then return end
                local ok, reason = pcall(click)
                if ok then yuji.blackFlashClicks = yuji.blackFlashClicks + 1 yuji.blackFlashLast = string.format("clicked %.0fms after the cue", wait * 1000)
                else yuji.blackFlashLast = "click failed: " .. tostring(reason) end
            end)
        end
    end)
end
onCleanup(function()
    for _, connection in ipairs(characterConnections) do connection:Disconnect() end
    table.clear(characterConnections)
end)

local nanami = {enabled = correctGame, last = "waiting", hits = 0}
state.Nanami = nanami
do

    local tapWays = {
        mouse = function(x, y)
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(0.03)
            vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end,

        touch = function(x, y)
            local vim = game:GetService("VirtualInputManager")
            vim:SendTouchEvent(37, 0, x, y)
            task.wait(0.03)
            vim:SendTouchEvent(37, 2, x, y)
        end,
        native = function()
            if type(mouse1click) ~= "function" then error("no mouse1click") end
            mouse1click()
        end,
    }

    local touchDevice = UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled
    local tapOrder = touchDevice and {"touch", "mouse", "native"} or {"mouse", "touch", "native"}
    nanami.tapOrder = tapOrder
    nanami.touchDevice = touchDevice

    local latency = {mouse = 1, touch = 2, native = 1}
    nanami.latency = latency
    local frameCount, lastTapFrame = 0, -1
    connect(RunService.Heartbeat, function() frameCount = frameCount + 1 end)
    connect(UIS.InputBegan, function(input)
        local kind = input.UserInputType
        if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then lastTapFrame = frameCount end
    end)

    local function tap()
        local cam = workspace.CurrentCamera
        local size = cam and cam.ViewportSize or Vector2.new(800, 600)
        local tried = {}
        for i, way in ipairs(tapOrder) do
            local sentFrame = frameCount
            local sent, why = pcall(tapWays[way], size.X / 2, size.Y * 0.4)
            if sent then

                while lastTapFrame < sentFrame and frameCount - sentFrame < 4 do RunService.Heartbeat:Wait() end
                if lastTapFrame >= sentFrame then
                    latency[way] = math.clamp(lastTapFrame - sentFrame, 0, 4)

                    table.remove(tapOrder, i)
                    table.insert(tapOrder, 1, way)
                    return true, way
                end
                why = "the game didn't see it"
            end
            table.insert(tried, way .. ": " .. tostring(why))
        end
        return false, table.concat(tried, "; ")
    end

    local TARGET, WINDOW, MARGIN = 0.7, 0.02, 0.004
    local current, clicked = nil, setmetatable({}, {__mode = "k"})
    local lastX = setmetatable({}, {__mode = "k"})
    local waits = setmetatable({}, {__mode = "k"})
    local function inside(x) return math.abs(TARGET - x) < WINDOW - MARGIN end
    local function aiming()
        local character = player.Character
        return character ~= nil and character:GetAttribute("NANAMIAIM") == true
    end

    local seenAt = setmetatable({}, {__mode = "k"})
    connect(workspace.DescendantAdded, function(descendant)
        if descendant.Name == "NanamiCutGUI" and nanami.enabled then
            current = descendant
            seenAt[descendant] = os.clock()
        end
    end)
    connect(RunService.Heartbeat, function()
        local gui = current
        if not gui then return end
        if not alive or not nanami.enabled or not correctGame or not gui.Parent or clicked[gui] then
            if not gui.Parent then current = nil end
            return
        end
        if not aiming() then
            if os.clock() - (seenAt[gui] or 0) > 0.5 then current = nil end
            return
        end
        local cutter = gui:FindFirstChild("MainBar") and gui.MainBar:FindFirstChild("Cutter")
        if not cutter then return end
        hideWindow()
        local x = cutter.Position.X.Scale
        local prev = lastX[gui]
        lastX[gui] = x
        nanami.trace = nanami.trace or {}
        if not prev then table.clear(nanami.trace) end
        table.insert(nanami.trace, math.floor(x * 1000 + 0.5) / 1000)
        if not prev then return end
        if x > TARGET + WINDOW then
            clicked[gui] = true
            nanami.last = string.format("missed: the bar jumped past (%.3f after %.3f)", x, prev)
            return
        end
        local step = math.max(0, x - prev)
        local judged = (latency[tapOrder[1]] or 2) - 2
        local function at(n) return x + step * n end

        local leaving = not inside(at(judged + 1))
        if not inside(at(judged)) then

            if not (at(judged + 1) > TARGET and math.abs(TARGET - at(judged)) < WINDOW - 0.001) then return end
        end
        if not leaving and not inside(at(judged - 1)) then return end

        waits[gui] = waits[gui] or math.random(0, 2)
        if not leaving and waits[gui] > 0 and inside(at(judged + 2)) then waits[gui] = waits[gui] - 1 return end
        clicked[gui] = true
        if UIS:GetFocusedTextBox() then nanami.last = "skipped (typing)" return end
        if not rollHit("nanami") then nanami.last = "left to you (hit chance)" return end
        task.spawn(function()
            local ok, how = tap()
            if ok then nanami.hits = nanami.hits + 1 nanami.last = string.format("tapped at %.3f (%s, %d frame delay)", x, how, latency[how] or -1)
            else nanami.last = "tap failed: " .. how end
        end)
    end)
end

local anyBlackFlash = {enabled = supported, last = "waiting", clicks = 0}
state.AnyBlackFlash = anyBlackFlash
do
    local DIVE_START, DIVE_FLOOR, DIVE_RESET = 40, 15, 65
    local diving, clicked, minFov, lastFov = false, false, 70, 70
    connect(RunService.RenderStepped, function()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local fov = camera.FieldOfView
        if not diving then
            if fov < DIVE_START and fov < lastFov then
                diving, clicked, minFov = true, false, fov
                if anyBlackFlash.enabled then hideWindow() end
            end
        else
            if fov < minFov then
                minFov = fov
            elseif not clicked and minFov < DIVE_FLOOR and fov > minFov + 0.25 then
                clicked = true
                if alive and anyBlackFlash.enabled and supported then
                    if not canInput() then
                        anyBlackFlash.last = "skipped (roblox not focused)"
                    elseif not rollHit("blackFlash") then
                        anyBlackFlash.last = "left to you (hit chance)"
                    else
                        local wait = humanDelay(30)
                        task.delay(wait, function()
                            if not alive or not anyBlackFlash.enabled then return end
                            local ok, reason = pcall(click)
                            if ok then anyBlackFlash.clicks = anyBlackFlash.clicks + 1 anyBlackFlash.last = string.format("clicked at fov %.1f, +%.0fms", fov, wait * 1000)
                            else anyBlackFlash.last = "click failed: " .. tostring(reason) end
                        end)
                    end
                end
            end
            if fov >= DIVE_RESET then diving = false end
        end
        lastFov = fov
    end)
end

local kokushibo = {enabled = false, available = false, last = "waiting", hits = 0}
state.Kokushibo = kokushibo
do
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("KokushiboCheck")
    local original
    if remote and type(getcallbackvalue) == "function" then
        local ok, fn = pcall(getcallbackvalue, remote, "OnClientInvoke")
        if ok and type(fn) == "function" then original = fn end
    end
    kokushibo.available = original ~= nil and supported
    if kokushibo.available then
        local function rightClick()
            local context = player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("BaseContext")
            local action = context and context:FindFirstChild("Move5")
            if not (action and action:IsA("InputAction")) then return false end
            action:Fire(true)
            task.wait(0.05)
            action:Fire(false)
            return true
        end
        remote.OnClientInvoke = function(a1, a2, ...)
            local ours = false
            if alive and kokushibo.enabled and type(a1) == "number" and type(a2) == "number" and a2 > 0 then
                ours = true
                local lead, window = (a1 - a2) * 2, a2 * 2
                local at = lead + window * (0.25 + math.random() * 0.45)
                task.delay(at, function()
                    if not alive or not kokushibo.enabled then return end
                    if not rollHit("kokushibo") then kokushibo.last = "left to you (hit chance)" return end
                    if rightClick() then
                        kokushibo.last = string.format("pressed %.2fs into a %.2fs window", at - lead, window)
                    else
                        kokushibo.last = "couldn't find the right-click action"
                    end
                end)
            end
            local result = original(a1, a2, ...)
            if ours and result == true then kokushibo.hits = kokushibo.hits + 1 end
            return result
        end
        onCleanup(function() pcall(function() remote.OnClientInvoke = original end) end)
    end
end

local yusuke = {enabled = correctGame and canCheckOwner, available = correctGame and canCheckOwner,
    teamMode = "enemies", last = "waiting for a gun move", shots = 0}
state.Yusuke = yusuke
if yusuke.available then
    local armedUntil = 0
    local active = {}
    local function restore(ball, velocity)
        if ball.Parent then pcall(function() ball.AssemblyLinearVelocity = velocity end) end
    end
    onCleanup(function()
        for ball, velocity in pairs(active) do restore(ball, velocity) end
        table.clear(active)
    end)

    local function sweep(ball, character, root)
        local velocity = ball.AssemblyLinearVelocity
        active[ball] = velocity
        local ok, reason = pcall(function()
            local live = workspace:FindFirstChild("Live")
            if not live then return end
            local targets = {}
            for _, model in ipairs(live:GetChildren()) do
                local targetRoot, humanoid = Game.aliveRoot(model)
                local targetPlayer = Players:GetPlayerFromCharacter(model)
                if model ~= character and targetRoot
                    and (not targetPlayer or Game.teamAllows(targetPlayer, yusuke.teamMode)) then
                    targets[#targets + 1] = {root = targetRoot, humanoid = humanoid,
                        distance = (targetRoot.Position - root.Position).Magnitude}
                end
            end
            table.sort(targets, function(a, b) return a.distance < b.distance end)
            local started, visited = os.clock(), 0
            for _, target in ipairs(targets) do
                if not alive or not yusuke.enabled or not ball.Parent or player.Character ~= character
                    or os.clock() - started > 20 then break end
                if target.root.Parent and target.humanoid.Health > 0 then

                    for _ = 1, 5 do
                        if not ball.Parent or not target.root.Parent then break end
                        ball.CFrame = target.root.CFrame
                        ball.AssemblyLinearVelocity = Vector3.zero
                        task.wait(0.03)
                    end
                    visited = visited + 1
                end
            end
            yusuke.last = "hit " .. visited .. "/" .. #targets .. " targets"
        end)
        restore(ball, velocity)
        active[ball] = nil
        if not ok then yusuke.last = "stopped: " .. tostring(reason) end
    end

    local function onBall(ball)
        if not alive or not yusuke.enabled or os.clock() > armedUntil then return end
        if ball.Name ~= "Ball" or not ball:IsA("BasePart") or ball.Anchored then return end
        local character = player.Character
        local root = Game.aliveRoot(character)
        if not root or (ball.Position - root.Position).Magnitude > 25 then return end
        local ok, owned = pcall(isnetworkowner, ball)
        if not ok or not owned then yusuke.last = "skipped (no ownership)" return end
        armedUntil = 0
        yusuke.shots = yusuke.shots + 1
        task.spawn(sweep, ball, character, root)
    end

    local thrownConnection
    local function watchThrown(folder)
        if thrownConnection then thrownConnection:Disconnect() end
        thrownConnection = connect(folder.ChildAdded, onBall)
    end
    if workspace:FindFirstChild("Thrown") then watchThrown(workspace.Thrown) end
    connect(workspace.ChildAdded, function(child) if child.Name == "Thrown" then watchThrown(child) end end)

    local function bindGun(character)
        connect(character.ChildAdded, function(child)
            if child.Name ~= "UsingSkill" or not child:IsA("StringValue") then return end
            local skill = Game.usingSkill(character)
            local gunMove = skill == "Spirit Gun" or skill == "Demon Gun"
            local isYusuke = character:GetAttribute("LastLoadedChar") == "Yusuke Urameshi"
            armedUntil = (yusuke.enabled and isYusuke and gunMove) and (os.clock() + 3) or 0
        end)
    end
    if player.Character then bindGun(player.Character) end
    connect(player.CharacterAdded, bindGun)
else
    yusuke.enabled = false
    yusuke.last = "not available (needs isnetworkowner)"
end

local krillin = {enabled = correctGame, teamMode = "enemies", fallback = false,
    volleyGap = 0.35, holdTime = 0.40, volleys = 0, last = "waiting for kiblast"}
state.Krillin = krillin
do
    local seen = setmetatable({}, {__mode = "k"})
    local volleyTarget, lastCatch = nil, -math.huge

    local function candidates(applyTeam)
        local list = {}
        for _, targetPlayer in ipairs(Players:GetPlayers()) do
            if targetPlayer ~= player then
                local root = Game.aliveRoot(targetPlayer.Character)
                if root and (not applyTeam or Game.teamAllows(targetPlayer, krillin.teamMode)) then
                    list[#list + 1] = root
                end
            end
        end
        return list
    end

    local function rollTarget()
        local list = candidates(true)
        if #list == 0 and krillin.fallback then list = candidates(false) end
        volleyTarget = #list > 0 and list[math.random(1, #list)] or nil
        lastCatch = os.clock()
        krillin.volleys = krillin.volleys + 1
        krillin.last = volleyTarget and ("volley " .. krillin.volleys .. " -> " .. volleyTarget.Parent.Name) or "no target"
        return volleyTarget
    end

    local function liveTarget()
        if volleyTarget and Game.aliveRoot(volleyTarget.Parent) then return volleyTarget end
        return nil
    end

    local function hold(part)
        RunService.Heartbeat:Wait()
        local stopAt = os.clock() + krillin.holdTime
        while alive and krillin.enabled and part.Parent and os.clock() < stopAt do
            local target = liveTarget() or rollTarget()
            if not target then break end
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
            part.CFrame = target.CFrame
            RunService.Heartbeat:Wait()
        end
    end

    connect(workspace.DescendantAdded, function(part)
        if not krillin.enabled or seen[part] or not part:IsA("BasePart") then return end
        if not string.find(string.lower(part.Name), "kiblast", 1, true) then return end
        seen[part] = true
        if not liveTarget() or os.clock() - lastCatch > krillin.volleyGap then rollTarget() else lastCatch = os.clock() end
        task.spawn(hold, part)
    end)
end

local sweeps = {enabled = false, teamMode = "enemies", range = 250, frames = 6, last = "waiting for a move", casts = 0, hits = 0}
state.Sweeps = sweeps

sweeps.MOVES = {
    {key = "gaaraTsunami", name = "Gaara: Sand Tsunami", chars = {"Gaara"}, part = "Tsunami"},
    {key = "gaaraGreat", name = "Gaara: Great Tsunami", chars = {"Gaara"}, part = "GreatTsunami"},

    {key = "josephJeep", name = "Old Joseph: Jeep", chars = {"Old Joseph"}, part = "Jeep", model = true, hold = 0.2},
    {key = "josephBarrel", name = "Old Joseph: Barrel", chars = {"Old Joseph"}, part = "Barrel", hold = 0.34},
    {key = "ichigoGetsuga", name = "Ichigo: Getsuga", chars = {"Ichigo"}, part = "NewGetsuga"},
    {key = "grimmjowClaw", name = "Grimmjow: Panther Claw", chars = {"Grimmjow"}, part = "Bal"},
    {key = "akainuFist", name = "Akainu: Lava Fist", chars = {"Akainu"}, part = "Fist"},
    {key = "dekuSmash", name = "Deku: Delaware Smash", chars = {"Deku", "Vigilante Deku"}, part = "Ball"},
    {key = "bakugouBlast", name = "Bakugou: Gauntlet Blast", chars = {"Bakugou"}, part = "GauntletBlast"},
    {key = "gojoPurple", name = "Gojo: Hollow Purple", chars = {"Satoru Gojo", "[Legacy] Satoru Gojo"}, part = "Ball", hold = 0.34},
    {key = "rengokuTiger", name = "Rengoku: Flaming Tiger", chars = {"Kyojuro Rengoku"}, part = "@Fire"},
    {key = "kazumaArrow", name = "Kazuma: Sniper Arrow", chars = {"Kazuma"}, part = "KazumaArrow", hold = 0.34},
}
sweeps.on = {}
for _, move in ipairs(sweeps.MOVES) do sweeps.on[move.key] = true end
do
    local armedUntil = 0
    local busy = setmetatable({}, {__mode = "k"})

    local function myCharacterName()
        local character = player.Character
        return character and (character:GetAttribute("LastLoadedChar") or player:GetAttribute("LastLoadedChar")) or nil
    end

    local function partName(move)
        if move.part == "@Fire" then return player.Name .. "Fire" end
        return move.part
    end

    local function matches(move, name, charName)
        if not sweeps.on[move.key] or partName(move) ~= name then return false end

        for _, c in ipairs(move.chars) do
            if charName:sub(1, #c) == c then return true end
        end
        return false
    end

    local function targets(from)
        local list = {}
        local live = workspace:FindFirstChild("Live")
        if not live then return list end
        for _, model in ipairs(live:GetChildren()) do
            local root, humanoid = Game.aliveRoot(model)
            if root and model ~= player.Character and not model:FindFirstChild("NoTarg") then
                local owner = Players:GetPlayerFromCharacter(model) or Game.ownerOf(model)
                local ok
                if owner == player then ok = false
                elseif owner then ok = Game.teamAllows(owner, sweeps.teamMode) and not Game.onAfkTeam(owner)
                else ok = not model:HasTag("FRIENDLYDUMMY") end
                local distance = (root.Position - from).Magnitude
                if ok and distance <= sweeps.range then
                    list[#list + 1] = {root = root, humanoid = humanoid, distance = distance}
                end
            end
        end
        table.sort(list, function(a, b) return a.distance < b.distance end)
        return list
    end

    local function place(object, cframe)
        if object:IsA("Model") then
            object:PivotTo(cframe)
            for _, part in ipairs(object:GetDescendants()) do
                if part:IsA("BasePart") then part.AssemblyLinearVelocity = Vector3.zero end
            end
        else
            object.CFrame = cframe
            object.AssemblyLinearVelocity = Vector3.zero
        end
    end

    local function sweep(object, move)
        busy[object] = true
        local ok, reason = pcall(function()

            if move.model then task.wait(0.3) end
            local root = Game.ownRoot()
            if not root then return end
            local list = targets(root.Position)
            local visited, started = 0, os.clock()
            for _, target in ipairs(list) do
                if not alive or not sweeps.enabled or not object.Parent or os.clock() - started > 12 then break end
                if target.root.Parent and target.humanoid.Health > 0 then
                    local frames, untilTime = 0, move.hold and (os.clock() + move.hold) or nil
                    while object.Parent and target.root.Parent do
                        if untilTime then
                            if os.clock() >= untilTime then break end
                        elseif frames >= sweeps.frames then
                            break
                        end
                        place(object, target.root.CFrame)
                        frames = frames + 1
                        RunService.Heartbeat:Wait()
                    end
                    visited = visited + 1
                end
            end
            sweeps.hits = sweeps.hits + visited
            sweeps.last = ("%s: went through %d/%d"):format(move.name, visited, #list)
        end)
        busy[object] = nil
        if not ok then sweeps.last = "stopped: " .. tostring(reason) end
    end

    local function onThrown(object)
        if not alive or not sweeps.enabled or os.clock() > armedUntil or busy[object] then return end
        if not (object:IsA("BasePart") or object:IsA("Model")) then return end
        local charName = myCharacterName()
        if not charName then return end
        for _, move in ipairs(sweeps.MOVES) do
            if matches(move, object.Name, charName) then

                local root = Game.ownRoot()
                local pos = object:IsA("Model") and object:GetPivot().Position or object.Position
                if move.part ~= "@Fire" and root and (pos - root.Position).Magnitude > 40 then return end
                sweeps.casts = sweeps.casts + 1
                task.spawn(sweep, object, move)
                return
            end
        end
    end

    local thrownConnection
    local function watchThrown(folder)
        if thrownConnection then thrownConnection:Disconnect() end
        thrownConnection = connect(folder.ChildAdded, function(child) task.defer(onThrown, child) end)
    end
    if workspace:FindFirstChild("Thrown") then watchThrown(workspace.Thrown) end
    connect(workspace.ChildAdded, function(child) if child.Name == "Thrown" then watchThrown(child) end end)

    local function bind(character)
        connect(character.ChildAdded, function(child)
            if child.Name == "UsingSkill" then armedUntil = os.clock() + 4 end
        end)
    end
    if player.Character then bind(player.Character) end
    connect(player.CharacterAdded, bind)
end

local autoBlock = {enabled = false, range = 14, hold = 0.45, skipGuardbreaks = true, whileFarming = false,
    faceCheck = true, faceAngle = 75, pingComp = true, reactMs = 0, missChance = 0, letFinisher = false,
    last = "off", blocks = 0}
state.AutoBlock = autoBlock
do
    local CollectionService = game:GetService("CollectionService")
    local holdUntil, holding, pressedAt = 0, false, 0
    local watched = setmetatable({}, {__mode = "k"})

    local lastOwnAttack = -math.huge
    for _, name in ipairs({"MouseClick", "Move1", "Move2", "Move3", "Move4", "Move5"}) do
        local action = gameAction(name)
        if action then connect(action.Pressed, function() lastOwnAttack = os.clock() end) end
    end

    local function myRoot() return Game.ownRoot() end

    local function isEnemy(model)
        if model == player.Character then return false end
        local owner = Game.ownerOf(model)
        if owner == player then return false end
        if not owner then return not model:HasTag("FRIENDLYDUMMY") end
        return not Game.sameTeam(owner)
    end

    local function breaksGuard(model, skill)
        local owner = Game.ownerOf(model)
        local backpack = owner and owner:FindFirstChildOfClass("Backpack")
        local move = backpack and backpack:FindFirstChild(skill)
        return move ~= nil and CollectionService:HasTag(move, "Guardbreaks")
    end

    local quietUntil = 0

    local function trigger(model, root, seconds, reach, why)
        if not autoBlock.enabled or not alive or os.clock() < quietUntil then return end
        local mine = myRoot()
        if not mine or (root.Position - mine.Position).Magnitude > reach then return end
        if not isEnemy(model) then return end
        if not autoBlock.whileFarming and state.Bot and state.Bot.enabled then return end

        if autoBlock.faceCheck then
            local toMe = (mine.Position - root.Position) * Vector3.new(1, 0, 1)
            local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
            if toMe.Magnitude > 2 and look.Magnitude > 0.1 then
                local angle = math.deg(math.acos(math.clamp(look.Unit:Dot(toMe.Unit), -1, 1)))
                if angle > autoBlock.faceAngle then
                    autoBlock.last = model.Name .. " isn't facing you"
                    return
                end
            end
        end
        if autoBlock.missChance > 0 and math.random() * 100 < autoBlock.missChance then
            autoBlock.last = "let one through on purpose"
            return
        end

        if autoBlock.pingComp then seconds = seconds + timing.ping end
        local function arm()
            if not autoBlock.enabled or os.clock() < quietUntil then return end
            holdUntil = math.max(holdUntil, os.clock() + seconds)
            autoBlock.last = why
        end

        if autoBlock.reactMs > 0 then
            task.delay(autoBlock.reactMs / 1000 * (0.5 + math.random() * 0.5), arm)
        else
            arm()
        end
    end

    local chains = setmetatable({}, {__mode = "k"})
    local function chainHit(model)
        local chain = chains[model]
        if not chain or os.clock() - chain.last > 1 then
            chain = {count = 0}
            chains[model] = chain
        end
        chain.count = chain.count + 1
        chain.last = os.clock()
        if autoBlock.letFinisher and chain.count >= 5 then
            chain.count = 0
            holdUntil = 0
            quietUntil = os.clock() + 0.35
            autoBlock.last = "letting " .. model.Name .. "'s finisher through"
            return true
        end
        return false
    end

    local function watch(model)
        if watched[model] or model == player.Character then return end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if not (animator and root) then return end
        watched[model] = true
        connect(animator.AnimationPlayed, function(track)
            if track.Looped or os.clock() - lastOwnAttack < 0.5 then return end
            if chainHit(model) then return end
            trigger(model, root, autoBlock.hold, autoBlock.range, "blocking an attack from " .. model.Name)
        end)
        connect(model.ChildAdded, function(child)
            if child.Name ~= "UsingSkill" or not child:IsA("StringValue") then return end
            task.defer(function()
                local skill = Game.usingSkill(model)
                if not skill then return end
                if autoBlock.skipGuardbreaks and breaksGuard(model, skill) then
                    autoBlock.last = skill .. " breaks guard, not blocking"
                    return
                end
                trigger(model, root, 0.8, autoBlock.range * 2, "blocking " .. skill)
            end)
        end)
    end

    local live = workspace:FindFirstChild("Live")
    if live then
        for _, model in ipairs(live:GetChildren()) do pcall(watch, model) end
        connect(live.ChildAdded, function(model) task.defer(function() pcall(watch, model) end) end)
    end

    local function setBlock(on)
        local action = gameAction("Block")
        if action then action:Fire(on) end
    end

    connect(RunService.Heartbeat, function()
        local want = autoBlock.enabled and alive and os.clock() < holdUntil and myRoot() ~= nil
        local character = player.Character
        local blocking = character and Game.isBlocking(character)
        if want and not holding then
            holding, pressedAt = true, os.clock()
            setBlock(true)
            autoBlock.blocks = autoBlock.blocks + 1
        elseif not want and holding then
            holding = false
            setBlock(false)
        elseif want and holding and not blocking and os.clock() - pressedAt > 0.2 then

            setBlock(false)
            setBlock(true)
            pressedAt = os.clock()
        end
    end)

    autoBlock.SetEnabled = function(value)
        autoBlock.enabled = value == true and alive
        autoBlock.last = autoBlock.enabled and "watching" or "off"
        if not autoBlock.enabled and holding then
            holding = false
            setBlock(false)
        end
    end
    onCleanup(function()
        autoBlock.enabled = false
        if holding then holding = false setBlock(false) end
    end)
end

local bot = {enabled = false, sprint = true, dash = true, useMoves = true, reach = 10, last = "off", target = "none",
    dashes = 0, jumps = 0, targets = "Players", teamMode = "enemies", skipAfk = true, stick = true,
    lockCamera = true, aimMouse = false, targetPlayer = nil, awaken = true, smart = true, targetMode = "nearest", skipUlt = true,
    trade = true, jumpOver = true, trades = 0, escapes = 0}
state.Bot = bot
do
    local PathfindingService = game:GetService("PathfindingService")
    local CollectionService = game:GetService("CollectionService")
    local RENDER = "CatnAutoFarm"
    local CAMERA = "CatnAutoFarmCamera"
    local lockRoot = nil
    local moveDir = Vector3.zero
    local hazards, hazardsReady = {}, false
    local blocked = setmetatable({}, {__mode = "k"})
    local running = false
    local sprinting = false

    local damagedAt = setmetatable({}, {__mode = "k"})
    local watched = setmetatable({}, {__mode = "k"})
    local function watch(dummy)
        if watched[dummy.model] then return end
        watched[dummy.model] = true
        local last = dummy.humanoid.Health
        dummy.humanoid.HealthChanged:Connect(function(hp)
            if hp < last then damagedAt[dummy.model] = os.clock() end
            last = hp
        end)
    end

    local function solo() return #Players:GetPlayers() == 1 end

    local function thrown() return workspace:FindFirstChild("Thrown") end

    local function scanHazards()
        local found = {}
        local root = workspace:FindFirstChild("Map") or workspace
        local list = root:GetDescendants()
        for index, part in ipairs(list) do
            if part:IsA("BasePart") and part:FindFirstChildOfClass("TouchTransmitter") then
                local live = workspace:FindFirstChild("Live")
                if not (live and part:IsDescendantOf(live)) then
                    found[#found + 1] = part
                end
            end
            if index % 3000 == 0 then task.wait() end
        end
        hazards, hazardsReady = found, true
    end

    local function inHazard(pos)
        for _, part in ipairs(hazards) do
            if part.Parent then
                local p = part.CFrame:PointToObjectSpace(pos)
                local half = part.Size / 2
                if math.abs(p.X) <= half.X + 2.5 and math.abs(p.Z) <= half.Z + 2.5
                    and p.Y >= -half.Y - 2 and p.Y <= half.Y + 7 then
                    return part
                end
            end
        end
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    rayParams.RespectCanCollide = true
    local function refreshFilter()
        local ignore = {}
        if player.Character then ignore[#ignore + 1] = player.Character end
        if workspace:FindFirstChild("Live") then ignore[#ignore + 1] = workspace.Live end
        if thrown() then ignore[#ignore + 1] = thrown() end
        rayParams.FilterDescendantsInstances = ignore
    end

    local function safeAt(pos)
        local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), rayParams)
        if not hit then return false, "no floor" end
        local below = hit.Instance
        if below:FindFirstChildOfClass("TouchTransmitter") then return false, "pad: " .. below.Name end
        local hazard = inHazard(hit.Position)
        if hazard then return false, "near " .. hazard.Name end
        return true
    end

    local function dummies()
        local list = {}
        if bot.targets ~= "Dummies" then
            for _, targetPlayer in ipairs(Players:GetPlayers()) do
                if targetPlayer ~= player and Game.teamAllows(targetPlayer, bot.teamMode)
                    and not (bot.skipAfk and Game.onAfkTeam(targetPlayer))
                    and not (bot.skipUlt and Game.untouchable(targetPlayer.Character)) then
                    local root, humanoid = Game.aliveRoot(targetPlayer.Character)
                    if root then
                        list[#list + 1] = {model = targetPlayer.Character, root = root, humanoid = humanoid, player = targetPlayer}
                    end
                end
            end
        end
        if bot.targets == "Players" then return list end
        local live = workspace:FindFirstChild("Live")
        if not live then return list end
        for _, model in ipairs(live:GetChildren()) do
            local root, humanoid = Game.aliveRoot(model)
            if root and model ~= player.Character and not Game.ownerOf(model)
                and not model:FindFirstChild("NoTarg") and not model:HasTag("FRIENDLYDUMMY") then
                list[#list + 1] = {model = model, root = root, humanoid = humanoid}
            end
        end
        return list
    end

    local function cost(dummy, from)
        local distance = (dummy.root.Position - from).Magnitude
        if bot.targetMode == "nearest" then return distance end
        local speed = (dummy.root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
        local health = dummy.humanoid.Health / math.max(dummy.humanoid.MaxHealth, 1)
        return distance + speed * 0.6 + health * 15 + (Game.isBlocking(dummy.model) and 10 or 0)
    end

    local function pickTarget(from)
        local best, bestCost
        for _, dummy in ipairs(dummies()) do
            if os.clock() > (blocked[dummy.model] or 0) then
                local value = cost(dummy, from)
                if not bestCost or value < bestCost then best, bestCost = dummy, value end
            end
        end
        return best, bestCost
    end

    local function route(from, dummy)
        local center = dummy.root.Position
        local toward = (from - center) * Vector3.new(1, 0, 1)
        toward = toward.Magnitude > 0.1 and toward.Unit or Vector3.new(0, 0, 1)
        local goals = {}
        for _, angle in ipairs({0, 45, -45, 90, -90, 135, -135, 180}) do
            local rotated = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(toward)
            goals[#goals + 1] = center + rotated * 4
        end
        for _, goal in ipairs(goals) do
            if safeAt(goal) then
                local path = PathfindingService:CreatePath({AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = true,
                    WaypointSpacing = 4})
                local ok = pcall(function() path:ComputeAsync(from, goal) end)
                if ok and path.Status == Enum.PathStatus.Success then
                    local waypoints = path:GetWaypoints()
                    local clean = true
                    for _, waypoint in ipairs(waypoints) do

                        if (waypoint.Position - from).Magnitude > 6 and not safeAt(waypoint.Position) then clean = false break end
                    end
                    if clean then return waypoints end
                end
            end
        end
    end

    local function gameSetting(key)
        local ok, value = pcall(function()
            local genv = type(getrenv) == "function" and getrenv() or nil
            local g = genv and genv._G or _G
            if key == "Platform" then return g.Platform end
            return g.PlayerSettings and g.PlayerSettings[key]
        end)
        return ok and value or nil
    end
    local runOn, runHeld, lastRunPress = false, false, 0
    do
        local run = gameAction("Run")
        if run then
            connect(run.Pressed, function()
                if gameSetting("SprintMode") == "Toggle" then runOn = not runOn else runOn = true end
            end)
            connect(run.Released, function()
                if gameSetting("SprintMode") ~= "Toggle" then runOn = false end
            end)
        end

        connect(player.CharacterAdded, function() runOn, runHeld = false, false end)
    end
    local function setSprint(on)
        sprinting = on
        local action = gameAction("Run")
        if not action or gameSetting("Platform") == "Mobile" then return end

        local _, humanoid = Game.ownRoot()
        if on and humanoid and humanoid.WalkSpeed < 12 then return end
        if gameSetting("SprintMode") == "Toggle" then
            if runOn ~= on and os.clock() - lastRunPress > 1 then
                lastRunPress = os.clock()
                pcall(function()
                    action:Fire(true)
                    action:Fire(false)
                end)
            end
        elseif on ~= runHeld then
            runHeld = on
            pcall(function() action:Fire(on) end)
        end
    end

    local function sprintFor(dist)
        if not bot.sprint then setSprint(false)
        elseif dist > 9 then setSprint(true) end
    end

    local SINGLE_JUMP, DOUBLE_JUMP = 6, 13
    local jumpBusy = false
    local function jump(double)
        if jumpBusy or not Game.ownRoot() then return end
        jumpBusy = true
        bot.jumps = bot.jumps + 1
        task.spawn(function()
            tapAction("MobileJump")
            if double then
                local t = os.clock()
                while os.clock() - t < 0.6 do
                    task.wait()
                    local r = Game.ownRoot()
                    if not r then break end
                    if os.clock() - t > 0.22 and r.AssemblyLinearVelocity.Y < 10 then break end
                end
                tapAction("MobileJump")
            end
            task.wait(0.3)
            jumpBusy = false
        end)
    end

    local function feetY(rootPart)
        local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -7, 0), rayParams)
        return hit and hit.Position.Y or rootPart.Position.Y - 3, hit ~= nil
    end

    local function obstacle(rootPart, dir, reach)
        local feet = feetY(rootPart)
        local base = Vector3.new(rootPart.Position.X, feet, rootPart.Position.Z)
        local nearest
        for _, h in ipairs({0.9, 2.6, 4.6}) do
            local hit = workspace:Raycast(base + Vector3.new(0, h, 0), dir * reach, rayParams)
            if hit and hit.Normal.Y < 0.6 then
                local d = ((hit.Position - base) * Vector3.new(1, 0, 1)).Magnitude
                nearest = math.min(nearest or math.huge, d)
            end
        end
        if not nearest then return nil end

        local top
        for _, extra in ipairs({0.35, 1.5}) do
            local spot = base + dir * (nearest + extra)
            local down = workspace:Raycast(spot + Vector3.new(0, 24, 0), Vector3.new(0, -24, 0), rayParams)
            local y = down and down.Position.Y or math.huge
            top = math.max(top or -math.huge, y)
        end
        return top - feet, nearest
    end

    local function canHop(rootPart, dir, height, distance)
        if not bot.jumpOver or height > DOUBLE_JUMP then return nil end
        local feet = feetY(rootPart)
        local over = Vector3.new(rootPart.Position.X, feet + height + 3.5, rootPart.Position.Z)
        if workspace:Raycast(over, dir * (distance + 6), rayParams) then return nil end
        local far = rootPart.Position + dir * (distance + 5)
        if not safeAt(far) then return nil end
        return height > SINGLE_JUMP
    end

    local function gapLanding(rootPart, dir)
        local feet = feetY(rootPart)
        for d = 6, 14, 2 do
            local spot = rootPart.Position + dir * d
            local hit = workspace:Raycast(spot + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), rayParams)
            if hit and math.abs(hit.Position.Y - feet) < 4 and safeAt(spot) then

                if not workspace:Raycast(Vector3.new(rootPart.Position.X, feet + 4, rootPart.Position.Z), dir * d, rayParams) then
                    return d
                end
            end
        end
    end

    local lastDash = -math.huge
    local function tryDash(rootPart, targetPos)
        if not bot.dash or os.clock() - lastDash < 2.5 then return end
        local offset = (targetPos - rootPart.Position) * Vector3.new(1, 0, 1)
        local distance = offset.Magnitude
        if distance < 14 or distance > 40 then return end
        if workspace:Raycast(rootPart.Position, offset, rayParams) then return end
        for step = 1, 4 do
            if not safeAt(rootPart.Position + offset * (step / 4)) then return end
        end
        lastDash = os.clock()
        bot.dashes = bot.dashes + 1
        rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + offset.Unit)
        tapAction("Dodge")
    end

    local M1_REACH = 9.5

    local lastSwing, lastMove, lastAwaken = 0, 0, 0

    local function guardBreaker(index)
        local backpack = player:FindFirstChildOfClass("Backpack")
        if not backpack then return false end
        for _, move in ipairs(backpack:GetChildren()) do
            if move:IsA("Configuration") and moveSlot(move) == index then
                return CollectionService:HasTag(move, "Guardbreaks")
            end
        end
        return false
    end

    local function face(dummy, rootPart)
        local look = Vector3.new(dummy.root.Position.X, rootPart.Position.Y, dummy.root.Position.Z)
        if (look - rootPart.Position).Magnitude > 0.5 then rootPart.CFrame = CFrame.lookAt(rootPart.Position, look) end
    end

    local function readyMove(blocking)
        for index = 1, 4 do
            if Game.ownMoveReady(index) and (not blocking or guardBreaker(index)) then return index end
        end
    end

    local trade = {swingAt = -math.huge, model = nil, blockUntil = 0, hitsOnMe = {}, lastEscape = -math.huge,
        landed = 0, landedAt = -math.huge, followUntil = 0}
    local tradeWatched = setmetatable({}, {__mode = "k"})

    local M1_ANIMS = {["1461128166"] = 1, ["1461128859"] = 2, ["1461136273"] = 3, ["1461136875"] = 4, ["1461137417"] = 5}

    local FLINCH_ANIMS = {["1461138523"] = true, ["1461139102"] = true, ["1461140455"] = true, ["1461142361"] = true}
    local function watchSwings(dummy)
        if tradeWatched[dummy.model] then return end
        local animator = dummy.humanoid:FindFirstChildOfClass("Animator")
        if not animator then return end
        tradeWatched[dummy.model] = true
        local model = dummy.model
        connect(animator.AnimationPlayed, function(track)
            if track.Looped or trade.model ~= model then return end
            local id = track.Animation and tostring(track.Animation.AnimationId):match("%d+$")
            if not id or FLINCH_ANIMS[id] or track.Length > 1.5 then return end
            trade.swingAt, trade.swingHit = os.clock(), M1_ANIMS[id] or 0
        end)
        local last = dummy.humanoid.Health
        connect(dummy.humanoid.HealthChanged, function(hp)
            if hp < last and trade.model == model and os.clock() - lastSwing < 0.6 then
                if os.clock() - trade.landedAt > 1 then trade.landed = 0 end
                trade.landed = trade.landed + 1
                trade.landedAt = os.clock()
                if trade.landed >= 5 then
                    trade.landed = 0
                    trade.followUntil = os.clock() + 1.2
                end
            end
            last = hp
        end)
    end
    local myHumanoid = nil
    local function watchMe()
        local _, humanoid = Game.ownRoot()
        if not humanoid or myHumanoid == humanoid then return end
        myHumanoid = humanoid
        local last = humanoid.Health
        connect(humanoid.HealthChanged, function(hp)
            if hp < last - 0.5 then
                table.insert(trade.hitsOnMe, os.clock())
                if #trade.hitsOnMe > 8 then table.remove(trade.hitsOnMe, 1) end
            end
            last = hp
        end)
    end
    local function recentHitsOnMe(window)
        local n = 0
        for _, t in ipairs(trade.hitsOnMe) do if os.clock() - t < window then n = n + 1 end end
        return n
    end
    local function facingMe(dummy, rootPart)
        local toMe = (rootPart.Position - dummy.root.Position) * Vector3.new(1, 0, 1)
        local look = dummy.root.CFrame.LookVector * Vector3.new(1, 0, 1)
        if toMe.Magnitude < 1 or look.Magnitude < 0.1 then return true end
        return look.Unit:Dot(toMe.Unit) > 0.35
    end

    local function defend(dummy, rootPart, dist)
        if not bot.trade then return false end
        if os.clock() < trade.blockUntil then return true end

        if player.Character and Game.isBlocking(player.Character) then
            trade.wasBlocking = true
            return true
        end
        if trade.wasBlocking then
            trade.wasBlocking = false
            if dist <= M1_REACH and not Game.isBlocking(dummy.model) then
                bot.trades = bot.trades + 1
                bot.last = "hitting " .. dummy.model.Name .. " back after a block"
                lastSwing = os.clock()
                task.spawn(tapAction, "MouseClick")
                return true
            end
        end

        if recentHitsOnMe(1) >= 2 and os.clock() - trade.landedAt > 0.8 and os.clock() - trade.lastEscape > 3 and bot.dash then
            local away = (rootPart.Position - dummy.root.Position) * Vector3.new(1, 0, 1)
            local side = away.Magnitude > 0.1
                and CFrame.Angles(0, math.rad(math.random() < 0.5 and 60 or -60), 0):VectorToWorldSpace(away.Unit)
                or rootPart.CFrame.RightVector
            if safeAt(rootPart.Position + side * 10) then
                trade.lastEscape = os.clock()
                bot.escapes = bot.escapes + 1
                rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + side)
                task.spawn(tapAction, "Dodge")
                bot.last = "getting out of " .. dummy.model.Name .. "'s combo"
                return true
            end
        end

        local blockAction = gameAction("Block")
        local since = os.clock() - trade.swingAt
        if since < 0.2 and trade.swingHit == 5 and dist <= M1_REACH + 2 and bot.dash
            and os.clock() - trade.lastEscape > 1.5 and facingMe(dummy, rootPart) then

            trade.swingAt = -math.huge
            local away = (rootPart.Position - dummy.root.Position) * Vector3.new(1, 0, 1)
            local side = away.Magnitude > 0.1
                and CFrame.Angles(0, math.rad(math.random() < 0.5 and 75 or -75), 0):VectorToWorldSpace(away.Unit)
                or rootPart.CFrame.RightVector
            if safeAt(rootPart.Position + side * 10) then
                trade.lastEscape = os.clock()
                bot.escapes = bot.escapes + 1
                rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + side)
                task.spawn(tapAction, "Dodge")
                bot.last = "dodging " .. dummy.model.Name .. "'s finisher"
                return true
            end
        end
        if since < 0.2 and trade.swingHit ~= 5 and dist <= M1_REACH + 2
            and facingMe(dummy, rootPart) and blockAction
            and not (autoBlock.enabled and autoBlock.whileFarming) then
            trade.swingAt = -math.huge
            local hold = 0.32 + timing.ping
            trade.blockUntil = os.clock() + hold + 0.05
            bot.trades = bot.trades + 1
            bot.last = "blocking " .. dummy.model.Name .. "'s swing, then hitting back"
            task.spawn(function()
                pcall(function() blockAction:Fire(true) end)
                task.wait(hold)
                pcall(function() blockAction:Fire(false) end)

                lastSwing = os.clock()
                tapAction("MouseClick")
            end)
            return true
        end
        return false
    end

    local function attack(dummy, rootPart, dist)
        face(dummy, rootPart)
        trade.model = dummy.model
        watchSwings(dummy)
        watchMe()
        if defend(dummy, rootPart, dist) then return end
        local blocking = bot.smart and Game.isBlocking(dummy.model)
        if bot.awaken and dist <= M1_REACH and Game.chargeFraction(player) >= 1 and os.clock() - lastAwaken > 3 then
            lastAwaken = os.clock()
            task.spawn(tapAction, "UseMode")
            return
        end
        if bot.useMoves and dist <= bot.reach and os.clock() - lastMove > 1 then
            local index = readyMove(blocking)
            if index then
                lastMove = os.clock()
                task.spawn(tapAction, "Move" .. index)
                return
            end
        end
        if dist <= M1_REACH and not blocking and os.clock() - lastSwing > 0.28 then
            lastSwing = os.clock()
            task.spawn(tapAction, "MouseClick")
        end
    end

    local function clearLine(from, to)
        local offset = (to - from) * Vector3.new(1, 0, 1)
        if offset.Magnitude < 1 then return true end
        if workspace:Raycast(from, offset, rayParams) then

            local rootPart = Game.ownRoot()
            if not (rootPart and (rootPart.Position - from).Magnitude < 1) then return false end
            local dir = offset.Unit
            local height, distance = obstacle(rootPart, dir, offset.Magnitude)
            if not height or canHop(rootPart, dir, height, distance) == nil then return false end

            local past = from + dir * (distance + 3)
            local rest = (to - past) * Vector3.new(1, 0, 1)
            if rest:Dot(dir) > 0 and workspace:Raycast(past, rest, rayParams) then return false end
        end
        local steps = math.clamp(math.floor(offset.Magnitude / 6), 1, 12)
        for step = 1, steps do
            if not safeAt(from + offset * (step / steps)) then return false end
        end
        return true
    end

    local function firstAhead(waypoints, from)
        local best, bestDistance = 1, math.huge
        for i, waypoint in ipairs(waypoints) do
            local distance = ((waypoint.Position - from) * Vector3.new(1, 0, 1)).Magnitude
            if distance < bestDistance then best, bestDistance = i, distance end
        end
        return math.min(best + 1, #waypoints)
    end

    local function loop()
        local path, index, pathTarget, pathAt, pathFrom = nil, 1, nil, 0, nil
        local clear, clearAt = false, 0
        local lastNearestCheck = 0
        local stuckFrom, stuckAt, jumps = nil, os.clock(), 0
        local fightTarget, fightStart = nil, 0
        local chaseTarget, chaseStart = nil, 0
        local failStreak = 0
        local jumpedAt = nil
        local skipAt = 0
        while bot.enabled and alive do
            local rootPart, humanoid = Game.ownRoot()
            if not rootPart then
                moveDir = Vector3.zero
                bot.last = "waiting to respawn"
                task.wait(0.5)
            elseif state.Spawner and state.Spawner.InLobby() then

                moveDir = Vector3.zero
                setSprint(false)
                pathTarget, path = nil, nil
                bot.target, bot.targetPlayer, lockRoot = "none", nil, nil
                bot.last = state.Spawner.enabled and "in the lobby, Auto spawn is putting you back in"
                    or "in the lobby (turn on Auto spawn to go back in by itself)"
                task.wait(0.5)
            elseif bot.targets == "Dummies" and not solo() then
                moveDir = Vector3.zero
                setSprint(false)
                bot.last = "paused (other players in the server)"
                task.wait(0.5)
            else
                refreshFilter()

                local keep = pathTarget and pathTarget.model.Parent and pathTarget.humanoid.Health > 0
                    and (not pathTarget.player or (pathTarget.player.Parent == Players
                        and Game.teamAllows(pathTarget.player, bot.teamMode)
                        and not (bot.skipAfk and Game.onAfkTeam(pathTarget.player))))
                    and not (bot.skipUlt and Game.untouchable(pathTarget.model))
                if keep and bot.targetMode == "nearest" then

                    if os.clock() - lastNearestCheck > 0.1 then
                        lastNearestCheck = os.clock()
                        local best = pickTarget(rootPart.Position)
                        if best and best.model ~= pathTarget.model then
                            local current = (pathTarget.root.Position - rootPart.Position).Magnitude
                            if current - (best.root.Position - rootPart.Position).Magnitude > 1 then keep = false end
                        end
                    end
                elseif keep and os.clock() - lastNearestCheck > 0.5 and os.clock() - chaseStart > 1.5 then

                    lastNearestCheck = os.clock()
                    local best, bestCost = pickTarget(rootPart.Position)
                    if best and best.model ~= pathTarget.model then
                        local current = cost(pathTarget, rootPart.Position)
                        if bestCost < current * (bot.targetMode == "stay" and 0.5 or 0.8) then keep = false end
                    end
                end

                if keep and bot.targetMode ~= "nearest" and chaseTarget == pathTarget.model and os.clock() - chaseStart > 8 then
                    blocked[pathTarget.model] = os.clock() + 6
                    bot.last = pathTarget.model.Name .. " keeps getting away, switching"
                    keep, chaseTarget = false, nil
                end
                local dummy = keep and pathTarget or pickTarget(rootPart.Position)
                if not dummy or failStreak >= 3 then
                    failStreak = 0
                    moveDir = Vector3.zero
                    bot.target = "none"
                    bot.targetPlayer, lockRoot = nil, nil

                    local escape
                    for _, radius in ipairs({10, 18, 28}) do
                        for angle = 0, 315, 45 do
                            local spot = rootPart.Position + CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(Vector3.new(0, 0, -radius))
                            if safeAt(spot) and not workspace:Raycast(rootPart.Position, spot - rootPart.Position, rayParams) then
                                escape = spot
                                break
                            end
                        end
                        if escape then break end
                    end
                    if escape then
                        bot.last = "nothing reachable from here, moving to open ground"
                        local t = os.clock()
                        while bot.enabled and os.clock() - t < 3 do
                            local r = Game.ownRoot()
                            if not r then break end
                            local to = (escape - r.Position) * Vector3.new(1, 0, 1)
                            if to.Magnitude < 2 then break end
                            moveDir = to.Unit
                            RunService.Heartbeat:Wait()
                        end
                        moveDir = Vector3.zero
                        table.clear(blocked)
                    else
                        bot.last = "no dummy it can reach safely"
                    end
                    task.wait(0.5)
                else
                    bot.target = dummy.model.Name
                    bot.targetPlayer, lockRoot = dummy.player, dummy.root
                    local gap = (dummy.root.Position - rootPart.Position) * Vector3.new(1, 0, 1)
                    local dist = gap.Magnitude
                    local level = math.abs(dummy.root.Position.Y - rootPart.Position.Y) < 8
                    watch(dummy)
                    if chaseTarget ~= dummy.model then chaseTarget, chaseStart = dummy.model, os.clock() end
                    if dist <= M1_REACH and level then

                        path = nil
                        chaseStart = os.clock()
                        sprintFor(dist)
                        if fightTarget ~= dummy.model then fightTarget, fightStart = dummy.model, os.clock() end
                        local patience = dummy.player and 8 or 4
                        if os.clock() - fightStart > patience and (damagedAt[dummy.model] or 0) < fightStart then

                            blocked[dummy.model] = os.clock() + (dummy.player and 10 or 30)
                            pathTarget, fightTarget = nil, nil
                            moveDir = Vector3.zero
                            bot.last = dummy.model.Name .. " isn't taking damage, moving on"
                        else
                            bot.last = "fighting " .. dummy.model.Name
                            pathTarget = dummy

                            local ahead = dummy.root.Position + dummy.root.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * 0.15
                            local to = (ahead - rootPart.Position) * Vector3.new(1, 0, 1)
                            local dir = to.Magnitude > 0.1 and to.Unit or Vector3.zero
                            if to.Magnitude > 3.5 and safeAt(rootPart.Position + dir * 3) then moveDir = dir else moveDir = Vector3.zero end
                            attack(dummy, rootPart, dist)
                        end
                    else

                        if os.clock() - clearAt > 0.2 then
                            clear, clearAt = clearLine(rootPart.Position, dummy.root.Position), os.clock()
                        end
                        if os.clock() < trade.followUntil and clear and dist > 8 and dist < 40 then

                            trade.followUntil = 0
                            lastDash = -math.huge
                            tryDash(rootPart, dummy.root.Position)
                        end
                        local direct = false
                        if clear then

                            local velocity = dummy.root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
                            local lead = Vector3.zero
                            if velocity.Magnitude > 2 and velocity.Unit:Dot(gap.Unit) > 0.5 then
                                lead = velocity * 0.2
                                if lead.Magnitude > 4 then lead = lead.Unit * 4 end
                            end
                            local aim = (dummy.root.Position + lead - rootPart.Position) * Vector3.new(1, 0, 1)
                            local dir = aim.Magnitude > 0.1 and aim.Unit or gap.Unit
                            local aheadSafe, why = safeAt(rootPart.Position + dir * 3)
                            if not aheadSafe and why == "no floor" and bot.jumpOver then

                                local landing = gapLanding(rootPart, dir)
                                if landing then
                                    aheadSafe = true
                                    local _, grounded = feetY(rootPart)
                                    if grounded then jump(landing > 8) end
                                end
                            end
                            if aheadSafe then
                                local height, distance = obstacle(rootPart, dir, 6)
                                if height and height > 1.2 and distance < (height > SINGLE_JUMP and 5 or 3.5) then
                                    local double = canHop(rootPart, dir, height, distance)
                                    if double ~= nil then jump(double) end
                                end
                                direct = true
                                path, pathTarget = nil, dummy
                                failStreak = 0
                                moveDir = dir
                                sprintFor(dist)
                                tryDash(rootPart, dummy.root.Position)
                                bot.last = ("running to %s (%d studs)"):format(dummy.model.Name, dist)
                            else
                                clear, clearAt = false, os.clock()
                            end
                        end
                        if not direct then

                            local moved = pathFrom ~= nil and (dummy.root.Position - pathFrom).Magnitude > 6
                            if not path or dummy ~= pathTarget or moved or os.clock() - pathAt > (dummy.player and 1 or 1.5) then
                                path, pathTarget, pathAt = route(rootPart.Position, dummy), dummy, os.clock()
                                pathFrom = dummy.root.Position
                                if path then
                                    index = firstAhead(path, rootPart.Position)
                                else
                                    blocked[dummy.model] = os.clock() + 10
                                    failStreak = failStreak + 1
                                    pathTarget = nil
                                    bot.last = "no safe way to " .. dummy.model.Name .. ", trying another"
                                end
                            end
                            if path then
                                failStreak = 0
                                local waypoint = path[index]
                                if not waypoint then
                                    path = nil
                                else

                                    if os.clock() - skipAt > 0.15 then
                                        skipAt = os.clock()
                                        for j = math.min(#path, index + 8), index + 1, -1 do
                                            local w = path[j]
                                            if w.Action ~= Enum.PathWaypointAction.Jump
                                                and math.abs(w.Position.Y - waypoint.Position.Y) < 3
                                                and clearLine(rootPart.Position, w.Position) then
                                                index = j
                                                waypoint = w
                                                break
                                            end
                                        end
                                    end
                                    local toPoint = (waypoint.Position - rootPart.Position) * Vector3.new(1, 0, 1)
                                    if toPoint.Magnitude < 2.5 then
                                        index = index + 1
                                    else

                                        if waypoint.Action == Enum.PathWaypointAction.Jump and jumpedAt ~= waypoint then
                                            jumpedAt = waypoint
                                            jump(waypoint.Position.Y - feetY(rootPart) > SINGLE_JUMP - 1)
                                        else
                                            local height, distance = obstacle(rootPart, toPoint.Unit, 4)
                                            if height and height > 1.2 and distance < 3.5
                                                and canHop(rootPart, toPoint.Unit, height, distance) ~= nil then
                                                jump(height > SINGLE_JUMP)
                                            end
                                        end
                                        local dir = toPoint.Unit

                                        if not safeAt(rootPart.Position + dir * 3) then
                                            moveDir, path = Vector3.zero, nil
                                            bot.last = "stopped short of a hazard, rerouting"
                                        else
                                            moveDir = dir
                                            sprintFor(dist)
                                            bot.last = ("running to %s (%d studs, around something)"):format(dummy.model.Name, dist)
                                        end
                                    end
                                end
                            end
                        end

                        if level and (dist <= M1_REACH + 1 or (bot.reach > M1_REACH and dist <= bot.reach and clear)) then
                            attack(dummy, rootPart, dist)
                        end

                        if not stuckFrom or (rootPart.Position - stuckFrom).Magnitude > 1.5 then
                            stuckFrom, stuckAt, jumps = rootPart.Position, os.clock(), 0
                        elseif moveDir.Magnitude > 0 and os.clock() - stuckAt > 0.8 then
                            jumps = jumps + 1
                            jump(jumps >= 2)
                            stuckAt = os.clock()
                            if jumps >= 3 then path, jumps, clear, clearAt = nil, 0, false, os.clock() end
                        end
                    end
                end
                RunService.Heartbeat:Wait()
            end
        end
        moveDir = Vector3.zero
        setSprint(false)
    end

    local function lockOn()
        if not bot.enabled or not lockRoot or not lockRoot.Parent then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local aim = lockRoot.Position + Vector3.new(0, 1, 0)
        if bot.lockCamera then
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, aim)
        end
        if bot.aimMouse and canAimMouse and canInput() then
            local point, onScreen = camera:WorldToViewportPoint(aim)
            if onScreen then
                local inset = game:GetService("GuiService"):GetGuiInset()
                pcall(mousemoveabs, math.floor(point.X + inset.X), math.floor(point.Y + inset.Y))
            end
        end
    end

    local function bind()
        pcall(function() RunService:UnbindFromRenderStep(CAMERA) end)

        RunService:BindToRenderStep(CAMERA, Enum.RenderPriority.Camera.Value + 1, lockOn)
        pcall(function() RunService:UnbindFromRenderStep(RENDER) end)
        RunService:BindToRenderStep(RENDER, Enum.RenderPriority.Character.Value + 1, function()
            if not bot.enabled then return end
            local _, humanoid = Game.ownRoot()
            if not humanoid then return end
            humanoid:Move(moveDir, false)
        end)
    end

    bot.SetEnabled = function(value)
        bot.enabled = value == true and alive and correctGame
        if not bot.enabled then
            moveDir = Vector3.zero
            setSprint(false)
            pcall(function() RunService:UnbindFromRenderStep(RENDER) end)
            pcall(function() RunService:UnbindFromRenderStep(CAMERA) end)
            bot.last, bot.target, bot.targetPlayer, lockRoot = "off", "none", nil, nil
            return
        end
        bind()
        if running then return end
        running = true
        task.spawn(function()
            if not hazardsReady then
                bot.last = "mapping hazards"
                pcall(scanHazards)
            end
            local ok, reason = pcall(loop)
            if not ok then bot.last = "stopped: " .. tostring(reason) end
            running = false
        end)
    end

    onCleanup(function()
        bot.enabled = false
        moveDir = Vector3.zero
        setSprint(false)
        pcall(function() RunService:UnbindFromRenderStep(RENDER) end)
        pcall(function() RunService:UnbindFromRenderStep(CAMERA) end)
    end)
end

local rejoin = {enabled = false, loader = "", last = "off"}
state.Rejoin = rejoin
do
    local GuiService = game:GetService("GuiService")
    local busy = false
    local function go(message)
        if busy or not rejoin.enabled or not alive then return end
        busy = true
        rejoin.last = "disconnected: " .. tostring(message):sub(1, 60)
        task.wait(1)
        if rejoin.loader ~= "" and type(queue_on_teleport) == "function" then
            pcall(queue_on_teleport, rejoin.loader)
        end
        for attempt = 1, 10 do
            if not alive then break end
            rejoin.last = "rejoining (try " .. attempt .. ")"
            pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
            task.wait(8)
        end
        busy = false
    end
    connect(GuiService.ErrorMessageChanged, function(message)
        if message and message ~= "" then task.spawn(go, message) end
    end)
end

local COLORS = {
    barBack = Color3.fromRGB(20, 20, 24),
    ready = Color3.fromRGB(110, 220, 120), charging = Color3.fromRGB(240, 170, 60),
    mode = Color3.fromRGB(150, 110, 240), modeReady = Color3.fromRGB(255, 215, 70),
    hpLow = Color3.fromRGB(235, 70, 70), hpHigh = Color3.fromRGB(110, 220, 120),
    text = Color3.fromRGB(230, 230, 230), dim = Color3.fromRGB(160, 160, 160),
}

local function makeBar(parent, height, order)
    local back = make("Frame", {BackgroundColor3 = COLORS.barBack, BackgroundTransparency = 0.25,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, height), LayoutOrder = order or 0}, parent)
    make("UICorner", {CornerRadius = UDim.new(0, 2)}, back)
    local fill = make("Frame", {BorderSizePixel = 0, Size = UDim2.fromScale(1, 1)}, back)
    make("UICorner", {CornerRadius = UDim.new(0, 2)}, fill)
    return back, fill
end

local function makeText(parent, props)
    props.BackgroundTransparency = 1
    props.Font = props.Font or Enum.Font.Gotham
    props.TextStrokeTransparency = props.TextStrokeTransparency or 0.4
    props.TextColor3 = props.TextColor3 or COLORS.text
    return make("TextLabel", props, parent)
end

local function makeMoveRows(parent, count, firstOrder, nameWidth, textSize)
    local rows = {}
    for index = 1, count do
        local row = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, textSize + 1),
            LayoutOrder = firstOrder + index, Visible = false}, parent)
        local label = makeText(row, {Size = UDim2.new(nameWidth, -4, 1, 0), TextSize = textSize,
            TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd})
        local back, fill = makeBar(row, 5)
        back.AnchorPoint = Vector2.new(1, 0.5)
        back.Position = UDim2.fromScale(1, 0.5)
        back.Size = UDim2.new(1 - nameWidth, 0, 0, 5)
        rows[index] = {row = row, label = label, fill = fill}
    end
    return rows
end

local function paintMoves(rows, moves)
    for index, row in ipairs(rows) do
        local move = moves[index]
        row.row.Visible = move ~= nil
        if move then
            row.label.Text = move.name
            row.label.TextColor3 = move.ready and COLORS.text or COLORS.dim
            row.fill.Size = UDim2.fromScale(move.progress, 1)
            row.fill.BackgroundColor3 = move.ready and COLORS.ready or COLORS.charging
        end
    end
end

local function healthColor(fraction) return COLORS.hpLow:Lerp(COLORS.hpHigh, fraction) end

local esp = {
    enabled = false, shown = 0,
    outline = true, fill = true, labels = true, distance = true,
    healthBar = true, modeBar = true, cooldowns = true,
    hideTeammates = true, hideAfk = true, teamColors = true,
    limitDistance = false, maxDistance = 1500,
    enemyColor = Color3.fromRGB(235, 87, 87), allyColor = Color3.fromRGB(87, 180, 235),
}
state.ESP = esp
do
    local container = make("Folder", {Name = "BPHubESP"}, hiddenGuiParent())
    local entries = {}
    onCleanup(function() container:Destroy() table.clear(entries) end)

    local function removeEntry(targetPlayer)
        local entry = entries[targetPlayer]
        if not entry then return end
        entry.highlight:Destroy()
        entry.billboard:Destroy()
        entries[targetPlayer] = nil
    end

    local function getEntry(targetPlayer)
        if entries[targetPlayer] then return entries[targetPlayer] end
        local highlight = make("Highlight", {DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false}, container)
        local billboard = make("BillboardGui", {AlwaysOnTop = true, Enabled = false, Size = UDim2.fromOffset(150, 120),
            StudsOffset = Vector3.new(0, 2.6, 0), SizeOffset = Vector2.new(0, 0.5), LightInfluence = 0,
            ResetOnSpawn = false}, container)
        local holder = make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, billboard)
        make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2),
            VerticalAlignment = Enum.VerticalAlignment.Bottom}, holder)
        local entry = {highlight = highlight, billboard = billboard}
        entry.name = makeText(holder, {Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Font = Enum.Font.GothamBold,
            TextSize = 13, TextStrokeTransparency = 0.35})
        entry.healthBack, entry.healthFill = makeBar(holder, 5, 2)
        entry.modeBack, entry.modeFill = makeBar(holder, 3, 3)
        entry.healthText = makeText(holder, {Size = UDim2.new(1, 0, 0, 11), LayoutOrder = 4, TextSize = 10})
        entry.moves = makeMoveRows(holder, 5, 10, 0.62, 10)
        entries[targetPlayer] = entry
        return entry
    end

    local function hideAll()
        for _, entry in pairs(entries) do
            entry.highlight.Enabled = false
            entry.billboard.Enabled = false
        end
    end

    local function paint(entry, targetPlayer, character, root, humanoid, distance)
        local teammate = Game.sameTeam(targetPlayer)
        local color = teammate and esp.allyColor or esp.enemyColor
        if esp.teamColors and targetPlayer.Team and not Game.onAfkTeam(targetPlayer) then
            color = targetPlayer.TeamColor.Color
        end
        local highlight = entry.highlight
        highlight.Adornee = character
        highlight.Enabled = esp.outline or esp.fill
        highlight.OutlineColor, highlight.FillColor = color, color
        highlight.OutlineTransparency = esp.outline and 0 or 1
        highlight.FillTransparency = esp.fill and 0.7 or 1

        local showBillboard = esp.labels or esp.healthBar or esp.modeBar or esp.cooldowns
        entry.billboard.Adornee = character:FindFirstChild("Head") or root
        entry.billboard.Enabled = showBillboard
        if not showBillboard then return end

        local mode = Game.chargeFraction(targetPlayer)
        entry.modeBack.Visible = esp.modeBar
        entry.modeFill.Size = UDim2.fromScale(mode, 1)
        entry.modeFill.BackgroundColor3 = mode >= 1 and COLORS.modeReady or COLORS.mode

        local name = targetPlayer.DisplayName
        if esp.modeBar and mode >= 1 then name = name .. (" [MODE]") end
        if esp.distance then name = name .. (string.format(" [%dm]", math.floor(distance + 0.5))) end
        entry.name.Visible = esp.labels
        entry.name.Text = name
        entry.name.TextColor3 = color

        local hp = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
        entry.healthBack.Visible = esp.healthBar
        entry.healthText.Visible = esp.healthBar
        entry.healthFill.Size = UDim2.fromScale(hp, 1)
        entry.healthFill.BackgroundColor3 = healthColor(hp)
        entry.healthText.Text = string.format("%d / %d", math.floor(humanoid.Health + 0.5), math.floor(humanoid.MaxHealth + 0.5))

        paintMoves(entry.moves, esp.cooldowns and Game.moves(targetPlayer) or {})
    end

    local wasEnabled = false
    task.spawn(function()
        while alive do
            if esp.enabled then
                wasEnabled = true
                local ok, reason = pcall(function()
                    local camera = workspace.CurrentCamera
                    local origin = camera and camera.CFrame.Position or Vector3.zero
                    local shown = 0
                    for _, targetPlayer in ipairs(Players:GetPlayers()) do
                        if targetPlayer ~= player then
                            local character = targetPlayer.Character
                            local root, humanoid = Game.aliveRoot(character)
                            local distance = root and (root.Position - origin).Magnitude or math.huge
                            local visible = root ~= nil
                                and not (esp.hideTeammates and Game.sameTeam(targetPlayer))
                                and not (esp.hideAfk and Game.onAfkTeam(targetPlayer))
                                and not (esp.limitDistance and distance > esp.maxDistance)
                            if visible then
                                paint(getEntry(targetPlayer), targetPlayer, character, root, humanoid, distance)
                                shown = shown + 1
                            elseif entries[targetPlayer] then
                                entries[targetPlayer].highlight.Enabled = false
                                entries[targetPlayer].billboard.Enabled = false
                            end
                        end
                    end
                    esp.shown = shown
                end)
                if not ok then warn("[Catn Hub ESP] " .. tostring(reason)) end
            elseif wasEnabled then
                wasEnabled = false
                esp.shown = 0
                hideAll()
            end
            task.wait(0.1)
        end
    end)
    connect(Players.PlayerRemoving, removeEntry)
end

local panel = {enabled = false, range = 150, subject = nil}
state.Panel = panel
do
    local gui = make("ScreenGui", {Name = "BPHubPanel", ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 8000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, hiddenGuiParent())
    onCleanup(function() gui:Destroy() end)
    local frame = make("Frame", {Size = UDim2.fromOffset(230, 0), Position = UDim2.new(0, 24, 0.5, -75),
        BackgroundColor3 = Color3.fromRGB(18, 18, 24), BackgroundTransparency = 0.15, BorderSizePixel = 0,
        Visible = false, AutomaticSize = Enum.AutomaticSize.Y}, gui)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, frame)
    make("UIStroke", {Color = Color3.fromRGB(143, 112, 236), Transparency = 0.5, Thickness = 1}, frame)
    make("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, frame)
    make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)}, frame)

    local title = makeText(frame, {Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Font = Enum.Font.GothamBold,
        TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
    local subtitle = makeText(frame, {Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 2, TextSize = 11,
        TextColor3 = COLORS.dim, TextXAlignment = Enum.TextXAlignment.Left})
    local _, healthFill = makeBar(frame, 7, 3)
    local healthText = makeText(frame, {Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 4, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left})
    local _, modeFill = makeBar(frame, 4, 5)
    local modeText = makeText(frame, {Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 6, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left})
    local moveRows = makeMoveRows(frame, 5, 10, 0.6, 11)

    local dragging, dragStart, startPosition
    connect(frame.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPosition = true, input.Position, frame.Position
        end
    end)
    connect(UIS.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end)
    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local function nearestEnemy()
        local ownRoot = Game.ownRoot()
        if not ownRoot then return nil end
        local best, bestDistance
        for _, targetPlayer in ipairs(Players:GetPlayers()) do
            if targetPlayer ~= player and not Game.onAfkTeam(targetPlayer) and not Game.sameTeam(targetPlayer) then
                local root = Game.aliveRoot(targetPlayer.Character)
                if root then
                    local distance = (root.Position - ownRoot.Position).Magnitude
                    if distance <= panel.range and (not bestDistance or distance < bestDistance) then
                        best, bestDistance = targetPlayer, distance
                    end
                end
            end
        end
        return best
    end

    local function refresh()
        local subject = nil
        if panel.enabled then
            subject = (bot.enabled and bot.targetPlayer) or nearestEnemy()
        end
        panel.subject = subject and subject.Name or nil
        local root, humanoid
        if subject then root, humanoid = Game.aliveRoot(subject.Character) end
        frame.Visible = root ~= nil
        if root then
            local ownRoot = Game.ownRoot()
            local distance = ownRoot and (root.Position - ownRoot.Position).Magnitude or 0
            title.Text = subject.DisplayName
            title.TextColor3 = subject.Team and not Game.onAfkTeam(subject) and subject.TeamColor.Color or COLORS.text
            local tags = {tostring(Game.characterName(subject)), string.format("%dm", math.floor(distance + 0.5))}
            if Game.isBlocking(subject.Character) then tags[#tags + 1] = "BLOCKING" end
            local skill = Game.usingSkill(subject.Character)
            if skill then tags[#tags + 1] = "using " .. skill end
            subtitle.Text = table.concat(tags, "  |  ")

            local hp = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
            healthFill.Size = UDim2.fromScale(hp, 1)
            healthFill.BackgroundColor3 = healthColor(hp)
            healthText.Text = string.format("HP %d / %d", math.floor(humanoid.Health + 0.5), math.floor(humanoid.MaxHealth + 0.5))
            local mode = Game.chargeFraction(subject)
            modeFill.Size = UDim2.fromScale(mode, 1)
            modeFill.BackgroundColor3 = mode >= 1 and COLORS.modeReady or COLORS.mode
            modeText.Text = mode >= 1 and "MODE READY" or string.format("mode %d%%", math.floor(mode * 100))
            modeText.TextColor3 = mode >= 1 and COLORS.modeReady or COLORS.dim
            paintMoves(moveRows, Game.moves(subject))
        end
    end

    task.spawn(function()
        while alive do
            local ok, reason = pcall(refresh)
            if not ok then warn("[Catn Hub panel] " .. tostring(reason)) end
            task.wait(0.1)
        end
    end)
end

local alerts = {enemies = false, own = false, enemiesOnly = true}
state.Alerts = alerts
do
    local wasFull = {}
    local function notify(title, content)
        pcall(function() BPUI:Notify({Title = title, Content = content, Type = "Warning", Duration = 4}) end)
    end
    task.spawn(function()
        while alive do
            for _, targetPlayer in ipairs(Players:GetPlayers()) do
                local fraction = Game.chargeFraction(targetPlayer)
                local full = fraction >= 1

                if wasFull[targetPlayer] == nil then
                    wasFull[targetPlayer] = full
                elseif wasFull[targetPlayer] and fraction < 0.9 then
                    wasFull[targetPlayer] = false
                elseif full and not wasFull[targetPlayer] then
                    wasFull[targetPlayer] = true
                    if targetPlayer == player then
                        if alerts.own then notify("Mode ready", "your mode bar is full") end
                    elseif alerts.enemies and not Game.onAfkTeam(targetPlayer)
                        and not (alerts.enemiesOnly and Game.sameTeam(targetPlayer)) then
                        notify("Mode ready", targetPlayer.DisplayName .. " (" .. tostring(Game.characterName(targetPlayer)) .. ") has mode")
                    end
                end
            end
            for targetPlayer in pairs(wasFull) do
                if targetPlayer.Parent ~= Players then wasFull[targetPlayer] = nil end
            end
            task.wait(0.5)
        end
    end)
end

local comp = {
    enabled = false, ring = true, reach = 9.5, ringOpacity = 0.55,
    strips = true, stripRange = 80, holdKey = Enum.KeyCode.LeftAlt, fpsSaver = false,
    accent = Color3.fromRGB(143, 112, 236), focus = nil, holding = false,
}
state.Comp = comp
do
    local container = make("Folder", {Name = "BPHubComp"}, hiddenGuiParent())
    onCleanup(function() container:Destroy() end)

    local YELLOW = Color3.fromRGB(255, 205, 70)

    local function enemyModel(model)
        if model == player.Character then return false end
        local owner = Game.ownerOf(model)
        if owner == player then return false end
        if not owner then return not model:HasTag("FRIENDLYDUMMY"), nil end
        return not Game.onAfkTeam(owner) and not Game.sameTeam(owner), owner
    end

    local ring = make("CylinderHandleAdornment", {Name = "Reach", Height = 0.06, Radius = comp.reach,
        InnerRadius = comp.reach - 0.18, ZIndex = 0, Visible = false, Color3 = COLORS.dim}, container)

    local live = workspace:FindFirstChild("Live")

    local stepTime = {}
    local tracked = setmetatable({}, {__mode = "k"})
    local function learn(move, now)
        local value = move:GetAttribute("COOLDOWN")
        value = type(value) == "number" and value or 20
        local seen = tracked[move]
        if not seen then tracked[move] = {value = value} return end
        if value > seen.value and value < 20 or (value == 20 and seen.value < 20) then
            if seen.at then
                local sample = (now - seen.at) / (value - seen.value)
                if sample > 0.05 and sample < 10 then
                    local old = stepTime[move.Name]
                    stepTime[move.Name] = old and (old * 0.7 + sample * 0.3) or sample
                end
            end
            seen.at = now
        elseif value < seen.value then
            seen.at = now
        end
        seen.value = value
    end

    local function short(name)
        local letters = {}
        for word in string.gmatch(name, "%w+") do
            letters[#letters + 1] = string.upper(string.sub(word, 1, 1))
        end
        if #letters == 1 then return string.sub(name, 1, 2) end
        return #letters > 0 and (letters[1] .. letters[2]) or "?"
    end

    local CELLS, CELL = 5, 22
    local strips = {}
    local function getStrip(targetPlayer)
        if strips[targetPlayer] then return strips[targetPlayer] end
        local billboard = make("BillboardGui", {AlwaysOnTop = true, Enabled = false, LightInfluence = 0,
            Size = UDim2.fromOffset(CELLS * (CELL + 2), CELL + 14), StudsOffset = Vector3.new(0, 3.6, 0),
            ResetOnSpawn = false}, container)
        local tags = makeText(billboard, {Size = UDim2.new(1, 0, 0, 12), Font = Enum.Font.GothamBold, TextSize = 11})
        local row = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 13),
            Size = UDim2.new(1, 0, 0, CELL)}, billboard)
        make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2),
            HorizontalAlignment = Enum.HorizontalAlignment.Center}, row)
        local cells = {}
        for index = 1, CELLS do
            local cell = make("Frame", {BackgroundColor3 = COLORS.barBack, BackgroundTransparency = 0.2,
                BorderSizePixel = 0, Size = UDim2.fromOffset(CELL, CELL), LayoutOrder = index, Visible = false}, row)
            make("UICorner", {CornerRadius = UDim.new(0, 4)}, cell)
            local fill = make("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
                BorderSizePixel = 0, BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1)}, cell)
            make("UICorner", {CornerRadius = UDim.new(0, 4)}, fill)
            local label = makeText(cell, {Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 11,
                TextStrokeTransparency = 0.2, ZIndex = 2})
            cells[index] = {cell = cell, fill = fill, label = label}
        end
        strips[targetPlayer] = {billboard = billboard, tags = tags, cells = cells}
        return strips[targetPlayer]
    end
    connect(Players.PlayerRemoving, function(targetPlayer)
        if strips[targetPlayer] then strips[targetPlayer].billboard:Destroy() strips[targetPlayer] = nil end
    end)

    local function paintStrip(strip, targetPlayer, character)
        local moves = Game.moves(targetPlayer)
        local backpack = targetPlayer:FindFirstChildOfClass("Backpack")
        for index, cell in ipairs(strip.cells) do
            local move = moves[index]
            cell.cell.Visible = move ~= nil
            if move then
                cell.fill.Size = UDim2.fromScale(1, move.progress)
                cell.fill.BackgroundColor3 = move.ready and comp.accent or COLORS.charging
                local text = short(move.name)
                local step = stepTime[move.name]
                if not move.ready and step then
                    local config = backpack and backpack:FindFirstChild(move.name)
                    local value = config and config:GetAttribute("COOLDOWN")
                    if type(value) == "number" then text = tostring(math.ceil((20 - value) * step)) end
                end
                cell.label.Text = text
                cell.label.TextColor3 = move.ready and COLORS.text or COLORS.dim
            end
        end
        local tags = {}
        if Game.isBlocking(character) then tags[#tags + 1] = "BLOCK" end
        if character:FindFirstChild("Counter") then tags[#tags + 1] = "COUNTER" end
        if Game.chargeFraction(targetPlayer) >= 1 then tags[#tags + 1] = "MODE" end
        strip.tags.Text = table.concat(tags, "  ")
        strip.tags.TextColor3 = #tags > 0 and YELLOW or COLORS.text
        strip.billboard.Adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        strip.billboard.Enabled = true
    end

    local function pickFocus(mine)
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        local look = camera.CFrame.LookVector
        local best, bestAngle, near, nearDistance
        for _, targetPlayer in ipairs(Players:GetPlayers()) do
            if targetPlayer ~= player and not Game.onAfkTeam(targetPlayer) and not Game.sameTeam(targetPlayer) then
                local root = Game.aliveRoot(targetPlayer.Character)
                if root then
                    local distance = (root.Position - mine.Position).Magnitude
                    if distance <= comp.stripRange then
                        local offset = root.Position - camera.CFrame.Position
                        local angle = math.deg(math.acos(math.clamp(look:Dot(offset.Unit), -1, 1)))
                        if angle < 20 and (not bestAngle or angle < bestAngle) then best, bestAngle = targetPlayer, angle end
                        if distance < 20 and (not nearDistance or distance < nearDistance) then near, nearDistance = targetPlayer, distance end
                    end
                end
            end
        end
        return best or near
    end

    connect(UIS.InputBegan, function(input)
        if input.KeyCode == comp.holdKey and comp.holdKey ~= Enum.KeyCode.Unknown then comp.holding = true end
    end)
    connect(UIS.InputEnded, function(input)
        if input.KeyCode == comp.holdKey then comp.holding = false end
    end)

    local tick = 0
    local function update()
        local now = os.clock()
        local mine, humanoid = Game.ownRoot()
        local on = comp.enabled and alive

        local showRing = on and comp.ring and not comp.fpsSaver and mine ~= nil
        ring.Visible = showRing
        if showRing then
            if ring.Adornee ~= mine then ring.Adornee = mine end
            local drop = humanoid.HipHeight + mine.Size.Y / 2 - 0.08
            ring.CFrame = CFrame.new(0, -drop, 0) * CFrame.Angles(math.rad(90), 0, 0)
            ring.Radius, ring.InnerRadius = comp.reach, math.max(0, comp.reach - 0.18)
            local inRange = false
            if live then
                for _, model in ipairs(live:GetChildren()) do
                    local root = model:FindFirstChild("HumanoidRootPart")
                    if root and (root.Position - mine.Position).Magnitude <= comp.reach and enemyModel(model) then
                        local _, other = Game.aliveRoot(model)
                        if other then inRange = true break end
                    end
                end
            end
            ring.Color3 = inRange and comp.accent or COLORS.dim
            ring.Transparency = inRange and math.max(0, 1 - comp.ringOpacity - 0.25) or 1 - comp.ringOpacity
        end

        tick = tick + 1
        if tick % 2 ~= 0 then return end

        for _, targetPlayer in ipairs(Players:GetPlayers()) do
            local backpack = targetPlayer:FindFirstChildOfClass("Backpack")
            if backpack then
                for _, move in ipairs(backpack:GetChildren()) do
                    if move:IsA("Configuration") then learn(move, now) end
                end
            end
        end
        if not on or not mine then
            for _, strip in pairs(strips) do strip.billboard.Enabled = false end
            comp.focus = nil
            return
        end

        local focus = pickFocus(mine)
        comp.focus = focus and focus.Name or nil
        local showStrips = comp.strips and not comp.fpsSaver
        for _, targetPlayer in ipairs(Players:GetPlayers()) do
            if targetPlayer ~= player then
                local character = targetPlayer.Character
                local root = Game.aliveRoot(character)
                local enemy = root and not Game.onAfkTeam(targetPlayer) and not Game.sameTeam(targetPlayer)
                local distance = root and (root.Position - mine.Position).Magnitude or math.huge
                local shown = showStrips and enemy and distance <= comp.stripRange
                    and (targetPlayer == focus or comp.holding)
                if shown then
                    paintStrip(getStrip(targetPlayer), targetPlayer, character)
                elseif strips[targetPlayer] then
                    strips[targetPlayer].billboard.Enabled = false
                end
            end
        end

        if comp.preview and player.Character then
            paintStrip(getStrip(player), player, player.Character)
        elseif strips[player] then
            strips[player].billboard.Enabled = false
        end
    end

    task.spawn(function()
        while alive do
            local ok, reason = pcall(update)
            if not ok then warn("[Catn Hub comp] " .. tostring(reason)) end
            task.wait(0.05)
        end
        ring.Visible = false
    end)
end

local session = {started = os.clock(), gold = 0, kills = 0, deaths = 0, damage = 0}
state.Session = session
do
    local function track(valueObject, key)
        if not valueObject or not valueObject:IsA("ValueBase") then return end
        local last = tonumber(valueObject.Value) or 0
        connect(valueObject.Changed, function(value)
            value = tonumber(value) or 0
            if value > last then session[key] = session[key] + (value - last) end
            last = value
        end)
    end
    task.spawn(function()
        local stats = player:WaitForChild("Stats", 15)
        if alive and stats then
            track(stats:FindFirstChild("Kills"), "kills")
            track(stats:FindFirstChild("Deaths"), "deaths")
            track(stats:FindFirstChild("Damage"), "damage")
        end
        local replicated = player:WaitForChild("ReplicatedStats", 15)
        if alive and replicated then track(replicated:FindFirstChild("Gold"), "gold") end
    end)
    session.Reset = function()
        session.started, session.gold, session.kills, session.deaths, session.damage = os.clock(), 0, 0, 0, 0
    end
end

local client = {fullbright = false, noFog = false, noAtmosphere = false, noDecals = false, noParticles = false,
    fpsBoost = false, streamer = false}
state.Client = client
do
    local Lighting = game:GetService("Lighting")
    local StarterGui = game:GetService("StarterGui")
    local saved = {}
    local decals = setmetatable({}, {__mode = "k"})
    local effects = setmetatable({}, {__mode = "k"})
    local atmospheres = {}
    local EFFECT_CLASSES = {"ParticleEmitter", "Trail", "Beam", "Smoke", "Fire", "Sparkles"}

    local function isEffect(object)
        for _, className in ipairs(EFFECT_CLASSES) do
            if object:IsA(className) then return true end
        end
        return false
    end

    local function hideDecal(object)
        if (object:IsA("Decal") or object:IsA("Texture")) and decals[object] == nil then
            decals[object] = object.Transparency
            object.Transparency = 1
        end
    end
    local function hideEffect(object)
        if isEffect(object) and effects[object] == nil then
            effects[object] = object.Enabled
            object.Enabled = false
        end
    end

    local function applyLighting()
        if client.fullbright then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.Ambient = Color3.fromRGB(178, 178, 178)
            Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        end
        if client.noFog then
            Lighting.FogStart = 1e9
            Lighting.FogEnd = 1e9
        end
    end

    client.Set = function(key, on)
        on = on == true and alive
        if client[key] == on then return end
        client[key] = on
        if key == "fullbright" then
            if on then
                saved.light = {Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
                    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient}
            elseif saved.light then
                for property, value in pairs(saved.light) do pcall(function() Lighting[property] = value end) end
                saved.light = nil
            end
        elseif key == "noFog" then
            if on then
                saved.fog = {FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd}
            elseif saved.fog then
                Lighting.FogStart, Lighting.FogEnd = saved.fog.FogStart, saved.fog.FogEnd
                saved.fog = nil
            end
        elseif key == "noAtmosphere" then
            if on then
                for _, child in ipairs(Lighting:GetChildren()) do
                    if child:IsA("Atmosphere") then atmospheres[#atmospheres + 1] = child child.Parent = nil end
                end
            else
                for _, atmosphere in ipairs(atmospheres) do pcall(function() atmosphere.Parent = Lighting end) end
                table.clear(atmospheres)
            end
        elseif key == "noDecals" then
            if on then
                for _, object in ipairs(workspace:GetDescendants()) do hideDecal(object) end
            else
                for object, transparency in pairs(decals) do pcall(function() object.Transparency = transparency end) end
                table.clear(decals)
            end
        elseif key == "noParticles" then
            if on then
                for _, object in ipairs(workspace:GetDescendants()) do hideEffect(object) end
            else
                for object, enabled in pairs(effects) do pcall(function() object.Enabled = enabled end) end
                table.clear(effects)
            end
        elseif key == "fpsBoost" then
            if on then
                local ok, level = pcall(function() return settings().Rendering.QualityLevel end)
                saved.fps = {quality = ok and level or nil, shadows = Lighting.GlobalShadows}
                pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
                Lighting.GlobalShadows = false
            elseif saved.fps then
                if saved.fps.quality then pcall(function() settings().Rendering.QualityLevel = saved.fps.quality end) end
                Lighting.GlobalShadows = saved.fps.shadows
                saved.fps = nil
            end
        elseif key == "streamer" then

            if on then
                local ok, shown = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList) end)
                saved.playerList = not ok or shown
                pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
            else
                local shown = saved.playerList ~= false
                saved.playerList = nil
                pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, shown) end)
            end
        end
        applyLighting()
    end

    connect(workspace.DescendantAdded, function(object)
        if client.noDecals then hideDecal(object) end
        if client.noParticles then hideEffect(object) end
    end)
    connect(Lighting.ChildAdded, function(child)
        if client.noAtmosphere and child:IsA("Atmosphere") then
            task.defer(function()
                atmospheres[#atmospheres + 1] = child
                child.Parent = nil
            end)
        end
    end)
    task.spawn(function()
        while alive do
            pcall(applyLighting)
            task.wait(1)
        end
    end)

    client.Reset = function()
        local _, humanoid = Game.ownRoot()
        if humanoid then humanoid.Health = 0 end
    end

    onCleanup(function()
        for _, key in ipairs({"fullbright", "noFog", "noAtmosphere", "noDecals", "noParticles", "fpsBoost", "streamer"}) do
            if client[key] then pcall(client.Set, key, false) end
        end
    end)
end

local MACRO_ACTIONS = {"MouseClick", "Move1", "Move2", "Move3", "Move4", "Move5", "Block", "Dodge", "Run", "UseMode"}
local macro = {recording = false, playing = false, loop = false, speed = 1, events = {}, last = "nothing recorded"}
state.Macro = macro
do
    local HttpService = game:GetService("HttpService")
    local FOLDER = "BPHubABA/macros"
    local startedAt = 0
    local playToken = 0
    local held = {}

    local function length()
        local last = macro.events[#macro.events]
        return last and last.t or 0
    end
    macro.Summary = function()
        return string.format("%d presses, %.1fs", #macro.events, length())
    end

    for _, name in ipairs(MACRO_ACTIONS) do
        local action = gameAction(name)
        if action then
            for _, pair in ipairs({{"Pressed", true}, {"Released", false}}) do
                local ok, signal = pcall(function() return action[pair[1]] end)
                if ok and typeof(signal) == "RBXScriptSignal" then
                    connect(signal, function()
                        if macro.recording and not macro.playing then
                            macro.events[#macro.events + 1] = {t = os.clock() - startedAt, a = name, d = pair[2]}
                        end
                    end)
                end
            end
        end
    end

    macro.StartRecording = function()
        if macro.playing then macro.Stop() end
        macro.events = {}
        startedAt = os.clock()
        macro.recording = true
        macro.last = "recording..."
    end

    macro.StopRecording = function()
        if not macro.recording then return end
        macro.recording = false

        local events = macro.events
        local first = events[1] and events[1].t or 0
        local down = {}
        for _, e in ipairs(events) do
            e.t = e.t - first
            down[e.a] = e.d or nil
        end
        local finish = length()
        for name in pairs(down) do events[#events + 1] = {t = finish + 0.05, a = name, d = false} end
        macro.last = #events > 0 and ("recorded " .. macro.Summary()) or "nothing recorded"
    end

    local function releaseAll()
        for name in pairs(held) do
            local action = gameAction(name)
            if action then pcall(function() action:Fire(false) end) end
        end
        table.clear(held)
    end

    macro.Stop = function()
        playToken = playToken + 1
        if macro.playing then macro.last = "stopped" end
        macro.playing = false
        releaseAll()
    end

    macro.Play = function()
        if macro.recording then macro.StopRecording() end
        if #macro.events == 0 then macro.last = "nothing to play" return end
        playToken = playToken + 1
        local token = playToken
        macro.playing = true
        task.spawn(function()
            local rounds = 0
            repeat
                rounds = rounds + 1
                macro.last = macro.loop and ("playing, loop " .. rounds) or "playing"
                local started = os.clock()
                for _, e in ipairs(macro.events) do
                    local at = started + e.t / math.max(macro.speed, 0.1)
                    while os.clock() < at and token == playToken and alive do RunService.Heartbeat:Wait() end
                    if token ~= playToken or not alive then return end
                    local action = gameAction(e.a)
                    if action then
                        pcall(function() action:Fire(e.d) end)
                        held[e.a] = e.d or nil
                    end
                end
                releaseAll()
                task.wait(0.1)
            until not macro.loop or token ~= playToken or not alive
            if token == playToken then
                macro.playing = false
                macro.last = "finished"
            end
        end)
    end

    local function ensureFolder()
        if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return end
        if not isfolder("BPHubABA") then makefolder("BPHubABA") end
        if not isfolder(FOLDER) then makefolder(FOLDER) end
    end
    local function clean(name) return (tostring(name or ""):gsub("[^%w%s%-_]", ""):gsub("^%s+", ""):gsub("%s+$", "")) end

    macro.List = function()
        local names = {}
        if type(listfiles) ~= "function" then return names end
        pcall(function()
            ensureFolder()
            for _, path in ipairs(listfiles(FOLDER)) do
                local name = tostring(path):match("([^/\\]+)%.json$")
                if name then names[#names + 1] = name end
            end
        end)
        table.sort(names, function(a, b) return a:lower() < b:lower() end)
        return names
    end

    macro.Save = function(name)
        name = clean(name)
        if name == "" then return false, "type a name first" end
        if #macro.events == 0 then return false, "record something first" end
        if type(writefile) ~= "function" then return false, "this executor can't save files" end
        local ok, err = pcall(function()
            ensureFolder()
            writefile(FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode({v = 1, events = macro.events}))
        end)
        return ok, ok and ("saved " .. name) or tostring(err)
    end

    local function useEvents(list)
        if type(list) ~= "table" then return false end
        local events = {}
        local known = {}
        for _, name in ipairs(MACRO_ACTIONS) do known[name] = true end
        for _, e in ipairs(list) do
            if type(e) == "table" and known[e.a] and tonumber(e.t) then
                events[#events + 1] = {t = tonumber(e.t), a = e.a, d = e.d == true}
            end
        end
        if #events == 0 then return false end
        if macro.playing then macro.Stop() end
        macro.events = events
        return true
    end

    macro.Load = function(name)
        name = clean(name)
        if type(readfile) ~= "function" then return false, "this executor can't read files" end
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(FOLDER .. "/" .. name .. ".json")) end)
        if not ok or not useEvents(type(data) == "table" and data.events) then return false, "couldn't read " .. name end
        macro.last = "loaded " .. name .. ", " .. macro.Summary()
        return true, macro.last
    end

    macro.Delete = function(name)
        name = clean(name)
        if type(delfile) ~= "function" then return false, "this executor can't delete files" end
        local ok = pcall(delfile, FOLDER .. "/" .. name .. ".json")
        return ok, ok and ("deleted " .. name) or ("couldn't delete " .. name)
    end

    macro.Export = function()
        if #macro.events == 0 then return nil end
        return "CATNMACRO:" .. HttpService:JSONEncode(macro.events)
    end

    macro.Import = function(code)
        local ok, list = pcall(function() return HttpService:JSONDecode((tostring(code or ""):gsub("^%s*CATNMACRO:", ""))) end)
        if not ok or not useEvents(list) then return false, "that code doesn't look right" end
        macro.last = "imported, " .. macro.Summary()
        return true, macro.last
    end

    onCleanup(function()
        macro.recording = false
        macro.Stop()
    end)
end

local misc = {antiAfk = false}
state.Misc = misc
connect(player.Idled, function()
    if not misc.antiAfk then return end
    pcall(function()
        local virtualUser = game:GetService("VirtualUser")
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.new())
    end)
end)

local spawner = {enabled = false, character = "", noAfk = false, last = "off"}
state.Spawner = spawner
do

    local LAST_FILE = "BPHubABA/last_character.txt"
    pcall(function() if isfile(LAST_FILE) then spawner.lastSpawned = readfile(LAST_FILE) end end)
    local function rememberCharacter(name)
        if type(name) ~= "string" or name == "" or name == spawner.lastSpawned then return end
        spawner.lastSpawned = name
        pcall(function()
            if not isfolder("BPHubABA") then makefolder("BPHubABA") end
            writefile(LAST_FILE, name)
        end)
    end
    local pressedAt, afkAt, lobbySince = 0, 0, nil

    local function hud() return player:FindFirstChildOfClass("PlayerGui") and player.PlayerGui:FindFirstChild("HUD") end
    local function input()
        local backpack = player:FindFirstChildOfClass("Backpack")
        local remote = backpack and backpack:FindFirstChild("Input")
        if remote and remote:IsA("RemoteEvent") then return remote end
    end

    function spawner.InLobby()
        local gui = hud()
        local line = gui and gui:FindFirstChild("RightBotCorner") and gui.RightBotCorner:FindFirstChild("Line1")
        local health = gui and gui:FindFirstChild("Health")
        return line ~= nil and line.Visible and not (health and health.Visible)
    end

    function spawner.Characters()
        local gui = hud()
        local select = gui and gui:FindFirstChild("CharacterSelect")
        local holder = select and select:FindFirstChild("Characters")
        local names, seen = {}, {}
        if holder then
            for _, button in ipairs(holder:GetDescendants()) do
                if button:IsA("ImageButton") and button.Name ~= "Icon" and not seen[button.Name]
                    and not button:GetAttribute("TestPlaceOnly") then
                    seen[button.Name] = true
                    names[#names + 1] = button.Name
                end
            end
        end
        table.sort(names)
        return names
    end

    local function pick()
        local wanted = spawner.character:lower():gsub("^%s+", ""):gsub("%s+$", "")
        local names = spawner.Characters()
        if wanted == "" then

            local last = player:GetAttribute("LastLoadedChar")
            if last and last ~= "" then return last end
            for _, name in ipairs(names) do if name == spawner.lastSpawned then return name end end
            return names[1]
        end
        for _, name in ipairs(names) do if name:lower() == wanted then return name end end
        for _, name in ipairs(names) do if name:lower():sub(1, #wanted) == wanted then return name end end
        return nil
    end
    spawner.Pick = pick

    local titleSince = nil
    local function titleScreen()
        local pg = player:FindFirstChildOfClass("PlayerGui")
        local menu = pg and pg:FindFirstChild("MainMenu")
        local play = menu and menu:FindFirstChild("MainGame")
        if not (play and menu.Enabled and play.Visible) or player:HasTag("PastMainMenu") then return nil end
        return play
    end
    local function pressPlay(play)
        if type(getconnections) == "function" then
            local ok, conns = pcall(getconnections, play.Activated)
            if ok and conns and #conns > 0 then
                for _, c in ipairs(conns) do pcall(function() c:Fire() end) end
                return
            end
        end
        if type(firesignal) == "function" and pcall(firesignal, play.Activated) then return end
        local loaded = game:GetService("ReplicatedStorage"):FindFirstChild("Loaded")
        if loaded then
            workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            loaded:FireServer()
            pcall(function() play.Parent:Destroy() end)
        end
    end
    spawner.TitleScreen = titleScreen

    task.spawn(function()
        while alive do
            local remote = input()
            local play = spawner.enabled and correctGame and titleScreen()
            if play then
                titleSince = titleSince or os.clock()
                spawner.last = "on the title screen, pressing Play"
                if os.clock() - titleSince > 2 and os.clock() - pressedAt > 4 then
                    pressedAt = os.clock()
                    pressPlay(play)
                end
            else
                titleSince = nil
            end
            if play then

            elseif spawner.enabled and remote and correctGame then
                if spawner.InLobby() then
                    lobbySince = lobbySince or os.clock()
                    local gui = hud()
                    local browsing = gui and gui:FindFirstChild("CharacterSelect") and gui.CharacterSelect.Visible
                    local name = pick()
                    if not name then
                        spawner.last = "no character called \"" .. spawner.character .. "\""
                    elseif browsing and not spawner.openedMenu then
                        spawner.last = "waiting, the character menu is open"
                    elseif os.clock() - lobbySince > 2 and os.clock() - pressedAt > 4 then

                        pressedAt = os.clock()
                        spawner.last = "spawning as " .. name
                        spawner.openedMenu = true
                        remote:FireServer("CharacterOpen")
                        task.wait(0.35)
                        remote:FireServer("CharacterButton", name)
                        task.wait(0.35)
                        remote:FireServer("ClickPlay")
                    end
                else
                    lobbySince = nil
                    spawner.openedMenu = false
                    spawner.last = "in a match"
                    rememberCharacter(player:GetAttribute("LastLoadedChar"))
                end
            elseif not spawner.enabled then
                lobbySince = nil
                spawner.last = "off"
            end
            local afk = player:FindFirstChild("AFK")
            if spawner.noAfk and remote and afk and afk:IsA("BoolValue") and afk.Value and os.clock() - afkAt > 6 then
                afkAt = os.clock()
                remote:FireServer("AFKToggle")
            end
            task.wait(1)
        end
    end)
end

local hop = {enabled = false, after = 90, last = "off", skipJuggernaut = false, skip = {Juggernaut = true}}
state.Hop = hop
do
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local idleSince, badSince, hoppingUntil = nil, nil, 0

    local function currentMode()
        local mode = workspace:GetAttribute("GameMode")
        return type(mode) == "string" and mode or nil
    end

    function hop.Candidates()
        local folder = ReplicatedStorage:FindFirstChild("Servers")
        local here = workspace:GetAttribute("ServerBrowserJobId") or game.JobId
        local list = {}
        if not folder then return list end
        for _, server in ipairs(folder:GetChildren()) do
            local mode = server:GetAttribute("Mode")
            local players = tonumber(server:GetAttribute("PlayerCount")) or 0
            local max = tonumber(server:GetAttribute("MaxPlayers")) or 0
            if server.Name ~= here and server:GetAttribute("Type") == "Public" and type(mode) == "string"
                and mode ~= "Intermission" and not hop.skip[mode] and players >= 3 and players <= max - 2 then
                list[#list + 1] = {id = server.Name, mode = mode, players = players, max = max,
                    name = server:GetAttribute("ServerName") or "?"}
            end
        end
        table.sort(list, function(a, b) return a.players > b.players end)
        return list
    end

    function hop.Go(reason)
        if os.clock() < hoppingUntil then return end
        hoppingUntil = os.clock() + 25
        if rejoin.loader ~= "" and type(queue_on_teleport) == "function" then pcall(queue_on_teleport, rejoin.loader) end
        local list = hop.Candidates()

        local pick = list[math.random(1, math.min(#list, 4))]
        local remote = ReplicatedStorage:FindFirstChild("ServerTP")
        if pick and remote then
            hop.last = ("%s: joining %s (%s, %d/%d)"):format(reason, pick.name, pick.mode, pick.players, pick.max)
            pcall(function() remote:FireServer(pick.id) end)

            task.delay(12, function()
                if alive then pcall(function() TeleportService:Teleport(game.PlaceId, player) end) end
            end)
        else
            hop.last = reason .. ": joining a random server"
            pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
        end
    end

    task.spawn(function()
        while alive do
            local mode = currentMode()
            local bad = hop.skipJuggernaut and correctGame and mode ~= nil and hop.skip[mode] == true
            local idle = bot.enabled and bot.target == "none" and Game.ownRoot() ~= nil and not spawner.InLobby()
            if os.clock() < hoppingUntil then

            elseif bad then

                badSince = badSince or os.clock()
                local left = math.ceil(4 - (os.clock() - badSince))
                hop.last = mode .. " here, leaving in " .. math.max(left, 0) .. "s"
                if left <= 0 then hop.Go(mode .. " here") end
            elseif hop.enabled and idle then
                badSince = nil
                idleSince = idleSince or os.clock()
                local left = math.ceil(hop.after - (os.clock() - idleSince))
                hop.last = "nobody to fight, hopping in " .. math.max(left, 0) .. "s"
                if left <= 0 then hop.Go("nobody to fight") end
            else
                idleSince, badSince = nil, nil
                hop.last = (hop.enabled or hop.skipJuggernaut) and ("watching" .. (mode and (" (" .. mode .. ")") or "")) or "off"
            end
            task.wait(1)
        end
    end)
end

local presetToggles = {}

local created, result = pcall(function()
    return BPUI:CreateWindow({Version = "1.6.2",
        Title = "Catn Hub", Subtitle = "Anime Battle Arena",
        Icon = "zap", Theme = "Void", Accent = Color3.fromRGB(143, 112, 236),
        ToggleKey = Enum.KeyCode.RightShift, ShowSettings = true, ConfigFolder = "BPHubABA",
        Watermark = false, CloseBehavior = "Hide", OnDestroy = cleanup,
    })
end)
if not created then cleanup() error("Window creation failed: " .. tostring(result)) end
window = result

local ui = {}
local toggles = {}

local function addToggle(section, config)
    local element = section:AddToggle(config)
    if config.Panic ~= false then toggles[#toggles + 1] = element end
    return element
end

local function teamDropdown(section, flag, onChange)
    return section:AddDropdown({Name = "Team check", Options = Game.teamModeOptions, Default = "Enemies only",
        Flag = flag, Callback = function(value) onChange(Game.teamModes[value] or "enemies") end})
end

local overviewTab = window:CreateTab({Name = "Overview", Icon = "home"})
do
    local info = overviewTab:CreateSection("Info")
    ui.status = info:AddLabel({Text = supported and "ABA detected" or "Wrong game, features locked",
        Style = supported and "Success" or "Error"})
    ui.character = info:AddLabel({Text = "Character: -", Style = "Sub"})
    ui.performance = info:AddLabel({Text = "FPS: -  |  ping: -", Style = "Sub"})
    ui.selfCheck = info:AddLabel({Text = "self check: running...", Style = "Sub"})
    info:AddButton({Name = "Unload", Callback = function() state.Destroy() end})

    local sessionSection = overviewTab:CreateSection("Session")
    ui.sessionTime = sessionSection:AddLabel({Text = "time: 0m", Style = "Sub"})
    ui.sessionGold = sessionSection:AddLabel({Text = "gold: +0", Style = "Sub"})
    ui.sessionFights = sessionSection:AddLabel({Text = "kills: 0  |  deaths: 0  |  damage: 0", Style = "Sub"})
    ui.sessionRate = sessionSection:AddLabel({Text = "per hour: -", Style = "Sub"})
    sessionSection:AddButton({Name = "Reset session", Callback = session.Reset})

    local statusSection = overviewTab:CreateSection("Status")
    ui.overview = {}
    for _, key in ipairs({"bot", "esp", "panel", "anyBlackFlash", "yuji", "nanami", "yusuke", "krillin"}) do
        ui.overview[key] = statusSection:AddLabel({Text = "-", Style = "Sub"})
    end

    local keys = overviewTab:CreateSection("Default keys")
    for _, line in ipairs({
        "RightShift  open/close menu", "End  turn everything off", "F2  auto block", "F3  Black Flash (any character)",
        "F4  ESP", "F5  target panel", "F6  Nanami auto hit", "F7  Yusuke gun sweep",
        "F8 / F9  Yuji Black Flash / Divergent", "F10  Krillin kiblast", "F11  Auto Farm", "F12  Kokushibo timing", "Home  move sweeps", "Insert  Comp HUD",
        "PageUp / PageDown  record / play macro",
    }) do
        keys:AddLabel({Text = line, Style = "Sub"})
    end
end

local farmTab = window:CreateTab({Name = "Auto Farm", Icon = "crosshair"})
local farmControls = {}
do
    local main = farmTab:CreateSection("Auto Farm")
    local botToggle = addToggle(main, {Name = "Auto Farm", Icon = "bot", Default = false, Flag = "bot_enabled",
        Description = "Runs, sprints, jumps and dashes to the nearest target and fights it with your own M1s and moves. Keeps off pads, kill bricks and edges.",
        Callback = function(value) bot.SetEnabled(value) end})
    if not correctGame then botToggle:Lock() end
    presetToggles.bot = botToggle
    main:AddKeybind({Name = "Key", Default = Enum.KeyCode.F11, Mode = "Press", Flag = "bot_key",
        Callback = function() if alive and correctGame then botToggle:Set(not bot.enabled) end end})
    ui.botStatus = main:AddLabel({Text = "off", Style = "Sub"})

    local targets = farmTab:CreateSection("Targets")
    farmControls.targets = targets:AddDropdown({Name = "Targets", Options = {"Players", "Dummies", "Both"}, Default = "Players", Flag = "bot_targets",
        Description = "Dummies on their own only run while you're alone in the server.",
        Callback = function(value) bot.targets = value or "Players" end})
    farmControls.team = teamDropdown(targets, "bot_team", function(mode) bot.teamMode = mode end)
    local targetModes = {["Whoever is nearest"] = "nearest", ["Easiest kill"] = "easiest", ["Stay on one until it dies"] = "stay"}
    farmControls.goAfter = targets:AddDropdown({Name = "Go after", Options = {"Whoever is nearest", "Easiest kill", "Stay on one until it dies"},
        Default = "Whoever is nearest", Flag = "bot_target_mode",
        Description = "Nearest always goes for the closest player. Easiest kill weighs health, running and blocking.",
        Callback = function(value) bot.targetMode = targetModes[value] or "nearest" end})
    farmControls.skipAfk = targets:AddToggle({Name = "Skip AFK team", Default = true, Flag = "bot_skip_afk",
        Callback = function(value) bot.skipAfk = value == true end})
    farmControls.skipUlt = targets:AddToggle({Name = "Skip players in an ultimate", Default = true, Flag = "bot_skip_ult",
        Description = "Ignores anyone frozen in an awakening or ultimate, or still spawn-protected, since they can't be hurt.",
        Callback = function(value) bot.skipUlt = value == true end})

    local fight = farmTab:CreateSection("Fighting")
    farmControls.moves = fight:AddToggle({Name = "Use moves", Default = true, Flag = "bot_moves",
        Description = "Casts whichever of moves 1-4 is ready once it's next to its target, M1 otherwise.",
        Callback = function(value) bot.useMoves = value == true end})
    farmControls.reach = fight:AddSlider({Name = "Move range", Min = 3, Max = 60, Default = 10, Increment = 1, Suffix = " studs", Flag = "bot_reach",
        Description = "How far out it casts moves. Past 10, ranged moves go off on the way in. M1s always wait until it's in reach.",
        Callback = function(value) bot.reach = math.clamp(tonumber(value) or 10, 3, 60) end})
    farmControls.awaken = fight:AddToggle({Name = "Use awakening", Default = true, Flag = "bot_awaken",
        Description = "Presses G when the mode bar is full and it's next to someone.",
        Callback = function(value) bot.awaken = value == true end})
    farmControls.trade = fight:AddToggle({Name = "M1 trading", Default = true, Flag = "bot_trade",
        Description = "Hits back the moment a block drops, blocks swings itself when Auto Block isn't on, dodges out after two hits in a row or a finisher, and dashes after its own finisher.",
        Callback = function(value) bot.trade = value == true end})
    farmControls.smart = fight:AddToggle({Name = "Wait out blocks", Default = true, Flag = "bot_smart",
        Description = "Doesn't M1 into someone holding block; saves a guard-break move for them instead.",
        Callback = function(value) bot.smart = value == true end})

    local move = farmTab:CreateSection("Movement")
    farmControls.sprint = move:AddToggle({Name = "Sprint", Default = true, Flag = "bot_sprint",
        Callback = function(value) bot.sprint = value == true end})
    farmControls.dash = move:AddToggle({Name = "Dash in", Default = true, Flag = "bot_dash",
        Description = "Dodges forward on straight, safe stretches 14 to 40 studs out, and out of combos.",
        Callback = function(value) bot.dash = value == true end})
    farmControls.jump = move:AddToggle({Name = "Jump over things", Default = true, Flag = "bot_jump",
        Description = "Jumps walls and ledges (double jump up to ~13 studs) and short gaps instead of running around them.",
        Callback = function(value) bot.jumpOver = value == true end})
    farmControls.lockCamera = move:AddToggle({Name = "Lock camera on target", Default = true, Flag = "bot_lock_camera",
        Description = "Keeps your view on whoever it's fighting, so moves aimed with the camera go at them.",
        Callback = function(value) bot.lockCamera = value == true end})
    farmControls.aimMouse = move:AddToggle({Name = "Point the mouse at target", Default = false, Flag = "bot_aim_mouse",
        Description = "For moves aimed with the cursor. Moves your real mouse, so only while Roblox is the focused window.",
        Callback = function(value) bot.aimMouse = value == true end})
    if not canAimMouse then farmControls.aimMouse:Lock() end

    local spawn = farmTab:CreateSection("Auto spawn")
    local spawnToggle = addToggle(spawn, {Name = "Auto spawn", Default = false, Flag = "spawn_enabled", Panic = false,
        Description = "Presses Play on the title screen and picks your character in the lobby, so a farm never sits on a menu after a hop or a death.",
        Callback = function(value) spawner.enabled = value == true end})
    if not correctGame then spawnToggle:Lock() end
    presetToggles.spawn = spawnToggle
    spawn:AddInput({Name = "Character", Placeholder = "blank = last played", Flag = "spawn_character",
        Description = "The name on its button in the character menu. The start of the name is enough.",
        Callback = function(text)
            spawner.character = tostring(text or "")
            if spawner.character ~= "" and not spawner.Pick() then
                pcall(function() BPUI:Notify({Title = "Auto spawn", Content = "No character called \"" .. spawner.character .. "\" in the menu", Type = "Warning", Duration = 3}) end)
            end
        end})
    presetToggles.noAfk = spawn:AddToggle({Name = "Stay off the AFK team", Default = false, Flag = "spawn_no_afk",
        Description = "If the game marks you AFK, presses the afk button again to come back.",
        Callback = function(value) spawner.noAfk = value == true end})
    ui.spawnStatus = spawn:AddLabel({Text = "off", Style = "Sub"})

    local night = farmTab:CreateSection("Overnight")
    presetToggles.hop = night:AddToggle({Name = "Hop when there's nobody to fight", Default = false, Flag = "hop_enabled",
        Description = "Joins another server, picked from the game's server list, once the farm has had no target for a while.",
        Callback = function(value) hop.enabled = value == true end})
    farmControls.hopAfter = night:AddSlider({Name = "Wait before hopping", Min = 30, Max = 300, Default = 90, Increment = 10, Suffix = " s", Flag = "hop_after",
        Callback = function(value) hop.after = tonumber(value) or 90 end})
    presetToggles.skipJuggernaut = night:AddToggle({Name = "Skip Juggernaut servers", Default = false, Flag = "hop_skip_juggernaut",
        Description = "Leaves a server as soon as it's playing Juggernaut, for one that has people in and isn't. Hops always pick a non-Juggernaut server.",
        Callback = function(value) hop.skipJuggernaut = value == true end})
    ui.hopStatus = night:AddLabel({Text = "off", Style = "Sub"})

    local BEST = {
        targets = "Players", team = "Enemies only", goAfter = "Whoever is nearest", skipAfk = true, skipUlt = true,
        moves = true, reach = 10, awaken = true, trade = true, smart = true,
        sprint = true, dash = true, jump = true, lockCamera = true, aimMouse = false, hopAfter = 60,
    }
    local function applyBest()
        for key, value in pairs(BEST) do
            local element = farmControls[key]
            if element then pcall(function() element:Set(value) end) end
        end
    end
    night:AddButton({Name = "Best farm settings", ButtonText = "Apply", Callback = function()
        applyBest()
        pcall(function() BPUI:Notify({Title = "Auto Farm", Content = "Farm settings set to what works best. Nothing was switched on.", Duration = 4}) end)
    end})
    night:AddButton({Name = "Set up for overnight", ButtonText = "Turn on", Callback = function()
        applyBest()
        for _, key in ipairs({"antiAfk", "rejoin", "block", "blockFarm", "spawn", "noAfk", "hop", "skipJuggernaut", "bot"}) do
            local element = presetToggles[key]
            if element then pcall(function() element:Set(true) end) end
        end
        pcall(function()
            BPUI:Notify({Title = "Overnight", Content = rejoin.loader ~= "" and "Best farm settings, plus farm, auto spawn, auto block, anti-AFK, rejoin, server hop and Juggernaut skip are on."
                or "All on. If the hub doesn't come back after a hop, paste your loader in Misc > Server.", Duration = 5})
        end)
    end})
end

local defenseTab = window:CreateTab({Name = "Defense", Icon = "shield"})
do
    local section = defenseTab:CreateSection("Auto block")
    local blockToggle = addToggle(section, {Name = "Auto block", Default = false, Flag = "auto_block",
        Description = "Blocks when a nearby enemy starts an attack. Works with Roblox in the background.",
        Callback = function(value) autoBlock.SetEnabled(value) end})
    presetToggles.block = blockToggle
    section:AddKeybind({Name = "Keybind", Default = Enum.KeyCode.F2, Mode = "Press", Flag = "auto_block_key",
        Callback = function() if alive then blockToggle:Set(not autoBlock.enabled) end end})
    ui.autoBlock = section:AddLabel({Text = "off", Style = "Sub"})
    local tuning = defenseTab:CreateSection("Tuning")
    tuning:AddSlider({Name = "Range", Min = 6, Max = 30, Default = 14, Increment = 1, Suffix = " studs", Flag = "auto_block_range",
        Description = "How close an enemy's attack has to start. Moves count from twice as far.",
        Callback = function(value) autoBlock.range = tonumber(value) or 14 end})
    tuning:AddSlider({Name = "Hold", Min = 0.2, Max = 1, Default = 0.45, Increment = 0.05, Suffix = " s", Flag = "auto_block_hold",
        Description = "How long block stays up after each attack starts.",
        Callback = function(value) autoBlock.hold = tonumber(value) or 0.45 end})
    tuning:AddToggle({Name = "Skip guardbreak moves", Default = true, Flag = "auto_block_skip_gb",
        Description = "Moves that go through block aren't worth blocking.",
        Callback = function(value) autoBlock.skipGuardbreaks = value == true end})
    tuning:AddToggle({Name = "Ping compensation", Default = true, Flag = "auto_block_ping",
        Description = "Holds block a little longer by your ping, since hits arrive later on your screen.",
        Callback = function(value) autoBlock.pingComp = value == true end})
    tuning:AddToggle({Name = "Let the 5th hit through", Default = false, Flag = "auto_block_finisher",
        Description = "Drops block for a chain's guard-breaking 5th hit so block isn't locked afterwards. About 22% less damage on the Attack Dummy.",
        Callback = function(value) autoBlock.letFinisher = value == true end})
    local face = defenseTab:CreateSection("Face check")
    local faceToggle = face:AddToggle({Name = "Only block attacks aimed at you", Default = true, Flag = "auto_block_face",
        Description = "Skips enemies swinging the other way.",
        Callback = function(value) autoBlock.faceCheck = value == true end})
    face:AddSlider({Name = "Facing angle", DependsOn = faceToggle, Min = 30, Max = 120, Default = 75, Increment = 5, Suffix = " deg",
        Flag = "auto_block_face_angle", Description = "How far off pointing at you they can be and still count.",
        Callback = function(value) autoBlock.faceAngle = tonumber(value) or 75 end})
    local human = defenseTab:CreateSection("Look human")
    human:AddSlider({Name = "Reaction delay", Min = 0, Max = 150, Default = 0, Increment = 10, Suffix = " ms", Flag = "auto_block_react",
        Description = "Waits a random part of this before blocking. M1s land about 210 ms after they start, so keep it low.",
        Callback = function(value) autoBlock.reactMs = tonumber(value) or 0 end})
    human:AddSlider({Name = "Miss chance", Min = 0, Max = 50, Default = 0, Increment = 5, Suffix = " %", Flag = "auto_block_miss",
        Description = "Lets this share of attacks through on purpose.",
        Callback = function(value) autoBlock.missChance = tonumber(value) or 0 end})
    presetToggles.blockFarm = tuning:AddToggle({Name = "Keep blocking while auto farm runs", Default = false, Flag = "auto_block_farm",
        Description = "Off: auto block waits while the farm is on, so it doesn't cut your attacks short.",
        Callback = function(value) autoBlock.whileFarming = value == true end})
    tuning:AddLabel({Text = "the 5th hit of an M1 chain knocks block off for a few seconds; nothing gets around that", Style = "Sub"})
end

local visualsTab = window:CreateTab({Name = "Visuals", Icon = "eye"})
do
    local espSection = visualsTab:CreateSection("ESP")
    local espToggle = addToggle(espSection, {Name = "Enabled", Default = false, Flag = "esp_enabled",
        Callback = function(value) esp.enabled = value == true and alive end})
    espSection:AddKeybind({Name = "Keybind", Default = Enum.KeyCode.F4, Mode = "Press", Flag = "esp_key",
        Callback = function() if alive then espToggle:Set(not esp.enabled) end end})
    ui.espStatus = espSection:AddLabel({Text = "off", Style = "Sub"})

    local show = visualsTab:CreateSection("Show")
    for _, option in ipairs({
        {"outline", "Outline"}, {"fill", "Fill"}, {"labels", "Name"}, {"distance", "Distance"},
        {"healthBar", "Health bar"}, {"modeBar", "Mode bar"}, {"cooldowns", "Move cooldowns"},
    }) do
        local key = option[1]
        show:AddToggle({Name = option[2], Default = true, Flag = "esp_" .. key,
            Callback = function(value) esp[key] = value == true end})
    end
    show:AddLabel({Text = "cooldowns: green = ready, orange = charging", Style = "Sub"})
    show:AddLabel({Text = "mode: purple = charging, gold = ready", Style = "Sub"})

    local filters = visualsTab:CreateSection("Filters")
    filters:AddToggle({Name = "Hide teammates", Default = true, Flag = "esp_hide_team",
        Callback = function(value) esp.hideTeammates = value == true end})
    filters:AddToggle({Name = "Hide AFK", Default = true, Flag = "esp_hide_afk",
        Callback = function(value) esp.hideAfk = value == true end})
    filters:AddToggle({Name = "Limit distance", Default = false, Flag = "esp_limit_distance",
        Callback = function(value) esp.limitDistance = value == true end})
    filters:AddSlider({Name = "Max distance", Min = 100, Max = 5000, Default = 1500, Increment = 50, Suffix = " studs",
        Flag = "esp_max_distance", Callback = function(value) esp.maxDistance = tonumber(value) or 1500 end})

    local colors = visualsTab:CreateSection("Colors")
    colors:AddToggle({Name = "Team colors", Default = true, Flag = "esp_team_colors",
        Callback = function(value) esp.teamColors = value == true end})
    colors:AddColorPicker({Name = "Enemy", Default = esp.enemyColor, Flag = "esp_enemy_color",
        Callback = function(value) esp.enemyColor = value end})
    colors:AddColorPicker({Name = "Teammate", Default = esp.allyColor, Flag = "esp_ally_color",
        Callback = function(value) esp.allyColor = value end})

    local panelSection = visualsTab:CreateSection("Target panel")
    local panelToggle = addToggle(panelSection, {Name = "Target panel", Default = false, Flag = "panel_enabled",
        Description = "Card with your target's HP, mode and cooldowns. Drag it to move it.",
        Callback = function(value) panel.enabled = value == true and alive end})
    panelSection:AddKeybind({Name = "Keybind", Default = Enum.KeyCode.F5, Mode = "Press", Flag = "panel_key",
        Callback = function() if alive then panelToggle:Set(not panel.enabled) end end})
    panelSection:AddSlider({Name = "Range", Min = 25, Max = 1000, Default = 150, Increment = 25, Suffix = " studs",
        Flag = "panel_range", Description = "How close an enemy has to be when you're not farming.",
        Callback = function(value) panel.range = tonumber(value) or 150 end})

    local alertSection = visualsTab:CreateSection("Mode alerts")
    addToggle(alertSection, {Name = "Enemy mode ready", Default = false, Flag = "alert_enemies",
        Callback = function(value) alerts.enemies = value == true end})
    alertSection:AddToggle({Name = "Only enemies", Default = true, Flag = "alert_enemies_only",
        Callback = function(value) alerts.enemiesOnly = value == true end})
    addToggle(alertSection, {Name = "My mode ready", Default = false, Flag = "alert_own",
        Callback = function(value) alerts.own = value == true end})
end

local compTab = window:CreateTab({Name = "Comp", Icon = "trophy"})
do
    local hud = compTab:CreateSection("Comp HUD")
    local compToggle = addToggle(hud, {Name = "Comp HUD", Default = false, Flag = "comp_enabled",
        Description = "Reach ring and enemy cooldowns. Only shows what the game already sends you.",
        Callback = function(value) comp.enabled = value == true and alive end})
    hud:AddKeybind({Name = "Keybind", Default = Enum.KeyCode.Insert, Mode = "Press", Flag = "comp_key",
        Callback = function() if alive then compToggle:Set(not comp.enabled) end end})
    hud:AddToggle({Name = "FPS saver", Default = false, Flag = "comp_fps_saver",
        Description = "Hides the ring and strips without turning the HUD off.",
        Callback = function(value) comp.fpsSaver = value == true end})
    ui.compStatus = hud:AddLabel({Text = "off", Style = "Sub"})

    local ringSection = compTab:CreateSection("Reach ring")
    ringSection:AddToggle({Name = "Ring", Default = true, Flag = "comp_ring",
        Description = "Lights up when an enemy is inside your M1 reach.",
        Callback = function(value) comp.ring = value == true end})
    ringSection:AddSlider({Name = "M1 reach", Min = 6, Max = 14, Default = 9.5, Increment = 0.1, Suffix = " studs",
        Flag = "comp_reach", Description = "Measured: lands at 9.8, misses at 10. 9.5 leaves room for ping.",
        Callback = function(value) comp.reach = tonumber(value) or 9.5 end})
    ringSection:AddSlider({Name = "Opacity", Min = 0.1, Max = 1, Default = 0.55, Increment = 0.05, Flag = "comp_ring_opacity",
        Callback = function(value) comp.ringOpacity = tonumber(value) or 0.55 end})

    local cds = compTab:CreateSection("Cooldown strips")
    cds:AddToggle({Name = "Focus target strip", Default = true, Flag = "comp_strips",
        Description = "Over the enemy you're looking at: one cell per move, seconds left once learned.",
        Callback = function(value) comp.strips = value == true end})
    local holdKeys = {["Left Alt"] = Enum.KeyCode.LeftAlt, Tab = Enum.KeyCode.Tab, ["Caps Lock"] = Enum.KeyCode.CapsLock,
        ["Left Ctrl"] = Enum.KeyCode.LeftControl, None = Enum.KeyCode.Unknown}
    cds:AddDropdown({Name = "Show all while holding", Options = {"Left Alt", "Tab", "Caps Lock", "Left Ctrl", "None"},
        Default = "Left Alt", Flag = "comp_hold_key",
        Callback = function(value) comp.holdKey = holdKeys[value] or Enum.KeyCode.LeftAlt comp.holding = false end})
    cds:AddSlider({Name = "Range", Min = 20, Max = 300, Default = 80, Increment = 10, Suffix = " studs",
        Flag = "comp_strip_range", Callback = function(value) comp.stripRange = tonumber(value) or 80 end})
    cds:AddColorPicker({Name = "Accent", Default = comp.accent, Flag = "comp_accent",
        Callback = function(value) comp.accent = value end})
    cds:AddLabel({Text = "seconds show after a move has ticked once; before that, its initials", Style = "Sub"})
end

local playerInfoTab = window:CreateTab({Name = "Player Info", Icon = "users"})
local playerInfoSection = playerInfoTab:CreateSection("Players")
ui.playerCount = playerInfoSection:AddLabel({Text = "loading...", Style = "Sub"})
local playerCards = {}

local function playerCardText(targetPlayer)
    local title = targetPlayer.DisplayName .. "  (" .. tostring(Game.characterName(targetPlayer)) .. ")"
    local mode = math.floor(Game.chargeFraction(targetPlayer) * 100 + 0.5)
    local lines = {string.format("%s  |  %d kills, %d deaths  |  %d dmg  |  mode %s",
        targetPlayer.Team and targetPlayer.Team.Name or "no team",
        Game.stat(targetPlayer, "Kills"), Game.stat(targetPlayer, "Deaths"),
        math.floor(Game.stat(targetPlayer, "Damage") + 0.5), mode >= 100 and "READY" or (mode .. "%"))}
    local skill = Game.usingSkill(targetPlayer.Character)
    if skill then lines[#lines + 1] = "using: " .. skill end
    for _, move in ipairs(Game.moves(targetPlayer)) do
        lines[#lines + 1] = move.name .. ": " .. (move.ready and "ready" or (math.floor(move.progress * 100) .. "%"))
    end
    return title, table.concat(lines, "\n")
end

local function refreshPlayerInfo()
    local list = Players:GetPlayers()
    for _, targetPlayer in ipairs(list) do
        local card = playerCards[targetPlayer]
        if not card then
            card = playerInfoSection:AddParagraph({Title = targetPlayer.Name, Content = ""})
            playerCards[targetPlayer] = card
        end
        local title, content = playerCardText(targetPlayer)
        card:SetTitle(title)
        card:SetContent(content)
    end
    for targetPlayer, card in pairs(playerCards) do
        if targetPlayer.Parent ~= Players then
            card:Destroy()
            playerCards[targetPlayer] = nil
        end
    end
    ui.playerCount:Set(#list .. " players")
end

local skillsTab = window:CreateTab({Name = "Skills", Icon = "sparkles"})
do
    local main = skillsTab:CreateSection("Move sweeps")
    local sweepToggle = addToggle(main, {Name = "Move sweeps", Default = false, Flag = "sweeps_enabled",
        Description = "After you use one of the moves below, its projectile is walked through every target in range, nearest first.",
        Callback = function(value) sweeps.enabled = value == true and correctGame end})
    if not correctGame then sweepToggle:Lock() end
    main:AddKeybind({Name = "Keybind", Default = Enum.KeyCode.Home, Mode = "Press", Flag = "sweeps_key",
        Callback = function() if alive and correctGame then sweepToggle:Set(not sweeps.enabled) end end})
    teamDropdown(main, "sweeps_team", function(mode) sweeps.teamMode = mode end)
    main:AddSlider({Name = "Range", Min = 25, Max = 600, Default = 250, Increment = 25, Suffix = " studs", Flag = "sweeps_range",
        Callback = function(value) sweeps.range = tonumber(value) or 250 end})
    main:AddSlider({Name = "Frames per target", Min = 2, Max = 12, Default = 6, Increment = 1, Flag = "sweeps_frames",
        Description = "How long it stays on each target. More lands more reliably; fewer reaches more people before the move ends.",
        Callback = function(value) sweeps.frames = tonumber(value) or 6 end})
    ui.sweeps = main:AddLabel({Text = "off", Style = "Sub"})

    local list = skillsTab:CreateSection("Moves")
    for _, move in ipairs(sweeps.MOVES) do
        list:AddToggle({Name = move.name, Default = true, Flag = "sweep_" .. move.key,
            Callback = function(value) sweeps.on[move.key] = value == true end})
    end
    list:AddLabel({Text = "Yusuke's Spirit Gun and Krillin's kiblasts have their own in Characters. Accelerator's Quake can't be swept: the server does its damage.", Style = "Sub"})
end

local charactersTab = window:CreateTab({Name = "Characters", Icon = "users"})

local function assistControls(section, config)
    local element = addToggle(section, {Name = config.name, Default = config.default, Flag = config.flag,
        Description = config.description, Callback = config.callback})
    if config.locked then element:Lock() end
    section:AddKeybind({Name = "Keybind", Default = config.key, Mode = "Press", Flag = config.flag .. "_key",
        Callback = function() if alive and not config.locked then element:Set(not config.get()) end end})
    return section:AddLabel({Text = "-", Style = "Sub"})
end

do
    local chances = charactersTab:CreateSection("Hit chance")
    chances:AddLabel({Text = "below 100% a helper sometimes leaves the timing to you, so it doesn't hit every single one", Style = "Sub"})
    for _, row in ipairs({{"blackFlash", "Black Flash (any character)"}, {"yuji", "Yuji"}, {"nanami", "Nanami"}, {"kokushibo", "Kokushibo"}}) do
        local key = row[1]
        chances:AddSlider({Name = row[2], Min = 50, Max = 100, Default = 100, Increment = 5, Suffix = " %", Flag = "hit_chance_" .. key,
            Callback = function(value) hitChance[key] = tonumber(value) or 100 end})
    end
    local section = charactersTab:CreateSection("Any character: Black Flash")
    ui.anyBlackFlash = assistControls(section, {name = "Auto Black Flash", default = anyBlackFlash.enabled,
        flag = "any_black_flash", key = Enum.KeyCode.F3, locked = not supported,
        description = "Clicks the zoom-in Black Flash check for whoever you're playing.",
        get = function() return anyBlackFlash.enabled end,
        callback = function(value)
            anyBlackFlash.enabled = value == true and supported and alive
            anyBlackFlash.last = anyBlackFlash.enabled and "waiting" or "off"
        end})
    section:AddLabel({Text = "if Yuji's own Black Flash misfires with this on, turn one off", Style = "Sub"})
end

do
    local blackFlash = charactersTab:CreateSection("Yuji: Black Flash (move 2)")
    ui.yujiBlackFlash = assistControls(blackFlash, {name = "Auto Black Flash", default = yuji.blackFlash,
        flag = "yuji_black_flash", key = Enum.KeyCode.F8, locked = not supported,
        description = "Clicks for you when the Black Flash cue hits.",
        get = function() return yuji.blackFlash end,
        callback = function(value)
            yuji.blackFlash = value == true and supported and alive
            yuji.blackFlashLast = yuji.blackFlash and "waiting for move 2" or "off"
        end})
    local divergent = charactersTab:CreateSection("Yuji: Divergent Fist (move 1)")
    ui.yujiDivergent = assistControls(divergent, {name = "Auto Divergent", default = yuji.divergent,
        flag = "yuji_divergent", key = Enum.KeyCode.F9, locked = not supported,
        description = "Works after you land a Black Flash.",
        get = function() return yuji.divergent end,
        callback = function(value)
            yuji.divergent = value == true and supported and alive
            yuji.divergentLast = yuji.divergent and "waiting for move 1" or "off"
        end})
    local skull = charactersTab:CreateSection("Yuji: Skull Smash (move 4)")
    local skullToggle = addToggle(skull, {Name = "Auto Skull Smash", Default = false, Flag = "yuji_skull",
        Description = "Clicks about 1.5s into the move. Timing can be off.",
        Callback = function(value)
            yuji.skull = value == true and supported and alive
            yuji.skullLast = yuji.skull and "waiting for move 4" or "off"
        end})
    if not supported then skullToggle:Lock() end
    ui.yujiSkull = skull:AddLabel({Text = "-", Style = "Sub"})
end

do
    local section = charactersTab:CreateSection("Nanami: Ratio / 7:3")
    ui.nanami = assistControls(section, {name = "Auto hit", default = nanami.enabled,
        flag = "nanami_hit", key = Enum.KeyCode.F6, locked = not correctGame,
        description = "Hits the timing bar on move 1 and the second 7:3.",
        get = function() return nanami.enabled end,
        callback = function(value)
            nanami.enabled = value == true and correctGame and alive
            nanami.last = nanami.enabled and "waiting" or "off"
        end})
end

do
    local section = charactersTab:CreateSection("Kokushibo: timed right click")
    ui.kokushibo = assistControls(section, {name = "Auto right click", default = false,
        flag = "kokushibo_check", key = Enum.KeyCode.F12, locked = not kokushibo.available,
        description = "Presses during the check's window at a different moment each time, so the game's same-timing kick never sees a pattern.",
        get = function() return kokushibo.enabled end,
        callback = function(value)
            kokushibo.enabled = value == true and kokushibo.available and alive
            kokushibo.last = kokushibo.enabled and "waiting" or "off"
        end})
    section:AddLabel({Text = "works with roblox in the background too", Style = "Sub"})
end

do
    local section = charactersTab:CreateSection("Yusuke: Spirit Gun / Demon Gun")
    ui.yusuke = assistControls(section, {name = "Gun sweep", default = yusuke.enabled,
        flag = "yusuke_sweep", key = Enum.KeyCode.F7, locked = not yusuke.available,
        description = "Bounces your Spirit Gun / Demon Gun shot through every nearby target.",
        get = function() return yusuke.enabled end,
        callback = function(value) yusuke.enabled = value == true and yusuke.available and alive end})
    teamDropdown(section, "yusuke_team", function(mode) yusuke.teamMode = mode end)
end

do
    local section = charactersTab:CreateSection("Krillin: kiblast")
    ui.krillin = assistControls(section, {name = "Redirect kiblasts", default = krillin.enabled,
        flag = "krillin_redirect", key = Enum.KeyCode.F10, locked = not correctGame,
        description = "Sends each volley at one random player.",
        get = function() return krillin.enabled end,
        callback = function(value)
            krillin.enabled = value == true and correctGame and alive
            krillin.last = krillin.enabled and "waiting for kiblast" or "off"
        end})
    local targets = charactersTab:CreateSection("Krillin: targets")
    teamDropdown(targets, "krillin_team", function(mode) krillin.teamMode = mode end)
    targets:AddToggle({Name = "Hit anyone if no enemies", Default = false, Flag = "krillin_fallback",
        Callback = function(value) krillin.fallback = value == true end})
    local timingSection = charactersTab:CreateSection("Krillin: timing")
    timingSection:AddSlider({Name = "Volley gap", Min = 0.1, Max = 1, Default = 0.35, Increment = 0.05, Suffix = " s",
        Flag = "krillin_gap", Callback = function(value) krillin.volleyGap = tonumber(value) or 0.35 end})
    timingSection:AddSlider({Name = "Hold per part", Min = 0.1, Max = 0.8, Default = 0.4, Increment = 0.05, Suffix = " s",
        Flag = "krillin_hold", Callback = function(value) krillin.holdTime = tonumber(value) or 0.4 end})
end

local clientTab = window:CreateTab({Name = "Client", Icon = "monitor"})
do
    local look = clientTab:CreateSection("Visuals")
    for _, option in ipairs({
        {"fullbright", "Fullbright", "Lights the map evenly, day or night."},
        {"noFog", "No fog", nil},
        {"noAtmosphere", "No atmosphere", "Removes the haze."},
        {"noDecals", "Remove decals", "Hides decals and textures."},
        {"noParticles", "Remove particles", "Hides particles, trails and beams, move effects included."},
    }) do
        local key = option[1]
        look:AddToggle({Name = option[2], Default = false, Flag = "client_" .. key, Description = option[3],
            Callback = function(value) client.Set(key, value) end})
    end
    local perf = clientTab:CreateSection("Performance")
    perf:AddToggle({Name = "FPS boost", Default = false, Flag = "client_fpsBoost",
        Description = "Lowest graphics quality and no shadows. Pair it with Remove particles for the most.",
        Callback = function(value) client.Set("fpsBoost", value) end})
    local other = clientTab:CreateSection("Other")
    other:AddToggle({Name = "Streamer mode", Default = false, Flag = "client_streamer",
        Description = "Hides the player list so names don't show on stream.",
        Callback = function(value) client.Set("streamer", value) end})
    other:AddButton({Name = "Reset character", ButtonText = "Reset", Callback = client.Reset})
    other:AddLabel({Text = "rejoin and server hop are in Misc, and in the hub's Utilities tab", Style = "Sub"})
end

local macroTab = window:CreateTab({Name = "Macros", Icon = "list"})
do
    local function say(text, kind)
        pcall(function() BPUI:Notify({Title = "Macros", Content = text, Type = kind or "Info", Duration = 3}) end)
    end

    local rec = macroTab:CreateSection("Record")
    local recButton
    local function toggleRecording()
        if macro.recording then
            macro.StopRecording()
            if recButton then recButton:SetText("Record") end
        else
            macro.StartRecording()
            if recButton then recButton:SetText("Stop") end
        end
    end
    recButton = rec:AddButton({Name = "Record your inputs", Desc = "Your M1s, moves, block, dodge, run and mode, with their timing.",
        ButtonText = "Record", Callback = toggleRecording})
    rec:AddKeybind({Name = "Record key", Default = Enum.KeyCode.PageUp, Mode = "Press", Flag = "macro_record_key",
        Callback = function() if alive then toggleRecording() end end})
    ui.macro = rec:AddLabel({Text = "nothing recorded", Style = "Sub"})

    local play = macroTab:CreateSection("Play")
    local function togglePlaying()
        if macro.playing then macro.Stop() else macro.Play() end
    end
    play:AddButton({Name = "Play or stop", ButtonText = "Play", Style = "Primary", Callback = togglePlaying})
    play:AddKeybind({Name = "Play key", Default = Enum.KeyCode.PageDown, Mode = "Press", Flag = "macro_play_key",
        Callback = function() if alive then togglePlaying() end end})
    play:AddToggle({Name = "Loop", Default = false, Flag = "macro_loop",
        Description = "Plays it again and again until you stop it.",
        Callback = function(value) macro.loop = value == true end})
    play:AddSlider({Name = "Speed", Min = 0.5, Max = 2, Default = 1, Increment = 0.05, Suffix = "x", Flag = "macro_speed",
        Callback = function(value) macro.speed = tonumber(value) or 1 end})

    local files = macroTab:CreateSection("Saved macros")
    local name, picked, code = "", nil, ""
    local picker
    files:AddInput({Name = "Name", Placeholder = "my combo", Callback = function(text) name = tostring(text or "") end})
    files:AddButton({Name = "Save the current macro", ButtonText = "Save", Callback = function()
        local ok, why = macro.Save(name)
        say(why, ok and "Success" or "Warning")
        if ok and picker then picker:Refresh(macro.List()) end
    end})
    picker = files:AddDropdown({Name = "Macro", Options = macro.List(), Callback = function(value) picked = value end})
    files:AddButton({Name = "Load", ButtonText = "Load", Callback = function()
        if not picked then say("pick one first", "Warning") return end
        local ok, why = macro.Load(picked)
        say(why, ok and "Success" or "Error")
    end})
    files:AddButton({Name = "Delete", ButtonText = "Delete", Style = "Danger", Callback = function()
        if not picked then say("pick one first", "Warning") return end
        local ok, why = macro.Delete(picked)
        say(why, ok and "Info" or "Error")
        picked = nil
        picker:Refresh(macro.List())
    end})
    files:AddButton({Name = "Refresh the list", ButtonText = "Refresh", Callback = function() picker:Refresh(macro.List()) end})

    local share = macroTab:CreateSection("Share")
    share:AddButton({Name = "Copy as a code", ButtonText = "Copy", Callback = function()
        local text = macro.Export()
        if not text then say("record something first", "Warning") return end
        if type(setclipboard) == "function" and pcall(setclipboard, text) then
            say("code copied", "Success")
        else
            say(text, "Info")
        end
    end})
    share:AddInput({Name = "Paste a code", Placeholder = "CATNMACRO:...", Callback = function(text, enter)
        if not enter or tostring(text or "") == "" then return end
        local ok, why = macro.Import(text)
        say(why, ok and "Success" or "Error")
    end})
end

local miscTab = window:CreateTab({Name = "Misc", Icon = "settings"})
do
    local general = miscTab:CreateSection("General")
    presetToggles.antiAfk = general:AddToggle({Name = "Anti-AFK", Default = false, Flag = "misc_anti_afk",
        Description = "Stops the Roblox idle kick.",
        Callback = function(value) misc.antiAfk = value == true end})
    general:AddKeybind({Name = "Turn everything off", Default = Enum.KeyCode.End, Mode = "Press", Flag = "misc_panic_key",
        Callback = function()
            for _, element in ipairs(toggles) do pcall(function() element:Set(false) end) end
            pcall(function() BPUI:Notify({Title = "Catn Hub", Content = "everything off", Duration = 2}) end)
        end})

    local server = miscTab:CreateSection("Server")
    server:AddLabel({Text = "job id: " .. (game.JobId ~= "" and game.JobId or "studio"), Style = "Sub"})
    server:AddButton({Name = "Rejoin this server", Callback = function()
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player) end)
    end})
    presetToggles.rejoin = server:AddToggle({Name = "Rejoin if kicked or disconnected", Default = false, Flag = "auto_rejoin",
        Description = "Joins ABA again when Roblox shows a kick or disconnect message.",
        Callback = function(value) rejoin.enabled = value == true rejoin.last = rejoin.enabled and "watching" or "off" end})
    server:AddInput({Name = "Run after rejoining", Placeholder = "your loadstring line", Flag = "auto_rejoin_loader",
        Description = "Paste the line you use to load the hub and it starts again in the new server.",
        Callback = function(text) rejoin.loader = tostring(text or "") end})
    ui.rejoin = server:AddLabel({Text = "off", Style = "Sub"})
    if type(queue_on_teleport) ~= "function" then
        server:AddLabel({Text = "this executor can't run things after a teleport, so only the rejoin works", Style = "Sub"})
    end

    local replicated = game:GetService("ReplicatedStorage")
    local function find(root, ...)
        local node = root
        for _, name in ipairs({...}) do node = node and node:FindFirstChild(name) end
        return node
    end
    local checks = {
        {"ABA place", "everything", function() return correctGame end},
        {"mouse1click", "click assists, M1", function() return click ~= nil end},
        {"mousemoveabs", "Auto Farm mouse aim", function() return canAimMouse end, true},
        {"isnetworkowner", "Yusuke sweep", function() return canCheckOwner end},
        {"gethui", "hiding ESP / panel", function() return type(gethui) == "function" end, true},
        {"NanamiCutGUI bar", "Nanami auto hit", function() return find(replicated, "NanamiCutGUI", "MainBar", "Cutter") ~= nil end},
        {"NanamiCheck", "Nanami auto hit", function() return replicated:FindFirstChild("NanamiCheck") ~= nil end},
        {"BlackFlashCheck", "Black Flash (any)", function() return replicated:FindFirstChild("BlackFlashCheck") ~= nil end},
        {"KokushiboCheck", "Kokushibo right click", function() return kokushibo.available end},
        {"Player.Charge", "mode bars, alerts", function()
            local charge = player:FindFirstChild("Charge")
            return charge ~= nil and (pcall(function() return charge.MaxValue end))
        end},
        {"Player.Stats", "session, Player Info", function()
            return find(player, "Stats", "Kills") ~= nil and find(player, "Stats", "Damage") ~= nil
        end},
        {"ReplicatedStats.Gold", "session gold", function() return find(player, "ReplicatedStats", "Gold") ~= nil end},
        {"move cooldowns", "cooldown bars, ready moves", function()
            for _, targetPlayer in ipairs(Players:GetPlayers()) do
                local backpack = targetPlayer:FindFirstChildOfClass("Backpack")
                if backpack and backpack:FindFirstChildOfClass("Configuration") then return true end
            end
            return false
        end, true},
        {"workspace.Live", "Yusuke sweep", function() return workspace:FindFirstChild("Live") ~= nil end},
        {"workspace.Thrown", "Yusuke sweep", function() return workspace:FindFirstChild("Thrown") ~= nil end, true},
        {".AFK team", "AFK filters", function()
            for _, team in ipairs(game:GetService("Teams"):GetTeams()) do
                if string.find(string.lower(team.Name), "afk", 1, true) then return true end
            end
            return false
        end, true},
        {"UseMode action", "Auto mode (G)", function() return find(player, "PlayerScripts", "BaseContext", "UseMode") ~= nil end, true},
    }

    local checkSection = miscTab:CreateSection("Self check")
    checkSection:AddLabel({Text = executor, Style = "Sub"})
    local summary = checkSection:AddLabel({Text = "checking...", Style = "Sub"})
    local rows = {}
    for index, check in ipairs(checks) do rows[index] = checkSection:AddLabel({Text = check[1], Style = "Sub"}) end

    local function runChecks()
        local missing, unsure = {}, 0
        for index, check in ipairs(checks) do
            local okCall, passed = pcall(check[3])
            passed = okCall and passed == true
            if passed then
                rows[index]:Set("ok  " .. check[1])
            elseif check[4] then
                unsure = unsure + 1
                rows[index]:Set("not found  " .. check[1] .. "  (" .. check[2] .. ", can be normal outside a match)")
            else
                missing[#missing + 1] = check[2]
                rows[index]:Set("MISSING  " .. check[1] .. "  ->  " .. check[2] .. " won't work")
            end
        end
        local text = #missing == 0 and ("all good" .. (unsure > 0 and (", " .. unsure .. " not found yet") or ""))
            or (#missing .. " missing: " .. table.concat(missing, ", "))
        summary:Set(text)
        ui.selfCheck:Set("self check: " .. text)
        state.selfCheck = text
        return #missing
    end
    state.RunSelfCheck = runChecks
    checkSection:AddButton({Name = "Run again", Callback = runChecks})

    task.spawn(function()
        task.wait(3)
        if not alive then return end
        local missingCount = runChecks()
        if missingCount > 0 then
            pcall(function()
                BPUI:Notify({Title = "Catn Hub", Content = "self check: " .. missingCount .. " missing, see Misc", Type = "Warning", Duration = 5})
            end)
        end
        while alive do
            task.wait(30)
            if alive then pcall(runChecks) end
        end
    end)
end

if player.Character then bindYuji(player.Character) end
connect(player.CharacterAdded, bindYuji)

window:SelectTab("Overview")
pcall(function()
    window:Notify({Title = "Catn Hub", Content = supported and "loaded, RightShift to open" or "loaded, but this isn't ABA",
        Type = supported and "Success" or "Warning", Duration = 4})
end)

local function tabOpen(tab)
    local ok, open = pcall(function() return window._visible ~= false and window._activeTab == tab end)
    return not ok or open
end

local function onOff(value) return value and "on" or "off" end

task.spawn(function()
    while alive do
        local ok, reason = pcall(function()
            ui.status:Set(supported and ("ABA detected  |  " .. executor) or "Wrong game, features locked")
            ui.character:Set("Character: " .. tostring(Game.characterName(player))
                .. (player.Team and ("  |  Team: " .. player.Team.Name) or ""))
            ui.performance:Set(string.format("FPS: %d  |  ping: %dms", math.floor(1 / math.max(timing.frame, 1e-3) + 0.5),
                math.floor(samplePing() * 1000 + 0.5)))

            local minutes = math.floor((os.clock() - session.started) / 60)
            ui.sessionTime:Set(string.format("time: %dh %dm", math.floor(minutes / 60), minutes % 60))
            ui.sessionGold:Set("gold: +" .. math.floor(session.gold))
            ui.sessionFights:Set(string.format("kills: %d  |  deaths: %d  |  damage: %d",
                session.kills, session.deaths, math.floor(session.damage)))
            local hours = math.max((os.clock() - session.started) / 3600, 1 / 60)
            ui.sessionRate:Set(string.format("per hour: %d kills  |  %d gold", math.floor(session.kills / hours),
                math.floor(session.gold / hours)))
            ui.hopStatus:Set(hop.last)

            local lines = ui.overview
            lines.bot:Set("Auto Farm: " .. onOff(bot.enabled) .. (bot.enabled and ("  (" .. bot.target .. ")") or ""))
            lines.esp:Set("ESP: " .. onOff(esp.enabled) .. (esp.enabled and ("  (" .. esp.shown .. " players)") or ""))
            lines.panel:Set("Target panel: " .. onOff(panel.enabled) .. (panel.subject and ("  (" .. panel.subject .. ")") or ""))
            lines.anyBlackFlash:Set(string.format("Black Flash (any): %s  (%d clicks)", onOff(anyBlackFlash.enabled), anyBlackFlash.clicks))
            lines.yuji:Set(string.format("Yuji: black flash %s, divergent %s, skull smash %s",
                onOff(yuji.blackFlash), onOff(yuji.divergent), onOff(yuji.skull)))
            lines.nanami:Set(string.format("Nanami: auto hit %s  (%d hits)", onOff(nanami.enabled), nanami.hits))
            lines.yusuke:Set("Yusuke: gun sweep " .. onOff(yusuke.enabled))
            lines.krillin:Set("Krillin: kiblast " .. onOff(krillin.enabled))

            ui.botStatus:Set(bot.enabled and (bot.last .. "  |  target: " .. bot.target) or "off")
            ui.spawnStatus:Set(spawner.last)
            ui.macro:Set(macro.last .. ((#macro.events > 0 and not macro.recording) and ("  |  " .. macro.Summary()) or ""))
            ui.espStatus:Set(esp.enabled and (esp.shown .. " players shown") or "off")
            ui.compStatus:Set(comp.enabled and ("focus: " .. (comp.focus or "none")) or "off")

            ui.anyBlackFlash:Set((anyBlackFlash.enabled and anyBlackFlash.last or "off") .. "  |  clicks: " .. anyBlackFlash.clicks)
            ui.yujiBlackFlash:Set((yuji.blackFlash and yuji.blackFlashLast or "off") .. "  |  clicks: " .. yuji.blackFlashClicks)
            ui.yujiDivergent:Set((yuji.divergent and yuji.divergentLast or "off") .. "  |  clicks: " .. yuji.divergentClicks)
            ui.yujiSkull:Set((yuji.skull and yuji.skullLast or "off") .. "  |  clicks: " .. yuji.skullClicks)
            ui.nanami:Set((nanami.enabled and nanami.last or "off") .. "  |  hits: " .. nanami.hits)
            ui.kokushibo:Set((kokushibo.enabled and kokushibo.last or "off") .. "  |  hits: " .. kokushibo.hits)
            ui.autoBlock:Set((autoBlock.enabled and autoBlock.last or "off") .. "  |  blocks: " .. autoBlock.blocks)
            ui.rejoin:Set(rejoin.last)
            ui.yusuke:Set((yusuke.enabled and yusuke.last or "off") .. "  |  shots: " .. yusuke.shots)
            ui.krillin:Set((krillin.enabled and krillin.last or "off") .. "  |  volleys: " .. krillin.volleys)
            ui.sweeps:Set((sweeps.enabled and sweeps.last or "off") .. "  |  casts: " .. sweeps.casts .. "  |  hits: " .. sweeps.hits)

            if tabOpen(playerInfoTab) then refreshPlayerInfo() end
        end)
        if not ok then warn("[Catn Hub] status: " .. tostring(reason)) end
        task.wait(0.5)
    end
end)

return state
