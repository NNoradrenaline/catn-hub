// node app/core.test.js
const assert = require("assert");
const C = require("./core.js");

assert.strictEqual(C.encodeKey("a.b/c[d]"), "a_b|c_d_");
assert.strictEqual(C.encodeKey(""), "_");

// streaming events
let t = C.applyEvent({}, "/", { a: { x: 1 }, b: 2 }, "put");
t = C.applyEvent(t, "/a/y", 5, "put");
assert.deepStrictEqual(t, { a: { x: 1, y: 5 }, b: 2 });
t = C.applyEvent(t, "/a", { x: null, z: 3 }, "patch");
assert.deepStrictEqual(t.a, { y: 5, z: 3 });
t = C.applyEvent(t, "/a", null, "put");
assert.deepStrictEqual(t, { b: 2 });
assert.deepStrictEqual(C.applyEvent({ b: 2 }, "/", null, "put"), {});

// online
assert.ok(C.isOnline({ t: 1000 }, 1100));
assert.ok(!C.isOnline({ t: 1000 }, 1200));
assert.ok(!C.isOnline({ t: 1000, st: "left" }, 1001));
assert.ok(C.windowAlive({ t: 1000 }, 50000) && !C.windowAlive({ t: 1000 }, 100000));

// layout grouping keeps order
const g = C.groupLayout([
  { id: "a", tab: "Farm", section: "Duo" },
  { id: "b", tab: "Misc", section: "" },
  { id: "c", tab: "Farm", section: "Duo" },
  { id: "d", tab: "Farm", section: "Solo" },
]);
assert.deepStrictEqual(g.map((x) => x.tab), ["Farm", "Misc"]);
assert.deepStrictEqual(g[0].sections.map((s) => s.controls.map((c) => c.id)), [["a", "c"], ["d"]]);

// status line
assert.strictEqual(C.statusText({ layout: [{ id: "s", kind: "Paragraph", name: "Status" }], v: { s: "on the pad" } }), "on the pad");
assert.strictEqual(C.statusText({ layout: [{ id: "s", kind: "Toggle", name: "Status" }], v: { s: true } }), null);

// order outcomes
const o = { op: "set", kind: "Toggle", value: true, t: 1000 };
assert.strictEqual(C.orderOutcome(o, null, 2000).state, "pending");
assert.deepStrictEqual(C.orderOutcome(o, null, 1000 + 60001), { state: "fail", msg: "the account didn't answer" });
assert.strictEqual(C.orderOutcome(o, { ok: true, value: true }, 2000).state, "ok");
assert.strictEqual(C.orderOutcome(o, { ok: true, value: false }, 2000).state, "fail"); // a locked toggle
assert.deepStrictEqual(C.orderOutcome(o, { ok: false, err: "out of range" }, 2000), { state: "fail", msg: "out of range" });
assert.strictEqual(C.orderOutcome({ op: "press", t: 1 }, { ok: true }, 2).state, "ok");

// ids are unique and Firebase-safe
const ids = new Set(Array.from({ length: 500 }, () => C.newOrderId(1795130000000)));
assert.strictEqual(ids.size, 500);
for (const id of ids) assert.match(id, /^[a-z0-9]+$/);

console.log("core: all tests pass");
