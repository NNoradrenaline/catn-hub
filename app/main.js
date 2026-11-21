// Catn Control desktop app: one native window around catn-control.html.
const { app, BrowserWindow, shell, session, ipcMain, net } = require("electron");
const path = require("path");
const fs = require("fs");

if (!app.requestSingleInstanceLock()) app.quit();
app.setAppUserModelId("com.catn.control"); // taskbar groups and pins under the cat icon

// UI updates: the page files (html + core.js) come from GitHub when the repo has a newer version.
// main.js/preload.js changes still need a reinstall, so an update that needs a newer bridge (MAIN_API) is skipped.
const MAIN_API = 1;
const RAW = "https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/app/";
const UI_FILES = ["catn-control.html", "core.js"];
const uiDir = () => path.join(app.getPath("userData"), "ui");
const newer = (a, b) => { const x = String(a).split(".").map(Number), y = String(b).split(".").map(Number); for (let i = 0; i < 3; i++) { if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0); } return false; };
function uiVersion() {
  try { const v = JSON.parse(fs.readFileSync(path.join(uiDir(), "version.json"), "utf8")).version; if (newer(v, app.getVersion())) return v; } catch {}
  return null;
}
const pageFile = () => (uiVersion() ? path.join(uiDir(), "catn-control.html") : path.join(__dirname, "catn-control.html"));
async function getText(url) {
  const r = await net.fetch(url + "?t=" + Date.now(), { cache: "no-store" });
  if (!r.ok) throw new Error(url + " " + r.status);
  return r.text();
}
async function checkUpdate() {
  try {
    const pkg = JSON.parse(await getText(RAW + "package.json"));
    const have = uiVersion() || app.getVersion();
    if (!newer(pkg.version, have) || (pkg.catnMainApi || 1) > MAIN_API) return;
    const files = {};
    for (const f of UI_FILES) files[f] = await getText(RAW + f); // all or nothing: a half update never loads
    if (!files["catn-control.html"].includes("<html") || !files["core.js"].includes("CatnCore")) return;
    const tmp = uiDir() + ".new";
    fs.rmSync(tmp, { recursive: true, force: true });
    fs.mkdirSync(tmp, { recursive: true });
    for (const f of UI_FILES) fs.writeFileSync(path.join(tmp, f), files[f]);
    for (const f of ["cat.png", "cat.ico"]) fs.copyFileSync(path.join(__dirname, f), path.join(tmp, f));
    fs.writeFileSync(path.join(tmp, "version.json"), JSON.stringify({ version: pkg.version }));
    fs.rmSync(uiDir(), { recursive: true, force: true });
    fs.renameSync(tmp, uiDir());
    if (win && !win.isDestroyed()) win.loadFile(pageFile()); // the page keeps its state in localStorage
  } catch (e) { /* offline or GitHub hiccup: try again next start */ }
}

// The duo farm watchdog (farm/watchdog.js) reads control.json and writes status.json here.
const FARM_DIR = process.env.CATN_FARM_DIR || path.join(process.env.LOCALAPPDATA || app.getPath("appData"), "CatnFarm");
const readJson = (f) => { try { return JSON.parse(fs.readFileSync(f, "utf8")); } catch { return null; } };
ipcMain.handle("farm:status", () => ({ status: readJson(path.join(FARM_DIR, "status.json")), control: readJson(path.join(FARM_DIR, "control.json")) }));
ipcMain.handle("farm:control", (e, patch) => {
  // only these keys, only these shapes: the page is trusted, but this file drives Roblox launches
  const cur = readJson(path.join(FARM_DIR, "control.json")) || {};
  if (patch && typeof patch.enabled === "boolean") cur.enabled = patch.enabled;
  for (const k of ["winner", "loser"]) if (patch && typeof patch[k] === "string" && /^\d{1,20}$/.test(patch[k])) cur[k] = patch[k];
  if (patch && patch.relaunch && /^\d{1,20}$/.test(String(patch.relaunch))) cur.relaunch = { id: String(patch.relaunch), at: Date.now() };
  fs.mkdirSync(FARM_DIR, { recursive: true });
  fs.writeFileSync(path.join(FARM_DIR, "control.json"), JSON.stringify(cur, null, 2));
  return cur;
});
ipcMain.handle("app:info", () => ({ version: uiVersion() || app.getVersion(), shell: app.getVersion() }));

let win;
const stateFile = () => path.join(app.getPath("userData"), "window.json");

function create() {
  let s = {};
  try { s = JSON.parse(fs.readFileSync(stateFile(), "utf8")); } catch {}
  win = new BrowserWindow({
    width: s.width || 1360, height: s.height || 880, x: s.x, y: s.y, minWidth: 900, minHeight: 600,
    title: "Catn Control", icon: path.join(__dirname, "cat.ico"), backgroundColor: "#09090b", show: false,
    titleBarStyle: "hidden", titleBarOverlay: { color: "#09090b", symbolColor: "#9a9aa6", height: 36 },
    webPreferences: { contextIsolation: true, sandbox: true, preload: path.join(__dirname, "preload.js") },
  });
  if (s.max) win.maximize();
  win.once("ready-to-show", () => win.show());
  win.loadFile(pageFile());
  // roblox:// join links and web links open outside the app
  win.webContents.setWindowOpenHandler(({ url }) => { shell.openExternal(url); return { action: "deny" }; });
  win.webContents.on("will-navigate", (e, url) => {
    if (!url.startsWith("file:")) { e.preventDefault(); shell.openExternal(url); }
  });
  win.on("close", () => {
    try { fs.writeFileSync(stateFile(), JSON.stringify({ ...win.getNormalBounds(), max: win.isMaximized() })); } catch {}
  });
}

app.on("second-instance", () => {
  if (!win) return;
  if (win.isMinimized()) win.restore();
  win.focus();
});
app.whenReady().then(() => {
  // Roblox's thumbnail API sends no CORS header; let the renderer read avatar image URLs from that one host.
  session.defaultSession.webRequest.onHeadersReceived({ urls: ["https://thumbnails.roblox.com/*"] }, (d, cb) =>
    cb({ responseHeaders: { ...d.responseHeaders, "access-control-allow-origin": ["*"] } }));
  create();
  setTimeout(checkUpdate, 5000);
  setInterval(checkUpdate, 6 * 3600 * 1000);
});
app.on("window-all-closed", () => app.quit());
