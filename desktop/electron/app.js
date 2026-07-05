// ═══════════════════════════════════════════════════════════════════
// MOSS-TTS-Nano Desktop — 应用核心
// ═══════════════════════════════════════════════════════════════════

// ─── 共享命名空间（供 voices.js 等子模块使用） ────────────────
window.MOSS = {};

// ─── 常量 ────────────────────────────────────────────────────────────
let API = "http://localhost:18083";
const isMac = navigator.platform.includes("Mac");

// ─── DOM ──────────────────────────────────────────────────────────────
const $ = (s) => document.querySelector(s);
const $$ = (s) => document.querySelectorAll(s);

const dot = $("#dot");
const dotText = $("#dot-text");
const voiceSelect = $("#voice");
const textInput = $("#text-input");
const charCount = $("#char-count");
const generateBtn = $("#generate-btn");
const saveBtn = $("#save-btn");
const player = $("#player");
const audioEl = $("#audio-el");
const audioMeta = $("#audio-meta");
const statusText = $("#status");
const statusRight = $("#status-right");

const advToggle = $("#adv-toggle");
const advBody = $("#adv-body");
const audioTemp = $("#audio-temp");
const audioTempVal = $("#audio-temp-val");
const audioTopp = $("#audio-topp");
const audioToppVal = $("#audio-topp-val");
const audioRep = $("#audio-rep");
const audioRepVal = $("#audio-rep-val");
const audioTopk = $("#audio-topk");
const maxFrames = $("#max-frames");
const seed = $("#seed");

const tabs = $$(".tab");
const tabLayouts = {
  single: $("#tab-single"),
  book: $("#tab-book"),
  voices: $("#tab-voices"),
  settings: $("#tab-settings"),
};

const bookList = $("#book-list");
const importBtn = $("#import-btn");
const generateAllBtn = $("#generate-all-btn");
const exportAllBtn = $("#export-all-btn");
const bookProgress = $("#book-progress");
const bookProgressFill = $("#book-progress-fill");

const defaultVoice = $("#default-voice");
const settingsBackend = $("#settings-backend");

// ─── 状态 ────────────────────────────────────────────────────────────
let audioBase64 = null;
let currentBlob = null;
let lastStatus = "";
let chapters = [];
let currentLang = "zh";
let __ = {};
let hiddenVoiceIds = new Set();

// 音频播放管理（通过 MOSS 命名空间共享，以支持 voices.js 中的引用）
window.MOSS._currentAudio = null;
window.MOSS._stopCurrentAudio = function() {
  if (window.MOSS._currentAudio) { window.MOSS._currentAudio.pause(); window.MOSS._currentAudio = null; }
};

function t(key, vars) {
  const parts = key.split(".");
  let obj = __;
  for (const p of parts) { if (obj && typeof obj === "object") obj = obj[p]; else return key; }
  if (typeof obj !== "string") return key;
  if (vars) return obj.replace(/\{(\w+)\}/g, (_, k) => vars[k] !== undefined ? vars[k] : `{${k}}`);
  return obj;
}
function formatCount(key, n) { return t(key, { n: String(n) }); }

// ─── 辅助 ────────────────────────────────────────────────────────────
let _appVersion = "v1.0.0";

async function _loadAppVersion() {
  try { _appVersion = "v" + (await window.mossTTS.getAppVersion()); } catch (_) {}
}

function setServerOnline(ok) {
  dot.className = "titlebar-dot" + (ok ? "" : " off");
  dotText.textContent = ok ? "服务运行中" : "服务离线";
}
function setStatus(msg, isErr = false) {
  statusText.textContent = msg;
  statusText.className = isErr ? "error" : "";
}
function base64ToBlob(b64, mime) {
  const bin = atob(b64);
  const u8 = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
  return new Blob([u8], { type: mime });
}
function fmtSize(bytes) {
  if (bytes < 1024) return bytes + " B";
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
  return (bytes / 1024 / 1024).toFixed(1) + " MB";
}
function fmtDuration(secs) {
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return m > 0 ? m + ":" + String(s).padStart(2, "0") : "0:" + String(s).padStart(2, "0");
}

// ─── 服务器检测 ──────────────────────────────────────────────────────────
let serverReady = false;
async function checkServer() {
  try {
    const r = await fetch(API + "/health");
    if (r.ok) {
      const info = await r.json();
      setServerOnline(true);
      const backendInfo = info.device + " · " + (info.attn_implementation || "auto");
      settingsBackend.textContent = backendInfo;
      const aboutText = document.querySelector("#about-text");
      if (aboutText) aboutText.innerHTML = _appVersion + "<br>" + t("settings.backend") + '<span id="settings-backend">' + backendInfo + "</span>";
      if (!serverReady) { serverReady = true; window.MOSS.loadVoices(); }
      return true;
    }
  } catch (_) {}
  if (serverReady) { serverReady = false; setStatus(t("app.reconnecting"), true); }
  setServerOnline(false);
  return false;
}
setInterval(checkServer, 5000);
checkServer();

// ─── 音色列表（基础版本 — 仅填充下拉框） ────────────────────
async function loadVoices() {
  try {
    const showHidden = document.getElementById("show-hidden-voices")?.checked || false;
    const r = await fetch(API + "/api/voices?show_hidden=" + showHidden);
    const data = await r.json();
    const voices = data.voices || [];
    voiceSelect.innerHTML = '<option value="">' + t("single.selectVoice") + '</option>';
    const groups = {};
    for (const v of voices) {
      const lang = v.language || "其他";
      if (!groups[lang]) groups[lang] = [];
      groups[lang].push(v);
    }
    for (const [lang, items] of Object.entries(groups)) {
      const g = document.createElement("optgroup");
      g.label = lang;
      for (const v of items) {
        const o = document.createElement("option");
        o.value = v.id; o.textContent = v.name;
        if (v.description) o.title = v.description;
        g.appendChild(o);
      }
      voiceSelect.appendChild(g);
    }
    defaultVoice.innerHTML = '<option value="">' + t("settings.noDefault") + '</option>';
    defaultVoice.innerHTML += voiceSelect.innerHTML;
    generateBtn.disabled = false;
    setStatus(t("app.ready") + " · " + formatCount("app.loadedVoices", voices.length));
  } catch (e) {
    voiceSelect.innerHTML = '<option value="">' + t("app.cannotConnect") + '</option>';
    setStatus(t("app.loadFailed"), true);
  }
}
window.MOSS.loadVoices = loadVoices;  // voices.js 会增强此函数
window.MOSS.baseLoadVoices = loadVoices;

// ─── Tab 切换 ──────────────────────────────────────────────────────────
tabs.forEach(t => {
  t.addEventListener("click", () => {
    tabs.forEach(x => x.classList.remove("active"));
    t.classList.add("active");
    const id = t.dataset.tab;
    Object.entries(tabLayouts).forEach(([k, el]) => el.classList.toggle("active", k === id));
    if (id === "voices") window.MOSS.loadVoices();
    const themeColors = { single: "#4a7da8", book: "#4a9e62", voices: "#8a5fad", settings: "#d48c30" };
    const color = themeColors[id] || "#0071e3";
    document.documentElement.style.setProperty("--accent", color);
    document.documentElement.style.setProperty("--accent-hover", color + "dd");
  });
});

// ─── 设置标签页切换 ────────────────────────────────────────────────
document.querySelectorAll(".settings-tab").forEach(tab => {
  tab.addEventListener("click", () => {
    document.querySelectorAll(".settings-tab").forEach(t => t.classList.remove("active"));
    tab.classList.add("active");
    document.querySelectorAll(".settings-pane").forEach(p => p.classList.remove("active"));
    const pane = document.getElementById("settings-" + tab.dataset.stab);
    if (pane) pane.classList.add("active");
  });
});

// ─── 高级参数折叠 ──────────────────────────────────────────────────────
advToggle.addEventListener("click", () => { advToggle.classList.toggle("open"); advBody.classList.toggle("open"); });
audioTemp.addEventListener("input", () => { audioTempVal.textContent = parseFloat(audioTemp.value).toFixed(2); });
audioTopp.addEventListener("input", () => { audioToppVal.textContent = parseFloat(audioTopp.value).toFixed(2); });
audioRep.addEventListener("input", () => { audioRepVal.textContent = parseFloat(audioRep.value).toFixed(2); });

// ─── 参数提示 ──────────────────────────────────────────────────────────
const paramTooltip = document.getElementById("param-tooltip");
document.addEventListener("click", (e) => {
  const icon = e.target.closest(".info-icon");
  if (icon) {
    e.stopPropagation();
    const tipKey = icon.dataset.tip;
    const text = t(`single.${tipKey}`);
    if (paramTooltip.classList.contains("visible") && paramTooltip._tipKey === tipKey) {
      paramTooltip.classList.remove("visible"); return;
    }
    paramTooltip.textContent = text;
    paramTooltip._tipKey = tipKey;
    const rect = icon.getBoundingClientRect();
    paramTooltip.style.left = Math.min(rect.right + 8, window.innerWidth - 270) + "px";
    paramTooltip.style.top = Math.max(8, rect.top - 4) + "px";
    paramTooltip.classList.add("visible");
  } else {
    paramTooltip.classList.remove("visible");
  }
});

// ─── 字数统计 ─────────────────────────────────────────────────────────
textInput.addEventListener("input", () => { charCount.textContent = formatCount("single.charCount", textInput.value.length); });

// ─── 生成 ─────────────────────────────────────────────────────────────
generateBtn.addEventListener("click", generate);
async function generate() {
  const voice = voiceSelect.value;
  const text = textInput.value.trim();
  if (!voice) { setStatus(t("single.noVoice"), true); return; }
  if (!text) { setStatus(t("single.noText"), true); return; }
  generateBtn.disabled = true; generateBtn.textContent = t("single.generating");
  player.classList.remove("visible"); saveBtn.disabled = true;
  audioBase64 = null; currentBlob = null; setStatus(t("app.synthesizing"));
  try {
    const fd = new FormData();
    fd.append("voice_name", voice); fd.append("text", text);
    fd.append("audio_temperature", audioTemp.value); fd.append("audio_top_k", audioTopk.value);
    fd.append("audio_top_p", audioTopp.value); fd.append("audio_repetition_penalty", audioRep.value);
    fd.append("max_new_frames", maxFrames.value); fd.append("seed", seed.value);
    const r = await fetch(API + "/api/generate", { method: "POST", body: fd });
    const data = await r.json();
    if (!r.ok || !data.audio_base64) { setStatus(data.error || t("app.requestFailed"), true); generateBtn.disabled = false; generateBtn.textContent = t("single.generate"); return; }
    audioBase64 = data.audio_base64; currentBlob = base64ToBlob(audioBase64, "audio/wav");
    audioEl.src = URL.createObjectURL(currentBlob);
    player.classList.add("visible");
    audioMeta.textContent = fmtSize(currentBlob.size) + " · " + data.sample_rate + "Hz";
    saveBtn.disabled = false;
    const chunks = data.text_chunks || [];
    setStatus(t("single.generated") + (chunks.length > 1 ? " " + formatCount("single.chunkInfo", chunks.length) : ""));
    lastStatus = data.run_status || "";
  } catch (e) { setStatus(t("app.requestFailed") + e.message, true); }
  finally { generateBtn.disabled = false; generateBtn.textContent = t("single.generate"); }
}

// ─── 保存 ─────────────────────────────────────────────────────────────
saveBtn.addEventListener("click", async () => {
  if (!audioBase64) return;
  try {
    const fp = await window.mossTTS.saveDialog("moss_tts_output.wav");
    if (!fp) return;
    const res = await window.mossTTS.writeFile(fp, audioBase64);
    if (res.success) setStatus(t("single.saved") + fp); else setStatus(t("single.saveFailed") + res.error, true);
  } catch (e) { setStatus(t("single.saveFailed") + e.message, true); }
});

// ─── 快捷键 ───────────────────────────────────────────────────────────
document.addEventListener("keydown", (e) => {
  if ((isMac ? e.metaKey : e.ctrlKey) && e.key === "Enter") { e.preventDefault(); if (!generateBtn.disabled) generate(); }
});

// ─── 有声书 ──────────────────────────────────────────────────────────────
importBtn.addEventListener("click", async () => {
  try {
    const paths = await window.mossTTS.openFiles("选择章节文件", [{ name: "文本文件", extensions: ["txt"] }]);
    if (!paths || paths.length === 0) return;
    for (const p of paths) chapters.push({ path: p, name: p.split(/[/\\]/).pop(), status: "waiting" });
    renderBookList();
  } catch (_) {
    const input = document.createElement("input");
    input.type = "file"; input.accept = ".txt"; input.multiple = true;
    input.onchange = () => { for (const f of input.files) chapters.push({ path: f.name, name: f.name, status: "waiting", file: f }); renderBookList(); };
    input.click();
  }
});

function renderBookList() {
  if (chapters.length === 0) {
    bookList.innerHTML = '<div style="padding:24px;text-align:center;color:var(--text-muted);font-size:13px;">' + t("book.noChapters") + '</div>';
    generateAllBtn.disabled = true; exportAllBtn.disabled = true; bookProgress.style.display = "none"; return;
  }
  generateAllBtn.disabled = false;
  let html = ""; const doneCount = chapters.filter(c => c.status === "done").length;
  for (const c of chapters) {
    let icon = "⬜", dur = "";
    if (c.status === "done") { icon = "✅"; dur = c.duration || ""; }
    else if (c.status === "generating") { icon = "⏳"; dur = c.progress || "0%"; }
    html += `<div class="book-item"><span class="status-icon">${icon}</span><span class="name">${c.name}</span><span class="duration">${dur}</span>${c.status === "done" ? '<span class="play-btn">▶</span>' : ""}</div>`;
  }
  bookList.innerHTML = html;
  exportAllBtn.disabled = doneCount === 0;
  if (chapters.length > 0) { bookProgress.style.display = "block"; bookProgressFill.style.width = (doneCount / chapters.length * 100) + "%"; }
}

// ─── GitHub 仓库链接 ──────────────────────────────────────────────────
$("#repo-link")?.addEventListener("click", (e) => { e.preventDefault(); window.mossTTS.openExternal("https://github.com/CharlesShan-hub/MossTTSNanoDesktop"); });
$("#repo-link")?.addEventListener("mouseenter", function() { this.style.borderColor = "var(--accent)"; });
$("#repo-link")?.addEventListener("mouseleave", function() { this.style.borderColor = "var(--border)"; });

// ─── 推理引擎切换 ─────────────────────────────────────────────────────
const runtimeSelect = document.getElementById("runtime-select");
const runtimeDesc = document.getElementById("runtime-desc");

async function initRuntime() {
  try { const mode = await window.mossTTS.getRuntime(); runtimeSelect.value = mode; updateRuntimeDesc(mode); } catch (_) {}
}
function updateRuntimeDesc(mode) { runtimeDesc.textContent = mode === "onnx" ? t("settings.runtimeONNXDesc") : t("settings.runtimePTDesc"); }

runtimeSelect.addEventListener("change", async () => {
  const mode = runtimeSelect.value; runtimeSelect.disabled = true; runtimeSelect.style.opacity = "0.5";
  setStatus(t("settings.switchingRuntime"));
  try {
    const result = await window.mossTTS.setRuntime(mode);
    if (result.success) { updateRuntimeDesc(mode); setStatus(result.changed ? t("settings.switchedTo") + mode + " ..." : t("settings.unchanged")); }
    else { setStatus(t("settings.switchFailed") + (result.error || ""), true); }
  } catch (e) { setStatus(t("settings.switchFailed") + e.message, true); }
  runtimeSelect.disabled = false; runtimeSelect.style.opacity = "1";
});
initRuntime();

// ─── 界面语言切换 ──────────────────────────────────────────────────────
const langSelect = document.getElementById("lang-select");

function applyLang() {
  // ── Tabs ──
  document.querySelector('.tab[data-tab="single"]').textContent = t("tabs.single");
  document.querySelector('.tab[data-tab="book"]').textContent = t("tabs.book");
  document.querySelector('.tab[data-tab="voices"]').textContent = t("tabs.voices");
  document.querySelector('.tab[data-tab="settings"]').textContent = t("tabs.settings");
  // ── Single tab ──
  const voiceLabel1 = document.querySelector("#tab-single .sidebar-group:first-child label");
  if (voiceLabel1) voiceLabel1.textContent = t("single.voiceLabel");
  textInput.placeholder = t("single.textPlaceholder");
  document.querySelector("#tab-single .text-meta span:last-child").textContent = t("single.voiceInfoText");
  generateBtn.textContent = t("single.generate");
  saveBtn.textContent = t("single.save");
  document.getElementById("adv-toggle").querySelector("span:first-child").textContent = t("single.advTitle");
  document.querySelector(".param-row:nth-child(1) label").textContent = t("single.paramTemp");
  document.querySelector(".param-row:nth-child(2) label").textContent = t("single.paramTopK");
  document.querySelector(".param-row:nth-child(3) label").textContent = t("single.paramTopP");
  document.querySelector(".param-row:nth-child(4) label").textContent = t("single.paramRep");
  document.querySelector(".param-row:nth-child(5) label").textContent = t("single.paramMaxFrames");
  document.querySelector(".param-row:nth-child(6) label").textContent = t("single.paramSeed");
  // ── Book tab ──
  const bookVoiceLabel = document.querySelector("#tab-book .sidebar-group:first-child label");
  if (bookVoiceLabel) bookVoiceLabel.textContent = t("book.voiceLabel");
  const bookOpsLabel = document.querySelectorAll("#tab-book .sidebar-group label")[1];
  if (bookOpsLabel) bookOpsLabel.textContent = t("book.operations");
  document.querySelector("#import-btn").textContent = t("book.importChapters");
  document.querySelector("#generate-all-btn").textContent = t("book.generateAll");
  document.querySelector("#export-all-btn").textContent = t("book.exportAll");
  // ── Voices tab ──
  document.querySelector("#add-voice-btn").textContent = t("voices.import");
  document.querySelector("#refresh-voices-btn").textContent = t("voices.refresh");
  const vOps = document.querySelector("#tab-voices .sidebar-group:first-child label");
  if (vOps) vOps.textContent = t("voices.operations");
  const filterLabel = document.querySelector("#tab-voices .sidebar-group:nth-child(3) label");
  if (filterLabel) filterLabel.textContent = t("voices.filter");
  const searchInput = document.getElementById("voice-search");
  if (searchInput) searchInput.placeholder = t("voices.searchPlaceholder");
  const langFilter = document.getElementById("voice-lang-filter");
  if (langFilter) langFilter.options[0].text = t("voices.allLanguages");
  const vHint = document.getElementById("v-hint-label");
  if (vHint) vHint.textContent = t("voices.hint");
  const tipEl = document.querySelector("#tab-voices .sidebar-group:last-child p");
  if (tipEl) tipEl.textContent = t("voices.tip");
  const previewLabel = document.getElementById("preview-text-label");
  if (previewLabel) previewLabel.textContent = t("voices.previewLabel");
  const previewInput = document.getElementById("preview-text");
  if (previewInput) previewInput.placeholder = t("single.previewText");
  const loadingOpt = document.getElementById("voice-loading-opt");
  if (loadingOpt) loadingOpt.textContent = t("app.loading");
  const dt = document.getElementById("dot-text");
  if (dt && dt.textContent.match(/加载中|Loading/)) dt.textContent = t("app.loading");
  // ── Settings tab ──
  // Settings sidebar tabs
  document.querySelectorAll(".settings-tab").forEach(tab => {
    tab.textContent = t(`settings.${tab.dataset.stab}`);
  });
  document.querySelector("#about-label").textContent = t("settings.about");
  document.querySelector("#about-text").innerHTML = _appVersion + "<br>" + t("settings.backend") + '<span id="settings-backend">' + (settingsBackend?.textContent || t("settings.backendChecking")) + '</span>';
  const repoLinkText = document.getElementById("repo-link-text");
  if (repoLinkText) repoLinkText.textContent = t("settings.repoLink");
  // Setting items by ID
  const settingLabels = {
    "close-to-tray": ["closeToTray", "closeToTrayDesc"],
    "default-voice": ["defaultVoice", "defaultVoiceDesc"],
    "lang-select": ["langTitle", "langDesc"],
    "anim-bg-toggle": ["animBg", "animBgDesc"],
    "orb-opacity": ["orbOpacity", "orbOpacityDesc"],
    "dark-mode-toggle": ["darkMode", "darkModeDesc"],
    "runtime-select": ["runtimeTitle", "runtimeDesc"],
    "server-port": ["serverPort", "serverPortDesc"],
  };
  document.querySelectorAll(".setting-item").forEach(item => {
    const input = item.querySelector('input, select');
    if (!input) return;
    const label = item.querySelector(".setting-label");
    const desc = item.querySelector(".setting-desc");
    const keys = settingLabels[input.id];
    if (label && keys) label.textContent = t(`settings.${keys[0]}`);
    if (desc && keys) desc.textContent = t(`settings.${keys[1]}`);
  });
  if (runtimeSelect) updateRuntimeDesc(runtimeSelect.value);
  // Modal placeholders
  document.querySelector("#import-name").placeholder = t("voices.importNamePlaceholder");
  document.querySelector("#import-lang").placeholder = t("voices.importLangPlaceholder");
  document.querySelector("#import-desc").placeholder = t("voices.importDescPlaceholder");
  renderBookList();
  window.MOSS.renderVoiceGrid?.();
  if (langSelect) langSelect.value = currentLang;
}

langSelect.addEventListener("change", async () => {
  currentLang = langSelect.value;
  try { __ = await window.mossTTS.getI18n(currentLang); } catch (_) {}
  applyLang();
  window.mossTTS.setSettings({ lang: currentLang }).catch(() => {});
});

// ─── 设置处理 ──────────────────────────────────────────────────────────
document.getElementById("close-to-tray")?.addEventListener("change", () => { window.mossTTS.setSettings({ closeToTray: document.getElementById("close-to-tray").checked }).catch(() => {}); });
document.getElementById("default-voice")?.addEventListener("change", () => { window.mossTTS.setSettings({ defaultVoice: document.getElementById("default-voice").value }).catch(() => {}); });

const animBg = document.getElementById("anim-bg");
const animBgToggle = document.getElementById("anim-bg-toggle");
if (animBgToggle) {
  animBgToggle.addEventListener("change", () => { animBg.classList.toggle("on", animBgToggle.checked); window.mossTTS.setSettings({ animBg: animBgToggle.checked }).catch(() => {}); });
}

const orbOpacityInput = document.getElementById("orb-opacity");
function applyOrbOpacity(val) {
  const v = parseFloat(val);
  if (isNaN(v)) return;
  document.querySelectorAll(".anim-bg .orb").forEach(el => el.style.opacity = v);
}
if (orbOpacityInput) {
  orbOpacityInput.addEventListener("change", () => { applyOrbOpacity(orbOpacityInput.value); window.mossTTS.setSettings({ orbOpacity: orbOpacityInput.value }).catch(() => {}); });
}

const darkModeToggle = document.getElementById("dark-mode-toggle");
if (darkModeToggle) {
  darkModeToggle.addEventListener("change", () => { document.documentElement.classList.toggle("dark-mode", darkModeToggle.checked); window.mossTTS.setSettings({ darkMode: darkModeToggle.checked }).catch(() => {}); });
}

const serverPortInput = document.getElementById("server-port");
if (serverPortInput) {
  serverPortInput.addEventListener("change", () => {
    const val = parseInt(serverPortInput.value, 10);
    if (isNaN(val) || val < 1024 || val > 65535) { setStatus("端口号需在 1024–65535 之间", true); serverPortInput.value = API.split(":").pop(); return; }
    setStatus("正在切换端口，重启后端服务...");
    window.mossTTS.setSettings({ serverPort: val }).then(() => { API = `http://localhost:${val}`; setStatus(`端口已切换至 ${val}，等待服务就绪...`); checkServer(); }).catch(() => {});
  });
}

// 覆盖状态函数（国际化后需要调用 t()）
const _origSetStatus = setStatus;
setStatus = function(msg, isErr) { statusText.textContent = msg; statusText.className = isErr ? "error" : ""; };
const _origSetServerOnline = setServerOnline;
setServerOnline = function(ok) { dot.className = "titlebar-dot" + (ok ? "" : " off"); dotText.textContent = ok ? t("app.online") : t("app.offline"); };

// ─── 暴露给子模块（voices.js） ──────────────────────────────────
Object.assign(window.MOSS, {
  $, t, setStatus, base64ToBlob, formatCount,
  loadVoices, baseLoadVoices: loadVoices,
});
Object.defineProperty(window.MOSS, "API", { get: () => API });

// ─── 初始化 ──────────────────────────────────────────────────────────────
async function initApp() {
  try {
    const s = await window.mossTTS.getSettings();
    if (s.lang) currentLang = s.lang;
    if (s.runtime && document.getElementById("runtime-select")) document.getElementById("runtime-select").value = s.runtime;
    if (s.defaultVoice && document.getElementById("default-voice")) document.getElementById("default-voice").value = s.defaultVoice;
    if (s.closeToTray !== undefined && document.getElementById("close-to-tray")) document.getElementById("close-to-tray").checked = s.closeToTray;
    const animOn = s.animBg !== false;
    if (document.getElementById("anim-bg-toggle")) document.getElementById("anim-bg-toggle").checked = animOn;
    if (animOn) document.getElementById("anim-bg")?.classList.add("on");
    if (s.orbOpacity && document.getElementById("orb-opacity")) { document.getElementById("orb-opacity").value = s.orbOpacity; applyOrbOpacity(s.orbOpacity); }
    if (s.darkMode) { document.getElementById("dark-mode-toggle").checked = true; document.documentElement.classList.add("dark-mode"); }
    if (s.serverPort) { API = `http://localhost:${s.serverPort}`; const pi = document.getElementById("server-port"); if (pi) pi.value = s.serverPort; }
  } catch (_) {}
  try { __ = await window.mossTTS.getI18n(currentLang); } catch (_) {}
  await _loadAppVersion();
  applyLang();
  document.documentElement.style.setProperty("--accent", "#4a7da8");
  document.documentElement.style.setProperty("--accent-hover", "#4a7da8dd");
}

setInterval(() => { statusRight.textContent = new Date().toLocaleTimeString(); }, 1000);
initApp();
