#!/usr/bin/env node

import { spawn } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const chromeBin = process.env.CHROME_BIN
  || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const url = process.argv[2];
const reportPath = resolve(process.argv[3] || "build/web-network-smoke-report.json");
const screenshotPath = resolve(process.argv[4] || "build/web-network-smoke.png");
if (!url) throw new Error("usage: web_network_smoke.mjs URL [report] [screenshot]");
const soakSeconds = Number(process.env.CAR_FIGHT_WEBRTC_SOAK_SECONDS || 0);
if (!Number.isFinite(soakSeconds) || soakSeconds < 0) {
  throw new Error("CAR_FIGHT_WEBRTC_SOAK_SECONDS must be a non-negative number");
}
const replacementSampleTarget = soakSeconds > 0
  ? Math.max(18, Math.floor(soakSeconds * 0.75))
  : 18;
const inputMode = soakSeconds > 0 ? "neutral" : "drive";

const profile = mkdtempSync(join(tmpdir(), "car-fight-web-network-"));
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

async function waitForValue(read, timeoutMs, label) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const value = read();
    if (value) return value;
    await sleep(100);
  }
  throw new Error(`${label} timed out after ${timeoutMs}ms`);
}

async function waitForDevTools() {
  const activePort = join(profile, "DevToolsActivePort");
  return waitForValue(() => {
    try {
      const [port] = readFileSync(activePort, "utf8").trim().split("\n");
      return port ? Number(port) : null;
    } catch (_) {
      return null;
    }
  }, 10000, "Chrome DevTools port");
}

async function run() {
  const port = await waitForDevTools();
  const pages = await waitForValue(async () => {
    const targets = await fetch(`http://127.0.0.1:${port}/json/list`).then(r => r.json());
    return targets.filter(target => target.type === "page");
  }, 5000, "Chrome page target");
  const page = pages[0];
  const socket = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolvePromise, reject) => {
    socket.addEventListener("open", resolvePromise, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  let commandId = 0;
  const pending = new Map();
  const consoleMessages = [];
  const telemetry = [];
  const errors = [];
  let lifecyclePhase = "launch";
  const send = (method, params = {}) => new Promise((resolveCommand, reject) => {
    commandId += 1;
    pending.set(commandId, { resolve: resolveCommand, reject });
    socket.send(JSON.stringify({ id: commandId, method, params }));
  });

  const capture = (text, source, level = "info", stackTrace = null) => {
    const stack = (stackTrace?.callFrames || []).map(frame => ({
      function: frame.functionName,
      url: frame.url,
      line: Number(frame.lineNumber) + 1,
      column: Number(frame.columnNumber) + 1,
    }));
    consoleMessages.push({ source, level, text, time_msec: Date.now(), stack });
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
      const captured = { source, text, stack, lifecycle_phase: lifecyclePhase };
      errors.push(captured);
      console.error(`WEB_NETWORK_CAPTURED_ERROR ${JSON.stringify(captured)}`);
    }
  };

  socket.addEventListener("message", event => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const handler = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) handler.reject(new Error(message.error.message));
      else handler.resolve(message.result || {});
      return;
    }
    if (message.method === "Runtime.consoleAPICalled") {
      const text = message.params.args
        .map(argument => argument.value ?? argument.description ?? "").join(" ");
      capture(text, "console", message.params.type, message.params.stackTrace);
    } else if (message.method === "Runtime.exceptionThrown") {
      const captured = { source: "exception",
        text: message.params.exceptionDetails.exception?.description
          || message.params.exceptionDetails.text,
        stack: (message.params.exceptionDetails.stackTrace?.callFrames || []).map(frame => ({
          function: frame.functionName,
          url: frame.url,
          line: Number(frame.lineNumber) + 1,
          column: Number(frame.columnNumber) + 1,
        })) };
      errors.push(captured);
      console.error(`WEB_NETWORK_CAPTURED_ERROR ${JSON.stringify(captured)}`);
    } else if (message.method === "Log.entryAdded") {
      capture(message.params.entry.text, message.params.entry.source,
        message.params.entry.level, message.params.entry.stackTrace);
    }
  });

  await send("Runtime.enable");
  await send("Log.enable");
  await send("Page.enable");
  await send("Performance.enable");
  await send("Page.bringToFront");
  await send("Emulation.setFocusEmulationEnabled", { enabled: true });

  const readyLines = () => consoleMessages.filter(message =>
    message.text.includes("[car-fight:client] CLIENT_READY id="));
  const sharedWorldLines = () => consoleMessages.filter(message =>
    /\[car-fight:client\] CLIENT_TICK .*players=[2-9][0-9]* world=[^|]+\|/.test(message.text));
  const drive = async () => {
    await send("Input.dispatchMouseEvent", { type: "mousePressed", x: 640, y: 400,
      button: "left", clickCount: 1 });
    await send("Input.dispatchMouseEvent", { type: "mouseReleased", x: 640, y: 400,
      button: "left", clickCount: 1 });
    await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 1080, y: 400,
      button: "none" });
  };
  const neutralize = async () => {
    // A click transfers focus from the browser shell to the game. Keep the
    // pointer centered afterwards so a soak observes networking without
    // silently steering the local car into arena geometry.
    const centerResult = await send("Runtime.evaluate", {
      expression: `(() => {
        const rect = document.querySelector("canvas")?.getBoundingClientRect();
        return rect ? { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 }
          : { x: 640, y: 360 };
      })()`,
      returnByValue: true,
    });
    const center = centerResult.result?.value || { x: 640, y: 360 };
    await send("Input.dispatchMouseEvent", { type: "mousePressed", x: center.x, y: center.y,
      button: "left", clickCount: 1 });
    await send("Input.dispatchMouseEvent", { type: "mouseReleased", x: center.x, y: center.y,
      button: "left", clickCount: 1 });
    await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: center.x, y: center.y,
      button: "none" });
  };
  const applyInputMode = () => inputMode === "neutral" ? neutralize() : drive();

  await send("Page.navigate", { url });
  lifecyclePhase = "first_gameplay";
  const firstReady = await waitForValue(() => readyLines()[0], 45000, "first browser join");
  await applyInputMode();
  await waitForValue(() => sharedWorldLines()[0], 15000, "first shared-world sample");
  await waitForValue(() => telemetry.filter(record => record.event === "sample").length >= 6,
    15000, "first telemetry window");
  const firstId = Number(firstReady.text.match(/CLIENT_READY id=(\d+)/)?.[1] || 0);

  // Leave the shared world long enough for the server's cross-transport RPC
  // tombstone to drain, then reload the same network page as a fresh browser peer.
  lifecyclePhase = "first_teardown";
  await send("Page.navigate", { url: "about:blank" });
  await sleep(2200);
  const secondStartIndex = telemetry.length;
  const secondSharedStartIndex = sharedWorldLines().length;
  lifecyclePhase = "replacement_startup";
  await send("Page.navigate", { url });
  const secondReady = await waitForValue(() => readyLines()[1], 45000, "replacement browser join");
  await applyInputMode();
  await waitForValue(() => sharedWorldLines().length > secondSharedStartIndex,
    15000, "replacement shared-world sample");
  lifecyclePhase = "replacement_soak";
  const soakStartedMsec = Date.now();
  if (soakSeconds > 0) {
    const soakDeadline = soakStartedMsec + soakSeconds * 1000;
    while (Date.now() < soakDeadline) {
      if (chrome.exitCode !== null) throw new Error("Chrome exited during the soak window");
      if (errors.length > 0) {
        console.error(`WEB_NETWORK_ERROR_CONTEXT ${JSON.stringify(
          consoleMessages.slice(-30).map(message => ({
            time_msec: message.time_msec,
            level: message.level,
            text: message.text,
          })))}`);
        throw new Error(`browser error occurred during the soak window: ${JSON.stringify(errors.at(-1))}`);
      }
      await sleep(Math.min(250, soakDeadline - Date.now()));
    }
  }
  await waitForValue(() => telemetry.slice(secondStartIndex)
    .filter(record => record.event === "sample").length >= replacementSampleTarget,
    soakSeconds > 0 ? 15000 : 30000, "replacement telemetry window");
  const soakObservedSeconds = (Date.now() - soakStartedMsec) / 1000;
  const secondId = Number(secondReady.text.match(/CLIENT_READY id=(\d+)/)?.[1] || 0);

  // Stop driving, then wait for a clean channel sample after the active input
  // burst. Authority continues at 60 Hz, so the assertion is that the SCTP
  // queue repeatedly drains—not that gameplay traffic stops.
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 640, y: 400,
    button: "none" });
  await waitForValue(() => consoleMessages.slice(-20).some(message =>
    /\[webrtc-channel\].*buffered_bytes=0/.test(message.text)),
    5000, "WebRTC queue drain");

  const replacementSamples = telemetry.slice(secondStartIndex)
    .filter(record => record.event === "sample");
  const replacementPositions = replacementSamples
    .map(record => record.player_position)
    .filter(position => Array.isArray(position) && position.length >= 3);
  const firstPosition = replacementPositions[0] || null;
  const planarDistance = (a, b) => Math.hypot(a[0] - b[0], a[2] - b[2]);
  const maximumPlanarDisplacement = firstPosition
    ? Math.max(...replacementPositions.map(position => planarDistance(position, firstPosition)))
    : -1;
  const maximumPlayerSpeed = replacementSamples.length
    ? Math.max(...replacementSamples.map(record => Number(record.player_speed || 0)))
    : -1;
  const fpsValues = replacementSamples.map(record => Number(record.fps || 0));
  const steady = fpsValues.slice(-(soakSeconds > 0 ? 30 : 5));
  const replacementNetworkHud = telemetry.slice(secondStartIndex)
    .filter(record => record.event === "network_hud");
  const finalNetworkHud = replacementNetworkHud.at(-1) || null;
  const replacementCorrections = telemetry.slice(secondStartIndex)
    .filter(record => record.event === "correction_cause");
  const bufferedValues = consoleMessages
    .map(message => message.text.match(/\[webrtc-channel\].*buffered_bytes=(\d+)/))
    .filter(Boolean).map(match => Number(match[1]));
  const worldSnapshots = sharedWorldLines().map(message =>
    message.text.match(/world=([^ ]+)/)?.[1] || "").filter(Boolean);
  const browserVersion = await send("Browser.getVersion");
  const performance = await send("Performance.getMetrics");
  const screenshot = await send("Page.captureScreenshot", { format: "png" });
  writeFileSync(screenshotPath, Buffer.from(screenshot.data, "base64"));

  const report = {
    url,
    chrome_version: browserVersion.product || null,
    first_peer_id: firstId,
    replacement_peer_id: secondId,
    first_shared_world_samples: sharedWorldLines().length,
    distinct_world_snapshots: new Set(worldSnapshots).size,
    soak_seconds_requested: soakSeconds,
    soak_seconds_observed: soakObservedSeconds,
    input_mode: inputMode,
    replacement_sample_target: replacementSampleTarget,
    replacement_samples: replacementSamples.length,
    replacement_sample_series: replacementSamples.map(record => ({
      monotonic_msec: record.monotonic_msec,
      fps: record.fps,
      maximum_frame_ms: record.maximum_frame_ms,
      process_ms: record.process_ms,
      physics_ms: record.physics_ms,
      slow_frames: record.slow_frames,
      player_position: record.player_position,
      player_speed: record.player_speed,
      player_velocity: record.player_velocity,
      maximum_network_loop_ms: record.maximum_network_loop_ms,
      maximum_rollback_loop_ms: record.maximum_rollback_loop_ms,
      maximum_network_ticks: record.maximum_network_ticks,
      maximum_rollback_ticks: record.maximum_rollback_ticks,
    })),
    steady_fps: {
      minimum: steady.length ? Math.min(...steady) : 0,
      average: steady.length ? steady.reduce((sum, value) => sum + value, 0) / steady.length : 0,
    },
    webrtc_buffered_bytes: {
      samples: bufferedValues.length,
      maximum: bufferedValues.length ? Math.max(...bufferedValues) : -1,
      final: bufferedValues.at(-1) ?? -1,
      drained_to_zero: bufferedValues.includes(0),
    },
    network_configuration: consoleMessages
      .filter(message => message.text.includes("[network-shape]"))
      .map(message => message.text),
    stale_rollback_warnings: consoleMessages
      .filter(message => message.text.includes("Skipping stale rollback origin")).length,
    network_health: {
      hud_samples: replacementNetworkHud.length,
      recoveries: Number(finalNetworkHud?.recoveries ?? -1),
      worst_correction: Number(finalNetworkHud?.worst_correction ?? -1),
      correction_events: replacementCorrections.length,
      correction_signals: replacementCorrections.reduce((counts, record) => {
        for (const signal of record.signals || ["unknown"]) {
          counts[signal] = (counts[signal] || 0) + 1;
        }
        return counts;
      }, {}),
      maximum_player_speed: maximumPlayerSpeed,
      maximum_planar_displacement: maximumPlanarDisplacement,
    },
    netapp_tail: consoleMessages
      .filter(message => message.text.includes("NETAPP tick="))
      .slice(-30).map(message => message.text),
    browser_performance_metrics: Object.fromEntries(
      performance.metrics.map(metric => [metric.name, metric.value])),
    errors,
    console_tail: consoleMessages.slice(-120),
    screenshot: screenshotPath,
  };
  const requiredFpsAverage = soakSeconds > 0 ? 40 : 45;
  report.pass = firstId > 1 && secondId > 1 && firstId !== secondId
    && report.first_shared_world_samples >= 2
    && report.replacement_samples >= replacementSampleTarget
    && report.distinct_world_snapshots >= 2
    // Local cross-play is deliberately a capacity smoke, not the offline
    // renderer benchmark. On this Mac the networked browser varies with Chrome
    // scheduling but remains playable while physics and SCTP stay healthy.
    // A long unattended durability run retains the 30 FPS floor but allows a
    // lower average than the short playable smoke. Correction and movement
    // gates below remain strict, so local renderer slowdown cannot hide a jump.
    && report.steady_fps.minimum >= 30
    && report.steady_fps.average >= requiredFpsAverage
    && report.webrtc_buffered_bytes.samples >= 2
    && report.webrtc_buffered_bytes.maximum <= 65536
    && report.webrtc_buffered_bytes.drained_to_zero
    && report.stale_rollback_warnings <= 4
    && (soakSeconds <= 0 || (report.soak_seconds_observed >= soakSeconds
      && report.network_health.hud_samples >= 2
      && report.network_health.recoveries >= 0
      && report.network_health.recoveries <= 4
      && report.network_health.worst_correction >= 0
      && report.network_health.worst_correction <= 2.0
      && report.input_mode === "neutral"
      && report.network_health.maximum_player_speed <= 0.5
      && report.network_health.maximum_planar_displacement <= 1.0))
    && errors.length === 0;
  writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(`WEB_NETWORK_SMOKE ${report.pass ? "PASS" : "FAIL"}`);
  console.log(`report: ${reportPath}`);
  console.log(`peers=${firstId}->${secondId} shared=${report.first_shared_world_samples}`
    + ` fps_steady=${report.steady_fps.average.toFixed(1)}`
    + ` buffer_max=${report.webrtc_buffered_bytes.maximum}`
    + ` buffer_final=${report.webrtc_buffered_bytes.final}`
    + ` recoveries=${report.network_health.recoveries}`
    + ` worst_correction=${report.network_health.worst_correction.toFixed(3)}`
    + ` max_speed=${report.network_health.maximum_player_speed.toFixed(3)}`
    + ` displacement=${report.network_health.maximum_planar_displacement.toFixed(3)}`
    + ` soak=${report.soak_seconds_observed.toFixed(1)}s errors=${errors.length}`);
  socket.close();
  if (!report.pass) process.exitCode = 1;
}

try {
  await run();
} catch (error) {
  console.error(`WEB_NETWORK_SMOKE FAIL: ${error.stack || error}`);
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
