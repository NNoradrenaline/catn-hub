// Catn Yapper - a standalone Discord bot you run on your own PC (node index.js).
// It stays online while this program runs, independent of Roblox, and is a read-only panel over the
// Funky Friday duo-farm: it reads the per-account stat files the Roblox script writes to disk, so it can
// report every account and its stats even when the accounts are offline.
//
// Commands (an optional "catn" or "!" prefix works):
//   accounts            - list every farm account with online status + lifetime/run stats
//   account <name>      - detailed stats for one account
//   stats               - totals across all accounts
//   help                - this list
//   hi                  - says bye
//   meow                - a random cat gif
//
// Farm CONTROL (start/stop/rejoin) stays in the Roblox script and only works while an account is in-game.
require("dotenv").config();
const fs = require("fs");
const path = require("path");
const os = require("os");
const { Client, GatewayIntentBits, Events, EmbedBuilder } = require("discord.js");

const TOKEN = process.env.DISCORD_TOKEN;
if (!TOKEN) {
  console.error("No token. Copy .env.example to .env and put your bot token in DISCORD_TOKEN.");
  process.exit(1);
}

// Where the Roblox script writes the farm files. Override with FARM_DIR in .env if your executor differs.
const LOCALAPPDATA = process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local");
const FARM_DIR = process.env.FARM_DIR || path.join(LOCALAPPDATA, "Real", "workspace", "FFAutoFarm");
const ONLINE_SECS = 45; // an account is "online" if its stat file was touched within this many seconds
const COLOR = 0x8f70ec;

function readJson(p) {
  try {
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch (e) {
    return null;
  }
}

function abbrev(n) {
  n = Number(n) || 0;
  const trim = (x) => x.toFixed(2).replace(/\.?0+$/, "");
  if (n >= 1e9) return trim(n / 1e9) + "B";
  if (n >= 1e6) return trim(n / 1e6) + "M";
  if (n >= 1e3) return trim(n / 1e3) + "K";
  return String(n);
}

function dur(sec) {
  sec = Math.max(0, Math.floor(sec));
  const d = Math.floor(sec / 86400),
    h = Math.floor((sec % 86400) / 3600),
    m = Math.floor((sec % 3600) / 60);
  if (d > 0) return `${d}d ${h}h ${m}m`;
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m`;
  return `${sec}s`;
}

// Reads every lifetime_<name>.json (and its matching stats_<name>.json run file) from FARM_DIR.
function readAccounts() {
  let files;
  try {
    files = fs.readdirSync(FARM_DIR);
  } catch (e) {
    return [];
  }
  const now = Math.floor(Date.now() / 1000);
  const accounts = [];
  for (const f of files) {
    const m = f.match(/^lifetime_(.+)\.json$/);
    if (!m) continue;
    const name = m[1];
    const life = readJson(path.join(FARM_DIR, f)) || {};
    const runFile = readJson(path.join(FARM_DIR, `stats_${name}.json`));
    const lastSeen = Math.max(Number(life.lastSeen) || 0, (runFile && Number(runFile.lastSeen)) || 0);
    accounts.push({
      name,
      wins: Number(life.wins) || 0,
      score: Number(life.score) || 0,
      since: Number(life.since) || 0,
      lastSeen,
      online: now - lastSeen < ONLINE_SECS,
      run: runFile && runFile.startedAt
        ? { wins: Number(runFile.wins) || 0, score: Number(runFile.score) || 0, startedAt: Number(runFile.startedAt) || 0 }
        : null,
    });
  }
  accounts.sort((a, b) => b.wins - a.wins);
  return accounts;
}

const HELP = new EmbedBuilder()
  .setTitle("Catn Yapper")
  .setColor(COLOR)
  .setDescription(
    [
      "**Farm panel**",
      "`accounts` - every account with online status + stats",
      "`account <name>` - detailed stats for one account",
      "`stats` - totals across all accounts",
      "",
      "**Other**",
      "`hi` - I say bye · `meow` - a random cat gif · `help` - this",
      "",
      "Control the farm (`start`/`stop`/`status`/`rejoin`) from Discord with the Roblox hub running - those live in the script.",
    ].join("\n")
  );

async function catGif() {
  try {
    const res = await fetch("https://api.thecatapi.com/v1/images/search?mime_types=gif&limit=1");
    const data = await res.json();
    if (Array.isArray(data) && data[0] && data[0].url) return data[0].url;
  } catch (e) {
    /* fall through */
  }
  return "https://cataas.com/cat/gif?" + Date.now();
}

function accountsEmbed() {
  const accts = readAccounts();
  if (!accts.length) return null;
  const now = Math.floor(Date.now() / 1000);
  const embed = new EmbedBuilder().setTitle("Farm accounts").setColor(COLOR);
  for (const a of accts) {
    let v = `${a.online ? "🟢 online" : "⚪ offline"} · lifetime **${a.wins}** wins · **${abbrev(a.score)}** score`;
    if (a.online && a.run) v += `\nthis run: ${a.run.wins} wins · ${abbrev(a.run.score)} · ${dur(now - a.run.startedAt)}`;
    embed.addFields({ name: a.name, value: v });
  }
  const online = accts.filter((a) => a.online).length;
  embed.setFooter({ text: `${accts.length} account(s) · ${online} online` });
  return embed;
}

function accountEmbed(query) {
  const accts = readAccounts();
  const q = query.toLowerCase();
  const a = accts.find((x) => x.name.toLowerCase() === q) || accts.find((x) => x.name.toLowerCase().includes(q));
  if (!a) return null;
  const now = Math.floor(Date.now() / 1000);
  const embed = new EmbedBuilder()
    .setTitle(a.name)
    .setColor(a.online ? 0x57f287 : 0x747f8d)
    .addFields(
      { name: "Status", value: a.online ? "🟢 farming" : "⚪ offline", inline: true },
      { name: "Lifetime wins", value: String(a.wins), inline: true },
      { name: "Lifetime score", value: abbrev(a.score), inline: true }
    );
  if (a.run)
    embed.addFields(
      { name: "This run", value: `${a.run.wins} wins · ${abbrev(a.run.score)} score`, inline: true },
      { name: "Farming for", value: a.online ? dur(now - a.run.startedAt) : "—", inline: true }
    );
  if (a.since) embed.addFields({ name: "Tracking since", value: `<t:${a.since}:D>`, inline: true });
  if (a.lastSeen) embed.addFields({ name: "Last seen", value: `<t:${a.lastSeen}:R>`, inline: true });
  return embed;
}

function statsEmbed() {
  const accts = readAccounts();
  const tw = accts.reduce((s, a) => s + a.wins, 0);
  const ts = accts.reduce((s, a) => s + a.score, 0);
  const online = accts.filter((a) => a.online).length;
  return new EmbedBuilder()
    .setTitle("Farm totals")
    .setColor(COLOR)
    .addFields(
      { name: "Accounts", value: `${accts.length} (${online} online)`, inline: true },
      { name: "Total wins", value: String(tw), inline: true },
      { name: "Total score", value: abbrev(ts), inline: true }
    );
}

const client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.MessageContent],
});

client.once(Events.ClientReady, (c) => console.log("online as " + c.user.tag + " | farm dir: " + FARM_DIR));

client.on(Events.MessageCreate, async (msg) => {
  if (msg.author.bot) return;
  const text = msg.content.trim().toLowerCase().replace(/^!\s*/, "").replace(/^catn\s+/, "");
  const parts = text.split(/\s+/);
  const word = parts[0] || "";
  const rest = text.slice(word.length).trim();
  try {
    if (word === "accounts" || word === "list") {
      const e = accountsEmbed();
      await msg.channel.send(e ? { embeds: [e] } : "No farm accounts found on this PC yet (run the farm once).");
    } else if (word === "account" || word === "acc") {
      if (!rest) return void (await msg.channel.send("Usage: `account <name>`"));
      const e = accountEmbed(rest);
      await msg.channel.send(e ? { embeds: [e] } : `No account matching "${rest}".`);
    } else if (word === "stats" || word === "totals") {
      await msg.channel.send({ embeds: [statsEmbed()] });
    } else if (word === "help" || word === "commands" || word === "?") {
      await msg.channel.send({ embeds: [HELP] });
    } else if (word === "hi") {
      await msg.channel.send("bye");
    } else if (word === "meow") {
      await msg.channel.send(await catGif());
    }
  } catch (e) {
    console.error("send failed:", e.message);
  }
});

client.login(TOKEN).catch((e) => {
  console.error("Login failed. Check the token, and that Message Content Intent is on.", e.message);
  process.exit(1);
});
