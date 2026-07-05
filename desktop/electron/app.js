// ═══════════════════════════════════════════════════════════════════
// MOSS-TTS-Nano Desktop — App
// ═══════════════════════════════════════════════════════════════════

// ─── 常量 ────────────────────────────────────────────────────────────
const API = "http://localhost:18083";
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
let __ = {};  // i18n strings
let hiddenVoiceIds = new Set();  // IDs of hidden voices, maintained for safety

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
  if (bytes < 1024*1024) return (bytes/1024).toFixed(1) + " KB";
  return (bytes/1024/1024).toFixed(1) + " MB";
}
function fmtDuration(secs) {
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return m > 0 ? m + ":" + String(s).padStart(2,"0") : "0:" + String(s).padStart(2,"0");
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
      if (aboutText) aboutText.innerHTML = t("settings.version") + "<br>" + t("settings.backend") + '<span id="settings-backend">' + backendInfo + "</span>";
      if (!serverReady) { serverReady = true; loadVoices(); }
      return true;
    }
  } catch (_) {}
  if (serverReady) { serverReady = false; setStatus(t("app.reconnecting"), true); }
  setServerOnline(false);
  return false;
}
setInterval(checkServer, 5000);
checkServer();

// ─── 音色列表 ────────────────────────────────────────────────────────────
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

// ─── Tab 切换 ──────────────────────────────────────────────────────────
tabs.forEach(t => {
  t.addEventListener("click", () => {
    tabs.forEach(x => x.classList.remove("active"));
    t.classList.add("active");
    const id = t.dataset.tab;
    Object.entries(tabLayouts).forEach(([k, el]) => el.classList.toggle("active", k === id));
    if (id === "voices") loadVoices();
    // Update accent color for current tab
    const themeColors = { single: "#4a7da8", book: "#4a9e62", voices: "#8a5fad", settings: "#d48c30" };
    const color = themeColors[id] || "#0071e3";
    document.documentElement.style.setProperty("--accent", color);
    // Compute slightly darker hover
    document.documentElement.style.setProperty("--accent-hover", color + "dd");
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
      paramTooltip.classList.remove("visible");
      return;
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

// ─── 音色管理 ────────────────────────────────────────────────────────────
let allVoices = [];
let editingVoiceId = null, deletingVoiceId = null;

function renderVoiceGrid() {
  const grid = $("#voice-grid");
  const query = (document.getElementById("voice-search")?.value || "").toLowerCase().trim();
  const langFilter = document.getElementById("voice-lang-filter")?.value || "";

  if (allVoices.length === 0) { grid.innerHTML = '<div style="padding:32px;text-align:center;color:var(--text-muted);font-size:13px;">' + t("voices.noVoices") + '</div>'; return; }

  // Filter
  let filtered = allVoices;
  if (query) filtered = filtered.filter(v => (v.name || "").toLowerCase().includes(query));
  if (langFilter) filtered = filtered.filter(v => (v.language || "其他") === langFilter);

  if (filtered.length === 0) {
    grid.innerHTML = '<div style="padding:32px;text-align:center;color:var(--text-muted);font-size:13px;">没有匹配的音色</div>';
    return;
  }

  const groups = {};
  for (const v of filtered) {
    const lang = v.language || "其他";
    if (!groups[lang]) groups[lang] = [];
    groups[lang].push(v);
  }
  if (!window._voiceCollapsed) window._voiceCollapsed = {};
  let html = "";
  for (const [lang, items] of Object.entries(groups)) {
    const collapsed = window._voiceCollapsed[lang] || false;
    const arrow = collapsed ? "▸" : "▾";
    const cardStyle = collapsed ? 'style="display:none;"' : "";
    html += `<div class="voice-group-header" data-lang="${lang}" style="font-size:12px;font-weight:600;color:var(--text-secondary);padding:8px 0 4px;text-transform:uppercase;letter-spacing:0.5px;cursor:pointer;user-select:none;"><span class="voice-group-arrow" style="display:inline-block;width:14px;">${arrow}</span>${lang} (${items.length})</div>`;
    for (const v of items) {
      const eyeIcon = v.hidden ? "👁️‍🗨️" : "👁️";
      const eyeTitle = v.hidden ? t("voices.unhide") : t("voices.hide");
      const vStyle = v.hidden ? "opacity:0.5;" : "";
      html += `<div class="voice-card" ${cardStyle} style="${vStyle}"><span class="lang-tag">${lang}</span><div style="flex:1;min-width:0;"><div class="vname">${v.name}</div><div class="vdesc">${v.description || ""}</div></div><div class="vactions"><button class="voice-btn" data-id="${v.id}" data-action="preview" title="合成试听">▶</button><button class="voice-btn" data-id="${v.id}" data-action="listen" title="播放参考音频">🔊</button><button class="voice-btn" data-id="${v.id}" data-action="edit" title="编辑">✏️</button><button class="voice-btn" data-id="${v.id}" data-action="hide" title="${eyeTitle}" style="font-size:14px;">${eyeIcon}</button><button class="voice-btn" data-id="${v.id}" data-action="delete" title="删除" style="color:var(--error);font-size:14px;">🗑</button></div></div>`;
    }
  }
  grid.innerHTML = html;
  // Bind group header click to collapse/expand
  grid.querySelectorAll(".voice-group-header").forEach(hdr => {
    hdr.addEventListener("click", () => {
      const lang = hdr.dataset.lang;
      window._voiceCollapsed[lang] = !window._voiceCollapsed[lang];
      renderVoiceGrid();
    });
  });
  grid.querySelectorAll(".voice-btn").forEach(btn => {
    btn.addEventListener("click", async () => {
      const id = btn.dataset.id, action = btn.dataset.action;
      if (action === "preview") await previewVoice(id, btn);
      else if (action === "listen") await listenVoice(id);
      else if (action === "hide") await toggleHidden(id);
      else if (action === "edit") openEditModal(id);
      else if (action === "delete") openDeleteModal(id);
    });
  });
}

async function previewVoice(id, btn) {
  btn.disabled = true; btn.textContent = "⏳";
  setStatus(t("voices.previewGenerating"));
  try {
    const fd = new FormData();
    fd.append("voice_name", id); fd.append("text", document.getElementById("preview-text")?.value || t("single.previewText")); fd.append("audio_temperature", "0.8");
    const r = await fetch(API + "/api/generate", { method: "POST", body: fd });
    const data = await r.json();
    if (data.audio_base64) {
      const blob = base64ToBlob(data.audio_base64, "audio/wav");
      const a = new Audio(URL.createObjectURL(blob));
      a.play().catch(() => {}); setStatus(t("voices.previewPlaying"));
      a.onended = () => setStatus(t("voices.previewEnded"));
    }
  } catch (e) { setStatus(t("voices.previewFailed") + e.message, true); }
  btn.disabled = false; btn.textContent = "▶";
}

async function listenVoice(id) {
  try {
    const r = await fetch(API + "/api/voices/" + encodeURIComponent(id) + "/audio");
    if (!r.ok) { setStatus(t("voices.listenFailed") + "404", true); return; }
    const blob = await r.blob();
    const a = new Audio(URL.createObjectURL(blob));
    a.play().catch(() => {}); setStatus(t("voices.listenRef"));
    a.onended = () => setStatus(t("voices.listenEnded"));
  } catch (e) { setStatus(t("voices.listenFailed") + e.message, true); }
}

async function toggleHidden(id) {
  try {
    const r = await fetch(API + "/api/voices/" + encodeURIComponent(id) + "/toggle-hidden", { method: "PATCH" });
    const data = await r.json();
    if (!r.ok) { setStatus("操作失败", true); return; }
    setStatus(data.hidden ? t("voices.hide") : t("voices.unhide"));
    await loadVoices();
  } catch (e) { setStatus(t("voices.hide") + " " + e.message, true); }
}

function openImportModal() {
  $("#import-name").value = ""; $("#import-lang").value = ""; $("#import-desc").value = ""; $("#import-file").value = t("voices.importNoFile");
  document.getElementById("import-file-input").value = "";
  document.getElementById("modal-import").classList.add("visible");
  setTimeout(() => $("#import-name").focus(), 100);
}
function closeImportModal() { document.getElementById("modal-import").classList.remove("visible"); }
document.getElementById("import-file-input").addEventListener("change", function() { if (this.files && this.files[0]) $("#import-file").value = this.files[0].name; });

async function submitImport() {
  const name = $("#import-name").value.trim(), lang = $("#import-lang").value.trim(), desc = $("#import-desc").value.trim();
  const fileInput = document.getElementById("import-file-input");
  if (!name) { setStatus(t("voices.nameRequired"), true); return; }
  if (!fileInput.files || !fileInput.files[0]) { setStatus(t("voices.fileRequired"), true); return; }
  const submitBtn = $("#import-submit-btn");
  submitBtn.disabled = true; submitBtn.textContent = t("voices.importing"); setStatus(t("voices.importing"));
  try {
    const fd = new FormData(); fd.append("name", name); fd.append("language", lang || "自定义"); fd.append("description", desc); fd.append("audio_file", fileInput.files[0]);
    const r = await fetch(API + "/api/voices", { method: "POST", body: fd }); const data = await r.json();
    if (!r.ok) { setStatus(t("voices.importFailed") + (data.error || r.statusText), true); submitBtn.disabled = false; submitBtn.textContent = t("voices.submitImport"); return; }
    setStatus(t("voices.importSucceed") + name); closeImportModal(); await loadVoices();
  } catch (e) { setStatus(t("voices.importFailed") + e.message, true); }
  submitBtn.disabled = false; submitBtn.textContent = t("voices.submitImport");
}

function openEditModal(voiceId) {
  const voice = allVoices.find(v => v.id === voiceId); if (!voice) return;
  editingVoiceId = voiceId;
  $("#edit-name").value = voice.name || voice.id; $("#edit-lang").value = voice.language || ""; $("#edit-desc").value = voice.description || ""; $("#edit-file").value = "不更换";
  document.getElementById("edit-file-input").value = "";
  document.getElementById("modal-edit").classList.add("visible"); setTimeout(() => $("#edit-name").focus(), 100);
}
function closeEditModal() { document.getElementById("modal-edit").classList.remove("visible"); editingVoiceId = null; }
document.getElementById("edit-file-input").addEventListener("change", function() { if (this.files && this.files[0]) $("#edit-file").value = this.files[0].name; });

async function submitEdit() {
  if (!editingVoiceId) return;
  const name = $("#edit-name").value.trim(), lang = $("#edit-lang").value.trim(), desc = $("#edit-desc").value.trim();
  const fileInput = document.getElementById("edit-file-input");
  const submitBtn = $("#edit-submit-btn"); submitBtn.disabled = true; submitBtn.textContent = t("voices.saving"); setStatus(t("voices.saving"));
  try {
    const fd = new FormData();
    if (name) fd.append("name", name); if (lang) fd.append("language", lang); if (desc) fd.append("description", desc);
    if (fileInput.files && fileInput.files[0]) fd.append("audio_file", fileInput.files[0]);
    const r = await fetch(API + "/api/voices/" + encodeURIComponent(editingVoiceId), { method: "PUT", body: fd }); const data = await r.json();
    if (!r.ok) { setStatus(t("voices.saveErr") + (data.error || r.statusText), true); submitBtn.disabled = false; submitBtn.textContent = t("voices.submitEdit"); return; }
    setStatus(t("voices.saved_")); closeEditModal(); await loadVoices();
  } catch (e) { setStatus(t("voices.saveErr") + e.message, true); }
  submitBtn.disabled = false; submitBtn.textContent = t("voices.submitEdit");
}

function openDeleteModal(voiceId) {
  const voice = allVoices.find(v => v.id === voiceId); if (!voice) return;
  deletingVoiceId = voiceId; document.getElementById("delete-voice-name").textContent = voice.name || voice.id;
  document.getElementById("modal-delete").classList.add("visible");
}
function closeDeleteModal() { document.getElementById("modal-delete").classList.remove("visible"); deletingVoiceId = null; }

async function submitDelete() {
  if (!deletingVoiceId) return;
  const submitBtn = $("#delete-submit-btn"); submitBtn.disabled = true; submitBtn.textContent = t("voices.deleting");
  try {
    const r = await fetch(API + "/api/voices/" + encodeURIComponent(deletingVoiceId), { method: "DELETE" }); const data = await r.json();
    if (!r.ok) { setStatus(t("voices.deleteErr") + (data.error || r.statusText), true); submitBtn.disabled = false; submitBtn.textContent = t("voices.delete_"); return; }
    setStatus(t("voices.deleted_") + (data.deleted || "")); closeDeleteModal(); await loadVoices();
  } catch (e) { setStatus(t("voices.deleteErr") + e.message, true); }
  submitBtn.disabled = false; submitBtn.textContent = t("voices.delete_");
}

$("#refresh-voices-btn").addEventListener("click", async () => { setStatus(t("voices.refreshed")); await loadVoices(); setStatus(t("voices.refreshed") + " " + formatCount("voices.count", allVoices.length)); });
$("#add-voice-btn").addEventListener("click", openImportModal);
document.getElementById("voice-search")?.addEventListener("input", () => renderVoiceGrid());
document.getElementById("voice-lang-filter")?.addEventListener("change", () => renderVoiceGrid());

const origLoadVoices = loadVoices;
loadVoices = async function() {
  await origLoadVoices.call(this);
  $("#voice-book").innerHTML = voiceSelect.innerHTML;

  // Fetch ALL voices (including hidden) for the voice grid page
  try {
    const r = await fetch(API + "/api/voices?show_hidden=true");
    const allData = await r.json();
    allVoices = allData.voices || [];
    hiddenVoiceIds = new Set(allVoices.filter(v => v.hidden).map(v => v.id));

    // Populate language filter dropdown
    const langFilter = document.getElementById("voice-lang-filter");
    if (langFilter) {
      const langs = new Set(allVoices.map(v => v.language || "其他"));
      const currentVal = langFilter.value;
      langFilter.innerHTML = '<option value="">' + t("voices.allLanguages") + '</option>';
      for (const l of [...langs].sort()) {
        const o = document.createElement("option");
        o.value = l; o.textContent = l;
        langFilter.appendChild(o);
      }
      langFilter.value = currentVal || "";
    }
  } catch (_) { allVoices = []; }

  // Double-check no hidden voice leaks into dropdowns
  const filterDropdown = (sel) => {
    if (!sel) return;
    const opts = sel.querySelectorAll("option");
    opts.forEach(o => {
      if (o.value && hiddenVoiceIds.has(o.value)) o.remove();
    });
  };
  filterDropdown(voiceSelect);
  filterDropdown($("#voice-book"));
  filterDropdown(document.getElementById("default-voice"));

  renderVoiceGrid();
};

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
  // ── Settings tab ──
  document.querySelector("#settings-section-label").textContent = t("settings.preferences");
  document.querySelector("#about-label").textContent = t("settings.about");
  document.querySelector("#about-text").innerHTML = t("settings.version") + "<br>" + t("settings.backend") + '<span id="settings-backend">检测中...</span>';
  const s1 = document.querySelector(".setting-item:nth-child(1) .setting-label");
  const s1d = document.querySelector(".setting-item:nth-child(1) .setting-desc");
  if (s1) s1.textContent = t("settings.startup");
  if (s1d) s1d.textContent = t("settings.startupDesc");
  const s2 = document.querySelector(".setting-item:nth-child(2) .setting-label");
  const s2d = document.querySelector(".setting-item:nth-child(2) .setting-desc");
  if (s2) s2.textContent = t("settings.closeToTray");
  if (s2d) s2d.textContent = t("settings.closeToTrayDesc");
  const s3 = document.querySelector(".setting-item:nth-child(3) .setting-label");
  const s3d = document.querySelector(".setting-item:nth-child(3) .setting-desc");
  if (s3) s3.textContent = t("settings.defaultVoice");
  if (s3d) s3d.textContent = t("settings.defaultVoiceDesc");
  const s4 = document.querySelector(".setting-item:nth-child(4) .setting-label");
  const s4d = document.querySelector(".setting-item:nth-child(4) .setting-desc");
  if (s4) s4.textContent = t("settings.runtimeTitle");
  if (s4d) s4d.textContent = t("settings.runtimeDesc");
  const s5 = document.querySelector(".setting-item:nth-child(5) .setting-label");
  const s5d = document.querySelector(".setting-item:nth-child(5) .setting-desc");
  if (s5) s5.textContent = t("settings.langTitle");
  if (s5d) s5d.textContent = t("settings.langDesc");
  const s6 = document.querySelector(".setting-item:nth-child(6) .setting-label");
  const s6d = document.querySelector(".setting-item:nth-child(6) .setting-desc");
  if (s6) s6.textContent = t("settings.animBg");
  if (s6d) s6d.textContent = t("settings.animBgDesc");
  const s7 = document.querySelector(".setting-item:nth-child(7) .setting-label");
  const s7d = document.getElementById("dark-mode-desc");
  if (s7) s7.textContent = t("settings.darkMode");
  if (s7d) s7d.textContent = t("settings.darkModeDesc");
  // Update runtime desc too
  if (runtimeSelect) updateRuntimeDesc(runtimeSelect.value);
  // Modal placeholders
  document.querySelector("#import-name").placeholder = t("voices.importNamePlaceholder");
  document.querySelector("#import-lang").placeholder = t("voices.importLangPlaceholder");
  document.querySelector("#import-desc").placeholder = t("voices.importDescPlaceholder");
  renderVoiceGrid(); renderBookList();
  if (langSelect) langSelect.value = currentLang;
}

langSelect.addEventListener("change", async () => {
  currentLang = langSelect.value;
  try { __ = await window.mossTTS.getI18n(currentLang); } catch (_) {}
  applyLang();
  window.mossTTS.setSettings({ lang: currentLang }).catch(() => {});
});
document.getElementById("auto-start")?.addEventListener("change", () => { window.mossTTS.setSettings({ autoStart: document.getElementById("auto-start").checked }).catch(() => {}); });
document.getElementById("close-to-tray")?.addEventListener("change", () => { window.mossTTS.setSettings({ closeToTray: document.getElementById("close-to-tray").checked }).catch(() => {}); });
document.getElementById("default-voice")?.addEventListener("change", () => { window.mossTTS.setSettings({ defaultVoice: document.getElementById("default-voice").value }).catch(() => {}); });

// Animated background toggle
const animBg = document.getElementById("anim-bg");
const animBgToggle = document.getElementById("anim-bg-toggle");
if (animBgToggle) {
  animBgToggle.addEventListener("change", () => {
    animBg.classList.toggle("on", animBgToggle.checked);
    window.mossTTS.setSettings({ animBg: animBgToggle.checked }).catch(() => {});
  });
}

// Dark mode toggle
const darkModeToggle = document.getElementById("dark-mode-toggle");
if (darkModeToggle) {
  darkModeToggle.addEventListener("change", () => {
    document.documentElement.classList.toggle("dark-mode", darkModeToggle.checked);
    window.mossTTS.setSettings({ darkMode: darkModeToggle.checked }).catch(() => {});
  });
}

// GitHub repo link
document.getElementById("repo-link")?.addEventListener("click", (e) => {
  e.preventDefault();
  window.mossTTS.openExternal("https://github.com/CharlesShan-hub/MossTTSNanoDesktop");
});

const _origSetStatus = setStatus;
setStatus = function(msg, isErr) { statusText.textContent = msg; statusText.className = isErr ? "error" : ""; };
const _origSetServerOnline = setServerOnline;
setServerOnline = function(ok) { dot.className = "titlebar-dot" + (ok ? "" : " off"); dotText.textContent = ok ? t("app.online") : t("app.offline"); };

// ─── 初始化 ──────────────────────────────────────────────────────────────
async function initApp() {
  try {
    const s = await window.mossTTS.getSettings();
    if (s.lang) currentLang = s.lang;
    if (s.runtime && document.getElementById("runtime-select")) document.getElementById("runtime-select").value = s.runtime;
    if (s.defaultVoice && document.getElementById("default-voice")) document.getElementById("default-voice").value = s.defaultVoice;
    if (s.closeToTray !== undefined && document.getElementById("close-to-tray")) document.getElementById("close-to-tray").checked = s.closeToTray;
    // Animated background (default on)
    const animOn = s.animBg !== false;
    if (document.getElementById("anim-bg-toggle")) document.getElementById("anim-bg-toggle").checked = animOn;
    if (animOn) document.getElementById("anim-bg")?.classList.add("on");
    // Dark mode
    if (s.darkMode) {
      document.getElementById("dark-mode-toggle").checked = true;
      document.documentElement.classList.add("dark-mode");
    }
  } catch (_) {}
  try { __ = await window.mossTTS.getI18n(currentLang); } catch (_) {}
  applyLang();
  // Set initial accent color (single tab = blue)
  document.documentElement.style.setProperty("--accent", "#4a7da8");
  document.documentElement.style.setProperty("--accent-hover", "#4a7da8dd");
}

setInterval(() => { statusRight.textContent = new Date().toLocaleTimeString(); }, 1000);
initApp();
