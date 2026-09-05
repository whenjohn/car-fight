import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { capture, captureOptions } from './network_packet_capture.mjs';
import { analyze, packetSummaries } from './network_diagnostics_report.mjs';
import { startupSummary } from './network_startup_report.mjs';

const startupRow = (time, x, generation = 1) => ({ event: 'startup_sample', mono_usec: time,
  epoch: 0, body_id: '42', instance_id: 123, generation, tick: 90, tickrate: 60,
  reference_seconds: 2.5, physics: { position: [x, 0, 0] }, node_position: [x, 0, 0],
  recorded_cursor: [12, 0] });
const startupRows = [startupRow(1000, 0), startupRow(17000, 1), startupRow(33000, 0),
  startupRow(49000, 2), startupRow(65000, 0, 2)];
const finishStartup = rows => [...rows, { event: 'complete', records: rows.length, dropped: 0, startup_dropped: 0 }];
const startup = startupSummary(finishStartup(startupRows));
assert.deepEqual(startup.quality_warnings, []);
assert.equal(startup.return_to_first_pose_count, 1);
assert.equal(startup.backwards_step_count, 1);
assert.equal(startup.identities, 2);
assert.equal(startup.reference_minus_tick_ms.max, 1000);
assert.equal(startupSummary(finishStartup([])).quality_warnings.length, 1);
assert(startupSummary(startupRows).quality_warnings.length > 0);
assert(startupSummary([...startupRows, { event: 'complete', records: 5, dropped: 0, startup_dropped: 1 }])
  .quality_warnings.some(x => x.includes('startup sample drops')));
assert(startupSummary(finishStartup([startupRow(1000, 0), startupRow(1000, 1)]))
  .quality_warnings.includes('non-increasing sample timestamps'));

const host = '100.113.2.60', port = 12780, localPort = 49001;
const stages = [{ event: 'config' }, { event: 'clock_anchor', mono_usec: 0, unix_usec: 1000000, read_span_usec: 0 },
  { event: 'endpoint', local_port: localPort },
  { event: 'frame', mono_usec: 500000, wall_gap_usec: 400000, engine_delta_usec: 16000, focused: true },
  { event: 'network_loop', start_usec: 110000, end_usec: 490000, forward_usec: 0,
    rollback_usec: 350000, prepare_usec: 10000, simulate_usec: 330000, record_usec: 10000 },
  { event: 'complete', dropped: 0 }];
stages.at(-1).records = stages.length - 1;
const meta = { complete: true, kernel_dropped: 0, packet_cap_reached: false, host, port };
const decoded = packetSummaries([0, .15, .25, .35, .6].map(t =>
  `${(1 + t).toFixed(6)} IP ${host}.${port} > 100.10.10.10.${localPort}: UDP, length 120`).join('\n'));
assert.equal(decoded.packets.length, 5);
assert.equal(decoded.unsupported, 0);
let report = analyze(stages, decoded, meta, host, port);
assert.equal(report.largest_gaps[0].evidence, 'packets_observed_while_client_callbacks_stalled');
assert.equal(report.largest_gaps[0].received_packets_during_gap, 3);
assert.equal(report.largest_gaps[0].largest_overlapping_loop_ms, 380);
assert.equal(report.stages.phases_ms.simulate.max, 330);
for (const metadata of [null, { ...meta, kernel_dropped: 1 }, { ...meta, packet_cap_reached: true }]) {
  assert.equal(analyze(stages, decoded, metadata, host, port).largest_gaps[0].evidence, 'incomplete_or_uncertain_coverage');
}
const sibling = { packets: decoded.packets.map(p => ({ ...p, dst_port: 49002 })), unsupported: 0 };
assert.equal(analyze(stages, sibling, meta, host, port).received_packets, 0);
assert.throws(() => analyze(stages.filter(r => r.event !== 'endpoint'), decoded, meta, host, port), /endpoint/);
const steppedClock = [...stages.slice(0, -1), { event: 'clock_anchor', mono_usec: 600000,
  unix_usec: 1700000, read_span_usec: 0 }, stages.at(-1)];
assert(analyze(steppedClock, decoded, meta, host, port).quality_warnings.some(x => x.includes('clock offset')));
assert.equal(packetSummaries('1.0 IP6 ::1.123 > ::1.456: UDP, length 10').packets.length, 1);
assert.equal(packetSummaries('truncated packet').unsupported, 1);
assert.throws(() => captureOptions({ interface: 'lo0', host: 'any; echo unsafe', port: '1', out: '/tmp/x' }));
assert.throws(() => captureOptions({ interface: 'lo0', host: '127.0.0.1', port: '1', seconds: '301', out: '/tmp/x' }));

const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'car-fight-packet-test-'));
try {
  // A real Ethernet/IPv4/UDP PCAP exercises the installed decoder without BPF access.
  const header = Buffer.alloc(24);
  header.writeUInt32LE(0xa1b2c3d4, 0);
  header.writeUInt16LE(2, 4); header.writeUInt16LE(4, 6);
  header.writeUInt32LE(96, 16); header.writeUInt32LE(1, 20);
  const packet = Buffer.alloc(96);
  packet.writeUInt16BE(0x0800, 12);
  packet[14] = 0x45; packet.writeUInt16BE(286, 16); packet[22] = 64; packet[23] = 17;
  Buffer.from([100, 113, 2, 60, 100, 10, 10, 10]).copy(packet, 26);
  packet.writeUInt16BE(port, 34); packet.writeUInt16BE(localPort, 36); packet.writeUInt16BE(266, 38);
  const chunks = [header];
  for (const micros of [0, 150000, 250000, 350000, 600000]) {
    const row = Buffer.alloc(16);
    row.writeUInt32LE(1, 0); row.writeUInt32LE(micros, 4);
    row.writeUInt32LE(packet.length, 8); row.writeUInt32LE(300, 12);
    chunks.push(row, packet);
  }
  const pcapPath = path.join(temp, 'fixture.pcap');
  fs.writeFileSync(pcapPath, Buffer.concat(chunks));
  const dump = spawnSync('/usr/sbin/tcpdump', ['-tt', '-nn', '-q', '-r', pcapPath], { encoding: 'utf8' });
  assert.equal(dump.status, 0, dump.stderr);
  assert.equal(packetSummaries(dump.stdout).packets.length, 5);
  fs.writeFileSync(path.join(temp, 'stages.jsonl'), stages.map(r => JSON.stringify(r)).join('\n'));
  fs.writeFileSync(path.join(temp, 'capture.json'), JSON.stringify(meta));
  const cli = spawnSync(process.execPath, [fileURLToPath(new URL('./network_diagnostics_report.mjs', import.meta.url)),
    '--stages', path.join(temp, 'stages.jsonl'), '--pcap', pcapPath,
    '--capture-meta', path.join(temp, 'capture.json'), '--host', host, '--port', String(port)], { encoding: 'utf8' });
  assert.equal(cli.status, 0, cli.stderr);
  assert.equal(JSON.parse(cli.stdout).largest_gaps[0].received_packets_during_gap, 3);
  const mock = path.join(temp, 'tcpdump');
  fs.writeFileSync(mock, `#!${process.execPath}\n
process.stderr.write('listening on lo0\\n');
process.stdout.write(Buffer.alloc(24));
process.on('SIGINT', () => { process.stderr.write('5 packets captured\\n0 packets dropped by kernel\\n'); process.exit(0); });
setInterval(() => {}, 1000);
`, { mode: 0o700 });
  const options = captureOptions({ interface: 'lo0', host: '127.0.0.1', port: '12345', seconds: '1', out: path.join(temp, 'success') });
  const result = await capture(options, mock);
  assert.equal(result.complete, true);
  assert.equal(result.kernel_dropped, 0);
  assert.equal(result.captured, 5);
  await assert.rejects(capture(options, mock), /EEXIST/);
  const failure = await capture({ ...options, out: path.join(temp, 'failure') }, path.join(temp, 'missing'));
  assert.equal(failure.complete, false);
  assert(failure.result.error);
  const interrupted = capture({ ...options, seconds: 10, out: path.join(temp, 'interrupt') }, mock);
  setTimeout(() => process.kill(process.pid, 'SIGTERM'), 300);
  assert.equal((await interrupted).complete, true);
  assert.equal(process.listenerCount('SIGTERM'), 0);
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}
console.log('NETWORK_DIAGNOSTICS_TEST PASS correlation, sibling isolation, clock/capture gaps, bounded capture and cleanup');
