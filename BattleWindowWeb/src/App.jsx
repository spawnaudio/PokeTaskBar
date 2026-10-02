import { useEffect, useState } from 'react';
import { native, nativeCommand } from './native.js';
import { POTIONS, initial, advance, addPotion, start, finish, buy, clock, reward } from './session.js';

const opponents = [{ name: 'GENGAR', asset: 'gengar' }, { name: 'PIKACHU', asset: 'pikachu' }, { name: 'ODDISH', asset: 'oddish' }];
const scenarios = ['Idle', 'Running', 'Paused', 'Zero HP', 'Empty bag', 'At time limit', 'Completion failed'];
const art = name => native ? new URL(`assets/${name}.png`, document.baseURI).href : `/assets/${name}.png`;

export function App() {
  const [s, set] = useState(initial);
  const [nativeReady, setNativeReady] = useState(!native);
  const [busy, setBusy] = useState(false);
  const potions = native && s.prices ? POTIONS.map(p => ({ ...p, price: s.prices[p.id] })) : POTIONS;
  const [view, show] = useState('battle');
  const [selected, select] = useState('hyper-potion');
  const [minutes, setMinutes] = useState('20');
  const [duration, setDuration] = useState('25');
  const [durationDraft, setDurationDraft] = useState('25');
  const [notice, tell] = useState('');
  const [zoom, setZoom] = useState(1);
  const [smallViewport, setSmallViewport] = useState(false);
  const actualZoom = smallViewport ? 1 : zoom;
  const [longTitle, setLongTitle] = useState(false);
  const [scenario, setScenario] = useState('Idle');
  const item = potions.find(p => p.id === selected);
  const active = s.phase !== 'idle';
  const zero = s.phase === 'zero';
  const paused = s.phase === 'paused';
  const bagEmpty = Object.values(s.bag).every(n => n === 0);
  const expanded = view === 'bag' || view === 'shop';
  const enemy = opponents[s.opponent];
  const task = native ? s.taskTitle : longTitle ? 'Prepare and review the complete studio website launch checklist' : 'Polish the menu bar';
  const hp = active ? Math.max(0, s.remaining / s.planned) * 100 : 0;
  const xp = Math.round(s.xp / s.threshold * 100);
  const canUse = p => active && s.bag[p.id] > 0 && (p.minutes ? s.planned + p.minutes * 60 <= 10800 : s.planned < 10800);

  useEffect(() => {
    if (native) {
      const update = e => { set(e.detail); setDuration(String(e.detail.defaultMinutes)); setNativeReady(true); };
      window.addEventListener('poketasks-state', update);
      const openBag = () => { select('potion'); show('bag'); tell(''); };
      window.addEventListener('poketasks-open-bag', openBag);
      nativeCommand('ready');
      return () => { window.removeEventListener('poketasks-state', update); window.removeEventListener('poketasks-open-bag', openBag); };
    }
    let last = Date.now();
    const timer = setInterval(() => {
      const now = Date.now(), delta = (now - last) / 1000;
      last = now;
      set(current => advance(current, delta));
    }, 1000);
    return () => clearInterval(timer);
  }, []);
  useEffect(() => {
    if (native) nativeCommand('layout', { height: expanded || view === 'more' ? 260 : view === 'custom' ? 200 : 180, input: view === 'custom' || view === 'duration' });
  }, [view, expanded]);
  useEffect(() => { if (zero) tell(''); }, [zero]);
  useEffect(() => {
    const media = matchMedia('(max-width: 850px)');
    const fit = () => setSmallViewport(media.matches);
    fit(); media.addEventListener('change', fit);
    return () => media.removeEventListener('change', fit);
  }, []);
  useEffect(() => {
    document.querySelector('.game input, .game .item.selected, .game .commands button:not(:disabled)')?.focus();
    const escape = e => { if (e.key === 'Escape' && view !== 'battle') { tell(''); show(view === 'custom' ? 'bag' : 'battle'); } };
    document.addEventListener('keydown', escape);
    return () => document.removeEventListener('keydown', escape);
  }, [view]);

  async function performNative(action, values = {}) {
    if (busy) return;
    setBusy(true);
    try {
      const result = await nativeCommand(action, values);
      if (result.error) { tell(result.error); return false; }
      return true;
    } finally { setBusy(false); }
  }
  function loadScenario(name) {
    setScenario(name); show('battle'); tell(''); select('hyper-potion'); setMinutes('20'); setDuration('25');
    set(initial(name));
  }
  async function begin() {
    const n = Number(view === 'duration' ? durationDraft : duration);
    if (!Number.isInteger(n) || n < 5 || n > 180) { tell('Choose 5–180 minutes.'); return; }
    if (native) { if (await performNative('start', { minutes: n })) { show('battle'); tell('Your task wants to battle!'); } return; }
    setDuration(String(n)); set(current => start(current, n, Math.floor(Math.random() * opponents.length)));
    show('battle'); tell('Your task wants to battle!');
  }
  async function useItem() {
    if (item.minutes == null && view !== 'custom') { setMinutes('20'); tell(''); show('custom'); return; }
    if (native) { if (await performNative('potion', { item: selected, minutes: Number(minutes) })) { show('battle'); tell(`Used a ${item.name}! +${item.minutes ?? Number(minutes)} min.`); } return; }
    const result = addPotion(s, selected, Number(minutes));
    if (result.error) { tell(result.error); return; }
    set(result.state); show('battle'); tell(`Used a ${item.name}! +${result.minutes} min.`);
  }
  async function rest() {
    if (native) { if (await performNative('rest')) { show('battle'); tell('Task finished!'); } return; }
    if (s.failCompletion) {
      set(current => ({ ...current, failCompletion: false }));
      tell('Could not finish the task. Try again.'); show('failed'); return;
    }
    const gained = reward(s);
    set(current => finish(current, false)); show('battle'); tell(`Task finished! +${gained / 1000000}M XP.`);
  }
  async function forfeit() {
    if (native) { if (await performNative('forfeit')) { show('battle'); tell('Timer forfeited. No session XP earned.'); } return; }
    set(current => finish(current, true)); show('battle'); tell('Timer forfeited. No session XP earned.');
  }
  function togglePause() {
    if (native) { performNative('pause'); tell(''); return; }
    set(current => ({ ...current, phase: current.phase === 'paused' ? 'running' : 'paused' })); tell('');
  }
  function enterBag() { tell(''); select(potions.find(canUse)?.id ?? 'potion'); show('bag'); }
  async function purchase() {
    if (native) { if (await performNative('buy', { item: selected })) tell(`Bought 1 ${item.name}. Added to your bag.`); return; }
    const result = buy(s, selected);
    if (result.error) { tell(result.error); return; }
    set(result.state); tell(`Bought 1 ${item.name}. Added to your bag.`);
  }
  const button = (label, action, disabled = false, primary = false) => <button key={label} type="button" disabled={disabled || busy} className={primary ? 'primary' : ''} onClick={action}><span>{label}</span></button>;
  const commands = (...children) => <nav className="commands" aria-label="Game actions">{children}</nav>;
  const dialogue = text => <div className="dialogue" role="status" aria-live="polite">{text}</div>;
  const goBack = () => { show('battle'); tell(''); };
  const openDuration = () => { setDurationDraft(duration); tell(''); show('duration'); };
  const title = view === 'bag' ? 'POTION BAG' : view === 'shop' ? 'POTION SHOP' : view === 'custom' ? 'FULL RESTORE' : view === 'forfeit' ? 'FORFEIT?' : view === 'duration' ? 'SESSION TIME' : view === 'failed' ? 'TASK NOT FINISHED' : view === 'more' ? 'MORE' : active ? `TASK · ${task}` : 'A new Task wants to Battle!';

  return <main className={`workspace ${native ? 'native' : ''}`} style={native && !nativeReady ? { visibility: 'hidden' } : native ? { '--native-scale': s.scale } : undefined}>
    <header className="page-heading"><div><p className="eyebrow">POKETASKS · V3</p><h1>Floating battle</h1></div><p className="subtitle">Try the session flow at its real window size.</p></header>
    <div className="preview-controls">
      <label>Preview state <select aria-label="Preview state" value={scenario} onChange={e => loadScenario(e.target.value)}>{scenarios.map(name => <option key={name}>{name}</option>)}</select></label>
      <fieldset><legend>Preview size</legend>{[1, 2].map(n => <button key={n} type="button" disabled={n === 2 && smallViewport} aria-pressed={actualZoom === n} onClick={() => setZoom(n)}>{n === 1 ? 'Actual size' : '2× detail'}</button>)}</fieldset>
      <label className="check"><input type="checkbox" checked={longTitle} onChange={e => setLongTitle(e.target.checked)} />Long task title</label>
      <button className="reset" type="button" onClick={() => loadScenario('Idle')}>Reset demo</button>
    </div>
    <section className="desktop" aria-label="Floating window preview">
      <div className="stage" style={{ '--zoom': actualZoom, '--height': expanded ? '260px' : view === 'custom' ? '200px' : '180px' }}>
        <section className={`game ${paused ? 'paused' : ''} ${expanded ? 'expanded' : ''} ${view === 'custom' ? 'custom' : ''} ${native && view === 'more' ? 'native-more' : ''}`} aria-label="Floating battle game" data-phase={s.phase} data-testid="game">
          <header className="game-header"><span className="game-title" title={title}>{title}</span>{view === 'battle' && active && <span className="enemy-name">{(native ? s.opponentName : enemy.name)}</span>}{view === 'shop' && <span className="coins">{s.coins.toLocaleString()} Coins</span>}</header>
          {view === 'battle' ? <>
            <div className={`arena ${notice.startsWith('Used a ') ? 'restored' : ''}`}>
              <img className={`player ${active ? '' : 'trainer'}`} src={native && active ? s.playerImage || art('trainer') : art(active ? 'lapras-back' : 'trainer')} alt={active ? `${native ? s.playerName : 'Lapras'}, your training Pokémon` : 'You, the trainer'} />
              <div className="stats">
                <div className="identity"><strong>{active ? native ? s.playerName : 'LAPRAS' : 'TRAINER'}</strong>{active && <span>{native ? s.stage : 'Lv.18'}</span>}</div>
                <div className="time"><strong data-testid="clock">{clock(active ? s.remaining : Number(duration) * 60)}</strong><span>{active ? `of ${clock(s.planned)}` : 'planned'}</span></div>
                <div className="bar-row"><span className={zero ? 'red' : ''}>HP</span><div className={`bar hp ${zero ? 'empty' : ''}`} role="progressbar" aria-label="Timer HP" aria-valuenow={Math.round(hp)} aria-valuemin="0" aria-valuemax="100"><div style={{ width: `${hp}%`, filter: hp > 50 ? 'none' : hp > 20 ? 'hue-rotate(-60deg)' : 'hue-rotate(-120deg)' }} /></div></div>
                <div className="bar-row"><span>XP</span><div className="bar xp" role="progressbar" aria-label="Companion XP" aria-valuenow={xp} aria-valuemin="0" aria-valuemax="100"><div style={{ width: `${xp}%` }} /></div></div>
              </div>
              {active && <div key={enemy.asset} className="opponent" role="img" aria-label={`${(native ? s.opponentName : enemy.name)}, your task opponent`}><img className="pokemon-frames" src={native ? s.opponentImage || art('trainer') : `/assets/animated/${enemy.asset}.png`} alt="" /></div>}
            </div>
            {dialogue(zero ? <>Time’s Up! Rest, Use a Potion,<br />or Forfeit</> : notice || (paused ? 'Paused. Ready when you are.' : active ? 'Stay focused. Your task is waiting!' : 'Ready when you are.'))}
            {!active ? commands(button('Start timer', begin, false, true), button('Duration', openDuration), button('Rest', rest, true), button('More', () => show('more'))) : zero ? commands(button('Rest', rest, false, true), button('Use a Potion', enterBag), button('Forfeit', () => show('forfeit')), button('More', () => show('more'))) : commands(button(paused ? 'Resume' : 'Pause', togglePause, false, true), button('Use a Potion', enterBag), button('Rest', rest), button('More', () => show('more')))}
          </> : view === 'bag' || view === 'shop' ? <>
            <p className="bag-intro">{view === 'bag' ? bagEmpty ? 'Your potion bag is empty.' : 'Choose an item to restore time.' : 'Buy potions with Coins.'}</p>
            <div className="item-list" role="group" aria-label={view === 'bag' ? 'Owned potions' : 'Shop potions'}>{potions.map(p => <button key={p.id} type="button" className={`item ${selected === p.id ? 'selected' : ''}`} onClick={() => { select(p.id); tell(''); }} aria-pressed={selected === p.id} aria-label={`${p.name}, ${view === 'bag' ? `${s.bag[p.id]} owned, ${p.minutes ? `adds ${p.minutes} minutes` : 'custom time'}` : `${p.price} Coins`}`}><img src={native ? s.itemImages?.[p.id] : art(p.id)} alt="" /><span>{p.name}</span><span className="item-effect">{view === 'bag' ? p.minutes ? `+${p.minutes} min` : 'Custom time' : `${p.price.toLocaleString()}`}</span><span className="quantity">×{s.bag[p.id]}</span></button>)}</div>
            {dialogue(notice || (view === 'shop' ? `${item.name}: ${item.minutes ? `+${item.minutes} min` : 'custom time'}. Uses 1 item.` : bagEmpty ? 'Visit the Shop to stock up.' : !active ? 'Start a timer to use a potion.' : s.bag[selected] === 0 ? 'None left. Visit the Shop to stock up.' : !canUse(item) ? 'Full boost exceeds the 180-minute limit.' : item.minutes ? `Adds ${item.minutes} minutes. Uses 1 ${item.name}.` : 'Choose extra minutes. Uses 1 Full Restore.'))}
            {view === 'shop' ? commands(button('Buy 1', purchase, s.coins < item.price, true), button('Back', () => { tell(''); show(active ? 'bag' : 'battle'); })) : commands(button('Use item', useItem, !canUse(item), true), button('Shop', () => { tell(''); show('shop'); }), button('Back', goBack))}
          </> : view === 'custom' || view === 'duration' ? <>
            <div className="time-form">
              {view === 'custom' && <img src={native ? s.itemImages?.['full-restore'] : art('full-restore')} alt="Full Restore" />}
              <div><label htmlFor="minute-input">{view === 'custom' ? 'How much time would you like to add?' : 'How long is this session?'}</label><div className="minute-input"><input id="minute-input" aria-label={view === 'custom' ? 'Extra minutes' : 'Session minutes'} type="number" step="1" min={view === 'custom' ? 1 : 5} max={view === 'custom' ? Math.floor((10800 - s.planned) / 60) : 180} value={view === 'custom' ? minutes : durationDraft} onChange={e => view === 'custom' ? setMinutes(e.target.value) : setDurationDraft(e.target.value)} /><span>minutes</span></div></div>
            </div>
            {dialogue(notice || (view === 'custom' ? `Adds ${minutes || '…'} minutes. Uses 1 Full Restore.` : 'Choose 5–180 minutes.'))}
            {commands(button(view === 'custom' ? 'Use item' : 'Start timer', view === 'custom' ? useItem : begin, false, true), button('Cancel', () => { tell(''); show(view === 'custom' ? 'bag' : 'battle'); }))}
          </> : view === 'forfeit' ? <>
            <div className="message-screen"><strong>Forfeit this battle?</strong><p>The timer ends and you lose its XP reward.</p><p>Your task stays unfinished.</p></div>
            {dialogue('Previously earned XP stays yours.')}
            {commands(button('Keep going', goBack, false, true), button('Forfeit', forfeit))}
          </> : view === 'failed' ? <>
            <div className="message-screen"><strong>Your task is still here.</strong><p>Completion failed. Your timer and session XP are kept.</p></div>
            {dialogue(notice)}{commands(button('Try again', rest, false, true), button('Back', goBack))}
          </> : <>
            <div className="more-menu">{native && <>{button(s.pinned ? 'Unpin window' : 'Pin window', () => performNative('pin'))}{button('Tuck at screen edge', () => performNative('tuck'))}{button('Open tasks', () => performNative('tasks'))}</>}{active ? button('Forfeit timer', () => show('forfeit')) : button('Session duration', openDuration)}{button('Potion bag', enterBag)}{button('Potion shop', () => { tell(''); show('shop'); })}</div>
            {dialogue(active ? 'One battle at a time.' : 'Ready for your next task?')}{commands(button('Back', goBack, false, true))}
          </>}
        </section>
      </div>
      <p className="size-caption">360 × {expanded ? 260 : view === 'custom' ? 200 : 180} · {actualZoom === 1 ? 'actual size' : 'detail view'}</p>
    </section>
    <footer className="preview-footer"><p>Demo items and Coins only. No task data is changed.</p><p>Start a timer, or choose a preview state to try its controls.</p></footer>
  </main>;
}

window.pokeTasksOpenBag = () => window.dispatchEvent(new Event('poketasks-open-bag'));
