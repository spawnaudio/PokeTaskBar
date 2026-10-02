export const POTIONS = [
  { id: 'potion', name: 'Potion', minutes: 5, price: 100 },
  { id: 'super-potion', name: 'Super Potion', minutes: 15, price: 300 },
  { id: 'hyper-potion', name: 'Hyper Potion', minutes: 30, price: 600 },
  { id: 'revive', name: 'Revive', minutes: 60, price: 1200 },
  { id: 'full-restore', name: 'Full Restore', minutes: null, price: 3600 },
];

export function initial(scenario = 'Idle') {
  const phase = scenario === 'Idle' ? 'idle' : scenario === 'Paused' ? 'paused' : scenario === 'Zero HP' || scenario === 'Empty bag' ? 'zero' : 'running';
  return { phase, planned: scenario === 'At time limit' ? 180 * 60 : 25 * 60,
    remaining: phase === 'zero' ? 0 : scenario === 'At time limit' ? 60 : 17 * 60 + 32,
    xp: 620000000, threshold: 1000000000, coins: 12000, opponent: 0,
    bag: Object.fromEntries(POTIONS.map((p, i) => [p.id, scenario === 'Empty bag' ? 0 : [3, 2, 1, 1, 1][i]])),
    failCompletion: scenario === 'Completion failed' };
}
export function start(s, minutes, opponent) {
  return { ...s, phase: 'running', planned: minutes * 60, remaining: minutes * 60, opponent };
}
export function advance(s, seconds) {
  if (s.phase !== 'running') return s;
  const remaining = Math.max(0, s.remaining - Math.max(0, seconds));
  return { ...s, remaining, phase: remaining === 0 ? 'zero' : 'running' };
}
export function addPotion(s, id, customMinutes) {
  const item = POTIONS.find(p => p.id === id);
  const minutes = item?.minutes ?? customMinutes;
  if (!item || s.phase === 'idle') return { error: 'Start a timer first.' };
  if (s.bag[id] < 1) return { error: 'This item is not in your bag.' };
  if (!Number.isInteger(minutes) || minutes < 1) return { error: 'Enter whole extra minutes above zero.' };
  if (s.planned + minutes * 60 > 10800) return { error: 'Full boost exceeds the 180-minute limit.' };
  return { minutes, state: { ...s, phase: s.phase === 'paused' ? 'paused' : 'running',
    planned: s.planned + minutes * 60, remaining: s.remaining + minutes * 60,
    bag: { ...s.bag, [id]: s.bag[id] - 1 } } };
}
// Demo local-task reward uses the current 10-minute / 1M XP cadence. Native code owns real settlement.
export function reward(s) { return Math.floor((s.planned - s.remaining) / 600) * 1000000; }
export function finish(s, forfeited) {
  if (s.phase === 'idle') return s;
  return { ...s, phase: 'idle', remaining: 0, xp: s.xp + (forfeited ? 0 : reward(s)) };
}
export function buy(s, id) {
  const item = POTIONS.find(p => p.id === id);
  if (!item || s.coins < item.price) return { error: 'Not enough Coins.' };
  return { state: { ...s, coins: s.coins - item.price, bag: { ...s.bag, [id]: s.bag[id] + 1 } } };
}
export function clock(seconds) {
  const n = Math.max(0, Math.ceil(seconds));
  return `${Math.floor(n / 60)}:${String(n % 60).padStart(2, '0')}`;
}
