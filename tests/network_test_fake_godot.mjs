#!/usr/bin/env node
// Process-only fixture for the real network_test.sh orchestration. No sockets or game simulation.
import { appendFileSync } from 'node:fs';

const args = process.argv.slice(2);
const value = (flag) => args[args.indexOf(flag) + 1];
const scenario = process.env.CAR_FIGHT_HARNESS_CASE;
appendFileSync(process.env.CAR_FIGHT_HARNESS_PID_LOG, `${process.pid}\n`);
process.on('SIGTERM', () => process.exit(0));

if (args.includes('--server')) {
  setTimeout(() => {
    console.log('[car-fight:server] RESULT players=2 minpair=2.5 contact=1 escapes=1');
    process.exit(0);
  }, 2200);
} else if (args.includes('--proxy')) {
  console.log(`[proxy] latency=${value('--latency')}ms jitter=+/-${value('--jitter')}ms loss=${Number(value('--loss')).toFixed(2)}% seed=${value('--shape-seed')}`);
  console.log('[proxy-stats] recv=100/100 fwd=100/100 drop=0/0 reorder=0/0 queue=0/0 high=0/0 clients=2');
  setInterval(() => {}, 1000);
} else {
  console.log('[car-fight:client] CLIENT_READY id=2');
  console.log('[car-fight:client] CLIENT_TICK tick=60 players=2 world=2:0,0|3:1,1 ');
  console.log('[car-fight:client] CORRECTION tick=60 error=1.0');
  if (scenario === 'hang' && value('--name') === 'alpha') {
    setInterval(() => {}, 1000);
  } else {
    setTimeout(() => {
      if (scenario === 'bad-exit' && value('--name') === 'alpha') process.exit(3);
      console.log('[car-fight:client] CLIENT_STOPPED');
      if (scenario === 'late-error' && value('--name') === 'alpha') {
        console.error("ERROR: The multiplayer instance isn't currently active.");
      }
      process.exit(2);
    }, 2200);
  }
}
