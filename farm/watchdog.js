// Catn duo farm watchdog: keeps two Funky Friday accounts in one server through Real, all night.
// Every minute: find each account's Roblox client through Real, relaunch any that dropped (into the
// partner's server when there is one), attach Real and start the hub; clear stuck windowless Roblox
// processes. Control: control.json (enabled/winner/loser). Status for the app and bot: status.json.
// Run: node watchdog.js   (no dependencies; needs Real open with its account manager unlocked)
"use strict";
const fs = require("fs");
const path = require("path");
const { spawn, execFileSync } = require("child_process");

const DIR = process.env.CATN_FARM_DIR || path.join(process.env.LOCALAPPDATA || ".", "CatnFarm");
const REAL_MCP = process.env.REAL_MCP || path.join(process.env.LOCALAPPDATA || ".", "Real", "data", "mcp", "real-mcp.exe");
const GUARD = path.join(DIR, "hold_roblox_mutex.ps1");
const FF_PLACE = 6447798030;
const LOADER = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/catn_hub.lua"))()';
const TICK_MS = 60000;
const MISSING_TICKS = 2;        // an account must be gone this many checks in a row before a relaunch (hops take a while)
const STUCK_TICKS = 5;          // in a client but not in Funky Friday / not answering this long -> close it
const TRAY_MAX_AGE_S = 180;     // a Roblox process with no window this old is a stuck tray handover
const LOGIN_BACKOFF_MS = 30 * 60000;

fs.mkdirSync(DIR, { recursive: true });
const CONTROL = path.join(DIR, "control.json");
const STATUS = path.join(DIR, "status.json");
const LOG = path.join(DIR, "watchdog.log");
const LOCK = path.join(DIR, "watchdog.pid");

function log(...a) {
  const line = new Date().toISOString() + " " + a.join(" ");
  console.log(line);
  try {
    fs.appendFileSync(LOG, line + "\n");
    if (fs.statSync(LOG).size > 2e6) fs.renameSync(LOG, LOG + ".old");
  } catch {}
}
const readJson = (f, d) => { try { return JSON.parse(fs.readFileSync(f, "utf8")); } catch { return d; } };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------- one copy only ----------
function pidAlive(pid) { try { process.kill(pid, 0); return true; } catch { return false; } }
function takeLock(file) {
  const old = Number(readJson(file, {}).pid);
  if (old && old !== process.pid && pidAlive(old)) return false;
  fs.writeFileSync(file, JSON.stringify({ pid: process.pid, started: Date.now() }));
  return true;
}

// ---------- Real, over its MCP server ----------
class Real {
  constructor() { this.p = null; }
  async start() {
    this.p = spawn(REAL_MCP, [], { stdio: ["pipe", "pipe", "ignore"], windowsHide: true });
    this.buf = ""; this.id = 0; this.wait = {};
    this.p.stdout.on("data", (d) => {
      this.buf += d;
      let i;
      while ((i = this.buf.indexOf("\n")) >= 0) {
        const l = this.buf.slice(0, i); this.buf = this.buf.slice(i + 1);
        try { const m = JSON.parse(l); if (this.wait[m.id]) { this.wait[m.id](m); delete this.wait[m.id]; } } catch {}
      }
    });
    this.p.on("exit", () => { this.p = null; for (const k in this.wait) this.wait[k]({ error: { message: "real-mcp exited" } }); this.wait = {}; });
    await this.rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "catn-watchdog", version: "1" } });
    this.p.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");
  }
  rpc(method, params, timeoutMs = 130000) {
    return new Promise((resolve) => {
      if (!this.p) return resolve({ error: { message: "real-mcp not running" } });
      const n = ++this.id;
      const t = setTimeout(() => { delete this.wait[n]; resolve({ error: { message: "timed out" } }); }, timeoutMs);
      this.wait[n] = (m) => { clearTimeout(t); resolve(m); };
      this.p.stdin.write(JSON.stringify({ jsonrpc: "2.0", id: n, method, params }) + "\n");
    });
  }
  // -> { ok, text, json }
  async call(name, args = {}, timeoutMs) {
    if (!this.p) await this.start();
    const m = await this.rpc("tools/call", { name, arguments: args }, timeoutMs);
    if (m.error) return { ok: false, text: m.error.message };
    const text = (m.result.content || []).map((c) => c.text || "").join("\n");
    return { ok: !m.result.isError, text, json: firstJson(text) };
  }
  stop() { if (this.p) this.p.kill(); }
}
// tool replies may wrap JSON in a data block: take the outermost {...}
function firstJson(text) {
  const a = text.indexOf("{"), b = text.lastIndexOf("}");
  if (a < 0 || b < a) return null;
  try { return JSON.parse(text.slice(a, b + 1)); } catch { return null; }
}

// ---------- Windows processes ----------
function ps(cmd) {
  return execFileSync("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", cmd], { encoding: "utf8", windowsHide: true, timeout: 30000 });
}
function robloxProcs() {
  const out = ps("Get-Process RobloxPlayerBeta -ErrorAction SilentlyContinue | ForEach-Object { '{0}|{1}|{2}' -f $_.Id, [int64]$_.MainWindowHandle, [int]((Get-Date) - $_.StartTime).TotalSeconds }; exit 0"); // no Roblox open sets a failing exit code
  return out.split(/\r?\n/).filter(Boolean).map((l) => { const [pid, hwnd, age] = l.split("|").map(Number); return { pid, hasWindow: hwnd !== 0, age }; });
}
function kill(pid, why) { log("closing Roblox", pid, "-", why); try { process.kill(pid); } catch {} }
function ensureGuard() {
  if (!fs.existsSync(GUARD)) return;
  const running = ps("(Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object CommandLine -like '*hold_roblox_mutex*' | Measure-Object).Count").trim();
  if (running !== "0") return;
  log("starting the multi-client guard");
  spawn("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", GUARD], { detached: true, stdio: "ignore", windowsHide: true }).unref();
}

// ---------- the farm ----------
const real = new Real();
const st = { missing: {}, stuck: {}, backoff: {}, lastAction: "", names: {}, relaunchAt: 0 };

async function accountNames() {
  if (Object.keys(st.names).length && Date.now() - (st.namesAt || 0) < 10 * 60000) return st.names;
  st.namesAt = Date.now();
  const r = await real.call("list-accounts");
  const list = r.ok ? JSON.parse(r.text.slice(r.text.indexOf("["))) : [];
  for (const a of list) st.names[a.id] = a.username;
  return st.names;
}

// every injected client -> { clientId, name, place, job, responsive }
async function clients() {
  const r = await real.call("list-clients", { probe: true }, 60000);
  const list = (r.json && r.json.clients) || [];
  const out = [];
  for (const c of list) {
    const id = Number(c.clientId);
    const info = { clientId: id, responsive: c.responsive !== false, name: null, place: 0, job: "" };
    if (info.responsive) {
      await real.call("set-active-client", { clientId: id });
      const e = await real.call("eval", { expression: 'local p=game:GetService("Players").LocalPlayer return (p and p.Name or "") .. "|" .. game.PlaceId .. "|" .. game.JobId', timeout: 10000 }, 30000);
      const v = e.json && typeof e.json.value === "string" ? e.json.value.split("|") : null;
      if (v) { info.name = v[0] || null; info.place = Number(v[1]) || 0; info.job = v[2] || ""; }
      else info.responsive = false;
    }
    out.push(info);
  }
  return out;
}

// launch -> wait for its window -> attach Real -> wait until in game as the right account -> start the hub
async function bringUp(accId, name, jobId) {
  const before = new Set(robloxProcs().map((p) => p.pid));
  const args = { accountId: String(accId), placeId: FF_PLACE, multiRoblox: true };
  if (jobId) args.jobId = jobId;
  log("launching", name, jobId ? "into " + jobId : "into a fresh server");
  const l = await real.call("launch-roblox", args, 60000);
  if (!l.ok) {
    log("launch failed for", name, "-", l.text);
    if (/403|cookie|expired|re-add/i.test(l.text)) { st.backoff[accId] = Date.now() + LOGIN_BACKOFF_MS; st.lastAction = name + " is logged out in Real: re-add it"; }
    return false;
  }
  let pid = null;
  for (let i = 0; i < 40 && !pid; i++) { await sleep(3000); const n = robloxProcs().find((p) => !before.has(p.pid) && p.hasWindow); if (n) pid = n.pid; }
  if (!pid) { log("no window appeared for", name); return false; }
  await sleep(8000);
  const inj = await real.call("inject", {}, 90000);
  if (!inj.ok) { log("inject failed for", name, "-", inj.text); return false; }
  await real.call("set-active-client", { clientId: pid });
  const e = await real.call("eval", { expression: 'local P=game:GetService("Players") local t=os.clock() repeat task.wait(1) until (P.LocalPlayer and game.JobId~="") or os.clock()-t>80 return (P.LocalPlayer and P.LocalPlayer.Name or "") .. "|" .. game.JobId', timeout: 90000 }, 110000);
  const v = e.json && typeof e.json.value === "string" ? e.json.value.split("|") : [];
  if (v[0] !== name) { log("client", pid, "is not", name, "yet (" + (v[0] || "not in game") + ")"); return false; }
  const x = await real.call("execute", { code: LOADER, quiet: true, watchMs: 2000 }, 60000);
  log("hub started for", name, "in", v[1], x.ok ? "" : "- " + x.text);
  st.lastAction = "relaunched " + name;
  return true;
}

async function tick() {
  const ctrl = readJson(CONTROL, null);
  const names = await accountNames();
  const status = { updated: Date.now(), enabled: !!(ctrl && ctrl.enabled), accounts: [], lastAction: st.lastAction, pid: process.pid,
    realAccounts: Object.entries(names).map(([id, name]) => ({ id, name })) }; // for the app's pickers
  if (!ctrl || !ctrl.enabled || !ctrl.winner || !ctrl.loser) { fs.writeFileSync(STATUS, JSON.stringify(status)); return; }

  ensureGuard();
  for (const p of robloxProcs()) if (!p.hasWindow && p.age > TRAY_MAX_AGE_S) kill(p.pid, "no window for " + p.age + "s (stuck handover)");

  const cl = await clients();
  const roles = [["winner", ctrl.winner], ["loser", ctrl.loser]];
  const byName = (n) => cl.find((c) => c.name === n);
  for (const [role, id] of roles) {
    const name = names[id] || String(id);
    const c = byName(name);
    const inFF = c && c.responsive && c.place === FF_PLACE && c.job;
    st.missing[id] = c ? 0 : (st.missing[id] || 0) + 1;
    st.stuck[id] = c && !inFF ? (st.stuck[id] || 0) + 1 : 0;
    status.accounts.push({ role, id, name, pid: c ? c.clientId : null, job: c ? c.job : "", state: inFF ? "farming" : c ? "not in game" : "offline", missingFor: st.missing[id] });
  }
  fs.writeFileSync(STATUS, JSON.stringify(status));

  // "Relaunch" from the app: close that account's client now; the normal path below brings it back
  if (ctrl.relaunch && ctrl.relaunch.at > st.relaunchAt) {
    st.relaunchAt = ctrl.relaunch.at;
    const id = ctrl.relaunch.id, c = byName(names[id]);
    if (c) kill(c.clientId, "relaunch asked for in the app");
    st.missing[id] = MISSING_TICKS; st.backoff[id] = 0;
    st.lastAction = "relaunching " + (names[id] || id) + " (asked in the app)";
  }
  for (const [, id] of roles) {
    const name = names[id] || String(id);
    const c = byName(name);
    if (c && st.stuck[id] >= STUCK_TICKS) { kill(c.clientId, name + " stuck outside Funky Friday"); st.stuck[id] = 0; st.missing[id] = MISSING_TICKS; continue; }
    if (st.missing[id] < MISSING_TICKS || (st.backoff[id] || 0) > Date.now()) continue;
    const partnerId = id === ctrl.winner ? ctrl.loser : ctrl.winner;
    const partner = byName(names[partnerId]);
    const partnerJob = partner && partner.place === FF_PLACE ? partner.job : "";
    // both gone: bring the winner up first, the loser follows into its server next tick
    if (!partnerJob && id === ctrl.loser && st.missing[ctrl.winner] >= MISSING_TICKS) continue;
    if (await bringUp(id, name, partnerJob)) st.missing[id] = 0;
    break; // one launch per tick: Roblox hands over badly when two start at once
  }
  status.lastAction = st.lastAction;
  fs.writeFileSync(STATUS, JSON.stringify(status));
}

async function main() {
  if (!takeLock(LOCK)) { console.log("watchdog already running"); return; }
  if (!fs.existsSync(CONTROL)) fs.writeFileSync(CONTROL, JSON.stringify({ enabled: false, winner: "", loser: "" }, null, 2));
  st.relaunchAt = (readJson(CONTROL, {}).relaunch || {}).at || 0; // only new requests
  log("watchdog up, folder", DIR);
  for (;;) {
    try { await tick(); } catch (e) { log("tick error:", e && e.stack || e); real.stop(); }
    await sleep(TICK_MS);
  }
}

if (require.main === module) main();
module.exports = { firstJson, takeLock };
