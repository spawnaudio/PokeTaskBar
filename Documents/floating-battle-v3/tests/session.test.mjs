import assert from 'node:assert/strict';
import { initial, start, advance, addPotion, finish, buy, POTIONS } from '../src/session.js';

// Walk the real flow, checking valuable failure branches as well as the happy path.
let s = start(initial(), 25, 0);
s = advance(s, 1500);
assert.equal(s.phase, 'zero');
const baselineXP = s.xp;
const restored = addPotion(s, 'hyper-potion');
assert.equal(restored.state.remaining, 1800);
assert.equal(restored.state.planned, 3300);
assert.equal(restored.state.bag['hyper-potion'], 0);
assert.equal(restored.state.xp, baselineXP);
assert.equal(restored.state.phase, 'running');
assert(addPotion(restored.state, 'hyper-potion').error, 'An empty bag must not add time.');
assert.equal(finish(restored.state, true).xp, baselineXP, 'Forfeit grants no timer XP.');
const rested = finish(s, false);
assert(rested.xp > baselineXP, 'Rest settles completed demo time.');
assert.equal(finish(rested, false).xp, rested.xp, 'Finish settles only once.');

let paused = initial('Paused');
for (const item of POTIONS) {
  const result = addPotion(paused, item.id, 20);
  assert.equal(result.state.phase, 'paused', `${item.name} must preserve pause.`);
  assert.equal(result.state.remaining - paused.remaining, (item.minutes ?? 20) * 60);
  assert.equal(advance(result.state, 600).remaining, result.state.remaining);
}
assert(addPotion(initial(), 'potion').error);
assert(addPotion(initial('Empty bag'), 'potion').error);
assert(addPotion(initial('At time limit'), 'potion').error);
const nearLimit = { ...paused, planned: 178 * 60 };
assert(addPotion(nearLimit, 'potion').error, 'A partially fitting boost must not consume an item.');
assert.equal(nearLimit.bag.potion, 3);
for (const bad of [0, -1, 1.5, NaN, Infinity, 181]) assert(addPotion(paused, 'full-restore', bad).error);
const purchase = buy(initial('Empty bag'), 'potion').state;
assert.equal(purchase.bag.potion, 1);
assert.equal(purchase.coins, 11900);
assert(buy({ ...purchase, coins: 0 }, 'full-restore').error);
console.log('Session flow passed: expiry, all five potions, paused use, custom validation, full-effect cap, purchase, Rest and Forfeit.');
