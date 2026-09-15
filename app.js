"use strict";

/* ---------- Constants ---------- */
const TILE = 44;
const COLS = 16;
const ROWS = 9;
const BASE_MIN_MS = 150; // real ms per game minute at 1x speed
const SAVE_KEY = "simlife_save_v1";

const ZONES = [
  { x0: 0, y0: 0, x1: 3, y1: 3, color: "#f3e3c3", name: "kuchnia" },
  { x0: 0, y0: 4, x1: 3, y1: 8, color: "#cfe7f5", name: "łazienka" },
  { x0: 4, y0: 0, x1: 7, y1: 8, color: "#e6d9f2", name: "sypialnia" },
  { x0: 8, y0: 0, x1: 11, y1: 8, color: "#d9f0d3", name: "salon" },
  { x0: 12, y0: 0, x1: 15, y1: 8, color: "#8fd18f", name: "ogród" },
];

const NEED_KEYS = ["hunger", "energy", "hygiene", "fun", "social", "bladder"];
const NEED_META = {
  hunger: { icon: "🍗", label: "Głód", decay: 0.055 },
  energy: { icon: "⚡", label: "Energia", decay: 0.04 },
  hygiene: { icon: "🧼", label: "Higiena", decay: 0.03 },
  fun: { icon: "🎉", label: "Zabawa", decay: 0.05 },
  social: { icon: "💬", label: "Kontakty", decay: 0.03 },
  bladder: { icon: "🚻", label: "Pęcherz", decay: 0.065 },
};

const TRAITS = {
  towarzyski: { name: "Towarzyski", desc: "Kontakty spadają wolniej.", mods: { social: 0.5 } },
  pracowity: { name: "Pracowity", desc: "Zarabia więcej w pracy.", mods: { salary: 1.35 } },
  leniwy: { name: "Leniwy", desc: "Energia spada wolniej.", mods: { energy: 0.6 } },
  imprezowicz: { name: "Imprezowicz", desc: "Zabawa spada szybciej, ale rośnie mocniej.", mods: { fun: 1.5, funGain: 1.3 } },
};

const COLORS = ["#ff6f59", "#3fa796", "#f6c445", "#7b6cf6", "#e85ea0"];

/* ---------- Furniture definitions ---------- */
// action: { label, need, gain, duration(min), sideEffects:{need:delta}, isWork }
function makeFurniture(id, type, label, icon, x, y, action) {
  return { id, type, label, icon, x, y, action, purchased: true };
}

const FURNITURE = [
  makeFurniture("fridge", "fridge", "Lodówka", "🍽️", 1, 1, {
    label: "Zjedz", need: "hunger", gain: 60, duration: 20, side: {},
  }),
  makeFurniture("sink", "sink", "Umywalka", "🚰", 2, 1, {
    label: "Umyj ręce", need: "hygiene", gain: 20, duration: 8, side: {},
  }),
  makeFurniture("toilet", "toilet", "Toaleta", "🚽", 1, 5, {
    label: "Skorzystaj z toalety", need: "bladder", gain: 100, duration: 6, side: {},
  }),
  makeFurniture("shower", "shower", "Prysznic", "🚿", 1, 7, {
    label: "Weź prysznic", need: "hygiene", gain: 100, duration: 15, side: { energy: 5 },
  }),
  makeFurniture("bed", "bed", "Łóżko", "🛏️", 5, 2, {
    label: "Śpij", need: "energy", gain: 100, duration: 240, side: { hygiene: -10, bladder: -15 },
  }),
  makeFurniture("bookshelf", "bookshelf", "Regał", "📚", 7, 1, {
    label: "Czytaj", need: "fun", gain: 25, duration: 30, side: {},
  }),
  makeFurniture("sofa", "sofa", "Sofa", "🛋️", 9, 3, {
    label: "Odpoczywaj", need: "fun", gain: 20, duration: 40, side: { energy: 10 },
  }),
  makeFurniture("tv", "tv", "Telewizor", "📺", 10, 3, {
    label: "Oglądaj TV", need: "fun", gain: 35, duration: 60, side: { energy: -5 },
  }),
  makeFurniture("computer", "computer", "Komputer", "💻", 9, 6, {
    label: "Graj na komputerze", need: "fun", gain: 30, duration: 55, side: { energy: -10 },
  }),
  makeFurniture("car", "car", "Praca (Samochód)", "🚗", 13, 3, {
    label: "Jedź do pracy", isWork: true, duration: 480,
    side: { energy: -30, fun: -10, social: -10, hygiene: -15, hunger: -20 },
  }),
  makeFurniture("tree", "tree", "Drzewo", "🌳", 14, 1, null),
];

const SHOP_ITEMS = [
  { type: "plant", label: "Roślina", icon: "🪴", cost: 150, action: { label: "Podziwiaj roślinę", need: "fun", gain: 12, duration: 10, side: {} } },
  { type: "piano", label: "Pianino", icon: "🎹", cost: 400, action: { label: "Zagraj na pianinie", need: "fun", gain: 40, duration: 50, side: {} } },
  { type: "gym", label: "Siłownia", icon: "🏋️", cost: 450, action: { label: "Ćwicz", need: "fun", gain: 25, duration: 45, side: { energy: -10 } } },
  { type: "firepit", label: "Ognisko", icon: "🔥", cost: 200, action: { label: "Usiądź przy ognisku", need: "social", gain: 30, duration: 40, side: { fun: 20 } } },
];

const EMPTY_SLOTS = [
  { id: "slot1", x: 6, y: 6 },
  { id: "slot2", x: 11, y: 6 },
  { id: "slot3", x: 13, y: 6 },
];

/* ---------- Game state ---------- */
const state = {
  sim: null,
  money: 500,
  day: 1,
  minutes: 8 * 60, // minutes since midnight
  speed: 1,
  furniture: FURNITURE.map((f) => ({ ...f })),
  slots: EMPTY_SLOTS.map((s) => ({ ...s, item: null })),
  lastFrame: 0,
  accumMs: 0,
  selectedObj: null,
};

function occupiedTiles() {
  const set = new Set();
  for (const f of state.furniture) set.add(f.x + "," + f.y);
  for (const s of state.slots) if (s.item) set.add(s.x + "," + s.y);
  return set;
}

function isWalkable(x, y) {
  if (x < 0 || y < 0 || x >= COLS || y >= ROWS) return false;
  return !occupiedTiles().has(x + "," + y);
}

/* ---------- Pathfinding (BFS) ---------- */
function bfsFrom(sx, sy) {
  const dist = new Map();
  const prev = new Map();
  const key = (x, y) => x + "," + y;
  const q = [[sx, sy]];
  dist.set(key(sx, sy), 0);
  let qi = 0;
  while (qi < q.length) {
    const [cx, cy] = q[qi++];
    const d = dist.get(key(cx, cy));
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = cx + dx, ny = cy + dy;
      const k = key(nx, ny);
      if (!isWalkable(nx, ny) || dist.has(k)) continue;
      dist.set(k, d + 1);
      prev.set(k, key(cx, cy));
      q.push([nx, ny]);
    }
  }
  return { dist, prev, key };
}

function reconstructPath(prev, key, sx, sy, tx, ty) {
  const path = [];
  let cur = key(tx, ty);
  const start = key(sx, sy);
  while (cur !== start) {
    const [x, y] = cur.split(",").map(Number);
    path.push({ x, y });
    cur = prev.get(cur);
    if (!cur) return null;
  }
  path.reverse();
  return path;
}

function findPathToNeighbor(sx, sy, tx, ty) {
  const sxr = Math.round(sx), syr = Math.round(sy);
  const { dist, prev, key } = bfsFrom(sxr, syr);
  const candidates = [[tx + 1, ty], [tx - 1, ty], [tx, ty + 1], [tx, ty - 1]];
  let best = null, bestD = Infinity;
  for (const [nx, ny] of candidates) {
    if (!isWalkable(nx, ny)) continue;
    const d = dist.get(nx + "," + ny);
    if (d !== undefined && d < bestD) { bestD = d; best = [nx, ny]; }
  }
  if (!best) return null;
  if (best[0] === sxr && best[1] === syr) return [];
  return reconstructPath(prev, key, sxr, syr, best[0], best[1]);
}

/* ---------- Sim ---------- */
function createSim(name, color, traitKey) {
  return {
    name, color, trait: traitKey,
    x: 3, y: 3, // tile coords (float for animation)
    path: [],
    speed: 4.2, // tiles per second
    needs: { hunger: 85, energy: 85, hygiene: 85, fun: 85, social: 85, bladder: 85 },
    action: null, // { targetId, label, need, gain, duration, side, elapsed, isWork }
    atWork: false,
  };
}

function traitMod(trait, key, def = 1) {
  const t = TRAITS[trait];
  if (!t || !t.mods || t.mods[key] === undefined) return def;
  return t.mods[key];
}

/* ---------- Toasts ---------- */
function toast(msg) {
  const c = document.getElementById("toastContainer");
  const el = document.createElement("div");
  el.className = "toast";
  el.textContent = msg;
  c.appendChild(el);
  setTimeout(() => el.remove(), 4000);
}

/* ---------- Actions ---------- */
function getObjAt(x, y) {
  for (const f of state.furniture) if (f.x === x && f.y === y) return f;
  for (const s of state.slots) if (s.item && s.x === x && s.y === y) {
    return { id: s.id, type: s.item.type, label: s.item.label, icon: s.item.icon, x: s.x, y: s.y, action: s.item.action };
  }
  return null;
}

function startAction(obj) {
  const sim = state.sim;
  if (!obj.action) return;
  const path = findPathToNeighbor(sim.x, sim.y, obj.x, obj.y);
  if (path === null) { toast("Nie można dojść do tego obiektu."); return; }
  sim.path = path;
  sim.pendingAction = obj;
  closePanels();
}

function beginPendingActionIfArrived() {
  const sim = state.sim;
  if (!sim.pendingAction) return;
  if (sim.path.length > 0) return;
  const obj = sim.pendingAction;
  sim.pendingAction = null;
  const a = obj.action;
  if (a.isWork) {
    const hour = Math.floor(state.minutes / 60) % 24;
    if (hour < 8 || hour >= 18) {
      toast("Praca dostępna tylko w godzinach 8:00–18:00.");
      return;
    }
  }
  sim.action = {
    objId: obj.id, label: a.label, need: a.need, gain: a.gain,
    duration: a.duration, side: a.side || {}, elapsed: 0, isWork: !!a.isWork,
  };
  sim.atWork = !!a.isWork;
  toast(`${sim.name}: ${a.label}...`);
}

function cancelAction() {
  const sim = state.sim;
  if (sim.action) {
    if (sim.action.isWork) toast(`${sim.name} przerwał pracę.`);
    sim.action = null;
    sim.atWork = false;
  }
  sim.pendingAction = null;
  sim.path = [];
  closePanels();
}

function finishAction() {
  const sim = state.sim;
  const a = sim.action;
  if (!a) return;
  if (a.isWork) {
    const base = 120;
    const pay = Math.round(base * traitMod(sim.trait, "salary"));
    state.money += pay;
    toast(`${sim.name} zarobił ${pay} zł!`);
  } else {
    toast(`${sim.name} ukończył: ${a.label}`);
  }
  sim.action = null;
  sim.atWork = false;
}

/* ---------- Update loop ---------- */
function applyNeedDecay(minutesPassed) {
  const sim = state.sim;
  for (const k of NEED_KEYS) {
    const mod = traitMod(sim.trait, k, 1);
    const rate = NEED_META[k].decay * mod;
    sim.needs[k] = clamp(sim.needs[k] - rate * minutesPassed, 0, 100);
  }
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

function tickMinutes(n) {
  state.minutes += n;
  while (state.minutes >= 1440) { state.minutes -= 1440; state.day += 1; }
  applyNeedDecay(n);

  const sim = state.sim;
  if (sim.action) {
    sim.action.elapsed += n;
    const frac = Math.min(1, n / sim.action.duration);
    if (sim.action.need) {
      sim.needs[sim.action.need] = clamp(
        sim.needs[sim.action.need] + sim.action.gain * frac * traitMod(sim.trait, "funGain", 1), 0, 100
      );
    }
    for (const [k, delta] of Object.entries(sim.action.side)) {
      sim.needs[k] = clamp(sim.needs[k] + delta * frac, 0, 100);
    }
    if (sim.action.elapsed >= sim.action.duration) finishAction();
  }

  for (const k of NEED_KEYS) {
    if (sim.needs[k] <= 12 && !sim._warned?.[k]) {
      sim._warned = sim._warned || {};
      sim._warned[k] = true;
      toast(`⚠️ ${NEED_META[k].label} Sima jest krytycznie niska!`);
    } else if (sim.needs[k] > 25 && sim._warned?.[k]) {
      sim._warned[k] = false;
    }
  }
}

function moveSimAlongPath(dtSec) {
  const sim = state.sim;
  if (sim.path.length === 0) return;
  const target = sim.path[0];
  const dx = target.x - sim.x, dy = target.y - sim.y;
  const dist = Math.hypot(dx, dy);
  const step = sim.speed * dtSec;
  if (step >= dist) {
    sim.x = target.x; sim.y = target.y;
    sim.path.shift();
  } else {
    sim.x += (dx / dist) * step;
    sim.y += (dy / dist) * step;
  }
}

function gameLoop(ts) {
  if (!state.lastFrame) state.lastFrame = ts;
  const dtMs = ts - state.lastFrame;
  state.lastFrame = ts;

  if (state.sim && state.speed > 0) {
    moveSimAlongPath(dtMs / 1000);
    beginPendingActionIfArrived();

    state.accumMs += dtMs * state.speed;
    const minuteMs = BASE_MIN_MS;
    while (state.accumMs >= minuteMs) {
      state.accumMs -= minuteMs;
      tickMinutes(1);
    }
  }

  render();
  updateUI();
  requestAnimationFrame(gameLoop);
}

/* ---------- Rendering ---------- */
const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");

function tileToPx(t) { return t * TILE; }

function render() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  for (const z of ZONES) {
    ctx.fillStyle = z.color;
    ctx.fillRect(tileToPx(z.x0), tileToPx(z.y0), tileToPx(z.x1 - z.x0 + 1), tileToPx(z.y1 - z.y0 + 1));
  }

  ctx.strokeStyle = "rgba(0,0,0,0.08)";
  ctx.lineWidth = 1;
  for (let x = 0; x <= COLS; x++) {
    ctx.beginPath(); ctx.moveTo(tileToPx(x), 0); ctx.lineTo(tileToPx(x), tileToPx(ROWS)); ctx.stroke();
  }
  for (let y = 0; y <= ROWS; y++) {
    ctx.beginPath(); ctx.moveTo(0, tileToPx(y)); ctx.lineTo(tileToPx(COLS), tileToPx(y)); ctx.stroke();
  }

  ctx.strokeStyle = state.sim ? "#33413a" : "#33413a";
  ctx.lineWidth = 4;
  ctx.strokeRect(1, 1, tileToPx(12) - 2, tileToPx(9) - 2);

  for (const f of state.furniture) drawObj(f);
  for (const s of state.slots) {
    if (s.item) drawObj({ x: s.x, y: s.y, icon: s.item.icon, label: s.item.label });
    else drawEmptySlot(s);
  }

  if (state.sim) drawSim(state.sim);

  const hour = Math.floor(state.minutes / 60);
  if (hour >= 21 || hour < 6) {
    const nightAlpha = hour >= 21 ? Math.min(0.45, (hour - 21) * 0.15) : Math.max(0, 0.45 - hour * 0.08);
    ctx.fillStyle = `rgba(10,15,40,${nightAlpha})`;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }
}

function drawObj(f) {
  const px = tileToPx(f.x), py = tileToPx(f.y);
  ctx.fillStyle = "#ffffffcc";
  ctx.fillRect(px + 3, py + 3, TILE - 6, TILE - 6);
  ctx.strokeStyle = "#33413a";
  ctx.lineWidth = 1.5;
  ctx.strokeRect(px + 3, py + 3, TILE - 6, TILE - 6);
  ctx.font = "22px sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(f.icon, px + TILE / 2, py + TILE / 2 - 2);
  if (state.selectedObj && state.selectedObj.x === f.x && state.selectedObj.y === f.y) {
    ctx.strokeStyle = "#ff6f59";
    ctx.lineWidth = 3;
    ctx.strokeRect(px + 2, py + 2, TILE - 4, TILE - 4);
  }
}

function drawEmptySlot(s) {
  const px = tileToPx(s.x), py = tileToPx(s.y);
  ctx.strokeStyle = "rgba(50,50,50,0.5)";
  ctx.setLineDash([4, 3]);
  ctx.lineWidth = 2;
  ctx.strokeRect(px + 4, py + 4, TILE - 8, TILE - 8);
  ctx.setLineDash([]);
  ctx.font = "16px sans-serif";
  ctx.fillStyle = "rgba(50,50,50,0.6)";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("🛒", px + TILE / 2, py + TILE / 2);
}

function drawSim(sim) {
  const px = tileToPx(sim.x) + TILE / 2, py = tileToPx(sim.y) + TILE / 2;
  ctx.beginPath();
  ctx.arc(px, py, 14, 0, Math.PI * 2);
  ctx.fillStyle = sim.color;
  ctx.fill();
  ctx.strokeStyle = "#22302a";
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.font = "14px sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = "#fff";
  ctx.fillText("🙂", px, py);

  if (sim.action) {
    const frac = Math.min(1, sim.action.elapsed / sim.action.duration);
    ctx.fillStyle = "rgba(0,0,0,0.5)";
    ctx.fillRect(px - 16, py - 26, 32, 5);
    ctx.fillStyle = "#4caf50";
    ctx.fillRect(px - 16, py - 26, 32 * frac, 5);
  }
}

/* ---------- UI ---------- */
function moodFromNeeds(sim) {
  const avg = NEED_KEYS.reduce((s, k) => s + sim.needs[k], 0) / NEED_KEYS.length;
  if (avg >= 80) return "😄";
  if (avg >= 60) return "🙂";
  if (avg >= 40) return "😐";
  if (avg >= 20) return "😟";
  return "😫";
}

function updateUI() {
  const sim = state.sim;
  if (!sim) return;
  document.getElementById("simName").textContent = sim.name + (sim.atWork ? " (w pracy)" : "");
  document.getElementById("mood").textContent = moodFromNeeds(sim);
  const hour = Math.floor(state.minutes / 60);
  const min = Math.floor(state.minutes % 60);
  document.getElementById("clock").textContent =
    `Dzień ${state.day}, ${String(hour).padStart(2, "0")}:${String(min).padStart(2, "0")}`;
  document.getElementById("money").textContent = `💰 ${state.money} zł`;

  for (const k of NEED_KEYS) {
    const el = document.querySelector(`.need[data-need="${k}"] .need-fill`);
    const v = sim.needs[k];
    el.style.width = v + "%";
    el.style.background = v > 60 ? "#4caf50" : v > 30 ? "#f6c445" : "#e35b5b";
  }
}

/* ---------- Panels (action / shop) ---------- */
function closePanels() {
  document.getElementById("actionPanel").classList.add("hidden");
  document.getElementById("shopPanel").classList.add("hidden");
  state.selectedObj = null;
}

function openActionPanel(obj, px, py) {
  closePanels();
  state.selectedObj = obj;
  const panel = document.getElementById("actionPanel");
  panel.innerHTML = "";
  const closeBtn = document.createElement("button");
  closeBtn.className = "panelClose";
  closeBtn.textContent = "✕";
  closeBtn.onclick = closePanels;
  panel.appendChild(closeBtn);

  const h = document.createElement("h4");
  h.textContent = obj.label;
  panel.appendChild(h);

  if (obj.action) {
    const btn = document.createElement("button");
    btn.className = "panelBtn";
    btn.textContent = obj.action.label;
    btn.onclick = () => startAction(obj);
    panel.appendChild(btn);
  } else {
    const p = document.createElement("div");
    p.style.fontSize = "0.8em";
    p.textContent = "Ten obiekt jest dekoracyjny.";
    panel.appendChild(p);
  }

  if (state.sim.action && state.sim.action.objId === obj.id) {
    const cancel = document.createElement("button");
    cancel.className = "panelBtn";
    cancel.textContent = "Anuluj czynność";
    cancel.onclick = cancelAction;
    panel.appendChild(cancel);
  }

  positionPanel(panel, px, py);
  panel.classList.remove("hidden");
}

function openShopPanel(slot, px, py) {
  closePanels();
  const panel = document.getElementById("shopPanel");
  panel.innerHTML = "";
  const closeBtn = document.createElement("button");
  closeBtn.className = "panelClose";
  closeBtn.textContent = "✕";
  closeBtn.onclick = closePanels;
  panel.appendChild(closeBtn);

  const h = document.createElement("h4");
  h.textContent = "Kup mebel";
  panel.appendChild(h);

  for (const item of SHOP_ITEMS) {
    const btn = document.createElement("button");
    btn.className = "panelBtn";
    btn.textContent = `${item.icon} ${item.label} — ${item.cost} zł`;
    btn.disabled = state.money < item.cost;
    btn.onclick = () => {
      if (state.money < item.cost) return;
      state.money -= item.cost;
      slot.item = { type: item.type, label: item.label, icon: item.icon, action: item.action };
      toast(`Kupiono: ${item.label}!`);
      closePanels();
    };
    panel.appendChild(btn);
  }

  positionPanel(panel, px, py);
  panel.classList.remove("hidden");
}

function positionPanel(panel, px, py) {
  const areaW = canvas.width;
  let left = px + 20, top = py;
  panel.style.left = Math.min(left, areaW - 180) + "px";
  panel.style.top = Math.max(top - 40, 4) + "px";
}

/* ---------- Input ---------- */
canvas.addEventListener("click", (e) => {
  if (!state.sim) return;
  const rect = canvas.getBoundingClientRect();
  const scaleX = canvas.width / rect.width;
  const scaleY = canvas.height / rect.height;
  const mx = (e.clientX - rect.left) * scaleX;
  const my = (e.clientY - rect.top) * scaleY;
  const tx = Math.floor(mx / TILE), ty = Math.floor(my / TILE);

  const obj = getObjAt(tx, ty);
  if (obj) {
    openActionPanel(obj, mx, my);
    return;
  }
  const slot = state.slots.find((s) => s.x === tx && s.y === ty && !s.item);
  if (slot) {
    openShopPanel(slot, mx, my);
    return;
  }
  closePanels();
  if (isWalkable(tx, ty)) {
    const sxr = Math.round(state.sim.x), syr = Math.round(state.sim.y);
    const { dist, prev, key } = bfsFrom(sxr, syr);
    if (dist.has(tx + "," + ty)) {
      const path = reconstructPath(prev, key, sxr, syr, tx, ty);
      state.sim.path = path || [];
      state.sim.pendingAction = null;
    }
  }
});

document.getElementById("speedControls").addEventListener("click", (e) => {
  const btn = e.target.closest("button");
  if (!btn) return;
  state.speed = Number(btn.dataset.speed);
  document.querySelectorAll("#speedControls button").forEach((b) => b.classList.remove("active"));
  btn.classList.add("active");
});

document.getElementById("saveBtn").addEventListener("click", () => { saveGame(); toast("Gra zapisana."); });
document.getElementById("newGameBtn").addEventListener("click", () => {
  if (confirm("Rozpocząć nową grę? Obecny postęp zostanie utracony.")) {
    localStorage.removeItem(SAVE_KEY);
    location.reload();
  }
});

/* ---------- Save / Load ---------- */
function saveGame() {
  const data = {
    sim: {
      name: state.sim.name, color: state.sim.color, trait: state.sim.trait,
      x: state.sim.x, y: state.sim.y, needs: state.sim.needs,
      path: state.sim.path, pendingAction: state.sim.pendingAction || null,
      action: state.sim.action, atWork: state.sim.atWork,
    },
    money: state.money, day: state.day, minutes: state.minutes,
    slots: state.slots.map((s) => ({ id: s.id, item: s.item })),
  };
  localStorage.setItem(SAVE_KEY, JSON.stringify(data));
}

function loadGame() {
  const raw = localStorage.getItem(SAVE_KEY);
  if (!raw) return false;
  try {
    const data = JSON.parse(raw);
    state.sim = createSim(data.sim.name, data.sim.color, data.sim.trait);
    state.sim.x = data.sim.x; state.sim.y = data.sim.y;
    state.sim.needs = data.sim.needs;
    state.sim.path = data.sim.path || [];
    state.sim.pendingAction = data.sim.pendingAction || null;
    state.sim.action = data.sim.action || null;
    state.sim.atWork = !!data.sim.atWork;
    state.money = data.money; state.day = data.day; state.minutes = data.minutes;
    for (const s of state.slots) {
      const found = data.slots.find((d) => d.id === s.id);
      if (found) s.item = found.item;
    }
    return true;
  } catch (e) {
    console.error("Save load failed", e);
    return false;
  }
}

window.addEventListener("beforeunload", () => { if (state.sim) saveGame(); });
setInterval(() => { if (state.sim) saveGame(); }, 30000);

/* ---------- Character creator ---------- */
function initCharCreator() {
  const colorsEl = document.getElementById("ccColors");
  let selectedColor = COLORS[0];
  COLORS.forEach((c, i) => {
    const sw = document.createElement("div");
    sw.className = "swatch" + (i === 0 ? " selected" : "");
    sw.style.background = c;
    sw.onclick = () => {
      selectedColor = c;
      colorsEl.querySelectorAll(".swatch").forEach((s) => s.classList.remove("selected"));
      sw.classList.add("selected");
    };
    colorsEl.appendChild(sw);
  });

  const traitsEl = document.getElementById("ccTraits");
  let selectedTrait = Object.keys(TRAITS)[0];
  Object.entries(TRAITS).forEach(([key, t], i) => {
    const div = document.createElement("div");
    div.className = "trait" + (i === 0 ? " selected" : "");
    div.innerHTML = `<b>${t.name}</b> — ${t.desc}`;
    div.onclick = () => {
      selectedTrait = key;
      traitsEl.querySelectorAll(".trait").forEach((d) => d.classList.remove("selected"));
      div.classList.add("selected");
    };
    traitsEl.appendChild(div);
  });

  document.getElementById("ccConfirm").addEventListener("click", () => {
    const name = document.getElementById("ccName").value.trim() || "Sim";
    state.sim = createSim(name, selectedColor, selectedTrait);
    document.getElementById("charCreator").classList.add("hidden");
    toast(`Witaj, ${name}! Kliknij obiekt, aby wykonać czynność.`);
  });
}

/* ---------- Boot ---------- */
function boot() {
  initCharCreator();
  if (loadGame()) {
    document.getElementById("charCreator").classList.add("hidden");
  }
  requestAnimationFrame(gameLoop);
}

boot();
