// ═══════════════════════════════════════════════════════════════════
// MOSS-TTS-Nano Desktop — 主进程（窗口、托盘、IPC、生命周期）
// ═══════════════════════════════════════════════════════════════════

const { app, BrowserWindow, Tray, Menu, nativeImage, dialog, ipcMain } = require("electron");
const fs = require("fs");
const path = require("path");
const http = require("http");
const server = require("./server");

// ─── 单实例锁 ────────────────────────────────────────────────────────────
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on("second-instance", () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.show();
      mainWindow.focus();
    }
  });
}

// ─── 资源路径配置 ──────────────────────────────────────────────────────────
const APP_VERSION = JSON.parse(fs.readFileSync(path.join(__dirname, "version.json"), "utf-8")).version;

const RESOURCES = {
  get root() {
    return app.isPackaged ? process.resourcesPath : path.join(__dirname, "..", "..");
  },
  get onnxModelsDir() {
    return path.join(this.root, "onnx");
  },
  get audioDir() {
    return path.join(this.root, "assets", "audio");
  },
  get voicesManifest() {
    return path.join(this.root, "assets", "audio", "voices.json");
  },
  get settingsPath() {
    return path.join(app.getPath("userData"), "settings.json");
  },
};

// ─── 默认设置 ────────────────────────────────────────────────────────────
const DEFAULT_SETTINGS = {
  lang: "zh", runtime: "onnx", defaultVoice: "",
  closeToTray: true, animBg: true, darkMode: false,
  autoStart: true, serverPort: 18083,
};

// ─── 设置读写 ──────────────────────────────────────────────────────────────
function loadSettings() {
  try {
    if (fs.existsSync(RESOURCES.settingsPath)) {
      return JSON.parse(fs.readFileSync(RESOURCES.settingsPath, "utf-8"));
    }
  } catch (_) {}
  return { ...DEFAULT_SETTINGS };
}

function saveSettings(settings) {
  try {
    fs.mkdirSync(path.dirname(RESOURCES.settingsPath), { recursive: true });
    fs.writeFileSync(RESOURCES.settingsPath, JSON.stringify(settings, null, 2), "utf-8");
  } catch (_) {}
}

// ─── 状态 ──────────────────────────────────────────────────────────────────
let mainWindow = null;
let tray = null;

// ─── IPC 处理器 ──────────────────────────────────────────────────────────
function registerIpcHandlers() {
  ipcMain.handle("save-dialog", async (_event, defaultName) => {
    const result = await dialog.showSaveDialog(mainWindow, {
      title: "保存音频",
      defaultPath: defaultName || "output.wav",
      filters: [{ name: "WAV 音频", extensions: ["wav"] }],
    });
    return result.canceled ? null : result.filePath;
  });

  ipcMain.handle("write-file", async (_event, filePath, base64Data) => {
    try {
      fs.writeFileSync(filePath, Buffer.from(base64Data, "base64"));
      return { success: true };
    } catch (err) {
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle("open-files", async (_event, title, filters) => {
    const result = await dialog.showOpenDialog(mainWindow, {
      title: title || "选择文件",
      filters: filters || [{ name: "所有文件", extensions: ["*"] }],
      properties: ["openFile", "multiSelections"],
    });
    return result.canceled ? null : result.filePaths;
  });

  ipcMain.handle("read-file", async (_event, filePath) => {
    try {
      return { success: true, content: fs.readFileSync(filePath, "utf-8") };
    } catch (err) {
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle("open-external", async (_event, url) => {
    const { shell } = require("electron");
    shell.openExternal(url);
  });

  ipcMain.handle("get-runtime", async () => server.getRuntime());

  ipcMain.handle("set-runtime", async (_event, mode) => {
    if (mode !== "onnx" && mode !== "pytorch") return { success: false, error: "invalid mode" };
    if (mode === server.getRuntime()) return { success: true, changed: false };
    server.setRuntime(mode);

    const settings = loadSettings();
    settings.runtime = mode;
    saveSettings(settings);

    server.stopServer();
    await server.waitForPortFree(15000);
    server.startServer(RESOURCES.root, app.isPackaged);

    try {
      await server.waitForServer(90000);
      return { success: true, changed: true };
    } catch (err) {
      return { success: false, changed: true, error: `Server did not start: ${err.message}` };
    }
  });

  ipcMain.handle("get-settings", async () => loadSettings());

  ipcMain.handle("set-settings", async (_event, partial) => {
    const current = loadSettings();
    const oldPort = current.serverPort;
    Object.assign(current, partial);
    saveSettings(current);

    if (partial.serverPort !== undefined && partial.serverPort !== oldPort) {
      server.setPort(partial.serverPort);
      server.stopServer();
      await server.waitForPortFree(15000);
      server.startServer(RESOURCES.root, app.isPackaged);
      try { await server.waitForServer(45000); } catch (_) {}
    }
    return { success: true };
  });

  ipcMain.handle("get-resource-paths", async () => ({
    onnxModels: RESOURCES.onnxModelsDir,
    audioDir: RESOURCES.audioDir,
    voicesManifest: RESOURCES.voicesManifest,
    root: RESOURCES.root,
    userData: app.getPath("userData"),
  }));

  ipcMain.handle("get-i18n", async (_event, lang) => {
    const langFile = path.join(__dirname, "i18n", `${lang || "zh"}.json`);
    try {
      if (fs.existsSync(langFile)) return JSON.parse(fs.readFileSync(langFile, "utf-8"));
    } catch (_) {}
    return JSON.parse(fs.readFileSync(path.join(__dirname, "i18n", "zh.json"), "utf-8"));
  });

  ipcMain.handle("get-app-version", async () => APP_VERSION);
}

// ─── 窗口 ──────────────────────────────────────────────────────────────────
function createMainWindow() {
  if (mainWindow) { mainWindow.show(); mainWindow.focus(); return; }

  mainWindow = new BrowserWindow({
    width: 1000, height: 720, minWidth: 800, minHeight: 500,
    title: "MOSS-TTS-Nano",
    titleBarStyle: "hiddenInset",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      nodeIntegration: false,
      contextIsolation: true,
      webSecurity: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, "index.html"));
  mainWindow.on("close", (event) => {
    if (!server.getQuitting()) { event.preventDefault(); mainWindow.hide(); }
  });
  mainWindow.on("closed", () => { mainWindow = null; });
}

// ─── 托盘 ──────────────────────────────────────────────────────────────────
function createTray() {
  const iconPath = path.join(__dirname, "icons", process.platform === "darwin" ? "tray-icon.png" : "icon.png");
  let trayIcon;
  try {
    trayIcon = nativeImage.createFromPath(iconPath).resize({ width: 22, height: 22 });
  } catch (_) { trayIcon = nativeImage.createEmpty(); }

  tray = new Tray(trayIcon);
  tray.setToolTip("MOSS-TTS-Nano");

  const contextMenu = Menu.buildFromTemplate([
    { label: "打开主界面", click: () => { mainWindow ? (mainWindow.show(), mainWindow.focus()) : createMainWindow(); } },
    { type: "separator" },
    { label: "服务状态", enabled: false, id: "server-status" },
    { type: "separator" },
    { label: "退出", click: () => { server.setQuitting(true); server.stopServer(); app.quit(); } },
  ]);

  tray.setContextMenu(contextMenu);
  tray.on("double-click", () => { mainWindow ? (mainWindow.show(), mainWindow.focus()) : createMainWindow(); });

  setInterval(() => {
    const item = contextMenu.getMenuItemById("server-status");
    if (!item) return;
    http.get(`http://localhost:${server.getPort()}/health`, (res) => {
      let data = "";
      res.on("data", (c) => (data += c));
      res.on("end", () => { try { item.label = `✓ 运行中  │ ${JSON.parse(data).device || "cpu"}`; } catch (_) { item.label = "✓ 运行中"; } });
    }).on("error", () => { item.label = "✗ 服务未就绪"; });
  }, 5000);
}

// ─── 生命周期 ────────────────────────────────────────────────────────────
app.whenReady().then(async () => {
  registerIpcHandlers();

  const settings = loadSettings();
  if (settings.serverPort) server.setPort(settings.serverPort);
  if (settings.runtime) server.setRuntime(settings.runtime);

  // 开机自启始终开启
  try { app.setLoginItemSettings({ openAtLogin: true }); } catch (_) {}

  server.startServer(RESOURCES.root, app.isPackaged);

  try {
    await server.waitForServer();
    console.log("[app] Server is ready");
  } catch (err) {
    console.error("[app] Server startup failed:", err.message);
    dialog.showErrorBox("启动失败", `语音合成服务启动超时，请检查日志。\n${err.message}`);
  }

  createTray();
  createMainWindow();
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") { server.setQuitting(true); server.stopServer(); app.quit(); }
});

app.on("before-quit", () => { server.setQuitting(true); server.stopServer(); });

app.on("activate", () => { mainWindow ? mainWindow.show() : createMainWindow(); });
