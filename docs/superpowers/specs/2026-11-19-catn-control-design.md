# Catn Control: design

## Why
One app where the owner sees every account and controls every script in every game, without Discord
commands or each script's own menu. It must look professional and keep the Catn look. Only the owner
may control anything.

## Goals
- See every account live: online, game, server, the script's status text, wins and points.
- Change any control of any script on any account: toggles, sliders, dropdowns, inputs, keybinds, colors, buttons.
- Know that an order really happened: each order shows pending, then ✓ or ✗ with the reason.
- Covers all six games today and any later script built on the Catn UI library, with no per-game work.
- A home dashboard with the important things up front.

## Non-goals (for now)
- Launching Roblox or logging accounts in from the app.
- Running arbitrary Lua from the app.
- Hiding the status data from the public (it is readable today too; a secret folder can be added later).
- A phone version.

## Anti-goals (a failure even if it works)
- Anyone but the owner can make an account do something.
- The app shows ✓ for a change that did not happen in the game.
- Orders replay after a rejoin, or old orders fire later.
- The polling lags the game or burns the Firebase free plan.

## Security (done 2026-11-19, verified)
Firebase rules: everyone reads; everyone writes `accounts`, `boards`, `acks`; only the owner's login
(uid zYex56M3Vxc3bo5QaZmPsLm7eM53) writes `orders`. Tested: a write to `orders` or the root without
login is refused; `accounts` and `boards` still accept writes.
Needed for this design: add `"menus": { ".write": true }` to the rules (the owner pastes it).

## Approaches considered
1. **Mirror every menu from the UI library** — one bridge inside `dist/ui.lua`; every script is covered
   automatically. Screens follow each script's own layout.
2. **Hand-made screens per game** — nicest look, but written and maintained per game, and covers only
   what is wired up.
3. **Mirror plus a dashboard** — approach 1 as the base, plus a home screen. **Chosen** (proposed by me,
   not objected to).

## How it works

### 1. Bridge in the UI library (`dist/ui.lua`)
- Every `Section:AddX` records the control in a registry: id, kind, label, tab, section, description,
  options / min / max, and get / set (toggles etc. reuse the existing `Flags` entry).
  The id is the control's `Flag`; controls without one (buttons, labels) get `tab/section/name`.
- Labels and paragraphs are mirrored read-only, so script status text ("on the pad, holding it…") shows in the app.
- Each window publishes `menus/<account>/<window>`: the layout once (again only when it changes), and
  current values whenever they change (hooked onto the existing debounced `_save`, plus a slow check
  for labels).
- Each window polls `orders/<account>.json` every 2 s. For an order newer than the window's start that it has
  not applied yet, it runs it through the same `Set` / button callback a click would use, then writes
  `acks/<account>/<orderId>` = `{ok, err, value, t}`. Orders older than 60 s are ignored, so a rejoin
  never replays them. One poller per account even with several windows open (hub plus game script).
- Built-in orders handled by the library: `rejoin` (same server) and `hop` (another server).

### 2. Orders
`orders/<account>/<orderId>` = `{op: "set" | "press" | "rejoin" | "hop", window, id, value, t}`.
Only the owner's login can write here. The app deletes an order once it is acked, or after 60 s with no ack
(shown as ✗ "account didn't answer").

### 3. The app
- One HTML page opened in its own window (Edge app mode, no browser bar) from a desktop shortcut.
  No server, no new installs.
- Sign-in once with the owner's email and password via Firebase Auth (needs the project's public Web API key,
  pasted once). The password is typed by the owner only; the app keeps a refresh token, never the password.
- Live updates through Firebase streaming (no refresh button).
- Screens:
  - **Home**: a card per account: online dot, game, server, status text, wins and points, and quick
    actions (rejoin, hop, plus any controls the owner pins to the card from the mirror).
  - **Account**: that account's mirrored menus, tab by tab, with real controls; each change shows pending → ✓/✗.
  - **Multi-select**: apply the same change to several accounts in the same game at once.
  - **Boards**: the global leaderboards the bot already reads.
- Look: dark Catn theme colors and accent from the hub, cat logo from `art/png/cat.png`.
- Real names are shown: the app is private, and name hiding was for the public Discord. (My call.)

## Load
About 20 accounts × one poll every 2 s ≈ 600 small requests a minute, mostly an empty `null` reply.
Menus publish only on change. Well inside the Firebase free plan.

## Testing
- The order parsing, staleness and ack logic in the bridge gets an assert-based self-check.
- Live check with the real tool on the two FF clients: change a toggle, a slider and a dropdown from the
  app, press a button, rejoin; confirm ✓ and the change in game; confirm an order without login is refused.

## Left to the builder
File layout of the app, exact visuals within the Catn look, how pins are stored (local to the app is fine),
version bumps for the library and the hub.
