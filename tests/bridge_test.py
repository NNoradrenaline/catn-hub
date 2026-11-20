# Tests the Catn Control bridge (the block spliced into dist/ui.lua) with a stubbed Roblox.
# Run: python tests/bridge_test.py   (needs: pip install lupa)
import json, os, re, lupa

HERE = os.path.dirname(os.path.abspath(__file__))
ui = open(os.path.join(HERE, '..', 'dist', 'ui.lua'), encoding='utf-8').read().replace('\r\n', '\n')
start = ui.index('-- Catn Control: mirrors every window')
bridge = ui[start:ui.index('local function convert(o)', start)]

L = lupa.LuaRuntime(unpack_returned_tuples=True)
reqs, state = [], {'orders': None}


def lua2py(t):
    if lupa.lua_type(t) != 'table':
        return t
    keys = list(t.keys())
    if keys and all(isinstance(k, int) for k in keys):
        return [lua2py(t[k]) for k in sorted(keys)]
    if not keys:
        return []
    return {str(k): lua2py(v) for k, v in t.items()}


def py2lua(v):
    if isinstance(v, dict):
        return L.table_from({k: py2lua(x) for k, x in v.items()})
    if isinstance(v, list):
        return L.table_from([py2lua(x) for x in v])
    return v


def py_request(o):
    method, url, body = o['Method'], o['Url'], o['Body']
    reqs.append((method, url, json.loads(body) if body else None))
    body = json.dumps(state['orders']) if method == 'GET' else 'null'
    return L.table_from({'StatusCode': 200, 'Body': body})


g = L.globals()
g.py_request = py_request
g.py_encode = lambda t: json.dumps(lua2py(t))
g.py_decode = lambda s: py2lua(json.loads(s))
L.execute(r'''
NOW = 3000
files = {}
function isfile(p) return files[p] ~= nil end
function readfile(p) return files[p] end
request = function(o) return py_request(o) end
typeof = function(v) if type(v) == "table" and v.__kind then return v.__kind end return type(v) end
DateTime = {now = function() return {UnixTimestampMillis = NOW} end}
Enum = {KeyCode = setmetatable({F = {__kind = "EnumItem", Name = "F"}}, {__index = function(_, k) error("bad key " .. k) end})}
Color3 = {fromHex = function(h) if not tostring(h):match("^#?%x%x%x%x%x%x$") then error("bad hex") end
    return {__kind = "Color3", ToHex = function() return (h:gsub("#", "")) end} end}
teleports = {}
local HttpService = {JSONEncode = function(_, t) return py_encode(t) end, JSONDecode = function(_, s) return py_decode(s) end}
local services = {HttpService = HttpService, Players = {LocalPlayer = {Name = "Tester.One"}},
    TeleportService = {Teleport = function() table.insert(teleports, "hop") end,
                       TeleportToPlaceInstance = function() table.insert(teleports, "rejoin") end}}
game = {GetService = function(_, n) return services[n] end, PlaceId = 1, JobId = "j"}
loops = {}
task = {spawn = function(f, ...) if select("#", ...) > 0 then f(...) else table.insert(loops, f) end end, wait = function() end}
''')
L.execute(bridge + '\n_G.Remote, _G.reg = Remote, reg\n')
L.execute(r'''
function mk(value, fail)
    local o = {value = value}
    function o:Get() return self.value end
    function o:Set(v) if fail then error("boom") end self.value = v end
    return o
end
win, win2 = {}, {}
Remote.add(win, "Funky Friday")
Remote.add(win2, "Funky Friday")
sec = {win = win, tab = "Farm", name = "Duo"}
tog = reg(sec, "Toggle", {Name = "Auto farm", Flag = "ff_auto"}, mk(false))
reg(sec, "Slider", {Name = "Speed", Min = 1, Max = 10}, mk(5))
reg(sec, "Dropdown", {Name = "Difficulty", Options = {"Easy", "Hard"}}, mk("Easy"))
reg(sec, "Toggle", {Name = "Broken"}, mk(false, true))
pressed = 0
reg(sec, "Button", {Name = "Hop now", Callback = function() pressed = pressed + 1 end}, {})
reg(sec, "Keybind", {Name = "Key"}, mk(nil))
par = {Set = function() end}
reg(sec, "Paragraph", {Title = "Status", Content = "idle"}, par)
par:Set("on the pad")
reg(sec, "Button", {Name = "Hop now"}, {})
''')


def tick(orders):
    state['orders'] = orders
    reqs.clear()
    L.execute('local n = 0; task.wait = function() n = n + 1 if n > 1 then error("stop") end end')
    try:
        g.loops[1]()
    except lupa.LuaError:
        pass
    return {re.search(r'/acks/[^/]+/(.+)\.json', u).group(1): b for m, u, b in reqs if '/acks/' in u}


W = 'Funky Friday'
L.execute('NOW = 5000')
assert g.win._key == W and g.win2._key == 'Funky Friday_2'
ids = [c.id for c in g.win._ctl.list.values()]
assert 'ff_auto' in ids and 'Farm|Duo|Hop now_2' in ids, ids

acks = tick({
    'o1': {'op': 'set', 'window': W, 'id': 'ff_auto', 'value': True, 't': 4000},
    'o2': {'op': 'set', 'window': W, 'id': 'Farm|Duo|Speed', 'value': 99, 't': 4001},
    'o3': {'op': 'set', 'window': W, 'id': 'Farm|Duo|Difficulty', 'value': 'Nightmare', 't': 4002},
    'o4': {'op': 'set', 'window': W, 'id': 'Farm|Duo|Broken', 'value': True, 't': 4003},
    'o5': {'op': 'press', 'window': W, 'id': 'Farm|Duo|Hop now', 't': 4004},
    'o6': {'op': 'set', 'window': W, 'id': 'Farm|Duo|Key', 'value': 'Nope', 't': 4005},
    'o7': {'op': 'set', 'window': 'Other', 'id': 'x', 'value': 1, 't': 4006},
    'old': {'op': 'set', 'window': W, 'id': 'ff_auto', 'value': False, 't': -100},
})
assert acks['o1']['ok'] and acks['o1']['value'] is True and g.tog.value is True, acks['o1']
assert not acks['o2']['ok'] and acks['o2']['err'] == 'out of range'
assert not acks['o3']['ok'] and 'not an option' in acks['o3']['err']
assert not acks['o4']['ok'] and 'boom' in acks['o4']['err']
assert acks['o5']['ok'] and g.pressed == 1
assert not acks['o6']['ok'] and 'unknown key' in acks['o6']['err']
assert not acks['o7']['ok'] and acks['o7']['err'] == 'window not open'
assert 'old' not in acks

# the same order seen again does not run twice
assert tick({'o5': {'op': 'press', 'window': W, 'id': 'Farm|Duo|Hop now', 't': 4004}}) == {} and g.pressed == 1

# hop acks first, teleports, and stops handling the rest of this batch
L.execute('NOW = 5100')
acks = tick({'h': {'op': 'hop', 't': 5050}, 'later': {'op': 'press', 'window': W, 'id': 'Farm|Duo|Hop now', 't': 5060}})
assert acks['h']['ok'] and list(g.teleports.values()) == ['hop'] and 'later' not in acks, acks

# layout and values are published, status text included
L.execute('win._ctl.dirty = true; win._ctl.last = nil')
tick(None)
lay = [b for m, u, b in reqs if u.endswith('/menus/Tester_One/Funky Friday/layout.json')]
val = [b for m, u, b in reqs if u.endswith('/menus/Tester_One/Funky Friday.json') and m == 'PATCH']
assert lay and len(lay[0]) == 8, lay
assert val and val[0]['v']['Farm|Duo|Status'] == 'on the pad' and val[0]['v']['ff_auto'] is True, val
assert val[0]['v']['Farm|Duo|Broken'] is False, 'switches that are off must be sent too'

print('bridge: all tests pass')
