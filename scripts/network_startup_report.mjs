import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { jsonLines, distribution, stageSummary } from './network_diagnostics_report.mjs';

const vector = v => Array.isArray(v) && v.length === 3 && v.every(Number.isFinite);
const distance = (a, b) => Math.hypot(...a.map((v, i) => v - b[i]));

export function startupSummary(records) {
  const stages = stageSummary(records);
  const footer = records.at(-1);
  const samples = records.filter(r => r.event === 'startup_sample');
  const quality = [];
  if (!stages.complete || stages.dropped !== 0) quality.push('stage trace incomplete or dropped records');
  if (footer?.startup_dropped !== 0) quality.push('startup sample drops nonzero or unavailable');
  if (!samples.length) quality.push('no startup body samples');
  const groups = new Map(), returns = [], backwards = [];
  for (const row of samples) {
    if (!vector(row.physics?.position)) { quality.push('invalid or unavailable physics pose'); continue; }
    const key = JSON.stringify([row.epoch, row.body_id, row.instance_id, row.generation]);
    const group = groups.get(key) ?? { first: row, previous: null, count: 0 };
    const prev = group.previous;
    if (prev) {
      const elapsed = (row.mono_usec - prev.mono_usec) / 1000;
      if (elapsed <= 0) quality.push('non-increasing sample timestamps');
      else {
        const p = row.physics.position, before = prev.physics.position;
        const details = { mono_usec: row.mono_usec, elapsed_ms: elapsed, tick: row.tick,
          previous_tick: prev.tick, epoch: row.epoch, body_id: row.body_id,
          generation: row.generation, before_position: before, after_position: p,
          latest_state_tick: row.latest_state_tick, previous_latest_state_tick: prev.latest_state_tick,
          history_at_latest_state: row.history_at_latest_state };
        if (distance(before, group.first.physics.position) >= .25 && distance(p, group.first.physics.position) <= .1) {
          returns.push(details);
        }
        const a = prev.recorded_cursor, b = row.recorded_cursor;
        if (Array.isArray(a) && Array.isArray(b) && a.length === 2 && b.length === 2
            && [...a, ...b].every(Number.isFinite)) {
          const an = Math.hypot(...a), bn = Math.hypot(...b);
          if (an > 0 && bn > 0 && (a[0] * b[0] + a[1] * b[1]) / an / bn > .99) {
            const reverse = -((p[0] - before[0]) * b[0] + (p[2] - before[2]) * b[1]) / bn;
            if (reverse > .1) backwards.push({ ...details, backwards_units: reverse });
          }
        }
      }
    }
    group.previous = row;
    group.count++;
    groups.set(key, group);
  }
  return { quality_warnings: [...new Set(quality)], samples: samples.length,
    identities: groups.size, clock_events: records.filter(r => ['startup_sync', 'startup_panic'].includes(r.event)),
    reference_minus_tick_ms: distribution(samples.filter(r => Number.isFinite(r.reference_seconds) && r.tickrate > 0)
      .map(r => (r.reference_seconds - r.tick / r.tickrate) * 1000)),
    node_physics_distance: distribution(samples.filter(r => vector(r.node_position) && vector(r.physics?.position))
      .map(r => distance(r.node_position, r.physics.position))),
    return_to_first_pose_count: returns.length, return_to_first_pose_candidates: returns.slice(0, 10),
    backwards_step_count: backwards.length,
    largest_backwards_steps: backwards.sort((a, b) => b.backwards_units - a.backwards_units).slice(0, 10),
    limitations: ['First sampled pose is not necessarily the spawn position.',
      'Backward steps/returns are candidates, not proven corrections; collisions and input changes can move a body.',
      'History is sampled mutable simulation history, not a pristine packet or exact state-application event.',
      'Frame samples can miss intra-frame resets; clocks on different hosts are not aligned.'] };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    if (process.argv.length !== 3) throw new Error('Usage: node scripts/network_startup_report.mjs TRACE.jsonl');
    const report = startupSummary(jsonLines(process.argv[2]));
    console.log(JSON.stringify(report, null, 2));
    if (report.quality_warnings.length) process.exitCode = 2;
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
