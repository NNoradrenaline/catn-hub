// Catn Yapper - a standalone Discord bot you run on your own PC (node index.js).
// It stays online while this program runs, independent of Roblox, and handles the chat commands.
// Farm commands (start/stop/status/...) are NOT here - those live in the Roblox script and only work
// while a Catn Hub account is in-game. This bot just lists them in `help`.
require("dotenv").config();
const { Client, GatewayIntentBits, Events } = require("discord.js");

const TOKEN = process.env.DISCORD_TOKEN;
if (!TOKEN) {
  console.error("No token. Copy .env.example to .env and put your bot token in DISCORD_TOKEN.");
  process.exit(1);
}

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent, // turn on "Message Content Intent" in the Developer Portal too
  ],
});

const HELP = [
  "**Catn Yapper**",
  "`hi` - I say bye",
  "`meow` - a random cat gif",
  "`help` - this list",
  "",
  "Farm commands (only while a Catn Hub account is in-game): `start`, `stop`, `status`, `stats`, `rejoin`",
].join("\n");

// A random cat gif URL that Discord will embed. The Cat API gives a direct .gif link; cataas is the fallback.
async function catGif() {
  try {
    const res = await fetch("https://api.thecatapi.com/v1/images/search?mime_types=gif&limit=1");
    const data = await res.json();
    if (Array.isArray(data) && data[0] && data[0].url) return data[0].url;
  } catch (e) {
    /* fall through to the fallback */
  }
  return "https://cataas.com/cat/gif?" + Date.now();
}

client.once(Events.ClientReady, (c) => console.log("online as " + c.user.tag));

client.on(Events.MessageCreate, async (msg) => {
  if (msg.author.bot) return;
  // accept an optional "catn" or "!" prefix, then take the first word
  const text = msg.content.trim().toLowerCase().replace(/^!\s*/, "").replace(/^catn\s+/, "");
  const word = text.split(/\s+/)[0] || "";
  try {
    if (word === "hi") {
      await msg.channel.send("bye");
    } else if (word === "meow") {
      await msg.channel.send(await catGif());
    } else if (word === "help" || word === "commands" || word === "?") {
      await msg.channel.send(HELP);
    }
  } catch (e) {
    // missing permissions in that channel, etc. - ignore so the bot keeps running
    console.error("send failed:", e.message);
  }
});

client.login(TOKEN).catch((e) => {
  console.error("Login failed. Check the token, and that Message Content Intent is on.", e.message);
  process.exit(1);
});
