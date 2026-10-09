// The packaged battle window uses the application's existing stores.
export const native = Boolean(window.webkit?.messageHandlers?.battle);
let nextID = 0;
const requests = new Map();
window.pokeTasksReply = ({ id, state, error }) => {
  if (state) window.dispatchEvent(new CustomEvent('poketasks-state', { detail: state }));
  requests.get(id)?.({ state, error });
  requests.delete(id);
};
export function nativeCommand(action, values = {}) {
  return new Promise(resolve => {
    const id = ++nextID;
    requests.set(id, resolve);
    window.webkit.messageHandlers.battle.postMessage({ id, action, ...values });
  });
}
