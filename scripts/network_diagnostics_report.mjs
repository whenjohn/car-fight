import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { parseArgs } from 'node:util';
import { pathToFileURL } from 'node:url';

export function jsonLines(file) {
  return fs.readFileSync(file, 'utf8').split('\n').filter(line => line.trim()).map(JSON.parse);
}

export function distribution(values) {
  const a = values.filter(Number.isFinite).sort((a, b) => a - b);
  const q = p => a.length ? a[Math.floor((a.length - 1) * p)] : null;
  return { count: a.length, median: q(.5), p95: q(.95), max: q(1) };
}

// tcpdump decodes the PCAP/link/IP layers; only its numeric UDP summary is parsed here.
export function packetSummaries(text) {
  const packets = [];
  let unsupported = 0;
  for (const line of text.split('\n').filter(line => line.trim())) {
    const m = line.match(/^(\d+\.\d+) IP6? (\S+)\.(\d+) > (\S+)\.(\d+): UDP, length (\d+)$/);
    if (!m) { unsupported++; continue; }
    packets.push({ unix_usec: Math.round(Number(m[1]) * 1e6), src: m[2], src_port: Number(m[3]),
      dst: m[4], dst_port: Number(m[5]), udp_bytes: Number(m[6]) });
  }
  return { packets, unsupported };
}

export function stageSummary(records) {
  const loops = records.filter(r => r.event === 'network_loop');
  const complete = records.at(-1)?.event === 'complete' ? records.at(-1) : null;
  const publications = records.filter(r => r.event === 'publication_queued');
  const byRecipient = {};
  for (const p of publications) (byRecipient[p.recipient] ??= []).push(p);
  return { complete: Boolean(complete) && complete.records === records.length - 1,
    dropped: complete?.dropped ?? null,
    network_ms: distribution(loops.map(r => (r.end_usec - r.start_usec) / 1000)),
    phases_ms: Object.fromEntries(['forward', 'rollback', 'prepare', 'simulate', 'record'].map(
      key => [key, distribution(loops.map(r => r[`${key}_usec`] / 1000))])),
    publication_gaps_ms: Object.fromEntries(Object.entries(byRecipient).map(([peer, rows]) =>
      [peer, distribution(rows.slice(1).map((r, i) => (r.start_usec - rows[i].start_usec) / 1000))])) };
}

export function analyze(stages, decoded, metadata, host, port, clientPort, presentation = []) {
  const anchors = stages.filter(r => r.event === 'clock_anchor');
  if (!anchors.length) throw new Error('No clock anchors; cannot align packet and game timestamps');
  const ports = [...new Set(stages.filter(r => r.event === 'endpoint').map(r => r.local_port))];
  const localPort = clientPort ?? (ports.length === 1 ? ports[0] : null);
  if (!Number.isInteger(localPort) || localPort < 1 || localPort > 65535) {
    throw new Error('Need one recorded ENet endpoint or explicit --client-port; never combine sibling clients');
  }
  const offsets = anchors.map(r => r.unix_usec - r.mono_usec);
  const offsetVariation = Math.max(...offsets) - Math.min(...offsets);
  const mapTime = mono => {
    const nearest = anchors.reduce((a, b) => Math.abs(a.mono_usec - mono) <= Math.abs(b.mono_usec - mono) ? a : b);
    return mono + nearest.unix_usec - nearest.mono_usec;
  };
  const rx = decoded.packets.filter(p => p.src === host && p.src_port === port && p.dst_port === localPort)
    .sort((a, b) => a.unix_usec - b.unix_usec);
  const quality = [];
  if (!metadata?.complete) quality.push('capture incomplete or metadata missing');
  if (metadata && (metadata.host !== host || metadata.port !== port)) quality.push('capture filter differs from requested server');
  if (metadata?.kernel_dropped !== 0) quality.push('capture drops nonzero or unavailable');
  if (metadata?.packet_cap_reached) quality.push('packet cap reached; coverage ended early');
  if (decoded.unsupported) quality.push(`${decoded.unsupported} packet summaries unsupported`);
  if (!rx.length) quality.push('no packets for this endpoint');
  if (offsetVariation > 10000) quality.push('system clock offset changed by more than 10 ms');
  if (anchors.some(r => r.read_span_usec > 10000)) quality.push('clock anchor read delayed more than 10 ms');
  const summary = stageSummary(stages);
  if (!summary.complete || summary.dropped !== 0) quality.push('stage trace incomplete or dropped records');
  const loops = stages.filter(r => r.event === 'network_loop');
  const gaps = stages.filter(r => r.event === 'frame' && r.wall_gap_usec >= 50000);
  const gapRows = [...gaps].sort((a, b) => b.wall_gap_usec - a.wall_gap_usec).slice(0, 20).map(gap => {
    const begin = gap.mono_usec - gap.wall_gap_usec, end = gap.mono_usec;
    const beginUnix = mapTime(begin), endUnix = mapTime(end);
    const inside = rx.filter(p => p.unix_usec > beginUnix + 2000 && p.unix_usec < endUnix - 2000);
    const covered = rx.length && beginUnix >= rx[0].unix_usec && endUnix <= rx.at(-1).unix_usec;
    const overlapping = loops.filter(r => r.end_usec > begin && r.start_usec < end);
    const bodyModes = {};
    for (const r of presentation) for (const b of r.bodies ?? []) {
      if (b.at_msec * 1000 >= begin && b.at_msec * 1000 <= end) bodyModes[b.mode] = (bodyModes[b.mode] ?? 0) + 1;
    }
    return { end_unix_usec: endUnix, wall_ms: gap.wall_gap_usec / 1000,
      engine_ms: gap.engine_delta_usec / 1000, focused: gap.focused,
      received_packets_during_gap: inside.length, body_modes: bodyModes,
      largest_overlapping_loop_ms: distribution(overlapping.map(r => (r.end_usec - r.start_usec) / 1000)).max,
      evidence: quality.length || !covered ? 'incomplete_or_uncertain_coverage' : inside.length >= 3
        ? 'packets_observed_while_client_callbacks_stalled'
        : 'few_packets_observed_not_a_loss_diagnosis' };
  });
  return { client_port: localPort, quality_warnings: quality, clock_offset_variation_usec: offsetVariation,
    stages: summary, received_packets: rx.length,
    receive_spacing_ms: distribution(rx.slice(1).map((r, i) => (r.unix_usec - rx[i].unix_usec) / 1000)),
    frame_gap_count: gaps.length, largest_gaps: gapRows.sort((a, b) => b.wall_ms - a.wall_ms).slice(0, 20),
    limitations: ['Packet capture timestamps are approximate OS observations, not NIC hardware times.',
      'No datagram-to-RPC matching: exact arrival-to-processing delay and network loss are not measured.',
      'Same-host anchors do not establish clock synchronization between client and server.',
      'Phase durations overlap and include descheduling; these are not CPU samples.'] };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    const { values: v } = parseArgs({ options: Object.fromEntries(
      ['stages', 'pcap', 'capture-meta', 'host', 'port', 'client-port', 'presentation', 'server-stages']
        .map(key => [key, { type: 'string' }])) });
    if (!v.stages || !v.pcap || !v.host || !v.port) throw new Error('Required: --stages FILE --pcap FILE --host IP --port PORT');
    const dump = spawnSync('/usr/sbin/tcpdump', ['-tt', '-nn', '-q', '-r', v.pcap],
      { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
    if (dump.status !== 0) throw new Error(dump.error?.message ?? dump.stderr);
    const metadata = v['capture-meta'] ? JSON.parse(fs.readFileSync(v['capture-meta'], 'utf8')) : null;
    const result = analyze(jsonLines(v.stages), packetSummaries(dump.stdout), metadata, v.host,
      Number(v.port), v['client-port'] ? Number(v['client-port']) : undefined,
      v.presentation ? jsonLines(v.presentation) : []);
    if (v['server-stages']) result.server = stageSummary(jsonLines(v['server-stages']));
    console.log(JSON.stringify(result, null, 2));
    if (result.quality_warnings.length) process.exitCode = 2;
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
