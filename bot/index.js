// Catn Yapper - a standalone Discord bot you run on your own PC (node index.js).
// It stays online while this program runs, independent of Roblox, and is a read-only panel over the
// Funky Friday duo-farm. It shows every account across ALL machines: each hub posts its stats to a shared
// channel (via STATS_WEBHOOK, no bot token needed), and this bot reads that channel + the local files.
//
// Commands (an optional "catn" or "!" prefix works):
//   accounts / online   - list accounts (all, or only the ones farming now)
//   account <name>      - detailed stats for one account
//   join <name>         - copy-paste script to join that account's server
//   top                 - leaderboard by wins
//   stats               - totals across all accounts
//   help / hi / meow
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

const STATS_WEBHOOK = (process.env.STATS_WEBHOOK || "").trim();
const LOCALAPPDATA = process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local");
const FARM_DIR = process.env.FARM_DIR || path.join(LOCALAPPDATA, "Real", "workspace", "FFAutoFarm");
const ONLINE_LOCAL = 60;
const ONLINE_REMOTE = 150; // ~3 missed 45s refreshes
const JOIN_FRESH = 75; // a server id newer than this is current; older may have hopped
const COLOR = 0x8f70ec;
const ZW = "​"; // zero-width spacer for a clean 3-column grid
const FF_PLACE = 6447798030; // Funky Friday place id (fallback when no live server is known)

// One consistent look for every card: author line, subtle footer, timestamp.
function brand(embed, footer) {
  return embed
    .setAuthor({ name: "Catn Yapper" })
    .setFooter({ text: footer ? footer + " · Catn Hub" : "Catn Hub" })
    .setTimestamp();
}

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

// This PC's accounts, from the local FFAutoFarm files (lifetime_, stats_, statmsg_ which holds the real board values).
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
    const msg = readJson(path.join(FARM_DIR, `statmsg_${name}.json`)) || {};
    const lastSeen = Math.max(Number(life.lastSeen) || 0, (runFile && Number(runFile.lastSeen)) || 0);
    out.push({
      name,
      wins: Number(msg.w) || Number(life.lastWins) || Number(life.wins) || 0, // real leaderboard wins
      points: Number(msg.p) || 0, // real Points currency
      totalScore: Number(msg.ts) || 0, // real total score
      scriptWins: Number(life.wins) || 0, // wins farmed by the script
      scriptScore: Number(life.score) || 0, // score farmed by the script
      since: Number(life.since) || 0,
      lastSeen,
      online: now - lastSeen < ONLINE_LOCAL,
      placeId: Number(msg.pl) || 0,
      jobId: typeof msg.j === "string" ? msg.j : "",
      run: runFile && runFile.startedAt
        ? { wins: Number(runFile.wins) || 0, score: Number(runFile.score) || 0, startedAt: Number(runFile.startedAt) || 0 }
        : null,
    });
  }
  return out;
}

let statsChannelId = null;
async function getStatsChannelId() {
  if (statsChannelId || !STATS_WEBHOOK) return statsChannelId;
  try {
    const res = await fetch(STATS_WEBHOOK);
    const d = await res.json();
    if (d && d.channel_id) statsChannelId = String(d.channel_id);
  } catch (e) {
    /* retry next call */
  }
  return statsChannelId;
}

// Every account reported to the shared channel (all machines). Keeps the most recent per name.
async function remoteAccounts() {
  const out = {};
  const ch = await getStatsChannelId();
  if (!ch) return out;
  // Edited messages keep their old position, so an account's STAT can sit far back. Page through
  // several hundred so long-running accounts don't fall out of view.
  const msgs = [];
  let before = "";
  try {
    for (let page = 0; page < 5; page++) {
      const url = `https://discord.com/api/v10/channels/${ch}/messages?limit=100` + (before ? "&before=" + before : "");
      const res = await fetch(url, { headers: { Authorization: "Bot " + TOKEN } });
      if (!res.ok) break;
      const batch = await res.json();
      if (!Array.isArray(batch) || !batch.length) break;
      msgs.push(...batch);
      before = batch[batch.length - 1].id;
      if (batch.length < 100) break;
    }
  } catch (e) {
    if (!msgs.length) return out;
  }
  const now = Math.floor(Date.now() / 1000);
  for (const m of msgs) {
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
      points: Number(d.p) || 0,
      totalScore: Number(d.ts) || 0,
      scriptWins: Number(d.sw) || 0,
      scriptScore: Number(d.s) || 0,
      since: 0,
      lastSeen: t,
      online: now - t < ONLINE_REMOTE,
      run: d.rt ? { wins: Number(d.rw) || 0, score: Number(d.rs) || 0, startedAt: Number(d.rt) || 0 } : null,
      placeId: Number(d.pl) || 0,
      jobId: typeof d.j === "string" ? d.j : "",
    };
  }
  return out;
}

// All accounts everywhere: remote (shared channel) with this PC's local files layered on top (fresher).
async function allAccounts() {
  const byName = {};
  const remote = await remoteAccounts();
  for (const a of Object.values(remote)) byName[a.name.toLowerCase()] = a;
  // Local files are fresher for stats, but keep the live placeId/jobId the channel reported.
  for (const a of localAccounts()) {
    const k = a.name.toLowerCase();
    byName[k] = byName[k] ? { ...byName[k], ...a } : a;
  }
  return Object.values(byName).sort((a, b) => b.wins - a.wins);
}

const HELP = brand(
  new EmbedBuilder()
    .setTitle("🎧 Catn Yapper")
    .setColor(COLOR)
    .setDescription("Your panel over the Funky Friday farm. Prefix with `catn ` or `!` if you like — both optional.")
    .addFields(
      {
        name: "📊 Stats",
        value: [
          "**`accounts`** — every account: wins, points & status",
          "**`online`** — only the ones farming right now",
          "**`account <name>`** — full stats for one account",
          "**`top`** — leaderboard by wins",
          "**`stats`** — grand totals across everyone",
        ].join("\n"),
      },
      {
        name: "🔗 Jump in",
        value: "**`join <name>`** — a copy-paste script that drops you into that account's server",
      },
      { name: "🐱 Fun", value: "**`meow`** — a random cat gif · **`hi`** — I say bye" }
    )
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

function accountsEmbed(accts, title) {
  if (!accts.length) return null;
  const now = Math.floor(Date.now() / 1000);
  const embed = new EmbedBuilder().setTitle("🎧 " + (title || "Funky Friday farm")).setColor(COLOR);
  for (const a of accts.slice(0, 25)) {
    let v = `${a.online ? "🟢 online" : "⚪ offline"} · **${a.wins}** wins · **${abbrev(a.points)}** pts · ${abbrev(a.totalScore)} score`;
    v += `\n╰ script farmed: ${a.scriptWins} wins · ${abbrev(a.scriptScore)}`;
    if (a.online && a.run) v += ` · this run ${a.run.wins}w (${dur(now - a.run.startedAt)})`;
    embed.addFields({ name: "▸ " + a.name, value: v });
  }
  const online = accts.filter((a) => a.online).length;
  let footer = `${accts.length} account${accts.length === 1 ? "" : "s"} · ${online} online`;
  if (accts.length > 25) footer += " · showing 25";
  return brand(embed, footer);
}

function accountEmbed(accts, query) {
  const q = query.toLowerCase();
  const a = accts.find((x) => x.name.toLowerCase() === q) || accts.find((x) => x.name.toLowerCase().includes(q));
  if (!a) return null;
  const now = Math.floor(Date.now() / 1000);
  const embed = new EmbedBuilder()
    .setTitle((a.online ? "🟢 " : "⚪ ") + a.name)
    .setColor(a.online ? 0x57f287 : 0x747f8d)
    .addFields(
      { name: "🏆 Wins", value: String(a.wins), inline: true },
      { name: "💰 Points", value: abbrev(a.points), inline: true },
      { name: "📈 Total score", value: abbrev(a.totalScore), inline: true },
      { name: "🤖 Farmed by script", value: `${a.scriptWins} wins · ${abbrev(a.scriptScore)}`, inline: true },
      { name: ZW, value: ZW, inline: true },
      { name: ZW, value: ZW, inline: true }
    );
  if (a.run)
    embed.addFields(
      { name: "▶️ This run", value: `${a.run.wins} wins · ${abbrev(a.run.score)}`, inline: true },
      { name: "⏱️ Farming for", value: a.online ? dur(now - a.run.startedAt) : "—", inline: true },
      { name: ZW, value: ZW, inline: true }
    );
  const meta = [];
  if (a.lastSeen) meta.push(`Last seen <t:${a.lastSeen}:R>`);
  if (a.since) meta.push(`tracking since <t:${a.since}:D>`);
  if (meta.length) embed.addFields({ name: ZW, value: meta.join(" · ") });
  embed.addFields({ name: "🔗 Join", value: `\`join ${a.name}\`` });
  return brand(embed, a.online ? "farming now" : "offline");
}

function topEmbed(accts) {
  if (!accts.length) return null;
  const top = [...accts].sort((a, b) => b.wins - a.wins).slice(0, 10);
  const medal = ["🥇", "🥈", "🥉"];
  const lines = top.map((a, i) => `${medal[i] || `\`${i + 1}.\``} **${a.name}** — ${a.wins} wins · ${abbrev(a.points)} pts ${a.online ? "🟢" : ""}`);
  return brand(new EmbedBuilder().setTitle("🏆 Top accounts by wins").setColor(0xffd166).setDescription(lines.join("\n")));
}

function statsEmbed(accts) {
  const sum = (k) => accts.reduce((s, a) => s + (a[k] || 0), 0);
  const online = accts.filter((a) => a.online).length;
  return brand(
    new EmbedBuilder()
      .setTitle("📊 Farm totals")
      .setColor(COLOR)
      .addFields(
        { name: "👥 Accounts", value: `${accts.length} (${online} online)`, inline: true },
        { name: "🏆 Total wins", value: String(sum("wins")), inline: true },
        { name: "💰 Total points", value: abbrev(sum("points")), inline: true },
        { name: "📈 Total score", value: abbrev(sum("totalScore")), inline: true },
        { name: "🤖 Farmed by scripts", value: `${sum("scriptWins")} wins · ${abbrev(sum("scriptScore"))}`, inline: true },
        { name: ZW, value: ZW, inline: true }
      )
  );
}

// A copy-paste executor script that teleports you into this account's live server.
function joinEmbed(accts, query) {
  const q = query.toLowerCase();
  const a = accts.find((x) => x.name.toLowerCase() === q) || accts.find((x) => x.name.toLowerCase().includes(q));
  if (!a) return null;
  const place = a.placeId || FF_PLACE;
  const age = a.lastSeen ? Math.floor(Date.now() / 1000) - a.lastSeen : Infinity;
  let script, note;
  if (a.jobId && a.online) {
    script = `game:GetService("TeleportService"):TeleportToPlaceInstance(${place}, "${a.jobId}")`;
    note =
      age <= JOIN_FRESH
        ? `Paste this in your executor to drop into **this account's server** (as of <t:${a.lastSeen}:R>).`
        : `⚠️ This was the server <t:${a.lastSeen}:R> — the account may have **hopped since**. If it fails, run \`join ${a.name}\` again in a few seconds for the fresh server.`;
  } else {
    script = `game:GetService("TeleportService"):Teleport(${place})`;
    note = a.online
      ? "This account is farming, but on an **older farm version** that doesn't share its server yet — reload the farm to update it. For now this joins **any** Funky Friday server."
      : "This account **isn't farming right now**, so there's no server to join. This joins **any** Funky Friday server instead.";
  }
  return brand(
    new EmbedBuilder()
      .setTitle("🔗 Join " + a.name)
      .setColor(a.online ? 0x57f287 : COLOR)
      .setDescription(`${note}\n\`\`\`lua\n${script}\n\`\`\``)
  );
}

const client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.MessageContent],
});

client.once(Events.ClientReady, (c) =>
  console.log("online as " + c.user.tag + " | stats: " + (STATS_WEBHOOK ? "shared" : "local only") + " | farm dir: " + FARM_DIR)
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
    } else if (word === "online") {
      const e = accountsEmbed((await allAccounts()).filter((a) => a.online), "Accounts farming now");
      await msg.channel.send(e ? { embeds: [e] } : "No accounts are farming right now.");
    } else if (word === "account" || word === "acc") {
      if (!rest) return void (await msg.channel.send("Usage: `account <name>`"));
      const e = accountEmbed(await allAccounts(), rest);
      await msg.channel.send(e ? { embeds: [e] } : `No account matching "${rest}".`);
    } else if (word === "join") {
      if (!rest) return void (await msg.channel.send("Usage: `join <name>`"));
      const e = joinEmbed(await allAccounts(), rest);
      await msg.channel.send(e ? { embeds: [e] } : `No account matching "${rest}".`);
    } else if (word === "top" || word === "leaderboard" || word === "lb") {
      const e = topEmbed(await allAccounts());
      await msg.channel.send(e ? { embeds: [e] } : "No accounts reported yet.");
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
