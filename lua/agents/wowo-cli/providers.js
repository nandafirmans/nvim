// Model APIs: OpenAI-compatible chat completions (OmniRoute, 9router,
// LiteLLM, OpenRouter, local servers) and Anthropic messages, both streamed
// with tool calls.
//
// Conversation format, shared by every provider and the session files:
//   { role: "user", content: "text" | [{ type: "text", text }] }
//   { role: "assistant", content: [{ type: "text", text } | { type: "thinking", text }
//                                  | { type: "toolCall", id, name, arguments }], usage, model }
//   { role: "toolResult", toolCallId, toolName, content: [{ type: "text", text }], isError }
import { resolveKey } from "./config.js";

export class ApiError extends Error {
  constructor(message, status, retryable) {
    super(message);
    this.status = status;
    this.retryable = retryable;
  }
}

function textOf(content) {
  if (typeof content === "string") return content;
  return (content ?? [])
    .filter((p) => p.type === "text")
    .map((p) => p.text)
    .join("\n");
}

// Server-sent events from a fetch response, one parsed JSON object per event.
async function* events(response, signal) {
  const decoder = new TextDecoder();
  let buffer = "";
  for await (const chunk of response.body) {
    if (signal?.aborted) return;
    buffer += decoder.decode(chunk, { stream: true });
    let index;
    while ((index = buffer.indexOf("\n")) >= 0) {
      const line = buffer.slice(0, index).trim();
      buffer = buffer.slice(index + 1);
      if (!line.startsWith("data:")) continue;
      const data = line.slice(5).trim();
      if (!data || data === "[DONE]") continue;
      try {
        yield JSON.parse(data);
      } catch {
        // A partial or non-JSON keep-alive line.
      }
    }
  }
}

async function post(url, headers, body, signal) {
  let response;
  try {
    response = await fetch(url, { method: "POST", headers, body: JSON.stringify(body), signal });
  } catch (err) {
    if (signal?.aborted) throw err;
    throw new ApiError(`network error: ${err.cause?.message ?? err.message}`, 0, true);
  }
  if (!response.ok) {
    const text = (await response.text().catch(() => "")).slice(0, 800);
    let message = text;
    try {
      const parsed = JSON.parse(text);
      message = parsed.error?.message ?? parsed.message ?? text;
    } catch {}
    const retryable = response.status === 429 || response.status >= 500;
    throw new ApiError(`HTTP ${response.status}: ${message}`, response.status, retryable);
  }
  return response;
}

// OpenAI chat completions ----------------------------------------------------------

function toOpenAI(system, messages) {
  const out = [{ role: "system", content: system }];
  for (const m of messages) {
    if (m.role === "user") {
      out.push({ role: "user", content: textOf(m.content) });
    } else if (m.role === "assistant") {
      const calls = m.content.filter((p) => p.type === "toolCall");
      out.push({
        role: "assistant",
        content: textOf(m.content) || null,
        ...(calls.length && {
          tool_calls: calls.map((c) => ({
            id: c.id,
            type: "function",
            function: { name: c.name, arguments: JSON.stringify(c.arguments ?? {}) },
          })),
        }),
      });
    } else if (m.role === "toolResult") {
      out.push({ role: "tool", tool_call_id: m.toolCallId, content: textOf(m.content) || "(no output)" });
    }
  }
  return out;
}

async function openai({ provider, model, system, messages, tools, signal, onText, onThinking }) {
  const key = resolveKey(provider.api_key);
  const headers = { "content-type": "application/json", ...(provider.headers ?? {}) };
  if (key) headers.authorization = `Bearer ${key}`;
  const body = {
    model: model.id,
    messages: toOpenAI(system, messages),
    stream: true,
    stream_options: { include_usage: true },
    max_tokens: model.maxTokens,
  };
  if (tools?.length) {
    body.tools = tools.map((t) => ({
      type: "function",
      function: { name: t.name, description: t.description, parameters: t.parameters },
    }));
  }
  const url = provider.base_url.replace(/\/+$/, "") + "/chat/completions";
  const response = await post(url, headers, body, signal);

  let text = "";
  let thinking = "";
  const calls = [];
  let usage = {};
  let stopReason = "stop";
  for await (const event of events(response, signal)) {
    if (event.error) throw new ApiError(event.error.message ?? JSON.stringify(event.error), 0, false);
    if (event.usage) usage = event.usage;
    const choice = event.choices?.[0];
    if (!choice) continue;
    const delta = choice.delta ?? {};
    const reasoning = delta.reasoning_content ?? delta.reasoning;
    if (typeof reasoning === "string" && reasoning) {
      thinking += reasoning;
      onThinking?.(reasoning);
    }
    if (typeof delta.content === "string" && delta.content) {
      text += delta.content;
      onText?.(delta.content);
    }
    for (const tc of delta.tool_calls ?? []) {
      const i = tc.index ?? calls.length;
      calls[i] ??= { id: "", name: "", args: "" };
      if (tc.id) calls[i].id = tc.id;
      if (tc.function?.name) calls[i].name += tc.function.name;
      if (tc.function?.arguments) calls[i].args += tc.function.arguments;
    }
    if (choice.finish_reason) stopReason = choice.finish_reason;
  }
  const content = [];
  if (thinking) content.push({ type: "thinking", text: thinking });
  if (text) content.push({ type: "text", text });
  calls.filter(Boolean).forEach((c, i) => {
    let args = {};
    try {
      args = c.args ? JSON.parse(c.args) : {};
    } catch {
      args = { __invalid_json: c.args };
    }
    content.push({ type: "toolCall", id: c.id || `call_${Date.now()}_${i}`, name: c.name, arguments: args });
  });
  const cached = usage.prompt_tokens_details?.cached_tokens ?? 0;
  return {
    content,
    stopReason: stopReason === "length" ? "length" : calls.length ? "toolUse" : "stop",
    usage: {
      input: (usage.prompt_tokens ?? 0) - cached,
      output: usage.completion_tokens ?? 0,
      cacheRead: cached,
      cacheWrite: 0,
    },
  };
}

// Anthropic messages ---------------------------------------------------------------

function toAnthropic(messages) {
  const out = [];
  const push = (role, blocks) => {
    const last = out[out.length - 1];
    if (last && last.role === role) last.content.push(...blocks);
    else out.push({ role, content: blocks });
  };
  for (const m of messages) {
    if (m.role === "user") {
      push("user", [{ type: "text", text: textOf(m.content) }]);
    } else if (m.role === "assistant") {
      const blocks = [];
      for (const p of m.content) {
        if (p.type === "text" && p.text) blocks.push({ type: "text", text: p.text });
        if (p.type === "toolCall") blocks.push({ type: "tool_use", id: p.id, name: p.name, input: p.arguments ?? {} });
      }
      if (blocks.length) push("assistant", blocks);
    } else if (m.role === "toolResult") {
      push("user", [
        {
          type: "tool_result",
          tool_use_id: m.toolCallId,
          content: textOf(m.content) || "(no output)",
          is_error: m.isError || undefined,
        },
      ]);
    }
  }
  // Cache the conversation so far: each turn re-reads it instead of paying again.
  const last = out[out.length - 1];
  if (last) last.content[last.content.length - 1].cache_control = { type: "ephemeral" };
  return out;
}

async function anthropic({ provider, model, system, messages, tools, signal, onText, onThinking }) {
  const key = resolveKey(provider.api_key);
  const headers = {
    "content-type": "application/json",
    "anthropic-version": "2023-06-01",
    ...(provider.headers ?? {}),
  };
  if (key) headers["x-api-key"] = key;
  const body = {
    model: model.id,
    max_tokens: model.maxTokens,
    system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }],
    messages: toAnthropic(messages),
    stream: true,
  };
  if (tools?.length) {
    body.tools = tools.map((t) => ({ name: t.name, description: t.description, input_schema: t.parameters }));
  }
  const url = provider.base_url.replace(/\/+$/, "") + "/messages";
  const response = await post(url, headers, body, signal);

  const blocks = [];
  const usage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
  let stopReason = "stop";
  for await (const event of events(response, signal)) {
    if (event.type === "error") throw new ApiError(event.error?.message ?? "stream error", 0, event.error?.type === "overloaded_error");
    if (event.type === "message_start") {
      const u = event.message?.usage ?? {};
      usage.input = u.input_tokens ?? 0;
      usage.cacheRead = u.cache_read_input_tokens ?? 0;
      usage.cacheWrite = u.cache_creation_input_tokens ?? 0;
    } else if (event.type === "content_block_start") {
      const b = event.content_block;
      blocks[event.index] =
        b.type === "tool_use"
          ? { type: "toolCall", id: b.id, name: b.name, json: "" }
          : b.type === "thinking"
            ? { type: "thinking", text: "" }
            : { type: "text", text: "" };
    } else if (event.type === "content_block_delta") {
      const b = blocks[event.index];
      const d = event.delta;
      if (d.type === "text_delta") {
        b.text += d.text;
        onText?.(d.text);
      } else if (d.type === "thinking_delta") {
        b.text += d.thinking;
        onThinking?.(d.thinking);
      } else if (d.type === "input_json_delta") {
        b.json += d.partial_json;
      }
    } else if (event.type === "message_delta") {
      usage.output = event.usage?.output_tokens ?? usage.output;
      if (event.delta?.stop_reason === "tool_use") stopReason = "toolUse";
      else if (event.delta?.stop_reason === "max_tokens") stopReason = "length";
    }
  }
  const content = blocks.filter(Boolean).map((b) => {
    if (b.type !== "toolCall") return b;
    let args = {};
    try {
      args = b.json ? JSON.parse(b.json) : {};
    } catch {
      args = { __invalid_json: b.json };
    }
    return { type: "toolCall", id: b.id, name: b.name, arguments: args };
  });
  return { content, stopReason, usage };
}

// Entry point ----------------------------------------------------------------------

const RETRIES = 4;

// One model turn, with retries on rate limits, overload and network errors.
// onRetry(message, seconds) is called before each wait.
export async function complete(options) {
  const call = (options.provider.api ?? "openai").startsWith("anthropic") ? anthropic : openai;
  for (let attempt = 0; ; attempt += 1) {
    try {
      return await call(options);
    } catch (err) {
      if (options.signal?.aborted) throw err;
      const limit = /usage limit|quota|credit|insufficient/i.test(err.message);
      if (!(err instanceof ApiError) || !err.retryable || limit || attempt >= RETRIES) throw err;
      const seconds = Math.min(30, 2 ** attempt * 2);
      options.onRetry?.(err.message, seconds);
      await new Promise((resolve, reject) => {
        const timer = setTimeout(resolve, seconds * 1000);
        options.signal?.addEventListener("abort", () => {
          clearTimeout(timer);
          reject(options.signal.reason ?? new Error("aborted"));
        });
      });
    }
  }
}
