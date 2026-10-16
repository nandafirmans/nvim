// Settings: ~/.wowo/config.json, written by the Neovim hub from
// wowo.providers (lua/agents/wowo.lua), or by hand.
//
// { "model": "omniroute/hermes-main",
//   "instructions": "…",
//   "providers": { "omniroute": { "base_url": "http://127.0.0.1:20128/v1",
//                                 "api": "openai" | "anthropic",
//                                 "api_key": "ENV_NAME" | "!command",
//                                 "headers": {}, "context": 200000,
//                                 "models": ["id", { "id": "…", "context": 400000, "max_tokens": 32000 }] } } }
//
// api_key is never a key: it names an environment variable or a command that
// prints the key, resolved only when a request is made.
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

export const HOME = process.env.WOWO_HOME || path.join(os.homedir(), ".wowo");
export const AGENT_DIR = path.join(HOME, "agent");

export function loadConfig() {
  const file = path.join(HOME, "config.json");
  let data = {};
  try {
    data = JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (err) {
    if (err.code !== "ENOENT") throw new Error(`${file}: ${err.message}`);
  }
  data.providers ??= {};
  data.permissions ??= "ask";
  return data;
}

// Every configured model as { ref: "provider/id", provider, id, context, maxTokens }.
export function listModels(config) {
  const out = [];
  for (const [name, p] of Object.entries(config.providers)) {
    for (const m of p.models ?? []) {
      const spec = typeof m === "string" ? { id: m } : m;
      out.push({
        ref: `${name}/${spec.id}`,
        provider: name,
        id: spec.id,
        context: spec.context ?? p.context ?? 200000,
        maxTokens: spec.max_tokens ?? p.max_tokens ?? 32000,
      });
    }
  }
  return out;
}

// "provider/id", a bare id, or a unique fragment of one.
export function findModel(config, wanted) {
  const models = listModels(config);
  if (!wanted) return models.find((m) => m.ref === config.model) ?? models[0];
  return (
    models.find((m) => m.ref === wanted) ??
    models.find((m) => m.id === wanted) ??
    (() => {
      const hits = models.filter((m) => m.ref.includes(wanted));
      return hits.length === 1 ? hits[0] : undefined;
    })()
  );
}

const keyCache = new Map();

export function resolveKey(spec) {
  if (!spec) return undefined;
  if (keyCache.has(spec)) return keyCache.get(spec);
  let key;
  if (spec.startsWith("!")) {
    try {
      key = execFileSync("/bin/sh", ["-c", spec.slice(1)], { encoding: "utf8", timeout: 10000 }).trim();
    } catch {
      key = undefined;
    }
  } else {
    key = process.env[spec];
  }
  if (key) keyCache.set(spec, key);
  return key || undefined;
}
