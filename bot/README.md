# Catn Yapper (standalone bot)

A Discord bot you run on your own PC. It stays online while this program runs (independent of Roblox) and is a
panel over **every account running Catn Hub, in any game**: who's online, where they are, their stats, and a
one-click way to join their exact server.

**Only server admins (and the owner) get replies.** Everyone else is ignored, buttons included.

## Commands

An optional `catn` or `!` prefix works on all of them. Typos are fine: unknown names get "did you mean…".

| Command | What it does |
| --- | --- |
| `accounts` | Every account: wins, points, game and status (pages automatically past 25) |
| `online` | Only accounts online right now |
| `account <name>` | Full stats for one account, with 🔄 Refresh / 🔗 Join buttons |
| `join <name>` | Executor script **and** a one-click Roblox link into that account's live server |
| `compare <a> <b>` | Two accounts side by side |
| `games` | Who's online, grouped by game |
| `search <game>` | Accounts in a given game |
| `top` / `top points` / `top score` | Leaderboards |
| `stats` | Totals across everyone |
| `status` | Bot uptime, tracked/online counts, data store |
| `prune` | Drop accounts not seen in 6 hours (also runs every 30 min by itself) |
| `remove <exact name>` | Forget one account |
| `help`, `hi`, `meow` | Help card, says bye, random cat gif |

Join buttons answer privately (only the clicker sees the script).

## Run it

1. Install **Node.js 18 or newer** from https://nodejs.org.
2. In this `bot` folder: `npm install`
3. Copy `.env.example` to `.env` and fill in `DISCORD_TOKEN` (a freshly reset token) and `FIREBASE_URL`.
   Keep `.env` private.
4. Developer Portal → Bot → turn on **Message Content Intent**.
5. Double-click `start.bat` (Windows). It restarts the bot automatically if it ever stops; close the window to
   stop it for good. Or run `npm start`.

Run only one copy at a time, or it will reply twice.

## Where the data comes from

- **Firebase Realtime DB** (`FIREBASE_URL`), the main store: every hub writes its account's live server + game
  every 45s, and the Funky Friday script adds wins/points/score on top.
- **Local farm files** in `%LOCALAPPDATA%\Real\workspace\FFAutoFarm` (override with `FARM_DIR`).
- **Legacy stats channel** (`STATS_WEBHOOK`), for accounts still on an older hub.

When sources disagree, the most recently updated one wins.

## Tests

```
BOT_TEST=1 node test.js
```

Runs the render, lookup, merge and admin-gate logic offline (no token or network needed).
