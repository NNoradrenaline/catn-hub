# Catn Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One desktop window that shows and controls every Catn UI menu on the owner's accounts.

**Architecture:** A bridge in the BPUI layer of the UI library records every control, publishes menus to
`menus/<account>/<window>`, polls `orders/<account>`, applies orders through the control's own `Set` /
callback, and writes `acks/<account>/<orderId>`. A single HTML page (Edge app mode) streams those paths and
writes orders with the owner's Firebase login.

**Tech Stack:** Luau (executor `request`, `writefile`/`isfile`), Firebase Realtime DB REST + streaming, Firebase Auth REST, plain HTML/CSS/JS.

**Spec:** `docs/superpowers/specs/2026-11-19-catn-control-design.md`

## Global Constraints
- Only the owner's login writes `orders` (rules live). Scripts never write `orders`.
- The bridge is off unless the PC opted in: a toggle "Allow Catn Control" in the window's Settings tab writes the file `catn_control_on`. Off by default, so other people who run Catn Hub are never remotely controllable. (Added during planning: without it, every public hub user would be controllable by the owner.)
- `dist/ui.lua` and `dist/catn_hub.lua` both carry the library; patch both by anchor with Python binary replace (CRLF). Never `sed -i`.
- Order ops: `set`, `press`, `rejoin`, `hop`. Orders with `t` (ms) older than the script's start, or older than 60 s, are ignored. Each order id applies at most once (shared `getgenv().CatnRemote.done`).
- Firebase keys can't contain `. $ # [ ] /`: window keys and control ids are encoded (`/` → `|`, others → `_`).
- Value encoding: Keybind → KeyCode name; ColorPicker → hex `#rrggbb`; everything else as is.

## Review Focus
1. A hop order still in the DB after the teleport lands → must not hop again (start-time check). Test: order with t < start is skipped.
2. Two windows with the same title on one account → keys `Title` and `Title_2`, orders reach the right one.
3. Setting a dropdown to a value not in its options → ack ✗ with the reason, nothing changed.
4. A control whose callback errors → ack ✗ with the error text, poller keeps running.
5. App signed out / token expired → order write fails visibly (401), app asks to sign in again.

---

### Task 1: Bridge in the UI library
**Files:** Modify `dist/ui.lua` and `dist/catn_hub.lua` (BPUI layer: `Section:Add*`, `Tab:CreateSection`, `wrapTab`, `BPUI:CreateWindow`; core `Window:_settingsTab` for the opt-in toggle). Bump library version 1.14.1 → 1.15.0.
**Produces:** DB layout `menus/<acct>/<win>` = `{layout: [{id, kind, name, tab, section, desc, options, min, max, step}], v: {id: value}, t}`; acks `{ok, err, value, t}`.
- [ ] Write the bridge as one Lua block `remote(win)` + `reg(section, kind, o, obj)` with a pure `pickOrders(orders, start, now, done)` and an assert self-check for it (Review Focus 1).
- [ ] Splice into both bundles by anchor; compile-check both through real (`loadstring(readfile("x.lua"))`).
- [ ] Commit.

### Task 2: The app
**Files:** Create `app/catn-control.html`, `app/Catn Control.cmd` (opens Edge `--app`), `app/README.md`.
**Consumes:** Task 1 DB layout.
- [ ] Sign-in (email/password via `accounts:signInWithPassword`, refresh via `securetoken`), Web API key pasted once, kept in localStorage with the refresh token only.
- [ ] Streams for `accounts`, `menus`, `acks`; Home cards, Account view with mirrored controls, multi-select apply, Boards.
- [ ] Order write `PUT orders/<acct>/<id>.json?auth=`; pending → ✓/✗ from acks; delete order + ack after; ✗ "didn't answer" after 60 s.
- [ ] Commit.

### Task 3: Live test
- [ ] On the FF clients through real: opt in, check `menus/<acct>` appears; send set (toggle, slider, dropdown), press, bad dropdown value; confirm acks and in-game values; confirm an unauthenticated order write is refused.
- [ ] Push.
