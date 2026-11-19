# Catn Yapper (standalone bot)

A Discord bot you run on your own PC. It stays online while this program is running (independent of Roblox)
and answers the chat commands: `hi` -> bye, `meow` -> a random cat gif, `help` -> the command list.

Farm commands (`start`, `stop`, `status`, `stats`, `rejoin`) are **not** here - those run in the Roblox hub
script and only work while a Catn Hub account is in-game. This bot just lists them in `help`.

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

Leave that terminal open - closing it (or turning off the PC) takes the bot offline. To keep it up without a
terminal window, run it with a process manager like `pm2` (`npm i -g pm2`, then `pm2 start index.js --name catn-yapper`).

## Notes

- The bot replies in whatever channel a message was posted, in any channel it can see and send in.
- If you also run the Roblox hub, the hub handles the farm commands and this bot handles the chat, so you
  never get double replies.
