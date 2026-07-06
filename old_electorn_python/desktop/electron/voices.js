// ═══════════════════════════════════════════════════════════════════
// MOSS-TTS-Nano Desktop — 音色管理（网格、导入、编辑、删除、试听）
// 完全自包含，仅依赖 window.MOSS.t / MOSS.API / MOSS.setStatus
// ═══════════════════════════════════════════════════════════════════

/* global window, document, fetch, FormData, Audio, URL */

(function () {
"use strict";

// ─── 本地别名 ──────────────────────────────────────────────────────
const _ = document.querySelector.bind(document);
const __ = (key, vars) => window.MOSS.t(key, vars);
const _api = () => window.MOSS.API;
const _status = (msg, err) => window.MOSS.setStatus(msg, err);

// ─── 状态 ──────────────────────────────────────────────────────────
let allVoices = [];
let hiddenVoiceIds = new Set();
let editingVoiceId = null;
let deletingVoiceId = null;

// ─── 渲染网格 ──────────────────────────────────────────────────────
function renderVoiceGrid() {
  const grid = _("#voice-grid");
  if (!grid) return;

  const query = (_("#voice-search")?.value || "").toLowerCase().trim();
  const langFilter = _("#voice-lang-filter")?.value || "";

  if (allVoices.length === 0) {
    grid.innerHTML = '<div class="empty-hint">' + __("voices.noVoices") + "</div>";
    return;
  }

  let filtered = allVoices;
  if (query) filtered = filtered.filter(v => (v.name || "").toLowerCase().includes(query));
  if (langFilter) filtered = filtered.filter(v => (v.language || "其他") === langFilter);

  if (filtered.length === 0) {
    grid.innerHTML = '<div class="empty-hint">没有匹配的音色</div>';
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
    html += `<div class="voice-group-header" data-lang="${lang}"><span class="voice-group-arrow">${collapsed ? "▸" : "▾"}</span>${lang} (${items.length})</div>`;
    for (const v of items) {
      const eye = v.hidden ? "👁️‍🗨️" : "👁️";
      const eyeT = v.hidden ? __("voices.unhide") : __("voices.hide");
      html += `<div class="voice-card"${collapsed ? ' style="display:none"' : ""}${v.hidden ? ' style="opacity:0.5"' : ""}>
        <span class="lang-tag">${lang}</span>
        <div style="flex:1;min-width:0"><div class="vname">${v.name}</div><div class="vdesc">${v.description || ""}</div></div>
        <div class="vactions">
          <button class="voice-btn" data-vid="${v.id}" data-act="preview" title="合成试听">▶</button>
          <button class="voice-btn" data-vid="${v.id}" data-act="listen" title="播放参考音频">🔊</button>
          <button class="voice-btn" data-vid="${v.id}" data-act="edit" title="编辑">✏️</button>
          <button class="voice-btn" data-vid="${v.id}" data-act="hide" title="${eyeT}">${eye}</button>
          <button class="voice-btn" data-vid="${v.id}" data-act="delete" title="删除" style="color:var(--error)">🗑</button>
        </div>
      </div>`;
    }
  }
  grid.innerHTML = html;

  // 折叠
  grid.querySelectorAll(".voice-group-header").forEach(el => {
    el.addEventListener("click", () => {
      window._voiceCollapsed[el.dataset.lang] = !window._voiceCollapsed[el.dataset.lang];
      renderVoiceGrid();
    });
  });

  // 按钮
  grid.querySelectorAll(".voice-btn").forEach(el => {
    el.addEventListener("click", () => {
      const id = el.dataset.vid, act = el.dataset.act;
      if (act === "preview") previewVoice(id, el);
      else if (act === "listen") listenVoice(id);
      else if (act === "hide") toggleHidden(id);
      else if (act === "edit") openEditModal(id);
      else if (act === "delete") openDeleteModal(id);
    });
  });
}

window.MOSS.renderVoiceGrid = renderVoiceGrid;

// ─── 试听 ──────────────────────────────────────────────────────────
async function previewVoice(id, btn) {
  btn.disabled = true; btn.textContent = "⏳";
  _status(__("voices.previewGenerating"));
  try {
    const fd = new FormData();
    fd.append("voice_name", id);
    fd.append("text", _("#preview-text")?.value || __("single.previewText"));
    fd.append("audio_temperature", "0.8");
    const r = await fetch(_api() + "/api/generate", { method: "POST", body: fd });
    const d = await r.json();
    if (d.audio_base64) {
      if (window.MOSS._currentAudio) { window.MOSS._currentAudio.pause(); window.MOSS._currentAudio = null; }
      const a = new Audio(URL.createObjectURL(window.MOSS.base64ToBlob(d.audio_base64, "audio/wav")));
      window.MOSS._currentAudio = a;
      a.play().catch(() => {});
      _status(__("voices.previewPlaying"));
      a.onended = () => { _status(__("voices.previewEnded")); if (window.MOSS._currentAudio === a) window.MOSS._currentAudio = null; };
    }
  } catch (e) { _status(__("voices.previewFailed") + e.message, true); }
  btn.disabled = false; btn.textContent = "▶";
}

async function listenVoice(id) {
  try {
    const r = await fetch(_api() + "/api/voices/" + encodeURIComponent(id) + "/audio");
    if (!r.ok) { _status(__("voices.listenFailed") + "404", true); return; }
    if (window.MOSS._currentAudio) { window.MOSS._currentAudio.pause(); window.MOSS._currentAudio = null; }
    const a = new Audio(URL.createObjectURL(await r.blob()));
    window.MOSS._currentAudio = a;
    a.play().catch(() => {});
    _status(__("voices.listenRef"));
    a.onended = () => { _status(__("voices.listenEnded")); if (window.MOSS._currentAudio === a) window.MOSS._currentAudio = null; };
  } catch (e) { _status(__("voices.listenFailed") + e.message, true); }
}

async function toggleHidden(id) {
  try {
    const r = await fetch(_api() + "/api/voices/" + encodeURIComponent(id) + "/toggle-hidden", { method: "PATCH" });
    const d = await r.json();
    if (!r.ok) { _status("操作失败", true); return; }
    _status(d.hidden ? __("voices.hide") : __("voices.unhide"));
    await loadVoices();
  } catch (e) { _status(__("voices.hide") + " " + e.message, true); }
}

// ─── 导入 ──────────────────────────────────────────────────────────
function openImportModal() {
  const m = _("#modal-import");
  if (!m) return console.warn("[voices] #modal-import not found");
  _("#import-name").value = "";
  _("#import-lang").value = "";
  _("#import-desc").value = "";
  _("#import-file").value = __("voices.importNoFile");
  const fi = _("#import-file-input");
  if (fi) fi.value = "";
  m.classList.add("visible");
  setTimeout(() => { const el = _("#import-name"); if (el) el.focus(); }, 100);
}

async function submitImport() {
  const name = _("#import-name").value.trim();
  const lang = _("#import-lang").value.trim();
  const desc = _("#import-desc").value.trim();
  const fi = _("#import-file-input");
  if (!name) { _status(__("voices.nameRequired"), true); return; }
  if (!fi || !fi.files || !fi.files[0]) { _status(__("voices.fileRequired"), true); return; }
  const btn = _("#import-submit-btn");
  btn.disabled = true; btn.textContent = __("voices.importing");
  _status(__("voices.importing"));
  try {
    const fd = new FormData();
    fd.append("name", name); fd.append("language", lang || "自定义");
    fd.append("description", desc); fd.append("audio_file", fi.files[0]);
    const r = await fetch(_api() + "/api/voices", { method: "POST", body: fd });
    if (!r.ok) { const d = await r.json(); _status(__("voices.importFailed") + (d.error || r.statusText), true); btn.disabled = false; btn.textContent = __("voices.submitImport"); return; }
    _status(__("voices.importSucceed") + name);
    _("#modal-import")?.classList.remove("visible");
    await loadVoices();
  } catch (e) { _status(__("voices.importFailed") + e.message, true); }
  btn.disabled = false; btn.textContent = __("voices.submitImport");
}

// ─── 编辑 ──────────────────────────────────────────────────────────
function openEditModal(id) {
  const v = allVoices.find(x => x.id === id);
  if (!v) return;
  editingVoiceId = id;
  _("#edit-name").value = v.name || v.id;
  _("#edit-lang").value = v.language || "";
  _("#edit-desc").value = v.description || "";
  _("#edit-file").value = "不更换";
  const fi = _("#edit-file-input");
  if (fi) fi.value = "";
  _("#modal-edit")?.classList.add("visible");
  setTimeout(() => { const el = _("#edit-name"); if (el) el.focus(); }, 100);
}

async function submitEdit() {
  if (!editingVoiceId) return;
  const name = _("#edit-name").value.trim();
  const lang = _("#edit-lang").value.trim();
  const desc = _("#edit-desc").value.trim();
  const fi = _("#edit-file-input");
  const btn = _("#edit-submit-btn");
  btn.disabled = true; btn.textContent = __("voices.saving");
  _status(__("voices.saving"));
  try {
    const fd = new FormData();
    if (name) fd.append("name", name); if (lang) fd.append("language", lang);
    if (desc) fd.append("description", desc);
    if (fi && fi.files && fi.files[0]) fd.append("audio_file", fi.files[0]);
    const r = await fetch(_api() + "/api/voices/" + encodeURIComponent(editingVoiceId), { method: "PUT", body: fd });
    if (!r.ok) { const d = await r.json(); _status(__("voices.saveErr") + (d.error || r.statusText), true); btn.disabled = false; btn.textContent = __("voices.submitEdit"); return; }
    _status(__("voices.saved"));
    _("#modal-edit")?.classList.remove("visible");
    editingVoiceId = null;
    await loadVoices();
  } catch (e) { _status(__("voices.saveErr") + e.message, true); }
  btn.disabled = false; btn.textContent = __("voices.submitEdit");
}

// ─── 删除 ──────────────────────────────────────────────────────────
function openDeleteModal(id) {
  const v = allVoices.find(x => x.id === id);
  if (!v) return;
  deletingVoiceId = id;
  const el = _("#delete-voice-name");
  if (el) el.textContent = v.name || v.id;
  _("#modal-delete")?.classList.add("visible");
}

async function submitDelete() {
  if (!deletingVoiceId) return;
  const btn = _("#delete-submit-btn");
  btn.disabled = true; btn.textContent = __("voices.deleting");
  try {
    const r = await fetch(_api() + "/api/voices/" + encodeURIComponent(deletingVoiceId), { method: "DELETE" });
    if (!r.ok) { const d = await r.json(); _status(__("voices.deleteErr") + (d.error || r.statusText), true); btn.disabled = false; btn.textContent = __("voices.delete_"); return; }
    _status(__("voices.deleted") + (d.deleted || ""));
    _("#modal-delete")?.classList.remove("visible");
    deletingVoiceId = null;
    await loadVoices();
  } catch (e) { _status(__("voices.deleteErr") + e.message, true); }
  btn.disabled = false; btn.textContent = __("voices.delete_");
}

// ═══════════════════════════════════════════════════════════════════
// loadVoices — 填充下拉框 + 网格
// ═══════════════════════════════════════════════════════════════════
function _hiddenFilter(sel) {
  if (!sel) return;
  sel.querySelectorAll("option").forEach(o => {
    if (o.value && hiddenVoiceIds.has(o.value)) o.remove();
  });
}

async function loadVoices() {
  try {
    const r1 = await fetch(_api() + "/api/voices?show_hidden=false");
    const d1 = await r1.json();
    const voices = d1.voices || [];

    const vs = _("#voice");
    if (vs) {
      vs.innerHTML = '<option value="">' + __("single.selectVoice") + "</option>";
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
        vs.appendChild(g);
      }
    }

    const dv = _("#default-voice");
    if (dv) {
      dv.innerHTML = '<option value="">' + __("settings.noDefault") + "</option>";
      if (vs) dv.innerHTML += vs.innerHTML;
    }

    const genBtn = _("#generate-btn");
    if (genBtn) genBtn.disabled = false;
    _status(__("app.ready") + " · " + window.MOSS.formatCount("app.loadedVoices", voices.length));

    const vb = _("#voice-book");
    if (vb && vs) vb.innerHTML = vs.innerHTML;

    const r2 = await fetch(_api() + "/api/voices?show_hidden=true");
    const d2 = await r2.json();
    allVoices = d2.voices || [];
    hiddenVoiceIds = new Set(allVoices.filter(v => v.hidden).map(v => v.id));

    const lf = _("#voice-lang-filter");
    if (lf) {
      const langs = new Set(allVoices.map(v => v.language || "其他"));
      const cur = lf.value;
      lf.innerHTML = '<option value="">' + __("voices.allLanguages") + "</option>";
      for (const l of [...langs].sort()) {
        const o = document.createElement("option");
        o.value = l; o.textContent = l;
        lf.appendChild(o);
      }
      lf.value = cur || "";
    }

    _hiddenFilter(_("#voice"));
    _hiddenFilter(_("#voice-book"));
    _hiddenFilter(_("#default-voice"));

    renderVoiceGrid();
  } catch (e) {
    console.error("[voices] loadVoices:", e);
    const vs = _("#voice");
    if (vs) vs.innerHTML = '<option value="">' + __("app.cannotConnect") + "</option>";
    _status(__("app.loadFailed"), true);
  }
}

window.MOSS.loadVoices = loadVoices;

// ═══════════════════════════════════════════════════════════════════
// 事件绑定
// ═══════════════════════════════════════════════════════════════════
function bindAll() {
  _("#import-cancel-btn")?.addEventListener("click", () => _("#modal-import")?.classList.remove("visible"));
  _("#edit-cancel-btn")?.addEventListener("click", () => { _("#modal-edit")?.classList.remove("visible"); editingVoiceId = null; });
  _("#delete-cancel-btn")?.addEventListener("click", () => { _("#modal-delete")?.classList.remove("visible"); deletingVoiceId = null; });
  _("#import-submit-btn")?.addEventListener("click", submitImport);
  _("#edit-submit-btn")?.addEventListener("click", submitEdit);
  _("#delete-submit-btn")?.addEventListener("click", submitDelete);
  _("#import-file")?.addEventListener("click", () => _("#import-file-input")?.click());
  _("#edit-file")?.addEventListener("click", () => _("#edit-file-input")?.click());
  _("#import-file-input")?.addEventListener("change", function () { if (this.files?.[0]) _("#import-file").value = this.files[0].name; });
  _("#edit-file-input")?.addEventListener("change", function () { if (this.files?.[0]) _("#edit-file").value = this.files[0].name; });
  _("#voice-search")?.addEventListener("input", renderVoiceGrid);
  _("#voice-lang-filter")?.addEventListener("change", renderVoiceGrid);
  _("#refresh-voices-btn")?.addEventListener("click", async () => {
    _status(__("voices.refreshed"));
    await loadVoices();
    _status(__("voices.refreshed") + " " + window.MOSS.formatCount("voices.count", allVoices.length));
  });
  _("#add-voice-btn")?.addEventListener("click", openImportModal);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", bindAll);
} else {
  bindAll();
}

})();
