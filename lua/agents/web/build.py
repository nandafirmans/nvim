"""Builds the phone page for `agents web` from ttyd's own index.html.

Adds what makes it work as a home-screen app on a phone: a name, an icon,
full-screen meta tags, and a row of keys a phone keyboard lacks (Esc, Tab,
Ctrl, arrows, detach). The icon is inlined as a data URI: ttyd serves only
its page, and the Mac App Store Tailscale cannot serve files.

    python3 build.py <ttyd index.html> <out dir>

Writes <out dir>/index.html (the terminal page) and icon.b64 (the icon for
the dashboard).
"""
import base64
import struct
import sys
import zlib
from pathlib import Path

HEAD = """
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
<meta name="apple-mobile-web-app-title" content="agents">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="mobile-web-app-capable" content="yes">
<meta name="theme-color" content="#1b1416">
<style>html, body { margin: 0; height: 100%; overflow: hidden; }</style>
<link rel="apple-touch-icon" href="ICON">
<link rel="icon" type="image/png" href="ICON">
<style>
  /* The fire colours, until the Neovim theme arrives (applyTheme below). */
  :root {
    --k-page: #1b1416; --k-bar1: #2a1d1f; --k-bar2: #1f1618; --k-line: #3d2a2c;
    --k-btn1: #3e2b2d; --k-btn2: #33242a; --k-shadow: #1a1012; --k-hi: #4c3638; --k-fg: #ffe6a8;
    --k-accent1: #ffb547; --k-accent2: #ff8a1c; --k-on-accent: #1b1416;
  }
  html, body { background: var(--k-page); overscroll-behavior: none; }
  #terminal-container { box-sizing: border-box; }
  /* The cells rarely fill the width exactly: centre them, so the spare pixels
     split into two thin edges instead of one strip on the right. */
  #terminal-container .xterm-screen { margin: 0 auto; }
  #agents-safe {
    position: fixed; visibility: hidden; pointer-events: none;
    padding: env(safe-area-inset-top) 0 env(safe-area-inset-bottom) 0;
  }
  #agents-keys {
    position: fixed; left: 0; right: 0; z-index: 10; box-sizing: border-box;
    width: 100vw; padding: 6px 6px; display: flex; flex-direction: column; gap: 6px;
    background: linear-gradient(var(--k-bar1), var(--k-bar2)); border-top: 1px solid var(--k-line);
    -webkit-user-select: none; user-select: none; touch-action: manipulation;
  }
  #agents-keys .row { display: flex; gap: 5px; width: 100%; }
  #agents-keys .row.more { display: none; }
  #agents-keys.open .row.more { display: flex; }
  #agents-keys button {
    flex: 1 1 0; min-width: 0; height: 38px; padding: 0;
    border: 0; border-radius: 9px; color: var(--k-fg);
    background: linear-gradient(var(--k-btn1), var(--k-btn2)); box-shadow: 0 1px 0 var(--k-shadow), inset 0 1px 0 var(--k-hi);
    font: 600 14px -apple-system, system-ui, sans-serif; letter-spacing: .2px;
  }
  #agents-keys button.wide { flex-grow: 1.4; }
  #agents-keys button.accent, #agents-keys button.on {
    color: var(--k-on-accent); background: linear-gradient(var(--k-accent1), var(--k-accent2)); box-shadow: 0 1px 0 var(--k-shadow);
  }
  #agents-keys button:active { transform: translateY(1px); filter: brightness(1.25); }
  #agents-keys button small { font-size: 11px; opacity: .75; font-weight: 500; }
</style>
"""

BODY = r"""
<div id="agents-safe"></div>
<div id="agents-keys">
  <div class="row more">
    <button data-k="stab">⇧⇥</button>
    <button data-k="cc">^C</button>
    <button data-k="paste">Paste</button>
    <button data-k="smaller">A<small>−</small></button>
    <button data-k="bigger">A<small>+</small></button>
    <button data-k="detach" class="wide">☰ Menu</button>
  </div>
  <div class="row">
    <button data-k="esc">esc</button>
    <button data-k="tab">⇥</button>
    <button data-k="ctrl">ctrl</button>
    <button data-k="left">←</button>
    <button data-k="down">↓</button>
    <button data-k="up">↑</button>
    <button data-k="right">→</button>
    <button data-k="enter" class="accent">⏎</button>
    <button data-k="keyboard">⌨</button>
    <button data-k="more">⋯</button>
  </div>
</div>
<script>
(() => {
  const SEQ = { esc: "\x1b", tab: "\t", up: "\x1b[A", down: "\x1b[B", right: "\x1b[C", left: "\x1b[D",
    enter: "\r", stab: "\x1b[Z", cc: "\x03", detach: "\x02d" };
  const bar = document.getElementById("agents-keys");
  const ctrlKey = bar.querySelector('[data-k="ctrl"]');
  const moreKey = bar.querySelector('[data-k="more"]');
  let ctrl = false;
  const setCtrl = (on) => { ctrl = on; ctrlKey.classList.toggle("on", on); };
  const term = () => window.term;
  const send = (s) => term() && term().input(s, true);
  // Ctrl+letter as the control character; Ctrl+Space as NUL.
  const ctrlOf = (ch) => ch === " " ? "\x00" : String.fromCharCode(ch.toUpperCase().charCodeAt(0) & 0x1f);

  // Font size: smaller on a phone, A− / A+ to change it, remembered here.
  const store = (k, v) => { try { v === undefined ? (v = localStorage.getItem(k)) : localStorage.setItem(k, v); } catch (e) {} return v; };
  const defaultSize = () => (Math.min(window.innerWidth, window.innerHeight) < 500 ? 12 : 15);
  let fontSize = Number(store("agents.fontSize")) || defaultSize();
  const setFont = (n) => {
    fontSize = Math.max(8, Math.min(22, n));
    store("agents.fontSize", String(fontSize));
    if (term()) { term().options.fontSize = fontSize; layout(); }
  };

  bar.addEventListener("pointerdown", (e) => e.preventDefault());
  bar.addEventListener("click", (e) => {
    const button = e.target.closest("button");
    const k = button && button.dataset.k;
    if (!k) return;
    if (k === "ctrl") return setCtrl(!ctrl);
    if (k === "more") {
      bar.classList.toggle("open");
      moreKey.classList.toggle("on", bar.classList.contains("open"));
      return layout();
    }
    if (k === "keyboard") {
      const t = term() && term().textarea;
      if (t) document.activeElement === t ? t.blur() : term().focus();
      return;
    }
    if (k === "smaller") return setFont(fontSize - 1);
    if (k === "bigger") return setFont(fontSize + 1);
    if (k === "paste") {
      navigator.clipboard && navigator.clipboard.readText().then((t) => t && term() && term().paste(t)).catch(() => {});
      return;
    }
    if (k === "detach" && window.parent !== window) {
      window.parent.postMessage("agents:close", "*");
      return;
    }
    send(SEQ[k]);
    setCtrl(false);
  });

  // Lay out for the screen: the terminal below the status bar (the page
  // runs full screen from the home screen) and the keys right above the
  // on-screen keyboard, or above the home indicator when it is closed.
  const container = document.getElementById("terminal-container");
  const safe = document.getElementById("agents-safe");
  // A computer has a real keyboard: no key row.
  if (!window.matchMedia("(pointer: coarse)").matches) bar.style.display = "none";
  const layout = () => {
    const vv = window.visualViewport;
    const h = vv ? vv.height : window.innerHeight;
    const top = vv ? vv.offsetTop : 0;
    // Inside the dashboard the frame already sits below its header and above
    // the home indicator; only a page opened on its own needs the safe areas.
    const st = getComputedStyle(safe);
    const framed = window.parent !== window;
    const safeTop = framed ? 0 : parseFloat(st.paddingTop) || 0;
    const keyboard = window.innerHeight - h > 120;
    const safeBottom = framed || keyboard ? 0 : Math.max(0, (parseFloat(st.paddingBottom) || 0) - 14);
    bar.style.paddingBottom = 6 + safeBottom + "px";
    const barHeight = bar.style.display === "none" ? 0 : bar.offsetHeight;
    bar.style.top = top + h - barHeight + "px";
    if (container) {
      container.style.position = "fixed";
      container.style.left = "0";
      container.style.right = "0";
      container.style.top = top + safeTop + "px";
      container.style.height = h - safeTop - barHeight + "px";
    }
    term() && term().fit && term().fit();
  };
  (window.visualViewport || window).addEventListener("resize", layout);
  (window.visualViewport || window).addEventListener("scroll", layout);
  window.addEventListener("orientationchange", () => setTimeout(layout, 300));
  // Touch: a swipe scrolls whatever is under the finger (the tab list, the
  // changes panel, the agent) and a tap clicks there, sent as mouse events
  // to Neovim and tmux. The keyboard stays down until ⌨ is pressed.
  const cellAt = (t) => {
    const screen = term().element.querySelector(".xterm-screen");
    const r = screen.getBoundingClientRect();
    const col = Math.floor((t.clientX - r.left) / (r.width / term().cols)) + 1;
    const row = Math.floor((t.clientY - r.top) / (r.height / term().rows)) + 1;
    return [Math.max(1, Math.min(term().cols, col)), Math.max(1, Math.min(term().rows, row))];
  };
  const mouseOn = () => term().modes && term().modes.mouseTrackingMode !== "none";
  const mouse = (button, t, release) => {
    const [x, y] = cellAt(t);
    send("\x1b[<" + button + ";" + x + ";" + y + (release ? "m" : "M"));
  };
  let touch = null;
  if (container) {
    container.addEventListener("touchstart", (e) => {
      if (!term()) return;
      if (e.touches.length === 2) {
        // Two fingers: pinch to zoom the text, like Termius.
        const [a, b] = e.touches;
        touch = { pinch: Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY), size: fontSize };
        e.stopPropagation();
        return;
      }
      if (e.touches.length !== 1) return;
      const t = e.touches[0];
      touch = { x: t.clientX, y: t.clientY, last: t.clientY, at: Date.now(), moved: false };
      e.stopPropagation();
    }, { capture: true, passive: true });
    container.addEventListener("touchmove", (e) => {
      if (!touch || !term()) return;
      if (touch.pinch) {
        if (e.touches.length === 2) {
          const [a, b] = e.touches;
          const size = Math.round(touch.size * Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY) / touch.pinch);
          if (size !== fontSize) setFont(size);
        }
        e.preventDefault();
        e.stopPropagation();
        return;
      }
      const t = e.touches[0];
      if (Math.abs(t.clientY - touch.y) > 8 || Math.abs(t.clientX - touch.x) > 8) touch.moved = true;
      const step = Math.max(8, fontSize * 1.4);
      while (Math.abs(t.clientY - touch.last) >= step) {
        const down = t.clientY > touch.last; // finger down: show what is above
        touch.last += down ? step : -step;
        if (mouseOn()) mouse(down ? 64 : 65, t);
        else term().scrollLines(down ? -1 : 1);
      }
      e.preventDefault();
      e.stopPropagation();
    }, { capture: true, passive: false });
    container.addEventListener("touchend", (e) => {
      if (!touch || !term()) return;
      const t = e.changedTouches[0];
      if (touch.pinch) {
        if (e.touches.length === 0) touch = null;
        e.preventDefault();
        return;
      }
      if (!touch.moved && Date.now() - touch.at < 400 && mouseOn()) {
        mouse(0, t);
        mouse(0, t, true);
      }
      touch = null;
      e.preventDefault();
      e.stopPropagation();
    }, { capture: true, passive: false });
  }

  // A Nerd Font, so the hub's icons (branch, file, status) draw instead of
  // boxes; phones have none installed. Fetched once from jsDelivr, then cached.
  const FONT = "https://cdn.jsdelivr.net/gh/ryanoasis/nerd-fonts@v3.2.1/patched-fonts/JetBrainsMono/Ligatures/Regular/JetBrainsMonoNerdFont-Regular.ttf";
  const useFont = () => {
    if (!window.FontFace) return;
    const face = new FontFace("JetBrainsMono Nerd Font", "url(" + FONT + ")");
    face.load().then((loaded) => {
      document.fonts.add(loaded);
      if (!term()) return;
      term().options.fontFamily = '"JetBrainsMono Nerd Font", Menlo, monospace';
      layout();
    }).catch(() => {});
  };

  // The Neovim colorscheme (lua/agents/theme.lua): the terminal's colours and
  // the key bar's. The dashboard sends a new one when it changes; on its own,
  // the page asks again when it comes back to the front.
  let xtermTheme = null;
  const mix = (a, b, t) => "#" + [1, 3, 5].map((i) => {
    const x = parseInt(a.substr(i, 2), 16), y = parseInt(b.substr(i, 2), 16);
    return Math.round(x + (y - x) * t).toString(16).padStart(2, "0");
  }).join("");
  const light = (c) => (parseInt(c.substr(1, 2), 16) * 299 + parseInt(c.substr(3, 2), 16) * 587 + parseInt(c.substr(5, 2), 16) * 114) / 255000 > 0.6;
  const applyTheme = (data) => {
    const p = data && data.theme;
    if (!p || !p.bg) return;
    const css = document.documentElement.style;
    const set = (k, v) => css.setProperty("--k-" + k, v);
    set("page", p.bg); set("bar1", mix(p.bg, p.fg, 0.09)); set("bar2", mix(p.bg, p.fg, 0.05));
    set("line", mix(p.bg, p.fg, 0.16)); set("btn1", mix(p.bg, p.fg, 0.2)); set("btn2", mix(p.bg, p.fg, 0.14));
    set("shadow", mix(p.bg, "#000000", 0.4)); set("hi", mix(p.bg, p.fg, 0.26)); set("fg", p.fg);
    set("accent1", mix(p.accent, "#ffffff", 0.15)); set("accent2", p.accent);
    set("on-accent", light(p.accent) ? mix(p.bg, "#000000", 0.3) : "#ffffff");
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.content = p.bg;
    xtermTheme = data.xterm;
    if (term() && xtermTheme) term().options.theme = xtermTheme;
  };
  const loadTheme = () => fetch("/api/theme").then((r) => r.ok && r.json()).then(applyTheme).catch(() => {});
  loadTheme();
  document.addEventListener("visibilitychange", () => document.visibilityState === "visible" && loadTheme());
  window.addEventListener("message", (e) => {
    if (e.origin === location.origin && e.data && e.data.type === "agents:theme") applyTheme(e.data);
  });

  // Once the terminal exists: font, layout, and a sticky Ctrl that turns
  // the next typed key into its control character.
  const wait = setInterval(() => {
    if (!term() || !term().textarea) return;
    clearInterval(wait);
    term().options.fontSize = fontSize;
    term().options.lineHeight = 1.1;
    if (xtermTheme) term().options.theme = xtermTheme;
    layout();
    useFont();
    term().attachCustomKeyEventHandler((e) => {
      if (ctrl && e.type === "keydown" && e.key.length === 1) {
        send(ctrlOf(e.key));
        setCtrl(false);
        return false;
      }
      return true;
    });
    term().textarea.addEventListener("beforeinput", (e) => {
      if (ctrl && e.data && e.data.length === 1) {
        e.preventDefault();
        send(ctrlOf(e.data));
        setCtrl(false);
      }
    }, true);
  }, 100);
})();
</script>
"""


def png(width, height, pixel):
    rows = b"".join(b"\x00" + b"".join(bytes(pixel(x, y)) for x in range(width)) for y in range(height))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


# The icon: a pine in front of a flame, pixel art on 18x18, scaled up.
ART = [
    "..................",
    "........y.........",
    ".......yy.........",
    "......yyo.....y...",
    "......yoo....yy...",
    ".....yoor...yoo...",
    "....yyoorr..yor...",
    "....yookrr.yoorr..",
    "...yyokkkrryoorr..",
    "...yookkkkroorrr..",
    "..yyokkkkkkoorrr..",
    "..yookkkkkkkorrr..",
    "..yoookkkkkoorrr..",
    "..wyookkkkkkyorr..",
    "..wwyookkkkkkyor..",
    "..gwwyyookyyyyoo..",
    "..gggggggkgggggg..",
    "..................",
]
COLORS = {".": (27, 20, 22), "y": (255, 210, 63), "o": (255, 159, 28), "r": (232, 32, 42),
          "w": (255, 243, 176), "k": (28, 15, 16), "g": (92, 36, 24)}


def icon(size=180):
    scale = size / len(ART)
    return png(size, size, lambda x, y: COLORS[ART[int(y / scale)][int(x / scale)]])


def main():
    source, out = Path(sys.argv[1]), Path(sys.argv[2])
    html = source.read_text(encoding="utf-8")
    html = html.replace("<title>ttyd - Terminal</title>", "<title>agents</title>")
    head = HEAD.replace("ICON", "data:image/png;base64," + base64.b64encode(icon()).decode())
    html = html.replace("</head>", head + "</head>", 1).replace("</body>", BODY + "</body>", 1)
    out.mkdir(parents=True, exist_ok=True)
    (out / "index.html").write_text(html, encoding="utf-8")
    (out / "icon.b64").write_text(base64.b64encode(icon()).decode())


if __name__ == "__main__":
    main()
