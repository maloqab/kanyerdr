// Which world each space wears. Pure functions, no Herdr imports, so they
// can be tested with plain Node.
//
// The assignment map is { [spaceId]: worldId }. Remote space ids look like
// "<machine>/sp…"; local ones have no prefix.

export const WORLDS = ["study-hall", "the-palace", "launch-pad", "cold-room"];

/** The machine a space lives on, or null for this computer. */
export function machineOf(spaceId) {
  const i = spaceId.indexOf("/");
  return i < 0 ? null : spaceId.slice(0, i);
}

/** The world fewest spaces wear; ties go to the earliest in WORLDS. */
export function leastUsed(assign) {
  const count = Object.fromEntries(WORLDS.map((w) => [w, 0]));
  for (const w of Object.values(assign)) if (w in count) count[w]++;
  let best = WORLDS[0];
  for (const w of WORLDS) if (count[w] < count[best]) best = w;
  return best;
}

/**
 * Bring the map in line with the spaces that exist now.
 * - A space that is gone is forgotten, but only when its machine is ready:
 *   an offline machine's spaces drop out of spaces() and must keep their world.
 * - A value that is not a world is dealt again.
 * - A new space is dealt the least-used world, in spaceIds order.
 * Returns a new map; the input is never changed.
 */
export function reconcile(assign, spaceIds, readyMachines) {
  const present = new Set(spaceIds);
  const ready = new Set(readyMachines);
  const next = {};
  let changed = false;
  for (const [id, w] of Object.entries(assign)) {
    const gone = !present.has(id) && ready.has(machineOf(id));
    if (gone || !WORLDS.includes(w)) changed = true;
    else next[id] = w;
  }
  for (const id of spaceIds) {
    if (!(id in next)) {
      next[id] = leastUsed(next);
      changed = true;
    }
  }
  return { assign: next, changed };
}

/**
 * Which terminals need the label kanyerdr.world=<world>.
 * paneList: [{ space, terminal }] (terminal is null for mod panes).
 * labelled: { [terminal]: world } already applied, as remembered in memory.
 * Each terminal appears at most once.
 */
export function labelPlan(paneList, assign, labelled) {
  const plan = [];
  const seen = new Set();
  for (const { space, terminal } of paneList) {
    const world = assign[space];
    if (!terminal || !world || seen.has(terminal)) continue;
    seen.add(terminal);
    if (labelled[terminal] !== world) plan.push({ terminal, world });
  }
  return plan;
}

/**
 * The machines whose spaces can be trusted to be complete: those whose layout is
 * "ready". This computer is null; if machines() doesn't list it, it counts as ready.
 */
export function readyMachines(machineList) {
  const ready = machineList.filter((m) => m.layout === "ready").map((m) => m.name);
  if (!machineList.some((m) => m.name === null)) ready.unshift(null);
  return ready;
}

/**
 * Whether to switch layouts now. Switch only when the focused space, or its world,
 * changed since the last call (lastKey), so a world picked by hand stays put until
 * the person moves to another space. Never leave a layout that isn't a world.
 * Returns { target: world | null, key } — pass key back in next time.
 */
export function switchTarget(lastKey, focusedSpace, assign, shown, available) {
  const world = focusedSpace ? assign[focusedSpace] ?? null : null;
  const key = focusedSpace ? `${focusedSpace}:${world}` : null;
  const moved = key !== null && key !== lastKey;
  const target = moved && world && WORLDS.includes(shown) && world !== shown && available.includes(world) ? world : null;
  return { target, key };
}
