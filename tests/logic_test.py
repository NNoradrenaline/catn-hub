# Tests the hub's and Funky Friday's small pure pieces, cut straight out of dist/ with a stubbed Roblox.
# Run: python tests/logic_test.py   (needs: pip install lupa)
import os, lupa

HERE = os.path.dirname(os.path.abspath(__file__))
read = lambda p: open(os.path.join(HERE, '..', 'dist', p), encoding='utf-8').read().replace('\r\n', '\n')
ff, hub = read('games/ff.lua'), read('catn_hub.lua')


def cut(src, start, end):
    i = src.index(start)
    return src[i:src.index(end, i)]


fails = 0


def ok(cond, name):
    global fails
    print(('  ok   ' if cond else '  FAIL ') + name)
    fails += not cond


# --- leaderboard text -> number ("1.13k", "1,234", "105m") ---
L = lupa.LuaRuntime()
num = L.execute(cut(ff, 'local function num(t) -- "3.13k"', 'local function board(name)') + '\nreturn num')
ok(num('1.13k') == 1130, 'num: 1.13k')
ok(num('1,234') == 1234, 'num: commas')
ok(num('105m') == 105e6, 'num: millions')
ok(num(' 7 ') == 7, 'num: spaces')
ok(num('') is None and num('abc') is None and num(None) is None, 'num: junk is nil')

# --- partner heartbeat: "alive in another server" vs offline ---
L = lupa.LuaRuntime()
L.execute('''
NOW = 1000
os = {time = function() return NOW end}
game = {JobId = "mine"}
BEAT = nil
function pjson() return BEAT end
partnerName = "abtestas24"
PAIR_FOLDER = "FFAutoFarm"
''')
where = L.execute(cut(ff, 'local function beatFile(name)', 'supervise("heartbeat"') +
                  cut(ff, 'local function partnerWhere()', '\n\n') + '\nreturn partnerWhere')
beat = lambda job, t: L.execute('BEAT = {job = %r, time = %d}' % (job, t))
beat('theirs', 990)
ok(where() == 'theirs', 'partner: fresh beat in another server -> follow it')
beat('theirs', 900)
ok(where() is None, 'partner: stale beat -> offline, hold')
beat('mine', 995)
ok(where() is None, 'partner: same server (still loading in) -> stay')
beat('', 995)
ok(where() is None, 'partner: no server -> stay')
L.execute('BEAT = nil')
ok(where() is None, 'partner: no heartbeat file -> stay')

# --- come-back loader: queued once, cleared first, only when on ---
L = lupa.LuaRuntime()
L.execute('''
Q = {}
function queue_on_teleport(s) Q[#Q + 1] = s end
function clear_teleport_queue() Q = {} end
comeBack = {on = true, loader = "loadstring(x)()"}
''')
requeue = L.execute(cut(hub, 'local canQueue', 'local comeBackToggle') + '\nreturn requeue')
requeue(); requeue()
ok(L.eval('#Q') == 1 and L.eval('Q[1]') == 'loadstring(x)()', 'requeue: one copy after two calls')
L.execute('comeBack.on = false')
requeue()
ok(L.eval('#Q') == 0, 'requeue: off clears the queue')
L.execute('comeBack.on = true; comeBack.loader = "   "')
requeue()
ok(L.eval('#Q') == 0, 'requeue: blank loader queues nothing')

# --- game scripts are fetched past the caches ---
ok('games/" .. key .. ".lua?t=" .. os.time()' in hub, 'hub: game scripts fetched with a cache-busting query')

print('\nlogic: %s' % ('all tests pass' if not fails else '%d failed' % fails))
raise SystemExit(1 if fails else 0)
