// Catn Yapper - a standalone Discord bot you run on your own PC (node index.js).
// It stays online while this program runs, independent of Roblox, and is a read-only panel over the
// Funky Friday duo-farm. It shows every account across ALL machines: each hub posts its stats to a shared
// channel (via STATS_WEBHOOK, no bot token needed), and this bot reads that channel + the local files.
//
// Commands (an optional "catn" or "!" prefix works):
//   accounts            - list every account (everyone's) with online status + lifetime/run stats
//   account <name>      - detailed stats for one account
//   stats               - totals across all accounts
//   help / hi / meow
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

// Shared stats channel every hub posts to. Same webhook URL that's baked into the hub script.
const STATS_WEBHOOK = (process.env.STATS_WEBHOOK || "").trim();
// Local files this PC's own hub writes (a fresher source for this machine's accounts).
const LOCALAPPDATA = process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local");
const FARM_DIR = process.env.FARM_DIR || path.join(LOCALAPPDATA, "Real", "workspace", "FFAutoFarm");

const ONLINE_LOCAL = 45; // local file touched within N seconds = online
const ONLINE_REMOTE = 200; // remote stat posted within N seconds = online (hubs post every ~120s)
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

// This PC's accounts, from the local FFAutoFarm files.
function localAccounts() {
  let files;
  try {
    files = fs.readdirSync(FARM_DIR);
  } catch (e) {
    return [];
  }
  const now = Math.floor(Date.now() / 1000);
  const out = [];
  for (const f of files) {
    const m = f.match(/^lifetime_(.+)\.json$/);
    if (!m) continue;
    const name = m[1];
    const life = readJson(path.join(FARM_DIR, f)) || {};
    const runFile = readJson(path.join(FARM_DIR, `stats_${name}.json`));
    const lastSeen = Math.max(Number(life.lastSeen) || 0, (runFile && Number(runFile.lastSeen)) || 0);
    out.push({
      name,
      wins: Number(life.wins) || 0,
      score: Number(life.score) || 0,
      since: Number(life.since) || 0,
      lastSeen,
      online: now - lastSeen < ONLINE_LOCAL,
      run: runFile && runFile.startedAt
        ? { wins: Number(runFile.wins) || 0, score: Number(runFile.score) || 0, startedAt: Number(runFile.startedAt) || 0 }
        : null,
    });
  }
  return out;
}

// Resolve the stats channel id from the webhook once, then cache it.
let statsChannelId = null;
async function getStatsChannelId() {
  if (statsChannelId || !STATS_WEBHOOK) return statsChannelId;
  try {
    const res = await fetch(STATS_WEBHOOK);
    const d = await res.json();
    if (d && d.channel_id) statsChannelId = String(d.channel_id);
  } catch (e) {
    /* ignore; we'll retry next call */
  }
  return statsChannelId;
}

// Every account reported to the shared channel (all machines). Keeps the most recent per name.
async function remoteAccounts() {
  const out = {};
  const ch = await getStatsChannelId();
  if (!ch) return out;
  let msgs;
  try {
    const res = await fetch(`https://discord.com/api/v10/channels/${ch}/messages?limit=100`, {
      headers: { Authorization: "Bot " + TOKEN },
    });
    if (!res.ok) return out;
    msgs = await res.json();
  } catch (e) {
    return out;
  }
  const now = Math.floor(Date.now() / 1000);
  for (const m of Array.isArray(msgs) ? msgs : []) {
    const c = (m && m.content) || "";
    if (!c.startsWith("STAT ")) continue;
    let d;
    try {
      d = JSON.parse(c.slice(5));
    } catch (e) {
      continue;
    }
    if (!d || typeof d.n !== "string") continue;
    const t = Number(d.t) || 0;
    if (out[d.n] && out[d.n].lastSeen >= t) continue;
    out[d.n] = {
      name: d.n,
      wins: Number(d.w) || 0,
      score: Number(d.s) || 0,
      since: 0,
      lastSeen: t,
      online: now - t < ONLINE_REMOTE,
      run: d.rt ? { wins: Number(d.rw) || 0, score: Number(d.rs) || 0, startedAt: Number(d.rt) || 0 } : null,
    };
  }
  return out;
}

// All accounts everywhere: remote (shared channel), with this PC's local files layered on top (fresher).
async function allAccounts() {
  const byName = {};
  const remote = await remoteAccounts();
  for (const a of Object.values(remote)) byName[a.name.toLowerCase()] = a;
  for (const a of localAccounts()) byName[a.name.toLowerCase()] = a;
  return Object.values(byName).sort((a, b) => b.wins - a.wins);
}

const HELP = new EmbedBuilder()
  .setTitle("Catn Yapper")
  .setColor(COLOR)
  .setDescription(
    [
      "**Farm panel (everyone's accounts)**",
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

function accountsEmbed(accts) {
  if (!accts.length) return null;
  const now = Math.floor(Date.now() / 1000);
  const embed = new EmbedBuilder().setTitle("Farm accounts").setColor(COLOR);
  for (const a of accts.slice(0, 25)) {
    let v = `${a.online ? "🟢 online" : "⚪ offline"} · lifetime **${a.wins}** wins · **${abbrev(a.score)}** score`;
    if (a.online && a.run) v += `\nthis run: ${a.run.wins} wins · ${abbrev(a.run.score)} · ${dur(now - a.run.startedAt)}`;
    embed.addFields({ name: a.name, value: v });
  }
  const online = accts.filter((a) => a.online).length;
  let footer = `${accts.length} account(s) · ${online} online`;
  if (accts.length > 25) footer += " · showing top 25 by wins";
  embed.setFooter({ text: footer });
  return embed;
}

function accountEmbed(accts, query) {
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

function statsEmbed(accts) {
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

client.once(Events.ClientReady, (c) =>
  console.log("online as " + c.user.tag + " | stats channel: " + (STATS_WEBHOOK ? "shared" : "local only") + " | farm dir: " + FARM_DIR)
);

client.on(Events.MessageCreate, async (msg) => {
  if (msg.author.bot) return;
  const text = msg.content.trim().toLowerCase().replace(/^!\s*/, "").replace(/^catn\s+/, "");
  const word = text.split(/\s+/)[0] || "";
  const rest = text.slice(word.length).trim();
  try {
    if (word === "accounts" || word === "list") {
      const e = accountsEmbed(await allAccounts());
      await msg.channel.send(e ? { embeds: [e] } : "No farm accounts reported yet.");
    } else if (word === "account" || word === "acc") {
      if (!rest) return void (await msg.channel.send("Usage: `account <name>`"));
      const e = accountEmbed(await allAccounts(), rest);
      await msg.channel.send(e ? { embeds: [e] } : `No account matching "${rest}".`);
    } else if (word === "stats" || word === "totals") {
      await msg.channel.send({ embeds: [statsEmbed(await allAccounts())] });
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
