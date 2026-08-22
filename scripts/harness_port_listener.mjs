#!/usr/bin/env node

import net from "node:net";

const [signalText, webText, runId] = process.argv.slice(2);
const ports = [Number(signalText), Number(webText)];
if (ports.some((port) => !Number.isInteger(port) || port < 1 || port > 65535) || !runId) {
  console.error("usage: harness_port_listener.mjs <signal-port> <web-port> <run-id>");
  process.exit(2);
}

const servers = ports.map(() => net.createServer((socket) => socket.end()));
let ready = 0;
let stopping = false;

function stop(status = 0) {
  if (stopping) return;
  stopping = true;
  let remaining = servers.length;
  for (const server of servers) {
    server.close(() => {
      remaining -= 1;
      if (remaining === 0) process.exit(status);
    });
  }
  setTimeout(() => process.exit(status), 1000).unref();
}

for (let index = 0; index < servers.length; index += 1) {
  const server = servers[index];
  server.on("error", (error) => {
    console.error(`HARNESS_PORT_ERROR run_id=${runId} port=${ports[index]} ${error.message}`);
    stop(1);
  });
  server.listen(ports[index], "127.0.0.1", () => {
    ready += 1;
    if (ready === servers.length) {
      console.log(`HARNESS_PORTS_READY run_id=${runId} signal=${ports[0]} web=${ports[1]}`);
    }
  });
}

process.on("SIGHUP", () => stop(129));
process.on("SIGINT", () => stop(130));
process.on("SIGTERM", () => stop(143));

