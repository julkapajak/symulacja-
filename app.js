"use strict";

/* ---------- Constants ---------- */
const TILE = 44;
const COLS = 16;
const ROWS = 9;
const BASE_MIN_MS = 150; // real ms per game minute at 1x speed
const SAVE_KEY = "simlife_save_v1";

const ZONES = [
  { x0: 0, y0: 0, x1: 3, y1: 3, color: "#e8d2a8", name: "kuchnia", floorType: "tile" },
  { x0: 0, y0: 4, x1: 3, y1: 8, color: "#bfe0ea", name: "łazienka", floorType: "tile" },
  { x0: 4, y0: 0, x1: 7, y1: 8, color: "#c9a06e", name: "sypialnia", floorType: "wood" },
  { x0: 8, y0: 0, x1: 11, y1: 8, color: "#caa070", name: "salon", floorType: "wood" },
  { x0: 12, y0: 0, x1: 15, y1: 8, color: "#7ec46a", name: "ogród", floorType: "grass" },
];

/* ---------- Walls, doors & windows ---------- */
const WALL_H = 88;

function zoneOf(tx, ty) {
  for (const z of ZONES) {
    if (tx >= z.x0 && tx <= z.x1 && ty >= z.y0 && ty <= z.y1) return z;
  }
  return null;
}
function isIndoorZone(z) { return !!z && z.name !== "ogród"; }

const DOOR_EDGES = new Set(["4,2,W", "4,6,W", "2,4,N", "8,4,W"]);
const WINDOW_EDGES = new Set(["1,0,N", "5,0,N", "9,0,N", "0,1,W", "0,6,W"]);

const WALLS = [];
const BLOCKED_EDGES = new Set();

(function buildWalls() {
  for (let ty = 0; ty < ROWS; ty++) {
    for (let tx = 0; tx < COLS; tx++) {
      const z = zoneOf(tx, ty);
      if (!isIndoorZone(z)) continue;
      const zn = ty > 0 ? zoneOf(tx, ty - 1) : null;
      if (ty === 0 || zn !== z) {
        const key = `${tx},${ty},N`;
        const kind = DOOR_EDGES.has(key) ? "door" : WINDOW_EDGES.has(key) ? "window" : "solid";
        WALLS.push({ tx, ty, edge: "N", kind });
        if (kind === "solid") BLOCKED_EDGES.add(key);
      }
      const zw = tx > 0 ? zoneOf(tx - 1, ty) : null;
      if (tx === 0 || zw !== z) {
        const key = `${tx},${ty},W`;
        const kind = DOOR_EDGES.has(key) ? "door" : WINDOW_EDGES.has(key) ? "window" : "solid";
        WALLS.push({ tx, ty, edge: "W", kind });
        if (kind === "solid") BLOCKED_EDGES.add(key);
      }
    }
  }
})();

function edgeBlocked(ax, ay, bx, by) {
  if (bx === ax && by === ay - 1) return BLOCKED_EDGES.has(`${ax},${ay},N`);
  if (bx === ax - 1 && by === ay) return BLOCKED_EDGES.has(`${ax},${ay},W`);
  if (bx === ax && by === ay + 1) return BLOCKED_EDGES.has(`${bx},${by},N`);
  if (bx === ax + 1 && by === ay) return BLOCKED_EDGES.has(`${bx},${by},W`);
  return false;
}

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

const SKILL_META = {
  cooking: { icon: "🍳", label: "Gotowanie" },
  fitness: { icon: "💪", label: "Kondycja" },
  charisma: { icon: "🗣️", label: "Charyzma" },
};
const SKILL_MAX = 10;

const JOB_TITLES = ["Stażysta", "Pracownik", "Specjalista", "Kierownik", "Dyrektor", "Prezes"];
const JOB_BASE_SALARY = [80, 120, 170, 230, 300, 400];
const SHIFTS_PER_PROMOTION = 3;

/* ---------- Furniture definitions ---------- */
// action: { label, need, gain, duration(min), sideEffects:{need:delta}, isWork }
function makeFurniture(id, type, label, icon, x, y, action) {
  return { id, type, label, icon, x, y, action, purchased: true };
}

const FURNITURE = [
  makeFurniture("fridge", "fridge", "Lodówka", "🍽️", 1, 1, {
    label: "Zjedz", need: "hunger", gain: 60, duration: 20, side: {}, skill: "cooking", skillGain: 0.12,
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
  { type: "gym", label: "Siłownia", icon: "🏋️", cost: 450, action: { label: "Ćwicz", need: "fun", gain: 25, duration: 45, side: { energy: -10 }, skill: "fitness", skillGain: 0.25 } },
  { type: "firepit", label: "Ognisko", icon: "🔥", cost: 200, action: { label: "Usiądź przy ognisku", need: "social", gain: 30, duration: 40, side: { fun: 20 }, skill: "charisma", skillGain: 0.2 } },
];

const EMPTY_SLOTS = [
  { id: "slot1", x: 6, y: 6 },
  { id: "slot2", x: 11, y: 6 },
  { id: "slot3", x: 13, y: 6 },
];

/* ---------- 3D (isometric) visuals: extrusion height + base color per type ---------- */
const VISUALS = {
  fridge: { h: 40, color: "#f2f4f4" },
  sink: { h: 20, color: "#dceff5" },
  toilet: { h: 22, color: "#ffffff" },
  shower: { h: 34, color: "#cdeaf7" },
  bed: { h: 16, color: "#e3d3f5" },
  bookshelf: { h: 42, color: "#b3814f" },
  sofa: { h: 22, color: "#efa08a" },
  tv: { h: 30, color: "#33393f" },
  computer: { h: 26, color: "#7a828c" },
  car: { h: 26, color: "#e35b52" },
  tree: { h: 36, color: "#5fae5f" },
  plant: { h: 18, color: "#6fae55" },
  piano: { h: 34, color: "#262626" },
  gym: { h: 26, color: "#9aa3ad" },
  firepit: { h: 14, color: "#d97a3d" },
  default: { h: 24, color: "#dddddd" },
};

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
      if (edgeBlocked(cx, cy, nx, ny)) continue;
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
    skills: { cooking: 0, fitness: 0, charisma: 0 },
    jobLevel: 0,
    shiftsWorked: 0,
    action: null, // { targetId, label, need, gain, duration, side, elapsed, isWork }
    atWork: false,
    walkPhase: 0,
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
    skill: a.skill || null, skillGain: a.skillGain || 0,
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
    const base = JOB_BASE_SALARY[sim.jobLevel];
    const charismaBonus = 1 + sim.skills.charisma * 0.03;
    const pay = Math.round(base * traitMod(sim.trait, "salary") * charismaBonus);
    state.money += pay;
    sim.shiftsWorked += 1;
    toast(`${sim.name} zarobił ${pay} zł jako ${JOB_TITLES[sim.jobLevel]}!`);
    if (sim.jobLevel < JOB_TITLES.length - 1 && sim.shiftsWorked % SHIFTS_PER_PROMOTION === 0) {
      sim.jobLevel += 1;
      toast(`🎉 Awans! ${sim.name} jest teraz: ${JOB_TITLES[sim.jobLevel]}`);
    }
  } else {
    toast(`${sim.name} ukończył: ${a.label}`);
  }
  if (a.skill && a.skillGain) {
    const before = sim.skills[a.skill];
    sim.skills[a.skill] = clamp(before + a.skillGain, 0, SKILL_MAX);
    if (Math.floor(sim.skills[a.skill]) > Math.floor(before)) {
      toast(`📈 ${SKILL_META[a.skill].label} wzrosło do poziomu ${Math.floor(sim.skills[a.skill])}!`);
    }
  }
  sim.action = null;
  sim.atWork = false;
}

/* ---------- Update loop ---------- */
function applyNeedDecay(minutesPassed) {
  const sim = state.sim;
  for (const k of NEED_KEYS) {
    let mod = traitMod(sim.trait, k, 1);
    if (k === "energy") mod *= 1 - sim.skills.fitness * 0.02;
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
      const skillMult = sim.action.skill ? 1 + sim.skills[sim.action.skill] * 0.05 : 1;
      sim.needs[sim.action.need] = clamp(
        sim.needs[sim.action.need] + sim.action.gain * frac * traitMod(sim.trait, "funGain", 1) * skillMult, 0, 100
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

  if (!sim.action && !sim.pendingAction && sim.path.length === 0) {
    autoFulfillCriticalNeed();
  }
}

function autoFulfillCriticalNeed() {
  const sim = state.sim;
  const critical = NEED_KEYS.filter((k) => sim.needs[k] <= 15).sort((a, b) => sim.needs[a] - sim.needs[b]);
  if (critical.length === 0) return;
  const need = critical[0];
  const candidates = [];
  for (const f of state.furniture) {
    if (f.action && !f.action.isWork && f.action.need === need) candidates.push(f);
  }
  for (const s of state.slots) {
    if (s.item && s.item.action && s.item.action.need === need) {
      candidates.push({ id: s.id, type: s.item.type, label: s.item.label, icon: s.item.icon, x: s.x, y: s.y, action: s.item.action });
    }
  }
  if (candidates.length === 0) return;
  candidates.sort((a, b) => (Math.abs(a.x - sim.x) + Math.abs(a.y - sim.y)) - (Math.abs(b.x - sim.x) + Math.abs(b.y - sim.y)));
  const target = candidates[0];
  const path = findPathToNeighbor(sim.x, sim.y, target.x, target.y);
  if (path === null) return;
  sim.path = path;
  sim.pendingAction = target;
  toast(`${sim.name} sam idzie zaspokoić potrzebę: ${NEED_META[need].label}`);
}

function moveSimAlongPath(dtSec) {
  const sim = state.sim;
  if (sim.path.length === 0) { sim.walkPhase = 0; return; }
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
  sim.walkPhase += dtSec * 9;
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

/* ---------- Rendering (isometric 3D) ---------- */
const ISO_TW = 52; // tile diamond full width
const ISO_TH = 26; // tile diamond full height
const ISO_TOP_MARGIN = WALL_H + 32; // room above the grid for walls / tall furniture / the sim
const ISO_SIDE_PAD = 26;

function isoX(tx, ty) { return (tx - ty) * (ISO_TW / 2); }
function isoY(tx, ty) { return (tx + ty) * (ISO_TH / 2); }

const ISO_MIN_X = isoX(0, ROWS - 1);
const ISO_MAX_X = isoX(COLS - 1, 0);
const ISO_MIN_Y = isoY(0, 0);
const ISO_MAX_Y = isoY(COLS - 1, ROWS - 1);
const ORIGIN_X = -ISO_MIN_X + ISO_SIDE_PAD + ISO_TW / 2;
const ORIGIN_Y = -ISO_MIN_Y + ISO_TOP_MARGIN;
const CANVAS_W = Math.ceil(ISO_MAX_X - ISO_MIN_X + ISO_TW + ISO_SIDE_PAD * 2);
const CANVAS_H = Math.ceil(ISO_MAX_Y - ISO_MIN_Y + ISO_TOP_MARGIN + ISO_TH + 30);

function project(tx, ty) { return { x: ORIGIN_X + isoX(tx, ty), y: ORIGIN_Y + isoY(tx, ty) }; }

function shade(hex, factor) {
  const r = parseInt(hex.slice(1, 3), 16), g = parseInt(hex.slice(3, 5), 16), b = parseInt(hex.slice(5, 7), 16);
  return `rgb(${Math.round(r * factor)},${Math.round(g * factor)},${Math.round(b * factor)})`;
}

function lerpPt(a, b, t) { return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t }; }
function facePoint(b0, b1, t0, t1, u, v) {
  const bx = b0.x + (b1.x - b0.x) * u, by = b0.y + (b1.y - b0.y) * u;
  const tx = t0.x + (t1.x - t0.x) * u, ty = t0.y + (t1.y - t0.y) * u;
  return { x: bx + (tx - bx) * v, y: by + (ty - by) * v };
}
function bilerp(N, E, S, W, u, v) {
  const x = N.x * (1 - u) * (1 - v) + E.x * u * (1 - v) + S.x * u * v + W.x * (1 - u) * v;
  const y = N.y * (1 - u) * (1 - v) + E.y * u * (1 - v) + S.y * u * v + W.y * (1 - u) * v;
  return { x, y };
}

function mulberry32(seed) {
  let t = seed >>> 0;
  return function () {
    t += 0x6d2b79f5;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r ^= r + Math.imul(r ^ (r >>> 7), 61 | r);
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

function hexToRgb(hex) {
  return { r: parseInt(hex.slice(1, 3), 16), g: parseInt(hex.slice(3, 5), 16), b: parseInt(hex.slice(5, 7), 16) };
}
function lerpColor(hex1, hex2, t) {
  const c1 = hexToRgb(hex1), c2 = hexToRgb(hex2);
  const r = Math.round(c1.r + (c2.r - c1.r) * t);
  const g = Math.round(c1.g + (c2.g - c1.g) * t);
  const b = Math.round(c1.b + (c2.b - c1.b) * t);
  return `rgb(${r},${g},${b})`;
}

const SKY_STOPS = [
  { h: 0, top: "#0b1030", bottom: "#1c2550" },
  { h: 5, top: "#0b1030", bottom: "#1c2550" },
  { h: 6.5, top: "#ff9d6c", bottom: "#ffd9a0" },
  { h: 8, top: "#8ec9f0", bottom: "#dff1ff" },
  { h: 17, top: "#8ec9f0", bottom: "#dff1ff" },
  { h: 19, top: "#ff8a5c", bottom: "#ffd08a" },
  { h: 21, top: "#2b2560", bottom: "#5a3a6e" },
  { h: 23, top: "#0b1030", bottom: "#1c2550" },
  { h: 24, top: "#0b1030", bottom: "#1c2550" },
];
function skyColors(hour) {
  let a = SKY_STOPS[0], b = SKY_STOPS[SKY_STOPS.length - 1];
  for (let i = 0; i < SKY_STOPS.length - 1; i++) {
    if (hour >= SKY_STOPS[i].h && hour <= SKY_STOPS[i + 1].h) { a = SKY_STOPS[i]; b = SKY_STOPS[i + 1]; break; }
  }
  const t = (hour - a.h) / Math.max(0.0001, b.h - a.h);
  return { top: lerpColor(a.top, b.top, t), bottom: lerpColor(a.bottom, b.bottom, t) };
}
function nightAmount(hour) {
  if (hour <= 5 || hour >= 21) return 1;
  if (hour >= 6 && hour <= 19) return 0;
  if (hour < 6) return 1 - (hour - 5);
  return (hour - 19) / 2;
}
function warmAmount(hour) {
  const dawn = Math.max(0, 1 - Math.abs(hour - 6.5) / 1.5);
  const dusk = Math.max(0, 1 - Math.abs(hour - 18.5) / 1.5);
  return Math.max(dawn, dusk);
}

const canvas = document.getElementById("canvas");
canvas.width = CANVAS_W;
canvas.height = CANVAS_H;
const ctx = canvas.getContext("2d");

function render() {
  const hourFloat = state.minutes / 60;
  const sky = skyColors(hourFloat);
  const skyGrad = ctx.createLinearGradient(0, 0, 0, canvas.height);
  skyGrad.addColorStop(0, sky.top);
  skyGrad.addColorStop(1, sky.bottom);
  ctx.fillStyle = skyGrad;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  const night = nightAmount(hourFloat);
  if (night > 0) {
    const rnd = mulberry32(42);
    ctx.fillStyle = `rgba(255,255,255,${0.85 * night})`;
    for (let i = 0; i < 40; i++) {
      const sx = rnd() * canvas.width, sy = rnd() * (ISO_TOP_MARGIN * 0.85);
      ctx.beginPath(); ctx.arc(sx, sy, rnd() * 1.2 + 0.3, 0, Math.PI * 2); ctx.fill();
    }
  }
  const isDay = hourFloat >= 6 && hourFloat <= 18;
  const discColor = isDay ? "#fff3c4" : "#e8ecf5";
  const glowColor = isDay ? "rgba(255,240,180,0.35)" : "rgba(220,225,245,0.22)";
  const sunX = 30 + (hourFloat / 24) * (canvas.width - 60);
  const sunY = 20 + 25 * Math.pow((hourFloat - 12) / 12, 2);
  const glow = ctx.createRadialGradient(sunX, sunY, 2, sunX, sunY, 28);
  glow.addColorStop(0, glowColor); glow.addColorStop(1, "rgba(255,255,255,0)");
  ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(sunX, sunY, 28, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = discColor; ctx.beginPath(); ctx.arc(sunX, sunY, 9, 0, Math.PI * 2); ctx.fill();

  // Pass 1: floor tiles.
  const floorItems = [];
  for (let ty = 0; ty < ROWS; ty++) {
    for (let tx = 0; tx < COLS; tx++) {
      const zone = zoneOf(tx, ty);
      floorItems.push({ depth: tx + ty, draw: () => drawFloorTile(tx, ty, zone) });
    }
  }
  floorItems.sort((a, b) => a.depth - b.depth);
  for (const it of floorItems) it.draw();

  // Pass 2: walls. Drawn as their own pass (always behind furniture/the sim) because a
  // tall wall panel can visually bleed into a lower-depth neighbor tile's screen space,
  // which would otherwise wrongly paint over furniture or the sim standing there.
  const wallItems = WALLS.map((w) => ({
    depth: w.tx + w.ty,
    draw: () => {
      if (w.kind === "door") drawDoorFrame(w.tx, w.ty, w.edge);
      else if (w.kind === "window") drawWallWindow(w.tx, w.ty, w.edge);
      else drawWallSolid(w.tx, w.ty, w.edge);
    },
  }));
  wallItems.sort((a, b) => a.depth - b.depth);
  for (const it of wallItems) it.draw();

  // Pass 3: furniture, shop slots and the sim, depth-sorted among themselves.
  const objItems = [];
  for (const f of state.furniture) {
    const v = VISUALS[f.type] || VISUALS.default;
    objItems.push({ depth: f.x + f.y + 0.5, draw: () => drawIsoObj(f, v) });
  }
  for (const s of state.slots) {
    if (s.item) {
      const v = VISUALS[s.item.type] || VISUALS.default;
      objItems.push({ depth: s.x + s.y + 0.5, draw: () => drawIsoObj({ x: s.x, y: s.y, icon: s.item.icon, type: s.item.type }, v) });
    } else {
      objItems.push({ depth: s.x + s.y + 0.4, draw: () => drawEmptySlot(s) });
    }
  }
  if (state.sim) {
    objItems.push({ depth: state.sim.x + state.sim.y + 0.6, draw: () => drawSim(state.sim) });
  }
  objItems.sort((a, b) => a.depth - b.depth);
  for (const it of objItems) it.draw();

  if (night > 0) {
    ctx.fillStyle = `rgba(15,20,55,${night * 0.38})`;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }
  const warm = warmAmount(hourFloat);
  if (warm > 0) {
    ctx.fillStyle = `rgba(255,140,60,${warm * 0.15})`;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }
}

function drawFloorTile(tx, ty, zone) {
  const { x: cx, y: cy } = project(tx, ty);
  const N = { x: cx, y: cy - ISO_TH / 2 }, E = { x: cx + ISO_TW / 2, y: cy };
  const S = { x: cx, y: cy + ISO_TH / 2 }, W = { x: cx - ISO_TW / 2, y: cy };
  const checker = (tx + ty) % 2 === 0;
  const base = zone.floorType === "tile" ? shade(zone.color, checker ? 1.0 : 0.93) : zone.color;

  ctx.beginPath();
  ctx.moveTo(N.x, N.y); ctx.lineTo(E.x, E.y); ctx.lineTo(S.x, S.y); ctx.lineTo(W.x, W.y); ctx.closePath();
  ctx.fillStyle = base;
  ctx.fill();

  if (zone.floorType === "wood") {
    ctx.save();
    ctx.clip();
    ctx.strokeStyle = "rgba(0,0,0,0.10)";
    ctx.lineWidth = 1;
    for (let i = 1; i <= 2; i++) {
      const p0 = lerpPt(W, N, i / 3), p1 = lerpPt(S, E, i / 3);
      ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.stroke();
    }
    ctx.restore();
  } else if (zone.floorType === "tile") {
    ctx.strokeStyle = "rgba(0,0,0,0.12)";
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(N.x, N.y); ctx.lineTo(S.x, S.y); ctx.moveTo(W.x, W.y); ctx.lineTo(E.x, E.y); ctx.stroke();
  } else if (zone.floorType === "grass") {
    const rnd = mulberry32(tx * 131 + ty * 977 + 7);
    ctx.fillStyle = "rgba(20,60,15,0.22)";
    for (let i = 0; i < 3; i++) {
      const u = rnd() * 2 - 1, v = rnd() * 2 - 1;
      if (Math.abs(u) + Math.abs(v) > 0.75) continue;
      const px = cx + u * (ISO_TW / 2) * 0.85, py = cy + v * (ISO_TH / 2) * 0.85;
      ctx.beginPath(); ctx.arc(px, py, 1.3, 0, Math.PI * 2); ctx.fill();
    }
  }

  ctx.strokeStyle = "rgba(0,0,0,0.10)";
  ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(N.x, N.y); ctx.lineTo(E.x, E.y); ctx.lineTo(S.x, S.y); ctx.lineTo(W.x, W.y); ctx.closePath();
  ctx.stroke();
}

function wallCorners(tx, ty, edge) {
  const { x: cx, y: cy } = project(tx, ty);
  const N = { x: cx, y: cy - ISO_TH / 2 };
  const E = { x: cx + ISO_TW / 2, y: cy };
  const W = { x: cx - ISO_TW / 2, y: cy };
  const topY = cy - WALL_H;
  const Nt = { x: N.x, y: topY - ISO_TH / 2 };
  if (edge === "N") {
    const Et = { x: E.x, y: topY };
    return { b0: N, b1: E, t0: Nt, t1: Et };
  }
  const Wt = { x: W.x, y: topY };
  return { b0: W, b1: N, t0: Wt, t1: Nt };
}

function drawWallSolid(tx, ty, edge) {
  const p = wallCorners(tx, ty, edge);
  const base = edge === "N" ? "#f1e8d9" : "#e2d8c4";
  ctx.beginPath();
  ctx.moveTo(p.b0.x, p.b0.y); ctx.lineTo(p.b1.x, p.b1.y); ctx.lineTo(p.t1.x, p.t1.y); ctx.lineTo(p.t0.x, p.t0.y);
  ctx.closePath();
  ctx.fillStyle = base;
  ctx.fill();
  ctx.strokeStyle = "rgba(0,0,0,0.15)";
  ctx.lineWidth = 1;
  ctx.stroke();

  const bb0 = facePoint(p.b0, p.b1, p.t0, p.t1, 0, 0.05), bb1 = facePoint(p.b0, p.b1, p.t0, p.t1, 1, 0.05);
  ctx.beginPath(); ctx.moveTo(p.b0.x, p.b0.y); ctx.lineTo(p.b1.x, p.b1.y); ctx.lineTo(bb1.x, bb1.y); ctx.lineTo(bb0.x, bb0.y); ctx.closePath();
  ctx.fillStyle = "rgba(0,0,0,0.12)"; ctx.fill();

  const tt0 = facePoint(p.b0, p.b1, p.t0, p.t1, 0, 0.94), tt1 = facePoint(p.b0, p.b1, p.t0, p.t1, 1, 0.94);
  ctx.beginPath(); ctx.moveTo(tt0.x, tt0.y); ctx.lineTo(tt1.x, tt1.y); ctx.lineTo(p.t1.x, p.t1.y); ctx.lineTo(p.t0.x, p.t0.y); ctx.closePath();
  ctx.fillStyle = "rgba(255,255,255,0.22)"; ctx.fill();
}

function drawWallWindow(tx, ty, edge) {
  drawWallSolid(tx, ty, edge);
  const p = wallCorners(tx, ty, edge);
  const c00 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.26, 0.32), c10 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.74, 0.32);
  const c11 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.74, 0.78), c01 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.26, 0.78);
  ctx.beginPath(); ctx.moveTo(c00.x, c00.y); ctx.lineTo(c10.x, c10.y); ctx.lineTo(c11.x, c11.y); ctx.lineTo(c01.x, c01.y); ctx.closePath();
  const sky = skyColors(state.minutes / 60);
  ctx.fillStyle = sky.bottom;
  ctx.fill();
  ctx.strokeStyle = "#6b4f34"; ctx.lineWidth = 2; ctx.stroke();
  const m0 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.5, 0.32), m1 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.5, 0.78);
  const m2 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.26, 0.55), m3 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.74, 0.55);
  ctx.beginPath(); ctx.moveTo(m0.x, m0.y); ctx.lineTo(m1.x, m1.y); ctx.moveTo(m2.x, m2.y); ctx.lineTo(m3.x, m3.y);
  ctx.strokeStyle = "#6b4f34"; ctx.lineWidth = 1.5; ctx.stroke();
}

function drawDoorFrame(tx, ty, edge) {
  const p = wallCorners(tx, ty, edge);
  const jw = 0.09;
  const parts = [[0, jw], [1 - jw, 1]];
  for (const [u0, u1] of parts) {
    const a = facePoint(p.b0, p.b1, p.t0, p.t1, u0, 0), b = facePoint(p.b0, p.b1, p.t0, p.t1, u1, 0);
    const c = facePoint(p.b0, p.b1, p.t0, p.t1, u1, 0.92), d = facePoint(p.b0, p.b1, p.t0, p.t1, u0, 0.92);
    ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.lineTo(c.x, c.y); ctx.lineTo(d.x, d.y); ctx.closePath();
    ctx.fillStyle = "#8a6b45"; ctx.fill(); ctx.strokeStyle = "rgba(0,0,0,0.25)"; ctx.lineWidth = 1; ctx.stroke();
  }
  const h0 = facePoint(p.b0, p.b1, p.t0, p.t1, 0, 0.92), h1 = facePoint(p.b0, p.b1, p.t0, p.t1, 1, 0.92);
  ctx.beginPath(); ctx.moveTo(h0.x, h0.y); ctx.lineTo(h1.x, h1.y); ctx.lineTo(p.t1.x, p.t1.y); ctx.lineTo(p.t0.x, p.t0.y); ctx.closePath();
  ctx.fillStyle = "#8a6b45"; ctx.fill(); ctx.strokeStyle = "rgba(0,0,0,0.25)"; ctx.stroke();
}

function drawIsoObj(obj, v) {
  const { x: cx, y: cy } = project(obj.x, obj.y);
  const topY = cy - v.h;
  const W = { x: cx - ISO_TW / 2, y: cy }, E = { x: cx + ISO_TW / 2, y: cy };
  const S = { x: cx, y: cy + ISO_TH / 2 }, N = { x: cx, y: cy - ISO_TH / 2 };
  const Wt = { x: W.x, y: topY }, Et = { x: E.x, y: topY };
  const St = { x: S.x, y: topY + ISO_TH / 2 }, Nt = { x: N.x, y: topY - ISO_TH / 2 };

  ctx.beginPath();
  ctx.moveTo(W.x, W.y); ctx.lineTo(S.x, S.y); ctx.lineTo(St.x, St.y); ctx.lineTo(Wt.x, Wt.y); ctx.closePath();
  ctx.fillStyle = shade(v.color, 0.68); ctx.fill();
  ctx.strokeStyle = "rgba(0,0,0,0.25)"; ctx.lineWidth = 1; ctx.stroke();

  ctx.beginPath();
  ctx.moveTo(S.x, S.y); ctx.lineTo(E.x, E.y); ctx.lineTo(Et.x, Et.y); ctx.lineTo(St.x, St.y); ctx.closePath();
  ctx.fillStyle = shade(v.color, 0.48); ctx.fill(); ctx.stroke();

  drawFurnitureDetail(obj, v, { N, E, S, W, Nt, Et, St, Wt });

  ctx.beginPath();
  ctx.moveTo(Nt.x, Nt.y); ctx.lineTo(Et.x, Et.y); ctx.lineTo(St.x, St.y); ctx.lineTo(Wt.x, Wt.y); ctx.closePath();
  ctx.fillStyle = v.color; ctx.fill();
  const sel = state.selectedObj && state.selectedObj.x === obj.x && state.selectedObj.y === obj.y;
  ctx.strokeStyle = sel ? "#ff6f59" : "rgba(0,0,0,0.3)";
  ctx.lineWidth = sel ? 3 : 1;
  ctx.stroke();

  if (obj.icon) {
    ctx.font = "20px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(obj.icon, cx, topY - 1);
  }
}

function drawFurnitureDetail(obj, v, g) {
  const { N, E, S, W, Nt, Et, St, Wt } = g;
  switch (obj.type) {
    case "bed": {
      const p0 = bilerp(Nt, Et, St, Wt, 0.15, 0.5), p1 = bilerp(Nt, Et, St, Wt, 0.85, 0.5);
      const p2 = bilerp(Nt, Et, St, Wt, 0.85, 0.95), p3 = bilerp(Nt, Et, St, Wt, 0.15, 0.95);
      ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.lineTo(p2.x, p2.y); ctx.lineTo(p3.x, p3.y); ctx.closePath();
      ctx.fillStyle = "#5b7fc4"; ctx.fill(); ctx.strokeStyle = "rgba(0,0,0,0.2)"; ctx.lineWidth = 1; ctx.stroke();
      const q0 = bilerp(Nt, Et, St, Wt, 0.15, 0.08), q1 = bilerp(Nt, Et, St, Wt, 0.85, 0.08);
      const q2 = bilerp(Nt, Et, St, Wt, 0.85, 0.42), q3 = bilerp(Nt, Et, St, Wt, 0.15, 0.42);
      ctx.beginPath(); ctx.moveTo(q0.x, q0.y); ctx.lineTo(q1.x, q1.y); ctx.lineTo(q2.x, q2.y); ctx.lineTo(q3.x, q3.y); ctx.closePath();
      ctx.fillStyle = "#fbfbf6"; ctx.fill(); ctx.strokeStyle = "rgba(0,0,0,0.15)"; ctx.stroke();
      break;
    }
    case "tv": {
      const p0 = facePoint(S, E, St, Et, 0.15, 0.25), p1 = facePoint(S, E, St, Et, 0.85, 0.25);
      const p2 = facePoint(S, E, St, Et, 0.85, 0.85), p3 = facePoint(S, E, St, Et, 0.15, 0.85);
      ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.lineTo(p2.x, p2.y); ctx.lineTo(p3.x, p3.y); ctx.closePath();
      const grad = ctx.createLinearGradient(p0.x, p0.y, p2.x, p2.y);
      grad.addColorStop(0, "#4a90d9"); grad.addColorStop(1, "#111820");
      ctx.fillStyle = grad; ctx.fill(); ctx.strokeStyle = "rgba(0,0,0,0.4)"; ctx.lineWidth = 1; ctx.stroke();
      break;
    }
    case "fridge": {
      const p0 = facePoint(S, E, St, Et, 0.24, 0.12), p1 = facePoint(S, E, St, Et, 0.32, 0.12);
      const p2 = facePoint(S, E, St, Et, 0.32, 0.88), p3 = facePoint(S, E, St, Et, 0.24, 0.88);
      ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.lineTo(p2.x, p2.y); ctx.lineTo(p3.x, p3.y); ctx.closePath();
      ctx.fillStyle = "rgba(0,0,0,0.32)"; ctx.fill();
      const s0 = facePoint(S, E, St, Et, 0.1, 0.32), s1 = facePoint(S, E, St, Et, 0.9, 0.32);
      ctx.beginPath(); ctx.moveTo(s0.x, s0.y); ctx.lineTo(s1.x, s1.y); ctx.strokeStyle = "rgba(0,0,0,0.18)"; ctx.lineWidth = 1; ctx.stroke();
      break;
    }
    case "bookshelf": {
      for (const hv of [0.3, 0.55, 0.8]) {
        const a = facePoint(W, S, Wt, St, 0, hv), b = facePoint(W, S, Wt, St, 1, hv);
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y);
        ctx.strokeStyle = "rgba(0,0,0,0.25)"; ctx.lineWidth = 1; ctx.stroke();
      }
      break;
    }
    case "car": {
      const p0 = facePoint(S, E, St, Et, 0.12, 0.5), p1 = facePoint(S, E, St, Et, 0.88, 0.5);
      const p2 = facePoint(S, E, St, Et, 0.88, 0.8), p3 = facePoint(S, E, St, Et, 0.12, 0.8);
      ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.lineTo(p2.x, p2.y); ctx.lineTo(p3.x, p3.y); ctx.closePath();
      ctx.fillStyle = "#bfe3f2"; ctx.fill(); ctx.strokeStyle = "rgba(0,0,0,0.3)"; ctx.lineWidth = 1; ctx.stroke();
      break;
    }
    case "sofa": {
      const a = facePoint(S, E, St, Et, 0.5, 0.15), b = facePoint(S, E, St, Et, 0.5, 0.85);
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.strokeStyle = "rgba(0,0,0,0.2)"; ctx.lineWidth = 1; ctx.stroke();
      break;
    }
    default:
      break;
  }
}

function drawEmptySlot(s) {
  const { x: cx, y: cy } = project(s.x, s.y);
  ctx.beginPath();
  ctx.moveTo(cx, cy - ISO_TH / 2 + 4);
  ctx.lineTo(cx + ISO_TW / 2 - 4, cy);
  ctx.lineTo(cx, cy + ISO_TH / 2 - 4);
  ctx.lineTo(cx - ISO_TW / 2 + 4, cy);
  ctx.closePath();
  ctx.setLineDash([4, 3]);
  ctx.strokeStyle = "rgba(50,50,50,0.55)";
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.font = "15px sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = "rgba(50,50,50,0.65)";
  ctx.fillText("🛒", cx, cy);
}

function drawSim(sim) {
  const { x: cx, y: cy } = project(sim.x, sim.y);

  ctx.beginPath();
  ctx.ellipse(cx, cy, ISO_TW * 0.2, ISO_TH * 0.32, 0, 0, Math.PI * 2);
  ctx.fillStyle = "rgba(0,0,0,0.28)";
  ctx.fill();

  const walking = sim.path.length > 0;
  const swing = walking ? Math.sin(sim.walkPhase) * 5 : 0;

  const legTopY = cy - 4, legH = 14;
  ctx.strokeStyle = "#33302c";
  ctx.lineCap = "round";
  ctx.lineWidth = 5;
  ctx.beginPath(); ctx.moveTo(cx - 4, legTopY); ctx.lineTo(cx - 4 - swing * 0.4, legTopY + legH); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx + 4, legTopY); ctx.lineTo(cx + 4 + swing * 0.4, legTopY + legH); ctx.stroke();

  const bodyH = 26, bw = 16;
  const bodyTopY = legTopY - bodyH;
  ctx.beginPath();
  ctx.moveTo(cx - bw / 2, legTopY);
  ctx.lineTo(cx - bw / 2, bodyTopY + bw / 2);
  ctx.arc(cx, bodyTopY + bw / 2, bw / 2, Math.PI, 0);
  ctx.lineTo(cx + bw / 2, legTopY);
  ctx.closePath();
  ctx.fillStyle = sim.color;
  ctx.fill();
  ctx.strokeStyle = "#22302a";
  ctx.lineWidth = 1.5;
  ctx.stroke();

  ctx.strokeStyle = sim.color;
  ctx.lineWidth = 4;
  ctx.lineCap = "round";
  ctx.beginPath(); ctx.moveTo(cx - bw / 2 + 1, bodyTopY + 6); ctx.lineTo(cx - bw / 2 - 2 - swing * 0.3, bodyTopY + 18); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx + bw / 2 - 1, bodyTopY + 6); ctx.lineTo(cx + bw / 2 + 2 + swing * 0.3, bodyTopY + 18); ctx.stroke();

  const headCy = bodyTopY - 7;
  ctx.beginPath();
  ctx.arc(cx, headCy, 8.5, 0, Math.PI * 2);
  ctx.fillStyle = "#f4c9a0";
  ctx.fill();
  ctx.strokeStyle = "#22302a";
  ctx.lineWidth = 1.2;
  ctx.stroke();

  ctx.beginPath();
  ctx.arc(cx, headCy - 1, 8.8, Math.PI * 1.05, Math.PI * 1.95);
  ctx.strokeStyle = "#4a3527";
  ctx.lineWidth = 4;
  ctx.stroke();

  ctx.fillStyle = "#22302a";
  ctx.beginPath(); ctx.arc(cx - 2.4, headCy, 0.9, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.arc(cx + 2.4, headCy, 0.9, 0, Math.PI * 2); ctx.fill();

  if (sim.action) {
    const frac = Math.min(1, sim.action.elapsed / sim.action.duration);
    const by = headCy - 16;
    ctx.fillStyle = "rgba(0,0,0,0.5)";
    ctx.fillRect(cx - 16, by, 32, 5);
    ctx.fillStyle = "#4caf50";
    ctx.fillRect(cx - 16, by, 32 * frac, 5);
  }
}

function pointInDiamond(px, py, cx, cy, hw, hh) {
  return Math.abs(px - cx) / hw + Math.abs(py - cy) / hh <= 1;
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

  document.getElementById("jobTitle").textContent = `💼 ${JOB_TITLES[sim.jobLevel]} (poziom ${sim.jobLevel + 1}/${JOB_TITLES.length})`;
  for (const k of Object.keys(SKILL_META)) {
    const el = document.querySelector(`.skill[data-skill="${k}"] .skill-fill`);
    const lvl = sim.skills[k];
    el.style.width = (lvl / SKILL_MAX) * 100 + "%";
    const label = document.querySelector(`.skill[data-skill="${k}"] .skill-level`);
    label.textContent = Math.floor(lvl) + "/" + SKILL_MAX;
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
function slotAsObj(s) {
  return { id: s.id, type: s.item.type, label: s.item.label, icon: s.item.icon, x: s.x, y: s.y, action: s.item.action };
}

canvas.addEventListener("click", (e) => {
  if (!state.sim) return;
  const rect = canvas.getBoundingClientRect();
  const scaleX = canvas.width / rect.width;
  const scaleY = canvas.height / rect.height;
  const mx = (e.clientX - rect.left) * scaleX;
  const my = (e.clientY - rect.top) * scaleY;

  // Tier 1: precise hit-test against each object's elevated top face.
  let hitObj = null, hitDepth = -Infinity;
  const tryHit = (ox, oy, h, obj) => {
    const { x: cx, y: cy } = project(ox, oy);
    if (pointInDiamond(mx, my, cx, cy - h, ISO_TW / 2, ISO_TH / 2)) {
      const d = ox + oy;
      if (d > hitDepth) { hitDepth = d; hitObj = obj; }
    }
  };
  for (const f of state.furniture) tryHit(f.x, f.y, (VISUALS[f.type] || VISUALS.default).h, f);
  for (const s of state.slots) if (s.item) tryHit(s.x, s.y, (VISUALS[s.item.type] || VISUALS.default).h, slotAsObj(s));

  if (hitObj) { openActionPanel(hitObj, mx, my); return; }

  // Tier 2: fall back to the floor-plane tile under the cursor.
  const rx = mx - ORIGIN_X, ry = my - ORIGIN_Y;
  const txf = (rx / (ISO_TW / 2) + ry / (ISO_TH / 2)) / 2;
  const tyf = (ry / (ISO_TH / 2) - rx / (ISO_TW / 2)) / 2;
  const tx = Math.round(txf), ty = Math.round(tyf);

  const furnHere = state.furniture.find((f) => f.x === tx && f.y === ty);
  if (furnHere) { openActionPanel(furnHere, mx, my); return; }

  const slotHere = state.slots.find((s) => s.x === tx && s.y === ty);
  if (slotHere) {
    if (slotHere.item) openActionPanel(slotAsObj(slotHere), mx, my);
    else openShopPanel(slotHere, mx, my);
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
      skills: state.sim.skills, jobLevel: state.sim.jobLevel, shiftsWorked: state.sim.shiftsWorked,
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
    state.sim.skills = data.sim.skills || { cooking: 0, fitness: 0, charisma: 0 };
    state.sim.jobLevel = data.sim.jobLevel || 0;
    state.sim.shiftsWorked = data.sim.shiftsWorked || 0;
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
