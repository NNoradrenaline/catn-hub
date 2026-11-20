// Catn Control desktop app: one native window around catn-control.html.
const { app, BrowserWindow, shell } = require("electron");
const path = require("path");
const fs = require("fs");

if (!app.requestSingleInstanceLock()) app.quit();
app.setAppUserModelId("com.catn.control"); // taskbar groups and pins under the cat icon

let win;
const stateFile = () => path.join(app.getPath("userData"), "window.json");

function create() {
  let s = {};
  try { s = JSON.parse(fs.readFileSync(stateFile(), "utf8")); } catch {}
  win = new BrowserWindow({
    width: s.width || 1360, height: s.height || 880, x: s.x, y: s.y, minWidth: 900, minHeight: 600,
    title: "Catn Control", icon: path.join(__dirname, "cat.ico"), backgroundColor: "#09090b", show: false,
    titleBarStyle: "hidden", titleBarOverlay: { color: "#09090b", symbolColor: "#9a9aa6", height: 36 },
    webPreferences: { contextIsolation: true, sandbox: true },
  });
  if (s.max) win.maximize();
  win.once("ready-to-show", () => win.show());
  win.loadFile(path.join(__dirname, "catn-control.html"));
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
app.whenReady().then(create);
app.on("window-all-closed", () => app.quit());
