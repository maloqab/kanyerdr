// worlds: every space wears one of four worlds.
//  - no props:        the switcher. Deals each space a world (shared "worlds.assign"),
//                     switches to the focused space's world, and labels its terminals
//                     kanyerdr.world=<world> so launchers (Claude Code) can match it.
//  - {part: "tl"...}: a piece of the shown world's frame (corners, edges).
import { View, div, image } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { focused, spaces, panes, machines, shared, setShared, run, layouts, props, hc } from "herdr";
import { reconcile, labelPlan, readyMachines, switchTarget } from "./assign.js";

const ART = "mods/worlds/art/";
const GOLD = "#eabf4a", GOLD_DARK = "#c98a22";
const RETRY_MS = 30000; // a terminal that couldn't be labelled waits this long before another try

// Module scope: every world layout has its own copy of the switcher, and a layout
// switch makes a new one. These must survive that, so they live here.
const labelled = {}; // terminal -> world, labels known to be applied
const pending = {};  // terminal -> world, a label call in flight
const failed = {};   // terminal -> time of the last failed try
let lastKey = null;  // "<focused space>:<its world>" at the last look

export default class Worlds extends View {
  init(_props, cx) {
    this.part = props()?.part ?? null;
  }

  render(cx) {
    return this.part === null ? this.switcher() : this.framePiece(this.part);
  }

  switcher() {
    const list = spaces();
    const ready = readyMachines(machines());
    const current = shared("worlds.assign") ?? {};
    const { assign, changed } = reconcile(current, list.map((s) => s.id), ready);
    if (changed) setShared("worlds.assign", assign);

    // Switch when the focused space (or its world) changes, and only between the
    // four worlds: a layout picked by hand stays until you move to another space.
    const f = focused();
    const next = switchTarget(lastKey, f?.space ?? null, assign, shared("layout"), layouts());
    lastKey = next.key;
    if (next.target) run("layout.switch", { name: next.target });

    this.label(list, assign);
    return div().id("worlds").size_full();
  }

  // Label every terminal with its space's world. A failure (say, the machine went
  // offline) is retried on a later render, at most once per RETRY_MS, and never notified.
  label(list, assign) {
    const spaceOfTab = {};
    for (const s of list) for (const t of s.tabs) spaceOfTab[t.id] = s.id;
    const paneList = panes().map((p) => ({ space: spaceOfTab[p.tab], terminal: p.terminal }));
    const now = Date.now();
    for (const { terminal, world } of labelPlan(paneList, assign, labelled)) {
      if (pending[terminal] === world) continue;
      if (now - (failed[terminal] ?? 0) < RETRY_MS) continue;
      pending[terminal] = world;
      const done = (ok) => {
        if (pending[terminal] === world) delete pending[terminal];
        if (ok) { labelled[terminal] = world; delete failed[terminal]; }
        else failed[terminal] = Date.now();
      };
      hc(["label", terminal, `kanyerdr.world=${world}`]).then((r) => done(r.code === 0), () => done(false));
    }
  }

  // Study Hall's frame: bars are 4 px gold at 18 px from the outer edge and 1 px darker gold at 27 px,
  // the same as in the corner and ornament artwork, so the pieces join seamlessly.
  framePiece(part) {
    const world = shared("layout");
    if (world === "launch-pad") return div().id(`frame-${part}`).size_full();   // the sky shows through
    if (world === "the-palace") return this.giltPiece(part);
    if (world === "cold-room") return this.coldPiece(part);                    // a plain gilt picture frame
    const hBars = (flip) => v_flex().flex_1().h_full().children(flip
      ? [div().h(16), div().h(1).bg(GOLD_DARK), div().h(5), div().h(4).bg(GOLD)]
      : [div().h(18), div().h(4).bg(GOLD), div().h(5), div().h(1).bg(GOLD_DARK)]);
    const vBars = (flip) => h_flex().w_full().flex_1().children(flip
      ? [div().w(16).h_full(), div().w(1).h_full().bg(GOLD_DARK), div().w(5).h_full(), div().w(4).h_full().bg(GOLD)]
      : [div().w(18).h_full(), div().w(4).h_full().bg(GOLD), div().w(5).h_full(), div().w(1).h_full().bg(GOLD_DARK)]);
    switch (part) {
      case "tl": case "tr": case "bl": case "br":
        return div().id(`frame-${part}`).size_full().child(image(`${ART}corner-${part}.svg`).size(44));
      case "top": case "bottom":
        return h_flex().id(`frame-${part}`).size_full()
          .child(hBars(part === "bottom")).child(image(`${ART}edge-${part}.svg`).w(160).h(44).flex_none()).child(hBars(part === "bottom"));
      case "left": case "right":
        return v_flex().id(`frame-${part}`).size_full()
          .child(vBars(part === "right")).child(image(`${ART}edge-${part}.svg`).w(44).h(120).flex_none()).child(vBars(part === "right"));
      default:
        return div();
    }
  }

  // The Palace: a plain gilt band in the same 44 px as Study Hall's ornaments, so the terminal never moves.
  // From the outer edge: 32 px of red, then a 12 px band (2 px highlight, 9 px gilt, 1 px shade) touching the terminal.
  giltPiece(part) {
    const OUT = 32, IN = 0;
    const band = (vertical, inward) => {
      const layers = [["#fbcf8d", 2], ["#efa74f", 9], ["#b97a2a", 1]];
      const ordered = inward ? layers : [...layers].reverse();
      return (vertical ? h_flex().h_full() : v_flex().w_full()).flex_none().children(
        ordered.map(([c, n]) => (vertical ? div().w(n).h_full() : div().h(n).w_full()).bg(c)));
    };
    const strip = (vertical, outerFirst) => {
      const kids = [vertical ? div().w(OUT).h_full() : div().h(OUT).w_full(), band(vertical, outerFirst), vertical ? div().w(IN).h_full() : div().h(IN).w_full()];
      return (vertical ? h_flex() : v_flex()).id(`gilt-${part}`).size_full().children(outerFirst ? kids : kids.reverse());
    };
    switch (part) {
      case "top": return strip(false, true);
      case "bottom": return strip(false, false);
      case "left": return strip(true, true);
      case "right": return strip(true, false);
      default: {
        // a corner: the two bands meet in an L on the terminal-facing side
        const top = part[0] === "t", left = part[1] === "l";
        const rowBand = h_flex().h(12).w_full().flex_none().children(left
          ? [div().w(OUT).h_full(), div().flex_1().h_full().bg("#efa74f")]
          : [div().flex_1().h_full().bg("#efa74f"), div().w(OUT).h_full()]);
        const colBand = h_flex().flex_1().w_full().children(left
          ? [div().w(OUT).h_full(), div().w(12).h_full().bg("#efa74f"), div().flex_1()]
          : [div().flex_1(), div().w(12).h_full().bg("#efa74f"), div().w(OUT).h_full()]);
        const kids = [div().h(OUT).w_full().flex_none(), rowBand, colBand];
        return v_flex().id(`gilt-${part}`).size_full().children(top ? kids : [colBand, rowBand, div().h(OUT).w_full().flex_none()]);
      }
    }
  }


  // Cold Room: a flat field and one quiet detail, a column of pastel swatches down the left rail.
  coldPiece(part) {
    if (part !== "left") return div().id(`cold-${part}`).size_full();
    const SW = ["#d1dfdc", "#a3c0b7", "#f6c7b8", "#b0938c", "#b8bebd", "#a9c4d6", "#e8d9a8", "#cdcec7"];
    return h_flex().id("cold-left").size_full().child(div().w(22).h_full()).child(
      v_flex().w(10).h_full().children(SW.map((c) => div().flex_1().w_full().bg(c))));
  }

}
