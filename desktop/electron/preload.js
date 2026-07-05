const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("mossTTS", {
  platform: process.platform,
  versions: {
    node: process.versions.node,
    electron: process.versions.electron,
  },
  // File operations
  saveDialog: (defaultName) =>
    ipcRenderer.invoke("save-dialog", defaultName),
  writeFile: (filePath, base64Data) =>
    ipcRenderer.invoke("write-file", filePath, base64Data),
  openFiles: (title, filters) =>
    ipcRenderer.invoke("open-files", title, filters),
  readFile: (filePath) =>
    ipcRenderer.invoke("read-file", filePath),
  // Runtime
  getRuntime: () =>
    ipcRenderer.invoke("get-runtime"),
  setRuntime: (mode) =>
    ipcRenderer.invoke("set-runtime", mode),
  // Settings
  getSettings: () =>
    ipcRenderer.invoke("get-settings"),
  setSettings: (partial) =>
    ipcRenderer.invoke("set-settings", partial),
  // I18n
  getI18n: (lang) =>
    ipcRenderer.invoke("get-i18n", lang),
  // External link
  openExternal: (url) =>
    ipcRenderer.invoke("open-external", url),
});
