// Run with: BOT_TEST=1 node test.js   (no token / network needed — exercises the pure render + gate logic)
process.env.BOT_TEST = "1";
const B = require("./index.js");

let pass = 0,
  fail = 0;
function ok(cond, name) {
  if (cond) {
    pass++;
  } else {
    fail++;
    console.error("  FAIL:", name);
  }
}
const now = Math.floor(Date.now() / 1000);
const acct = (o) => Object.assign({ name: "x", wins: 0, points: 0, totalScore: 0, scriptWins: 0, scriptScore: 0, since: 0, lastSeen: now, online: true, run: null, placeId: 0, jobId: "", game: "" }, o);
const desc = (e) => (e && e.data && (e.data.description || "")) || "";
const fields = (e) => (e && e.data && e.data.fields) || [];
const hasField = (e, re) => fields(e).some((f) => re.test(f.name + " " + f.value));

// --- number + duration formatting ---
ok(B.abbrev(999) === "999", "abbrev small");
ok(B.abbrev(1234) === "1.23K", "abbrev K");
ok(B.abbrev(1000000) === "1M", "abbrev M");
ok(B.abbrev(2500000000) === "2.5B", "abbrev B");
ok(B.dur(45) === "45s", "dur seconds");
ok(B.dur(3661).startsWith("1h"), "dur hours");

// --- join: live (fresh) ---
const live = acct({ name: "Viper", placeId: 6447798030, jobId: "job-123", game: "Funky Friday", lastSeen: now - 10 });
const je = B.joinEmbed([live], "viper");
ok(/TeleportToPlaceInstance\(6447798030, "job-123"\)/.test(desc(je)), "join live script");
ok(hasField(je, /One-click/) && hasField(je, /gameInstanceId=job-123/), "join one-click link");

// --- join: stale (online but old) ---
const stale = acct({ name: "Old", placeId: 1, jobId: "jj", lastSeen: now - 600 });
ok(/hopped since/.test(desc(B.joinEmbed([stale], "old"))), "join stale warns");

// --- join: offline with place ---
const off = acct({ name: "Off", placeId: 55, jobId: "", online: false, lastSeen: now - 99999 });
const offe = B.joinEmbed([off], "off");
ok(/Teleport\(55\)/.test(desc(offe)) && /isn't online/.test(desc(offe)), "join offline fallback");

// --- join: no place (legacy) ---
ok(/Teleport\(6447798030\)/.test(desc(B.joinEmbed([acct({ name: "Leg", online: false })], "leg"))), "join legacy fallback");

// --- join: peers in same server ---
const p1 = acct({ name: "Duo1", placeId: 7, jobId: "same", game: "G" });
const p2 = acct({ name: "Duo2", placeId: 7, jobId: "same", game: "G" });
ok(hasField(B.joinEmbed([p1, p2], "duo1"), /Also here[\s\S]*Duo2/), "join peers");
ok(B.samePeers([p1, p2], p1).includes("Duo2"), "samePeers");

// --- account card shows game + peers ---
const ae = B.accountEmbed([p1, p2], "duo1");
ok(hasField(ae, /Game[\s\S]*G/), "account shows game");
ok(hasField(ae, /same server[\s\S]*Duo2/), "account shows peers");

// --- lists + paging ---
ok(B.accountsEmbeds([]).length === 0, "empty list -> no pages");
const many = Array.from({ length: 40 }, (_, i) => acct({ name: "a" + i, wins: i }));
ok(B.accountsEmbeds(many).length === 2, "40 accounts -> 2 pages");

// --- games grouping ---
const ge = B.gamesEmbed([acct({ name: "g1", game: "Funky Friday" }), acct({ name: "g2", game: "Funky Friday" }), acct({ name: "g3", game: "ABA" })]);
ok(/Funky Friday/.test(desc(ge)) && /ABA/.test(desc(ge)), "games grouped");

// --- top metrics ---
ok(/by wins/.test(B.topEmbed([live], "wins").data.title), "top wins title");
ok(/by points/.test(B.topEmbed([live], "points").data.title), "top points title");
ok(/total score/.test(B.topEmbed([live], "score").data.title), "top score title");

// --- status ---
ok(hasField(B.statusEmbed([live, off]), /Uptime/), "status uptime");

// --- admin gate ---
const mk = (guild, member, admin, owner) => ({ guild: guild ? { ownerId: owner || "owner" } : null, member: member ? { permissions: { has: () => admin } } : null, author: { id: "u1" } });
ok(B.isAdmin(mk(true, true, true)) === true, "admin allowed");
ok(B.isAdmin(mk(true, true, false)) === false, "non-admin blocked");
ok(B.isAdmin(mk(true, true, false, "u1")) === true, "owner allowed");
ok(B.isAdmin(mk(false, false, true)) === false, "DM blocked");

// --- markdown safety: underscores in usernames must be escaped ---
ok(B.esc("Eloise_QwQ_") === "Eloise\\_QwQ\\_", "esc underscores");
const md = B.accountEmbed([acct({ name: "a_b_c" })], "a_b_c");
ok(/a\\_b\\_c/.test(md.data.title), "card title escaped");

// --- lookup + did-you-mean ---
const roster = [acct({ name: "ViperbmRumbleZ180266" }), acct({ name: "abtestas24" })];
ok(B.findAccount(roster, "ABTESTAS24").name === "abtestas24", "find exact, case-insensitive");
ok(B.findAccount(roster, "viper").name === "ViperbmRumbleZ180266", "find substring");
ok(B.findAccount(roster, "") === null, "find empty -> null");
ok(/Did you mean `abtestas24`/.test(B.notFound(roster, "abtestaz24")), "did-you-mean typo");
ok(!/Did you mean/.test(B.notFound(roster, "zzzzzzzzzz")), "no wild suggestions");
ok(B.editDistance("kitten", "sitting") === 3, "edit distance");

// --- compare ---
const ce = B.compareEmbed(acct({ name: "A", wins: 10 }), acct({ name: "B", wins: 4 }));
ok(/A leads by \*\*6\*\* wins/.test(desc(ce)), "compare lead");
ok(fields(ce).length === 6, "compare rows");

// --- buttons carry the exact name ---
const btn = B.cardButtons("abtestas24").toJSON();
ok(btn.components[0].custom_id === "acct:abtestas24" && btn.components[1].custom_id === "join:abtestas24", "card buttons ids");
ok(B.joinButtons("x").toJSON().components[0].custom_id === "joinr:x", "join button id");

// --- interaction admin gate ---
const mki = (inGuild, admin, owner) => ({ inGuild: () => inGuild, guild: { ownerId: owner || "owner" }, user: { id: "u1" }, memberPermissions: { has: () => admin } });
ok(B.interactionIsAdmin(mki(true, true)) === true, "button admin allowed");
ok(B.interactionIsAdmin(mki(true, false)) === false, "button non-admin blocked");
ok(B.interactionIsAdmin(mki(false, true)) === false, "button DM blocked");

// --- help renders and is within Discord limits ---
const h = B.helpEmbed();
ok(h.data.fields.every((f) => f.value.length <= 1024) && JSON.stringify(h.data).length < 6000, "help within limits");

// --- every embed we build serializes (catches invalid field shapes) ---
for (const [n, e] of [["account", md], ["compare", ce], ["help", h], ["status", B.statusEmbed(roster)], ["games", ge], ["join", je]]) {
  let good = true;
  try { e.toJSON(); } catch (err) { good = false; }
  ok(good, n + " serializes");
}

// --- merge: fresher source wins, fields are unioned ---
const staleLocal = acct({ name: "Viper", lastSeen: now - 3600, online: false, jobId: "old", game: "Funky Friday", scriptWins: 777 });
const freshFb = acct({ name: "viper", lastSeen: now - 5, online: true, jobId: "new", game: "Other Game", wins: 905 });
const m1 = B.mergeAccounts([[freshFb], [staleLocal]]); // stale local layered LAST must not win
ok(m1.length === 1, "merge dedupes case-insensitively");
ok(m1[0].jobId === "new" && m1[0].online === true && m1[0].game === "Other Game", "merge: fresh beats stale even when layered first");
const m2 = B.mergeAccounts([[staleLocal], [freshFb]]);
ok(m2[0].jobId === "new" && m2[0].online === true, "merge: fresh beats stale layered last");
const m3 = B.mergeAccounts([[acct({ name: "A", wins: 1 }), acct({ name: "B", wins: 9 })]]);
ok(m3[0].name === "B", "merge sorts by wins desc");

// --- canonical game names (players report localized names) ---
ok(B.gameName({ u: 2404080894, g: "[Acércate] Viernes funky" }) === "Funky Friday", "canonical by universe");
ok(B.gameName({ pl: 6520999642, g: "whatever" }) === "Basically FNF: Remix", "canonical by place");
ok(B.gameName({ u: 1, pl: 2, g: "Slap Battles" }) === "Slap Battles", "unknown game keeps reported name");
ok(B.gameName({}) === "", "no game -> empty");

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
