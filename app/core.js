// Catn Control: the pure logic, shared by the page and the tests (node app/core.test.js).
(function (root) {
  "use strict";

  // same as Remote.key in the UI library: Firebase keys can't hold . $ # [ ] /
  function encodeKey(s) {
    s = String(s == null ? "" : s).replace(/\//g, "|").replace(/[.$#[\]]/g, "_");
    return s === "" ? "_" : s;
  }

  // apply one Firebase streaming event ("put" replaces, "patch" merges) to a plain object tree
  function applyEvent(tree, path, data, kind) {
    const parts = String(path || "/").split("/").filter(Boolean);
    const write = (node, i, value) => {
      if (i === parts.length) {
        if (kind === "patch" && value && typeof value === "object") {
          const out = Object.assign({}, node && typeof node === "object" ? node : {});
          for (const [k, v] of Object.entries(value)) {
            if (v === null) delete out[k];
            else out[k] = v;
          }
          return out;
        }
        return value === null ? undefined : value;
      }
      const out = Object.assign({}, node && typeof node === "object" ? node : {});
      const next = write(out[parts[i]], i + 1, value);
      if (next === undefined) delete out[parts[i]];
      else out[parts[i]] = next;
      return out;
    };
    const res = write(tree, 0, data);
    return res === undefined ? {} : res;
  }

  const ONLINE_SEC = 150; // the bot uses the same window
  function isOnline(acct, nowSec) {
    return !!acct && nowSec - (Number(acct.t) || 0) < ONLINE_SEC && acct.st !== "left";
  }
  // a window heartbeats every 30 s; older than 90 s means the script stopped
  function windowAlive(win, nowMs) {
    return !!win && typeof win.t === "number" && nowMs - win.t < 90000;
  }

  // layout array -> [{tab, sections: [{name, controls}]}], keeping the script's order
  function groupLayout(layout) {
    const tabs = [];
    const find = (list, key, make) => list.find((x) => x.key === key) || (list.push(make()), list[list.length - 1]);
    for (const c of Array.isArray(layout) ? layout : Object.values(layout || {})) {
      if (!c || !c.id) continue;
      const tab = find(tabs, c.tab || "Main", () => ({ key: c.tab || "Main", tab: c.tab || "Main", sections: [] }));
      const sec = find(tab.sections, c.section || "", () => ({ key: c.section || "", name: c.section || "", controls: [] }));
      sec.controls.push(c);
    }
    return tabs;
  }

  // the script's own live status line, whatever the game calls it
  function statusText(win) {
    if (!win || !win.layout || !win.v) return null;
    const lay = Array.isArray(win.layout) ? win.layout : Object.values(win.layout);
    const val = (c) => { const v = win.v[c.id]; return typeof v === "string" ? v.trim() : ""; };
    const ok = (s) => s && s !== "-" && s !== "–";
    const isText = (c) => c && (c.kind === "Paragraph" || c.kind === "Label");
    // 1. a control the script itself labels "status" / "state"
    for (const c of lay) if (isText(c) && /status|state/i.test((c.name || "") + " " + (c.section || "")) && ok(val(c))) return val(c);
    // 2. otherwise the first live line that isn't a history/log readout
    for (const c of lay) if (isText(c) && !/last |misses|history|log|recent/i.test(c.name || "") && ok(val(c))) return val(c);
    return null;
  }

  const ORDER_TIMEOUT = 60000;
  // what became of an order: pending / ok / fail, with a reason for fail
  function orderOutcome(order, ack, nowMs) {
    if (ack) {
      if (!ack.ok) return { state: "fail", msg: ack.err || "the script refused it" };
      if (order.op === "set" && ["Toggle", "Dropdown", "Input"].includes(order.kind) && !Array.isArray(order.value)) {
        const want = order.kind === "Toggle" ? order.value === true : String(order.value);
        const got = order.kind === "Toggle" ? ack.value === true : String(ack.value);
        if (want !== got) return { state: "fail", msg: "the script didn't take it (it's " + String(ack.value) + ")" };
      }
      return { state: "ok" };
    }
    if (nowMs - order.t > ORDER_TIMEOUT) return { state: "fail", msg: "the account didn't answer" };
    return { state: "pending" };
  }

  let seq = 0;
  function newOrderId(nowMs) {
    seq = (seq + 1) % 1296;
    return "o" + nowMs.toString(36) + seq.toString(36).padStart(2, "0") + Math.random().toString(36).slice(2, 6);
  }

  // an account's progress number: Funky Friday's leaderboard wins (only ever goes up), or a game script's own
  // run counter from getgenv().CatnRun (kills, songs...), which restarts at 0 every time the script runs
  function metricOf(a) {
    if (!a) return null;
    if (a.w != null) return { m: "wins", v: Number(a.w) || 0 };
    if (a.rn != null) return { m: String(a.rl || "progress"), v: Number(a.rn) || 0 };
    return null;
  }

  // How much `metric` went up after fromMs, from the app's minute samples [{t, d: {key: [metric, value]}}] (oldest
  // first). Only rises count: a run counter dropping back to 0 is a restart, and for wins a dip (the leaderboard
  // rebuilding) can't be counted again when it comes back. A gap over 10 min means the app was closed and when
  // those gains happened is unknown, so it starts a fresh baseline. Returns the running total over time and per account.
  const GAP_MS = 10 * 60000;
  function gained(samples, metric, fromMs, onlyKey) {
    let i = samples.length;
    while (i > 0 && samples[i - 1].t >= fromMs) i--;
    const last = {}, high = {}, by = {}, series = [];
    let total = 0, prevT = null;
    for (let j = Math.max(0, i - 1); j < samples.length; j++) {
      const s = samples[j];
      if (prevT != null && s.t - prevT > GAP_MS) for (const k in last) delete last[k];
      prevT = s.t;
      for (const k in s.d || {}) {
        if (onlyKey && k !== onlyKey) continue;
        const mv = s.d[k];
        if (!mv || mv[0] !== metric) { delete last[k]; continue; }
        const v = Number(mv[1]) || 0;
        if (k in last && s.t >= fromMs) {
          const base = metric === "wins" ? Math.max(last[k], high[k]) : last[k];
          if (v > base) { by[k] = (by[k] || 0) + (v - base); total += v - base; }
        }
        high[k] = Math.max(high[k] == null ? v : high[k], v);
        last[k] = v;
      }
      if (s.t >= fromMs) series.push({ t: s.t, v: total });
    }
    return { series, by, total };
  }

  // Stretches in [fromMs, toMs] when an account (or, with no key, every account) wasn't reporting:
  // samples are only taken for online accounts, so a hole longer than a few minutes is downtime
  // (or the app being closed). Starts at the first sample in range, never before history begins.
  const DOWN_MS = 3 * 60000;
  function downtime(samples, fromMs, toMs, onlyKey) {
    const out = [];
    let prev = null;
    for (const s of samples) {
      if (s.t < fromMs || s.t > toMs) continue;
      if (onlyKey && !(s.d && s.d[onlyKey])) continue;
      if (prev != null && s.t - prev > DOWN_MS) out.push([prev, s.t]);
      prev = s.t;
    }
    if (prev != null && toMs - prev > DOWN_MS) out.push([prev, toMs]);
    return out;
  }

  const api = { encodeKey, applyEvent, isOnline, windowAlive, groupLayout, statusText, orderOutcome, newOrderId, ORDER_TIMEOUT, metricOf, gained, downtime };
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.CatnCore = api;
})(typeof window !== "undefined" ? window : globalThis);
