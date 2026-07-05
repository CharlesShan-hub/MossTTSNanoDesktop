// ═══════════════════════════════════════════════════════════════════
// MOSS-TTS-Nano Desktop — 后端服务管理
// ═══════════════════════════════════════════════════════════════════

const { spawn } = require("child_process");
const http = require("http");
const path = require("path");
const fs = require("fs");

// ─── 状态 ──────────────────────────────────────────────────────────────────
let serverPort = 18083;
let SERVER_URL = `http://localhost:${serverPort}`;
let currentRuntime = "onnx";
let serverProcess = null;
let serverStarting = false;
let isQuitting = false;  // 应用级别，由 main.js 设置

const POLL_INTERVAL_MS = 500;
const POLL_TIMEOUT_MS = 30_000;

// ─── 工具函数 ──────────────────────────────────────────────────────────────

/** 找到 Python 后端二进制文件 */
function findServerBinary(resourcesDir, isPackaged) {
  if (!isPackaged || !resourcesDir) return null;
  const platform = process.platform;
  const binName = platform === "win32" ? "moss-tts-server.exe" : "moss-tts-server";
  const searchPaths = [
    path.join(resourcesDir, "server", binName),
    path.join(resourcesDir, "server", platform, binName),
  ];
  for (const p of searchPaths) {
    try { fs.accessSync(p); return p; } catch (_) {}
  }
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

/** 启动 Python 后端 */
function startServer(resourcesRoot, isPackaged) {
  if (serverStarting) {
    console.log("[server] already starting, skipping");
    return;
  }
  serverStarting = true;

  SERVER_URL = `http://localhost:${serverPort}`;

  const binary = findServerBinary(
    isPackaged ? path.join(process.resourcesPath, "server") : null,
    isPackaged
  );

  if (binary) {
    serverProcess = spawn(binary, ["--port", String(serverPort)], {
      stdio: ["ignore", "pipe", "pipe"],
    });
  } else {
    serverProcess = spawn("pixi", ["run", "python", "src/app.py", "--runtime", currentRuntime, "--port", String(serverPort)], {
      cwd: resourcesRoot,
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
  const proc = serverProcess;
  if (!proc) {
    serverStarting = false;
    return;
  }
  serverProcess = null;
  serverStarting = false;
  proc.kill("SIGTERM");
  const forceKillTimer = setTimeout(() => {
    try { proc.kill("SIGKILL"); } catch (_) {}
  }, 3000);
  proc.on("exit", () => clearTimeout(forceKillTimer));
}

/** 等待端口释放（仅 macOS） */
function waitForPortFree(timeoutMs) {
  return new Promise((resolve) => {
    const start = Date.now();
    const check = () => {
      try {
        const occupied = require("child_process").execSync(
          `lsof -ti:${serverPort} 2>/dev/null || true`,
          { encoding: "utf-8" }
        ).trim();
        if (!occupied) return resolve();
      } catch (_) {}
      if (Date.now() - start > timeoutMs) return resolve();
      setTimeout(check, 500);
    };
    check();
  });
}

/** 获取当前端口 */
function getPort() { return serverPort; }

/** 设置端口（在重启前调用） */
function setPort(port) { serverPort = port; }

/** 获取运行时模式 */
function getRuntime() { return currentRuntime; }

/** 设置运行时模式 */
function setRuntime(mode) { currentRuntime = mode; }

/** 设置退出标志 */
function setQuitting(val) { isQuitting = val; }

/** 获取退出标志 */
function getQuitting() { return isQuitting; }

module.exports = {
  startServer,
  stopServer,
  waitForServer,
  waitForPortFree,
  getPort,
  setPort,
  getRuntime,
  setRuntime,
  setQuitting,
  getQuitting,
  POLL_TIMEOUT_MS,
  POLL_INTERVAL_MS,
};
