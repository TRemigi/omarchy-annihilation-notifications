// Tests the pure functions of NotificationLogic.js (the real file, in node). In P0 the file is
// Omarchy's own, so these are mostly a regression net for what this fork must keep doing: the
// DND rules, the state-file names and format, lifetimes, and placement. They also fail loudly if
// a merge from upstream changes one of those. Each check was confirmed to fail when broken on purpose.
//   usage: node test/logic-test.js
const path = require("path");
const L = require(path.join(__dirname, "..", "NotificationLogic.js"));
let pass = 0, fail = 0;
const eq = (name, got, want) => { const ok = JSON.stringify(got) === JSON.stringify(want); ok ? pass++ : (fail++, console.log("FAIL", name, "got", JSON.stringify(got), "want", JSON.stringify(want))); };
const CRITICAL = 2, NORMAL = 1;

// Do Not Disturb: omarchy's own toasts always show; critical notify-send shows; nothing else does.
eq("omarchy-action bypasses DND", L.shouldBypassDnd({ appName: "omarchy-action", urgency: 0 }, CRITICAL), true);
eq("critical notify-send bypasses DND", L.shouldBypassDnd({ appName: "notify-send", urgency: CRITICAL }, CRITICAL), true);
eq("normal notify-send does not", L.shouldBypassDnd({ appName: "notify-send", urgency: NORMAL }, CRITICAL), false);
eq("a chat app cannot force it with critical", L.shouldBypassDnd({ appName: "Signal", urgency: CRITICAL }, CRITICAL), false);
eq("no notification at all does not", [L.shouldBypassDnd(null, CRITICAL), L.shouldBypassDnd({}, CRITICAL)], [false, false]);
eq("ephemeral apps", ["notify-send", "omarchy-action", "Signal", "", undefined].map(L.isEphemeralApp), [true, true, false, false, false]);

// State-file names: <timestamp>-<originalId>.json
eq("file name", L.popupFileName({ timestamp: 1793381825465, originalId: 2 }), "1793381825465-2.json");
eq("file name defaults", L.popupFileName({}), "0-0.json");
eq("image stem", L.imageStem({ timestamp: 5, originalId: 7 }), "5-7");

// Where the toast column sits: top right, clear of a bar on the top or right edge only.
eq("bar on top", L.popupPlacement("top", 30, 5).margins, { top: 30, bottom: 5, left: 5, right: 5 });
eq("bar on the right", L.popupPlacement("right", 40, 5).margins, { top: 5, bottom: 5, left: 5, right: 40 });
eq("bar on the left or bottom does not move it", [L.popupPlacement("left", 40, 5).margins, L.popupPlacement("bottom", 40, 5).margins],
  [{ top: 5, bottom: 5, left: 5, right: 5 }, { top: 5, bottom: 5, left: 5, right: 5 }]);
eq("anchored top right", L.popupPlacement("top", 0, 0).anchors, { top: true, bottom: false, left: false, right: true });
eq("junk falls back to the top bar and zero", L.popupPlacement(undefined, "x", NaN).margins, { top: 0, bottom: 0, left: 0, right: 0 });

// Restoring toasts after a shell restart.
eq("a toast past its lifetime is not restored", L.popupExpired({ timestamp: 1000 }, 8000, 9000), true);
eq("one inside it is", L.popupExpired({ timestamp: 1000 }, 8000, 8999), false);
eq("critical (duration 0) always survives", L.popupExpired({ timestamp: 1 }, 0, 1e12), false);
eq("a restore deadline outranks the timestamp", [L.popupExpired({ timestamp: 1, deadline: 5000 }, 8000, 4999), L.popupExpired({ timestamp: 1, deadline: 5000 }, 8000, 5000)], [false, true]);

// The popup file format: one compact line, read back newest first, tolerant of a torn write.
const entry = (o) => Object.assign({ id: 1, originalId: 1, app: "Signal", summary: "hi", body: "there", urgency: CRITICAL, expireTimeout: 12000, timestamp: 1000 }, o);
const line = L.serializePopup(entry(), NORMAL);
eq("serialised on one line", line.indexOf("\n"), -1);
eq("it keeps the fields other code reads", Object.keys(JSON.parse(line)).sort(),
  ["app", "appIcon", "body", "execArgv", "expireTimeout", "glyph", "id", "image", "originalId", "summary", "timestamp", "urgency"]);
const back = L.parsePopupFiles(line + "\n", NORMAL)[0];
eq("round trip", [back.summary, back.app, back.urgency, back.expireTimeout, back.timestamp], ["hi", "Signal", CRITICAL, 12000, 1000]);
const many = [L.serializePopup(entry({ summary: "old", timestamp: 1 }), NORMAL), "{ torn", "5", "null", L.serializePopup(entry({ summary: "new", timestamp: 9 }), NORMAL)].join("\n");
eq("newest first, junk skipped", L.parsePopupFiles(many, NORMAL).map((e) => e.summary), ["new", "old"]);
eq("a missing urgency becomes the normal one", L.parsePopupFiles(JSON.stringify({ summary: "s" }), 1)[0].urgency, 1);
eq("a restore deadline survives the file", L.parsePopupFiles(L.serializePopup(entry({ deadline: 77 }), NORMAL), NORMAL)[0].deadline, 77);

// What a D-Bus notification becomes.
const snap = L.snapshotOf({ id: 4, appName: "a", summary: "s", expireTimeout: -5, urgency: 1, hints: { "omarchy-glyph": "G", "omarchy-exec-argv": "[\"mpv\",\"x\"]" } }, 55);
eq("snapshot: ids, timestamp, hints", [snap.id, snap.originalId, snap.timestamp, snap.glyph, snap.execArgv], [4, 4, 55, "G", "[\"mpv\",\"x\"]"]);
eq("snapshot: a negative timeout becomes 0", snap.expireTimeout, 0);
eq("an update with the same content writes nothing", L.popupRowChanged(snap, Object.assign({}, snap)), false);
eq("a changed body is a change", L.popupRowChanged(snap, Object.assign({}, snap, { body: "x" })), true);

// The click command's argv hint: structural check only, and it fails closed.
eq("a valid argv", L.parseExecArgv('["mpv","--","/a b.mp4"]'), ["mpv", "--", "/a b.mp4"]);
eq("not an array / empty / bad json / empty program / option-looking program / non-string",
  ['{"a":1}', "[]", "nope", '[""]', '["-rf"]', '["ls",1]', ""].map(L.parseExecArgv), [null, null, null, null, null, null, null]);

// The settings file.
eq("dnd on", L.parseSettings('{"version":3,"dnd":true}'), { error: false, dnd: true, legacy: false });
eq("empty", L.parseSettings(""), { error: false, dnd: null, legacy: false });
eq("legacy payload is reported", L.parseSettings('{"dnd":false,"pending":[]}').legacy, true);
eq("junk is an error", L.parseSettings("{").error, true);

eq("chromium-derived senders", [["chromium", ""], ["", "brave-browser"], ["Signal", "signal"]].map(([a, i]) => L.isChromiumDerived(a, i)), [true, true, false]);

console.log(fail === 0 ? `ALL ${pass} CHECKS PASS` : `${fail} FAILED, ${pass} passed`); process.exit(fail ? 1 : 0);
