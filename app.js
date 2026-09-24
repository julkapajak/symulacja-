"use strict";

/* ---------- Grid constants ---------- */
const COLS = 16;
const ROWS = 9;
const BASE_MIN_MS = 150; // real ms per game minute at 1x speed
const SAVE_KEY = "simlife_save_v2";

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

/* ---------- Needs / traits / skills / career ---------- */
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

const COLORS = ["#ff6f59", "#3fa796", "#f6c445", "#7b6cf6", "#e85ea0", "#4fb0e8"];

const SKILL_META = {
  cooking: { icon: "🍳", label: "Gotowanie" },
  fitness: { icon: "💪", label: "Kondycja" },
  charisma: { icon: "🗣️", label: "Charyzma" },
};
const SKILL_MAX = 10;

const JOB_TITLES = ["Stażysta", "Pracownik", "Specjalista", "Kierownik", "Dyrektor", "Prezes"];
const JOB_BASE_SALARY = [80, 120, 170, 230, 300, 400];
const SHIFTS_PER_PROMOTION = 3;

/* ---------- Item catalog (furniture types: visuals + action + cost) ---------- */
const ITEM_CATALOG = {
  fridge: { label: "Lodówka", icon: "🍽️", cost: 300, h: 40, color: "#f2f4f4",
    action: { label: "Zjedz", need: "hunger", gain: 60, duration: 20, side: {}, skill: "cooking", skillGain: 0.12 } },
  sink: { label: "Umywalka", icon: "🚰", cost: 120, h: 20, color: "#dceff5",
    action: { label: "Umyj ręce", need: "hygiene", gain: 20, duration: 8, side: {} } },
  toilet: { label: "Toaleta", icon: "🚽", cost: 250, h: 22, color: "#ffffff",
    action: { label: "Skorzystaj z toalety", need: "bladder", gain: 100, duration: 6, side: {} } },
  shower: { label: "Prysznic", icon: "🚿", cost: 350, h: 34, color: "#cdeaf7",
    action: { label: "Weź prysznic", need: "hygiene", gain: 100, duration: 15, side: { energy: 5 } } },
  bed: { label: "Łóżko", icon: "🛏️", cost: 400, h: 16, color: "#e3d3f5",
    action: { label: "Śpij", need: "energy", gain: 100, duration: 240, side: { hygiene: -10, bladder: -15 } } },
  bookshelf: { label: "Regał", icon: "📚", cost: 220, h: 42, color: "#b3814f",
    action: { label: "Czytaj", need: "fun", gain: 25, duration: 30, side: {} } },
  sofa: { label: "Sofa", icon: "🛋️", cost: 280, h: 22, color: "#efa08a",
    action: { label: "Odpoczywaj", need: "fun", gain: 20, duration: 40, side: { energy: 10 } } },
  tv: { label: "Telewizor", icon: "📺", cost: 500, h: 30, color: "#33393f",
    action: { label: "Oglądaj TV", need: "fun", gain: 35, duration: 60, side: { energy: -5 } } },
  computer: { label: "Komputer", icon: "💻", cost: 450, h: 26, color: "#7a828c",
    action: { label: "Graj na komputerze", need: "fun", gain: 30, duration: 55, side: { energy: -10 } } },
  plant: { label: "Roślina", icon: "🪴", cost: 150, h: 18, color: "#6fae55",
    action: { label: "Podziwiaj roślinę", need: "fun", gain: 12, duration: 10, side: {} } },
  piano: { label: "Pianino", icon: "🎹", cost: 400, h: 34, color: "#262626",
    action: { label: "Zagraj na pianinie", need: "fun", gain: 40, duration: 50, side: {} } },
  gym: { label: "Siłownia", icon: "🏋️", cost: 450, h: 26, color: "#9aa3ad",
    action: { label: "Ćwicz", need: "fun", gain: 25, duration: 45, side: { energy: -10 }, skill: "fitness", skillGain: 0.25 } },
  firepit: { label: "Ognisko", icon: "🔥", cost: 200, h: 14, color: "#d97a3d",
    action: { label: "Usiądź przy ognisku", need: "social", gain: 30, duration: 40, side: { fun: 20 }, skill: "charisma", skillGain: 0.2 } },
  car: { label: "Praca (Samochód)", icon: "🚗", cost: 0, h: 26, color: "#e35b52",
    action: { label: "Jedź do pracy", isWork: true, duration: 480, side: { energy: -30, fun: -10, social: -10, hygiene: -15, hunger: -20 } }, fixed: true },
  tree: { label: "Drzewo", icon: "🌳", cost: 60, h: 36, color: "#5fae5f", action: null },
};

function makeItem(id, type, x, y) { return { id, type, x, y }; }
const STARTER_ITEMS = [
  makeItem("fridge", "fridge", 1, 1),
  makeItem("sink", "sink", 2, 1),
  makeItem("toilet", "toilet", 1, 5),
  makeItem("shower", "shower", 1, 7),
  makeItem("bed", "bed", 5, 2),
  makeItem("bookshelf", "bookshelf", 7, 1),
  makeItem("sofa", "sofa", 9, 3),
  makeItem("tv", "tv", 10, 3),
  makeItem("computer", "computer", 9, 6),
  makeItem("car", "car", 13, 3),
  makeItem("tree", "tree", 14, 1),
];

/* ---------- Game state ---------- */
const state = {
  sim: null,
  partner: null,
  relationship: 30,
  money: 500,
  day: 1,
  minutes: 8 * 60,
  speed: 1,
  items: STARTER_ITEMS.map((i) => ({ ...i })),
  buildMode: false,
  movingItemId: null,
  pendingPlaceTile: null,
  lastFrame: 0,
  accumMs: 0,
  selectedObj: null,
  itemCounter: 1,
  camera: { zoom: 1, camX: 0, camY: 0 },
};

function itemAt(x, y) {
  return state.items.find((i) => i.x === x && i.y === y) || null;
}
function occupiedTiles() {
  const set = new Set();
  for (const i of state.items) set.add(i.x + "," + i.y);
  return set;
}
function isWalkable(x, y) {
  if (x < 0 || y < 0 || x >= COLS || y >= ROWS) return false;
  return !occupiedTiles().has(x + "," + y);
}

/* ---------- Pathfinding (BFS, wall-aware) ---------- */
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

function findPathToTile(sx, sy, tx, ty) {
  const sxr = Math.round(sx), syr = Math.round(sy);
  const { dist, prev, key } = bfsFrom(sxr, syr);
  if (!dist.has(tx + "," + ty)) return null;
  if (sxr === tx && syr === ty) return [];
  return reconstructPath(prev, key, sxr, syr, tx, ty);
}

/* ---------- Sim ---------- */
function createSim(name, color, traitKey) {
  return {
    name, color, trait: traitKey,
    x: 3, y: 3,
    path: [],
    speed: 4.2,
    needs: { hunger: 85, energy: 85, hygiene: 85, fun: 85, social: 85, bladder: 85 },
    skills: { cooking: 0, fitness: 0, charisma: 0 },
    jobLevel: 0,
    shiftsWorked: 0,
    action: null,
    pendingAction: null,
    atWork: false,
    walkPhase: 0,
    _warned: {},
  };
}

function traitMod(trait, key, def = 1) {
  const t = TRAITS[trait];
  if (!t || !t.mods || t.mods[key] === undefined) return def;
  return t.mods[key];
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

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
function catalogOf(item) { return ITEM_CATALOG[item.type]; }

function startAction(sim, item) {
  const cat = catalogOf(item);
  if (!cat || !cat.action) return;
  const path = findPathToNeighbor(sim.x, sim.y, item.x, item.y);
  if (path === null) { toast("Nie można dojść do tego obiektu."); return; }
  sim.path = path;
  sim.pendingAction = item;
  closePanels();
}

function beginPendingActionIfArrived(sim) {
  if (!sim.pendingAction) return;
  if (sim.path.length > 0) return;
  const item = sim.pendingAction;
  sim.pendingAction = null;
  const cat = catalogOf(item);
  if (!cat || !cat.action) return;
  const a = cat.action;
  if (a.isWork) {
    const hour = Math.floor(state.minutes / 60) % 24;
    if (hour < 8 || hour >= 18) {
      if (sim === state.sim) toast("Praca dostępna tylko w godzinach 8:00–18:00.");
      return;
    }
  }
  sim.action = {
    itemId: item.id, label: a.label, need: a.need, gain: a.gain,
    duration: a.duration, side: a.side || {}, elapsed: 0, isWork: !!a.isWork,
    skill: a.skill || null, skillGain: a.skillGain || 0,
  };
  sim.atWork = !!a.isWork;
  toast(`${sim.name}: ${a.label}...`);
}

function cancelAction(sim) {
  if (sim.action) {
    if (sim.action.isWork) toast(`${sim.name} przerwał pracę.`);
    sim.action = null;
    sim.atWork = false;
  }
  sim.pendingAction = null;
  sim.path = [];
  closePanels();
}

function finishAction(sim) {
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
      toast(`📈 ${sim.name}: ${SKILL_META[a.skill].label} → poziom ${Math.floor(sim.skills[a.skill])}!`);
    }
  }
  sim.action = null;
  sim.atWork = false;
}

/* ---------- Per-sim update loop ---------- */
function applyNeedDecay(sim, minutesPassed) {
  for (const k of NEED_KEYS) {
    let mod = traitMod(sim.trait, k, 1);
    if (k === "energy") mod *= 1 - sim.skills.fitness * 0.02;
    const rate = NEED_META[k].decay * mod;
    sim.needs[k] = clamp(sim.needs[k] - rate * minutesPassed, 0, 100);
  }
}

function progressAction(sim, n) {
  if (!sim.action) return;
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
  if (sim.action.elapsed >= sim.action.duration) finishAction(sim);
}

function checkWarnings(sim) {
  for (const k of NEED_KEYS) {
    if (sim.needs[k] <= 12 && !sim._warned[k]) {
      sim._warned[k] = true;
      toast(`⚠️ ${NEED_META[k].label} (${sim.name}) jest krytycznie niska!`);
    } else if (sim.needs[k] > 25 && sim._warned[k]) {
      sim._warned[k] = false;
    }
  }
}

function autonomyTick(sim, proactive) {
  if (!sim) return;
  if (sim.action || sim.pendingAction || sim.path.length > 0) return;
  const threshold = proactive ? 55 : 15;
  const needy = NEED_KEYS.filter((k) => sim.needs[k] <= threshold).sort((a, b) => sim.needs[a] - sim.needs[b]);
  let need = needy[0];
  if (!need && proactive && Math.random() < 0.12) {
    need = Math.random() < 0.5 ? "fun" : "social";
  }
  if (!need) return;
  const candidates = state.items.filter((i) => {
    const cat = catalogOf(i);
    return cat && cat.action && !cat.action.isWork && cat.action.need === need;
  });
  if (candidates.length === 0) return;
  candidates.sort((a, b) => (Math.abs(a.x - sim.x) + Math.abs(a.y - sim.y)) - (Math.abs(b.x - sim.x) + Math.abs(b.y - sim.y)));
  const target = candidates[0];
  const path = findPathToNeighbor(sim.x, sim.y, target.x, target.y);
  if (path === null) return;
  sim.path = path;
  sim.pendingAction = target;
  if (!proactive) toast(`${sim.name} sam idzie zaspokoić potrzebę: ${NEED_META[need].label}`);
}

function moveSimAlongPath(sim, dtSec) {
  if (!sim) return;
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

/* ---------- Global tick / loop ---------- */
function tickMinutes(n) {
  state.minutes += n;
  while (state.minutes >= 1440) { state.minutes -= 1440; state.day += 1; }

  applyNeedDecay(state.sim, n);
  progressAction(state.sim, n);
  checkWarnings(state.sim);
  autonomyTick(state.sim, false);

  if (state.partner) {
    applyNeedDecay(state.partner, n);
    progressAction(state.partner, n);
    checkWarnings(state.partner);
    autonomyTick(state.partner, true);
  }
}

function gameLoop(ts) {
  if (!state.lastFrame) state.lastFrame = ts;
  const dtMs = ts - state.lastFrame;
  state.lastFrame = ts;

  if (state.sim && state.speed > 0) {
    moveSimAlongPath(state.sim, dtMs / 1000);
    beginPendingActionIfArrived(state.sim);
    if (state.partner) {
      moveSimAlongPath(state.partner, dtMs / 1000);
      beginPendingActionIfArrived(state.partner);
    }

    state.accumMs += dtMs * state.speed;
    while (state.accumMs >= BASE_MIN_MS) {
      state.accumMs -= BASE_MIN_MS;
      tickMinutes(1);
    }
  }

  render();
  updateUI();
  requestAnimationFrame(gameLoop);
}

/* ---------- Rendering geometry helpers ---------- */
const ISO_TW = 52;
const ISO_TH = 26;
const ISO_TOP_MARGIN = WALL_H + 32;
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
function pointInDiamond(px, py, cx, cy, hw, hh) {
  return Math.abs(px - cx) / hw + Math.abs(py - cy) / hh <= 1;
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

/* ---------- Canvas + fullscreen fit transform (with user zoom/pan camera) ---------- */
const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");
let dpr = 1, fitScale = 1, topBarH = 0, botHudH = 0;
const ZOOM_MIN = 1, ZOOM_MAX = 4.5;

function resizeCanvas() {
  dpr = Math.min(window.devicePixelRatio || 1, 2);
  const topEl = document.getElementById("topbar");
  const botEl = document.getElementById("bottomHud");
  topBarH = topEl ? topEl.getBoundingClientRect().height : 0;
  botHudH = botEl ? botEl.getBoundingClientRect().height : 0;
  const vw = window.innerWidth, vh = window.innerHeight;
  const availW = Math.max(200, vw - 24);
  const availH = Math.max(200, vh - topBarH - botHudH - 20);
  const rawScale = Math.min(availW / CANVAS_W, availH / CANVAS_H);
  fitScale = Math.max(0.5, Math.min(rawScale, 2.6));
  canvas.width = Math.max(1, Math.round(vw * dpr));
  canvas.height = Math.max(1, Math.round(vh * dpr));
  canvas.style.width = vw + "px";
  canvas.style.height = vh + "px";
}
window.addEventListener("resize", resizeCanvas);
window.addEventListener("orientationchange", resizeCanvas);

function viewCenter() {
  return { x: window.innerWidth / 2, y: topBarH + (window.innerHeight - topBarH - botHudH) / 2 };
}
function getTransform() {
  const scale = fitScale * state.camera.zoom;
  const c = viewCenter();
  return { scale, offCssX: c.x - state.camera.camX * scale, offCssY: c.y - state.camera.camY * scale };
}
function clampCamera() {
  state.camera.camX = clamp(state.camera.camX, -CANVAS_W * 0.15, CANVAS_W * 1.15);
  state.camera.camY = clamp(state.camera.camY, -CANVAS_H * 0.15, CANVAS_H * 1.15);
}
function setZoomAt(cssX, cssY, targetZoom) {
  const before = getTransform();
  const nativeX = state.camera.camX + (cssX - viewCenter().x) / before.scale;
  const nativeY = state.camera.camY + (cssY - viewCenter().y) / before.scale;
  state.camera.zoom = clamp(targetZoom, ZOOM_MIN, ZOOM_MAX);
  const after = getTransform();
  state.camera.camX = nativeX - (cssX - viewCenter().x) / after.scale;
  state.camera.camY = nativeY - (cssY - viewCenter().y) / after.scale;
  clampCamera();
}
function zoomBy(cssX, cssY, factor) { setZoomAt(cssX, cssY, state.camera.zoom * factor); }
function resetCamera() {
  state.camera.zoom = 1;
  state.camera.camX = CANVAS_W / 2;
  state.camera.camY = CANVAS_H / 2;
}
resetCamera();

/* ---------- Render ---------- */
function render() {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.fillStyle = "#05070f";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  const { scale, offCssX, offCssY } = getTransform();
  ctx.setTransform(dpr * scale, 0, 0, dpr * scale, dpr * offCssX, dpr * offCssY);

  const hourFloat = state.minutes / 60;
  const sky = skyColors(hourFloat);
  const skyGrad = ctx.createLinearGradient(0, 0, 0, CANVAS_H);
  skyGrad.addColorStop(0, sky.top);
  skyGrad.addColorStop(1, sky.bottom);
  ctx.fillStyle = skyGrad;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  const night = nightAmount(hourFloat);
  if (night > 0) {
    const rnd = mulberry32(42);
    ctx.fillStyle = `rgba(255,255,255,${0.85 * night})`;
    for (let i = 0; i < 50; i++) {
      const sx = rnd() * CANVAS_W, sy = rnd() * (ISO_TOP_MARGIN * 0.85);
      ctx.beginPath(); ctx.arc(sx, sy, rnd() * 1.2 + 0.3, 0, Math.PI * 2); ctx.fill();
    }
  }
  const isDay = hourFloat >= 6 && hourFloat <= 18;
  const discColor = isDay ? "#fff3c4" : "#e8ecf5";
  const glowColor = isDay ? "rgba(255,240,180,0.35)" : "rgba(220,225,245,0.22)";
  const sunX = 30 + (hourFloat / 24) * (CANVAS_W - 60);
  const sunY = 20 + 25 * Math.pow((hourFloat - 12) / 12, 2);
  const glow = ctx.createRadialGradient(sunX, sunY, 2, sunX, sunY, 28);
  glow.addColorStop(0, glowColor); glow.addColorStop(1, "rgba(255,255,255,0)");
  ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(sunX, sunY, 28, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = discColor; ctx.beginPath(); ctx.arc(sunX, sunY, 9, 0, Math.PI * 2); ctx.fill();

  const floorItems = [];
  for (let ty = 0; ty < ROWS; ty++) {
    for (let tx = 0; tx < COLS; tx++) {
      const zone = zoneOf(tx, ty);
      floorItems.push({ depth: tx + ty, draw: () => drawFloorTile(tx, ty, zone) });
    }
  }
  floorItems.sort((a, b) => a.depth - b.depth);
  for (const it of floorItems) it.draw();

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

  const objItems = [];
  for (const item of state.items) {
    const cat = catalogOf(item);
    objItems.push({ depth: item.x + item.y + 0.5, draw: () => drawIsoObj(item, cat) });
  }
  if (state.sim) objItems.push({ depth: state.sim.x + state.sim.y + 0.6, draw: () => drawSim(state.sim) });
  if (state.partner) objItems.push({ depth: state.partner.x + state.partner.y + 0.62, draw: () => drawSim(state.partner) });
  objItems.sort((a, b) => a.depth - b.depth);
  for (const it of objItems) it.draw();

  if (night > 0) {
    ctx.fillStyle = `rgba(15,20,55,${night * 0.38})`;
    ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
  }
  const warm = warmAmount(hourFloat);
  if (warm > 0) {
    ctx.fillStyle = `rgba(255,140,60,${warm * 0.15})`;
    ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
  }
  if (state.buildMode) {
    ctx.strokeStyle = "rgba(255,122,89,0.55)";
    ctx.lineWidth = 6;
    ctx.strokeRect(3, 3, CANVAS_W - 6, CANVAS_H - 6);
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

  if (state.buildMode && !occupiedTiles().has(tx + "," + ty)) {
    ctx.strokeStyle = "rgba(255,255,255,0.28)";
    ctx.setLineDash([3, 3]);
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(N.x, N.y); ctx.lineTo(E.x, E.y); ctx.lineTo(S.x, S.y); ctx.lineTo(W.x, W.y); ctx.closePath(); ctx.stroke();
    ctx.setLineDash([]);
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

function drawIsoObj(item, cat) {
  const { x: cx, y: cy } = project(item.x, item.y);
  const topY = cy - cat.h;
  const W = { x: cx - ISO_TW / 2, y: cy }, E = { x: cx + ISO_TW / 2, y: cy };
  const S = { x: cx, y: cy + ISO_TH / 2 }, N = { x: cx, y: cy - ISO_TH / 2 };
  const Wt = { x: W.x, y: topY }, Et = { x: E.x, y: topY };
  const St = { x: S.x, y: topY + ISO_TH / 2 }, Nt = { x: N.x, y: topY - ISO_TH / 2 };

  ctx.beginPath();
  ctx.moveTo(W.x, W.y); ctx.lineTo(S.x, S.y); ctx.lineTo(St.x, St.y); ctx.lineTo(Wt.x, Wt.y); ctx.closePath();
  ctx.fillStyle = shade(cat.color, 0.68); ctx.fill();
  ctx.strokeStyle = "rgba(0,0,0,0.25)"; ctx.lineWidth = 1; ctx.stroke();

  ctx.beginPath();
  ctx.moveTo(S.x, S.y); ctx.lineTo(E.x, E.y); ctx.lineTo(Et.x, Et.y); ctx.lineTo(St.x, St.y); ctx.closePath();
  ctx.fillStyle = shade(cat.color, 0.48); ctx.fill(); ctx.stroke();

  drawFurnitureDetail(item.type, { N, E, S, W, Nt, Et, St, Wt });

  ctx.beginPath();
  ctx.moveTo(Nt.x, Nt.y); ctx.lineTo(Et.x, Et.y); ctx.lineTo(St.x, St.y); ctx.lineTo(Wt.x, Wt.y); ctx.closePath();
  ctx.fillStyle = cat.color; ctx.fill();
  const sel = state.selectedObj && state.selectedObj.x === item.x && state.selectedObj.y === item.y;
  const moving = state.movingItemId === item.id;
  ctx.strokeStyle = moving ? "#3fd0c9" : sel ? "#ff6f59" : "rgba(0,0,0,0.3)";
  ctx.lineWidth = moving || sel ? 3 : 1;
  ctx.stroke();

  if (cat.icon) {
    ctx.font = "20px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.globalAlpha = moving ? 0.55 : 1;
    ctx.fillText(cat.icon, cx, topY - 1);
    ctx.globalAlpha = 1;
  }
}

function drawFurnitureDetail(type, g) {
  const { N, E, S, W, Nt, Et, St, Wt } = g;
  switch (type) {
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

function drawSim(sim) {
  const { x: cx, y: cy } = project(sim.x, sim.y);

  const shadowGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, ISO_TW * 0.22);
  shadowGrad.addColorStop(0, "rgba(0,0,0,0.32)");
  shadowGrad.addColorStop(1, "rgba(0,0,0,0)");
  ctx.beginPath();
  ctx.ellipse(cx, cy, ISO_TW * 0.22, ISO_TH * 0.34, 0, 0, Math.PI * 2);
  ctx.fillStyle = shadowGrad;
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
  ctx.strokeStyle = sim === state.partner ? "#2b2118" : "#4a3527";
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

/* ---------- UI ---------- */
function moodFromNeeds(sim) {
  const avg = NEED_KEYS.reduce((s, k) => s + sim.needs[k], 0) / NEED_KEYS.length;
  if (avg >= 80) return "😄";
  if (avg >= 60) return "🙂";
  if (avg >= 40) return "😐";
  if (avg >= 20) return "😟";
  return "😫";
}
function relationshipLabel(v) {
  if (v < 20) return "Nieznajomi";
  if (v < 50) return "Znajomi";
  if (v < 80) return "Bliscy";
  return "Zakochani";
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
    const el = document.querySelector(`#needsPanel .need[data-need="${k}"] .need-fill`);
    const v = sim.needs[k];
    el.style.width = v + "%";
    el.style.background = v > 60 ? "#4caf50" : v > 30 ? "#f6c445" : "#e35b5b";
  }

  document.getElementById("jobTitle").textContent = `💼 ${JOB_TITLES[sim.jobLevel]} (${sim.jobLevel + 1}/${JOB_TITLES.length})`;
  for (const k of Object.keys(SKILL_META)) {
    const el = document.querySelector(`.skill[data-skill="${k}"] .skill-fill`);
    const lvl = sim.skills[k];
    el.style.width = (lvl / SKILL_MAX) * 100 + "%";
    document.querySelector(`.skill[data-skill="${k}"] .skill-level`).textContent = Math.floor(lvl) + "/" + SKILL_MAX;
  }

  const partnerPanel = document.getElementById("partnerPanel");
  if (state.partner) {
    partnerPanel.classList.remove("hidden");
    document.getElementById("partnerName").textContent = state.partner.name;
    document.getElementById("partnerMood").textContent = moodFromNeeds(state.partner);
    for (const k of ["hunger", "energy", "fun"]) {
      const el = document.querySelector(`#partnerPanel .need[data-pneed="${k}"] .need-fill`);
      const v = state.partner.needs[k];
      el.style.width = v + "%";
      el.style.background = v > 60 ? "#4caf50" : v > 30 ? "#f6c445" : "#e35b5b";
    }
    document.getElementById("relFill").style.width = state.relationship + "%";
    document.getElementById("relLabel").textContent = relationshipLabel(state.relationship);
  } else {
    partnerPanel.classList.add("hidden");
  }

  document.getElementById("buildBtn").classList.toggle("active", state.buildMode);
}

/* ---------- Panels ---------- */
function closePanels() {
  document.getElementById("actionPanel").classList.add("hidden");
  document.getElementById("shopPanel").classList.add("hidden");
  state.selectedObj = null;
}

function panelHeader(panel, titleText) {
  panel.innerHTML = "";
  const closeBtn = document.createElement("button");
  closeBtn.className = "panelClose";
  closeBtn.textContent = "✕";
  closeBtn.onclick = closePanels;
  panel.appendChild(closeBtn);
  const h = document.createElement("h4");
  h.textContent = titleText;
  panel.appendChild(h);
}

function openActionPanel(item, px, py) {
  closePanels();
  state.selectedObj = item;
  const cat = catalogOf(item);
  const panel = document.getElementById("actionPanel");
  panelHeader(panel, cat.label);

  if (cat.action) {
    const btn = document.createElement("button");
    btn.className = "panelBtn";
    btn.textContent = cat.action.label;
    btn.onclick = () => startAction(state.sim, item);
    panel.appendChild(btn);
  } else {
    const p = document.createElement("div");
    p.className = "panelHint";
    p.textContent = "Ten obiekt jest dekoracyjny.";
    panel.appendChild(p);
  }

  if (state.sim.action && state.sim.action.itemId === item.id) {
    const cancel = document.createElement("button");
    cancel.className = "panelBtn";
    cancel.textContent = "Anuluj czynność";
    cancel.onclick = () => cancelAction(state.sim);
    panel.appendChild(cancel);
  }

  positionPanel(panel, px, py);
  panel.classList.remove("hidden");
}

function openManagePanel(item, px, py) {
  closePanels();
  const cat = catalogOf(item);
  const panel = document.getElementById("shopPanel");
  panelHeader(panel, `🔨 ${cat.label}`);

  if (cat.fixed) {
    const p = document.createElement("div");
    p.className = "panelHint";
    p.textContent = "Tego obiektu nie można przenieść ani sprzedać.";
    panel.appendChild(p);
  } else {
    const moveBtn = document.createElement("button");
    moveBtn.className = "panelBtn";
    moveBtn.textContent = "↔️ Przenieś";
    moveBtn.onclick = () => {
      state.movingItemId = item.id;
      closePanels();
      toast("Kliknij puste miejsce, aby przenieść mebel.");
    };
    panel.appendChild(moveBtn);

    const refund = Math.round(cat.cost * 0.5);
    const sellBtn = document.createElement("button");
    sellBtn.className = "panelBtn";
    sellBtn.textContent = `💰 Sprzedaj (+${refund} zł)`;
    sellBtn.onclick = () => {
      state.items = state.items.filter((i) => i.id !== item.id);
      state.money += refund;
      toast(`Sprzedano: ${cat.label} (+${refund} zł)`);
      closePanels();
    };
    panel.appendChild(sellBtn);
  }

  positionPanel(panel, px, py);
  panel.classList.remove("hidden");
}

function openSocialPanel(px, py) {
  closePanels();
  const sim = state.sim, partner = state.partner;
  const adjacent = Math.abs(Math.round(sim.x) - Math.round(partner.x)) + Math.abs(Math.round(sim.y) - Math.round(partner.y)) <= 1;
  const panel = document.getElementById("actionPanel");
  panelHeader(panel, `${partner.name} · ${relationshipLabel(state.relationship)}`);

  if (!adjacent) {
    const p = document.createElement("div");
    p.className = "panelHint";
    p.textContent = "Podejdź bliżej, aby wejść w interakcję.";
    panel.appendChild(p);
  }

  const interactions = [
    { label: "💬 Porozmawiaj", min: 0, social: 15, fun: 0, rel: 3 },
    { label: "🤗 Przytul", min: 20, social: 12, fun: 12, rel: 5 },
    { label: "💋 Pocałuj", min: 50, social: 18, fun: 18, rel: 8 },
  ];
  for (const it of interactions) {
    const btn = document.createElement("button");
    btn.className = "panelBtn";
    btn.textContent = it.label + (state.relationship < it.min ? ` (wymaga: ${relationshipLabel(it.min)})` : "");
    btn.disabled = !adjacent || state.relationship < it.min;
    btn.onclick = () => {
      sim.needs.social = clamp(sim.needs.social + it.social, 0, 100);
      partner.needs.social = clamp(partner.needs.social + it.social, 0, 100);
      sim.needs.fun = clamp(sim.needs.fun + it.fun, 0, 100);
      partner.needs.fun = clamp(partner.needs.fun + it.fun, 0, 100);
      state.relationship = clamp(state.relationship + it.rel, 0, 100);
      toast(`${sim.name} i ${partner.name}: ${it.label}`);
      closePanels();
    };
    panel.appendChild(btn);
  }

  positionPanel(panel, px, py);
  panel.classList.remove("hidden");
}

function positionPanel(panel, px, py) {
  panel.style.left = Math.min(Math.max(px + 16, 8), window.innerWidth - 200) + "px";
  panel.style.top = Math.min(Math.max(py - 30, 8), window.innerHeight - 160) + "px";
}

/* ---------- Item picker (build mode: place new item) ---------- */
function openItemPicker(tx, ty) {
  state.pendingPlaceTile = { x: tx, y: ty };
  const grid = document.getElementById("itemPickerGrid");
  grid.innerHTML = "";
  for (const [type, cat] of Object.entries(ITEM_CATALOG)) {
    if (cat.fixed) continue;
    const card = document.createElement("button");
    card.className = "itemCard";
    card.disabled = state.money < cat.cost;
    card.innerHTML = `<span class="itemIcon">${cat.icon}</span>${cat.label}<span class="itemCost">${cat.cost} zł</span>`;
    card.onclick = () => {
      if (state.money < cat.cost) return;
      state.money -= cat.cost;
      const id = `item_${state.itemCounter++}`;
      state.items.push(makeItem(id, type, tx, ty));
      toast(`Postawiono: ${cat.label}`);
      document.getElementById("itemPicker").classList.add("hidden");
    };
    grid.appendChild(card);
  }
  document.getElementById("itemPicker").classList.remove("hidden");
}

/* ---------- Input ---------- */
function screenToNative(clientX, clientY) {
  const rect = canvas.getBoundingClientRect();
  const relX = clientX - rect.left, relY = clientY - rect.top;
  const { scale, offCssX, offCssY } = getTransform();
  return { nx: (relX - offCssX) / scale, ny: (relY - offCssY) / scale, cssX: relX, cssY: relY };
}

function handleTap(clientX, clientY) {
  if (!state.sim) return;
  const { nx, ny, cssX, cssY } = screenToNative(clientX, clientY);

  const rx = nx - ORIGIN_X, ry = ny - ORIGIN_Y;
  const txf = (rx / (ISO_TW / 2) + ry / (ISO_TH / 2)) / 2;
  const tyf = (ry / (ISO_TH / 2) - rx / (ISO_TW / 2)) / 2;
  const tx = Math.round(txf), ty = Math.round(tyf);

  // Mid-move: this click chooses the drop tile for a build-mode "move" in progress.
  if (state.buildMode && state.movingItemId) {
    const moving = state.items.find((i) => i.id === state.movingItemId);
    if (!moving) { state.movingItemId = null; return; }
    if (tx === moving.x && ty === moving.y) return;
    if (itemAt(tx, ty) || tx < 0 || ty < 0 || tx >= COLS || ty >= ROWS) {
      toast("To miejsce jest zajęte.");
      return;
    }
    moving.x = tx; moving.y = ty;
    state.movingItemId = null;
    toast("Mebel przeniesiony.");
    return;
  }

  // Tier 1: precise hit-test against each item's / sim's elevated silhouette.
  let hitObj = null, hitDepth = -Infinity;
  const tryHit = (ox, oy, h, hw, hh, obj) => {
    const { x: cx, y: cy } = project(ox, oy);
    if (pointInDiamond(nx, ny, cx, cy - h, hw, hh)) {
      const d = ox + oy;
      if (d > hitDepth) { hitDepth = d; hitObj = obj; }
    }
  };
  for (const item of state.items) tryHit(item.x, item.y, catalogOf(item).h, ISO_TW / 2, ISO_TH / 2, { __item: item });
  if (!state.buildMode && state.partner) {
    tryHit(state.partner.x, state.partner.y, 40, ISO_TW * 0.34, ISO_TH * 0.6, { __partner: true });
  }

  if (hitObj) {
    if (hitObj.__partner) { openSocialPanel(cssX, cssY); return; }
    if (state.buildMode) openManagePanel(hitObj.__item, cssX, cssY);
    else openActionPanel(hitObj.__item, cssX, cssY);
    return;
  }

  // Tier 2: floor-plane fallback.
  const itemHere = itemAt(tx, ty);
  if (itemHere) {
    if (state.buildMode) openManagePanel(itemHere, cssX, cssY);
    else openActionPanel(itemHere, cssX, cssY);
    return;
  }
  if (!state.buildMode && state.partner && Math.round(state.partner.x) === tx && Math.round(state.partner.y) === ty) {
    openSocialPanel(cssX, cssY);
    return;
  }

  closePanels();
  if (state.buildMode) {
    if (isWalkable(tx, ty) && tx >= 0 && ty >= 0 && tx < COLS && ty < ROWS) openItemPicker(tx, ty);
    return;
  }
  if (isWalkable(tx, ty)) {
    const path = findPathToTile(state.sim.x, state.sim.y, tx, ty);
    if (path !== null) {
      state.sim.path = path;
      state.sim.pendingAction = null;
    }
  }
}

/* ---------- Pointer input: tap-to-interact, drag-to-pan, wheel/pinch-to-zoom ---------- */
const activePointers = new Map();
let dragPointerId = null, dragStart = null, dragLast = null, dragged = false;
let pinchStartDist = 0, pinchStartZoom = 1;

canvas.addEventListener("pointerdown", (e) => {
  canvas.setPointerCapture(e.pointerId);
  activePointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if (activePointers.size === 1) {
    dragPointerId = e.pointerId;
    dragStart = { x: e.clientX, y: e.clientY };
    dragLast = { x: e.clientX, y: e.clientY };
    dragged = false;
  } else if (activePointers.size === 2) {
    dragPointerId = null;
    const pts = [...activePointers.values()];
    pinchStartDist = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y);
    pinchStartZoom = state.camera.zoom;
  }
});

canvas.addEventListener("pointermove", (e) => {
  if (!activePointers.has(e.pointerId)) return;
  activePointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

  if (activePointers.size === 2) {
    const pts = [...activePointers.values()];
    const dist = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y);
    const midX = (pts[0].x + pts[1].x) / 2, midY = (pts[0].y + pts[1].y) / 2;
    if (pinchStartDist > 10) {
      setZoomAt(midX, midY, pinchStartZoom * (dist / pinchStartDist));
    }
    return;
  }

  if (e.pointerId === dragPointerId && dragStart) {
    const totalMove = Math.hypot(e.clientX - dragStart.x, e.clientY - dragStart.y);
    if (!dragged && totalMove > 6) dragged = true;
    if (dragged) {
      const { scale } = getTransform();
      state.camera.camX -= (e.clientX - dragLast.x) / scale;
      state.camera.camY -= (e.clientY - dragLast.y) / scale;
      clampCamera();
    }
    dragLast = { x: e.clientX, y: e.clientY };
  }
});

function pointerEnd(e) {
  activePointers.delete(e.pointerId);
  if (e.pointerId === dragPointerId) {
    if (!dragged) handleTap(e.clientX, e.clientY);
    dragPointerId = null; dragStart = null; dragLast = null; dragged = false;
  }
  if (activePointers.size < 2) pinchStartDist = 0;
}
canvas.addEventListener("pointerup", pointerEnd);
canvas.addEventListener("pointercancel", pointerEnd);

canvas.addEventListener("wheel", (e) => {
  e.preventDefault();
  const factor = e.deltaY < 0 ? 1.15 : 1 / 1.15;
  zoomBy(e.clientX, e.clientY, factor);
}, { passive: false });

document.getElementById("zoomInBtn").addEventListener("click", () => zoomBy(window.innerWidth / 2, (topBarH + window.innerHeight - botHudH) / 2, 1.35));
document.getElementById("zoomOutBtn").addEventListener("click", () => zoomBy(window.innerWidth / 2, (topBarH + window.innerHeight - botHudH) / 2, 1 / 1.35));
document.getElementById("zoomResetBtn").addEventListener("click", () => resetCamera());

document.getElementById("speedControls").addEventListener("click", (e) => {
  const btn = e.target.closest("button");
  if (!btn) return;
  state.speed = Number(btn.dataset.speed);
  document.querySelectorAll("#speedControls button").forEach((b) => b.classList.remove("active"));
  btn.classList.add("active");
});

document.getElementById("buildBtn").addEventListener("click", () => {
  state.buildMode = !state.buildMode;
  state.movingItemId = null;
  closePanels();
  toast(state.buildMode ? "🔨 Tryb budowania włączony" : "Tryb budowania wyłączony");
});

document.getElementById("itemPickerClose").addEventListener("click", () => {
  document.getElementById("itemPicker").classList.add("hidden");
});

document.getElementById("saveBtn").addEventListener("click", () => { saveGame(); toast("Gra zapisana."); });
document.getElementById("newGameBtn").addEventListener("click", () => {
  if (confirm("Rozpocząć nową grę? Obecny postęp zostanie utracony.")) {
    try { localStorage.removeItem(SAVE_KEY); } catch (e) {}
    location.reload();
  }
});

/* ---------- Save / Load ---------- */
function serializeSim(sim) {
  return {
    name: sim.name, color: sim.color, trait: sim.trait, x: sim.x, y: sim.y,
    needs: sim.needs, skills: sim.skills, jobLevel: sim.jobLevel, shiftsWorked: sim.shiftsWorked,
    path: sim.path, pendingAction: sim.pendingAction ? { id: sim.pendingAction.id } : null,
    action: sim.action, atWork: sim.atWork,
  };
}
function deserializeSim(data) {
  const sim = createSim(data.name, data.color, data.trait);
  sim.x = data.x; sim.y = data.y;
  sim.needs = data.needs;
  sim.skills = data.skills || { cooking: 0, fitness: 0, charisma: 0 };
  sim.jobLevel = data.jobLevel || 0;
  sim.shiftsWorked = data.shiftsWorked || 0;
  sim.path = data.path || [];
  sim.pendingAction = data.pendingAction ? itemAt2(data.pendingAction.id) : null;
  sim.action = data.action || null;
  sim.atWork = !!data.atWork;
  return sim;
}
function itemAt2(id) { return state.items.find((i) => i.id === id) || null; }

function saveGame() {
  try {
    const data = {
      sim: serializeSim(state.sim),
      partner: state.partner ? serializeSim(state.partner) : null,
      relationship: state.relationship,
      money: state.money, day: state.day, minutes: state.minutes,
      items: state.items, itemCounter: state.itemCounter,
    };
    localStorage.setItem(SAVE_KEY, JSON.stringify(data));
  } catch (e) { /* storage unavailable */ }
}

function loadGame() {
  let raw = null;
  try { raw = localStorage.getItem(SAVE_KEY); } catch (e) { return false; }
  if (!raw) return false;
  try {
    const data = JSON.parse(raw);
    state.items = data.items || STARTER_ITEMS.map((i) => ({ ...i }));
    state.itemCounter = data.itemCounter || 1;
    state.sim = deserializeSim(data.sim);
    state.partner = data.partner ? deserializeSim(data.partner) : null;
    state.relationship = data.relationship || 30;
    state.money = data.money; state.day = data.day; state.minutes = data.minutes;
    return true;
  } catch (e) {
    return false;
  }
}

window.addEventListener("beforeunload", () => { if (state.sim) saveGame(); });
setInterval(() => { if (state.sim) saveGame(); }, 30000);

/* ---------- Character creators ---------- */
let ccSelectedColor = COLORS[0];
let ccSelectedTrait = Object.keys(TRAITS)[0];
let pcSelectedColor = COLORS[1];

function buildSwatches(container, onPick, defaultColor) {
  container.innerHTML = "";
  COLORS.forEach((c, i) => {
    const sw = document.createElement("div");
    sw.className = "swatch" + (c === defaultColor ? " selected" : "");
    sw.style.background = c;
    sw.onclick = () => {
      onPick(c);
      container.querySelectorAll(".swatch").forEach((s) => s.classList.remove("selected"));
      sw.classList.add("selected");
    };
    container.appendChild(sw);
  });
}

function initCharCreator() {
  buildSwatches(document.getElementById("ccColors"), (c) => { ccSelectedColor = c; }, ccSelectedColor);

  const traitsEl = document.getElementById("ccTraits");
  Object.entries(TRAITS).forEach(([key, t], i) => {
    const div = document.createElement("div");
    div.className = "trait" + (i === 0 ? " selected" : "");
    div.innerHTML = `<b>${t.name}</b> — ${t.desc}`;
    div.onclick = () => {
      ccSelectedTrait = key;
      traitsEl.querySelectorAll(".trait").forEach((d) => d.classList.remove("selected"));
      div.classList.add("selected");
    };
    traitsEl.appendChild(div);
  });

  document.getElementById("ccConfirm").addEventListener("click", () => {
    const name = document.getElementById("ccName").value.trim() || "Sim";
    state.sim = createSim(name, ccSelectedColor, ccSelectedTrait);
    document.getElementById("charCreator").classList.add("hidden");
    initPartnerCreator();
    document.getElementById("partnerCreator").classList.remove("hidden");
  });
}

function initPartnerCreator() {
  pcSelectedColor = COLORS.find((c) => c !== ccSelectedColor) || COLORS[1];
  buildSwatches(document.getElementById("pcColors"), (c) => { pcSelectedColor = c; }, pcSelectedColor);

  document.getElementById("pcConfirm").onclick = () => {
    const name = document.getElementById("pcName").value.trim() || "Współlokator";
    state.partner = createSim(name, pcSelectedColor, "towarzyski");
    state.partner.x = 4; state.partner.y = 3;
    document.getElementById("partnerCreator").classList.add("hidden");
    resizeCanvas();
    toast(`Witajcie, ${state.sim.name} i ${name}! Kliknijcie obiekt, aby wykonać czynność.`);
  };
  document.getElementById("pcSkip").onclick = () => {
    document.getElementById("partnerCreator").classList.add("hidden");
    resizeCanvas();
    toast(`Witaj, ${state.sim.name}! Kliknij obiekt, aby wykonać czynność.`);
  };
}

/* ---------- Boot ---------- */
function boot() {
  resizeCanvas();
  initCharCreator();
  if (loadGame()) {
    document.getElementById("charCreator").classList.add("hidden");
    document.getElementById("partnerCreator").classList.add("hidden");
  }
  resizeCanvas();
  requestAnimationFrame(gameLoop);
}

boot();
