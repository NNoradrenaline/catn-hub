// The page's only way out of its sandbox: the duo farm watchdog's two files, and the app version.
const { contextBridge, ipcRenderer } = require("electron");
contextBridge.exposeInMainWorld("catnFarm", {
  status: () => ipcRenderer.invoke("farm:status"),
  control: (patch) => ipcRenderer.invoke("farm:control", patch),
});
contextBridge.exposeInMainWorld("catnApp", { info: () => ipcRenderer.invoke("app:info") });
