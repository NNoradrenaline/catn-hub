# Catn Yapper (standalone bot)

A Discord bot you run on your own PC. It stays online while this program is running (independent of Roblox)
and acts as a read-only **panel over the Funky Friday duo-farm**: it reads the per-account stat files the
Roblox script writes to disk, so it can report every account and its stats even when the accounts are offline.

## Commands

An optional `catn` or `!` prefix works on all of them.

| Command | What it does |
| --- | --- |
| `accounts` | List every farm account with online status + lifetime/run stats |
| `account <name>` | Detailed stats for one account |
| `stats` | Totals across all accounts |
| `help` | The command list |
| `hi` | Says bye |
| `meow` | A random cat gif |

Farm **control** (`start`, `stop`, `status`, `rejoin`) stays in the Roblox hub script and only works while an
account is in-game - this bot just reports.

## Run it

1. Install **Node.js 18 or newer** from https://nodejs.org (the LTS build is fine).
2. Open a terminal in this `bot` folder.
3. Install the dependencies:
   ```
   npm install
   ```
4. Make your config file: copy `.env.example` to `.env`, open `.env`, and paste your bot token after
   `DISCORD_TOKEN=`. Use a freshly **reset** token (Developer Portal -> your app -> Bot -> Reset Token).
   Keep `.env` private - it is your token.
5. In the Developer Portal, make sure **Message Content Intent** is ON (Bot tab -> Privileged Gateway Intents).
6. Start it:
   ```
   npm start
   ```
   You should see `online as Catn Yapper#....` and the bot shows online in Discord.

On Windows you can also just double-click `start.bat`.

Leave it running - closing the window (or turning off the PC) takes the bot offline. To keep it up without a
window, run it with a process manager like `pm2` (`npm i -g pm2`, then `pm2 start index.js --name catn-yapper`).

## Where the stats come from

The bot reads the Roblox script's farm files - by default
`%LOCALAPPDATA%\Real\workspace\FFAutoFarm` (the `lifetime_<name>.json` and `stats_<name>.json` files). If your
executor stores them somewhere else, set `FARM_DIR=C:\path\to\FFAutoFarm` in `.env`. An account counts as
"online" when its file was updated in the last 45 seconds.

## Notes

- The bot replies in whatever channel a message was posted, in any channel it can see and send in.
- Run only one copy at a time, or it will reply twice.
