import { test } from "node:test";
import assert from "node:assert/strict";
import { readyMachines, switchTarget, reconcile } from "../kanyerdr/mods/worlds/assign.js";

const ALL = ["main", "study-hall", "the-palace", "launch-pad", "cold-room"];

test("readyMachines: this computer counts only once its layout is ready", () => {
  assert.deepEqual(readyMachines([{ name: null, layout: "loading" }, { name: "box", layout: "ready" }]), ["box"]);
  assert.deepEqual(readyMachines([{ name: null, layout: "ready" }, { name: "box", layout: "unavailable" }]), [null]);
});

test("readyMachines: this computer is ready when machines() doesn't list it", () => {
  assert.deepEqual(readyMachines([{ name: "box", layout: "ready" }]), [null, "box"]);
});

test("reconcile keeps local picks while this computer is still loading", () => {
  const ready = readyMachines([{ name: null, layout: "loading" }]);
  assert.deepEqual(reconcile({ a: "cold-room" }, [], ready).assign, { a: "cold-room" });
});

test("switchTarget switches when the focused space changes", () => {
  const r = switchTarget(null, "b", { a: "study-hall", b: "cold-room" }, "study-hall", ALL);
  assert.equal(r.target, "cold-room");
});

test("switchTarget leaves a world picked by hand while the space stays the same", () => {
  const first = switchTarget(null, "a", { a: "study-hall" }, "study-hall", ALL);
  assert.equal(first.target, null);
  // ctrl-shift-l moves to cold-room; same space, same world: stay.
  assert.equal(switchTarget(first.key, "a", { a: "study-hall" }, "cold-room", ALL).target, null);
});

test("switchTarget switches when the space's world is changed (World menu)", () => {
  const first = switchTarget(null, "a", { a: "study-hall" }, "study-hall", ALL);
  assert.equal(switchTarget(first.key, "a", { a: "cold-room" }, "study-hall", ALL).target, "cold-room");
});

test("switchTarget never leaves a layout that isn't a world", () => {
  assert.equal(switchTarget(null, "b", { b: "cold-room" }, "main", ALL).target, null);
});

test("switchTarget doesn't switch to a layout that isn't installed", () => {
  assert.equal(switchTarget(null, "b", { b: "cold-room" }, "study-hall", ["study-hall"]).target, null);
});

test("switchTarget with no focused space does nothing", () => {
  assert.equal(switchTarget(null, null, {}, "study-hall", ALL).target, null);
});
