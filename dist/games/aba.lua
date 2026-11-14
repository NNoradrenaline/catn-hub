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

local RUN_ID = tostring(math.floor(os.clock() * 1000) % 1000000000)
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

local function tapAction(name, hold)
    local action = gameAction(name)
    if not action then return false end
    action:Fire(true)
    task.wait(hold or 0.03)
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
    farmGuard = true, dodgeGuardbreaks = true, last = "off", blocks = 0, dodges = 0}
state.AutoBlock = autoBlock
do
    local CollectionService = game:GetService("CollectionService")
    local holdUntil, holding, pressedAt = 0, false, 0
    local watched = setmetatable({}, {__mode = "k"})

    local skills = setmetatable({}, {__mode = "k"})
    local MOVE_CAP = 4
    local lastHitAt, lastDodge = -math.huge, -math.huge
    local dodgeFrom

    local M1_IDS = {["1461128166"] = 1, ["1461128859"] = 2, ["1461136273"] = 3, ["1461136875"] = 4, ["1461137417"] = 5}
    local FLINCH_IDS = {["1461138523"] = true, ["1461139102"] = true, ["1461140455"] = true, ["1461142361"] = true}

    local function guardOn()
        if autoBlock.enabled then return true end
        local bot = state.Bot
        return autoBlock.farmGuard and bot ~= nil and bot.enabled == true and bot.trade ~= false and alive
    end
    autoBlock.GuardOn = guardOn

    autoBlock.Wants = function() return guardOn() and os.clock() < holdUntil end

    local function angleTo(root, mine)
        local toMe = (mine.Position - root.Position) * Vector3.new(1, 0, 1)
        local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
        if toMe.Magnitude < 2 or look.Magnitude < 0.1 then return 0 end
        return math.deg(math.acos(math.clamp(look.Unit:Dot(toMe.Unit), -1, 1)))
    end

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
        if not guardOn() or not alive or os.clock() < quietUntil then return end
        local mine = myRoot()
        if not mine or (root.Position - mine.Position).Magnitude > reach then return end
        if not isEnemy(model) then return end

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
            if not guardOn() or os.clock() < quietUntil then return end
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
    local function chainHit(model, index)
        local chain = chains[model]
        if not chain or os.clock() - chain.last > 1 then
            chain = {count = 0}
            chains[model] = chain
        end

        if index then chain.count = index else chain.count = math.min(chain.count + 1, 4) end
        chain.last = os.clock()

        local root, mine = model:FindFirstChild("HumanoidRootPart"), myRoot()
        if chain.count >= 5 and autoBlock.dodgeGuardbreaks and state.Bot and state.Bot.enabled and dodgeFrom
            and root and mine and (root.Position - mine.Position).Magnitude < autoBlock.range
            and os.clock() - lastDodge >= 2.5 then
            chain.count = 0
            dodgeFrom(root, mine, "dodging " .. model.Name .. "'s finisher")
            return true
        end
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
            if track.Looped then return end
            local id = track.Animation and tostring(track.Animation.AnimationId):match("%d+$")
            if id and FLINCH_IDS[id] then return end

            if not (id and M1_IDS[id]) and (os.clock() - lastOwnAttack < 0.5 or track.Length > 1.5) then return end
            if chainHit(model, id and M1_IDS[id]) then return end
            trigger(model, root, autoBlock.hold, autoBlock.range, "blocking an attack from " .. model.Name)
        end)
        local function skillStarted()
            local skill = Game.usingSkill(model)
            if not skill then return end
            local breaks = breaksGuard(model, skill)
            skills[model] = {name = skill, at = os.clock(), root = root, breaks = breaks}
            if autoBlock.skipGuardbreaks and breaks then
                autoBlock.last = skill .. " breaks guard, not blocking"
                return
            end
            trigger(model, root, 0.35, autoBlock.range * 2, "blocking " .. skill)
        end
        connect(model.ChildAdded, function(child)
            if child.Name ~= "UsingSkill" or not child:IsA("StringValue") then return end
            task.defer(skillStarted)

            connect(child:GetPropertyChangedSignal("Value"), function() task.defer(skillStarted) end)
        end)
        connect(model.ChildRemoved, function(child)
            if child.Name == "UsingSkill" then skills[model] = nil end
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

    local myHumanoid
    local function watchMe()
        local _, humanoid = Game.ownRoot()
        if not humanoid or humanoid == myHumanoid then return end
        myHumanoid = humanoid
        local last = humanoid.Health
        connect(humanoid.HealthChanged, function(hp)
            if hp < last - 0.5 then
                lastHitAt = os.clock()
                local mine = myRoot()
                if mine and guardOn() and os.clock() >= quietUntil then

                    if not Game.isBlocking(player.Character) and os.clock() - lastOwnAttack > 0.6 then
                        holdUntil = math.max(holdUntil, os.clock() + 0.5)
                        autoBlock.last = "got hit, blocking the rest"
                    end
                    for model, s in pairs(skills) do
                        if model.Parent and s.root.Parent and (s.root.Position - mine.Position).Magnitude < 25 then
                            s.hitUntil = os.clock() + 1
                        end
                    end
                end
            end
            last = hp
        end)
    end
    connect(player.CharacterAdded, function() task.wait(1) watchMe() end)

    dodgeFrom = function(root, mine, why)
        local action = gameAction("Dodge")
        if not action or os.clock() - lastDodge < 2.5 then return end

        local character = player.Character
        if character and (character:FindFirstChild("Action") or character:FindFirstChild("NoDodge")
            or (character:FindFirstChild("Slow") and not character:FindFirstChild("DodgeOkay"))) then return end
        local away = (mine.Position - root.Position) * Vector3.new(1, 0, 1)
        if away.Magnitude < 0.1 then away = mine.CFrame.RightVector end
        local side = CFrame.Angles(0, math.rad(math.random() < 0.5 and 70 or -70), 0):VectorToWorldSpace(away.Unit)
        lastDodge = os.clock()
        autoBlock.dodges = autoBlock.dodges + 1
        autoBlock.last = why
        mine.CFrame = CFrame.lookAt(mine.Position, mine.Position + side)
        task.spawn(function()
            pcall(function() action:Fire(true) end)
            task.wait(0.1)
            pcall(function() action:Fire(false) end)
        end)
    end

    connect(RunService.Heartbeat, function()
        local mine = myRoot()
        if guardOn() and mine and os.clock() >= quietUntil then
            if not myHumanoid or not myHumanoid.Parent then watchMe() end
            local now = os.clock()
            local tail = 0.2 + (autoBlock.pingComp and timing.ping or 0)
            for model, s in pairs(skills) do
                if not model.Parent or not s.root.Parent then
                    skills[model] = nil
                elseif (now - s.at < MOVE_CAP or now < (s.hitUntil or 0)) and isEnemy(model) then
                    local d = (s.root.Position - mine.Position).Magnitude

                    local aimed = d < 9 or not autoBlock.faceCheck or angleTo(s.root, mine) < 110
                    if s.breaks and autoBlock.skipGuardbreaks then

                        if autoBlock.dodgeGuardbreaks and d < 24 and aimed and now - s.at < 2 then
                            dodgeFrom(s.root, mine, "dodging " .. s.name .. " (breaks guard)")
                        end
                    elseif d <= autoBlock.range * 2 and aimed then
                        holdUntil = math.max(holdUntil, now + tail)
                        autoBlock.last = ("holding block through %s (%.1fs in)"):format(s.name, now - s.at)
                    end
                end
            end
        end
        local want = guardOn() and alive and os.clock() < holdUntil and mine ~= nil
        local character = player.Character
        local blocking = character and Game.isBlocking(character)
        if want and not holding then
            holding, pressedAt = true, os.clock()
            setBlock(true)
            autoBlock.blocks = autoBlock.blocks + 1
        elseif not want and holding then
            holding = false
            setBlock(false)
        elseif want and holding and not blocking and (os.clock() - pressedAt > 0.2

            or (os.clock() - pressedAt > 0.12 and character and not character:FindFirstChild("Action")
                and not character:FindFirstChild("Slow"))) then

            setBlock(false)
            setBlock(true)
            pressedAt = os.clock()
        end
    end)

    autoBlock.SetEnabled = function(value)
        autoBlock.enabled = value == true and alive
        autoBlock.last = autoBlock.enabled and "watching" or "off"
        if not guardOn() and holding then
            holding = false
            setBlock(false)
        end
    end
    onCleanup(function()
        autoBlock.enabled = false
        if holding then holding = false setBlock(false) end
    end)
end

local brain = {enabled = true, last = "learning", data = nil}
state.Brain = brain
do
    local HttpService = game:GetService("HttpService")
    local FILE = "BPHubABA/brain.json"
    local dirty, savedAt = false, os.clock()

    local function blank()
        return {v = 1, fights = 0, moves = {}, styles = {}, trades = {}, players = {},
            score = {learned = {n = 0, dealt = 0, taken = 0, secs = 0, kills = 0, deaths = 0},
                plain = {n = 0, dealt = 0, taken = 0, secs = 0, kills = 0, deaths = 0}}}
    end
    brain.data = blank()
    pcall(function()
        if isfile(FILE) then
            local data = HttpService:JSONDecode(readfile(FILE))
            if type(data) == "table" and data.v == 1 then brain.data = data end
        end
    end)
    for _, key in ipairs({"moves", "styles", "trades", "players"}) do brain.data[key] = brain.data[key] or {} end
    brain.data.score = brain.data.score or blank().score

    local function rate(sc)
        if sc.n == 0 or sc.secs <= 0 then return nil end
        return (sc.dealt - sc.taken + sc.kills * 60 - sc.deaths * 80) / sc.secs
    end
    brain.Rate = rate

    local function trusted()
        local sc = brain.data.score
        local l, p = rate(sc.learned), rate(sc.plain)
        if not l or not p or sc.learned.n < 15 or sc.plain.n < 6 then return true end
        return l >= p - 0.5
    end
    brain.Trusted = trusted

    function brain.Save()
        dirty = false
        savedAt = os.clock()
        pcall(function()
            if not isfolder("BPHubABA") then makefolder("BPHubABA") end
            writefile(FILE, HttpService:JSONEncode(brain.data))
        end)
    end
    function brain.Reset()
        brain.data = blank()
        brain.Save()
    end
    local function touch()
        dirty = true
        if os.clock() - savedAt > 20 then brain.Save() end
    end
    onCleanup(function() if dirty then brain.Save() end end)

    local function myChar() return Game.characterName(player) end
    local function charOf(model)
        local owner = Players:GetPlayerFromCharacter(model)
        if owner then return Game.characterName(owner) end
        return "dummy"
    end
    local function entry(tbl, key, make)
        local e = tbl[key]
        if not e then e = make() tbl[key] = e end
        return e
    end

    local function ucb(mean, n, total, c)
        if n <= 0 then return math.huge end
        return mean + (c or 1) * math.sqrt(math.log(math.max(total, 1) + 1) / n)
    end

    local casts = {}
    function brain.MoveStats(name)
        local mine = brain.data.moves[myChar()]
        return mine and mine[name]
    end

    local plainFight = false
    local function learning() return brain.enabled and not plainFight and trusted() end
    function brain.PickMove(candidates, dist)
        if not learning() or #candidates == 0 then return candidates[1] and candidates[1].index end
        local mine = brain.data.moves[myChar()] or {}
        local total = 0
        for _, c in ipairs(candidates) do total = total + ((mine[c.name] and mine[c.name].n) or 0) end
        local best, bestScore
        for _, c in ipairs(candidates) do
            local m = mine[c.name]
            local ok = true
            if m and m.hit >= 3 then
                local range = m.range / m.hit
                if dist > range + 4 then ok = false end
            end
            if ok then
                local mean = m and m.n > 0 and (m.dmg / m.n) / 20 or 0
                local score = ucb(mean, m and m.n or 0, total, 0.6)
                if not bestScore or score > bestScore then best, bestScore = c, score end
            end
        end
        return best and best.index
    end
    function brain.Cast(name, model, dist)
        if not brain.enabled or not name then return end
        local cast = {name = name, char = myChar(), at = os.clock(), model = model, dist = dist, dealt = 0}
        casts[#casts + 1] = cast
        task.delay(1.6, function()
            local mine = entry(brain.data.moves, cast.char, function() return {} end)
            local m = entry(mine, cast.name, function() return {n = 0, hit = 0, dmg = 0, range = 0} end)
            m.n = m.n + 1
            if cast.dealt > 0 then
                m.hit = m.hit + 1
                m.dmg = m.dmg + cast.dealt
                m.range = m.range + cast.dist
            end
            for i, c in ipairs(casts) do if c == cast then table.remove(casts, i) break end end
            touch()
        end)
    end

    local STYLES = {"rush", "combo", "counter"}
    local fight = nil
    local watched = setmetatable({}, {__mode = "k"})

    local function styleKey(enemy) return enemy end
    function brain.ChooseStyle(enemy)
        if not learning() then return "rush" end
        local row = entry(brain.data.styles, styleKey(enemy), function() return {} end)

        local rush = row.rush
        local rushMean = rush and rush.n > 0 and rush.sum / rush.n or 0
        if math.random() < 0.125 then
            local least, leastN
            for _, st in ipairs(STYLES) do
                local n = row[st] and row[st].n or 0
                if not leastN or n < leastN then least, leastN = st, n end
            end
            return least
        end
        local best, bestMean = "rush", rushMean
        for _, st in ipairs(STYLES) do
            local r = row[st]
            if st ~= "rush" and r and r.n >= 4 and r.sum / r.n > bestMean + 0.15 then best, bestMean = st, r.sum / r.n end
        end
        do return best end
        local total = 0
        for _, st in ipairs(STYLES) do total = total + ((row[st] and row[st].n) or 0) end
        local best, bestScore
        for _, st in ipairs(STYLES) do
            local r = row[st]

            local score = ucb(r and r.n > 0 and r.sum / r.n or 0, r and r.n or 0, total, 0.5)
            if st == "rush" and (not r or r.n == 0) then score = score + 1 end
            if not bestScore or score > bestScore then best, bestScore = st, score end
        end
        return best or "rush"
    end

    local function closeFight(reason)
        local f = fight
        fight = nil
        if not f then return end
        local seconds = math.max(os.clock() - f.started, 1)

        if f.dealt + f.taken < 5 and reason ~= "died" then return end
        local sc = brain.data.score[f.plain and "plain" or "learned"]
        sc.n, sc.dealt, sc.taken, sc.secs = sc.n + 1, sc.dealt + f.dealt, sc.taken + f.taken, sc.secs + seconds
        if reason == "kill" then sc.kills = sc.kills + 1 end
        if reason == "died" then sc.deaths = sc.deaths + 1 end
        local reward = (f.dealt - f.taken) / math.max(seconds, 4) / 6
        if reason == "kill" then reward = reward + 1 end
        if reason == "died" then reward = reward - 1 end
        reward = math.clamp(reward, -2, 2)
        local row = entry(brain.data.styles, styleKey(f.enemy), function() return {} end)
        local r = entry(row, f.style, function() return {n = 0, sum = 0} end)
        r.n, r.sum = r.n + 1, r.sum + reward
        brain.data.fights = (brain.data.fights or 0) + 1
        if f.player then
            local id = tostring(f.player.UserId)
            local pr = entry(brain.data.players, id, function() return {name = f.player.Name, fights = 0, kills = 0, deaths = 0, dealt = 0, taken = 0} end)
            pr.name = f.player.Name
            pr.fights, pr.dealt, pr.taken = pr.fights + 1, pr.dealt + f.dealt, pr.taken + f.taken
            if reason == "kill" then pr.kills = pr.kills + 1 end
            if reason == "died" then pr.deaths = pr.deaths + 1 end
        end
        brain.last = ("%s vs %s: %s (%+.2f)"):format(f.style, f.enemy, reason, reward)
        touch()
    end

    local function watchModel(model, humanoid)
        if watched[model] then return end
        watched[model] = true
        local last = humanoid.Health
        connect(humanoid.HealthChanged, function(hp)
            local lost = last - hp
            last = hp
            if lost <= 0 then return end
            if fight and fight.model == model then
                fight.dealt = fight.dealt + lost
                fight.lastHit = os.clock()
                if hp <= 0 then closeFight("kill") end
            end
            for _, c in ipairs(casts) do
                if c.model == model and os.clock() - c.at < 1.5 then c.dealt = c.dealt + lost end
            end
        end)
    end

    local mine = nil
    local function watchMine()
        local _, humanoid = Game.ownRoot()
        if not humanoid or humanoid == mine then return end
        mine = humanoid
        local last = humanoid.Health
        connect(humanoid.HealthChanged, function(hp)
            local lost = last - hp
            last = hp
            if lost > 0 and fight then fight.taken = fight.taken + lost end
            if hp <= 0 and fight then closeFight("died") end
        end)
    end

    function brain.Fight(target)
        if not brain.enabled then return "rush" end
        watchMine()
        if fight and fight.model ~= target.model then

            closeFight("switched")
        end
        if not fight then
            watchModel(target.model, target.humanoid)

            plainFight = math.random() < 0.2
            local enemy = charOf(target.model)
            fight = {model = target.model, player = target.player, enemy = enemy, style = brain.ChooseStyle(enemy), plain = plainFight,
                started = os.clock(), dealt = 0, taken = 0, lastHit = os.clock()}
        end
        return fight.style
    end
    function brain.EndFight() if fight then closeFight("left") end end
    function brain.CurrentStyle() return fight and (fight.style .. (fight.plain and " (control)" or "")) or "-" end

    function brain.Comparison()
        local sc = brain.data.score
        local l, p = rate(sc.learned), rate(sc.plain)
        if not l or not p then return ("comparing: %d learned / %d control fights so far"):format(sc.learned.n, sc.plain.n) end
        local base = math.max(math.abs(p), 1)
        local pct = (l - p) / base * 100
        local sure = (sc.learned.n >= 15 and sc.plain.n >= 6) and "" or " (early)"
        return ("learned %+d%% vs control%s, %d/%d fights%s"):format(math.floor(pct + 0.5), sure,
            sc.learned.n, sc.plain.n, trusted() and "" or " - behind, playing plain")
    end

    function brain.TradeChoice(enemy)
        if not learning() then return "block" end
        local row = entry(brain.data.trades, enemy, function() return {} end)

        local b, w = row.block, row.swing
        if math.random() < 0.15 then return (not w or (b and w.n < b.n)) and "swing" or "block" end
        if w and w.n >= 4 and (not b or w.sum / w.n > (b.n > 0 and b.sum / b.n or 0) + 0.2) then return "swing" end
        do return "block" end
        local total = (row.block and row.block.n or 0) + (row.swing and row.swing.n or 0)
        local best, bestScore
        for _, choice in ipairs({"block", "swing"}) do
            local r = row[choice]
            local score = ucb(r and r.n > 0 and r.sum / r.n or 0, r and r.n or 0, total, 0.5)
            if not bestScore or score > bestScore then best, bestScore = choice, score end
        end
        return best
    end
    function brain.TradeResult(enemy, choice, reward)
        if not brain.enabled then return end
        local row = entry(brain.data.trades, enemy, function() return {} end)
        local r = entry(row, choice, function() return {n = 0, sum = 0} end)
        r.n, r.sum = r.n + 1, r.sum + math.clamp(reward, -3, 3)
        touch()
    end
    brain.CharOf = charOf

    function brain.PlayerCost(targetPlayer)
        if not learning() or not targetPlayer then return 0 end
        local pr = brain.data.players[tostring(targetPlayer.UserId)]
        if not pr or pr.fights < 2 then return 0 end
        local edge = (pr.dealt - pr.taken) / math.max(pr.fights, 1) / 30 + (pr.kills - pr.deaths) * 0.5
        return math.clamp(-edge * 10, -15, 30)
    end

    function brain.Summary()
        local d = brain.data
        local lines = {brain.Comparison()}
        local mineMoves = d.moves[myChar()]
        if mineMoves then
            local best, bestRate
            for name, m in pairs(mineMoves) do
                if m.n >= 3 then
                    local rate = m.hit / m.n
                    if not bestRate or rate > bestRate then best, bestRate = name, rate end
                end
            end
            if best then lines[#lines + 1] = ("best move as %s: %s (lands %d%%)"):format(myChar(), best, math.floor(bestRate * 100)) end
        end
        local nemesis, worst
        for _, pr in pairs(d.players) do
            if pr.fights >= 2 then
                local edge = pr.kills - pr.deaths
                if not worst or edge < worst then nemesis, worst = pr.name, edge end
            end
        end
        if nemesis and worst < 0 then lines[#lines + 1] = "toughest: " .. nemesis end
        return table.concat(lines, "  ·  ")
    end
end

local bot = {enabled = false, sprint = true, dash = true, useMoves = true, reach = 10, last = "off", target = "none",
    dashes = 0, jumps = 0, targets = "Players", teamMode = "enemies", skipAfk = true, stick = true,
    lockCamera = true, aimMouse = false, targetPlayer = nil, awaken = true, smart = true, targetMode = "nearest", skipUlt = true,
    trade = true, jumpOver = true, trades = 0, escapes = 0, learn = true}
state.Bot = bot
do
    local PathfindingService = game:GetService("PathfindingService")
    local CollectionService = game:GetService("CollectionService")
    local RENDER = "CatnAutoFarm" .. RUN_ID
    local CAMERA = "CatnAutoFarmCamera" .. RUN_ID
    local lockRoot = nil
    local moveDir = Vector3.zero
    local hazards, hazardsReady = {}, false
    local blocked = setmetatable({}, {__mode = "k"})
    local running = false
    local sprinting = false

    local damagedAt = setmetatable({}, {__mode = "k"})

    local aboveSince = setmetatable({}, {__mode = "k"})
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
        local distance = (dummy.root.Position - from).Magnitude + (bot.learn and brain.PlayerCost(dummy.player) or 0)
        if bot.targetMode == "nearest" then

            local hp = dummy.humanoid.Health / math.max(dummy.humanoid.MaxHealth, 1)
            return distance - (hp < 0.35 and 12 or 0)
        end
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

            tapAction("MobileJump", 0.12)
            if double then
                local t = os.clock()
                while os.clock() - t < 0.6 do
                    task.wait()
                    local r = Game.ownRoot()
                    if not r then break end
                    if os.clock() - t > 0.22 and r.AssemblyLinearVelocity.Y < 10 then break end
                end
                tapAction("MobileJump", 0.12)
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

    local function moveNameAt(index)
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        local button = playerGui and playerGui:FindFirstChild("HUD") and playerGui.HUD:FindFirstChild("Moves")
            and playerGui.HUD.Moves:FindFirstChild(tostring(index))
        return button and button:GetAttribute("MoveName") or ("Move" .. index)
    end

    local function readyMove(blocking, dist)
        local candidates = {}
        for index = 1, 4 do
            if Game.ownMoveReady(index) and (not blocking or guardBreaker(index)) then
                candidates[#candidates + 1] = {index = index, name = moveNameAt(index)}
            end
        end
        return brain.PickMove(candidates, dist or 0)
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
                trade.landedCount = (trade.landedCount or 0) + 1
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
        if autoBlock.Wants and autoBlock.Wants() then
            trade.wasBlocking = true
            return true
        end

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
        local enemy = brain.CharOf(dummy.model)
        local choice = (since < 0.2 and trade.swingHit ~= 5) and (trade.choiceFor == trade.swingAt and trade.choice or nil)
        if since < 0.2 and trade.swingHit ~= 5 and not choice then
            choice = brain.TradeChoice(enemy)
            trade.choice, trade.choiceFor = choice, trade.swingAt

            local landed0, taken0 = trade.landedCount or 0, #trade.hitsOnMe
            local swingAt = trade.swingAt
            task.delay(1, function()
                local taken = 0
                for _, t in ipairs(trade.hitsOnMe) do if t > swingAt then taken = taken + 1 end end
                brain.TradeResult(enemy, choice, ((trade.landedCount or 0) - landed0) - taken)
            end)
        end
        if since < 0.2 and trade.swingHit ~= 5 and choice == "block" and dist <= M1_REACH + 2
            and facingMe(dummy, rootPart) and blockAction
            and not autoBlock.GuardOn() then
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
        local style = brain.Fight(dummy)

        local comboReady = os.clock() - trade.landedAt < 0.8 or dist > M1_REACH
        if bot.useMoves and dist <= bot.reach and os.clock() - lastMove > 1 and (style ~= "combo" or comboReady) then
            local index = readyMove(blocking, dist)
            if index then
                lastMove = os.clock()
                brain.Cast(moveNameAt(index), dummy.model, dist)
                task.spawn(tapAction, "Move" .. index)
                return
            end
        end

        if style == "counter" and os.clock() - trade.landedAt > 0.6 and os.clock() - trade.swingAt > 0.6 then
            trade.idleSince = trade.idleSince or os.clock()
            if os.clock() - trade.idleSince < 1.5 then return end
        else
            trade.idleSince = nil
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

    local bind
    local function loop()
        local stillSince = nil
        local path, index, pathTarget, pathAt, pathFrom = nil, 1, nil, 0, nil
        local clear, clearAt = false, 0
        local lastNearestCheck = 0
        local stuckFrom, stuckAt, jumps = nil, os.clock(), 0
        local fightTarget, fightStart = nil, 0
        local chaseTarget, chaseStart = nil, 0
        local failStreak = 0
        local jumpedAt = nil
        local skipAt = 0
        local lobbyPos, lobbyAt = nil, 0
        while bot.enabled and alive do
            bot.beat = os.clock()
            local rootPart, humanoid = Game.ownRoot()

            if humanoid and moveDir.Magnitude > 0 and humanoid.MoveDirection.Magnitude < 0.01 and humanoid.WalkSpeed > 0 then
                stillSince = stillSince or os.clock()
                if os.clock() - stillSince > 2 then
                    stillSince = nil
                    bot.rebinds = (bot.rebinds or 0) + 1
                    bind()
                end
            else
                stillSince = nil
            end
            if not rootPart then
                moveDir = Vector3.zero
                bot.last = "waiting to respawn"
                task.wait(0.5)
            elseif state.Spawner and (state.Spawner.InLobby() or (lobbyPos and os.clock() - lobbyAt < 5
                and (rootPart.Position - lobbyPos).Magnitude < 300)) then

                if state.Spawner.InLobby() then lobbyPos, lobbyAt = rootPart.Position, os.clock() end
                moveDir = Vector3.zero
                setSprint(false)
                pathTarget, path = nil, nil
                bot.target, bot.targetPlayer, lockRoot = "none", nil, nil
                bot.last = state.Spawner.enabled and "in the lobby, Auto spawn is putting you back in"
                    or "in the lobby (turn on Auto spawn to go back in by itself)"
                task.wait(0.2)
            elseif state.Obby and state.Obby.active then
                moveDir = Vector3.zero
                setSprint(false)
                bot.last = "a minigame is on, Play minigames is playing it"
                task.wait(0.3)
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
                            local current = math.max(cost(pathTarget, rootPart.Position), 0)
                            local other = math.max(cost(best, rootPart.Position), 0)

                            local hp = pathTarget.humanoid.Health / math.max(pathTarget.humanoid.MaxHealth, 1)
                            local engaged = os.clock() - (damagedAt[pathTarget.model] or -math.huge) < 2.5 or hp < 0.35
                            local margin = engaged and math.max(10, current * 0.5) or math.max(2, current * 0.15)
                            if current - other > margin then keep = false end
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
                    brain.EndFight()
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
                    local above = dummy.root.Position.Y - rootPart.Position.Y
                    if dist <= M1_REACH and not level and above > 0 then
                        aboveSince[dummy.model] = aboveSince[dummy.model] or os.clock()
                    else
                        aboveSince[dummy.model] = nil
                    end
                    if aboveSince[dummy.model] and os.clock() - aboveSince[dummy.model] > 3 then

                        aboveSince[dummy.model] = nil
                        blocked[dummy.model] = os.clock() + 5
                        pathTarget, path = nil, nil
                        moveDir = Vector3.zero
                        bot.last = dummy.model.Name .. " is out of reach above, switching"
                    elseif dist <= M1_REACH and not level and above > 0 and above < 17 then

                        path = nil
                        chaseStart = os.clock()
                        local _, grounded = feetY(rootPart)
                        if grounded then jump(above > SINGLE_JUMP + 1) end
                        local to = (dummy.root.Position - rootPart.Position) * Vector3.new(1, 0, 1)
                        moveDir = to.Magnitude > 1.5 and to.Unit or Vector3.zero
                        bot.last = ("jumping at %s (%d studs up)"):format(dummy.model.Name, above)
                        if rootPart.Position.Y + 4 > dummy.root.Position.Y - 4 then attack(dummy, rootPart, dist) end
                    elseif dist <= M1_REACH and level then

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

    bind = function()
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
            while bot.enabled and alive do
                local ok, reason = pcall(loop)
                if ok then break end

                bot.crashes = (bot.crashes or 0) + 1
                bot.crash = tostring(reason)
                bot.crashAt = os.clock()
                bot.last = "hit an error, restarting: " .. tostring(reason)
                moveDir = Vector3.zero
                task.wait(2)
            end
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

local STYLE = {
    card = Color3.fromRGB(14, 15, 19), line = Color3.fromRGB(255, 255, 255),
    text = Color3.fromRGB(236, 237, 240), sub = Color3.fromRGB(150, 153, 163), faint = Color3.fromRGB(98, 101, 112),
    good = Color3.fromRGB(80, 214, 140), warn = Color3.fromRGB(245, 176, 65), bad = Color3.fromRGB(240, 84, 84),
    mode = Color3.fromRGB(156, 120, 255), gold = Color3.fromRGB(255, 206, 84), block = Color3.fromRGB(90, 170, 255),
}
local FONT_FAMILY = "rbxasset://fonts/families/BuilderSans.json"
local function font(weight) return Font.new(FONT_FAMILY, weight or Enum.FontWeight.Medium) end
local function hpTone(fraction)
    if fraction > 0.6 then return STYLE.good:Lerp(STYLE.warn, (1 - fraction) / 0.4 * 0.35) end
    if fraction > 0.3 then return STYLE.warn end
    return STYLE.bad
end
local barTweens = setmetatable({}, {__mode = "k"})
local TweenService = game:GetService("TweenService")
local SLIDE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function slide(fill, fraction)
    fraction = math.clamp(fraction, 0, 1)
    if barTweens[fill] and math.abs(barTweens[fill] - fraction) < 0.004 then return end
    barTweens[fill] = fraction
    TweenService:Create(fill, SLIDE, {Size = UDim2.fromScale(fraction, 1)}):Play()
end
local function label(parent, props)
    props.BackgroundTransparency = 1
    props.FontFace = props.FontFace or font()
    props.TextColor3 = props.TextColor3 or STYLE.text
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    return make("TextLabel", props, parent)
end

local function track(parent, size, props)
    local back = make("Frame", {BackgroundColor3 = STYLE.line, BackgroundTransparency = 0.88, BorderSizePixel = 0, Size = size}, parent)
    for key, value in pairs(props or {}) do back[key] = value end
    make("UICorner", {CornerRadius = UDim.new(1, 0)}, back)
    local fill = make("Frame", {BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundColor3 = STYLE.good}, back)
    make("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)
    return back, fill
end

local function chip(parent, order)
    local frame = make("Frame", {AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 15), BackgroundTransparency = 0.8,
        BorderSizePixel = 0, LayoutOrder = order or 0, Visible = false}, parent)
    make("UICorner", {CornerRadius = UDim.new(0, 4)}, frame)
    make("UIPadding", {PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)}, frame)
    local text = label(frame, {AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 10,
        FontFace = font(Enum.FontWeight.Bold), TextXAlignment = Enum.TextXAlignment.Center})
    return function(on, words, color)
        frame.Visible = on == true
        if not on then return end
        text.Text = string.upper(words)
        text.TextColor3, frame.BackgroundColor3 = color, color
    end
end

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

    local PIPS = 5
    local function getEntry(targetPlayer)
        if entries[targetPlayer] then return entries[targetPlayer] end
        local highlight = make("Highlight", {DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false}, container)
        local billboard = make("BillboardGui", {AlwaysOnTop = true, Enabled = false, Size = UDim2.fromOffset(180, 78),
            StudsOffset = Vector3.new(0, 2.9, 0), SizeOffset = Vector2.new(0, 0.5), LightInfluence = 0,
            ResetOnSpawn = false}, container)
        local holder = make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, billboard)
        make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3),
            VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center}, holder)
        local entry = {highlight = highlight, billboard = billboard}

        local chips = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 1}, holder)
        make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, chips)
        entry.chipsRow = chips
        entry.modeChip, entry.blockChip, entry.skillChip = chip(chips, 1), chip(chips, 2), chip(chips, 3)

        local card = make("Frame", {AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), BackgroundColor3 = STYLE.card,
            BackgroundTransparency = 0.18, BorderSizePixel = 0, LayoutOrder = 2}, holder)
        make("UICorner", {CornerRadius = UDim.new(0, 5)}, card)
        entry.cardStroke = make("UIStroke", {Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, card)
        make("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 7)}, card)
        make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, card)
        entry.edge = make("Frame", {Size = UDim2.fromOffset(2, 10), BorderSizePixel = 0, LayoutOrder = 0}, card)
        make("UICorner", {CornerRadius = UDim.new(1, 0)}, entry.edge)
        entry.name = label(card, {AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), TextSize = 13,
            FontFace = font(Enum.FontWeight.SemiBold), LayoutOrder = 1})
        entry.distance = label(card, {AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), TextSize = 11,
            TextColor3 = STYLE.sub, LayoutOrder = 2})

        local bars = make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 9), LayoutOrder = 3}, holder)
        entry.healthBack, entry.healthFill = track(bars, UDim2.fromOffset(116, 3), {Position = UDim2.fromOffset(0, 1)})
        entry.healthText = label(bars, {Size = UDim2.fromOffset(30, 9), Position = UDim2.fromOffset(120, -1), TextSize = 10,
            FontFace = font(Enum.FontWeight.SemiBold)})
        entry.modeBack, entry.modeFill = track(bars, UDim2.fromOffset(116, 2), {Position = UDim2.fromOffset(0, 6)})
        entry.bars = bars

        local pips = make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 4), LayoutOrder = 4}, holder)
        make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, pips)
        entry.pipsRow = pips
        entry.pips = {}
        for index = 1, PIPS do
            local back, fill = track(pips, UDim2.fromOffset(20, 3), {LayoutOrder = index, Visible = false})
            entry.pips[index] = {back = back, fill = fill}
        end
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
        highlight.OutlineTransparency = esp.outline and 0.15 or 1
        highlight.FillTransparency = esp.fill and 0.82 or 1

        local showBillboard = esp.labels or esp.healthBar or esp.modeBar or esp.cooldowns
        entry.billboard.Adornee = character:FindFirstChild("Head") or root
        entry.billboard.Enabled = showBillboard
        if not showBillboard then return end

        local mode = Game.chargeFraction(targetPlayer)
        local blocking = Game.isBlocking(character)
        local skill = Game.usingSkill(character)
        entry.modeChip(esp.modeBar and mode >= 1, "Mode", STYLE.gold)
        entry.blockChip(blocking, "Block", STYLE.block)
        entry.skillChip(skill ~= nil, skill or "", STYLE.warn)
        entry.chipsRow.Visible = (esp.modeBar and mode >= 1) or blocking or skill ~= nil

        entry.name.Parent.Visible = esp.labels
        entry.name.Text = targetPlayer.DisplayName
        entry.edge.BackgroundColor3 = color
        entry.cardStroke.Color = color
        entry.distance.Visible = esp.distance
        entry.distance.Text = string.format("%dm", math.floor(distance + 0.5))

        local hp = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
        entry.bars.Visible = esp.healthBar or esp.modeBar
        entry.healthBack.Visible = esp.healthBar
        entry.healthText.Visible = esp.healthBar
        slide(entry.healthFill, hp)
        entry.healthFill.BackgroundColor3 = hpTone(hp)
        entry.healthText.Text = tostring(math.floor(humanoid.Health + 0.5))
        entry.healthText.TextColor3 = hpTone(hp)
        entry.modeBack.Visible = esp.modeBar
        slide(entry.modeFill, mode)
        entry.modeFill.BackgroundColor3 = mode >= 1 and STYLE.gold or STYLE.mode

        local moves = esp.cooldowns and Game.moves(targetPlayer) or {}
        entry.pipsRow.Visible = #moves > 0
        for index, pip in ipairs(entry.pips) do
            local move = moves[index]
            pip.back.Visible = move ~= nil
            if move then
                slide(pip.fill, move.progress)
                pip.fill.BackgroundColor3 = move.ready and STYLE.good or STYLE.sub
            end
        end
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
    local frame = make("Frame", {Size = UDim2.fromOffset(264, 0), Position = UDim2.new(0, 24, 0.5, -110),
        BackgroundColor3 = STYLE.card, BackgroundTransparency = 0, BorderSizePixel = 0,
        Visible = false, AutomaticSize = Enum.AutomaticSize.Y}, gui)
    make("UICorner", {CornerRadius = UDim.new(0, 10)}, frame)
    local frameStroke = make("UIStroke", {Color = STYLE.line, Transparency = 0.9, Thickness = 1}, frame)
    make("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, frame)
    make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)}, frame)

    local header = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 1}, frame)
    local avatar = make("ImageLabel", {Size = UDim2.fromOffset(38, 38), BackgroundColor3 = Color3.fromRGB(32, 34, 42),
        BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop}, header)
    make("UICorner", {CornerRadius = UDim.new(1, 0)}, avatar)
    local avatarRing = make("UIStroke", {Thickness = 2, Transparency = 0.2}, avatar)
    local title = label(header, {Position = UDim2.fromOffset(48, 1), Size = UDim2.new(1, -100, 0, 18), TextSize = 15,
        FontFace = font(Enum.FontWeight.Bold), TextTruncate = Enum.TextTruncate.AtEnd})
    local subtitle = label(header, {Position = UDim2.fromOffset(48, 20), Size = UDim2.new(1, -100, 0, 15), TextSize = 11,
        TextColor3 = STYLE.sub, TextTruncate = Enum.TextTruncate.AtEnd})
    local distanceText = label(header, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 1), Size = UDim2.fromOffset(52, 18),
        TextSize = 15, FontFace = font(Enum.FontWeight.SemiBold), TextXAlignment = Enum.TextXAlignment.Right})
    label(header, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 20), Size = UDim2.fromOffset(52, 15),
        TextSize = 10, TextColor3 = STYLE.faint, Text = "AWAY", FontFace = font(Enum.FontWeight.Bold), TextXAlignment = Enum.TextXAlignment.Right})

    local chipRow = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 2}, frame)
    make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, chipRow)
    local targetChip, modeChip, blockChip, skillChip = chip(chipRow, 1), chip(chipRow, 2), chip(chipRow, 3), chip(chipRow, 4)

    local function divider(order)
        make("Frame", {BackgroundColor3 = STYLE.line, BackgroundTransparency = 0.93, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 1), LayoutOrder = order}, frame)
    end
    divider(3)

    local function stat(order, caption, barHeight)
        local box = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 15 + barHeight + 4), LayoutOrder = order}, frame)
        label(box, {Size = UDim2.new(0.5, 0, 0, 14), TextSize = 10, TextColor3 = STYLE.faint, Text = caption,
            FontFace = font(Enum.FontWeight.Bold)})
        local value = label(box, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, 0, 0, 14),
            TextSize = 12, FontFace = font(Enum.FontWeight.SemiBold), TextXAlignment = Enum.TextXAlignment.Right})
        local _, fill = track(box, UDim2.new(1, 0, 0, barHeight), {Position = UDim2.fromOffset(0, 18)})
        return value, fill
    end
    local healthValue, healthFill = stat(4, "HEALTH", 6)
    local modeValue, modeFill = stat(5, "MODE", 4)
    divider(6)

    label(frame, {Size = UDim2.new(1, 0, 0, 12), TextSize = 10, TextColor3 = STYLE.faint, Text = "MOVES",
        FontFace = font(Enum.FontWeight.Bold), LayoutOrder = 7})
    local moveRows = {}
    for index = 1, 5 do
        local row = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 7 + index, Visible = false}, frame)
        local badge = make("Frame", {Size = UDim2.fromOffset(18, 18), BackgroundColor3 = STYLE.line, BackgroundTransparency = 0.92, BorderSizePixel = 0}, row)
        make("UICorner", {CornerRadius = UDim.new(0, 4)}, badge)
        local number = label(badge, {Size = UDim2.fromScale(1, 1), TextSize = 10, Text = tostring(index), TextColor3 = STYLE.sub,
            FontFace = font(Enum.FontWeight.Bold), TextXAlignment = Enum.TextXAlignment.Center})
        local name = label(row, {Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -96, 1, 0), TextSize = 12,
            TextTruncate = Enum.TextTruncate.AtEnd})
        local ready = label(row, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(60, 18),
            TextSize = 10, Text = "READY", TextColor3 = STYLE.good, FontFace = font(Enum.FontWeight.Bold), TextXAlignment = Enum.TextXAlignment.Right})
        local back, fill = track(row, UDim2.fromOffset(60, 4), {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5)})
        moveRows[index] = {row = row, name = name, ready = ready, back = back, fill = fill, number = number}
    end

    local headshots = {}
    local function headshot(userId)
        if headshots[userId] ~= nil then return headshots[userId] end
        headshots[userId] = ""
        task.spawn(function()
            local ok, image = pcall(function()
                return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and image then headshots[userId] = image end
        end)
        return ""
    end

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
            local teamColor = subject.Team and not Game.onAfkTeam(subject) and subject.TeamColor.Color or STYLE.mode
            avatar.Image = headshot(subject.UserId)
            avatarRing.Color = teamColor
            title.Text = subject.DisplayName
            subtitle.Text = "@" .. subject.Name .. "  ·  " .. tostring(Game.characterName(subject))
            distanceText.Text = string.format("%dm", math.floor(distance + 0.5))
            distanceText.TextColor3 = distance <= 10 and STYLE.warn or STYLE.text

            local mode = Game.chargeFraction(subject)
            local skill = Game.usingSkill(subject.Character)
            local blocking = Game.isBlocking(subject.Character)
            local farming = bot.enabled and bot.targetPlayer == subject
            targetChip(farming, "Farm target", STYLE.bad)
            modeChip(mode >= 1, "Mode ready", STYLE.gold)
            blockChip(blocking, "Blocking", STYLE.block)
            skillChip(skill ~= nil, skill or "", STYLE.warn)
            chipRow.Visible = farming or mode >= 1 or blocking or skill ~= nil

            local hp = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
            slide(healthFill, hp)
            healthFill.BackgroundColor3 = hpTone(hp)
            healthValue.Text = string.format("%d / %d", math.floor(humanoid.Health + 0.5), math.floor(humanoid.MaxHealth + 0.5))
            healthValue.TextColor3 = hpTone(hp)
            slide(modeFill, mode)
            modeFill.BackgroundColor3 = mode >= 1 and STYLE.gold or STYLE.mode
            modeValue.Text = mode >= 1 and "READY" or string.format("%d%%", math.floor(mode * 100))
            modeValue.TextColor3 = mode >= 1 and STYLE.gold or STYLE.text

            local moves = Game.moves(subject)
            for index, row in ipairs(moveRows) do
                local move = moves[index]
                row.row.Visible = move ~= nil
                if move then
                    row.name.Text = move.name
                    row.name.TextColor3 = move.ready and STYLE.text or STYLE.sub
                    row.ready.Visible = move.ready
                    row.back.Visible = not move.ready
                    slide(row.fill, move.progress)
                    row.fill.BackgroundColor3 = STYLE.warn
                    row.number.TextColor3 = move.ready and STYLE.good or STYLE.faint
                end
            end
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
            if value > last then
                session[key] = session[key] + (value - last)
                session[key .. "At"] = os.clock()
            end
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

local spawner = {enabled = false, character = "", noAfk = false, quests = false, last = "off", failed = {}}
state.Spawner = spawner
do

    local LAST_FILE = "BPHubABA/last_character_" .. tostring(player.UserId) .. ".txt"
    pcall(function()
        if isfile(LAST_FILE) then spawner.lastSpawned = readfile(LAST_FILE)
        elseif isfile("BPHubABA/last_character.txt") then spawner.lastSpawned = readfile("BPHubABA/last_character.txt") end
    end)
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
                    and not button:GetAttribute("TestPlaceOnly") and button.ImageColor3.R > 0.5
                    and os.clock() > (spawner.failed[button.Name] or 0) then
                    seen[button.Name] = true
                    names[#names + 1] = button.Name
                end
            end
        end
        table.sort(names)
        return names
    end

    function spawner.QuestCharacter()
        local stats = player:FindFirstChild("ReplicatedStats")
        local value = stats and stats:FindFirstChild("DailyQuest")
        if not value then return nil end
        local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(value.Value) end)
        if not ok or type(data) ~= "table" then return nil end
        local quest = data.Focus and data[data.Focus]
        if type(quest) ~= "table" or quest.Finished or type(quest.Requirements) ~= "table" then return nil end
        local wanted = quest.Requirements.Character
        if type(wanted) ~= "string" or wanted == "" then return nil end
        return wanted, quest.Description
    end

    local function pick()
        local wanted = spawner.character:lower():gsub("^%s+", ""):gsub("%s+$", "")
        local names = spawner.Characters()

        if #names == 0 and next(spawner.failed) then
            table.clear(spawner.failed)
            names = spawner.Characters()
        end
        if spawner.quests then
            local questChar = spawner.QuestCharacter()
            if questChar then
                local q = questChar:lower()
                for _, name in ipairs(names) do if name:lower() == q then return name end end
                for _, name in ipairs(names) do if name:lower():sub(1, #q) == q then return name end end
            end
        end
        local function fallback()

            local last = player:GetAttribute("LastLoadedChar")
            if #names == 0 then return last ~= "" and last or nil end
            for _, name in ipairs(names) do if name == last then return name end end
            for _, name in ipairs(names) do if name == spawner.lastSpawned then return name end end
            return names[1]
        end
        if wanted == "" then return fallback() end
        for _, name in ipairs(names) do if name:lower() == wanted then return name end end
        for _, name in ipairs(names) do if name:lower():sub(1, #wanted) == wanted then return name end end

        return fallback()
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
                    elseif os.clock() - lobbySince > 1 and os.clock() - pressedAt > 4 then

                        pressedAt = os.clock()

                        local roundOn = workspace:GetAttribute("GameMode") ~= nil
                        if not roundOn then
                            spawner.tries = nil
                        elseif spawner.tries and spawner.tries.name == name then
                            spawner.tries.count = spawner.tries.count + 1
                        else
                            spawner.tries = {name = name, count = 1}
                        end
                        if spawner.tries and spawner.tries.count > 3 then
                            spawner.failed[name] = os.clock() + 600
                            spawner.tries = nil
                            name = pick() or name
                        end
                        spawner.last = (roundOn and "spawning as " or "waiting for the round to start, then ") .. name
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
                    spawner.tries = nil
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
            task.wait(0.5)
        end
    end)
end

local quests = {enabled = false, last = "off", done = 0, onFinished = nil}
state.Quests = quests
do
    local HttpService = game:GetService("HttpService")
    local remote = function() return game:GetService("ReplicatedStorage"):FindFirstChild("QuestStuff") end
    local SINGLE_LIFE_DAMAGE, MAX_COMBO = 300, 10

    function quests.Data()
        local stats = player:FindFirstChild("ReplicatedStats")
        local value = stats and stats:FindFirstChild("DailyQuest")
        if not value then return nil end
        local ok, data = pcall(function() return HttpService:JSONDecode(value.Value) end)
        return ok and type(data) == "table" and data or nil
    end

    function quests.Focused()
        local data = quests.Data()
        local quest = data and data.Focus and data[data.Focus]
        if type(quest) ~= "table" then return nil end
        local goal = tonumber(quest.Num) or 1
        local left = 0
        for key, value in pairs(quest.Requirements or {}) do
            if key ~= "Character" and tonumber(value) and tonumber(value) <= goal then left = goal - tonumber(value) end
        end
        return quest, ("%d/%d"):format(quest.Finished and goal or left, goal)
    end

    local function judge(text)
        local t = tostring(text or ""):lower()
        if t:find("ranked") or t:find("^%s*win") or t:find(" win ") then return nil, "ranked or wins" end
        local character = text:match(" as (.-)%s+in a single life") or text:match(" as (.-)%s*$")
            or text:match(" with (.-)%s*$") or text:match(" in (.-)'s mode")
        if character then character = character:gsub("^%s+", ""):gsub("%s+$", "") end
        local kills = t:match("get (%d+) kills")
        if kills then
            local effort = tonumber(kills) * (t:find("'s mode") and 3 or 1)
            return effort, nil, character
        end
        local damage = t:match("deal (%d+) damage")
        if damage then
            damage = tonumber(damage)
            if t:find("single life") and damage > SINGLE_LIFE_DAMAGE then return nil, "too much in one life" end
            return damage / 60 * (t:find("single life") and 2 or 1), nil, character
        end
        local combo = t:match("combo count of (%d+)")
        if combo then
            if tonumber(combo) > MAX_COMBO then return nil, "combo too long" end
            return 4, nil, character
        end
        return nil, "not something the farm does"
    end
    quests.Judge = judge

    local function characterExists(name)
        if not name then return true end
        local q = name:lower()
        for _, n in ipairs(spawner.Characters()) do
            if n:lower() == q or n:lower():sub(1, #q) == q then return true end
        end
        return false
    end

    local function board()
        local r = remote()
        local gui = player.PlayerGui:FindFirstChild("DailyQuestGui")
        local opened = false
        if not gui and r then
            r:FireServer("Open")
            opened = true
            gui = player.PlayerGui:WaitForChild("DailyQuestGui", 5)
        end
        if not gui then return nil end
        task.wait(0.4)
        local list = gui:FindFirstChild("List")
        local options = {}
        for _, slot in ipairs(list and list:GetChildren() or {}) do
            local desc = slot:FindFirstChild("Description")
            local finished = slot:FindFirstChild("Finished")
            local gold = slot:FindFirstChild("Gold")
            if slot:IsA("Frame") and desc and slot.Visible and not (finished and finished.Visible) then
                local effort, why, character = judge(desc.Text)
                local digits = (gold and gold.Text or ""):gsub("[^%d]", "")
                local money = tonumber(digits) or 0
                if effort and characterExists(character) then
                    options[#options + 1] = {slot = slot.Name, text = desc.Text, gold = money, score = money / math.max(effort, 1)}
                end
            end
        end
        table.sort(options, function(a, b) return a.score > b.score end)
        local best = options[1]
        if best and r then r:FireServer("Take", best.slot) end
        task.wait(0.3)
        if opened and r then r:FireServer("Close") end
        return best, #options
    end

    local checkedAt, lastFocus, lastFinished = -math.huge, nil, nil
    local tries = 0
    task.spawn(function()
        while alive do
            local quest, progress = quests.Focused()
            local key = quest and (tostring(quest.QuestId) .. tostring(quest.Description))

            if quest and quest.Finished and lastFocus == key and not lastFinished then
                quests.done = quests.done + 1
                if quests.onFinished then pcall(quests.onFinished, quest) end
            end
            lastFocus, lastFinished = key, quest and quest.Finished or false
            if not quests.enabled or not correctGame then
                quests.last = quests.enabled and "not in Anime Battle Arena" or "off"
            else
                local doable = quest and not quest.Finished and judge(quest.Description) ~= nil
                if doable then
                    tries = 0
                    quests.last = ("on: %s - %s"):format(quest.Description, progress)
                elseif os.clock() - checkedAt > 120 then
                    checkedAt = os.clock()
                    quests.last = "looking at the quest board"
                    local ok, best, count = pcall(board)
                    if not ok then
                        local r = game:GetService("ReplicatedStorage"):FindFirstChild("QuestStuff")
                        if r and player.PlayerGui:FindFirstChild("DailyQuestGui") then pcall(function() r:FireServer("Close") end) end
                    end
                    if ok and best then
                        quests.last = "took: " .. best.text

                        tries = tries + 1
                        if tries <= 2 then checkedAt = os.clock() - 110 end
                    elseif ok then
                        quests.last = "nothing on the board the farm can finish" .. ""
                    else
                        quests.last = "couldn't read the board"
                    end
                end
            end
            task.wait(5)
        end
    end)
end

local obby = {enabled = false, active = false, last = "off", runs = 0, finishes = 0, jumps = 0, waits = 0}
state.Obby = obby
do
    local HttpService = game:GetService("HttpService")
    local G, V1, V2, T2 = 90, 37.2, 40, 0.3
    local SPEED = 15
    local CELL = 2
    local RENDER = "CatnObby" .. RUN_ID
    local SAFE_TOUCH = {Won = true, Check = true, CoinSpawner = true, Coin = true, Spawn = true}
    local moveDir = Vector3.zero

    local function airTime(dy, double)
        if not double then
            local disc = V1 * V1 - 2 * G * dy
            if disc < 0 then return nil end
            return (V1 + math.sqrt(disc)) / G
        end
        local h1 = V1 * T2 - 0.5 * G * T2 * T2
        local disc = V2 * V2 - 2 * G * (dy - h1)
        if disc < 0 then return nil end
        return T2 + (V2 + math.sqrt(disc)) / G
    end

    local function inBox(part, point, grow, growUp)
        local rel = part.CFrame:PointToObjectSpace(point)
        local h = part.Size / 2
        return math.abs(rel.X) <= h.X + grow and math.abs(rel.Z) <= h.Z + grow and math.abs(rel.Y) <= h.Y + (growUp or grow)
    end

    local function saveMap(map)
        pcall(function()
            local parts = {}
            for _, d in ipairs(map:GetDescendants()) do
                if d:IsA("BasePart") then
                    local rx, ry, rz = d.CFrame:ToOrientation()
                    parts[#parts + 1] = {n = d.Name, p = {d.Position.X, d.Position.Y, d.Position.Z},
                        s = {d.Size.X, d.Size.Y, d.Size.Z}, r = {math.deg(rx), math.deg(ry), math.deg(rz)},
                        c = d.CanCollide, t = d:FindFirstChildOfClass("TouchTransmitter") ~= nil, tr = d.Transparency,
                        k = d.ClassName, sh = d:IsA("Part") and d.Shape.Name or nil, col = {math.floor(d.Color.R * 255), math.floor(d.Color.G * 255), math.floor(d.Color.B * 255)}}
                end
            end
            local message = game:GetService("ReplicatedStorage"):FindFirstChild("GameMessage")
            local label = (message and tostring(message.Value) or "minigame"):gsub("[^%w]+", "_"):sub(1, 30)
            if not isfolder("BPHubABA") then makefolder("BPHubABA") end
            if not isfolder("BPHubABA/minigames") then makefolder("BPHubABA/minigames") end
            writefile(("BPHubABA/minigames/%s_%d.json"):format(label, os.time()),
                HttpService:JSONEncode({message = message and message.Value, parts = parts}))
        end)
    end

    local function logResult(kind, map, started)
        pcall(function()
            local message = game:GetService("ReplicatedStorage"):FindFirstChild("GameMessage")
            local file = "BPHubABA/minigames/results.txt"
            local line = ("%s  %s  %s  %.0fs  jumps %d  resets %d  [%s]\n"):format(os.date("%m-%d %H:%M"), kind,
                obby.last, os.clock() - started, obby.jumps, obby.resets or 0, message and tostring(message.Value) or "?")
            if not isfolder("BPHubABA/minigames") then makefolder("BPHubABA/minigames") end
            if type(appendfile) == "function" and isfile(file) then appendfile(file, line)
            else writefile(file, (isfile(file) and readfile(file) or "") .. line) end
        end)
    end

    local grid, cells, goalCells, movers, statics, won = nil, nil, nil, nil, nil, nil
    local arcParams = RaycastParams.new()
    arcParams.FilterType = Enum.RaycastFilterType.Include
    arcParams.RespectCanCollide = true
    local linkCache = setmetatable({}, {__mode = "k"})
    local function key(ix, iz) return ix * 100000 + iz end

    local function build(map)
        won = nil
        local parts = {}
        for _, d in ipairs(map:GetDescendants()) do
            if d:IsA("BasePart") then
                parts[#parts + 1] = d
                if d.Name == "Won" then won = d end
            end
        end
        if not won then return false end

        local before = {}
        for _, part in ipairs(parts) do before[part] = part.CFrame end
        task.wait(0.12)
        movers, statics = {}, {}
        local solids = {}
        for _, part in ipairs(parts) do
            local moved = part.Name == "Spinner" or not part.Anchored
                or (before[part].Position - part.Position).Magnitude > 0.01
                or before[part].LookVector:Dot(part.CFrame.LookVector) < 0.99999
                or before[part].UpVector:Dot(part.CFrame.UpVector) < 0.99999
            local touch = part:FindFirstChildOfClass("TouchTransmitter") ~= nil
            if moved and (touch or part.CanCollide) then

                local axis, angle = before[part]:ToObjectSpace(part.CFrame):ToAxisAngle()
                movers[#movers + 1] = {part = part, last = part.CFrame, at = os.clock(), omega = Vector3.zero, vel = Vector3.zero,
                    spinAxis = angle > 0.001 and before[part]:VectorToWorldSpace(axis) or nil}
            elseif touch and not SAFE_TOUCH[part.Name] then
                statics[#statics + 1] = part
            elseif part.CanCollide and part.Name ~= "BLOCKER" then
                solids[#solids + 1] = part
            end
        end

        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Include
        overlap.FilterDescendantsInstances = {map}
        overlap.RespectCanCollide = true
        local moverSet = {}
        for _, m in ipairs(movers) do moverSet[m.part] = true end
        movers.set = moverSet
        arcParams.FilterDescendantsInstances = {map}
        table.clear(linkCache)
        local function roomAt(x, y, z, under)
            local hits = workspace:GetPartBoundsInBox(CFrame.new(x, y + 3.1, z), Vector3.new(2.6, 5, 2.6), overlap)
            for _, hit in ipairs(hits) do

                if hit.Name ~= "BLOCKER" and not moverSet[hit] and hit ~= under then return false end
            end
            return true
        end

        grid, cells, goalCells = {}, {}, {}
        local lo, hi
        for _, part in ipairs(solids) do
            local half = part.Size.Magnitude / 2
            if half < 300 then
                local p = part.Position
                lo = lo and Vector3.new(math.min(lo.X, p.X - half), math.min(lo.Y, p.Y - half), math.min(lo.Z, p.Z - half)) or p - Vector3.one * half
                hi = hi and Vector3.new(math.max(hi.X, p.X + half), math.max(hi.Y, p.Y + half), math.max(hi.Z, p.Z + half)) or p + Vector3.one * half
            end
        end
        if not lo then return false end
        local _, me = Game.ownRoot()
        local maxSlope = math.min(me and me.MaxSlopeAngle or 45, 75)
        local minNormalY = math.cos(math.rad(maxSlope))
        local down = RaycastParams.new()
        down.FilterType = Enum.RaycastFilterType.Include
        down.FilterDescendantsInstances = solids
        down.RespectCanCollide = true
        local x0, x1 = math.floor(lo.X / CELL), math.ceil(hi.X / CELL)
        local z0, z1 = math.floor(lo.Z / CELL), math.ceil(hi.Z / CELL)
        local count = 0
        for ix = x0, x1 do
            for iz = z0, z1 do
                local x, z = ix * CELL, iz * CELL
                local fromY = hi.Y + 5
                for _ = 1, 6 do
                    local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, lo.Y - fromY - 1, 0), down)
                    if not hit then break end
                    local y = hit.Position.Y
                    fromY = y - 0.05

                    if hit.Normal.Y > minNormalY then
                        local point = Vector3.new(x, y + 2, z)
                        local blocked = false
                        for _, h in ipairs(statics) do

                            if inBox(h, point, 2, 2.5) then blocked = true break end
                        end

                        if not blocked and not roomAt(x, y, z, hit.Instance) then blocked = true end
                        if not blocked then
                            local list = grid[key(ix, iz)] or {}
                            local cell = {ix = ix, iz = iz, x = x, z = z, y = y, i = #cells + 1,
                                part = hit.Instance, ramp = hit.Normal.Y < 0.98}
                            for _, other in ipairs(list) do
                                if math.abs(other.y - y) < 3 then cell = nil break end
                            end
                            if cell then
                                list[#list + 1] = cell
                                grid[key(ix, iz)] = list
                                cells[#cells + 1] = cell
                                if inBox(won, Vector3.new(x, y + 2.5, z), 0.5, 1) then
                                    cell.goal = true
                                    goalCells[#goalCells + 1] = cell
                                end
                            end
                        end
                    end
                end
                count = count + 1
                if count % 400 == 0 then task.wait() end
                if #cells > 40000 then break end
            end
        end

        for _, m in ipairs(movers) do
            if m.spinAxis then
                local part = m.part
                local center = part.Position
                local reach = math.max(part.Size.X, part.Size.Y, part.Size.Z) / 2 + 3
                local h = part.Size / 2
                for _, cell in ipairs(cells) do
                    if math.abs(cell.x - center.X) <= reach and math.abs(cell.z - center.Z) <= reach and math.abs(cell.y - center.Y) <= reach + 6 then
                        local hits = 0
                        for step = 0, 23 do
                            local cf = CFrame.fromAxisAngle(m.spinAxis, math.rad(step * 15)) * (part.CFrame - center) + center
                            for _, up in ipairs({1, 3, 5}) do
                                local rel = cf:PointToObjectSpace(Vector3.new(cell.x, cell.y + up, cell.z))
                                if math.abs(rel.X) <= h.X + 1.5 and math.abs(rel.Y) <= h.Y + 1.5 and math.abs(rel.Z) <= h.Z + 1.5 then
                                    hits = hits + 1
                                    break
                                end
                            end
                        end
                        cell.danger = math.max(cell.danger or 0, hits / 24)
                    end
                end
                task.wait()
            end
        end
        return #cells > 0 and #goalCells > 0
    end

    local function cellsAt(ix, iz) return grid[key(ix, iz)] end

    local function cellNear(position)
        local best, bestD
        local ix, iz = math.floor(position.X / CELL + 0.5), math.floor(position.Z / CELL + 0.5)
        for dx = -2, 2 do
            for dz = -2, 2 do
                for _, c in ipairs(cellsAt(ix + dx, iz + dz) or {}) do
                    local feet = position.Y - 3
                    if c.y <= feet + 2 and c.y >= feet - 8 then
                        local d = math.abs(c.x - position.X) + math.abs(c.z - position.Z) + math.abs(c.y - feet) * 0.5
                        if not bestD or d < bestD then best, bestD = c, d end
                    end
                end
            end
        end
        return best
    end

    local function solidHit(from, to)
        local result = workspace:Raycast(from, to - from, arcParams)
        return result ~= nil and result.Instance.Name ~= "BLOCKER" and not (movers and movers.set and movers.set[result.Instance])
    end
    local function arcClear(cell, n, double)
        local a, b = Vector3.new(cell.x, cell.y, cell.z), Vector3.new(n.x, n.y, n.z)
        local flatGap = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
        local dist = flatGap.Magnitude
        local dir = dist > 0.01 and flatGap.Unit or Vector3.zero
        local h1 = V1 * T2 - 0.5 * G * T2 * T2
        local function height(t)
            if not double or t <= T2 then return V1 * t - 0.5 * G * t * t end
            local u = t - T2
            return h1 + V2 * u - 0.5 * G * u * u
        end
        local prev = a
        local t = 0
        while t < 2 do
            t = t + 0.06
            local y = height(t)
            local p = a + dir * math.min(SPEED * t, dist) + Vector3.new(0, y, 0)

            local falling = (double and t > T2 + V2 / G) or (not double and t > V1 / G)
            if falling and p.Y <= b.Y then p = Vector3.new(p.X, b.Y, p.Z) end
            for _, up in ipairs({0.7, 4.6}) do
                if solidHit(prev + Vector3.new(0, up, 0), p + Vector3.new(0, up, 0)) then return false end
            end
            prev = p
            if falling and p.Y <= b.Y then break end
        end
        return true
    end

    local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
    local function links(cell)
        if linkCache[cell] then return linkCache[cell] end
        local out = {}
        linkCache[cell] = out
        for _, d in ipairs(DIRS) do
            local diag = d[1] ~= 0 and d[2] ~= 0
            for _, n in ipairs(cellsAt(cell.ix + d[1], cell.iz + d[2]) or {}) do

                if math.abs(n.y - cell.y) < 1.6 or (cell.ramp and n.part == cell.part and math.abs(n.y - cell.y) < 5) then
                    out[#out + 1] = {to = n, kind = "walk", cost = (diag and CELL * 1.42 or CELL) + (n.danger or 0) * 30}
                end
            end

            local gap = false
            for k = 2, 12 do
                local list = cellsAt(cell.ix + d[1] * k, cell.iz + d[2] * k)
                local landed = false
                if not list or #list == 0 then
                    gap = true
                else
                    for _, n in ipairs(list) do
                        local dy = n.y - cell.y
                        local dist = k * CELL * (diag and 1.42 or 1)
                        local needsJump = gap or dy > 1.6
                        if needsJump and dy < 15 then
                            local t1, t2 = airTime(dy + 0.8, false), airTime(dy + 0.8, true)
                            local kind
                            if t1 and SPEED * t1 >= dist + 1 then kind = "jump"
                            elseif t2 and SPEED * t2 >= dist + 1 then kind = "double" end

                            if kind == "jump" and not arcClear(cell, n, false) then
                                kind = (t2 and SPEED * t2 >= dist + 1) and "double" or nil
                            end
                            if kind == "double" and not arcClear(cell, n, true) then kind = nil end

                            if kind == "jump" and arcClear(cell, n, true) then kind = "double" end
                            if kind then
                                out[#out + 1] = {to = n, kind = kind, cost = dist + 3 + (n.danger or 0) * 30}

                                if dy > -1.6 then landed = true end
                            end
                        elseif not needsJump and math.abs(dy) < 1.6 then
                            landed = true
                        end
                    end

                    if not landed then
                        local level = false
                        for _, n in ipairs(list) do if math.abs(n.y - cell.y) < 1.6 then level = true break end end
                        if not level then gap = true end
                    end
                end
                if landed then break end
            end
        end
        return out
    end

    local function closestReachable(start)
        local seen, queue, qi = {[start] = true}, {start}, 1
        local target = won.Position
        local best, bestD = start, math.huge
        while qi <= #queue and qi < 25000 do
            local c = queue[qi]
            qi = qi + 1
            local d = math.sqrt((c.x - target.X) ^ 2 + (c.z - target.Z) ^ 2) + math.abs(c.y + 3 - (target.Y - won.Size.Y / 2)) * 2
            if d < bestD then best, bestD = c, d end
            for _, link in ipairs(links(c)) do
                if not seen[link.to] then
                    seen[link.to] = true
                    queue[#queue + 1] = link.to
                end
            end
            if qi % 400 == 0 then task.wait() end
        end
        return best
    end

    local function plan(start)
        local goal = goalCells[1]
        local function h(c)
            local best = math.huge
            for i = 1, math.min(#goalCells, 30) do
                local g = goalCells[i]
                local d = math.sqrt((g.x - c.x) ^ 2 + (g.z - c.z) ^ 2)
                if d < best then best = d end
            end
            return best
        end
        local open, gScore, came, cameLink, closed = {start}, {[start] = 0}, {}, {}, {}
        local fScore = {[start] = h(start)}
        local expanded = 0
        while #open > 0 do
            local bi, best = 1, open[1]
            for i = 2, #open do if fScore[open[i]] < fScore[best] then bi, best = i, open[i] end end
            table.remove(open, bi)
            if best.goal then
                local path = {}
                local cur = best
                while came[cur] do table.insert(path, 1, cameLink[cur]) cur = came[cur] end
                return path
            end
            closed[best] = true
            expanded = expanded + 1
            if expanded % 300 == 0 then task.wait() end
            if expanded > 20000 then return nil end
            for _, link in ipairs(links(best)) do
                local n = link.to
                if not closed[n] then
                    local g = gScore[best] + link.cost
                    if not gScore[n] or g < gScore[n] then
                        if not gScore[n] then open[#open + 1] = n end
                        gScore[n], came[n], cameLink[n] = g, best, link
                        fScore[n] = g + h(n)
                    end
                end
            end
        end
        return nil
    end

    local function trackMovers()
        local now = os.clock()
        for _, m in ipairs(movers) do
            local part = m.part
            if part.Parent then
                local dt = now - m.at
                if dt > 0.02 then
                    local cf = part.CFrame
                    local delta = m.last:ToObjectSpace(cf)
                    local axis, angle = delta:ToAxisAngle()
                    m.omega = m.last:VectorToWorldSpace(axis) * (angle / dt)
                    m.vel = (cf.Position - m.last.Position) / dt
                    m.last, m.at = cf, now
                end
            end
        end
    end

    local function dangerAt(spot, feetY, ahead)
        for _, m in ipairs(movers) do
            local part = m.part
            if part.Parent then
                local speed = m.omega.Magnitude
                for t = 0, ahead, 0.05 do
                    local cf = part.CFrame
                    if speed > 0.01 then cf = CFrame.fromAxisAngle(m.omega.Unit, speed * t) * (cf - cf.Position) + cf.Position end
                    cf = cf + m.vel * t
                    local h = part.Size / 2
                    for _, y in ipairs({feetY + 1, feetY + 3, feetY + 5}) do
                        local rel = cf:PointToObjectSpace(Vector3.new(spot.X, y, spot.Z))
                        if math.abs(rel.X) <= h.X + 1.6 and math.abs(rel.Y) <= h.Y + 1.6 and math.abs(rel.Z) <= h.Z + 1.6 then return true end
                    end
                end
            end
        end
        return false
    end

    local function jump(double)
        local action = gameAction("MobileJump")
        if not action then return end
        obby.jumps = obby.jumps + 1
        task.spawn(function()

            action:Fire(true) task.wait(0.12) action:Fire(false)
            if double then
                task.wait(math.max(T2 - 0.12, 0.05))
                action:Fire(true) task.wait(0.12) action:Fire(false)
            end
        end)
    end

    local function grounded(root)
        local _, humanoid = Game.ownRoot()
        return humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air and math.abs(root.AssemblyLinearVelocity.Y) < 6
    end

    local function bind()
        pcall(function() RunService:UnbindFromRenderStep(RENDER) end)
        RunService:BindToRenderStep(RENDER, Enum.RenderPriority.Character.Value + 2, function()
            if not obby.active then return end
            local _, humanoid = Game.ownRoot()
            if humanoid then humanoid:Move(moveDir, false) end
        end)
    end
    onCleanup(function() pcall(function() RunService:UnbindFromRenderStep(RENDER) end) end)

    local function flat(v) return Vector3.new(v.X, 0, v.Z) end

    local function clearWalk(from, cell)
        local to = Vector3.new(cell.x, 0, cell.z)
        local offset = flat(to - from)
        local steps = math.max(1, math.ceil(offset.Magnitude / 1))
        for k = 1, steps do
            local p = from + offset * (k / steps)
            local list = cellsAt(math.floor(p.X / CELL + 0.5), math.floor(p.Z / CELL + 0.5))
            local ok = false
            for _, c in ipairs(list or {}) do
                if math.abs(c.y - cell.y) < 1.6 or (c.part == cell.part and c.ramp) then ok = true break end
            end
            if not ok then return false end
        end
        return true
    end

    local function follow(path, map)
        local i = 1
        local legStart = os.clock()
        local lastPos = nil
        local stuckPos, stuckAt, stuckJumped = nil, os.clock(), false
        while i <= #path do
            if not obby.enabled or not alive or not map.Parent then return "stop" end
            local root = Game.ownRoot()
            if not root then return "replan" end

            if lastPos and (root.Position - lastPos).Magnitude > 12 then
                obby.resets = (obby.resets or 0) + 1
                return "replan"
            end
            lastPos = root.Position
            obby.lastSeen = root.Position
            trackMovers()
            local link = path[i]
            local target = Vector3.new(link.to.x, link.to.y, link.to.z)
            if link.kind == "walk" then

                local j = i
                while j < #path and j < i + 8 and path[j + 1].kind == "walk" and clearWalk(root.Position, path[j + 1].to) do j = j + 1 end
                local far = path[j].to
                local aim = Vector3.new(far.x, far.y, far.z)
                local gap = flat(aim - root.Position)

                local dir = gap.Magnitude > 0.1 and gap.Unit or Vector3.zero
                local risky = false
                for _, ahead in ipairs({3, 5, 7}) do
                    if dangerAt(root.Position + dir * ahead, link.to.y, 0.35 + ahead * 0.08) then risky = true break end
                end
                if risky then
                    obby.waits = obby.waits + 1
                    obby.last = "waiting for a moving hazard"
                    stuckPos = nil
                    if dangerAt(root.Position, link.to.y, 0.35) then
                        moveDir = gap.Magnitude > 0.1 and -gap.Unit or Vector3.zero
                    else
                        moveDir = Vector3.zero
                    end
                    RunService.Heartbeat:Wait()
                else
                    obby.last = ("running (%d steps left)"):format(#path - i + 1)
                    moveDir = gap.Magnitude > 0.1 and gap.Unit or Vector3.zero

                    if not stuckPos or (root.Position - stuckPos).Magnitude > 2 then
                        stuckPos, stuckAt, stuckJumped = root.Position, os.clock(), false
                    elseif os.clock() - stuckAt > 3 then
                        return "replan"
                    elseif os.clock() - stuckAt > 1 and not stuckJumped and grounded(root) then
                        stuckJumped = true
                        jump(true)
                    end

                    for k = j, i, -1 do
                        local c = path[k].to
                        if flat(Vector3.new(c.x, 0, c.z) - root.Position).Magnitude < 2 and math.abs(c.y - (root.Position.Y - 3)) < 4 then
                            i = k + 1
                            break
                        end
                    end
                    RunService.Heartbeat:Wait()
                end
            else

                local from = i > 1 and path[i - 1].to or cellNear(root.Position)
                local takeoff = from and Vector3.new(from.x, 0, from.z) or flat(root.Position)
                local toTakeoff = flat(takeoff - root.Position)
                if toTakeoff.Magnitude > 1.2 then
                    moveDir = toTakeoff.Unit
                    RunService.Heartbeat:Wait()
                elseif dangerAt(target, link.to.y, 0.9) then
                    moveDir = Vector3.zero
                    obby.waits = obby.waits + 1
                    obby.last = "waiting to jump"
                    RunService.Heartbeat:Wait()
                else
                    obby.last = link.kind == "double" and "double jump" or "jump"
                    jump(link.kind == "double")
                    local air = os.clock()
                    task.wait(0.08)
                    while os.clock() - air < 3 do
                        root = Game.ownRoot()
                        if not root then return "replan" end
                        local gap = flat(target - root.Position)

                        moveDir = gap.Magnitude > 0.7 and gap.Unit or Vector3.zero
                        if os.clock() - air > 0.3 and grounded(root) then break end
                        RunService.Heartbeat:Wait()
                    end
                    moveDir = Vector3.zero
                    lastPos = root and root.Position
                    local here = root and cellNear(root.Position)
                    if not here or here ~= link.to and flat(Vector3.new(here.x, 0, here.z) - target).Magnitude > 3 then
                        return "replan"
                    end
                    i = i + 1
                end
            end
            if os.clock() - legStart > 40 then return "replan" end
        end
        return "ok"
    end

    local function run(map)
        if obby.active then return end
        obby.active = true
        obby.runs = obby.runs + 1
        bind()
        local runStarted = os.clock()

        task.spawn(function()
            while obby.active do
                pcall(setSprint, true)
                task.wait(1)
            end
        end)
        local ok, err = pcall(function()
            obby.last = "mapping the course"
            if not build(map) then obby.last = "no finish (Won) or nowhere to walk" return end
            obby.last = ("mapped: %d cells, %d moving hazards"):format(#cells, #movers)

            local gateWait = os.clock()
            while obby.enabled and alive and map.Parent and os.clock() - gateWait < 90 do
                local gate = map:FindFirstChild("BLOCKER", true)
                if not (gate and gate:IsA("BasePart") and gate.CanCollide and gate.Transparency < 0.99) then break end
                obby.last = "waiting for the race to start"
                task.wait(0.05)
            end
            local attempts = 0
            while obby.enabled and alive and map.Parent and attempts < 30 do
                local root = Game.ownRoot()
                if root and won and inBox(won, root.Position, 0.5, 2) then
                    obby.finishes = obby.finishes + 1
                    obby.last = "finished"
                    break
                end
                if not root or not grounded(root) then
                    moveDir = Vector3.zero
                    task.wait(0.2)
                else
                    local start = cellNear(root.Position)
                    local path = start and plan(start)
                    attempts = attempts + 1
                    local partial = false
                    if not path and start then

                        local best = closestReachable(start)
                        local there = best and math.abs(best.x - start.x) + math.abs(best.z - start.z) <= 4 and math.abs(best.y - start.y) < 2
                        if best and not there then
                            local saved = goalCells
                            goalCells = {best}
                            best.goal = true
                            path = plan(start)
                            best.goal = nil
                            goalCells = saved
                            partial = path ~= nil
                        elseif there then
                            obby.last = "as far as it can get (the rest needs moves, not jumps)"
                            moveDir = Vector3.zero
                            while obby.enabled and alive and map.Parent do task.wait(0.5) end
                            break
                        end
                    end
                    if not path then
                        obby.last = "no way to the finish from here"
                        task.wait(0.5)
                    else
                        if partial then obby.partial = true end
                        local result = follow(path, map)
                        moveDir = Vector3.zero
                        if result == "stop" then break end
                    end
                end
            end
        end)
        if not ok then obby.last = "stopped: " .. tostring(err) end

        if not map.Parent and won and obby.lastSeen and inBox(won, obby.lastSeen, 6, 6)
            and not tostring(obby.last):find("^finished") then
            obby.finishes = obby.finishes + 1
            obby.last = "finished"
        end
        logResult("course", map, runStarted)
        moveDir = Vector3.zero
        obby.active = false
        pcall(setSprint, false)
    end

    local function indicatorColor(indicator)
        local best = indicator.Color
        for _, d in ipairs(indicator:GetDescendants()) do
            if d:IsA("GuiObject") and d.Visible and d.BackgroundTransparency < 0.5 and d.AbsoluteSize.X > 5 then best = d.BackgroundColor3 break end
        end
        return best
    end
    local function colorGap(a, b) return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) end
    local function runColors(map)
        if obby.active then return end
        obby.active = true
        obby.runs = obby.runs + 1
        bind()
        local runStarted = os.clock()
        local rounds = 0
        local ok, err = pcall(function()
            local indicator = map:FindFirstChild("Indicator", true)
            local started = os.clock()
            local floorY
            for _, tile in ipairs(map:GetDescendants()) do
                if tile:IsA("BasePart") and tile.Name == "Tile" then floorY = math.min(floorY or math.huge, tile.Position.Y - tile.Size.Y / 2) end
            end
            obby.fell = false
            local wasMixed = false
            while obby.enabled and alive and map.Parent and indicator and indicator.Parent and os.clock() - started < 240 do
                local root = Game.ownRoot()
                if root and floorY and root.Position.Y < floorY - 4 then obby.fell = true end

                if root and floorY and root.Position.Y > floorY + 40 then
                    obby.fell = true
                    moveDir = Vector3.zero
                    obby.last = "out, watching"
                elseif not root then
                    moveDir = Vector3.zero
                else
                    local want = indicatorColor(indicator)
                    local best, bestD

                    local sum, count, first, mixed = Vector3.zero, 0, nil, false
                    for _, tile in ipairs(map:GetDescendants()) do
                        if tile:IsA("BasePart") and tile.Name == "Tile" then
                            sum, count = sum + tile.Position, count + 1
                            if not first then first = tile.Color elseif colorGap(first, tile.Color) > 0.08 then mixed = true end
                            if tile.CanCollide and tile.Transparency < 0.9 and colorGap(tile.Color, want) < 0.08 then
                                local d = flat(tile.Position - root.Position).Magnitude
                                if not bestD or d < bestD then best, bestD = tile, d end
                            end
                        end
                    end
                    pcall(setSprint, true)
                    if mixed and not wasMixed and not obby.fell then rounds = rounds + 1 end
                    wasMixed = mixed
                    if not mixed and count > 0 then
                        local centre = flat(sum / count - root.Position)
                        moveDir = centre.Magnitude > 1.5 and centre.Unit or Vector3.zero
                        obby.last = ("waiting in the middle for the colour (%d studs away)"):format(math.floor(centre.Magnitude))
                    elseif best then
                        local to = flat(best.Position - root.Position)

                        moveDir = to.Magnitude > math.min(best.Size.X, best.Size.Z) * 0.15 and to.Unit or Vector3.zero
                        obby.last = ("standing on %s (%d studs away)"):format(tostring(best.BrickColor), math.floor(bestD))
                    else
                        moveDir = Vector3.zero
                        obby.last = "waiting for the colour"
                    end
                end
                RunService.Heartbeat:Wait()
            end
        end)
        if not ok then obby.last = "stopped: " .. tostring(err) end
        if obby.fell then obby.last = ("out after %d rounds (%s)"):format(rounds, obby.last)
        else obby.last = ("stayed on to the end (%d rounds)"):format(rounds) end
        pcall(setSprint, false)
        logResult("colours", map, runStarted)
        moveDir = Vector3.zero
        obby.active = false
    end
    obby.RunColors = runColors

    local function onMap(map)
        if map.Name ~= "MinigameMap" then return end
        task.wait(1)
        saveMap(map)
        if not (obby.enabled and correctGame) then return end
        if map:FindFirstChild("Indicator", true) and map:FindFirstChild("Tile", true) then task.spawn(runColors, map)
        elseif map:FindFirstChild("Won", true) then task.spawn(run, map) end
    end
    connect(workspace.ChildAdded, function(child) task.spawn(onMap, child) end)
    obby.Start = function()
        local map = workspace:FindFirstChild("MinigameMap")
        if not map or obby.active then return end
        if map:FindFirstChild("Indicator", true) and map:FindFirstChild("Tile", true) then task.spawn(runColors, map)
        elseif map:FindFirstChild("Won", true) then task.spawn(run, map) end
    end
    obby.Run = run
end

local hop = {enabled = false, after = 90, last = "off", skipJuggernaut = false, skip = {Juggernaut = true},
    lowPop = false, minPlayers = 5}
state.Hop = hop
do
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local idleSince, badSince, smallSince, hoppingUntil = nil, nil, nil, 0
    local startedAt = os.clock()

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
                and mode ~= "Intermission" and not hop.skip[mode] and players >= 3 and players <= max - 2
                and (not hop.wantBigger or players >= hop.minPlayers) then
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

            local count = #Players:GetPlayers()
            local small = hop.lowPop and correctGame and count < hop.minPlayers and os.clock() - startedAt > 60
            if small then
                hop.wantBigger = true
                small = #hop.Candidates() > 0
                hop.wantBigger = false
            end
            if os.clock() < hoppingUntil then

            elseif small then
                idleSince, badSince = nil, nil
                smallSince = smallSince or os.clock()
                local left = math.ceil(30 - (os.clock() - smallSince))
                hop.last = ("only %d players here, hopping in %ds"):format(count, math.max(left, 0))
                if left <= 0 then
                    smallSince = nil
                    hop.wantBigger = true
                    hop.Go(("only %d players"):format(count))
                    hop.wantBigger = false
                end
            elseif bad then
                smallSince = nil

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
                idleSince, badSince, smallSince = nil, nil, nil
                hop.last = (hop.enabled or hop.skipJuggernaut or hop.lowPop) and ("watching" .. (mode and (" (" .. mode .. ")") or "")) or "off"
            end
            task.wait(1)
        end
    end)
end

local webhook = {enabled = false, url = "", every = 30, events = true, last = "off"}
state.Webhook = webhook
do
    local HttpService = game:GetService("HttpService")

    local FILE = "BPHubABA/night_" .. tostring(player.UserId) .. ".json"
    local night
    local function load()
        local ok, data = pcall(function() return isfile(FILE) and HttpService:JSONDecode(readfile(FILE)) end)
        if ok and type(data) == "table" and os.time() - (tonumber(data.updated) or 0) < 1800 then return data end
        return {started = os.time(), updated = os.time(), kills = 0, deaths = 0, gold = 0, damage = 0, quests = 0, hops = 0, servers = 1}
    end
    night = load()

    if night.job ~= game.JobId then
        night.servers = (night.job and (night.servers or 0) + 1) or 1
        night.job = game.JobId
    end
    local seen = {kills = 0, deaths = 0, gold = 0, damage = 0}
    local function save()
        for _, key in ipairs({"kills", "deaths", "gold", "damage"}) do
            local now = session[key] or 0
            if now > seen[key] then night[key] = (night[key] or 0) + (now - seen[key]) end
            seen[key] = now
        end
        night.updated = os.time()
        pcall(function()
            if not isfolder("BPHubABA") then makefolder("BPHubABA") end
            writefile(FILE, HttpService:JSONEncode(night))
        end)
    end
    webhook.Night = function() save() return night end

    local reset = session.Reset
    session.Reset = function() reset() for key in pairs(seen) do seen[key] = 0 end end

    local function valid(url)
        return type(url) == "string" and (url:match("^https://discord%.com/api/webhooks/%d+/[%w_%-]+$")
            or url:match("^https://%a*%.?discord%.com/api/webhooks/%d+/[%w_%-]+$")
            or url:match("^https://discordapp%.com/api/webhooks/%d+/[%w_%-]+$")) ~= nil
    end
    webhook.Valid = valid

    local function post(payload)
        local send = request or http_request or (syn and syn.request) or (http and http.request)
        if not send then webhook.last = "this executor can't send web requests" return false end
        if not valid(webhook.url) then webhook.last = "paste a Discord webhook link first" return false end
        local ok, res = pcall(send, {Url = webhook.url, Method = "POST",
            Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(payload)})
        local code = ok and type(res) == "table" and tonumber(res.StatusCode) or 0
        if code >= 200 and code < 300 then
            webhook.last = "sent " .. os.date("%H:%M")
            return true
        end
        webhook.last = ok and ("Discord said " .. tostring(code)) or ("couldn't send: " .. tostring(res))
        return false
    end

    local function duration(seconds)
        local m = math.floor(seconds / 60)
        return ("%dh %02dm"):format(math.floor(m / 60), m % 60)
    end
    local function num(n)
        local s = tostring(math.floor(n + 0.5))
        local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
        return (out:gsub("^,", ""))
    end

    function webhook.Stats(title)
        save()
        local secs = math.max(os.time() - night.started, 60)
        local hours = secs / 3600
        local kd = night.deaths > 0 and night.kills / night.deaths or night.kills
        local quest, progress
        if state.Quests then quest, progress = state.Quests.Focused() end
        local fields = {
            {name = "Kills", value = num(night.kills), inline = true},
            {name = "Deaths", value = num(night.deaths) .. (" (K/D %.2f)"):format(kd), inline = true},
            {name = "Gold", value = "+" .. num(night.gold), inline = true},
            {name = "Per hour", value = ("%s kills · %s gold"):format(num(night.kills / hours), num(night.gold / hours)), inline = true},
            {name = "Damage", value = num(night.damage), inline = true},
            {name = "Quests done", value = num(night.quests or 0), inline = true},
            {name = "This server", value = ("%s · %d players · %s here · %d kills"):format(tostring(workspace:GetAttribute("GameMode") or "?"),
                #Players:GetPlayers(), duration(os.clock() - session.started), session.kills), inline = false},
            {name = "Playing", value = tostring(player:GetAttribute("LastLoadedChar") or "-")
                .. (quest and not quest.Finished and ("\nQuest: " .. tostring(quest.Description) .. " - " .. tostring(progress)) or ""), inline = false},
        }
        return {
            username = "Catn Hub",
            embeds = {{

                title = (title or ("Farm report · " .. duration(secs))) .. " · " .. player.Name,
                color = 0x8F70EC,
                fields = fields,
                footer = {text = ("Anime Battle Arena · %d servers · %d hops"):format(night.servers or 1, night.hops or 0)},
                timestamp = DateTime.now():ToIsoDate(),
            }},
        }
    end

    function webhook.Event(text, color)
        if not (webhook.enabled and webhook.events) then return end
        task.spawn(post, {username = "Catn Hub", embeds = {{description = text, color = color or 0x8F70EC,
            footer = {text = player.Name},
            timestamp = DateTime.now():ToIsoDate()}}})
    end
    function webhook.SendNow(title) return post(webhook.Stats(title)) end

    if state.Quests then
        state.Quests.onFinished = function(quest)
            night.quests = (night.quests or 0) + 1
            save()
            local r = quest.Rewards or {}
            webhook.Event(("Quest done: **%s** (+$%s, +%s EXP)"):format(tostring(quest.Description), tostring(r.Gold or "?"), tostring(r.EXP or "?")), 0x57F287)
        end
    end
    local go = hop.Go
    hop.Go = function(reason)
        night.hops = (night.hops or 0) + 1
        save()
        webhook.Event(("Hopping servers: %s"):format(tostring(reason)), 0xFEE75C)
        task.wait(0.5)
        return go(reason)
    end

    task.spawn(function()
        local sentAt = os.clock()
        while alive do
            save()
            if webhook.enabled and os.clock() - sentAt >= webhook.every * 60 then
                sentAt = os.clock()
                post(webhook.Stats())
            elseif not webhook.enabled then
                webhook.last = "off"
                sentAt = os.clock()
            end
            task.wait(10)
        end
    end)
end

local screen = {no3d = false, cover = "Off", fpsLimit = false, fps = 30}
state.Screen = screen
do
    local gui, label
    local capped = false
    local function build()
        if gui and gui.Parent then return end
        gui = Instance.new("ScreenGui")
        gui.Name = "CatnCover"
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 50
        gui.Enabled = false
        local frame = Instance.new("Frame")
        frame.Name = "Cover"
        frame.Size = UDim2.fromScale(1, 1)
        frame.BorderSizePixel = 0
        frame.Parent = gui
        label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Position = UDim2.fromScale(0.5, 0.5)
        label.Size = UDim2.new(0.8, 0, 0, 60)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 16
        label.TextWrapped = true
        label.Parent = frame
        if type(syn) == "table" and type(syn.protect_gui) == "function" then pcall(syn.protect_gui, gui) end
        gui.Parent = hiddenGuiParent()
    end
    local function apply()
        local covered = screen.cover == "Black" or screen.cover == "White"
        pcall(function() RunService:Set3dRenderingEnabled(not (screen.no3d or covered)) end)
        if screen.cover == "Black" or screen.cover == "White" then
            build()
            local black = screen.cover == "Black"
            gui.Cover.BackgroundColor3 = black and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
            label.TextColor3 = Color3.fromRGB(120, 120, 130)
            gui.Enabled = true
        elseif gui then
            gui.Enabled = false
        end

        if type(setfpscap) == "function" and (screen.fpsLimit or capped) then
            capped = screen.fpsLimit
            pcall(setfpscap, screen.fpsLimit and screen.fps or 0)
        end
    end
    screen.Apply = apply

    task.spawn(function()
        while alive do
            if gui and gui.Enabled and label then
                local s = state.Session
                local bot = state.Bot
                label.Text = ("screen covered  ·  %s\nkills %d  ·  deaths %d  ·  gold +%d  ·  RightShift opens the menu"):format(
                    bot and bot.enabled and ("farming: " .. tostring(bot.last)) or "farm off",
                    s and s.kills or 0, s and s.deaths or 0, math.floor(s and s.gold or 0))
            end
            task.wait(1)
        end
    end)
    onCleanup(function()
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
        if type(setfpscap) == "function" and capped then pcall(setfpscap, 0) end
        if gui then gui:Destroy() end
    end)
end

local presetToggles = {}

local created, result = pcall(function()
    return BPUI:CreateWindow({Version = "1.10.0",
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
    ui.performance = info:AddLabel({Text = "FPS: -  ·  ping: -", Style = "Sub"})
    ui.selfCheck = info:AddLabel({Text = "self check: running...", Style = "Sub"})
    info:AddButton({Name = "Unload", Callback = function() state.Destroy() end})

    local sessionSection = overviewTab:CreateSection("Session")
    ui.sessionTime = sessionSection:AddLabel({Text = "time: 0m", Style = "Sub"})
    ui.sessionGold = sessionSection:AddLabel({Text = "gold: +0", Style = "Sub"})
    ui.sessionFights = sessionSection:AddLabel({Text = "kills: 0  ·  deaths: 0  ·  damage: 0", Style = "Sub"})
    ui.sessionRate = sessionSection:AddLabel({Text = "per hour: -", Style = "Sub"})
    sessionSection:AddButton({Name = "Reset session", Callback = session.Reset})

    local statusSection = overviewTab:CreateSection("Status")
    ui.overview = {}
    for _, key in ipairs({"bot", "esp", "panel", "anyBlackFlash", "yuji", "nanami", "yusuke", "krillin"}) do
        ui.overview[key] = statusSection:AddLabel({Text = "-", Style = "Sub"})
    end

    local keys = overviewTab:CreateSection("Default keys", {Collapsed = true})
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

    local learn = farmTab:CreateSection("Learning")
    farmControls.learn = learn:AddToggle({Name = "Learn from fights", Tag = "Experimental", Default = true, Flag = "bot_learn",
        Description = "Keeps score of which moves land, which fight style works against each character, whether to block or trade, and who keeps beating you, then leans toward what works. Saved, so it keeps improving across servers.",
        Callback = function(value) brain.enabled = value == true bot.learn = brain.enabled end})
    ui.brain = learn:AddLabel({Text = "-", Style = "Sub"})
    learn:AddButton({Name = "Forget what it learned", ButtonText = "Reset", Style = "Danger", Callback = function()
        brain.Reset()
        pcall(function() BPUI:Notify({Title = "Learning", Content = "Starting from scratch.", Duration = 3}) end)
    end})

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

    local questSection = farmTab:CreateSection("Daily quests")
    presetToggles.quests = questSection:AddToggle({Name = "Do daily quests", Default = false, Flag = "spawn_quests",
        Description = "Takes the quests the farm can finish by itself (kills, damage, short combos), best gold first, and respawns you as the character they need. Ranked, wins and anything else are skipped. Needs Auto spawn on to change character.",
        Callback = function(value) spawner.quests = value == true quests.enabled = value == true end})
    ui.questStatus = questSection:AddLabel({Text = "off", Style = "Sub"})

    local minigames = farmTab:CreateSection("Minigames")
    presetToggles.minigames = minigames:AddToggle({Name = "Play minigames", Tag = "Experimental", Default = false, Flag = "minigames_auto",
        Description = "When the server runs a minigame it plays it: runs the obby, the race and the maze to the finish (around walls, over gaps, waiting out spinners), and stands on the right colour in the colour game. The farm waits meanwhile.",
        Callback = function(value)
            obby.enabled = value == true
            if obby.enabled then obby.Start() end
        end})
    ui.minigameStatus = minigames:AddLabel({Text = "off", Style = "Sub"})

    local discord = farmTab:CreateSection("Discord")
    discord:AddInput({Name = "Webhook link", Placeholder = "https://discord.com/api/webhooks/...", Flag = "webhook_url",
        Description = "In Discord: channel settings > Integrations > Webhooks > New Webhook > Copy Webhook URL. Anyone with the link can post to that channel, so keep it to yourself.",
        Callback = function(text)
            webhook.url = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if webhook.url ~= "" and not webhook.Valid(webhook.url) then
                pcall(function() BPUI:Notify({Title = "Discord", Content = "That isn't a Discord webhook link.", Type = "Warning", Duration = 4}) end)
            end
        end})
    presetToggles.webhook = discord:AddToggle({Name = "Send farm stats", Default = false, Flag = "webhook_enabled",
        Description = "Posts kills, deaths, gold, per-hour rates and quest progress to your channel. Totals carry over server hops.",
        Callback = function(value) webhook.enabled = value == true end})
    discord:AddSlider({Name = "Every", Min = 5, Max = 120, Default = 30, Increment = 5, Suffix = " min", Flag = "webhook_every",
        Callback = function(value) webhook.every = tonumber(value) or 30 end})
    discord:AddToggle({Name = "Also when a quest finishes or it hops", Default = true, Flag = "webhook_events",
        Callback = function(value) webhook.events = value == true end})
    discord:AddButton({Name = "Send a report now", ButtonText = "Send", Callback = function()
        task.spawn(function()
            local ok = webhook.SendNow()
            pcall(function() BPUI:Notify({Title = "Discord", Content = ok and "Sent." or webhook.last, Type = ok and "Info" or "Warning", Duration = 4}) end)
        end)
    end})
    ui.webhookStatus = discord:AddLabel({Text = "off", Style = "Sub"})

    local night = farmTab:CreateSection("Overnight")
    presetToggles.leaveAfk = night:AddToggle({Name = "Leave the AFK World", Default = true, Flag = "leave_afk_world",
        Description = "If the game moves you to its AFK World while you're idle, the hub sends you straight back to a normal server. Needs the hub in your executor's autoexec, so it loads there too.",
        Callback = function(value)
            pcall(function()
                if not isfolder("BPHubABA") then makefolder("BPHubABA") end
                writefile("BPHubABA/leave_afk_world.txt", value and "on" or "off")
            end)
        end})
    presetToggles.hop = night:AddToggle({Name = "Hop when there's nobody to fight", Default = false, Flag = "hop_enabled",
        Description = "Joins another server, picked from the game's server list, once the farm has had no target for a while.",
        Callback = function(value) hop.enabled = value == true end})
    farmControls.hopAfter = night:AddSlider({Name = "Wait before hopping", Min = 30, Max = 300, Default = 90, Increment = 10, Suffix = " s", Flag = "hop_after",
        Callback = function(value) hop.after = tonumber(value) or 90 end})
    presetToggles.skipJuggernaut = night:AddToggle({Name = "Skip Juggernaut servers", Default = false, Flag = "hop_skip_juggernaut",
        Description = "Leaves a server as soon as it's playing Juggernaut, for one that has people in and isn't. Hops always pick a non-Juggernaut server.",
        Callback = function(value) hop.skipJuggernaut = value == true end})
    presetToggles.lowPop = night:AddToggle({Name = "Hop when the server is small", Default = false, Flag = "hop_low_pop",
        Description = "Joins a bigger server from the game's list when this one has fewer players than the number below for 30 seconds. More people to fight means more kills.",
        Callback = function(value) hop.lowPop = value == true end})
    farmControls.minPlayers = night:AddSlider({Name = "Fewest players", Min = 2, Max = 12, Default = 5, Increment = 1, Suffix = " players", Flag = "hop_min_players",
        Callback = function(value) hop.minPlayers = tonumber(value) or 5 end})
    ui.hopStatus = night:AddLabel({Text = "off", Style = "Sub"})

    local BEST = {
        targets = "Players", team = "Enemies only", goAfter = "Whoever is nearest", skipAfk = true, skipUlt = true,
        moves = true, reach = 10, awaken = true, trade = true, smart = true,
        sprint = true, dash = true, jump = true, lockCamera = true, aimMouse = false, hopAfter = 60, learn = true,
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
    night:AddButton({Name = "Set up for overnight", ButtonText = "Turn on", Style = "Primary", Callback = function()
        applyBest()
        for _, key in ipairs({"antiAfk", "rejoin", "block", "blockFarm", "spawn", "quests", "noAfk", "leaveAfk", "hop", "lowPop", "skipJuggernaut", "bot"}) do
            local element = presetToggles[key]
            if element then pcall(function() element:Set(true) end) end
        end
        pcall(function()
            BPUI:Notify({Title = "Overnight", Content = rejoin.loader ~= "" and "Best farm settings, plus farm, auto spawn, auto block, anti-AFK, rejoin, server hops and Juggernaut skip are on."
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
    local tuning = defenseTab:CreateSection("Tuning", {Collapsed = true})
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
    local face = defenseTab:CreateSection("Face check", {Collapsed = true})
    local faceToggle = face:AddToggle({Name = "Only block attacks aimed at you", Default = true, Flag = "auto_block_face",
        Description = "Skips enemies swinging the other way.",
        Callback = function(value) autoBlock.faceCheck = value == true end})
    face:AddSlider({Name = "Facing angle", DependsOn = faceToggle, Min = 30, Max = 120, Default = 75, Increment = 5, Suffix = " deg",
        Flag = "auto_block_face_angle", Description = "How far off pointing at you they can be and still count.",
        Callback = function(value) autoBlock.faceAngle = tonumber(value) or 75 end})
    local human = defenseTab:CreateSection("Look human", {Collapsed = true})
    human:AddSlider({Name = "Reaction delay", Min = 0, Max = 150, Default = 0, Increment = 10, Suffix = " ms", Flag = "auto_block_react",
        Description = "Waits a random part of this before blocking. M1s land about 210 ms after they start, so keep it low.",
        Callback = function(value) autoBlock.reactMs = tonumber(value) or 0 end})
    human:AddSlider({Name = "Miss chance", Min = 0, Max = 50, Default = 0, Increment = 5, Suffix = " %", Flag = "auto_block_miss",
        Description = "Lets this share of attacks through on purpose.",
        Callback = function(value) autoBlock.missChance = tonumber(value) or 0 end})
    presetToggles.blockFarm = tuning:AddToggle({Name = "Auto farm blocks too", Default = true, Flag = "auto_block_farm_guard",
        Description = "The farm blocks every swing and holds block for a move's whole length, even with Auto block off.",
        Callback = function(value) autoBlock.farmGuard = value == true end})
    tuning:AddToggle({Name = "Dodge guard breaks and finishers", Default = true, Flag = "auto_block_dodge_gb",
        Description = "Dashes sideways out of moves that go through block, and out of the farm's 5th M1 hit.",
        Callback = function(value) autoBlock.dodgeGuardbreaks = value == true end})
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

    local filters = visualsTab:CreateSection("Filters", {Collapsed = true})
    filters:AddToggle({Name = "Hide teammates", Default = true, Flag = "esp_hide_team",
        Callback = function(value) esp.hideTeammates = value == true end})
    filters:AddToggle({Name = "Hide AFK", Default = true, Flag = "esp_hide_afk",
        Callback = function(value) esp.hideAfk = value == true end})
    filters:AddToggle({Name = "Limit distance", Default = false, Flag = "esp_limit_distance",
        Callback = function(value) esp.limitDistance = value == true end})
    filters:AddSlider({Name = "Max distance", Min = 100, Max = 5000, Default = 1500, Increment = 50, Suffix = " studs",
        Flag = "esp_max_distance", Callback = function(value) esp.maxDistance = tonumber(value) or 1500 end})

    local colors = visualsTab:CreateSection("Colors", {Collapsed = true})
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

    local alertSection = visualsTab:CreateSection("Mode alerts", {Collapsed = true})
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

    local cds = compTab:CreateSection("Cooldown strips", {Collapsed = true})
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
    local lines = {string.format("%s  ·  %d kills, %d deaths  ·  %d dmg  ·  mode %s",
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
    local targets = charactersTab:CreateSection("Krillin: targets", {Collapsed = true})
    teamDropdown(targets, "krillin_team", function(mode) krillin.teamMode = mode end)
    targets:AddToggle({Name = "Hit anyone if no enemies", Default = false, Flag = "krillin_fallback",
        Callback = function(value) krillin.fallback = value == true end})
    local timingSection = charactersTab:CreateSection("Krillin: timing", {Collapsed = true})
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
        Description = "Lowest graphics quality and no shadows. A small gain at most; for a big one, turn off 3D rendering below.",
        Callback = function(value) client.Set("fpsBoost", value) end})
    perf:AddToggle({Name = "Turn off 3D rendering", Default = false, Flag = "screen_no3d",
        Description = "The world stops drawing, which takes most of the load off your graphics card. The game, the farm and the menus keep running.",
        Callback = function(value) screen.no3d = value == true screen.Apply() end})
    perf:AddDropdown({Name = "Cover the screen", Options = {"Off", "Black", "White"}, Default = "Off", Flag = "screen_cover",
        Description = "A plain screen over the game, with the farm's kills and gold on it. 3D drawing is switched off underneath, which is where the FPS gain comes from. The hub's menu still opens on top.",
        Callback = function(value) screen.cover = value or "Off" screen.Apply() end})
    perf:AddToggle({Name = "Limit FPS", Default = false, Flag = "screen_fps_limit",
        Description = "Caps the frame rate, so an overnight farm runs cooler. The farm works fine at 30.",
        Callback = function(value) screen.fpsLimit = value == true screen.Apply() end})
    perf:AddSlider({Name = "FPS limit", Min = 10, Max = 120, Default = 30, Increment = 5, Suffix = " fps", Flag = "screen_fps",
        Callback = function(value) screen.fps = tonumber(value) or 30 screen.Apply() end})
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

    local share = macroTab:CreateSection("Share", {Collapsed = true})
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

        {"loadstring", "the hub itself", function() return type(loadstring) == "function" end},
        {"file functions", "saved settings, learning, night totals, last character", function()
            return type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function"
                and type(makefolder) == "function" and type(isfolder) == "function"
        end},
        {"BaseContext actions", "Auto Farm (M1, moves, block, dodge, sprint, jump)", function()
            for _, name in ipairs({"MouseClick", "Move1", "Move2", "Move3", "Move4", "Block", "Dodge", "Run", "MobileJump"}) do
                if not find(player, "PlayerScripts", "BaseContext", name) then return false end
            end
            return true
        end},
        {"game's sprint setting", "Auto Farm sprint (reads _G.PlayerSettings.SprintMode)", function()
            local g = type(getrenv) == "function" and getrenv()._G or _G
            return g.PlayerSettings ~= nil and g.PlayerSettings.SprintMode ~= nil
        end, true},
        {"Auto Farm loop", "Auto Farm", function()
            if not bot.enabled then return true end
            return bot.beat ~= nil and os.clock() - bot.beat < 15
        end, false, function() return "the farm's loop hasn't run for 15 s" end},
        {"Auto Farm errors", "Auto Farm", function()
            return not (bot.crashAt and os.clock() - bot.crashAt < 600)
        end, false, function() return ("hit %d error(s), restarted; last: %s"):format(bot.crashes or 0, tostring(bot.crash)) end},
        {"Auto Farm dealing damage", "Auto Farm", function()

            if not bot.enabled or spawner.InLobby() or not Game.ownRoot() or bot.target == "none" then return true end
            local since = session.damageAt or session.started
            return os.clock() - since < 180
        end, false, function() return "on and has a target, but no damage dealt in 3 min" end},

        {"Backpack.Input", "Auto spawn, Stay off AFK", function()
            local backpack = player:FindFirstChildOfClass("Backpack")
            return backpack ~= nil and backpack:FindFirstChild("Input") ~= nil
        end},
        {"HUD lobby line", "Auto spawn (knowing you're in the lobby)", function() return find(player, "PlayerGui", "HUD", "RightBotCorner", "Line1") ~= nil end},
        {"character menu", "Auto spawn (character names, locked ones skipped)", function() return #spawner.Characters() > 0 end},
        {"GameMessage", "Play minigames (telling the minigames apart)", function() return replicated:FindFirstChild("GameMessage") ~= nil end},
        {"title screen Play", "Auto spawn after a hop", function()
            return type(getconnections) == "function" or type(firesignal) == "function" or replicated:FindFirstChild("Loaded") ~= nil
        end},
        {"Player.AFK", "Stay off the AFK team", function() return player:FindFirstChild("AFK") ~= nil end, true},

        {"server list", "server hop, Juggernaut skip", function() return replicated:FindFirstChild("Servers") ~= nil end},
        {"ServerTP remote", "server hop (falls back to a random server)", function() return replicated:FindFirstChild("ServerTP") ~= nil end, true},
        {"GameMode attribute", "Juggernaut skip", function() return type(workspace:GetAttribute("GameMode")) == "string" end, true},
        {"queue_on_teleport", "hub coming back after a hop", function() return type(queue_on_teleport) == "function" end},

        {"QuestStuff remote", "Daily quests (taking quests)", function() return replicated:FindFirstChild("QuestStuff") ~= nil end},
        {"DailyQuest data", "Daily quests (progress, quest character)", function()
            local quest = find(player, "ReplicatedStats", "DailyQuest")
            return quest ~= nil and quests.Data() ~= nil
        end},

        {"web requests", "Discord stats", function()
            return type(request) == "function" or type(http_request) == "function"
                or (type(syn) == "table" and type(syn.request) == "function")
        end},
        {"Discord sending", "Discord stats", function()
            return not webhook.enabled or not tostring(webhook.last):find("^Discord said")
                and not tostring(webhook.last):find("^couldn't send") and not tostring(webhook.last):find("^paste")
        end, false, function() return "last try: " .. tostring(webhook.last) end},

        {"3D rendering switch", "Turn off 3D rendering", function()
            return (pcall(function() return RunService.Set3dRenderingEnabled end))
        end},
        {"setfpscap", "Limit FPS", function() return type(setfpscap) == "function" end},
    }

    local checkSection = miscTab:CreateSection("Self check", {Collapsed = true})
    checkSection:AddLabel({Text = executor, Style = "Sub"})
    local summary = checkSection:AddLabel({Text = "checking...", Style = "Sub"})
    local rows = {}
    for index, check in ipairs(checks) do rows[index] = checkSection:AddLabel({Text = check[1], Style = "Sub"}) end

    local rowText = {}
    local function setRow(index, text) rows[index]:Set(text) rowText[index] = text end
    local function runChecks()
        local missing, unsure = {}, 0
        for index, check in ipairs(checks) do
            local okCall, passed = pcall(check[3])
            passed = okCall and passed == true
            if passed then
                setRow(index, "ok  " .. check[1])
            elseif check[4] then
                unsure = unsure + 1
                setRow(index, "not found  " .. check[1] .. "  (" .. check[2] .. ", can be normal outside a match)")
            elseif check[5] then

                local why = select(2, pcall(check[5]))
                missing[#missing + 1] = check[2]
                setRow(index, "PROBLEM  " .. check[1] .. "  ->  " .. tostring(why))
            else
                missing[#missing + 1] = check[2]
                setRow(index, "MISSING  " .. check[1] .. "  ->  " .. check[2] .. " won't work")
            end
        end
        local text = #missing == 0 and ("all good" .. (unsure > 0 and (", " .. unsure .. " not found yet") or ""))
            or (#missing .. " problem(s): " .. table.concat(missing, ", "))

        local report = {"Catn Hub ABA self check  ·  " .. executor .. "  ·  " .. os.date("%Y-%m-%d %H:%M")}
        for index in ipairs(checks) do report[#report + 1] = rowText[index] or "" end
        state.selfCheckReport = report
        summary:Set(text)
        ui.selfCheck:Set("self check: " .. text)
        state.selfCheck = text
        return #missing
    end
    state.RunSelfCheck = runChecks
    checkSection:AddButton({Name = "Run again", Callback = runChecks})
    checkSection:AddButton({Name = "Copy the report", ButtonText = "Copy", Callback = function()
        runChecks()
        local text = table.concat(state.selfCheckReport or {}, "\n")
        local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
        if copy and pcall(copy, text) then
            pcall(function() BPUI:Notify({Title = "Self check", Content = "Copied. Paste it wherever you're asking for help.", Duration = 3}) end)
        else
            pcall(function() BPUI:Notify({Title = "Self check", Content = "This executor can't copy, so the report was printed to the console (F9).", Type = "Warning", Duration = 5}) end)
            print(text)
        end
    end})

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
            ui.status:Set(supported and ("ABA detected  ·  " .. executor) or "Wrong game, features locked")
            ui.character:Set("Character: " .. tostring(Game.characterName(player))
                .. (player.Team and ("  ·  Team: " .. player.Team.Name) or ""))
            ui.performance:Set(string.format("FPS: %d  ·  ping: %dms", math.floor(1 / math.max(timing.frame, 1e-3) + 0.5),
                math.floor(samplePing() * 1000 + 0.5)))

            local minutes = math.floor((os.clock() - session.started) / 60)
            ui.sessionTime:Set(string.format("time: %dh %dm", math.floor(minutes / 60), minutes % 60))
            ui.sessionGold:Set("gold: +" .. math.floor(session.gold))
            ui.sessionFights:Set(string.format("kills: %d  ·  deaths: %d  ·  damage: %d",
                session.kills, session.deaths, math.floor(session.damage)))
            local hours = math.max((os.clock() - session.started) / 3600, 1 / 60)
            ui.sessionRate:Set(string.format("per hour: %d kills  ·  %d gold", math.floor(session.kills / hours),
                math.floor(session.gold / hours)))
            ui.hopStatus:Set(hop.last)
            ui.questStatus:Set(quests.last .. (quests.done > 0 and ("  ·  done: " .. quests.done) or ""))
            ui.minigameStatus:Set((obby.enabled and (obby.last == "off" and "waiting for a minigame" or obby.last) or "off") .. (obby.finishes > 0 and ("  ·  finished: " .. obby.finishes) or ""))
            ui.webhookStatus:Set(webhook.last)
            ui.brain:Set(brain.enabled and (brain.Summary() .. "  ·  now: " .. brain.CurrentStyle() .. "  ·  last: " .. brain.last) or "off")

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

            ui.botStatus:Set(bot.enabled and (bot.last .. "  ·  target: " .. bot.target) or "off")
            ui.spawnStatus:Set(spawner.last)
            ui.macro:Set(macro.last .. ((#macro.events > 0 and not macro.recording) and ("  ·  " .. macro.Summary()) or ""))
            ui.espStatus:Set(esp.enabled and (esp.shown .. " players shown") or "off")
            ui.compStatus:Set(comp.enabled and ("focus: " .. (comp.focus or "none")) or "off")

            ui.anyBlackFlash:Set((anyBlackFlash.enabled and anyBlackFlash.last or "off") .. "  ·  clicks: " .. anyBlackFlash.clicks)
            ui.yujiBlackFlash:Set((yuji.blackFlash and yuji.blackFlashLast or "off") .. "  ·  clicks: " .. yuji.blackFlashClicks)
            ui.yujiDivergent:Set((yuji.divergent and yuji.divergentLast or "off") .. "  ·  clicks: " .. yuji.divergentClicks)
            ui.yujiSkull:Set((yuji.skull and yuji.skullLast or "off") .. "  ·  clicks: " .. yuji.skullClicks)
            ui.nanami:Set((nanami.enabled and nanami.last or "off") .. "  ·  hits: " .. nanami.hits)
            ui.kokushibo:Set((kokushibo.enabled and kokushibo.last or "off") .. "  ·  hits: " .. kokushibo.hits)
            ui.autoBlock:Set((autoBlock.GuardOn() and autoBlock.last or "off") .. "  ·  blocks: " .. autoBlock.blocks
                .. "  ·  dodges: " .. autoBlock.dodges)
            ui.rejoin:Set(rejoin.last)
            ui.yusuke:Set((yusuke.enabled and yusuke.last or "off") .. "  ·  shots: " .. yusuke.shots)
            ui.krillin:Set((krillin.enabled and krillin.last or "off") .. "  ·  volleys: " .. krillin.volleys)
            ui.sweeps:Set((sweeps.enabled and sweeps.last or "off") .. "  ·  casts: " .. sweeps.casts .. "  ·  hits: " .. sweeps.hits)

            if tabOpen(playerInfoTab) then refreshPlayerInfo() end
        end)
        if not ok then warn("[Catn Hub] status: " .. tostring(reason)) end
        task.wait(0.5)
    end
end)

return state
