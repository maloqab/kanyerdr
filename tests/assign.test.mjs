import { test } from "node:test";
import assert from "node:assert/strict";
import { WORLDS, machineOf, leastUsed, reconcile } from "../kanyerdr/mods/worlds/assign.js";

test("WORLDS are in the fixed order", () => {
  assert.deepEqual(WORLDS, ["study-hall", "the-palace", "launch-pad", "cold-room"]);
});

test("machineOf splits remote ids and returns null for local ones", () => {
  assert.equal(machineOf("box/sp1"), "box");
  assert.equal(machineOf("sp1"), null);
});

test("leastUsed picks the emptiest world, ties in WORLDS order", () => {
  assert.equal(leastUsed({}), "study-hall");
  assert.equal(leastUsed({ a: "study-hall" }), "the-palace");
  assert.equal(leastUsed({ a: "study-hall", b: "the-palace", c: "launch-pad", d: "cold-room" }), "study-hall");
});

test("reconcile deals new spaces in order", () => {
  const r = reconcile({}, ["a", "b", "c", "d", "e"], [null]);
  assert.deepEqual(r.assign, { a: "study-hall", b: "the-palace", c: "launch-pad", d: "cold-room", e: "study-hall" });
  assert.equal(r.changed, true);
});

test("reconcile is stable when nothing changed", () => {
  const prev = reconcile({}, ["a", "b", "c"], [null]).assign;
  const r = reconcile(prev, ["a", "b", "c"], [null]);
  assert.deepEqual(r.assign, prev);
  assert.equal(r.changed, false);
});

test("reconcile prunes gone spaces on ready machines", () => {
  const r = reconcile({ a: "cold-room" }, [], [null]);
  assert.deepEqual(r.assign, {});
  assert.equal(r.changed, true);
});

test("reconcile keeps spaces of a machine that is not ready (offline)", () => {
  const r = reconcile({ "m/x": "cold-room" }, [], [null]);
  assert.deepEqual(r.assign, { "m/x": "cold-room" });
  assert.equal(r.changed, false);
});

test("reconcile prunes a gone remote space when its machine is ready", () => {
  const r = reconcile({ "m/x": "cold-room" }, [], [null, "m"]);
  assert.deepEqual(r.assign, {});
});

test("reconcile re-deals a value that is not a world", () => {
  const r = reconcile({ a: "main" }, ["a"], [null]);
  assert.deepEqual(r.assign, { a: "study-hall" });
  assert.equal(r.changed, true);
});

test("reconcile keeps a manual pick even if it is not least-used", () => {
  const r = reconcile({ a: "cold-room", b: "cold-room" }, ["a", "b", "c"], [null]);
  assert.deepEqual(r.assign, { a: "cold-room", b: "cold-room", c: "study-hall" });
});

test("reconcile never mutates its input", () => {
  const input = { a: "main", gone: "cold-room" };
  const copy = structuredClone(input);
  reconcile(input, ["a", "b"], [null]);
  assert.deepEqual(input, copy);
});
