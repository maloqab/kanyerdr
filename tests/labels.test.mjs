import { test } from "node:test";
import assert from "node:assert/strict";
import { labelPlan } from "../kanyerdr/mods/worlds/assign.js";

const assign = { a: "cold-room", "m/b": "the-palace" };

test("labels every terminal in an assigned space", () => {
  const panes = [{ space: "a", terminal: "t1" }, { space: "a", terminal: "t2" }];
  assert.deepEqual(labelPlan(panes, assign, {}), [
    { terminal: "t1", world: "cold-room" },
    { terminal: "t2", world: "cold-room" },
  ]);
});

test("skips terminals already labelled with that world", () => {
  const panes = [{ space: "a", terminal: "t1" }, { space: "a", terminal: "t2" }];
  assert.deepEqual(labelPlan(panes, assign, { t1: "cold-room", t2: "cold-room" }), []);
});

test("relabels a terminal whose space changed world", () => {
  const panes = [{ space: "a", terminal: "t1" }];
  assert.deepEqual(labelPlan(panes, assign, { t1: "study-hall" }), [{ terminal: "t1", world: "cold-room" }]);
});

test("skips mod panes (terminal null)", () => {
  assert.deepEqual(labelPlan([{ space: "a", terminal: null }], assign, {}), []);
});

test("skips spaces with no assignment", () => {
  assert.deepEqual(labelPlan([{ space: "zzz", terminal: "t9" }], assign, {}), []);
});

test("remote terminals keep their machine-qualified address", () => {
  assert.deepEqual(labelPlan([{ space: "m/b", terminal: "m/t7" }], assign, {}), [{ terminal: "m/t7", world: "the-palace" }]);
});

test("lists a terminal shown in two panes once", () => {
  const panes = [{ space: "a", terminal: "t1" }, { space: "a", terminal: "t1" }];
  assert.deepEqual(labelPlan(panes, assign, {}), [{ terminal: "t1", world: "cold-room" }]);
});
