// Catn Yapper - a standalone Discord bot you run on your own PC (node index.js).
// It stays online while this program runs, independent of Roblox, and is a read-only panel over the
// Funky Friday duo-farm. It shows every account across ALL machines: each hub posts its stats to a shared
// channel (via STATS_WEBHOOK, no bot token needed), and this bot reads that channel + the local files.
//
// Commands (an optional "catn" or "!" prefix works):
//   accounts / online   - list accounts (all, or only the ones farming now)
//   account <name>      - detailed stats for one account
//   join <name>         - copy-paste script + one-click link to join that account's live server (any game)
//   games / search <g>  - who's online grouped by game / accounts in a given game
//   top                 - leaderboard by wins
//   stats               - totals across all accounts
//   help / hi / meow
require("dotenv").config();
const fs = require("fs");
const path = require("path");
const os = require("os");
const {
  Client,
  GatewayIntentBits,
  Events,
  EmbedBuilder,
  PermissionsBitField,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  escapeMarkdown,
  SlashCommandBuilder,
} = require("discord.js");
const esc = (s) => escapeMarkdown(String(s == null ? "" : s)); // usernames like Eloise_QwQ must not turn into italics

const TEST = !!process.env.BOT_TEST; // when set, export helpers and don't log in (for the test harness)
const TOKEN = process.env.DISCORD_TOKEN;
if (!TOKEN && !TEST) {
  console.error("No token. Copy .env.example to .env and put your bot token in DISCORD_TOKEN.");
  process.exit(1);
}
const START_TS = Math.floor(Date.now() / 1000);
let BOT_ICON = ""; // set to the bot's own avatar on ready, so every card is branded with no hosted asset

const STATS_WEBHOOK = (process.env.STATS_WEBHOOK || "").trim();
const FIREBASE = (process.env.FIREBASE_URL || "").trim().replace(/\/+$/, "");
const LOCALAPPDATA = process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local");
const FARM_DIR = process.env.FARM_DIR || path.join(LOCALAPPDATA, "Real", "workspace", "FFAutoFarm");
const ONLINE_LOCAL = 60;
const ONLINE_REMOTE = 150; // ~3 missed 45s refreshes
const JOIN_FRESH = 75; // a server id newer than this is current; older may have hopped
const VERIFIED_FRESH = 50; // hubs re-verify every 20s; a check older than this is no longer proof
const PRUNE_AGE = 6 * 3600; // drop DB nodes not seen in this long, so the roster stays real
const COLOR = 0x8f70ec;
const ZW = "​"; // zero-width spacer for a clean 3-column grid
const FF_PLACE = 6447798030; // Funky Friday place id (fallback when no live server is known)
// Roblox reports game names in each player's language ("Viernes funky"…), so the hub's own games get one
// canonical name, keyed by universe id then place id (same ids the hub uses to detect them).
const KNOWN_UNIVERSES = { 2404080894: "Funky Friday", 578392296: "Anime Battle Arena", 10765490774: "Climb For Animals Eggs", 3047037061: "bLockerman's Minesweeper" };
const KNOWN_PLACES = { 6447798030: "Funky Friday", 1458767429: "Anime Battle Arena", 85738654635245: "Climb For Animals Eggs", 7871169780: "bLockerman's Minesweeper", 6520999642: "Basically FNF: Remix" };
function gameName(d) {
  return KNOWN_UNIVERSES[Number(d.u)] || KNOWN_PLACES[Number(d.pl)] || (typeof d.g === "string" ? d.g : "");
}

// One consistent look for every card: branded author (with the bot's own avatar), subtle footer, timestamp.
function brand(embed, footer) {
  embed.setAuthor(BOT_ICON ? { name: "Catn Yapper", iconURL: BOT_ICON } : { name: "Catn Yapper" });
  embed.setFooter(BOT_ICON ? { text: footer ? footer + " · Catn Hub" : "Catn Hub", iconURL: BOT_ICON } : { text: footer ? footer + " · Catn Hub" : "Catn Hub" });
  return embed.setTimestamp();
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
      game: "Funky Friday", // the FFAutoFarm files only come from the Funky Friday script
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
      game: "Funky Friday", // channel STAT lines only come from the Funky Friday script
    };
  }
  return out;
}

// Every account in the Firebase DB (all machines) — one GET, no burial, no rate limit.
async function firebaseAccounts() {
  if (!FIREBASE) return {};
  const out = {};
  try {
    const res = await fetch(FIREBASE + "/accounts.json");
    if (!res.ok) return out;
    const data = await res.json();
    if (!data || typeof data !== "object") return out;
    const now = Math.floor(Date.now() / 1000);
    for (const d of Object.values(data)) {
      if (!d || typeof d.n !== "string") continue;
      const t = Number(d.t) || 0;
      out[d.n] = {
        name: d.n,
        wins: Number(d.w) || 0,
        points: Number(d.p) || 0,
        totalScore: Number(d.ts) || 0,
        scriptWins: Number(d.sw) || 0,
        scriptScore: Number(d.s) || 0,
        since: 0,
        lastSeen: t,
        online: now - t < ONLINE_REMOTE && d.st !== "left",
        run: d.rt ? { wins: Number(d.rw) || 0, score: Number(d.rs) || 0, startedAt: Number(d.rt) || 0 } : null,
        placeId: Number(d.pl) || 0,
        jobId: typeof d.j === "string" ? d.j : "",
        presence: typeof d.st === "string" ? d.st : "", // "in" (verified) / "hopping" / "left"; "" = older hub
        game: gameName(d),
      };
    }
  } catch (e) {
    /* ignore */
  }
  return out;
}

// All accounts everywhere: channel (legacy) < Firebase (global) < this PC's local files (freshest), merged by name.
// Short cache so a burst of commands / button clicks doesn't refetch Firebase + channel history each time.
let acctCache = null,
  acctCacheAt = 0;
const CACHE_MS = 10 * 1000;
async function allAccounts(fresh) {
  if (!fresh && acctCache && Date.now() - acctCacheAt < CACHE_MS) return acctCache;
  acctCache = await loadAccounts();
  acctCacheAt = Date.now();
  return acctCache;
}
function invalidateAccounts() {
  acctCache = null;
}

// Union of every source's fields; where two sources overlap, the most recently seen record wins.
function mergeAccounts(lists) {
  const byName = {};
  for (const list of lists)
    for (const a of list) {
      const k = a.name.toLowerCase();
      const prev = byName[k];
      byName[k] = !prev ? a : (a.lastSeen || 0) >= (prev.lastSeen || 0) ? { ...prev, ...a } : { ...a, ...prev };
    }
  return Object.values(byName).sort((a, b) => b.wins - a.wins);
}

async function loadAccounts() {
  const [remote, fb] = await Promise.all([remoteAccounts(), firebaseAccounts()]);
  return mergeAccounts([Object.values(remote), Object.values(fb), localAccounts()]);
}

function helpEmbed() {
  return brand(
    new EmbedBuilder()
      .setTitle("🎧 Catn Yapper")
      .setColor(COLOR)
      .setDescription("Your panel over the hub farms, across every game. Type **`/`** for slash commands with name autocomplete, or type them plainly (`catn ` / `!` prefix optional). _Admins only._")
      .addFields(
        {
          name: "📊 Stats",
          value: [
            "**`accounts`** — every account: wins, points, game & status",
            "**`online`** — only the ones online right now",
            "**`account <name>`** — full stats, with 🔄 Refresh / 🔗 Join buttons",
            "**`compare <name> <name>`** — two accounts side by side",
            "**`games`** — who's online, grouped by game",
            "**`search <game>`** — accounts in a given game",
            "**`top`** / `top points` / `top score` — leaderboards of our accounts",
            "**`global`** / `global weekly wins` — the game's real global boards, with our accounts' positions",
            "**`stats`** — grand totals · **`status`** — bot health",
          ].join("\n"),
        },
        {
          name: "🔗 Jump in",
          value: "**`join <name>`** — a copy-paste script **and a one-click link** into that account's live server, in any game",
        },
        { name: "🛠️ Admin", value: "**`prune`** — drop stale accounts now · **`remove <exact name>`** — forget one account" },
        { name: "💡 Tips", value: "Typos are fine — I'll suggest the closest names. Join buttons answer privately, so only you see the script." },
        { name: "🐱 Fun", value: "**`meow`** — a random cat gif · **`hi`** — I say bye" }
      )
  );
}

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
  const embed = new EmbedBuilder().setTitle("🎧 " + (title || "Hub accounts")).setColor(COLOR);
  for (const a of accts.slice(0, 25)) {
    let v = `${VERDICT_LABEL[verdict(a)]} · **${a.wins}** wins · **${abbrev(a.points)}** pts · ${abbrev(a.totalScore)} score`;
    if (a.game) v += ` · 🎮 ${esc(a.game)}`;
    v += `\n╰ script farmed: ${a.scriptWins} wins · ${abbrev(a.scriptScore)}`;
    if (a.online && a.run) v += ` · this run ${a.run.wins}w (${dur(now - a.run.startedAt)})`;
    embed.addFields({ name: "▸ " + esc(a.name), value: v });
  }
  const online = accts.filter((a) => a.online).length;
  let footer = `${accts.length} account${accts.length === 1 ? "" : "s"} · ${online} online`;
  if (accts.length > 25) footer += " · showing 25";
  return brand(embed, footer);
}

function accountEmbed(accts, query) {
  const a = findAccount(accts, query);
  if (!a) return null;
  const now = Math.floor(Date.now() / 1000);
  const embed = new EmbedBuilder()
    .setTitle((a.online ? "🟢 " : "⚪ ") + esc(a.name))
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
  embed.addFields({ name: "📡 Server", value: VERDICT_LABEL[verdict(a)], inline: true });
  if (a.game) embed.addFields({ name: "🎮 Game", value: esc(a.game), inline: true });
  const meta = [];
  if (a.lastSeen) meta.push(`Last seen <t:${a.lastSeen}:R>`);
  if (a.since) meta.push(`tracking since <t:${a.since}:D>`);
  if (meta.length) embed.addFields({ name: ZW, value: meta.join(" · ") });
  const peers = a.online && a.jobId ? samePeers(accts, a) : [];
  if (peers.length) embed.addFields({ name: "🧑‍🤝‍🧑 In the same server", value: peers.map(esc).join(", ").slice(0, 1000), inline: false });
  embed.addFields({ name: "🔗 Join", value: `\`join ${a.name}\`` });
  return brand(embed, a.online ? "online" : "offline");
}

// How much we trust an account's reported server:
//   verified: its hub confirmed it's connected to that server within the last ~50s
//   reported: an older hub (no check) reported it recently     stale: last confirmation is too old
//   hopping:  teleport in progress     left: kicked / disconnected     offline: not around
function verdict(a) {
  const age = a.lastSeen ? Math.floor(Date.now() / 1000) - a.lastSeen : Infinity;
  if (a.presence === "left") return "left";
  if (!a.online) return "offline";
  if (a.presence === "hopping") return "hopping";
  if (!a.jobId) return "offline";
  if (a.presence === "in") return age <= VERIFIED_FRESH ? "verified" : "stale";
  return age <= JOIN_FRESH ? "reported" : "stale";
}
const VERDICT_LABEL = {
  verified: "✅ verified in server",
  reported: "🟢 online (unverified)",
  stale: "⚠️ server unconfirmed",
  hopping: "🔄 switching servers",
  left: "❌ left / disconnected",
  offline: "⚪ offline",
};

// Exact name first, then a substring match.
function findAccount(accts, query) {
  const q = String(query || "").toLowerCase();
  if (!q) return null;
  return accts.find((x) => x.name.toLowerCase() === q) || accts.find((x) => x.name.toLowerCase().includes(q)) || null;
}

function editDistance(a, b) {
  const dp = Array.from({ length: a.length + 1 }, (_, i) => [i]);
  for (let j = 1; j <= b.length; j++) dp[0][j] = j;
  for (let i = 1; i <= a.length; i++)
    for (let j = 1; j <= b.length; j++)
      dp[i][j] = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
  return dp[a.length][b.length];
}

// "No account matching X" plus up to 3 close names, so a typo still gets you there.
function notFound(accts, query) {
  const q = String(query || "").toLowerCase();
  const close = accts
    .map((a) => ({ name: a.name, d: editDistance(q, a.name.toLowerCase()) }))
    .filter((x) => x.d <= Math.max(2, Math.floor(q.length / 3)))
    .sort((x, y) => x.d - y.d)
    .slice(0, 3)
    .map((x) => "`" + x.name + "`");
  return `No account matching "${esc(query)}".` + (close.length ? ` Did you mean ${close.join(", ")}?` : "");
}

// Two accounts side by side.
function compareEmbed(a, b) {
  const row = (label, f) => ({ name: label, value: `${esc(a.name)}: **${f(a)}**\n${esc(b.name)}: **${f(b)}**`, inline: true });
  const lead = a.wins === b.wins ? "Dead even on wins." : `${esc(a.wins > b.wins ? a.name : b.name)} leads by **${Math.abs(a.wins - b.wins)}** wins.`;
  return brand(
    new EmbedBuilder()
      .setTitle(`⚔️ ${esc(a.name)} vs ${esc(b.name)}`)
      .setColor(COLOR)
      .setDescription(lead)
      .addFields(
        row("🏆 Wins", (x) => x.wins),
        row("💰 Points", (x) => abbrev(x.points)),
        row("📈 Total score", (x) => abbrev(x.totalScore)),
        row("🤖 Script wins", (x) => x.scriptWins),
        row("🟢 Status", (x) => (x.online ? "online" : "offline")),
        row("🎮 Game", (x) => (x.game ? esc(x.game) : "—"))
      )
  );
}

// Buttons under cards. customIds carry the exact account name.
function cardButtons(name) {
  return new ActionRowBuilder().addComponents(
    new ButtonBuilder().setCustomId("acct:" + name).setLabel("Refresh").setEmoji("🔄").setStyle(ButtonStyle.Secondary),
    new ButtonBuilder().setCustomId("join:" + name).setLabel("Join").setEmoji("🔗").setStyle(ButtonStyle.Primary)
  );
}
function joinButtons(name) {
  return new ActionRowBuilder().addComponents(
    new ButtonBuilder().setCustomId("joinr:" + name).setLabel("Refresh server").setEmoji("🔄").setStyle(ButtonStyle.Secondary)
  );
}

// Online accounts sitting in the same server instance as `a` (handy for duo/group joins).
function samePeers(accts, a) {
  const here = (x) => verdict(x) === "verified" || verdict(x) === "reported";
  return accts.filter((x) => here(x) && x.jobId === a.jobId && x.name.toLowerCase() !== a.name.toLowerCase()).map((x) => x.name);
}

// Active accounts grouped by the game they're in.
function gamesEmbed(accts) {
  const online = accts.filter((a) => a.online);
  if (!online.length) return null;
  const by = {};
  for (const a of online) {
    const g = a.game || "Unknown game";
    (by[g] = by[g] || []).push(a.name);
  }
  const lines = Object.entries(by)
    .sort((x, y) => y[1].length - x[1].length)
    .map(([g, names]) => `🎮 **${esc(g)}** — ${names.length}\n${names.slice(0, 15).map(esc).join(", ")}${names.length > 15 ? ` +${names.length - 15} more` : ""}`);
  return brand(new EmbedBuilder().setTitle("🎮 Active games").setColor(COLOR).setDescription(lines.join("\n\n")));
}

// Remove accounts not seen in a while, so lists and totals reflect who's actually around.
async function pruneStale() {
  if (!FIREBASE) return;
  try {
    const res = await fetch(FIREBASE + "/accounts.json");
    if (!res.ok) return;
    const data = await res.json();
    if (!data || typeof data !== "object") return;
    const cutoff = Math.floor(Date.now() / 1000) - PRUNE_AGE;
    for (const [key, d] of Object.entries(data)) {
      if (!d || (Number(d.t) || 0) < cutoff) {
        await fetch(FIREBASE + "/accounts/" + encodeURIComponent(key) + ".json", { method: "DELETE" });
      }
    }
  } catch (e) {
    /* ignore */
  }
}

const TOP_METRICS = {
  wins: { key: "wins", label: "wins", title: "🏆 Top by wins", fmt: (n) => String(n) },
  points: { key: "points", label: "points", title: "💰 Top by points", fmt: abbrev },
  score: { key: "totalScore", label: "score", title: "📈 Top by total score", fmt: abbrev },
};
function topEmbed(accts, metric) {
  if (!accts.length) return null;
  const m = TOP_METRICS[metric] || TOP_METRICS.wins;
  const top = [...accts].sort((a, b) => (b[m.key] || 0) - (a[m.key] || 0)).slice(0, 10);
  const medal = ["🥇", "🥈", "🥉"];
  const lines = top.map((a, i) => `${medal[i] || `\`${i + 1}.\``} **${esc(a.name)}** — ${m.fmt(a[m.key] || 0)} ${m.label} ${a.online ? "🟢" : ""}`);
  return brand(new EmbedBuilder().setTitle(m.title).setColor(0xffd166).setDescription(lines.join("\n")));
}

// Funky Friday's global lobby boards (weekly wins, all-time score...), as read in-game by the FF script:
// boards/ff = { t, by, boards: { WeeklyWins: { title, rows: [{ r, n, v }] }, ... } }
async function globalBoards() {
  if (!FIREBASE) return null;
  try {
    const res = await fetch(FIREBASE + "/boards/ff.json");
    const d = res.ok ? await res.json() : null;
    if (!d || !d.boards || typeof d.boards !== "object") return null;
    const boards = Object.values(d.boards).filter((b) => b && b.title && Array.isArray(b.rows));
    return boards.length ? { t: d.t, by: d.by, boards } : null;
  } catch (e) {
    return null;
  }
}

// Overview of every board (top 5 + where our accounts sit), or one board in full when `which` matches its title.
function globalEmbed(data, accts, which) {
  const ours = new Set(accts.map((a) => a.name.toLowerCase()));
  const isOurs = (n) => ours.has(String(n || "").toLowerCase());
  const row = (x) => `${["🥇", "🥈", "🥉"][x.r - 1] || `\`#${x.r}\``} ${isOurs(x.n) ? "🐱 **" + esc(x.n) + "**" : esc(x.n)} — ${esc(x.v)}`;
  const boards = data.boards;
  const e = new EmbedBuilder().setColor(0xffd166);
  const pick = which ? boards.find((b) => b.title.toLowerCase().includes(which)) : null;
  if (which && !pick) return null;
  if (pick) {
    e.setTitle("🌍 " + esc(pick.title)).setDescription(pick.rows.slice(0, 25).map(row).join("\n").slice(0, 4000) || "Empty board.");
  } else {
    e.setTitle("🌍 Funky Friday global boards");
    for (const b of boards.slice(0, 12)) {
      const top = b.rows.slice(0, 5).map(row);
      const mine = b.rows.slice(5).filter((x) => isOurs(x.n)).map(row);
      e.addFields({ name: esc(b.title), value: top.concat(mine).join("\n").slice(0, 1024) || "Empty board.", inline: true });
    }
  }
  const placed = [];
  for (const b of pick ? [pick] : boards) for (const x of b.rows) if (isOurs(x.n)) placed.push(`**${esc(x.n)}** #${x.r} ${esc(b.title)}`);
  e.addFields({ name: "🐱 Our accounts on the boards", value: (placed.join("\n") || "None of our accounts are on a board yet.").slice(0, 1024) });
  if (data.t) e.addFields({ name: "Read", value: `<t:${data.t}:R>${data.by ? " by " + esc(data.by) : ""}`, inline: true });
  return brand(e, "global boards");
}

// Accounts list split into Discord-safe pages (25 fields each, up to 10 embeds).
function accountsEmbeds(accts, title) {
  if (!accts.length) return [];
  const pages = [];
  for (let i = 0; i < accts.length && pages.length < 10; i += 25) {
    const e = accountsEmbed(accts.slice(i, i + 25), title);
    if (e) pages.push(e);
  }
  return pages;
}

function statusEmbed(accts) {
  const online = accts.filter((a) => a.online).length;
  const games = new Set(accts.filter((a) => a.online && a.game).map((a) => a.game)).size;
  return brand(
    new EmbedBuilder()
      .setTitle("🩺 Catn Yapper status")
      .setColor(0x57f287)
      .addFields(
        { name: "Uptime", value: dur(Math.floor(Date.now() / 1000) - START_TS), inline: true },
        { name: "Accounts tracked", value: String(accts.length), inline: true },
        { name: "Online now", value: String(online), inline: true },
        { name: "Active games", value: String(games), inline: true },
        { name: "Store", value: FIREBASE ? "Firebase DB" : STATS_WEBHOOK ? "Discord channel" : "local only", inline: true },
        { name: ZW, value: ZW, inline: true }
      )
  );
}

// Only server admins (or the owner) get a reply.
function isAdmin(msg) {
  if (!msg.guild || !msg.member) return false;
  if (msg.guild.ownerId === msg.author.id) return true;
  return msg.member.permissions.has(PermissionsBitField.Flags.Administrator);
}

// Delete one account's node from the DB (admin cleanup).
async function removeAccount(name) {
  if (!FIREBASE) return false;
  try {
    const res = await fetch(FIREBASE + "/accounts/" + encodeURIComponent(name) + ".json", { method: "DELETE" });
    return res.ok;
  } catch (e) {
    return false;
  }
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
  const a = findAccount(accts, query);
  if (!a) return null;
  const where = a.game ? `**${esc(a.game)}**` : "their game";
  const v = verdict(a);
  const instance = `game:GetService("TeleportService"):TeleportToPlaceInstance(${a.placeId || FF_PLACE}, "${a.jobId}")`;
  let script = null,
    note;
  if (v === "hopping") {
    note = `🔄 **${esc(a.name)} is switching servers right now.** Hit **Refresh server** in a few seconds to get the new one.`;
  } else if (v === "verified") {
    script = instance;
    note = `✅ **Verified in this server** <t:${a.lastSeen}:R> (the hub re-checks every 20s). Paste this in your executor to drop into ${where}.`;
  } else if (v === "reported") {
    script = instance;
    note = `This is the server the account last reported <t:${a.lastSeen}:R>. Its hub is an older version that can't confirm it's still there, so this may fail.`;
  } else if (v === "stale") {
    script = instance;
    note = `⚠️ This server was last confirmed <t:${a.lastSeen}:R> — the account may have **hopped or left since**. Hit **Refresh server** to check again.`;
  } else if (v === "left") {
    script = `game:GetService("TeleportService"):Teleport(${a.placeId || FF_PLACE})`;
    note = `❌ **${esc(a.name)} left or got disconnected**, so there's no server to join. This joins ${where} on any server instead.`;
  } else if (a.placeId) {
    script = `game:GetService("TeleportService"):Teleport(${a.placeId})`;
    note = `This account **isn't online right now**, so there's no live server. This joins ${where} on any server instead.`;
  } else {
    script = `game:GetService("TeleportService"):Teleport(${FF_PLACE})`;
    note = "This account hasn't reported a game yet (it needs the updated hub). This joins any Funky Friday server for now.";
  }
  const embed = new EmbedBuilder()
    .setTitle("🔗 Join " + esc(a.name))
    .setColor(v === "verified" ? 0x57f287 : v === "left" ? 0xed4245 : v === "hopping" || v === "stale" ? 0xfee75c : COLOR)
    .setDescription(script ? `${note}\n\`\`\`lua\n${script}\n\`\`\`` : note);
  if ((v === "verified" || v === "reported" || v === "stale") && a.placeId)
    embed.addFields({
      name: "▶ One-click",
      value: `[Launch Roblox into this server](https://www.roblox.com/games/start?placeId=${a.placeId}&gameInstanceId=${a.jobId})`,
    });
  const peers = v === "verified" || v === "reported" ? samePeers(accts, a) : [];
  if (peers.length) embed.addFields({ name: "🧑‍🤝‍🧑 Also here", value: peers.map(esc).join(", ").slice(0, 1000) });
  return brand(embed, a.game || (a.online ? "online" : "offline"));
}

const client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.MessageContent],
});

client.once(Events.ClientReady, (c) => {
  BOT_ICON = c.user.displayAvatarURL({ size: 128 });
  console.log("online as " + c.user.tag + " | db: " + (FIREBASE ? "firebase" : STATS_WEBHOOK ? "channel" : "local only") + " | admins only | farm dir: " + FARM_DIR);
  c.application.commands.set(SLASH.map((s) => s.toJSON())).then(
    (cmds) => console.log("slash commands registered: " + cmds.size),
    (e) => console.error("slash register failed:", e.message)
  );
  if (FIREBASE) {
    pruneStale();
    setInterval(() => pruneStale().then(invalidateAccounts), 30 * 60 * 1000); // keep the roster tidy
  }
});

// Resolve a text command into messages to send. Pure except for the data/network calls it awaits — reused by tests.
async function handleCommand(word, rest) {
  switch (word) {
    case "accounts":
    case "list": {
      const pages = accountsEmbeds(await allAccounts());
      return pages.length ? { embeds: pages } : "No accounts reported yet.";
    }
    case "online": {
      const pages = accountsEmbeds((await allAccounts()).filter((a) => a.online), "Accounts online now");
      return pages.length ? { embeds: pages } : "No accounts are online right now.";
    }
    case "games": {
      const e = gamesEmbed(await allAccounts());
      return e ? { embeds: [e] } : "No accounts are online right now.";
    }
    case "search":
    case "find": {
      if (!rest) return "Usage: `search <game name>`";
      const hits = (await allAccounts()).filter((a) => (a.game || "").toLowerCase().includes(rest));
      const pages = accountsEmbeds(hits, `Accounts in "${rest}"`);
      return pages.length ? { embeds: pages } : `No accounts in a game matching "${rest}".`;
    }
    case "account":
    case "acc": {
      if (!rest) return "Usage: `account <name>`";
      const accts = await allAccounts();
      const a = findAccount(accts, rest);
      if (!a) return notFound(accts, rest);
      return { embeds: [accountEmbed(accts, a.name)], components: [cardButtons(a.name)] };
    }
    case "join": {
      if (!rest) return "Usage: `join <name>`";
      const accts = await allAccounts(true); // never hand out a cached server
      const a = findAccount(accts, rest);
      if (!a) return notFound(accts, rest);
      return { embeds: [joinEmbed(accts, a.name)], components: [joinButtons(a.name)] };
    }
    case "compare":
    case "vs": {
      const [x, y] = rest.split(/\s+/);
      if (!x || !y) return "Usage: `compare <name> <name>`";
      const accts = await allAccounts();
      const a = findAccount(accts, x),
        b = findAccount(accts, y);
      if (!a) return notFound(accts, x);
      if (!b) return notFound(accts, y);
      return { embeds: [compareEmbed(a, b)] };
    }
    case "top":
    case "leaderboard":
    case "lb": {
      const metric = rest.includes("point") ? "points" : rest.includes("score") ? "score" : "wins";
      const e = topEmbed(await allAccounts(), metric);
      return e ? { embeds: [e] } : "No accounts reported yet.";
    }
    case "global":
    case "boards":
    case "board":
    case "glb": {
      const data = await globalBoards();
      if (!data) return "No global board data yet — it appears once an account running the FF script has been in the lobby.";
      const e = globalEmbed(data, await allAccounts(), rest);
      return e ? { embeds: [e] } : `No board matching "${rest}". Boards: ${data.boards.map((b) => "`" + b.title + "`").join(", ")}`;
    }
    case "stats":
    case "totals":
      return { embeds: [statsEmbed(await allAccounts())] };
    case "status":
    case "ping":
      return { embeds: [statusEmbed(await allAccounts())] };
    case "prune": {
      await pruneStale();
      invalidateAccounts();
      return { embeds: [statusEmbed(await allAccounts())] };
    }
    case "remove":
    case "forget": {
      if (!rest) return "Usage: `remove <exact name>`";
      const accts = await allAccounts();
      const a = accts.find((x) => x.name.toLowerCase() === rest); // exact only: never delete on a partial match
      if (!a) return notFound(accts, rest) + " (`remove` needs the exact name.)";
      const ok = await removeAccount(a.name);
      invalidateAccounts();
      return ok ? `Removed **${esc(a.name)}** from the roster.` : `Couldn't remove "${esc(a.name)}" (no DB, or request failed).`;
    }
    case "help":
    case "commands":
    case "?":
      return { embeds: [helpEmbed()] };
    case "hi":
      return "bye";
    case "meow":
      return await catGif();
    default:
      return null;
  }
}

client.on(Events.MessageCreate, async (msg) => {
  if (msg.author.bot) return;
  if (!isAdmin(msg)) return; // admins (and the owner) only
  const text = msg.content.trim().toLowerCase().replace(/^!\s*/, "").replace(/^catn\s+/, "");
  const word = text.split(/\s+/)[0] || "";
  const rest = text.slice(word.length).trim();
  let reply;
  try {
    reply = await handleCommand(word, rest);
  } catch (e) {
    console.error("command failed:", e.message);
    reply = "Something went wrong running that — try again in a moment.";
  }
  if (!reply) return;
  try {
    if (typeof msg.channel.sendTyping === "function") msg.channel.sendTyping().catch(() => {});
    await msg.channel.send(reply);
  } catch (e) {
    console.error("send failed:", e.message);
  }
});

function interactionIsAdmin(i) {
  if (!i.inGuild()) return false;
  if (i.guild && i.guild.ownerId === i.user.id) return true;
  return !!(i.memberPermissions && i.memberPermissions.has(PermissionsBitField.Flags.Administrator));
}

// Slash commands: the same commands as text, with account/game names that autocomplete.
// Hidden from non-admins by default; interactionIsAdmin still checks, since server owners can override that.
const ADMIN_PERM = PermissionsBitField.Flags.Administrator;
const slash = (name, desc) => new SlashCommandBuilder().setName(name).setDescription(desc).setDefaultMemberPermissions(ADMIN_PERM).setDMPermission(false);
const nameOpt = (o, n = "name", d = "Roblox account name") => o.setName(n).setDescription(d).setRequired(true).setAutocomplete(true);
const SLASH = [
  slash("accounts", "Every account: wins, points, game & status"),
  slash("online", "Only the accounts online right now"),
  slash("games", "Who's online, grouped by game"),
  slash("search", "Accounts in a given game").addStringOption((o) => nameOpt(o, "game", "Game name")),
  slash("account", "Full stats for one account").addStringOption((o) => nameOpt(o)),
  slash("join", "Script + one-click link into an account's live server (only you see it)").addStringOption((o) => nameOpt(o)),
  slash("compare", "Two accounts side by side").addStringOption((o) => nameOpt(o, "first", "First account")).addStringOption((o) => nameOpt(o, "second", "Second account")),
  slash("top", "Leaderboard").addStringOption((o) =>
    o.setName("by").setDescription("What to rank by (default wins)").addChoices({ name: "wins", value: "wins" }, { name: "points", value: "points" }, { name: "score", value: "score" })
  ),
  slash("global", "Funky Friday's global boards (weekly wins, score...) and where our accounts sit").addStringOption((o) =>
    o.setName("board").setDescription("One board in full (leave empty for all)").setAutocomplete(true)
  ),
  slash("stats", "Grand totals across every account"),
  slash("status", "Bot health"),
  slash("prune", "Drop stale accounts now"),
  slash("remove", "Forget one account (exact name)").addStringOption((o) => nameOpt(o)),
  slash("help", "What I can do"),
  slash("meow", "A random cat gif"),
];

// Up to 25 autocomplete picks: names starting with what was typed first, then ones containing it.
function suggest(names, typed) {
  const q = String(typed || "").toLowerCase();
  const uniq = [...new Set(names.filter(Boolean))];
  const starts = uniq.filter((n) => n.toLowerCase().startsWith(q));
  const has = uniq.filter((n) => !n.toLowerCase().startsWith(q) && n.toLowerCase().includes(q));
  return starts.concat(has).slice(0, 25).map((n) => ({ name: n.slice(0, 100), value: n.slice(0, 100) }));
}

// Turn a slash interaction into the text command's (word, rest), so both share handleCommand.
function slashToText(i) {
  const o = i.options;
  const word = i.commandName;
  const rest =
    word === "compare" ? `${o.getString("first")} ${o.getString("second")}`
    : word === "search" ? o.getString("game")
    : word === "top" ? o.getString("by") || ""
    : word === "global" ? o.getString("board") || ""
    : ["account", "join", "remove"].includes(word) ? o.getString("name")
    : "";
  return { word, rest: String(rest || "").trim().toLowerCase() };
}

client.on(Events.InteractionCreate, async (i) => {
  if (i.isAutocomplete()) {
    if (!interactionIsAdmin(i)) return void i.respond([]).catch(() => {});
    try {
      const f = i.options.getFocused(true);
      const accts = await allAccounts(); // cached is fine for suggestions, and keeps us under Discord's 3s limit
      const names =
        f.name === "board" ? ((await globalBoards()) || { boards: [] }).boards.map((b) => b.title)
        : f.name === "game" ? accts.map((a) => a.game)
        : accts.map((a) => a.name);
      await i.respond(suggest(names, f.value));
    } catch (e) {
      i.respond([]).catch(() => {});
    }
    return;
  }
  if (!i.isChatInputCommand()) return;
  if (!interactionIsAdmin(i)) return void i.reply({ content: "Admins only.", ephemeral: true }).catch(() => {});
  const { word, rest } = slashToText(i);
  const ephemeral = word === "join"; // the join script is for you, not the channel
  try {
    await i.deferReply({ ephemeral });
    const reply = await handleCommand(word, rest);
    await i.editReply(reply || "Unknown command.");
  } catch (e) {
    console.error("slash failed:", e.message);
    (i.deferred ? i.editReply("Something went wrong running that — try again in a moment.") : i.reply({ content: "That didn't work.", ephemeral: true })).catch(() => {});
  }
});

// Buttons: Refresh redraws the card in place, Join answers privately (only the clicker sees the script).
client.on(Events.InteractionCreate, async (i) => {
  if (!i.isButton()) return;
  if (!interactionIsAdmin(i)) return void i.reply({ content: "Admins only.", ephemeral: true }).catch(() => {});
  const cut = i.customId.indexOf(":");
  const kind = i.customId.slice(0, cut),
    name = i.customId.slice(cut + 1);
  try {
    const accts = await allAccounts(true); // buttons always show live data
    const a = findAccount(accts, name);
    if (kind === "acct") {
      return void (await i.update(a ? { embeds: [accountEmbed(accts, a.name)], components: [cardButtons(a.name)] } : { content: `**${esc(name)}** isn't in the roster anymore.`, embeds: [], components: [] }));
    }
    if (kind === "join") {
      return void (await i.reply(a ? { embeds: [joinEmbed(accts, a.name)], components: [joinButtons(a.name)], ephemeral: true } : { content: `**${esc(name)}** isn't in the roster anymore.`, ephemeral: true }));
    }
    if (kind === "joinr") {
      return void (await i.update(a ? { embeds: [joinEmbed(accts, a.name)], components: [joinButtons(a.name)] } : { content: `**${esc(name)}** isn't in the roster anymore.`, embeds: [], components: [] }));
    }
  } catch (e) {
    console.error("button failed:", e.message);
    if (!i.replied && !i.deferred) i.reply({ content: "That didn't work — try again in a moment.", ephemeral: true }).catch(() => {});
  }
});

// Stay up overnight: log instead of dying on a stray network error.
client.on("error", (e) => console.error("client error:", e && e.message));
process.on("unhandledRejection", (e) => console.error("unhandled rejection:", e && e.message ? e.message : e));
process.on("uncaughtException", (e) => console.error("uncaught exception:", e && e.message ? e.message : e));

if (TEST) {
  module.exports = {
    abbrev, dur, esc, samePeers, accountsEmbed, accountsEmbeds, accountEmbed, topEmbed, statsEmbed, gamesEmbed, joinEmbed,
    statusEmbed, isAdmin, interactionIsAdmin, handleCommand, brand, helpEmbed, findAccount, notFound, editDistance,
    compareEmbed, cardButtons, joinButtons, mergeAccounts, gameName, verdict, SLASH, suggest, slashToText, globalEmbed,
  };
} else {
  client.login(TOKEN).catch((e) => {
    console.error("Login failed. Check the token, and that Message Content Intent is on.", e.message);
    process.exit(1);
  });
}
