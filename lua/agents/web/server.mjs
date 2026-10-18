// agents web: the phone dashboard for the Neovim agent hub. Serves the
// dashboard and a small JSON API over the hub's tmux sessions, checks the PIN
// and keeps a login cookie, and proxies the terminal (ttyd, started here on
// loopback) under /t/. Node, no dependencies. Run by `agents web` as a
// LaunchAgent; Tailscale serve publishes it to your own devices only.
import { execFile, spawn } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import http from "node:http";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const env = process.env;
const PORT = Number(env.AGENTS_WEB_PORT || 7681);
const TTYD_PORT = Number(env.AGENTS_TTYD_PORT || 7682);
const STATE = env.AGENTS_STATE || path.join(env.HOME, ".local/state/agents");
const SOCKET = env.AGENTS_SOCKET || "nvim-agents";
const AGENTS_BIN = env.AGENTS_BIN;
const TTYD = env.AGENTS_TTYD || "ttyd";
const PIN_FILE = path.join(STATE, "pin");
const DASHBOARD = path.join(HERE, "dashboard.html");
const TERMINAL_PAGE = path.join(STATE, "web", "index.html");
const SESSION_DAYS = 30;

const log = (...a) => console.log(new Date().toISOString(), ...a);

// ttyd -------------------------------------------------------------------------------
// One ttyd on loopback; ?arg=<tab> opens that tab (`agents --web <tab>`).

function startTtyd() {
  const args = [
    "-W", "-i", "lo0", "-p", String(TTYD_PORT), "-b", "/t", "-a",
    "-t", "disableLeaveAlert=true", "-t", "disableResizeOverlay=true", "-t", "titleFixed=agents",
    "-t", 'theme={"background":"#1b1416","foreground":"#e6e9f0","cursor":"#ffd23f","selectionBackground":"#5c2418"}',
  ];
  if (fs.existsSync(TERMINAL_PAGE)) args.push("-I", TERMINAL_PAGE);
  args.push(AGENTS_BIN, "--web");
  const child = spawn(TTYD, args, { stdio: ["ignore", "ignore", "inherit"] });
  child.on("exit", (code) => {
    log("ttyd exited", code, "- restarting");
    setTimeout(startTtyd, 2000);
  });
}

// Auth ---------------------------------------------------------------------------------

const sessions = new Map(); // token -> expiry (ms)
let failures = 0;
let lockedUntil = 0;

function cookies(req) {
  const out = {};
  for (const part of (req.headers.cookie || "").split(";")) {
    const i = part.indexOf("=");
    if (i > 0) out[part.slice(0, i).trim()] = part.slice(i + 1).trim();
  }
  return out;
}

function authed(req) {
  const token = cookies(req).agents_session;
  const expiry = token && sessions.get(token);
  if (!expiry) return false;
  if (expiry < Date.now()) {
    sessions.delete(token);
    return false;
  }
  return true;
}

// Same salted hash `agents pin` writes: sha256("<salt>:<pin>").
function pinMatches(pin) {
  let stored;
  try {
    stored = fs.readFileSync(PIN_FILE, "utf8").trim();
  } catch {
    return null; // no PIN set
  }
  const [salt, want] = stored.split(":");
  const got = crypto.createHash("sha256").update(`${salt}:${pin}`).digest("hex");
  return want && got.length === want.length && crypto.timingSafeEqual(Buffer.from(got), Buffer.from(want));
}

// tmux ---------------------------------------------------------------------------------

function tmux(args, input) {
  return new Promise((resolve) => {
    const child = execFile("tmux", ["-L", SOCKET, ...args], { timeout: 5000 }, (err, stdout) => resolve(err ? null : stdout));
    if (input !== undefined) child.stdin.end(input);
  });
}

function git(cwd, args) {
  return new Promise((resolve) => {
    execFile("git", ["-C", cwd, ...args], { timeout: 5000 }, (err, stdout) => resolve(err ? null : stdout));
  });
}

const FIELDS = ["name", "project", "tool", "index", "cwd", "branch", "hook", "activity", "dead", "label", "doing", "task", "created"];
const FORMAT = [
  "#{session_name}", "#{@agent_project}", "#{@agent_tool}", "#{@agent_index}", "#{@agent_cwd}", "#{@agent_branch}",
  "#{@agent_status}", "#{window_activity}", "#{pane_dead}", "#{@agent_label}", "#{@agent_activity}", "#{@agent_task}",
  "#{session_created}",
].join("\t");
const STATUSES = new Set(["running", "waiting", "done", "idle", "limited"]);

const changeCache = new Map(); // cwd -> { at, value }

async function changes(cwd) {
  const cached = changeCache.get(cwd);
  if (cached && Date.now() - cached.at < 8000) return cached.value;
  let value = null;
  const status = cwd ? await git(cwd, ["status", "--porcelain"]) : null;
  if (status !== null) {
    const files = status.split("\n").filter(Boolean).length;
    const stat = (await git(cwd, ["diff", "--shortstat", "HEAD"])) || "";
    value = {
      files,
      add: Number(stat.match(/(\d+) insertion/)?.[1] || 0),
      del: Number(stat.match(/(\d+) deletion/)?.[1] || 0),
    };
  }
  changeCache.set(cwd, { at: Date.now(), value });
  return value;
}

async function listAgents() {
  const out = await tmux(["list-sessions", "-F", FORMAT]);
  if (!out) return [];
  const now = Math.floor(Date.now() / 1000);
  const agents = out
    .split("\n")
    .filter(Boolean)
    .map((line) => Object.fromEntries(line.split("\t").map((v, i) => [FIELDS[i], v])))
    .filter((a) => a.tool);
  for (const a of agents) {
    a.index = Number(a.index) || 1;
    a.activity = Number(a.activity) || 0;
    a.status = a.dead === "1" ? "exited" : STATUSES.has(a.hook) ? a.hook : now - a.activity <= 3 ? "running" : "idle";
    a.changes = await changes(a.cwd);
    delete a.hook;
    delete a.dead;
  }
  agents.sort((x, y) => x.project.localeCompare(y.project) || x.index - y.index);
  return agents;
}

async function exists(name) {
  return (await listAgents()).some((a) => a.name === name);
}

// HTTP ---------------------------------------------------------------------------------

function json(res, code, body, headers = {}) {
  res.writeHead(code, { "content-type": "application/json", "cache-control": "no-store", ...headers });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve) => {
    let data = "";
    req.on("data", (c) => {
      data += c;
      if (data.length > 200_000) req.destroy();
    });
    req.on("end", () => {
      try {
        resolve(JSON.parse(data || "{}"));
      } catch {
        resolve({});
      }
    });
  });
}

function proxy(req, res) {
  const upstream = http.request(
    { host: "127.0.0.1", port: TTYD_PORT, path: req.url, method: req.method, headers: req.headers },
    (up) => {
      res.writeHead(up.statusCode, up.headers);
      up.pipe(res);
    },
  );
  upstream.on("error", () => {
    res.writeHead(502);
    res.end("terminal not ready, try again");
  });
  req.pipe(upstream);
}

const KEYS = { approve: "Enter", deny: "Escape" };

async function api(req, res, url) {
  if (url.pathname === "/api/login" && req.method === "POST") {
    if (Date.now() < lockedUntil) return json(res, 429, { error: `Too many tries. Wait ${Math.ceil((lockedUntil - Date.now()) / 1000)}s.` });
    const { pin } = await readBody(req);
    const ok = pinMatches(String(pin || ""));
    if (ok === null) return json(res, 403, { error: "No PIN set. On the Mac, run: agents pin" });
    if (!ok) {
      failures += 1;
      await new Promise((r) => setTimeout(r, 1500));
      if (failures % 3 === 0) {
        lockedUntil = Date.now() + 60_000 * 2 ** (failures / 3 - 1);
        fs.appendFileSync(path.join(STATE, "pin.log"), `${new Date().toISOString()} ${failures} wrong PINs from the dashboard\n`);
      }
      return json(res, 401, { error: "Wrong PIN." });
    }
    failures = 0;
    const token = crypto.randomBytes(32).toString("hex");
    sessions.set(token, Date.now() + SESSION_DAYS * 86400_000);
    return json(res, 200, { ok: true }, {
      "set-cookie": `agents_session=${token}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${SESSION_DAYS * 86400}`,
    });
  }
  if (!authed(req)) return json(res, 401, { error: "login" });
  if (url.pathname === "/api/logout" && req.method === "POST") {
    sessions.delete(cookies(req).agents_session);
    return json(res, 200, { ok: true }, { "set-cookie": "agents_session=; Path=/; Max-Age=0" });
  }
  if (url.pathname === "/api/agents") return json(res, 200, { agents: await listAgents(), now: Math.floor(Date.now() / 1000) });
  const m = url.pathname.match(/^\/api\/agents\/([\w.-]+)\/(send|approve|deny)$/);
  if (m && req.method === "POST") {
    const [, name, action] = m;
    if (!(await exists(name))) return json(res, 404, { error: "no such tab" });
    if (action === "send") {
      const { text } = await readBody(req);
      if (!text || !String(text).trim()) return json(res, 400, { error: "empty" });
      const buffer = `agents-web-${crypto.randomBytes(4).toString("hex")}`;
      await tmux(["load-buffer", "-b", buffer, "-"], String(text));
      await tmux(["paste-buffer", "-p", "-d", "-b", buffer, "-t", `=${name}:`]);
      await new Promise((r) => setTimeout(r, 150));
      await tmux(["send-keys", "-t", `=${name}:`, "Enter"]);
    } else {
      await tmux(["send-keys", "-t", `=${name}:`, KEYS[action]]);
    }
    return json(res, 200, { ok: true });
  }
  return json(res, 404, { error: "not found" });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://localhost");
  try {
    if (url.pathname.startsWith("/api/")) return await api(req, res, url);
    if (url.pathname === "/t" || url.pathname.startsWith("/t/")) {
      if (!authed(req)) {
        res.writeHead(302, { location: "/" });
        return res.end();
      }
      return proxy(req, res);
    }
    if (url.pathname === "/" || url.pathname === "/index.html") {
      let icon = "";
      try {
        icon = fs.readFileSync(path.join(STATE, "web", "icon.b64"), "utf8").trim();
      } catch {}
      res.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
      return res.end(fs.readFileSync(DASHBOARD, "utf8").replaceAll("ICON", icon));
    }
    res.writeHead(404);
    res.end();
  } catch (err) {
    log("error", err);
    if (!res.headersSent) json(res, 500, { error: "server error" });
  }
});

// The terminal's websocket goes straight through to ttyd, logged-in only.
server.on("upgrade", (req, socket, head) => {
  if (!req.url.startsWith("/t/") || !authed(req)) {
    socket.end("HTTP/1.1 401 Unauthorized\r\n\r\n");
    return;
  }
  const upstream = net.connect(TTYD_PORT, "127.0.0.1", () => {
    const headers = Object.entries(req.headers).map(([k, v]) => `${k}: ${v}`).join("\r\n");
    upstream.write(`${req.method} ${req.url} HTTP/1.1\r\n${headers}\r\n\r\n`);
    if (head?.length) upstream.write(head);
    socket.pipe(upstream).pipe(socket);
  });
  upstream.on("error", () => socket.destroy());
  socket.on("error", () => upstream.destroy());
});

startTtyd();
server.listen(PORT, "127.0.0.1", () => log(`agents web on http://127.0.0.1:${PORT}`));
