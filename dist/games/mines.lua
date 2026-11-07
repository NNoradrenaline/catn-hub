local genv = getgenv()
if genv.MS_SOLVER_STOP then pcall(genv.MS_SOLVER_STOP) end

local function solve(grid, width, height, totalMines, stop, pause)
    pause = pause or function() end
    local NODE_LIMIT, PROBE_LIMIT = 1500000, 40000

    local function neighbours(id)
        local x, z = id % width, math.floor(id / width)
        local list = {}
        for dz = -1, 1 do
            for dx = -1, 1 do
                local nx, nz = x + dx, z + dz
                if (dx ~= 0 or dz ~= 0) and nx >= 0 and nx < width and nz >= 0 and nz < height then
                    local n = nx + nz * width
                    if grid[n] ~= nil then table.insert(list, n) end
                end
            end
        end
        return list
    end

    local result = {prob = {}, exact = true, bad = false, skipped = 0, comps = 0, largest = 0, solutions = 0}
    local minesLeft, unknownCount = totalMines, 0
    for id, v in pairs(grid) do
        if v == "x" then minesLeft = minesLeft - 1 elseif v == "?" then unknownCount = unknownCount + 1 end
    end

    local rules, seen = {}, {}
    local function addRule(cells, need)
        if #cells == 0 then
            if need ~= 0 then result.bad = true end
            return false
        end
        if need < 0 or need > #cells then
            result.bad = true
            return false
        end
        table.sort(cells)
        local key = table.concat(cells, ",")
        if seen[key] ~= nil then
            if seen[key] ~= need then result.bad = true end
            return false
        end
        seen[key] = need
        table.insert(rules, {cells = cells, need = need})
        return true
    end

    for id, v in pairs(grid) do
        if type(v) == "number" then
            local cells, need = {}, v
            for _, n in ipairs(neighbours(id)) do
                if grid[n] == "?" then table.insert(cells, n)
                elseif grid[n] == "x" then need = need - 1 end
            end
            addRule(cells, need)
        end
    end
    if result.bad then return result end

    local fixed = {}
    local changed = true
    while changed and not result.bad do
        changed = false
        local kept = {}
        for _, rule in ipairs(rules) do
            local cells, need = {}, rule.need
            for _, c in ipairs(rule.cells) do
                if fixed[c] == nil then table.insert(cells, c)
                else need = need - (fixed[c]) end
            end
            if need < 0 or need > #cells then
                result.bad = true
                return result
            end
            if #cells > 0 then
                if need == 0 or need == #cells then
                    local v = need == 0 and 0 or 1
                    for _, c in ipairs(cells) do fixed[c] = v end
                    changed = true
                else
                    table.insert(kept, {cells = cells, need = need})
                end
            end
        end
        rules = kept

        if not changed then
            local byCell = {}
            for i, rule in ipairs(rules) do
                rule.set = {}
                for _, c in ipairs(rule.cells) do
                    rule.set[c] = true
                    byCell[c] = byCell[c] or {}
                    table.insert(byCell[c], i)
                end
            end
            local count = #rules
            for i = 1, count do
                if #rules > 1500 then break end
                local a = rules[i]
                for _, j in ipairs(byCell[a.cells[1]]) do
                    local b = rules[j]
                    if j ~= i and #b.cells > #a.cells then
                        local inside = true
                        for _, c in ipairs(a.cells) do
                            if not b.set[c] then inside = false break end
                        end
                        if inside then
                            local rest = {}
                            for _, c in ipairs(b.cells) do
                                if not a.set[c] then table.insert(rest, c) end
                            end
                            local need = b.need - a.need
                            if need < 0 or need > #rest then
                                result.bad = true
                                return result
                            end
                            table.sort(rest)
                            local key = table.concat(rest, ",")
                            if seen[key] == nil then
                                seen[key] = need
                                table.insert(rules, {cells = rest, need = need, set = {}})
                                for _, c in ipairs(rest) do rules[#rules].set[c] = true end
                                changed = true
                            elseif seen[key] ~= need then
                                result.bad = true
                                return result
                            end
                        end
                    end
                end
            end
        end
        pause()
        if stop() then return nil end
    end

    local fixedMines, fixedCount = 0, 0
    for id, v in pairs(fixed) do
        result.prob[id] = v
        fixedMines = fixedMines + v
        fixedCount = fixedCount + 1
    end
    minesLeft = minesLeft - fixedMines

    local parent = {}
    local function find(a)
        while parent[a] ~= a do
            parent[a] = parent[parent[a]]
            a = parent[a]
        end
        return a
    end
    for _, rule in ipairs(rules) do
        for _, c in ipairs(rule.cells) do
            if parent[c] == nil then parent[c] = c end
        end
        for i = 2, #rule.cells do
            parent[find(rule.cells[i])] = find(rule.cells[1])
        end
    end

    local groups = {}
    for _, rule in ipairs(rules) do
        local root = find(rule.cells[1])
        groups[root] = groups[root] or {rules = {}, cells = {}}
        table.insert(groups[root].rules, rule)
    end
    for c in pairs(parent) do
        table.insert(groups[find(c)].cells, c)
    end

    local solved, unsolved = {}, {}
    local constrained = 0

    for _, group in pairs(groups) do
        result.comps = result.comps + 1
        result.largest = math.max(result.largest, #group.cells)
        constrained = constrained + (#group.cells)

        local index, order, cellRules = {}, {}, {}
        for r, rule in ipairs(group.rules) do
            for _, c in ipairs(rule.cells) do
                cellRules[c] = cellRules[c] or {}
                table.insert(cellRules[c], r)
            end
        end
        local doneRule = {}
        local queue = {group.rules[1]}
        doneRule[group.rules[1]] = true
        local head = 1
        while head <= #queue do
            local rule = queue[head]
            head = head + 1
            for _, c in ipairs(rule.cells) do
                if not index[c] then
                    table.insert(order, c)
                    index[c] = #order
                    for _, r in ipairs(cellRules[c]) do
                        local other = group.rules[r]
                        if not doneRule[other] then
                            doneRule[other] = true
                            table.insert(queue, other)
                        end
                    end
                end
            end
        end

        local n = #order
        local need, left, touches = {}, {}, {}
        for r, rule in ipairs(group.rules) do
            need[r], left[r] = rule.need, #rule.cells
        end
        for i, c in ipairs(order) do touches[i] = cellRules[c] end

        local function place(i, v)
            local ok = true
            for _, r in ipairs(touches[i]) do
                left[r] = left[r] - 1
                need[r] = need[r] - v
                if need[r] < 0 or need[r] > left[r] then ok = false end
            end
            return ok
        end
        local function unplace(i, v)
            for _, r in ipairs(touches[i]) do
                left[r] = left[r] + 1
                need[r] = need[r] + v
            end
        end

        local ways, cellWays = {}, {}
        for i = 1, n do cellWays[i] = {} end
        local value, nodes, aborted, sinceYield = {}, 0, false, 0

        local function walk(i, mines)
            if aborted then return end
            nodes = nodes + 1
            sinceYield = sinceYield + 1
            if nodes > NODE_LIMIT then aborted = true return end
            if sinceYield > 4000 then
                sinceYield = 0
                pause()
                if stop() then aborted = true return end
            end
            if i > n then
                ways[mines] = (ways[mines] or 0) + 1
                for c = 1, n do
                    if value[c] == 1 then
                        local t = cellWays[c]
                        t[mines] = (t[mines] or 0) + 1
                    end
                end
                return
            end
            for v = 0, 1 do
                value[i] = v
                if place(i, v) then walk(i + 1, mines + v) end
                unplace(i, v)
                if aborted then return end
            end
        end
        walk(1, 0)
        if stop() then return nil end

        if not aborted then
            if next(ways) == nil then
                result.bad = true
                return result
            end
            table.insert(solved, {order = order, ways = ways, cellWays = cellWays})
            for _, w in pairs(ways) do result.solutions = result.solutions + w end
        else

            result.exact = false
            result.skipped = result.skipped + 1
            local function canFit(i)
                nodes = nodes + 1
                sinceYield = sinceYield + 1
                if nodes > PROBE_LIMIT then return nil end
                if sinceYield > 4000 then
                    sinceYield = 0
                    pause()
                end
                if i > n then return true end
                if value[i] ~= nil then
                    local v = value[i]
                    local fits, answer = place(i, v), false
                    if fits then answer = canFit(i + 1) end
                    unplace(i, v)
                    return answer
                end
                for v = 0, 1 do
                    local fits, answer = place(i, v), false
                    if fits then answer = canFit(i + 1) end
                    unplace(i, v)
                    if answer == nil or answer == true then return answer end
                end
                return false
            end

            for i = 1, n do
                local c = order[i]
                value = {}
                value[i] = 1
                nodes = 0
                local couldBeMine = canFit(1)
                value = {}
                value[i] = 0
                nodes = 0
                local couldBeSafe = canFit(1)
                value = {}
                if stop() then return nil end
                if couldBeMine == false and couldBeSafe == false then
                    result.bad = true
                    return result
                elseif couldBeMine == false then
                    result.prob[c] = 0
                elseif couldBeSafe == false then
                    result.prob[c] = 1
                else

                    local guess = 0
                    for _, r in ipairs(cellRules[c]) do
                        local rule = group.rules[r]
                        guess = math.max(guess, rule.need / #rule.cells)
                    end
                    result.prob[c] = guess
                end
            end
            table.insert(unsolved, order)
        end
    end

    local open = unknownCount - fixedCount - constrained
    local logFact = {[0] = 0}
    for i = 1, unknownCount + 1 do logFact[i] = logFact[i - 1] + math.log(i) end
    local function logChoose(a, b)
        return logFact[a] - logFact[b] - logFact[a - b]
    end

    local useCount = result.exact
    local function convolve(a, b)
        local out = {}
        for i, x in pairs(a) do
            for j, y in pairs(b) do
                out[i + j] = (out[i + j] or 0) + x * y
            end
        end
        return out
    end

    local before, after = {[1] = {[0] = 1}}, {[#solved] = {[0] = 1}}
    for i = 2, #solved do before[i] = convolve(before[i - 1], solved[i - 1].ways) end
    for i = #solved - 1, 1, -1 do after[i] = convolve(after[i + 1], solved[i + 1].ways) end
    local all = {[0] = 1}
    if #solved > 0 then all = convolve(before[#solved], solved[#solved].ways) end

    local base
    for t in pairs(all) do
        local rest = minesLeft - t
        if rest >= 0 and rest <= open then
            local l = logChoose(open, rest)
            if not base or l > base then base = l end
        end
    end
    if not base and useCount then

        useCount = false
        result.countOff = true
    end

    local function weight(t)
        if not useCount then return 1 end
        local rest = minesLeft - t
        if rest < 0 or rest > open then return 0 end
        return math.exp(logChoose(open, rest) - base)
    end

    local total = 0
    for t, w in pairs(all) do total = total + (w * weight(t)) end

    for g, comp in ipairs(solved) do
        local others = #solved > 1 and convolve(before[g], after[g]) or {[0] = 1}
        for i, c in ipairs(comp.order) do
            local sum, notMine = 0, 0
            for k, w in pairs(comp.ways) do
                local yes = comp.cellWays[i][k] or 0
                for r, o in pairs(others) do
                    local boards = o * weight(k + r)
                    sum = sum + (yes * boards)
                    notMine = notMine + ((w - yes) * boards)
                end
            end

            if sum == 0 then result.prob[c] = 0
            elseif notMine == 0 then result.prob[c] = 1
            else result.prob[c] = sum / (sum + notMine) end
        end
    end

    if open > 0 then
        local expected = 0
        for t, w in pairs(all) do expected = expected + (w * weight(t) * math.max(0, minesLeft - t)) end
        expected = expected / total
        if not result.exact then

            for _, order in ipairs(unsolved) do
                for _, c in ipairs(order) do expected = expected - (result.prob[c]) end
            end
        end
        local p = math.clamp(expected / open, 0, 1)

        if not useCount then p = math.clamp(p, 0.01, 0.99) end
        for id, v in pairs(grid) do
            if v == "?" and result.prob[id] == nil then result.prob[id] = p end
        end
    end

    result.minesLeft = minesLeft + fixedMines
    return result
end

local Info = game:GetService("ReplicatedStorage"):WaitForChild("Info")
local Parts = workspace:WaitForChild("Flag"):WaitForChild("Parts")

local function readBoard()
    local tiles = Parts:GetChildren()
    if #tiles == 0 then return nil end
    local size = tiles[1].Size.X
    local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
    for _, t in ipairs(tiles) do
        local p = t.Position
        minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
        minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
    end
    local width = math.floor((maxX - minX) / size + 0.5) + 1
    local height = math.floor((maxZ - minZ) / size + 0.5) + 1

    local grid, byId, flagged, sig = {}, {}, {}, {}
    for _, t in ipairs(tiles) do
        local id = math.floor((t.Position.X - minX) / size + 0.5) + math.floor((t.Position.Z - minZ) / size + 0.5) * width
        local state = "?"
        local gui = t:FindFirstChild("NumberGui")
        if gui then
            local label = gui:FindFirstChild("TextLabel")
            local text = label and label.Text or ""
            if text == "" then state = 0
            elseif text == "X" then state = "x"
            else state = tonumber(text) or "-" end
        else
            for _, c in ipairs(t:GetChildren()) do
                if c:IsA("Model") then flagged[id] = true break end
            end
        end
        grid[id], byId[id] = state, t
        sig[#sig + 1] = id .. "=" .. tostring(state) .. (flagged[id] and "f" or "")
    end
    table.sort(sig)
    return {grid = grid, tiles = byId, flagged = flagged, width = width, height = height,
        signature = table.concat(sig, ";") .. "|" .. tostring(Info.Mines.Value)}
end

local BPUI = ... or loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/ui.lua"))()

local settings = {design = "Glass", enabled = true, safe = true, mines = true, percents = true, guess = true}
local alive = true
local generation, needsDraw = 0, true
local clearAll

local window = BPUI:CreateWindow({Version = "1.0.0",
    Title = "Minesweeper Solver",
    Subtitle = "bLockerman's Minesweeper",
    ToggleKey = Enum.KeyCode.F8,
    ConfigFolder = "CatnMinesweeper",
    Scene = false,
    OnDestroy = function()
        alive = false
        generation = generation + 1
        clearAll()
        genv.MS_SOLVER_STOP = nil
    end,
})

pcall(function() window.v:SetBlur(false) end)

local tab = window:CreateTab({Name = "Solver", Icon = "bomb"})
local stats = tab:CreateSection("Board")
local statusText = stats:AddLabel({Text = "starting"})
local countText = stats:AddLabel({Text = "", Style = "Sub"})
local guessText = stats:AddLabel({Text = "", Style = "Sub"})
local solverText = stats:AddLabel({Text = "", Style = "Sub"})

local show = tab:CreateSection("Show")
show:AddDropdown({Name = "Tile design", Options = {"Glass", "Minimal", "Frost", "Brackets", "Wash", "Mono"}, Default = "Glass", Flag = "design",
    Description = "How the marks on the tiles look",
    Callback = function(choice)
        settings.design = choice
        needsDraw = true
    end})
local function option(name, key, description)
    show:AddToggle({Name = name, Default = true, Flag = key, Description = description, Callback = function(on)
        settings[key] = on
        needsDraw = true
    end})
end
option("Solver on", "enabled")
option("Safe tiles", "safe", "Tiles that can't be a mine")
option("Mines", "mines", "Tiles that have to be a mine")
option("Percentages", "percents", "The chance of a mine on every tile the numbers touch")
option("Best guess", "guess", "The lowest chance when nothing is certain")

local INK = Color3.fromRGB(14, 14, 15)
local CREAM = Color3.fromRGB(236, 232, 224)
local SAGE = Color3.fromRGB(156, 204, 170)
local DEEP_SAGE = Color3.fromRGB(62, 118, 84)
local CLAY = Color3.fromRGB(214, 112, 98)
local DEEP_CLAY = Color3.fromRGB(160, 62, 50)
local GOLD = Color3.fromRGB(226, 198, 138)
local WHITE = Color3.fromRGB(245, 245, 245)

local DESIGNS = {
    Glass = {
        text = CREAM, cold = CREAM, hot = CLAY,
        safe = {color = INK, fill = 0.62, stroke = SAGE, line = 0.1, width = 3, dot = SAGE, ring = true},
        mine = {color = INK, fill = 0.28, stroke = CLAY, line = 0.35, width = 2, dot = CLAY},
        percent = {color = INK, fill = 0.74, stroke = CREAM, line = 0.86, width = 1},
        guess = {color = INK, fill = 0.3, stroke = GOLD, line = 0, width = 4, text = GOLD, pulse = true},
        flag = {color = INK, fill = 0.42, stroke = GOLD, line = 0.2, width = 2, text = GOLD},
    },
    Minimal = {
        text = CREAM, cold = CREAM, hot = CLAY, textStroke = 0.45, textSize = 22,
        safe = {dot = SAGE, ring = true, dotSize = 18},
        mine = {dot = CLAY, dotSize = 16},
        percent = {},
        guess = {dot = GOLD, ring = true, dotSize = 58, text = GOLD, pulseDot = true},
        flag = {text = GOLD},
    },
    Frost = {
        text = INK, cold = INK, hot = DEEP_CLAY,
        safe = {color = CREAM, fill = 0.5, stroke = WHITE, line = 0.4, width = 2, dot = DEEP_SAGE, ring = true},
        mine = {color = CREAM, fill = 0.14, stroke = WHITE, line = 0.4, width = 2, dot = DEEP_CLAY},
        percent = {color = CREAM, fill = 0.62},
        guess = {color = CREAM, fill = 0.06, stroke = GOLD, line = 0, width = 4, pulse = true},
        flag = {color = CREAM, fill = 0.25, stroke = GOLD, line = 0, width = 2},
    },
    Brackets = {
        text = CREAM, cold = CREAM, hot = CLAY, textStroke = 0.5,
        safe = {color = INK, fill = 0.84, brackets = SAGE},
        mine = {color = INK, fill = 0.5, brackets = CLAY, dot = CLAY, dotSize = 14},
        percent = {color = INK, fill = 0.86},
        guess = {color = INK, fill = 0.55, brackets = GOLD, text = GOLD},
        flag = {color = INK, fill = 0.7, brackets = GOLD, text = GOLD},
    },
    Wash = {
        text = WHITE, cold = SAGE, hot = CLAY, textStroke = 0.5, size = 1, radius = 0, tintPercent = true,
        safe = {color = SAGE, fill = 0.56},
        mine = {color = CLAY, fill = 0.42, dot = INK, dotSize = 12},
        percent = {color = SAGE, fill = 0.8},
        guess = {color = GOLD, fill = 0.32, pulse = true, stroke = GOLD, line = 0.2, width = 2},
        flag = {color = GOLD, fill = 0.6},
    },
    Mono = {
        text = WHITE, cold = WHITE, hot = WHITE,
        safe = {color = INK, fill = 0.68, stroke = WHITE, line = 0.45, width = 2, dot = WHITE, ring = true},
        mine = {color = INK, fill = 0.12, dot = WHITE},
        percent = {color = INK, fill = 0.76},
        guess = {color = INK, fill = 0.25, stroke = WHITE, line = 0, width = 4, pulse = true},
        flag = {color = INK, fill = 0.5, stroke = WHITE, line = 0.2, width = 2},
    },
}

local FADE = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local PULSE = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local TweenService = game:GetService("TweenService")

local holder = Instance.new("Folder")
holder.Name = "MSSolver"
holder.Parent = gethui and gethui() or game:GetService("CoreGui")

local marks = {}

local textRotation = 0
local function faceCamera()
    local look = workspace.CurrentCamera.CFrame.LookVector
    local angle = math.deg(math.atan2(-look.Z, -look.X))
    local snapped = (math.floor(angle / 90 + 0.5) * 90) % 360
    if snapped == textRotation then return end
    textRotation = snapped
    for _, m in pairs(marks) do m.text.Rotation = snapped end
end

local function markFor(tile)
    local m = marks[tile]
    if m then return m end
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Top
    gui.Adornee = tile
    gui.LightInfluence = 0
    gui.CanvasSize = Vector2.new(100, 100)
    gui.Active = false
    gui.Parent = holder

    local chip = Instance.new("Frame")
    chip.AnchorPoint = Vector2.new(0.5, 0.5)
    chip.Position = UDim2.fromScale(0.5, 0.5)
    chip.Size = UDim2.fromScale(0.84, 0.84)
    chip.BackgroundColor3 = INK
    chip.BackgroundTransparency = 1
    chip.BorderSizePixel = 0
    chip.Parent = gui
    Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 16)
    local stroke = Instance.new("UIStroke")
    stroke.Transparency = 1
    stroke.Parent = chip

    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.fromScale(0.5, 0.5)
    dot.Size = UDim2.fromOffset(20, 20)
    dot.BorderSizePixel = 0
    dot.Visible = false
    dot.Parent = chip
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    local dotRing = Instance.new("UIStroke")
    dotRing.Thickness = 3
    dotRing.Parent = dot

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.fromScale(1, 1)
    text.Font = Enum.Font.GothamMedium
    text.TextSize = 26
    text.TextColor3 = CREAM
    text.Rotation = textRotation
    text.Parent = chip

    m = {gui = gui, chip = chip, stroke = stroke, dot = dot, dotRing = dotRing, text = text}
    marks[tile] = m
    return m
end

local function showBrackets(m, color)
    if not m.brackets then
        if not color then return end
        m.brackets = {}
        local LENGTH, THICK = 0.26, 0.05
        for _, corner in ipairs({{0, 0}, {1, 0}, {0, 1}, {1, 1}}) do
            for _, size in ipairs({{LENGTH, THICK}, {THICK, LENGTH}}) do
                local bar = Instance.new("Frame")
                bar.AnchorPoint = Vector2.new(corner[1], corner[2])
                bar.Position = UDim2.fromScale(corner[1], corner[2])
                bar.Size = UDim2.fromScale(size[1], size[2])
                bar.BorderSizePixel = 0
                bar.Parent = m.chip
                table.insert(m.brackets, bar)
            end
        end
    end
    for _, bar in ipairs(m.brackets) do
        bar.Visible = color ~= nil
        if color then bar.BackgroundColor3 = color end
    end
end

local function setMark(tile, kind, words, chance)
    local m = markFor(tile)
    local design = DESIGNS[settings.design] or DESIGNS.Glass
    local style = design[kind]

    local heat = chance and math.clamp((chance - 0.15) / 0.6, 0, 1)
    local tint = heat and design.cold:Lerp(design.hot, heat)
    m.text.Text = words or ""
    m.text.TextColor3 = style.text or (kind == "percent" and not design.tintPercent and tint) or design.text
    if kind == "percent" and design.tintPercent then m.chip.BackgroundColor3 = tint end

    local key = settings.design .. kind
    if m.key == key then return end
    m.key = key

    if m.pulse then
        m.pulse:Cancel()
        m.pulse = nil
    end
    local size = design.size or 0.84
    m.chip.Size = UDim2.fromScale(size, size)
    m.chip.UICorner.CornerRadius = UDim.new(0, design.radius or 16)
    if not (kind == "percent" and design.tintPercent) then m.chip.BackgroundColor3 = style.color or INK end
    m.stroke.Color = style.stroke or INK
    m.stroke.Thickness = style.width or 1
    m.text.TextSize = design.textSize or 26
    m.text.TextStrokeColor3 = INK
    m.text.TextStrokeTransparency = design.textStroke or 1
    showBrackets(m, style.brackets)

    m.dot.Visible = style.dot ~= nil
    if style.dot then

        local dotSize = style.dotSize or 20
        m.dot.Size = UDim2.fromOffset(dotSize, dotSize)
        m.dot.BackgroundColor3 = style.dot
        m.dot.BackgroundTransparency = style.ring and 1 or 0
        m.dotRing.Color = style.dot
        m.dotRing.Transparency = style.ring and 0 or 1
    end

    TweenService:Create(m.chip, FADE, {BackgroundTransparency = style.fill or 1}):Play()
    TweenService:Create(m.stroke, FADE, {Transparency = style.stroke and style.line or 1}):Play()
    if style.pulse then
        m.pulse = TweenService:Create(m.stroke, PULSE, {Transparency = 0.55})
        m.pulse:Play()
    elseif style.pulseDot then
        m.pulse = TweenService:Create(m.dotRing, PULSE, {Transparency = 0.55})
        m.pulse:Play()
    end
end

clearAll = function()
    for tile, m in pairs(marks) do
        m.gui:Destroy()
        marks[tile] = nil
    end
    if not alive then holder:Destroy() end
end

local function draw(board, result)
    if not settings.enabled or not result or result.bad then
        clearAll()
        return
    end

    local want = {}
    local safe, mines, wrongFlags = 0, 0, 0
    local best, bestP = nil, math.huge
    for id, p in pairs(result.prob) do
        if p <= 0 then
            safe = safe + 1
            if board.flagged[id] then wrongFlags = wrongFlags + 1 end
        elseif p >= 1 then
            mines = mines + 1
        elseif p < bestP then
            best, bestP = id, p
        end
    end
    local guessing = safe == 0 and best ~= nil

    for id, p in pairs(result.prob) do
        local tile = board.tiles[id]
        if tile and board.grid[id] == "?" then
            if p <= 0 then
                if settings.safe then
                    want[tile] = true
                    if board.flagged[id] then setMark(tile, "flag", "flag?") else setMark(tile, "safe") end
                end
            elseif p >= 1 then
                if settings.mines then
                    want[tile] = true
                    setMark(tile, "mine")
                end
            elseif guessing and id == best and settings.guess then
                want[tile] = true
                setMark(tile, "guess", math.floor(p * 100 + 0.5) .. "%", p)
            elseif settings.percents and result.touched[id] then
                want[tile] = true
                setMark(tile, "percent", (result.exact and "" or "~") .. math.floor(p * 100 + 0.5) .. "%", p)
            end
        end
    end
    for tile, m in pairs(marks) do
        if not want[tile] or not tile.Parent then
            m.gui:Destroy()
            marks[tile] = nil
        end
    end

    countText:Set(("%d safe, %d mines worked out, %d mines left"):format(safe, mines, result.minesLeft or 0))
    if wrongFlags > 0 then
        statusText:Set(wrongFlags .. " flag" .. (wrongFlags == 1 and " is" or "s are") .. " on a safe tile")
    elseif safe > 0 then
        statusText:Set("Safe tiles are marked")
    elseif best then
        statusText:Set("No safe tiles, you have to guess")
    else
        statusText:Set("Nothing left to work out")
    end
    guessText:Set(guessing and ("Best guess: %.1f%% chance of a mine"):format(bestP * 100) or "")
    solverText:Set((result.exact and "Exact" or "Some percentages are estimates")
        .. (" - %d group%s, biggest %d tiles"):format(result.comps, result.comps == 1 and "" or "s", result.largest)
        .. (result.countOff and ", mine count ignored" or ""))
end

local function touchedTiles(board)
    local touched = {}
    for id, v in pairs(board.grid) do
        if type(v) == "number" and v > 0 then
            local x, z = id % board.width, math.floor(id / board.width)
            for dz = -1, 1 do
                for dx = -1, 1 do
                    local nx, nz = x + dx, z + dz
                    if nx >= 0 and nx < board.width and nz >= 0 and nz < board.height then
                        touched[nx + nz * board.width] = true
                    end
                end
            end
        end
    end
    return touched
end

local lastSignature, latestResult, latestBoard

local function startSolve(board)
    generation = generation + 1
    local mine = generation
    task.spawn(function()
        local lastPause = os.clock()
        local result = solve(board.grid, board.width, board.height, Info.Mines.Value,
            function() return not alive or mine ~= generation end,
            function()
                if os.clock() - lastPause > 0.006 then
                    task.wait()
                    lastPause = os.clock()
                end
            end)
        if not result or mine ~= generation then return end
        result.touched = touchedTiles(board)
        latestResult, latestBoard = result, board
        needsDraw = true
    end)
end

task.spawn(function()
    while alive do
        local ok, err = pcall(function()
            faceCamera()
            if not Info.GameRunning.Value or not settings.enabled then
                if next(marks) then clearAll() end
                lastSignature, latestResult = nil, nil
                generation = generation + 1
                statusText:Set(settings.enabled and "Waiting for a round" or "Turned off")
                countText:Set("")
                guessText:Set("")
                solverText:Set("")
                return
            end
            local board = readBoard()
            if board and board.signature ~= lastSignature then
                lastSignature = board.signature
                statusText:Set("Working it out...")
                startSolve(board)
            end
            if needsDraw and latestResult then
                needsDraw = false
                if latestResult.bad then
                    clearAll()
                    statusText:Set("These numbers don't add up, is an event messing with them?")
                else
                    draw(latestBoard, latestResult)
                end
            end
        end)
        if not ok then warn("[solver] " .. tostring(err)) end
        task.wait(0.2)
    end
end)

genv.MS_SOLVER_STOP = function() window:Destroy() end

print("[solver] loaded, f8 for the menu")
