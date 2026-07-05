const { app, BrowserWindow, Tray, Menu, nativeImage, dialog, ipcMain } = require("electron");
const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const http = require("http");

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

// ─── 常量 ──────────────────────────────────────────────────────────────────
const SERVER_PORT = 18083;
const SERVER_URL = `http://localhost:${SERVER_PORT}`;
const POLL_INTERVAL_MS = 500;
const POLL_TIMEOUT_MS = 30_000;

// ─── 运行时模式 ────────────────────────────────────────────────────────────
let currentRuntime = "onnx";  // "onnx" | "pytorch"

// ─── 状态 ──────────────────────────────────────────────────────────────────
let mainWindow = null;
let tray = null;
let serverProcess = null;
let isQuitting = false;

// ─── 工具函数 ──────────────────────────────────────────────────────────────

/** 找到 Python 后端二进制文件 */
function findServerBinary() {
  // 打包后的路径: <app>/Contents/Resources/server/moss-tts-server
  // 开发时: pixi run serve-onnx
  const isPackaged = app.isPackaged;
  if (isPackaged) {
    const platform = process.platform;
    const binName = platform === "win32" ? "moss-tts-server.exe" : "moss-tts-server";
    const searchPaths = [
      path.join(process.resourcesPath, "server", binName),
      path.join(process.resourcesPath, "server", platform, binName),
    ];
    for (const p of searchPaths) {
      try {
        require("fs").accessSync(p);
        return p;
      } catch (_) {}
    }
    return null;
  }
  // 开发模式下返回 null，外部自己启动服务
  return null;
}

/** 轮询等待后端就绪 */
function waitForServer(timeoutMs = POLL_TIMEOUT_MS) {
  return new Promise((resolve, reject) => {
    const start = Date.now();
    const poll = () => {
      if (isQuitting) return reject(new Error("app quitting"));
      http
        .get(`${SERVER_URL}/health`, (res) => {
          let data = "";
          res.on("data", (chunk) => (data += chunk));
          res.on("end", () => resolve(true));
        })
        .on("error", () => {
          if (Date.now() - start > timeoutMs) {
            reject(new Error(`Server did not start within ${timeoutMs}ms`));
          } else {
            setTimeout(poll, POLL_INTERVAL_MS);
          }
        });
    };
    poll();
  });
}

let serverStarting = false;

/** 启动 Python 后端 */
function startServer() {
  if (serverStarting) {
    console.log("[server] already starting, skipping");
    return;
  }
  serverStarting = true;

  const binary = findServerBinary();
  if (binary) {
    // 打包模式：直接执行 PyInstaller 二进制
    serverProcess = spawn(binary, [], {
      stdio: ["ignore", "pipe", "pipe"],
    });
  } else {
    // 开发模式：通过 pixi 启动，传 runtime 参数
    const projectRoot = path.join(__dirname, "..", "..");
    const pixiTask = currentRuntime === "onnx" ? "serve-onnx" : "serve";
    serverProcess = spawn("pixi", ["run", pixiTask], {
      cwd: projectRoot,
      stdio: ["ignore", "pipe", "pipe"],
      shell: true,
    });
  }

  serverProcess.stdout.on("data", (data) => {
    console.log(`[server] ${data.toString().trim()}`);
  });
  serverProcess.stderr.on("data", (data) => {
    console.error(`[server:err] ${data.toString().trim()}`);
  });
  serverProcess.on("exit", (code) => {
    console.log(`[server] exited with code ${code}`);
    serverProcess = null;
    serverStarting = false;
  });
}

/** 停止 Python 后端 */
function stopServer() {
  if (serverProcess) {
    serverProcess.kill("SIGTERM");
    serverProcess = null;
    serverStarting = false;
    // 给 3 秒优雅退出，否则强制 kill
    setTimeout(() => {
      if (serverProcess) {
        serverProcess.kill("SIGKILL");
        serverProcess = null;
      }
    }, 3000);
  }
}

/** 等待端口释放 */
function _waitForPortFree(timeoutMs) {
  return new Promise((resolve) => {
    const start = Date.now();
    const check = () => {
      try {
        const occupied = require("child_process").execSync(
          `lsof -ti:${SERVER_PORT} 2>/dev/null || true`,
          { encoding: "utf-8" }
        ).trim();
        if (!occupied) return resolve();
      } catch (_) {}
      if (Date.now() - start > timeoutMs) return resolve(); // give up, try anyway
      setTimeout(check, 500);
    };
    check();
  });
}

/** 注册 IPC 处理器（只注册一次） */
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
      const buffer = Buffer.from(base64Data, "base64");
      fs.writeFileSync(filePath, buffer);
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
      const content = fs.readFileSync(filePath, "utf-8");
      return { success: true, content };
    } catch (err) {
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle("open-external", async (_event, url) => {
    const { shell } = require("electron");
    shell.openExternal(url);
  });

  // Runtime mode switching
  ipcMain.handle("get-runtime", async () => {
    return currentRuntime;
  });

  ipcMain.handle("set-runtime", async (_event, mode) => {
    if (mode !== "onnx" && mode !== "pytorch") return { success: false, error: "invalid mode" };
    if (mode === currentRuntime) return { success: true, changed: false };
    currentRuntime = mode;

    // Persist setting
    const settings = loadSettings();
    settings.runtime = mode;
    saveSettings(settings);

    // Kill the current server and wait for port to be free
    stopServer();
    await _waitForPortFree(15000);

    // Start the new server
    startServer();

    // Wait for the new server to be ready
    try {
      await waitForServer(90000);  // PyTorch can take 60s+
      return { success: true, changed: true };
    } catch (err) {
      return { success: false, changed: true, error: `Server did not start: ${err.message}` };
    }
  });

  // Settings
  const SETTINGS_PATH = path.join(app.getPath("userData"), "settings.json");

  function loadSettings() {
    try {
      if (fs.existsSync(SETTINGS_PATH)) {
        return JSON.parse(fs.readFileSync(SETTINGS_PATH, "utf-8"));
      }
    } catch (_) {}
    return { lang: "zh", runtime: "onnx", defaultVoice: "", closeToTray: true, animBg: true, darkMode: false };
  }

  function saveSettings(settings) {
    try {
      fs.mkdirSync(path.dirname(SETTINGS_PATH), { recursive: true });
      fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2), "utf-8");
    } catch (_) {}
  }

  ipcMain.handle("get-settings", async () => loadSettings());

  ipcMain.handle("set-settings", async (_event, partial) => {
    const current = loadSettings();
    Object.assign(current, partial);
    saveSettings(current);
    return { success: true };
  });

  // I18n
  ipcMain.handle("get-i18n", async (_event, lang) => {
    const langFile = path.join(__dirname, "i18n", `${lang || "zh"}.json`);
    try {
      if (fs.existsSync(langFile)) {
        return JSON.parse(fs.readFileSync(langFile, "utf-8"));
      }
    } catch (_) {}
    return JSON.parse(fs.readFileSync(path.join(__dirname, "i18n", "zh.json"), "utf-8"));
  });
}

/** 创建主窗口 */
function createMainWindow() {
  if (mainWindow) {
    mainWindow.show();
    mainWindow.focus();
    return;
  }

  mainWindow = new BrowserWindow({
    width: 1000,
    height: 720,
    minWidth: 800,
    minHeight: 500,
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
    if (!isQuitting) {
      event.preventDefault();
      mainWindow.hide();
    }
  });

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

/** 创建系统托盘 */
function createTray() {
  const iconPath = path.join(__dirname, "icons", process.platform === "darwin" ? "tray-icon.png" : "icon.png");
  let trayIcon;
  try {
    trayIcon = nativeImage.createFromPath(iconPath);
    trayIcon = trayIcon.resize({ width: 22, height: 22 });
  } catch (_) {
    // 如果没有图标，创建一个 22x22 的纯色图标
    trayIcon = nativeImage.createEmpty();
  }

  tray = new Tray(trayIcon);
  tray.setToolTip("MOSS-TTS-Nano");

  const contextMenu = Menu.buildFromTemplate([
    {
      label: "打开主界面",
      click: () => {
        if (mainWindow) {
          mainWindow.show();
          mainWindow.focus();
        } else {
          createMainWindow();
        }
      },
    },
    { type: "separator" },
    {
      label: "服务状态",
      enabled: false,
      id: "server-status",
    },
    { type: "separator" },
    {
      label: "退出",
      click: () => {
        isQuitting = true;
        stopServer();
        app.quit();
      },
    },
  ]);

  tray.setContextMenu(contextMenu);
  tray.on("double-click", () => {
    if (mainWindow) {
      mainWindow.show();
      mainWindow.focus();
    } else {
      createMainWindow();
    }
  });

  // 定期更新服务状态
  setInterval(() => {
    const statusItem = contextMenu.getMenuItemById("server-status");
    if (!statusItem) return;
    http
      .get(`${SERVER_URL}/health`, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            const info = JSON.parse(data);
            statusItem.label = `✓ 运行中  │ ${info.device || "cpu"}`;
          } catch (_) {
            statusItem.label = `✓ 运行中`;
          }
        });
      })
      .on("error", () => {
        statusItem.label = `✗ 服务未就绪`;
      });
  }, 5000);
}

// ─── 应用生命周期 ──────────────────────────────────────────────────────────

app.whenReady().then(async () => {
  registerIpcHandlers();

  // 启动后端
  startServer();

  // 等待后端就绪
  try {
    await waitForServer();
    console.log("[app] Server is ready");
  } catch (err) {
    console.error("[app] Server startup failed:", err.message);
    dialog.showErrorBox("启动失败", `语音合成服务启动超时，请检查日志。\n${err.message}`);
    // 即使超时也尝试打开界面（可能只是慢）
  }

  createTray();
  createMainWindow();
});

app.on("window-all-closed", () => {
  // macOS 上不退出，保留托盘
  if (process.platform !== "darwin") {
    isQuitting = true;
    stopServer();
    app.quit();
  }
});

app.on("before-quit", () => {
  isQuitting = true;
  stopServer();
});

app.on("activate", () => {
  // macOS 点击 Dock 图标时重新显示窗口
  if (mainWindow) {
    mainWindow.show();
  } else {
    createMainWindow();
  }
});
