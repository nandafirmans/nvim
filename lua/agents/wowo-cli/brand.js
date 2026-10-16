// The WOWO-AGENT look: a wordmark in fire colours and a burning forest drawn
// in braille dots, for the banner.

const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
const fg = (rgb) => `\x1b[38;2;${rgb.join(";")}m`;

export const FIRE = ["#fff3b0", "#ffd23f", "#ff9f1c", "#ff5f1f", "#e8202a", "#9e1b32"];

// Colour at t in [0, 1] along `stops`.
export function mix(stops, t) {
  const cols = stops.map(hex);
  t = Math.max(0, Math.min(1, t));
  const seg = Math.min(cols.length - 2, Math.floor(t * (cols.length - 1)));
  const local = t * (cols.length - 1) - seg;
  return cols[seg].map((v, k) => Math.round(v + (cols[seg + 1][k] - v) * local));
}

// ANSI Shadow letters; the █ faces burn, the outlines stay as embers.
const BIG = {
  W: ["██╗    ██╗", "██║    ██║", "██║ █╗ ██║", "██║███╗██║", "╚███╔███╔╝", " ╚══╝╚══╝ "],
  O: [" ██████╗ ", "██╔═══██╗", "██║   ██║", "██║   ██║", "╚██████╔╝", " ╚═════╝ "],
  "-": ["      ", "      ", "█████╗", "╚════╝", "      ", "      "],
  A: [" █████╗ ", "██╔══██╗", "███████║", "██╔══██║", "██║  ██║", "╚═╝  ╚═╝"],
  G: [" ██████╗ ", "██╔════╝ ", "██║  ███╗", "██║   ██║", "╚██████╔╝", " ╚═════╝ "],
  E: ["███████╗", "██╔════╝", "█████╗  ", "██╔══╝  ", "███████╗", "╚══════╝"],
  N: ["███╗   ██╗", "████╗  ██║", "██╔██╗ ██║", "██║╚██╗██║", "██║ ╚████║", "╚═╝  ╚═══╝"],
  T: ["████████╗", "╚══██╔══╝", "   ██║   ", "   ██║   ", "   ██║   ", "   ╚═╝   "],
};

const SMALL = [
  "█ █ █ █▀█ █ █ █ █▀█     ▄▀█ █▀▀ █▀▀ █▄ █ ▀█▀",
  "▀▄▀▄▀ █▄█ ▀▄▀▄▀ █▄█ ▀▀▀ █▀█ █▄█ ██▄ █ ▀█  █ ",
];

const NAME = "WOWO-AGENT";
export const BIG_WIDTH = [...NAME].reduce((n, ch) => n + [...BIG[ch][0]].length, 0);

// The wordmark for a terminal `cols` wide: big letters when they fit.
export function wordmark(cols) {
  const rows = cols >= BIG_WIDTH + 2 ? [0, 1, 2, 3, 4, 5].map((r) => [...NAME].map((ch) => BIG[ch][r]).join("")) : SMALL;
  const ember = fg(hex("#7a2e1f"));
  return rows.map((row, r) => {
    const chars = [...row];
    return (
      chars
        .map((ch, i) => {
          if (ch === " ") return ch;
          if (ch !== "█" && ch !== "▀" && ch !== "▄") return ember + ch;
          // Hot at the top, deeper red to the bottom and towards the right.
          const t = r / Math.max(1, rows.length - 1) * 0.7 + (i / chars.length) * 0.3;
          return fg(mix(FIRE.slice(0, 5), t)) + ch;
        })
        .join("") + "\x1b[39m"
    );
  });
}

// A small seeded random, so the forest looks the same every time.
function random(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

// A burning pine forest as pixel art, `cols` characters wide and `rows` high:
// each character holds two pixels (▀ with a foreground and a background
// colour). A wall of fire, white-hot at the roots and red at the tips, with
// dark pines standing in front of it, sparks and smoke above, embers below.
export function forest(cols = 26, rows = 13, seed = 7) {
  const W = cols;
  const H = rows * 2;
  const rnd = random(seed);
  const ground = H - 2;
  const px = Array.from({ length: H }, () => Array(W).fill(null));

  // The fire: a height per column from a few tongues, hottest near the ground.
  const tongues = [];
  for (let x = rnd() * 3; x < W + 2; x += 2.5 + rnd() * 3) tongues.push({ x, h: H * (0.25 + rnd() * 0.5), w: 1 + rnd() * 1.6 });
  const BANDS = [[0.8, "#fff3b0"], [0.62, "#ffd23f"], [0.44, "#ff9f1c"], [0.26, "#ff5f1f"], [-Infinity, "#c92a2a"]];
  for (let x = 0; x < W; x++) {
    let height = H * 0.18;
    for (const t of tongues) height = Math.max(height, t.h * Math.exp(-(((x + 0.5 - t.x) / t.w) ** 2)));
    for (let y = ground - 1; y >= 0 && ground - y <= height; y--) {
      const heat = 1 - (ground - y) / height + (rnd() - 0.5) * 0.12;
      px[y][x] = BANDS.find(([min]) => heat >= min)[1];
    }
  }

  // Pines in front, as dark silhouettes: tiers of branches on a trunk.
  for (let x = 2.5 + rnd() * 2; x < W - 2; x += 7 + rnd() * 3) {
    const h = H * (0.5 + rnd() * 0.3);
    const w = 2.8 + rnd() * 1;
    const top = ground - h;
    for (let y = Math.max(0, Math.floor(top)); y < ground; y++) {
      for (let col = 0; col < W; col++) {
        const k = (y + 0.5 - top) / (h * 0.82);
        const dx = Math.abs(col + 0.5 - x);
        const trunk = dx < 0.6;
        const tier = (k * 3) % 1;
        const crown = k <= 1 && dx <= w * (0.25 + 0.75 * k) * (0.35 + 0.65 * tier);
        if (trunk || crown) px[y][col] = "#1c0f10";
      }
    }
  }

  // Sparks and smoke above, embers on the ground.
  for (let i = 0; i < W / 3; i++) {
    const x = Math.floor(rnd() * W);
    const y = Math.floor(rnd() * H * 0.45);
    if (!px[y][x]) px[y][x] = rnd() < 0.5 ? "#ffd23f" : "#ff9f1c";
  }
  for (let i = 0; i < W / 2; i++) {
    const x = Math.floor(rnd() * W);
    const y = Math.floor(rnd() * H * 0.18);
    if (!px[y][x]) px[y][x] = rnd() < 0.5 ? "#5f6b7a" : "#4b5563";
  }
  for (let y = ground; y < H; y++) {
    for (let x = 0; x < W; x++) px[y][x] = rnd() < 0.25 ? (y === ground ? "#ff5f1f" : "#b8361f") : y === ground ? "#5c2418" : "#3a1a14";
  }

  const bg = (rgb) => `\x1b[48;2;${rgb.join(";")}m`;
  const lines = [];
  for (let row = 0; row < rows; row++) {
    let line = "";
    for (let x = 0; x < W; x++) {
      const top = px[row * 2][x];
      const bottom = px[row * 2 + 1][x];
      if (top && bottom) line += fg(hex(top)) + bg(hex(bottom)) + "▀\x1b[49m";
      else if (top) line += fg(hex(top)) + "▀";
      else if (bottom) line += fg(hex(bottom)) + "▄";
      else line += " ";
    }
    lines.push(line + "\x1b[39m");
  }
  return lines;
}
