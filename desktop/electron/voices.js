// ═══════════════════════════════════════════════════════════════════
// MOSS-TTS-Nano Desktop — 音色管理（网格、导入、编辑、删除、试听）
// ═══════════════════════════════════════════════════════════════════

// 通过 window.MOSS 共享的 API：
//   MOSS.$, MOSS.t, MOSS.API, MOSS.setStatus, MOSS.base64ToBlob,
//   MOSS._currentAudio, MOSS._stopCurrentAudio, MOSS.formatCount,
//   MOSS.baseLoadVoices — 由 app.js 在加载完成后设置

// ─── 状态 ──────────────────────────────────────────────────────────────────
let allVoices = [];
let editingVoiceId = null;
let deletingVoiceId = null;
let hiddenVoiceIds = new Set();

const _$ = (s) => window.MOSS.$(s);
const _t = (k, v) => window.MOSS.t(k, v);
const _setStatus = (m, e) => window.MOSS.setStatus(m, e);

// ─── 网格渲染 ────────────────────────────────────────────────────────────
function renderVoiceGrid() {
  const grid = _$("#voice-grid");

  const query = (document.getElementById("voice-search")?.value || "").toLowerCase().trim();
  const langFilter = document.getElementById("voice-lang-filter")?.value || "";

  if (allVoices.length === 0) {
    grid.innerHTML = '<div style="padding:32px;text-align:center;color:var(--text-muted);font-size:13px;">' + _t("voices.noVoices") + '</div>';
    return;
  }

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
      const eyeTitle = v.hidden ? _t("voices.unhide") : _t("voices.hide");
      const vStyle = v.hidden ? "opacity:0.5;" : "";
      html += `<div class="voice-card" ${cardStyle} style="${vStyle}"><span class="lang-tag">${lang}</span><div style="flex:1;min-width:0;"><div class="vname">${v.name}</div><div class="vdesc">${v.description || ""}</div></div><div class="vactions"><button class="voice-btn" data-id="${v.id}" data-action="preview" title="合成试听">▶</button><button class="voice-btn" data-id="${v.id}" data-action="listen" title="播放参考音频">🔊</button><button class="voice-btn" data-id="${v.id}" data-action="edit" title="编辑">✏️</button><button class="voice-btn" data-id="${v.id}" data-action="hide" title="${eyeTitle}" style="font-size:14px;">${eyeIcon}</button><button class="voice-btn" data-id="${v.id}" data-action="delete" title="删除" style="color:var(--error);font-size:14px;">🗑</button></div></div>`;
    }
  }
  grid.innerHTML = html;

  grid.querySelectorAll(".voice-group-header").forEach(hdr => {
    hdr.addEventListener("click", () => {
      window._voiceCollapsed[hdr.dataset.lang] = !window._voiceCollapsed[hdr.dataset.lang];
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

// Expose to MOSS namespace for app.js (applyLang)
window.MOSS.renderVoiceGrid = renderVoiceGrid;

// ─── 试听 ────────────────────────────────────────────────────────────────
async function previewVoice(id, btn) {
  btn.disabled = true; btn.textContent = "⏳";
  _setStatus(_t("voices.previewGenerating"));
  try {
    const fd = new FormData();
    fd.append("voice_name", id);
    fd.append("text", document.getElementById("preview-text")?.value || _t("single.previewText"));
    fd.append("audio_temperature", "0.8");
    const r = await fetch(window.MOSS.API + "/api/generate", { method: "POST", body: fd });
    const data = await r.json();
    if (data.audio_base64) {
      const blob = window.MOSS.base64ToBlob(data.audio_base64, "audio/wav");
      window.MOSS._stopCurrentAudio();
      const a = new Audio(URL.createObjectURL(blob));
      window.MOSS._currentAudio = a;
      a.play().catch(() => {});
      _setStatus(_t("voices.previewPlaying"));
      a.onended = () => { _setStatus(_t("voices.previewEnded")); if (window.MOSS._currentAudio === a) window.MOSS._currentAudio = null; };
    }
  } catch (e) { _setStatus(_t("voices.previewFailed") + e.message, true); }
  btn.disabled = false; btn.textContent = "▶";
}

async function listenVoice(id) {
  try {
    const r = await fetch(window.MOSS.API + "/api/voices/" + encodeURIComponent(id) + "/audio");
    if (!r.ok) { _setStatus(_t("voices.listenFailed") + "404", true); return; }
    const blob = await r.blob();
    window.MOSS._stopCurrentAudio();
    const a = new Audio(URL.createObjectURL(blob));
    window.MOSS._currentAudio = a;
    a.play().catch(() => {});
    _setStatus(_t("voices.listenRef"));
    a.onended = () => { _setStatus(_t("voices.listenEnded")); if (window.MOSS._currentAudio === a) window.MOSS._currentAudio = null; };
  } catch (e) { _setStatus(_t("voices.listenFailed") + e.message, true); }
}

// ─── 隐藏/显示 ──────────────────────────────────────────────────────────
async function toggleHidden(id) {
  try {
    const r = await fetch(window.MOSS.API + "/api/voices/" + encodeURIComponent(id) + "/toggle-hidden", { method: "PATCH" });
    const data = await r.json();
    if (!r.ok) { _setStatus("操作失败", true); return; }
    _setStatus(data.hidden ? _t("voices.hide") : _t("voices.unhide"));
    await window.MOSS.loadVoices();
  } catch (e) { _setStatus(_t("voices.hide") + " " + e.message, true); }
}

// ─── 导入弹窗 ────────────────────────────────────────────────────────────
function openImportModal() {
  _$("#import-name").value = "";
  _$("#import-lang").value = "";
  _$("#import-desc").value = "";
  _$("#import-file").value = _t("voices.importNoFile");
  document.getElementById("import-file-input").value = "";
  document.getElementById("modal-import").classList.add("visible");
  setTimeout(() => _$("#import-name").focus(), 100);
}

function closeImportModal() {
  document.getElementById("modal-import").classList.remove("visible");
}

document.getElementById("import-file-input").addEventListener("change", function() {
  if (this.files && this.files[0]) _$("#import-file").value = this.files[0].name;
});

async function submitImport() {
  const name = _$("#import-name").value.trim();
  const lang = _$("#import-lang").value.trim();
  const desc = _$("#import-desc").value.trim();
  const fileInput = document.getElementById("import-file-input");
  if (!name) { _setStatus(_t("voices.nameRequired"), true); return; }
  if (!fileInput.files || !fileInput.files[0]) { _setStatus(_t("voices.fileRequired"), true); return; }
  const btn = _$("#import-submit-btn");
  btn.disabled = true; btn.textContent = _t("voices.importing");
  _setStatus(_t("voices.importing"));
  try {
    const fd = new FormData();
    fd.append("name", name); fd.append("language", lang || "自定义");
    fd.append("description", desc); fd.append("audio_file", fileInput.files[0]);
    const r = await fetch(window.MOSS.API + "/api/voices", { method: "POST", body: fd });
    const data = await r.json();
    if (!r.ok) { _setStatus(_t("voices.importFailed") + (data.error || r.statusText), true); btn.disabled = false; btn.textContent = _t("voices.submitImport"); return; }
    _setStatus(_t("voices.importSucceed") + name);
    closeImportModal();
    await window.MOSS.loadVoices();
  } catch (e) { _setStatus(_t("voices.importFailed") + e.message, true); }
  btn.disabled = false; btn.textContent = _t("voices.submitImport");
}

// ─── 编辑弹窗 ────────────────────────────────────────────────────────────
function openEditModal(voiceId) {
  const voice = allVoices.find(v => v.id === voiceId);
  if (!voice) return;
  editingVoiceId = voiceId;
  _$("#edit-name").value = voice.name || voice.id;
  _$("#edit-lang").value = voice.language || "";
  _$("#edit-desc").value = voice.description || "";
  _$("#edit-file").value = "不更换";
  document.getElementById("edit-file-input").value = "";
  document.getElementById("modal-edit").classList.add("visible");
  setTimeout(() => _$("#edit-name").focus(), 100);
}

function closeEditModal() {
  document.getElementById("modal-edit").classList.remove("visible");
  editingVoiceId = null;
}

document.getElementById("edit-file-input").addEventListener("change", function() {
  if (this.files && this.files[0]) _$("#edit-file").value = this.files[0].name;
});

async function submitEdit() {
  if (!editingVoiceId) return;
  const name = _$("#edit-name").value.trim();
  const lang = _$("#edit-lang").value.trim();
  const desc = _$("#edit-desc").value.trim();
  const fileInput = document.getElementById("edit-file-input");
  const btn = _$("#edit-submit-btn");
  btn.disabled = true; btn.textContent = _t("voices.saving");
  _setStatus(_t("voices.saving"));
  try {
    const fd = new FormData();
    if (name) fd.append("name", name);
    if (lang) fd.append("language", lang);
    if (desc) fd.append("description", desc);
    if (fileInput.files && fileInput.files[0]) fd.append("audio_file", fileInput.files[0]);
    const r = await fetch(window.MOSS.API + "/api/voices/" + encodeURIComponent(editingVoiceId), { method: "PUT", body: fd });
    const data = await r.json();
    if (!r.ok) { _setStatus(_t("voices.saveErr") + (data.error || r.statusText), true); btn.disabled = false; btn.textContent = _t("voices.submitEdit"); return; }
    _setStatus(_t("voices.saved"));
    closeEditModal();
    await window.MOSS.loadVoices();
  } catch (e) { _setStatus(_t("voices.saveErr") + e.message, true); }
  btn.disabled = false; btn.textContent = _t("voices.submitEdit");
}

// ─── 删除弹窗 ────────────────────────────────────────────────────────────
function openDeleteModal(voiceId) {
  const voice = allVoices.find(v => v.id === voiceId);
  if (!voice) return;
  deletingVoiceId = voiceId;
  document.getElementById("delete-voice-name").textContent = voice.name || voice.id;
  document.getElementById("modal-delete").classList.add("visible");
}

function closeDeleteModal() {
  document.getElementById("modal-delete").classList.remove("visible");
  deletingVoiceId = null;
}

async function submitDelete() {
  if (!deletingVoiceId) return;
  const btn = _$("#delete-submit-btn");
  btn.disabled = true; btn.textContent = _t("voices.deleting");
  try {
    const r = await fetch(window.MOSS.API + "/api/voices/" + encodeURIComponent(deletingVoiceId), { method: "DELETE" });
    const data = await r.json();
    if (!r.ok) { _setStatus(_t("voices.deleteErr") + (data.error || r.statusText), true); btn.disabled = false; btn.textContent = _t("voices.delete_"); return; }
    _setStatus(_t("voices.deleted") + (data.deleted || ""));
    closeDeleteModal();
    await window.MOSS.loadVoices();
  } catch (e) { _setStatus(_t("voices.deleteErr") + e.message, true); }
  btn.disabled = false; btn.textContent = _t("voices.delete_");
}

// ─── 模态按钮绑定 ──────────────────────────────────────────────────────
document.addEventListener("DOMContentLoaded", () => {
  _$("#import-cancel-btn")?.addEventListener("click", closeImportModal);
  _$("#edit-cancel-btn")?.addEventListener("click", closeEditModal);
  _$("#delete-cancel-btn")?.addEventListener("click", closeDeleteModal);
  _$("#import-submit-btn")?.addEventListener("click", submitImport);
  _$("#edit-submit-btn")?.addEventListener("click", submitEdit);
  _$("#delete-submit-btn")?.addEventListener("click", submitDelete);
  _$("#import-file")?.addEventListener("click", () => document.getElementById("import-file-input")?.click());
  _$("#edit-file")?.addEventListener("click", () => document.getElementById("edit-file-input")?.click());
  document.getElementById("voice-search")?.addEventListener("input", () => renderVoiceGrid());
  document.getElementById("voice-lang-filter")?.addEventListener("change", () => renderVoiceGrid());
  _$("#refresh-voices-btn")?.addEventListener("click", async () => {
    _setStatus(_t("voices.refreshed"));
    await window.MOSS.loadVoices();
    _setStatus(_t("voices.refreshed") + " " + window.MOSS.formatCount("voices.count", allVoices.length));
  });
  _$("#add-voice-btn")?.addEventListener("click", openImportModal);
});

// ─── 增强 loadVoices（在 app.js 的基础版本上叠加） ──────────────────
// app.js 加载完成后设置 MOSS.baseLoadVoices，之后 voices.js 接管
(function enhanceLoadVoices() {
  const orig = window.MOSS.loadVoices;
  window.MOSS.loadVoices = async function() {
    if (orig) await orig.call(this);

    const voiceSelect = _$("#voice");
    const voiceBook = _$("#voice-book");
    if (voiceBook && voiceSelect) voiceBook.innerHTML = voiceSelect.innerHTML;

    // 获取所有音色（含隐藏）用于网格页
    try {
      const r = await fetch(window.MOSS.API + "/api/voices?show_hidden=true");
      const data = await r.json();
      allVoices = data.voices || [];
      hiddenVoiceIds = new Set(allVoices.filter(v => v.hidden).map(v => v.id));

      const langFilter = document.getElementById("voice-lang-filter");
      if (langFilter) {
        const langs = new Set(allVoices.map(v => v.language || "其他"));
        const currentVal = langFilter.value;
        langFilter.innerHTML = '<option value="">' + _t("voices.allLanguages") + '</option>';
        for (const l of [...langs].sort()) {
          const o = document.createElement("option");
          o.value = l; o.textContent = l;
          langFilter.appendChild(o);
        }
        langFilter.value = currentVal || "";
      }
    } catch (_) { allVoices = []; }

    // 从下拉框移除隐藏音色
    [voiceSelect, voiceBook, document.getElementById("default-voice")].forEach(sel => {
      if (!sel) return;
      sel.querySelectorAll("option").forEach(o => {
        if (o.value && hiddenVoiceIds.has(o.value)) o.remove();
      });
    });

    renderVoiceGrid();
  };
})();
