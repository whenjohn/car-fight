#!/usr/bin/env node

import { spawn } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const chromeBin = process.env.CHROME_BIN
  || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const url = process.argv[2] || "http://127.0.0.1:8088/";
const reportPath = resolve(process.argv[3] || "build/web-smoke-report.json");
const screenshotPath = resolve(process.argv[4] || "build/web-smoke.png");
const profile = mkdtempSync(join(tmpdir(), "car-fight-web-smoke-"));
const chrome = spawn(chromeBin, [
  "--remote-debugging-port=0",
  `--user-data-dir=${profile}`,
  "--no-first-run",
  "--no-default-browser-check",
  "--disable-extensions",
  "--disable-background-networking",
  "--disable-background-timer-throttling",
  "--disable-backgrounding-occluded-windows",
  "--disable-component-update",
  "--disable-renderer-backgrounding",
  "--disable-sync",
  "--window-size=1280,815",
  "--window-position=80,80",
  "--new-window",
  "about:blank",
], { stdio: ["ignore", "ignore", "pipe"] });

let chromeStderr = "";
chrome.stderr.on("data", chunk => { chromeStderr += chunk.toString(); });

const sleep = milliseconds => new Promise(resolvePromise => setTimeout(resolvePromise, milliseconds));

async function waitForDevTools() {
  const activePort = join(profile, "DevToolsActivePort");
  for (let attempt = 0; attempt < 200; attempt += 1) {
    try {
      const [port] = readFileSync(activePort, "utf8").trim().split("\n");
      if (port) return Number(port);
    } catch (_) {
      // Chrome creates the file only after its debugging endpoint is ready.
    }
    await sleep(50);
  }
  throw new Error("Chrome did not publish DevToolsActivePort");
}

async function waitForPage(port) {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    const targets = await fetch(`http://127.0.0.1:${port}/json/list`).then(response => response.json());
    const page = targets.find(target => target.type === "page");
    if (page) return page;
    await sleep(50);
  }
  throw new Error("Chrome did not create a page target");
}

async function run() {
  const port = await waitForDevTools();
  const page = await waitForPage(port);
  const socket = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolvePromise, reject) => {
    socket.addEventListener("open", resolvePromise, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  let commandId = 0;
  const pending = new Map();
  const consoleMessages = [];
  const errors = [];
  const telemetry = [];
  let loadTimestamp = null;

  const captureText = (text, source, level = "info") => {
    consoleMessages.push({ source, level, text });
    const marker = "CAR_FIGHT_TELEMETRY ";
    const markerIndex = text.indexOf(marker);
    if (markerIndex >= 0) {
      try {
        telemetry.push(JSON.parse(text.slice(markerIndex + marker.length)));
      } catch (error) {
        errors.push({ source: "telemetry_parse", text: String(error), raw: text });
      }
    }
    if (level === "error" && /(^|\s)(ERROR:|SCRIPT ERROR:|Uncaught |WebGL: INVALID)/.test(text)) {
      errors.push({ source, text });
    }
  };

  socket.addEventListener("message", event => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const { resolve: resolveCommand, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) reject(new Error(message.error.message));
      else resolveCommand(message.result || {});
      return;
    }
    if (message.method === "Runtime.consoleAPICalled") {
      const text = message.params.args
        .map(argument => argument.value ?? argument.description ?? "")
        .join(" ");
      captureText(text, "console", message.params.type);
    } else if (message.method === "Runtime.exceptionThrown") {
      errors.push({
        source: "exception",
        text: message.params.exceptionDetails.exception?.description
          || message.params.exceptionDetails.text,
      });
    } else if (message.method === "Log.entryAdded") {
      captureText(message.params.entry.text, message.params.entry.source,
        message.params.entry.level);
    } else if (message.method === "Page.loadEventFired") {
      loadTimestamp = message.params.timestamp;
    }
  });

  const send = (method, params = {}) => new Promise((resolveCommand, reject) => {
    commandId += 1;
    pending.set(commandId, { resolve: resolveCommand, reject });
    socket.send(JSON.stringify({ id: commandId, method, params }));
  });

  await send("Runtime.enable");
  await send("Log.enable");
  await send("Page.enable");
  await send("Performance.enable");
  await send("Page.bringToFront");
  await send("Emulation.setFocusEmulationEnabled", { enabled: true });
  await send("Page.navigate", { url });

  const deadline = Date.now() + 45000;
  while (!telemetry.some(record => record.event === "offline_ready")) {
    if (Date.now() >= deadline) throw new Error("offline_ready telemetry timed out");
    await sleep(100);
  }

  // Focus the canvas, then hold the mouse toward its right side. Car Fight's
  // normal mouse-follow input should accelerate the local Jeep without a test
  // hook or browser-only gameplay path.
  await send("Input.dispatchMouseEvent", { type: "mousePressed", x: 640, y: 400,
    button: "left", clickCount: 1 });
  await send("Input.dispatchMouseEvent", { type: "mouseReleased", x: 640, y: 400,
    button: "left", clickCount: 1 });
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 1080, y: 400,
    button: "none" });

  const sampleDeadline = Date.now() + 20000;
  while (telemetry.filter(record => record.event === "sample").length < 10
      && Date.now() < sampleDeadline) {
    await sleep(100);
  }

  const runtime = await send("Runtime.evaluate", {
    expression: `JSON.stringify({
      crossOriginIsolated,
      canvas: (() => { const c = document.querySelector("canvas"); return c ?
        {width: c.width, height: c.height, clientWidth: c.clientWidth,
         clientHeight: c.clientHeight} : null; })(),
      navigation: performance.getEntriesByType("navigation")[0]?.toJSON() || null
    })`,
    returnByValue: true,
  });
  const browserState = JSON.parse(runtime.result.value);
  const browserVersion = await send("Browser.getVersion");
  const performance = await send("Performance.getMetrics");
  const screenshot = await send("Page.captureScreenshot", { format: "png" });
  writeFileSync(screenshotPath, Buffer.from(screenshot.data, "base64"));

  const samples = telemetry.filter(record => record.event === "sample");
  const readyRecord = telemetry.find(record => record.event === "offline_ready");
  const fpsValues = samples.map(record => Number(record.fps || 0));
  const steadyFpsValues = fpsValues.slice(-5);
  const speedValues = samples.map(record => Number(record.player_speed || 0));
  const rapierReady = consoleMessages.some(message =>
    message.text.includes("PHYSICS ENGINE 3D: Rapier3D v0.8.39"));
  const report = {
    url,
    chrome_version: browserVersion.product || null,
    load_event_timestamp: loadTimestamp,
    cross_origin_isolated: browserState.crossOriginIsolated,
    canvas: browserState.canvas,
    navigation: browserState.navigation,
    rapier_ready: rapierReady,
    offline_ready: Boolean(readyRecord),
    runtime_ready_msec: Number(readyRecord?.monotonic_msec || 0),
    telemetry_samples: samples.length,
    fps: {
      minimum: fpsValues.length ? Math.min(...fpsValues) : 0,
      average: fpsValues.length ? fpsValues.reduce((sum, value) => sum + value, 0)
        / fpsValues.length : 0,
      latest: fpsValues.at(-1) || 0,
    },
    steady_fps: {
      minimum: steadyFpsValues.length ? Math.min(...steadyFpsValues) : 0,
      average: steadyFpsValues.length
        ? steadyFpsValues.reduce((sum, value) => sum + value, 0) / steadyFpsValues.length : 0,
    },
    maximum_player_speed: speedValues.length ? Math.max(...speedValues) : 0,
    maximum_frame_ms: samples.length
      ? Math.max(...samples.map(record => Number(record.maximum_frame_ms || 0))) : 0,
    latest_sample: samples.at(-1) || null,
    sample_series: samples.map(record => ({
      monotonic_msec: record.monotonic_msec,
      fps: record.fps,
      maximum_frame_ms: record.maximum_frame_ms,
      process_ms: record.process_ms,
      physics_ms: record.physics_ms,
      nodes: record.nodes,
      draw_calls: record.draw_calls,
      static_memory_bytes: record.static_memory_bytes,
      video_memory_bytes: record.video_memory_bytes,
      player_speed: record.player_speed,
    })),
    browser_performance_metrics: Object.fromEntries(
      performance.metrics.map(metric => [metric.name, metric.value])),
    errors,
    relevant_console: consoleMessages.filter(message =>
      message.text.includes("Rapier3D")
      || message.text.includes("CAR_FIGHT_TELEMETRY")
      || message.level === "error"),
    chrome_stderr_tail: chromeStderr.split("\n").filter(Boolean).slice(-30),
    screenshot: screenshotPath,
  };
  report.pass = report.cross_origin_isolated && report.rapier_ready
    && report.offline_ready && report.telemetry_samples >= 5
    && report.maximum_player_speed > 1.0 && report.errors.length === 0;
  writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(`WEB_SMOKE ${report.pass ? "PASS" : "FAIL"}`);
  console.log(`report: ${reportPath}`);
  console.log(`fps avg=${report.fps.average.toFixed(1)} min=${report.fps.minimum.toFixed(1)}`
    + ` steady=${report.steady_fps.average.toFixed(1)} latest=${report.fps.latest.toFixed(1)}`
    + ` speed_max=${report.maximum_player_speed.toFixed(2)}`
    + ` errors=${report.errors.length}`);

  socket.close();
  if (!report.pass) process.exitCode = 1;
}

try {
  await run();
} catch (error) {
  console.error(`WEB_SMOKE FAIL: ${error.stack || error}`);
  console.error(chromeStderr.split("\n").filter(Boolean).slice(-30).join("\n"));
  process.exitCode = 1;
} finally {
  if (chrome.exitCode === null) chrome.kill("SIGTERM");
  await Promise.race([
    new Promise(resolvePromise => chrome.once("exit", resolvePromise)),
    sleep(3000),
  ]);
  rmSync(profile, { recursive: true, force: true });
}
