if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local StarterPlayer = game:GetService("StarterPlayer")
local rs = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer
while not plr do task.wait() plr = Players.LocalPlayer end

local genv = getgenv and getgenv() or _G
if genv.__CFAE_FARM and genv.__CFAE_FARM.Destroy then
    pcall(genv.__CFAE_FARM.Destroy)
end

local BPUI = ... or loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/ui.lua"))()

local src = rs:WaitForChild("src")
local knit = require(src:WaitForChild("Packages"):WaitForChild("knit"))
pcall(function() knit.OnStart():await() end)

local function elevate()
    if setthreadidentity then pcall(setthreadidentity, 8) end
end

local function getController(name)
    local okc, c = pcall(knit.GetController, name)
    if okc then return c end
end

local function getService(name)
    local oks, s = pcall(knit.GetService, name)
    if oks then return s end
end

local config = src:WaitForChild("GameConfiguration")
local zoneConfig = require(config.Gameplay.zoneConfig)
local eggConfig = require(config.Gameplay.eggConfig)
local animalConfig = require(config.Gameplay.animalConfig)
local staminaUpgradeConfig = require(config.Economy.staminaUpgradeConfig)
local treadmillConfig = require(config.Economy.treadmillConfig)
local baseUpgradeConfig = require(config.Economy.baseUpgradeConfig)
local rebirthConfig = require(config.Economy.rebirthConfig)
local guardConfig = require(config.Gameplay.guardConfig)
local guardGeometry = require(src.utility.guardGeometry)
local dayCycle = require(src.utility.dayCycle)
local backpackLimits = require(src.utility.backpackLimits)
local speedCurve = require(src.utility.speedCurve)

local Data = getController("DataController")
local Bases = getController("BaseController")
local Hatcher = getController("EggHatchController")
local Loadout = getController("AnimalLoadoutController")
local Treadmill = getController("TreadmillController")
local Gifts = getController("GiftPlayTimeController")
local Jetpack = getController("JetpackController")
local SpeedState = getController("SpeedStateController")
local GuardAi = getController("GuardController")

local svc = {}
for _, name in ipairs({"EggPlacementService", "AnimalSellService", "StaminaUpgradeService", "TreadmillService",
    "BaseUpgradeService", "RebirthService", "DailyRewardsService", "GiftPlayTimeService", "IndexService",
    "CashFlowService", "DayCycleService", "HalloweenShopService"}) do
    svc[name] = getService(name)
end

local charContext = StarterPlayer:WaitForChild("PlayerModule"):WaitForChild("InputContexts"):WaitForChild("CharacterContext")
local MoveAction = charContext:WaitForChild("MoveAction")
local JumpAction = charContext:WaitForChild("JumpAction")

local alive = true
local conns = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(conns, c)
    return c
end

local settings = {
    pick = "Most valuable",
    waitForGuard = true,
    escape = "Best",
    halloween = true,
    guardWait = 45,
    guardMargin = 2,
    maxEscape = 70,
    betterOnly = false,
    nights = true,
    idle = "Train on the treadmill",
    trainOnly = false,
    place = true,
    hatch = true,
    equip = true,
    sell = false,
    keepSpare = 5,
    buyStamina = true,
    buyTreadmill = true,
    buyBase = true,
    reserve = 0,
    rebirth = true,
    multipliers = true,
    rewards = true,
    candyEggs = true,
    antiAfk = true,
}

local farm = {enabled = false, run = 0, status = "off"}
local stats = {started = os.clock(), taken = 0, lost = 0, placed = 0, hatched = 0, sold = 0, bought = 0, rebirths = 0,
    candy = 0, candyEggs = 0, best = nil, bestValue = 0, cashStart = nil}

local logLines = {}
local lastLog, lastLogAt = nil, 0
local function log(msg)

    if msg == lastLog and os.clock() - lastLogAt < 60 then return end
    lastLog, lastLogAt = msg, os.clock()
    table.insert(logLines, 1, os.date("%H:%M:%S") .. "  " .. msg)
    if #logLines > 80 then table.remove(logLines) end
end

local function data(key)
    if not Data then return nil end
    local okd, v = pcall(Data.GetValue, Data, key)
    if okd then return v end
end

local function count(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

local SUFFIX = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
local function short(n)
    n = tonumber(n) or 0
    local i = 1
    while math.abs(n) >= 1000 and i < #SUFFIX do
        n = n / 1000
        i = i + 1
    end
    if i == 1 then return tostring(math.floor(n + 0.5)) end
    return (string.format("%.2f", n):gsub("%.?0+$", "")) .. SUFFIX[i]
end

local function call(service, method, ...)
    local s = svc[service]
    if not s or type(s[method]) ~= "function" then return nil, service .. "." .. method .. " is missing" end
    local args = table.pack(...)
    local okc, done, res = pcall(function()
        return s[method](s, table.unpack(args, 1, args.n)):await()
    end)
    if not okc then return nil, tostring(done) end
    if not done then return nil, tostring(res) end
    return res
end

local function reasonOf(res, err)
    if type(res) == "table" and res.Reason then return tostring(res.Reason) end
    return tostring(err or "refused")
end

local variantMult = {}
for _, v in pairs(eggConfig.Variants or {}) do
    if type(v) == "table" and v.Name then variantMult[v.Name] = tonumber(v.CashMultiplier) or 1 end
end

local function animalFor(eggName)
    local e = eggConfig.Eggs and eggConfig.Eggs[eggName]
    return (e and e.Animal) or eggName
end

local function animalValue(name, variant)
    local a = animalConfig[name]
    local cps = a and tonumber(a.CashPerSecond) or 0
    return cps * (variantMult[variant or "Normal"] or 1)
end

local function rarityOf(eggName)
    local e = eggConfig.Eggs and eggConfig.Eggs[eggName]
    return (e and e.Rarity) or "?"
end

local function eggLabel(eggName, variant)
    local name = tostring(eggName)
    if variant and variant ~= "Normal" then name = variant .. " " .. name end
    return name .. " (" .. rarityOf(eggName) .. ")"
end

local function animals()
    local inv, eq = data("Inventory") or {}, data("EquippedAnimals") or {}
    local list = {}
    for key, item in pairs(inv) do
        if type(item) == "table" and item.Handler == "Animal" then
            local variant = (type(item.CustomData) == "table" and item.CustomData.Variant) or item.Variant or "Normal"
            table.insert(list, {key = key, name = item.Name, variant = variant,
                value = animalValue(item.Name, variant), equipped = eq[key] ~= nil})
        end
    end
    return list
end

local function worstOnBase()
    local maxAnimals = tonumber(data("MaxAnimals")) or 7
    local n, worst = 0, math.huge
    for _, a in ipairs(animals()) do
        if a.equipped then
            n = n + 1
            worst = math.min(worst, a.value)
        end
    end
    if n < maxAnimals then return 0 end
    return worst
end

local function getChar()
    local c = plr.Character
    if not c then return nil end
    local h = c:FindFirstChildOfClass("Humanoid")
    local r = c:FindFirstChild("HumanoidRootPart")
    if h and r and h.Health > 0 then return c, h, r end
    return nil
end

local function flat(v)
    return Vector3.new(v.X, 0, v.Z)
end

local function steer(dir)
    dir = flat(dir)
    if dir.Magnitude < 0.001 then
        pcall(function() MoveAction:Fire(Vector2.zero) end)
        return
    end
    dir = dir.Unit
    local cam = workspace.CurrentCamera
    local look = flat(cam.CFrame.LookVector)
    local right = flat(cam.CFrame.RightVector)
    if look.Magnitude < 0.001 or right.Magnitude < 0.001 then
        look, right = Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)
    end
    look, right = look.Unit, right.Unit
    local x, y = dir:Dot(right), dir:Dot(look)
    pcall(function() MoveAction:Fire(Vector2.new(x, y)) end)
end

local function hold(x, y)
    pcall(function() MoveAction:Fire(Vector2.new(x, y)) end)
end

local function stopMoving()
    pcall(function() MoveAction:Fire(Vector2.zero) end)
end

local function tapJump()
    pcall(function() JumpAction:Fire(true) end)
    task.wait(0.1)
    pcall(function() JumpAction:Fire(false) end)
end

local function running(id)
    return alive and farm.enabled and farm.run == id
end

local function status(s)
    farm.status = s
end

local function walkTo(id, point, radius, limit)
    radius = radius or 2.5
    limit = limit or 20
    local started, lastPos, lastMove = os.clock(), nil, os.clock()
    while running(id) do
        local c, h, r = getChar()
        if not c then
            stopMoving()
            return false, "died"
        end
        local gap = flat(point - r.Position)
        if gap.Magnitude <= radius then
            stopMoving()
            return true
        end
        if h:GetState() == Enum.HumanoidStateType.Climbing then
            stopMoving()
            return false, "grabbed the wall"
        end
        if os.clock() - started > limit then
            stopMoving()
            return false, "took too long"
        end
        steer(gap)
        if not lastPos or (r.Position - lastPos).Magnitude > 1.5 then
            lastPos, lastMove = r.Position, os.clock()
        elseif os.clock() - lastMove > 1.2 then
            tapJump()
            lastMove = os.clock()
        end
        RunService.Heartbeat:Wait()
    end
    stopMoving()
    return false, "stopped"
end

local function myBase()
    if not Bases then return nil end
    local okb, b = pcall(Bases.GetBase, Bases)
    if okb then return b end
end

local function plotBox()
    local b = myBase()
    local fences = b and b:FindFirstChild("Fences")
    if not fences then return nil end
    local okp, cf, size = pcall(function() return fences:GetBoundingBox() end)
    if okp then return cf, size end
end

local function insidePlot(pos)
    local cf, size = plotBox()
    if not cf then return false end
    local p = cf:PointToObjectSpace(pos)
    return math.abs(p.X) < size.X / 2 + 1 and math.abs(p.Z) < size.Z / 2 + 1
end

local function gatePoints()
    local b = myBase()
    local gate = b and b:FindFirstChild("Gate")
    local cf = plotBox()
    if not gate or not cf then return nil end
    local g = gate:GetPivot().Position
    local out = flat(g - cf.Position)
    if out.Magnitude < 0.1 then return nil end
    out = out.Unit
    return g - out * 5, g + out * 6
end

local function travel(id, point, radius, limit)
    local c, _, r = getChar()
    if not c then return false, "died" end
    local fromInside, toInside = insidePlot(r.Position), insidePlot(point)
    if fromInside ~= toInside then
        local inner, outer = gatePoints()
        if inner then
            local first, second = outer, inner
            if fromInside then first, second = inner, outer end
            local okw, why = walkTo(id, first, 3, 15)
            if not okw and why ~= "took too long" then return false, why end
            okw, why = walkTo(id, second, 3, 10)
            if not okw and why ~= "took too long" then return false, why end
        end
    end
    return walkTo(id, point, radius, limit)
end

local function wallNear(folder, near, fallback)
    local minZ, maxZ, sumX, n, top = math.huge, -math.huge, 0, 0, -math.huge
    if folder then
        for _, d in ipairs(folder:GetDescendants()) do
            if d:IsA("TrussPart") and math.abs(d.Position.X - near.X) < 6 and math.abs(d.Position.Z - near.Z) < 60 then
                top = math.max(top, d.Position.Y + d.Size.Y / 2)
                if d.Position.Y < near.Y + 120 then
                    minZ = math.min(minZ, d.Position.Z - d.Size.Z / 2)
                    maxZ = math.max(maxZ, d.Position.Z + d.Size.Z / 2)
                    sumX = sumX + d.Position.X
                    n = n + 1
                end
            end
        end
    end
    if n == 0 then return fallback.wallX, fallback.minZ, fallback.maxZ, math.huge end
    return sumX / n, minZ, maxZ, top
end

local towers = {}
do
    local parts = workspace:FindFirstChild("TutorialParts")
    local padPart = parts and parts:FindFirstChild("Climb")
    local pad = padPart and padPart.Position or Vector3.new(2211.6, 74.3, -751.6)
    local wallX, minZ, maxZ, top = wallNear(workspace:FindFirstChild("Structures"), pad, {wallX = 2210.07, minZ = -774.1, maxZ = -726.1})
    local nx = pad.X >= wallX and 1 or -1
    towers.main = {name = "main", pad = pad, wallX = wallX, nx = nx, minZ = minZ, maxZ = maxZ, midZ = (minZ + maxZ) / 2, top = top}

    local dimension = workspace:FindFirstChild("HalloweenDimension")
    if dimension then
        local zones = getController("ZoneController")
        local start = zones and typeof(zones.DimensionLadderStart) == "Vector3" and zones.DimensionLadderStart
            or Vector3.new(2210.17, 73.74, 4553.02)
        local dx, dmin, dmax, dtop = wallNear(dimension, start, {wallX = 2210.17, minZ = 4526, maxZ = 4580})

        towers.halloween = {name = "halloween", pad = Vector3.new(dx + nx * 1.5, start.Y, start.Z), wallX = dx, nx = nx,
            minZ = dmin, maxZ = dmax, midZ = (dmin + dmax) / 2, top = dtop}
    end
end

local tower = towers.main
local function useWorld(name)
    tower = towers[name] or towers.main
end

local BIOMES = {}
for name, z in pairs(zoneConfig) do
    if name ~= "Lobby" and type(z) == "table" and type(z.Height) == "number" then
        BIOMES[name] = {world = "main", height = z.Height}
    end
end
if towers.halloween then
    local islands = workspace.HalloweenDimension:FindFirstChild("Islands")
    for _, name in ipairs({"Pumpkin Abyss", "Bone Field", "Witches Castle"}) do
        local isl = islands and islands:FindFirstChild(name)
        local area = isl and isl:FindFirstChild("Area")
        if area and area:IsA("BasePart") then BIOMES[name] = {world = "halloween", height = area.Position.Y} end
    end
end

local function sidePoints(low)
    local z = low and (tower.minZ - 8) or (tower.maxZ + 8)
    local shaftZ = low and (tower.minZ + 6) or (tower.maxZ - 6)
    return {
        outer = Vector3.new(tower.wallX + tower.nx * 6, 0, z),
        corner = Vector3.new(tower.wallX - tower.nx * 4, 0, z),
        shaft = Vector3.new(tower.wallX + tower.nx * 14, 0, shaftZ),
    }
end

local floorCache = {}
local function floorOf(biome)
    if floorCache[biome] then return floorCache[biome] end
    local info = BIOMES[biome]
    local t = info and towers[info.world]
    if not t then return nil end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = plr.Character and {plr.Character} or {}

    local origin = Vector3.new(t.wallX + t.nx * 3, info.height + 40, t.minZ - 8)
    for _ = 1, 10 do
        local hit = workspace:Raycast(origin, Vector3.new(0, -140, 0), params)
        if not hit then break end
        if hit.Instance:IsA("TrussPart") or not hit.Instance.CanCollide then
            origin = hit.Position - Vector3.new(0, 0.05, 0)
        else
            floorCache[biome] = hit.Position.Y
            return hit.Position.Y
        end
    end
    return nil
end

local gateLevel = {Forest = 0}
for _, g in ipairs(staminaUpgradeConfig.BiomeGates or {}) do
    if type(g) == "table" and g.Name then gateLevel[g.Name] = tonumber(g.Level) or math.huge end
end

local portalConfig = require(config.Gameplay.portalConfig)
local function halloweenOpen()
    if not towers.halloween or rs:GetAttribute(portalConfig.OpenAttribute or "HalloweenPortalOpen") ~= true then return false end
    local unlock = getController("HalloweenUnlockController")
    if unlock and type(unlock.IsUnlocked) == "function" then
        local oku, yes = pcall(unlock.IsUnlocked, unlock)
        if oku then return yes == true end
    end
    return (tonumber(data("Speed")) or 0) >= (tonumber(portalConfig.UnlockSpeed) or math.huge)
end

local function isTop(biome)
    local info = BIOMES[biome]
    local t = info and towers[info.world]
    local floor = floorOf(biome)
    return t ~= nil and floor ~= nil and t.top ~= nil and floor + 10 > t.top
end

local function topFloor(floorY)
    return tower.top ~= nil and floorY + 10 > tower.top
end

local function topDrop(from)
    return Vector3.new(tower.wallX + tower.nx * 6, 0, math.clamp(from.Z, tower.minZ + 4, tower.maxZ - 4))
end

local function reachable(biome)
    local info = BIOMES[biome]
    if not info then return false end

    if settings.onlyWorld and info.world ~= settings.onlyWorld then return false end
    if settings.onlyBiome and biome ~= settings.onlyBiome then return false end

    if isTop(biome) and info.world ~= "main" then return false end
    local level = tonumber(data("StaminaLevel")) or 1
    if info.world == "halloween" then
        if not settings.halloween or not halloweenOpen() then return false end

        local okh, reach = pcall(staminaUpgradeConfig.GetReachHeight, level)
        return okh and tonumber(reach) ~= nil and info.height <= reach
    end
    local need = gateLevel[biome]
    return need ~= nil and level >= need
end

local function worldAt(pos)
    if towers.halloween and math.abs(pos.Z - towers.halloween.pad.Z) < math.abs(pos.Z - towers.main.pad.Z) then
        return "halloween"
    end
    return "main"
end

local function currentWorld()
    local c = plr.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    return r and worldAt(r.Position) or "main"
end

local function nightState()
    local t = workspace:GetServerTimeNow()
    local okn, isNight = pcall(dayCycle.IsNight, t)
    local okt, nightAt = pcall(dayCycle.GetNightStartsAt, t)
    local okd, dayAt = pcall(dayCycle.GetDayStartsAt, t)
    return okn and isNight == true, okt and (nightAt - t) or math.huge, okd and (dayAt - t) or 0
end

local climbRatio = 0.7
local function climbWalkSpeed()
    local okw, ws = pcall(speedCurve.ToWalkSpeed, tonumber(data("Speed")) or 250)
    ws = okw and tonumber(ws) or 22
    if Jetpack then
        local okj, m = pcall(Jetpack.GetSpeedMultiplier, Jetpack)
        if okj and tonumber(m) then ws = ws * m end
    end
    return math.max(ws, 1)
end

local function tripTime(biome)
    local info = BIOMES[biome]
    local t = towers[info and info.world or "main"] or towers.main
    local floor = floorOf(biome) or t.pad.Y
    local _, _, r = getChar()
    local walk = 8
    if r then

        walk = worldAt(r.Position) == t.name and flat(t.pad - r.Position).Magnitude / 26 or 15
    end
    local climb = math.max(0, floor + 8 - t.pad.Y - (staminaUpgradeConfig.ClimbBoostHeight or 125))
    local fall = math.sqrt(2 * math.max(floor - t.pad.Y, 0) / workspace.Gravity)
    return walk + 2 + climb / (climbWalkSpeed() * climbRatio) + 16 + fall + 3
end

local CHASE = tonumber(guardConfig.ChaseSpeed) or 18
local REPATH = tonumber(guardConfig.ChaseRepathInterval) or 0.2

local PATROL = 12

local BODY = 1.5

local function carrySpeed()
    local okc, v = pcall(function() return SpeedState.StateFunctions.Stealing() end)
    v = okc and tonumber(v)
    return (v and v > 0) and v or 10
end

local function guardZone(biome)
    local okf, isl = pcall(guardGeometry.FindIsland, biome)
    local area = okf and isl and isl:FindFirstChild("Area")
    if area and area:IsA("BasePart") then return area end
end

local function guardsJailed()
    return workspace:GetServerTimeNow() < (tonumber(workspace:GetAttribute("GuardsJailedUntil")) or 0)
end

local reachCache = setmetatable({}, {__mode = "k"})
local function hitboxReach(box, pivot)
    if not box or not box.Parent then return 10 end
    if reachCache[box] then return reachCache[box] end
    local reach = 0
    for _, sx in ipairs({-1, 1}) do
        for _, sz in ipairs({-1, 1}) do
            local corner = box.CFrame:PointToWorldSpace(Vector3.new(sx * box.Size.X / 2, 0, sz * box.Size.Z / 2))
            reach = math.max(reach, flat(corner - pivot).Magnitude)
        end
    end
    reachCache[box] = reach
    return reach
end

local function guardsNear(floorY)
    local list = {}
    local now = os.clock()
    if GuardAi and type(GuardAi.Guards) == "table" then
        for _, g in pairs(GuardAi.Guards) do
            local okp, pos = pcall(function() return g.Pose.Value end)
            if okp and typeof(pos) == "Vector3" and g.Model and g.Model.Parent and math.abs(pos.Y - floorY) < 30 then
                local info = {pos = flat(pos), reach = hitboxReach(g.Hitbox, pos), state = g.State,
                    left = (tonumber(g.NextAction) or now) - now}
                if g.State == "Walk" and typeof(g.FacingPosition) == "Vector3" then
                    info.target = flat(g.FacingPosition)
                    info.speed = (info.target - info.pos).Magnitude / math.max(info.left, 0.05)
                end
                table.insert(list, info)
            end
        end
    end

    local dimension = workspace:FindFirstChild("HalloweenDimension")
    local monsters = dimension and dimension:FindFirstChild("ActiveMiniMonsters")
    if monsters then
        local serverNow = workspace:GetServerTimeNow()
        for _, m in ipairs(monsters:GetChildren()) do
            local okp, cf = pcall(function() return m:GetPivot() end)
            if okp and m:IsA("Model") and math.abs(cf.Position.Y - floorY) < 30 and not m:GetAttribute("Boss") then
                local to, from = m:GetAttribute("MoveTo"), m:GetAttribute("MoveFrom")
                local duration = tonumber(m:GetAttribute("MoveDuration")) or 0
                local info = {pos = flat(cf.Position), reach = 5, state = "Idle", left = 0, chase = 8}
                if typeof(to) == "Vector3" and typeof(from) == "Vector3" and duration > 0 then
                    local speed = flat(to - from).Magnitude / duration
                    info.state, info.target, info.speed = "Walk", flat(to), speed
                    info.left = (tonumber(m:GetAttribute("MoveStart")) or serverNow) + duration - serverNow
                    info.chase = math.max(speed, 8)
                end
                table.insert(list, info)
            end
        end
    end
    if GuardAi and type(GuardAi.Guards) == "table" then return list end

    local folder = workspace:FindFirstChild("LocalGuards")
    if not folder then return list end
    for _, m in ipairs(folder:GetChildren()) do
        local okp, cf = pcall(function() return m:GetPivot() end)
        if okp and math.abs(cf.Position.Y - floorY) < 30 then
            table.insert(list, {pos = flat(cf.Position), reach = hitboxReach(m:FindFirstChild("Hitbox", true), cf.Position),
                state = "?", left = 0})
        end
    end
    return list
end

local function inZone(area, p)
    local q = area.CFrame:PointToObjectSpace(Vector3.new(p.X, area.Position.Y, p.Z))
    return math.abs(q.X) <= area.Size.X / 2 and math.abs(q.Z) <= area.Size.Z / 2
end

local function clampToZone(area, p)
    local q = area.CFrame:PointToObjectSpace(Vector3.new(p.X, area.Position.Y, p.Z))
    local hx, hz = area.Size.X / 2, area.Size.Z / 2
    local w = area.CFrame:PointToWorldSpace(Vector3.new(math.clamp(q.X, -hx, hx), 0, math.clamp(q.Z, -hz, hz)))
    return Vector3.new(w.X, 0, w.Z)
end

local function escapeRoute(from, low)
    local side = sidePoints(low)
    return {flat(from), side.corner, side.outer}
end

local function routeLength(route)
    local n = 0
    for i = 2, #route do n = n + (route[i] - route[i - 1]).Magnitude end
    return n
end

local function closestApproach(route, area, guard, hold, startStay, endStay)
    local speed = carrySpeed()
    local me, g = route[1], guard.pos
    local seg, t, dt = 2, 0, 0.05
    local nextRepath, target = hold, nil
    local walkFrom = hold + (startStay or 0)
    local stayUntil = nil
    local closest = (g - me).Magnitude - guard.reach - BODY
    for _ = 1, 1200 do
        t = t + dt
        if t <= hold then
            if guard.state == "Walk" and guard.target then

                if t < guard.left then
                    local d = guard.target - g
                    local step = guard.speed * dt
                    if d.Magnitude <= step then g = guard.target else g = g + d.Unit * step end
                end
            elseif guard.state ~= "Idle" or t >= guard.left then

                local d = me - g
                if d.Magnitude > 0.5 then g = g + d.Unit * math.min(PATROL * dt, d.Magnitude) end
            end
        else
            local move = t > walkFrom and speed * dt or 0
            while move > 0 and seg <= #route do
                local d = route[seg] - me
                if d.Magnitude <= move then
                    me = route[seg]
                    move = move - d.Magnitude
                    seg = seg + 1
                else
                    me = me + d.Unit * move
                    move = 0
                end
            end
            if not inZone(area, me) then return closest end
            if seg > #route then
                stayUntil = stayUntil or (t + (endStay or 0))
                if t >= stayUntil then return closest end
            end
            if t >= nextRepath then
                target = clampToZone(area, me)
                nextRepath = t + REPATH
            end
            local d = target - g
            local step = (guard.chase or CHASE) * dt
            if d.Magnitude <= step then g = target else g = g + d.Unit * step end
            closest = math.min(closest, (g - me).Magnitude - guard.reach - BODY)
        end
    end
    return closest
end

local function backFacePoint(pos)

    return Vector3.new(tower.wallX - tower.nx * 2.3, 0, math.clamp(pos.Z, tower.minZ + 2, tower.maxZ - 2))
end

local function wallClimbTime()
    return 0.5 + 20 / math.max(climbWalkSpeed() * climbRatio, 8)
end

local REACT = 0.15

local function escapePlan(from, biome, floorY, hold)
    local area = guardZone(biome)
    local guards = (area and not guardsJailed()) and guardsNear(floorY) or {}
    local options = {}
    local top = isTop(biome)
    if top then

        local route = {flat(from), topDrop(from)}
        table.insert(options, {route = route, top = true, length = routeLength(route), stay = 0.5})
    end
    if not top and settings.escape ~= "Up the wall" then
        for _, low in ipairs({true, false}) do
            local route = escapeRoute(from, low)
            table.insert(options, {route = route, low = low, length = routeLength(route)})
        end
    end
    if not top and settings.escape ~= "Round the wall" then
        local route = {flat(from), backFacePoint(from)}
        table.insert(options, {route = route, wall = true, length = routeLength(route), stay = wallClimbTime()})
    end
    local best
    for _, plan in ipairs(options) do
        plan.margin = math.huge
        for _, g in ipairs(guards) do
            plan.margin = math.min(plan.margin, closestApproach(plan.route, area, g, hold, REACT, plan.stay))
        end
        if not best or plan.margin > best.margin or (plan.margin == best.margin and plan.length < best.length) then
            best = plan
        end
    end
    return best.margin > settings.guardMargin, best
end

local function dropPlan(biome, floorY)
    local area = guardZone(biome)
    local guards = (area and not guardsJailed()) and guardsNear(floorY) or {}
    local best
    for _, low in ipairs({true, false}) do
        local land = Vector3.new(tower.wallX - tower.nx * 1.5, 0, low and (tower.minZ - 1.5) or (tower.maxZ + 1.5))
        local route = {land, sidePoints(low).outer}
        local margin = math.huge
        for _, g in ipairs(guards) do
            margin = math.min(margin, closestApproach(route, area, g, 0, 0.6, 0))
        end
        if not best or margin > best.margin then best = {low = low, margin = margin} end
    end
    return best.margin > settings.guardMargin + 2, best
end

local function escapeLength(pos)
    return math.min(routeLength(escapeRoute(pos, true)), routeLength(escapeRoute(pos, false)))
end

local function eggsIn(biome)
    local folder = workspace:FindFirstChild("SpawnedEggs")
    folder = folder and folder:FindFirstChild(biome)
    local list = {}
    local info = BIOMES[biome]
    if not folder or not info then return list end

    local current = tower
    tower = towers[info.world] or towers.main
    local top = isTop(biome)
    for _, m in ipairs(folder:GetChildren()) do
        local eggName = m:GetAttribute("EggName")
        local prompt = eggName and m:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and prompt.Enabled then
            local variant = m:GetAttribute("Variant") or "Normal"
            local pos = m:GetPivot().Position
            table.insert(list, {model = m, prompt = prompt, biome = biome, name = eggName, variant = variant,
                value = animalValue(animalFor(eggName), variant), pos = pos,
                escape = top and flat(topDrop(pos) - pos).Magnitude or escapeLength(pos)})
        end
    end
    tower = current
    return list
end

local biomeRest = {}

local function bestEgg(onlyBiome, anyTime, skipModels)
    local least = settings.betterOnly and worstOnBase() or -1
    local isNight, toNight = nightState()
    local timeCheck = settings.nights and not anyTime
    local best, nightBlocked = nil, false
    for biome in pairs(BIOMES) do
        local resting = not onlyBiome and os.clock() < (biomeRest[biome] or 0)
        if (not onlyBiome or biome == onlyBiome) and not resting and reachable(biome) and floorOf(biome) then
            local trip = tripTime(biome) + (settings.waitForGuard and 6 or 0)
            local tooLate = timeCheck and (isNight or trip + 4 > toNight)
            for _, e in ipairs(eggsIn(biome)) do
                local skip = e.value <= least or (skipModels ~= nil and skipModels[e.model] == true)

                if settings.waitForGuard and e.escape > settings.maxEscape then skip = true end
                if not skip and tooLate then
                    skip = true
                    nightBlocked = true
                end
                if not skip then

                    e.trip = trip + (settings.waitForGuard and math.max(0, e.escape - 35) * 0.8 or 0)
                    if settings.pick == "Most cash per minute" then
                        e.score = e.value / trip
                    else
                        e.score = e.value
                    end
                    if not best or e.score > best.score or (e.score == best.score and trip < best.trip) then
                        best = e
                    end
                end
            end
        end
    end
    return best, nightBlocked
end

local function eggsOwned()
    local n = count(data("PlacedEggs"))
    for _, item in pairs(data("Inventory") or {}) do
        if type(item) == "table" and item.Handler == "Egg" then n = n + 1 end
    end
    return n
end

local lastStun, lastCaught = 0, 0
local function dropReason()
    if os.clock() - lastStun < 6 then return "a guard caught you" end
    if os.clock() - lastCaught < 6 then return "caught at night" end
    return "dropped it"
end

local function carrying()
    return plr:GetAttribute("CarryingEgg") ~= nil
end

local function onTreadmill()
    return Treadmill ~= nil and Treadmill.OnTreadmill == true
end

local function treadmillPart()
    local b = myBase()
    local folder = b and b:FindFirstChild("Treadmill")
    local m = folder and folder:FindFirstChildWhichIsA("Model")
    return m and (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true))
end

local function leaveTreadmill()
    if onTreadmill() then
        pcall(function() Treadmill:DeactivateTreadmill() end)
        task.wait(0.4)
    end
end

local function goToWorld(id, world)
    if currentWorld() == world then
        useWorld(world)
        return true
    end
    leaveTreadmill()
    local dimension = workspace:FindFirstChild("HalloweenDimension")
    local portals = dimension and dimension:FindFirstChild("Portals")
    local route = world == "halloween" and "LobbyToHalloween" or "HalloweenToLobby"
    local model = portals and portals:FindFirstChild(route)
    local trigger = model and model:FindFirstChild("Trigger")
    if not trigger then return false, "couldn't find the portal" end
    status(world == "halloween" and "walking into the halloween portal" or "walking back through the portal")

    local front = model:FindFirstChild("OutPos")
    if front and front:IsA("BasePart") then
        travel(id, front.Position, 3, 40)
    else
        travel(id, trigger.Position, 2, 40)
    end

    local t = os.clock()
    while running(id) and currentWorld() ~= world and os.clock() - t < 12 do
        local c, _, r = getChar()
        if c then steer(trigger.Position - r.Position) end
        RunService.Heartbeat:Wait()
    end
    stopMoving()
    if currentWorld() ~= world then return false, "the portal didn't take you through" end
    useWorld(world)

    task.wait(1.5)
    return true
end

local function train(id, done)
    local part = treadmillPart()
    if not part then return false, "no treadmill yet" end
    if not onTreadmill() then
        local home, why = goToWorld(id, "main")
        if not home then return false, why end
        status("walking to the treadmill")
        travel(id, part.Position, 1.5, 30)
        local t = os.clock()
        while running(id) and not onTreadmill() and os.clock() - t < 3 do
            local c, _, r = getChar()
            if c then steer(part.Position - r.Position) end
            RunService.Heartbeat:Wait()
        end
        stopMoving()
        if not onTreadmill() then return false, "couldn't get on the treadmill" end
        log("training on the treadmill")
    end
    while running(id) and onTreadmill() and not done() do
        status("training speed (" .. short(data("Speed")) .. ")")
        task.wait(0.5)
    end
    return true
end

local function faceWall(r)
    local n = Vector3.new(tower.nx, 0, 0)
    local p = r.Position
    workspace.CurrentCamera.CFrame = CFrame.lookAt(p + n * 12 + Vector3.new(0, 3, 0), p - n * 4)
end

local function climbTo(id, height)
    local okw, why = travel(id, tower.pad, 3, 30)
    if not okw and why ~= "grabbed the wall" then return false, why end
    local started = os.clock()
    while running(id) do
        local c, h = getChar()
        if not c then return false, "died" end
        if h:GetState() == Enum.HumanoidStateType.Climbing then break end
        if os.clock() - started > 6 then
            stopMoving()
            return false, "couldn't grab the wall"
        end
        steer(Vector3.new(-tower.nx, 0, 0))
        RunService.Heartbeat:Wait()
    end
    local lastY, lastProgress, offWallSince = nil, os.clock(), nil
    local measureFrom, measureAt = nil, nil
    while running(id) do
        local c, h, r = getChar()
        if not c then
            stopMoving()
            return false, "died"
        end
        local y = r.Position.Y
        if y >= height then
            stopMoving()
            if measureFrom and os.clock() - measureAt > 1 then
                local rate = (y - measureFrom) / (os.clock() - measureAt)
                climbRatio = math.clamp(rate / climbWalkSpeed(), 0.2, 1.5)
            end
            return true
        end
        if h:GetState() ~= Enum.HumanoidStateType.Climbing then
            offWallSince = offWallSince or os.clock()
            if os.clock() - offWallSince > 1 then
                stopMoving()
                return false, "fell off the wall"
            end
        else
            offWallSince = nil
        end

        if not measureFrom and y > tower.pad.Y + (staminaUpgradeConfig.ClimbBoostHeight or 125) + 10 then
            measureFrom, measureAt = y, os.clock()
        end
        faceWall(r)
        hold(0, 1)
        if not lastY or y > lastY + 0.5 then
            lastY, lastProgress = y, os.clock()
        elseif os.clock() - lastProgress > 4 then
            stopMoving()
            return false, "stuck on the wall"
        end
        status(string.format("climbing, %d / %d", math.floor(y), math.floor(height)))
        RunService.Heartbeat:Wait()
    end
    stopMoving()
    return false, "stopped"
end

local function stepOff(id, floorY)
    for _, dir in ipairs({1, -1}) do
        local started = os.clock()
        while running(id) do
            local c, h = getChar()
            if not c or h:GetState() ~= Enum.HumanoidStateType.Climbing then break end
            if os.clock() - started > 7 then break end
            hold(dir, 0)
            RunService.Heartbeat:Wait()
        end
        stopMoving()
        local c, h = getChar()
        if not c or h:GetState() ~= Enum.HumanoidStateType.Climbing then break end
    end
    local started = os.clock()
    while running(id) do
        local c, h, r = getChar()
        if not c then return false end
        if h.FloorMaterial ~= Enum.Material.Air and h:GetState() ~= Enum.HumanoidStateType.Climbing then
            return math.abs(r.Position.Y - floorY) < 9, r
        end
        if os.clock() - started > 5 then return false end
        RunService.Heartbeat:Wait()
    end
    return false
end

local function climbOver(id, floorY)
    local started = os.clock()
    while running(id) do
        local c, h, r = getChar()
        if not c then break end
        if h:GetState() ~= Enum.HumanoidStateType.Climbing and h.FloorMaterial ~= Enum.Material.Air
            and r.Position.Y > floorY - 1 then
            stopMoving()
            return true
        end
        if os.clock() - started > 8 then break end
        faceWall(r)
        hold(0, 1)
        RunService.Heartbeat:Wait()
    end
    stopMoving()
    return false
end

local function islandWalk(id, point, floorY, radius, limit)
    for _ = 1, 3 do
        local okw, why = walkTo(id, point, radius, limit)
        if okw or why ~= "grabbed the wall" then return okw, why end
        tapJump()
        local t = os.clock()
        while running(id) and os.clock() - t < 3 do
            local c, h = getChar()
            if not c then return false, "died" end
            if h.FloorMaterial ~= Enum.Material.Air and h:GetState() ~= Enum.HumanoidStateType.Climbing then break end
            RunService.Heartbeat:Wait()
        end
        local c, _, r = getChar()
        if not c or r.Position.Y < floorY - 6 then return false, "fell off the island" end
    end
    return false, "kept grabbing the wall"
end

local function dropDown(id, floorY, low)
    local side = sidePoints(low)
    local c, _, r = getChar()
    local drop = side.shaft
    if c and topFloor(floorY) then

        drop = topDrop(r.Position)
        islandWalk(id, Vector3.new(tower.wallX - tower.nx * 3, 0, drop.Z), floorY, 2.5, 15)
    else

        if c and tower.nx * (r.Position.X - tower.wallX) < 0 then
            islandWalk(id, side.corner, floorY, 2.5, 12)
        end
        islandWalk(id, side.outer, floorY, 3, 8)
    end
    local t = os.clock()
    while running(id) do
        local c, _, r = getChar()
        if not c then return false, "died" end
        if r.Position.Y < floorY - 8 then break end
        if os.clock() - t > 8 then
            stopMoving()
            return false, "couldn't find the drop"
        end
        steer(drop - r.Position)
        RunService.Heartbeat:Wait()
    end
    stopMoving()
    local limit = math.sqrt(2 * math.max(floorY - tower.pad.Y, 0) / workspace.Gravity) + 8
    t = os.clock()
    while running(id) do
        local c, h, r = getChar()
        if not c then return false, "died" end
        if r.Position.Y < tower.pad.Y + 30 and h.FloorMaterial ~= Enum.Material.Air then return true end
        if os.clock() - t > limit then return false, "still falling" end
        RunService.Heartbeat:Wait()
    end
    return false, "stopped"
end

local function getDown(id)
    useWorld(currentWorld())

    local function islandFloor(y)
        local nearestY
        for biome, info in pairs(BIOMES) do
            local f = info.world == tower.name and floorOf(biome)
            if f and math.abs(f - y) < 15 and (not nearestY or math.abs(f - y) < math.abs(nearestY - y)) then nearestY = f end
        end
        return nearestY
    end
    for _ = 1, 3 do
        local c, h, r = getChar()
        if not c then return false, "died" end
        local climbing = h:GetState() == Enum.HumanoidStateType.Climbing
        local floorY = islandFloor(r.Position.Y)
        if not climbing and not floorY and r.Position.Y < tower.pad.Y + 120 then return true end
        status("getting back down to the lobby")
        if climbing or not floorY then
            tapJump()
        else
            dropDown(id, floorY, r.Position.Z < tower.midZ)
        end
        local t = os.clock()
        while running(id) and os.clock() - t < 12 do
            local c2, h2 = getChar()
            if not c2 then return false, "died" end
            if h2.FloorMaterial ~= Enum.Material.Air and h2:GetState() ~= Enum.HumanoidStateType.Climbing then break end
            RunService.Heartbeat:Wait()
        end
        if not running(id) then return false, "stopped" end
    end
    local _, _, r = getChar()
    if not r then return false, "died" end
    return islandFloor(r.Position.Y) == nil, "stuck up on an island"
end

local function wallEscape(id, biome, floorY, plan)
    local n = Vector3.new(tower.nx, 0, 0)
    local function faceBack(r)
        workspace.CurrentCamera.CFrame = CFrame.lookAt(r.Position - n * 12 + Vector3.new(0, 3, 0), r.Position + n * 4)
    end
    local spot = plan.route[2]
    local t = os.clock()
    while running(id) do
        local c, h, r = getChar()
        if not c then return false, "died" end
        if h:GetState() == Enum.HumanoidStateType.Climbing then break end
        if os.clock() - t > 8 then
            log("couldn't get onto the back of the wall, running for it")
            return dropDown(id, floorY, r.Position.Z < tower.midZ)
        end
        local to = flat(spot - r.Position)
        if to.Magnitude > 1.5 then steer(to) else steer(n) end
        RunService.Heartbeat:Wait()
    end
    t = os.clock()
    while running(id) do
        local c, h, r = getChar()
        if not c then return false, "died" end
        if h:GetState() ~= Enum.HumanoidStateType.Climbing then
            stopMoving()
            return dropDown(id, floorY, r.Position.Z < tower.midZ)
        end
        if r.Position.Y >= floorY + 30 or os.clock() - t > 6 then break end
        faceBack(r)
        hold(0, 1)
        RunService.Heartbeat:Wait()
    end
    stopMoving()
    if not carrying() then return false, "lost it before getting up the wall" end

    local deadline = os.clock() + 90
    local choice
    while running(id) do
        local c, h = getChar()
        if not c then return false, "died" end
        if h:GetState() ~= Enum.HumanoidStateType.Climbing then break end
        local clear
        clear, choice = dropPlan(biome, floorY)
        local isNight, toNight = nightState()
        if clear or os.clock() > deadline or (settings.nights and (isNight or toNight < 8)) then break end
        status("on the wall with the egg, waiting for the guard to move off")
        hold(0, 0)
        task.wait(0.15)
    end

    local low = choice == nil or choice.low
    local dir = (low and -1 or 1) * tower.nx
    t = os.clock()
    while running(id) do
        local c, h, r = getChar()
        if not c then return false, "died" end
        if h:GetState() ~= Enum.HumanoidStateType.Climbing or os.clock() - t > 8 then break end
        faceBack(r)
        hold(dir, 0)
        RunService.Heartbeat:Wait()
    end
    stopMoving()
    t = os.clock()
    while running(id) do
        local c, h = getChar()
        if not c then return false, "died" end
        if h.FloorMaterial ~= Enum.Material.Air or os.clock() - t > 4 then break end
        RunService.Heartbeat:Wait()
    end
    return dropDown(id, floorY, low)
end

local function grab(egg)
    for _ = 1, 2 do
        if not egg.model.Parent or not egg.prompt.Enabled then return false, "someone else took it" end
        pcall(function() egg.prompt:InputHoldBegin() end)
        task.wait((tonumber(egg.prompt.HoldDuration) or 0.5) + 0.15)
        pcall(function() egg.prompt:InputHoldEnd() end)
        local t = os.clock()
        while os.clock() - t < 2 do
            if carrying() then return true end
            task.wait(0.05)
        end
    end
    return false, "the prompt didn't take"
end

local function waitAndGrab(id, target, biome, floorY, deadline)
    local hold = (tonumber(target.prompt.HoldDuration) or 0.5) + 0.25
    local fall = math.sqrt(2 * math.max(floorY - tower.pad.Y, 0) / workspace.Gravity)
    while running(id) do
        if not target.model.Parent or not target.prompt.Enabled then return "taken" end
        local c, _, r = getChar()
        if not c then return "stop" end
        local safe, plan = escapePlan(r.Position, biome, floorY, hold)
        if safe or not settings.waitForGuard then
            if grab(target) then return "got", plan end
            return "taken"
        end
        if os.clock() > deadline then return "timeout" end
        if settings.nights then
            local isNight, toNight = nightState()
            if isNight or toNight < plan.length / carrySpeed() + fall + 6 then return "night" end
        end
        status(string.format("waiting for the guard to move off (%ds left)", math.max(0, math.ceil(deadline - os.clock()))))
        task.wait(0.15)
    end
    return "stop"
end

local function trip(id, egg)
    local biome = egg.biome
    local floorY = floorOf(biome)
    if not floorY then return false, "couldn't find the " .. biome .. " floor" end
    log("going for " .. eggLabel(egg.name, egg.variant) .. " in " .. biome)
    local there, why = getDown(id)
    if not there then return false, why end
    there, why = goToWorld(id, BIOMES[biome].world)
    if not there then return false, why end
    status("going to " .. biome .. " for " .. eggLabel(egg.name, egg.variant))
    local top = isTop(biome)
    local okc
    okc, why = climbTo(id, top and floorY - 4 or floorY + 7.5)
    if not okc then return false, why end
    local low, okw
    if top then
        if not climbOver(id, floorY) then return false, "couldn't get over the top" end
        local _, _, r = getChar()
        if not r then return false, "died" end
        low = r.Position.Z < tower.midZ
        status("walking to the egg")
    else
        local landed, r = stepOff(id, floorY)
        if not landed then return false, "missed the platform" end
        low = r.Position.Z < tower.midZ
        local side = sidePoints(low)
        status("walking to the egg")
        okw, why = islandWalk(id, side.outer, floorY, 3, 8)
        if okw then okw, why = islandWalk(id, side.corner, floorY, 2.5, 10) end
        if not okw and why ~= "took too long" then return false, why end
    end

    local tried = {}
    local target = egg
    local deadline = os.clock() + settings.guardWait
    local before, plan, result = eggsOwned(), nil, nil
    while running(id) do

        if not target or not target.model.Parent or not target.prompt.Enabled then
            target = bestEgg(biome, true, tried)
            if not target then break end
        end

        local exitLow = routeLength(escapeRoute(target.pos, true)) <= routeLength(escapeRoute(target.pos, false))
        local toward = flat((top and topDrop(target.pos) or sidePoints(exitLow).corner) - target.pos)
        local spot = toward.Magnitude > 0.1 and (flat(target.pos) + toward.Unit * 5) or target.pos
        okw, why = islandWalk(id, spot, floorY, 2, 15)
        local _, _, here = getChar()
        local close = here ~= nil and flat(target.pos - here.Position).Magnitude <= 6
        if not okw and not close then
            if why == "stopped" or why == "died" or why == "fell off the island" then return false, why end
            tried[target.model] = true
            target = nil
        else
            before = eggsOwned()
            result, plan = waitAndGrab(id, target, biome, floorY, deadline)
            if result == "got" or result == "stop" or result == "timeout" or result == "night" then break end
            tried[target.model] = true
            target = nil
        end
    end

    if result == "timeout" and running(id) then
        local least = settings.betterOnly and worstOnBase() or -1
        local spare
        for _, e in ipairs(eggsIn(biome)) do
            if not tried[e.model] and (not target or e.model ~= target.model) and e.value > least then
                local safe, p = escapePlan(e.pos, biome, floorY, 2)
                if safe and p.margin > settings.guardMargin + 4 and (not spare or e.value > spare.value) then
                    spare = e
                end
            end
        end
        if spare then
            log("switching to " .. eggLabel(spare.name, spare.variant) .. ", the guard is away from it")
            if islandWalk(id, spare.pos, floorY, 4, 10) then
                target = spare
                before = eggsOwned()
                result, plan = waitAndGrab(id, spare, biome, floorY, os.clock() + 8)
            end
        end
    end
    if result == "stop" or not running(id) then return false, "stopped" end
    if result ~= "got" then
        if result == "timeout" then
            biomeRest[biome] = os.clock() + 60
            log("the " .. biome .. " guard never gave an opening, trying elsewhere for a minute")
        end
        local c2, _, r2 = getChar()
        dropDown(id, floorY, c2 and r2.Position.Z < tower.midZ or low)
        if result == "night" then return false, "night is close" end
        return false, "no safe moment to grab"
    end

    status("bringing back " .. eggLabel(target.name, target.variant))
    local okd
    if plan.wall then
        log("running for the back of the wall with it")
        okd, why = wallEscape(id, biome, floorY, plan)
    else
        okd, why = dropDown(id, floorY, plan.low)
    end
    if not okd then
        if not carrying() then
            stats.lost = stats.lost + 1
            log("lost the egg: " .. dropReason())
        end
        return false, why
    end

    local t = os.clock()
    while carrying() and os.clock() - t < 6 do task.wait(0.1) end
    task.wait(0.5)
    if eggsOwned() > before then
        stats.taken = stats.taken + 1
        if target.value > stats.bestValue then
            stats.best, stats.bestValue = eggLabel(target.name, target.variant), target.value
        end
        log("got " .. eggLabel(target.name, target.variant) .. ", worth " .. short(target.value) .. "/s")
        return true
    end
    stats.lost = stats.lost + 1
    log("lost the egg: " .. dropReason())
    return false, "egg lost"
end

local CANDY_ISLAND = "Pumpkin Abyss"
local BAT_REACH = 5

local function batTool()
    local c = plr.Character
    local bp = plr:FindFirstChildOfClass("Backpack")
    return (c and c:FindFirstChild("Bat")) or (bp and bp:FindFirstChild("Bat"))
end

local function putAwayBat()
    local _, h = getChar()
    local c = plr.Character
    if h and c and c:FindFirstChild("Bat") then pcall(function() h:UnequipTools() end) end
end

local function monsterPos(m, serverNow)
    local from, to = m:GetAttribute("MoveFrom"), m:GetAttribute("MoveTo")
    local duration = tonumber(m:GetAttribute("MoveDuration")) or 0
    if typeof(from) == "Vector3" and typeof(to) == "Vector3" and duration > 0 then
        local a = math.clamp((serverNow - (tonumber(m:GetAttribute("MoveStart")) or serverNow)) / duration, 0, 1)
        return from:Lerp(to, a)
    end
    return m:GetPivot().Position
end

local function nearestMonster(from)
    local dimension = workspace:FindFirstChild("HalloweenDimension")
    local folder = dimension and dimension:FindFirstChild("ActiveMiniMonsters")
    if not folder then return nil end
    local serverNow = workspace:GetServerTimeNow()
    local best, bestPos, bestGap
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m:GetAttribute("Island") == CANDY_ISLAND and not m:GetAttribute("Boss")
            and not m:GetAttribute("Dying") and not m:GetAttribute("Dead") and (tonumber(m:GetAttribute("Health")) or 0) > 0 then
            local pos = monsterPos(m, serverNow)
            local gap = flat(pos - from).Magnitude
            if not bestGap or gap < bestGap then best, bestPos, bestGap = m, pos, gap end
        end
    end
    return best, bestPos, bestGap
end

local function nearestCandy(from, floorY)
    local folder = workspace:FindFirstChild("CandyDrops")
    if not folder then return nil end
    local best, bestGap
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and math.abs(part.Position.Y - floorY) < 15 then
            local gap = flat(part.Position - from).Magnitude
            if gap < 60 and (not bestGap or gap < bestGap) then best, bestGap = part, gap end
        end
    end
    return best
end

local function playerNear(pos, radius)
    for _, other in ipairs(Players:GetPlayers()) do
        local r = other ~= plr and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
        if r and (r.Position - pos).Magnitude < radius then return true end
    end
    return false
end

local function farmCandy(id, done)
    if not halloweenOpen() then return false, "the event portal is closed" end
    if not BIOMES[CANDY_ISLAND] then return false, "couldn't find " .. CANDY_ISLAND end
    if not batTool() then return false, "no bat" end
    local floorY = floorOf(CANDY_ISLAND)
    if not floorY then return false, "couldn't find the " .. CANDY_ISLAND .. " floor" end
    local c, h, r = getChar()
    if not c then return false, "died" end
    if currentWorld() ~= "halloween" or math.abs(r.Position.Y - floorY) > 8 then
        leaveTreadmill()
        local ok, why = getDown(id)
        if not ok then return false, why end
        ok, why = goToWorld(id, "halloween")
        if not ok then return false, why end
        status("going to " .. CANDY_ISLAND .. " for candy")
        ok, why = climbTo(id, floorY + 7.5)
        if not ok then return false, why end
        local landed, r2 = stepOff(id, floorY)
        if not landed then return false, "missed the platform" end
        local side = sidePoints(r2.Position.Z < tower.midZ)
        islandWalk(id, side.outer, floorY, 3, 8)
        islandWalk(id, side.corner, floorY, 2.5, 10)
        log("hitting monsters on " .. CANDY_ISLAND .. " for candy")
    end
    local lastCandy = tonumber(data("Candy")) or 0
    local nextCheck, nextSwing = 0, 0
    while running(id) do
        if os.clock() >= nextCheck then
            if done() then break end
            nextCheck = os.clock() + 2
        end
        c, h, r = getChar()
        if not c then return false, "died" end
        if math.abs(r.Position.Y - floorY) > 10 then return false, "fell off the island" end
        if h.Health < h.MaxHealth * 0.35 then
            putAwayBat()
            log("health low, leaving the candy island")
            dropDown(id, floorY, r.Position.Z < tower.midZ)
            return false, "health low"
        end
        local candy = tonumber(data("Candy")) or 0
        if candy > lastCandy then stats.candy = stats.candy + (candy - lastCandy) end
        lastCandy = candy
        local drop = nearestCandy(r.Position, floorY)
        local monster, pos, gap = nearestMonster(r.Position)
        if drop and (not monster or gap > BAT_REACH) then
            status("picking up candy (" .. short(candy) .. ")")
            steer(drop.Position - r.Position)
        elseif not monster then
            stopMoving()
            status("waiting for a monster (" .. short(candy) .. " candy)")
        else
            status(string.format("hitting a %s (%s candy)", tostring(monster:GetAttribute("MonsterName") or monster.Name), short(candy)))

            if gap > 2.5 then steer(pos - r.Position) else stopMoving() end
            if gap <= BAT_REACH and os.clock() >= nextSwing and not playerNear(r.Position, 10) then
                local bat = batTool()
                if bat and bat.Parent ~= c then pcall(function() h:EquipTool(bat) end) end
                if bat and bat.Parent == c then
                    pcall(function() bat:Activate() end)
                    nextSwing = os.clock() + (tonumber(bat:GetAttribute("Cooldown")) or 0.35) + 0.05 + math.random() * 0.15
                end
            end
        end
        RunService.Heartbeat:Wait()
    end
    stopMoving()
    putAwayBat()
    return true
end

local function buyCandyEggs()
    while alive and settings.candyEggs and (tonumber(data("Candy")) or 0) >= 250 do

        local ok, err = call("HalloweenShopService", "BuyCandyEgg")
        if ok ~= true then
            log("couldn't buy a candy egg" .. (err and (": " .. tostring(err)) or ""))
            return
        end
        stats.candyEggs = stats.candyEggs + 1
        log("bought a Halloween Dimension Egg with candy")
        task.wait(1)
    end
end

local function nextEgg()
    if settings.trainOnly then return nil, "training only" end
    local egg, nightBlocked = bestEgg()
    if egg then return egg end
    if nightBlocked then
        local isNight = nightState()
        return nil, isNight and "night time" or "night is close"
    end
    return nil, "no eggs worth taking"
end

local function farmLoop(id)
    log("auto farm on")
    while running(id) do
        local c, _, r = getChar()
        if not c then
            status("waiting to respawn")
            task.wait(1)
        elseif flat(r.Position - towers[worldAt(r.Position)].pad).Magnitude > 1500 then
            status("away from both towers (a boss fight?), waiting")
            task.wait(2)
        elseif carrying() then

            useWorld(worldAt(r.Position))
            if r.Position.Y < tower.pad.Y + 30 then
                status("waiting for the egg to be claimed")
                task.wait(1)
            else
                local nearest, nearestY
                for biome, info in pairs(BIOMES) do
                    local y = info.world == tower.name and floorOf(biome)
                    if y and (not nearestY or math.abs(y - r.Position.Y) < math.abs(nearestY - r.Position.Y)) then
                        nearest, nearestY = biome, y
                    end
                end
                if nearestY and math.abs(nearestY - r.Position.Y) < 15 then
                    dropDown(id, nearestY, r.Position.Z < tower.midZ)
                else
                    tapJump()
                    task.wait(1)
                end
            end
        else
            local egg, why = nextEgg()
            if egg then
                leaveTreadmill()
                local okt, res = trip(id, egg)
                if not okt and running(id) then
                    log("trip cut short: " .. tostring(res))
                    task.wait(0.5)
                end
            else
                local trained = false
                local function eggReady() return nextEgg() ~= nil end
                if settings.idle == "Farm candy (Halloween)" and halloweenOpen() then
                    local okc, res = farmCandy(id, eggReady)
                    trained = okc
                    if not okc and running(id) then
                        log("candy farming stopped: " .. tostring(res))
                        task.wait(1)
                    end
                elseif settings.idle == "Train on the treadmill" and treadmillPart() then

                    if not onTreadmill() then getDown(id) end
                    trained = train(id, eggReady)
                end
                if not trained then
                    status("waiting: " .. why)
                    task.wait(1)
                end
            end
        end

        RunService.Heartbeat:Wait()
    end
    stopMoving()
end

local function setFarm(on)
    on = on == true and alive
    if on == farm.enabled then return end
    farm.enabled = on
    farm.run = farm.run + 1
    stopMoving()
    if on then
        local id = farm.run
        task.spawn(function()
            local okf, err = pcall(farmLoop, id)
            stopMoving()
            if not okf then
                log("farm error: " .. tostring(err))
                warn("[climb eggs] " .. tostring(err))
            end
        end)
    else
        farm.status = "off"
        log("auto farm off")
    end
end

local spotRefused = {}
local placePause = 0

local function freeSpot()
    local cf, size = plotBox()
    local b = myBase()
    if not cf or not b then return nil end
    local taken = {}
    local placed = b:FindFirstChild("PlacedEggs")
    if placed then
        for _, e in ipairs(placed:GetChildren()) do
            local okp, p = pcall(function() return e:GetPivot().Position end)
            if okp then table.insert(taken, p) end
        end
    end
    local ground = workspace:FindFirstChild("Ground")
    local y = (ground and ground:IsA("BasePart")) and (ground.Position.Y + ground.Size.Y / 2) or cf.Position.Y
    local hx, hz = size.X / 2 - 5, size.Z / 2 - 5
    local x = -hx
    while x <= hx do
        local z = -hz
        while z <= hz do
            local p = cf:PointToWorldSpace(Vector3.new(x, 0, z))
            p = Vector3.new(p.X, y, p.Z)
            local key = math.floor(x) .. ":" .. math.floor(z)
            local clear = not spotRefused[key] or os.clock() - spotRefused[key] > 120
            if clear then
                for _, t in ipairs(taken) do
                    if flat(t - p).Magnitude < 6 then
                        clear = false
                        break
                    end
                end
            end
            if clear then return CFrame.new(p), key end
            z = z + 6
        end
        x = x + 6
    end
    return nil
end

local function placeOne()
    if os.clock() < placePause then return false end
    local key
    for k, item in pairs(data("Inventory") or {}) do
        if type(item) == "table" and item.Handler == "Egg" then
            key = k
            break
        end
    end
    if not key then return false end
    local spot, spotKey = freeSpot()
    if not spot then
        log("no free spot on the plot for eggs")
        placePause = os.clock() + 20
        return false
    end
    local res, err = call("EggPlacementService", "RequestToPlace", key, spot)
    if res and res.Status then
        stats.placed = stats.placed + 1
        log("placed a " .. key:split("_")[1] .. " egg")
        return true
    end
    spotRefused[spotKey] = os.clock()
    log("couldn't place an egg: " .. reasonOf(res, err))
    placePause = os.clock() + 8
    return false
end

local needEquip, lastEquip = false, 0

local function hatchOne()
    if not Hatcher then return false end
    local okc, can = pcall(backpackLimits.CanHatch, data("Inventory"))
    if okc and not can then return false end
    for key, info in pairs(data("PlacedEggs") or {}) do
        if type(info) == "table" and info.CanHatch and not (Hatcher.Pending and Hatcher.Pending[key]) then
            pcall(function() Hatcher:Hatch(key) end)
            local t = os.clock()
            while (data("PlacedEggs") or {})[key] and os.clock() - t < 8 do task.wait(0.25) end
            if not (data("PlacedEggs") or {})[key] then
                stats.hatched = stats.hatched + 1
                log("hatched a " .. key:split("_")[1])
                needEquip = true
            end
            return true
        end
    end
    return false
end

local function equipBest()
    if not Loadout then return end
    local spare, onBase = 0, 0
    for _, a in ipairs(animals()) do
        if a.equipped then onBase = onBase + 1 else spare = spare + 1 end
    end
    if spare == 0 then
        needEquip = false
        return
    end
    if needEquip or os.clock() - lastEquip > 45 then
        needEquip = false
        lastEquip = os.clock()
        pcall(function() Loadout:Request("EquipBest") end)
    end
end

local lastSell = 0
local function sellSpare()
    if os.clock() - lastSell < 15 then return end
    local spare = {}
    for _, a in ipairs(animals()) do
        if not a.equipped then table.insert(spare, a) end
    end
    local okf, full = pcall(backpackLimits.IsFull, data("Inventory"))
    full = okf and full == true
    if #spare <= settings.keepSpare and not full then return end
    lastSell = os.clock()
    table.sort(spare, function(a, b) return a.value < b.value end)
    local n = math.max(#spare - settings.keepSpare, 1)
    local keys = {}
    for i = 1, math.min(n, #spare) do table.insert(keys, spare[i].key) end
    local res, err = call("AnimalSellService", "Request", "SellList", keys)
    if res and res.Status then
        stats.sold = stats.sold + #keys
        log("sold " .. #keys .. " spare animal" .. (#keys == 1 and "" or "s") .. " for $" .. short(res.Amount))
    else
        log("couldn't sell: " .. reasonOf(res, err))
    end
end

local buyCooldown = {}

local function upgradeOptions()
    local opts = {}
    if settings.buyStamina then
        local lvl = tonumber(data("StaminaLevel")) or 1
        if lvl < (tonumber(staminaUpgradeConfig.MaxLevel) or 30) then
            local okp, price = pcall(staminaUpgradeConfig.GetPrice, lvl)
            local tut = data("Tutorial")
            if type(tut) == "table" and tut.FreeStaminaUsed == false then price = 0 end
            if okp and tonumber(price) then table.insert(opts, {what = "stamina", cost = tonumber(price), level = lvl}) end
        end
    end
    if settings.buyTreadmill then
        local lvl = tonumber(data("TreadmillLevel")) or 0
        local nxt = treadmillConfig.LevelConfig and treadmillConfig.LevelConfig[lvl + 1]
        if nxt and lvl < (tonumber(treadmillConfig.MaxLevel) or 12) then
            table.insert(opts, {what = "treadmill", cost = tonumber(nxt.UpgradeCost) or 0, level = lvl})
        end
    end
    if settings.buyBase then
        local lvl = tonumber(data("BaseLevel")) or 1
        local nxt = baseUpgradeConfig.Levels and baseUpgradeConfig.Levels[lvl + 1]
        if nxt then table.insert(opts, {what = "base", cost = tonumber(nxt.UpgradeCost) or math.huge, level = lvl}) end
    end
    table.sort(opts, function(a, b) return a.cost < b.cost end)
    return opts
end

local NAMES = {stamina = "stamina", treadmill = "treadmill", base = "base slots"}

local function buyUpgrades()
    local cash = tonumber(data("Cash")) or 0
    local budget = cash * (1 - settings.reserve / 100)
    for _, opt in ipairs(upgradeOptions()) do
        if opt.cost <= budget and os.clock() > (buyCooldown[opt.what] or 0) then
            local res, err
            if opt.what == "stamina" then
                res, err = call("StaminaUpgradeService", "Purchase", opt.level)
            elseif opt.what == "treadmill" then
                res, err = call("TreadmillService", "RequestToUpgrade")
            else
                res, err = call("BaseUpgradeService", "RequestToUpgrade")
            end
            if res and res.Status then
                stats.bought = stats.bought + 1
                log("bought " .. NAMES[opt.what] .. " level " .. (opt.level + 1) .. (opt.cost > 0 and (" for $" .. short(opt.cost)) or " (free)"))
            else
                buyCooldown[opt.what] = os.clock() + 30
                log("couldn't buy " .. NAMES[opt.what] .. ": " .. reasonOf(res, err))
            end
            return
        end
    end
end

local rebirthPause = 0
local function rebirthReady()
    local n = tonumber(data("Rebirths")) or 0
    local maxR = tonumber(rebirthConfig.MaxRebirths) or 0
    if maxR > 0 and n >= maxR then return false end
    local okr, req = pcall(rebirthConfig.GetRequirements, n)
    if not okr or type(req) ~= "table" then return false end
    for stat, need in pairs(req) do
        if (tonumber(data(stat)) or 0) < (tonumber(need) or math.huge) then return false end
    end
    return true
end

local function tryRebirth()
    if os.clock() < rebirthPause or not rebirthReady() then return end

    local res, err = call("RebirthService", "Request", false)
    if res and res.Status then
        stats.rebirths = stats.rebirths + 1
        log("rebirthed (now " .. tostring(data("Rebirths")) .. ")")
    else
        rebirthPause = os.clock() + 60
        log("couldn't rebirth: " .. reasonOf(res, err))
    end
end

local lastDaily, lastIndex = -1e9, -1e9
local function claimRewards()
    if Gifts then
        for i = 1, 12 do
            local okr, ready = pcall(Gifts.IsReady, Gifts, i)
            local okc, claimed = pcall(Gifts.IsClaimed, Gifts, i)
            if okr and ready == true and okc and claimed ~= true then
                local res = call("GiftPlayTimeService", "Claim", i)
                if res and res.Status then log("claimed playtime gift " .. i) end
                task.wait(0.4)
            end
        end
    end
    if os.clock() - lastDaily > 600 then
        lastDaily = os.clock()
        local res = call("DailyRewardsService", "Claim")
        if res and res.Status then log("claimed the daily reward") end
    end
    if os.clock() - lastIndex > 300 then
        lastIndex = os.clock()
        local res = call("IndexService", "ClaimAll")
        if res and res.Status then log("claimed index rewards") end
    end
    if (tonumber(data("PendingOfflineCash")) or 0) > 0 then
        local res = call("CashFlowService", "ClaimOfflineCash")
        if res and res.Status then log("claimed offline cash") end
    end
end

task.spawn(function()
    while alive do
        pcall(function()
            if settings.hatch and hatchOne() then return end
            if settings.place then placeOne() end
            if settings.equip then equipBest() end
            if settings.sell then sellSpare() end
        end)
        task.wait(1.5)
    end
end)

task.spawn(function()
    local rounds = 0
    while alive do
        rounds = rounds + 1
        pcall(function()
            if settings.rebirth then tryRebirth() end
            if settings.buyStamina or settings.buyTreadmill or settings.buyBase then buyUpgrades() end
            if settings.rewards and rounds % 10 == 1 then claimRewards() end
            if settings.candyEggs and rounds % 5 == 2 then buyCandyEggs() end
        end)
        task.wait(2)
    end
end)

if svc.TreadmillService and svc.TreadmillService.ShowMultiplier then
    pcall(function()
        connect(svc.TreadmillService.ShowMultiplier, function(multId)
            if not alive or not settings.multipliers or not Treadmill then return end
            task.delay(0.35 + math.random() * 0.9, function()
                if alive and onTreadmill() then pcall(function() Treadmill:ClaimMultiplier(multId) end) end
            end)
        end)
    end)
end

if svc.DayCycleService and svc.DayCycleService.CaughtAtNight then
    pcall(function()
        connect(svc.DayCycleService.CaughtAtNight, function(caught)
            if caught then lastCaught = os.clock() end
        end)
    end)
end

local function watchCharacter(c)
    connect(c:GetAttributeChangedSignal("GuardStunned"), function()
        if c:GetAttribute("GuardStunned") then lastStun = os.clock() end
    end)
end
if plr.Character then watchCharacter(plr.Character) end
connect(plr.CharacterAdded, watchCharacter)

connect(plr.Idled, function()
    if not settings.antiAfk then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

elevate()

local function shutdown()
    if not alive then return end
    alive = false
    farm.enabled = false
    farm.run = farm.run + 1
    stopMoving()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if genv.__CFAE_FARM and genv.__CFAE_FARM.Settings == settings then genv.__CFAE_FARM = nil end
end

local window = BPUI:CreateWindow({Version = "1.4.0",
    Title = "Climb Eggs", Subtitle = "Climb For Animals Eggs",
    Icon = "egg", Theme = "Void", ToggleKey = Enum.KeyCode.RightShift, ShowSettings = true,
    ConfigFolder = "CatnClimbEggs", Watermark = false, CloseBehavior = "Hide",
    OnDestroy = shutdown,
})

genv.__CFAE_FARM = {
    Farm = farm, Settings = settings, Stats = stats, Log = logLines,
    SetFarm = setFarm,

    Debug = {EscapePlan = escapePlan, EggsIn = eggsIn, FloorOf = floorOf, NextEgg = nextEgg, IsTop = isTop, Reachable = reachable},
    Destroy = function()
        shutdown()
        pcall(function() window:Destroy() end)
    end,
}

local ui = {}

local farmTab = window:CreateTab({Name = "Farm", Icon = "egg"})
local main = farmTab:CreateSection("Auto farm")
local farmToggle = main:AddToggle({Name = "Auto farm", Default = false, Flag = "cfae_farm",
    Description = "Climbs, takes the best egg you can reach, brings it back. Trains when there's nothing to take.",
    Callback = function(v) setFarm(v) end})
main:AddKeybind({Name = "Keybind", Default = Enum.KeyCode.F6, Mode = "Press", Flag = "cfae_farm_key",
    Callback = function() farmToggle:Set(not farm.enabled) end})
ui.status = main:AddLabel({Text = "off", Style = "Sub"})
ui.session = main:AddLabel({Text = "-", Style = "Sub"})
ui.account = main:AddLabel({Text = "-", Style = "Sub"})

local eggSec = farmTab:CreateSection("Eggs")
eggSec:AddDropdown({Name = "Pick", Options = {"Most valuable", "Most cash per minute"}, Default = "Most valuable",
    Flag = "cfae_pick", Description = "Cash per minute weighs how long the climb takes.",
    Callback = function(v) settings.pick = v end})
local guardToggle = eggSec:AddToggle({Name = "Wait for the guard", Default = true, Flag = "cfae_guard_wait",
    Description = "Guards run at 18, you carry at 10. Waits by the egg until the guard is too far off to catch you before you're past the wall.",
    Callback = function(v) settings.waitForGuard = v == true end})
eggSec:AddDropdown({Name = "Escape route", DependsOn = guardToggle, Options = {"Best", "Round the wall", "Up the wall"},
    Default = "Best", Flag = "cfae_escape",
    Description = "Up the wall: run for the back of the tower, climb out of the guard's reach, hop off once it's wandered away.",
    Callback = function(v) settings.escape = v end})
eggSec:AddSlider({Name = "Longest wait per trip", DependsOn = guardToggle, Min = 5, Max = 120, Default = 45, Increment = 5,
    Suffix = " s", Flag = "cfae_guard_wait_s", Description = "Then it takes any egg up there the guard is away from, or tries another biome for a minute.",
    Callback = function(v) settings.guardWait = math.clamp(tonumber(v) or 45, 5, 120) end})
eggSec:AddSlider({Name = "Safety margin", DependsOn = guardToggle, Min = 0, Max = 10, Default = 2, Increment = 1,
    Suffix = " studs", Flag = "cfae_guard_margin", Description = "Room left between the guard's hitbox and you on the way out. Higher waits longer but gets caught less.",
    Callback = function(v) settings.guardMargin = math.clamp(tonumber(v) or 2, 0, 10) end})
eggSec:AddToggle({Name = "Only eggs better than my worst animal", Default = false, Flag = "cfae_better",
    Description = "Once the base is full, skips eggs that wouldn't replace anything.",
    Callback = function(v) settings.betterOnly = v == true end})
eggSec:AddToggle({Name = "Halloween eggs", Default = true, Flag = "cfae_halloween",
    Description = "Also goes through the halloween portal for Pumpkin Abyss, Bone Field and Witches Castle eggs while the event is open.",
    Callback = function(v) settings.halloween = v == true end})
eggSec:AddToggle({Name = "Stay off the tower at night", Default = true, Flag = "cfae_nights",
    Description = "Anyone carrying an egg at night drops it. Waits for the restock instead.",
    Callback = function(v) settings.nights = v == true end})
ui.next = eggSec:AddLabel({Text = "next: -", Style = "Sub"})
ui.night = eggSec:AddLabel({Text = "-", Style = "Sub"})

local idleSec = farmTab:CreateSection("Between trips")
idleSec:AddDropdown({Name = "When there's nothing to take", Options = {"Train on the treadmill", "Farm candy (Halloween)", "Wait in the lobby"},
    Default = "Train on the treadmill", Flag = "cfae_idle",
    Description = "Farm candy hits the pumpkins on Pumpkin Abyss with your Bat while the event is open.",
    Callback = function(v) settings.idle = v end})
idleSec:AddToggle({Name = "Buy candy eggs", Default = true, Flag = "cfae_candy_eggs",
    Description = "Spends every 250 candy on a Halloween Dimension Egg.",
    Callback = function(v) settings.candyEggs = v == true end})
idleSec:AddToggle({Name = "Train only", Default = false, Flag = "cfae_train_only",
    Description = "No egg runs, just speed for rebirths.",
    Callback = function(v) settings.trainOnly = v == true end})
idleSec:AddToggle({Name = "Click speed multipliers", Default = true, Flag = "cfae_mult",
    Callback = function(v) settings.multipliers = v == true end})

local baseTab = window:CreateTab({Name = "Base", Icon = "house"})
local baseSec = baseTab:CreateSection("Eggs and animals")
baseSec:AddToggle({Name = "Place eggs", Default = true, Flag = "cfae_place",
    Description = "Puts eggs from your backpack on free spots of your plot.",
    Callback = function(v) settings.place = v == true end})
baseSec:AddToggle({Name = "Hatch eggs", Default = true, Flag = "cfae_hatch",
    Callback = function(v) settings.hatch = v == true end})
baseSec:AddToggle({Name = "Equip best animals", Default = true, Flag = "cfae_equip",
    Description = "Uses the game's Equip Best after each hatch.",
    Callback = function(v) settings.equip = v == true end})
local sellToggle = baseSec:AddToggle({Name = "Sell spare animals", Default = false, Flag = "cfae_sell",
    Description = "Sells the weakest animals that aren't on your base. Animals on the base are never sold.",
    Callback = function(v) settings.sell = v == true end})
baseSec:AddSlider({Name = "Spare animals to keep", DependsOn = sellToggle, Min = 0, Max = 30, Default = 5, Increment = 1,
    Flag = "cfae_keep", Callback = function(v) settings.keepSpare = math.floor(tonumber(v) or 5) end})
ui.base = baseSec:AddLabel({Text = "-", Style = "Sub"})

local upTab = window:CreateTab({Name = "Upgrades", Icon = "trending-up"})
local upSec = upTab:CreateSection("Spending")
upSec:AddToggle({Name = "Buy stamina", Default = true, Flag = "cfae_buy_stamina",
    Description = "More stamina opens higher biomes with better eggs.",
    Callback = function(v) settings.buyStamina = v == true end})
upSec:AddToggle({Name = "Buy treadmills", Default = true, Flag = "cfae_buy_treadmill",
    Description = "Better treadmills train speed faster.",
    Callback = function(v) settings.buyTreadmill = v == true end})
upSec:AddToggle({Name = "Buy base slots", Default = true, Flag = "cfae_buy_base",
    Callback = function(v) settings.buyBase = v == true end})
upSec:AddSlider({Name = "Keep in reserve", Min = 0, Max = 90, Default = 0, Increment = 5, Suffix = " %", Flag = "cfae_reserve",
    Description = "Only spends what's above this share of your cash.",
    Callback = function(v) settings.reserve = math.clamp(tonumber(v) or 0, 0, 90) end})
ui.nextBuy = upSec:AddLabel({Text = "-", Style = "Sub"})
local rbSec = upTab:CreateSection("Rebirth")
rbSec:AddToggle({Name = "Rebirth when ready", Default = true, Flag = "cfae_rebirth",
    Description = "Rebirth only resets speed and raises your cash multiplier.",
    Callback = function(v) settings.rebirth = v == true end})
ui.rebirth = rbSec:AddLabel({Text = "-", Style = "Sub"})

local rewardTab = window:CreateTab({Name = "Rewards", Icon = "gift"})
local rewardSec = rewardTab:CreateSection("Free stuff")
rewardSec:AddToggle({Name = "Claim free rewards", Default = true, Flag = "cfae_rewards",
    Description = "Playtime gifts, the daily reward, index rewards and offline cash.",
    Callback = function(v) settings.rewards = v == true end})
rewardSec:AddToggle({Name = "Anti AFK", Default = true, Flag = "cfae_afk",
    Description = "Roblox kicks you after 20 idle minutes otherwise.",
    Callback = function(v) settings.antiAfk = v == true end})

local logTab = window:CreateTab({Name = "Log", Icon = "list"})
local logSec = logTab:CreateSection("What the farm did")
ui.log = {}
for i = 1, 14 do ui.log[i] = logSec:AddLabel({Text = i == 1 and "nothing yet" or "", Style = "Sub"}) end
logSec:AddButton({Name = "Copy the whole log", ButtonText = "Copy", Callback = function()
    if setclipboard then
        setclipboard(table.concat(logLines, "\n"))
        window:Notify({Title = "Log", Content = "Copied " .. #logLines .. " lines.", Type = "Success", Duration = 3})
    end
end})

local function minutes(s)
    s = math.floor(s)
    if s < 60 then return s .. "s" end
    if s < 3600 then return math.floor(s / 60) .. "m" end
    return math.floor(s / 3600) .. "h " .. math.floor((s % 3600) / 60) .. "m"
end

task.spawn(function()
    local shownLog = -1
    while alive do
        pcall(function()

            local text = {}
            text.status = farm.enabled and farm.status or "off"
            text.session = string.format("this session: %d eggs, %d lost, %d hatched, %d bought, %d rebirths, %d candy, %d candy eggs, %s",
                stats.taken, stats.lost, stats.hatched, stats.bought, stats.rebirths, stats.candy, stats.candyEggs,
                minutes(os.clock() - stats.started))
            text.account = string.format("cash $%s (%s/s), speed %s, stamina %s, treadmill %s, rebirths %s",
                short(data("Cash")), short(plr:GetAttribute("CashPerSecond")), short(data("Speed")),
                tostring(data("StaminaLevel")), tostring(data("TreadmillLevel")), tostring(data("Rebirths")))
            local egg, why = nextEgg()
            text.next = egg and string.format("next: %s in %s, %s/s, about %ds there and back",
                eggLabel(egg.name, egg.variant), egg.biome, short(egg.value), math.floor(egg.trip))
                or ("next: nothing (" .. tostring(why) .. ")")
            local isNight, toNight, toDay = nightState()
            text.night = isNight and ("night, eggs restock in " .. minutes(toDay)) or ("night in " .. minutes(toNight))
            local list = animals()
            local onBase = 0
            for _, a in ipairs(list) do if a.equipped then onBase = onBase + 1 end end
            text.base = string.format("%d / %s animals on the base, %d spare, %d eggs growing",
                onBase, tostring(data("MaxAnimals")), #list - onBase, count(data("PlacedEggs")))
            local opts = upgradeOptions()
            text.nextBuy = opts[1] and ("next: " .. NAMES[opts[1].what] .. " for $" .. short(opts[1].cost)) or "next: nothing left to buy"
            local n = tonumber(data("Rebirths")) or 0
            local okr, req = pcall(rebirthConfig.GetRequirements, n)
            local need = okr and type(req) == "table" and req.Speed
            text.rebirth = need and string.format("speed %s / %s", short(data("Speed")), short(need)) or "-"

            elevate()
            for key, value in pairs(text) do ui[key]:Set(value) end
            if lastLogAt ~= shownLog then
                shownLog = lastLogAt
                for i = 1, #ui.log do ui.log[i]:Set(logLines[i] or "") end
            end
        end)
        task.wait(0.5)
    end
end)
