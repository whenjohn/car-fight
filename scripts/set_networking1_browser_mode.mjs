#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { join } from "node:path";

const profile = process.argv[2];
const action = process.argv[3];
if (!profile || !["fixed", "adaptive", "predictive", "proxy", "cruise"].includes(action)) {
  throw new Error("usage: set_networking1_browser_mode.mjs CHROME_PROFILE fixed|adaptive|predictive|proxy|cruise");
}

const [port, browserPath] = readFileSync(join(profile, "DevToolsActivePort"), "utf8")
  .trim().split("\n");
const socket = new WebSocket(`ws://127.0.0.1:${port}${browserPath}`);
await new Promise((resolve, reject) => {
  socket.addEventListener("open", resolve, { once: true });
  socket.addEventListener("error", reject, { once: true });
});

let nextId = 0;
const pending = new Map();
socket.addEventListener("message", event => {
  const message = JSON.parse(event.data);
  if (!message.id || !pending.has(message.id)) return;
  const { resolve, reject, timeout } = pending.get(message.id);
  pending.delete(message.id);
  clearTimeout(timeout);
  if (message.error) reject(new Error(message.error.message));
  else resolve(message.result || {});
});
const send = (method, params = {}, sessionId = undefined) => new Promise((resolve, reject) => {
  nextId += 1;
  const id = nextId;
  const timeout = setTimeout(() => {
    pending.delete(id);
    reject(new Error(`browser control timed out during ${method}`));
  }, 5000);
  pending.set(id, { resolve, reject, timeout });
  socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
});

const { targetInfos } = await send("Target.getTargets");
const page = targetInfos.find(target => target.type === "page"
  && target.url.startsWith("http://127.0.0.1:"));
if (!page) throw new Error(`Car Fight browser target not found: ${JSON.stringify(targetInfos)}`);
const { sessionId } = await send("Target.attachToTarget", {
  targetId: page.targetId,
  flatten: true,
});
if (action === "cruise") {
  await send("Runtime.evaluate", {
    expression: "document.querySelector('canvas')?.focus()",
    returnByValue: true,
  }, sessionId);
  const key = {
    key: "p",
    code: "KeyP",
    text: "p",
    unmodifiedText: "p",
    keyIdentifier: "U+0050",
    windowsVirtualKeyCode: 80,
    nativeVirtualKeyCode: 35,
  };
  await send("Input.dispatchKeyEvent", { type: "rawKeyDown", ...key }, sessionId);
  await send("Input.dispatchKeyEvent", { type: "keyUp", ...key }, sessionId);
} else {
  await send("Runtime.evaluate", {
    expression: `window.localStorage.setItem('carFightPresentationMode', ${JSON.stringify(action)})`,
    returnByValue: true,
  }, sessionId);
}
socket.close();
console.log(action === "cruise"
  ? "BROWSER_CONTROL cruise=toggle"
  : `PRESENTATION_BROWSER_CONTROL mode=${action}`);
