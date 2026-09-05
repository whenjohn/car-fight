import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { isIP } from 'node:net';
import { parseArgs } from 'node:util';
import { pathToFileURL } from 'node:url';

export function captureOptions(values) {
  const port = Number(values.port), seconds = Number(values.seconds ?? 120);
  if (!values.interface || !isIP(values.host) || !values.out ||
      !Number.isInteger(port) || port < 1 || port > 65535 ||
      !Number.isInteger(seconds) || seconds < 1 || seconds > 300) {
    throw new Error('Required: --interface DEVICE --host IP --port PORT --out NEW_DIR [--seconds 1..300]');
  }
  return { interface: values.interface, host: values.host, port, seconds, out: path.resolve(values.out) };
}

export async function capture(options, executable = '/usr/sbin/tcpdump') {
  fs.mkdirSync(path.dirname(options.out), { recursive: true });
  fs.mkdirSync(options.out, { mode: 0o700 }); // Never overwrite prior evidence.
  const pcap = path.join(options.out, 'packets.pcap');
  const fd = fs.openSync(pcap, 'wx', 0o600);
  const filter = `udp and host ${options.host} and port ${options.port}`;
  const args = ['-i', options.interface, '-p', '-nn', '-U', '-s', '96',
    '-c', '200000', '-w', '-', filter];
  const started = Date.now();
  const child = spawn(executable, args, { stdio: ['ignore', fd, 'pipe'] });
  fs.closeSync(fd);
  let stderr = '', forced = false, stopping = false, stopTimer;
  child.stderr.on('data', data => { stderr = (stderr + data).slice(-1024 * 1024); });
  const stop = () => {
    if (stopping) return;
    stopping = true;
    child.kill('SIGINT');
    stopTimer = setTimeout(() => { forced = true; child.kill('SIGKILL'); }, 3000);
  };
  const timer = setTimeout(stop, options.seconds * 1000);
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);
  const result = await new Promise(resolve => {
    child.once('error', error => resolve({ code: null, error: error.message }));
    child.once('close', (code, signal) => resolve({ code, signal }));
  });
  clearTimeout(timer);
  clearTimeout(stopTimer);
  process.removeListener('SIGINT', stop);
  process.removeListener('SIGTERM', stop);
  const captured = Number(stderr.match(/(\d+) packets? captured/)?.[1] ?? NaN);
  const kernelDropped = Number(stderr.match(/(\d+) packets? dropped by kernel/)?.[1] ?? NaN);
  const metadata = { ...options, filter, snaplen: 96, packet_cap: 200000,
    started_unix_ms: started, ended_unix_ms: Date.now(), result, forced,
    captured: Number.isFinite(captured) ? captured : null,
    kernel_dropped: Number.isFinite(kernelDropped) ? kernelDropped : null,
    packet_cap_reached: captured >= 200000,
    complete: result.code === 0 && !forced };
  fs.writeFileSync(path.join(options.out, 'tcpdump.stderr'), stderr, { mode: 0o600 });
  fs.writeFileSync(path.join(options.out, 'capture.json'), JSON.stringify(metadata, null, 2) + '\n', { mode: 0o600 });
  // sudo is only needed to open BPF; return private evidence to its invoking user.
  if (process.getuid?.() === 0 && /^\d+$/.test(process.env.SUDO_UID ?? '') &&
      /^\d+$/.test(process.env.SUDO_GID ?? '')) {
    for (const item of ['packets.pcap', 'tcpdump.stderr', 'capture.json', '']) {
      fs.chownSync(path.join(options.out, item), Number(process.env.SUDO_UID), Number(process.env.SUDO_GID));
    }
  }
  return metadata;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    const { values } = parseArgs({ options: Object.fromEntries(
      ['interface', 'host', 'port', 'seconds', 'out'].map(key => [key, { type: 'string' }])) });
    const result = await capture(captureOptions(values));
    console.log(JSON.stringify(result));
    if (!result.complete || !result.captured) process.exitCode = 1;
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
