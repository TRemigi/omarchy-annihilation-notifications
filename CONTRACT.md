# What this fork must keep doing

This fork replaces Omarchy's notification daemon for every caller that used to talk to it. Those
callers were written against the stock plugin, so the surface below is a contract: change it only on
purpose, in step with the callers, and say so in the commit. `tools/contract-check` (planned, P1)
verifies the parts that can be checked from files. Source of every item: Omarchy 4.0.4-1.

## How the fork is found

- Manifest id `annihilation.notifications`, `omarchy.clonedFrom: "omarchy.notifications"`, kind
  `service`, entry point `Service.qml`, `keepLoaded: true` (killing the notification server mid-session
  drops toasts).
- Omarchy's registry routes calls made to `omarchy.notifications` to the enabled clone, switches the
  stock plugin off while the clone is enabled, and switches it back on when the clone is disabled or
  removed (`shell/services/PluginRegistry.qml`: `resolveEnabledId`, `restoreCloneSource`,
  `cloneSourceRestores`, `disabledPlugins`).

## Members other code reads

| Member | Used by |
|--------|---------|
| `doNotDisturb` (bool, readable) | the bar's DND indicator (`plugins/bar/indicators/Dnd.qml`, through `firstPartyServiceFor("omarchy.notifications")` and the proxy in `services/PluginFirstPartyServiceApi.qml`) |
| `setDoNotDisturb(bool)` | the same |

## IPC target `notifications` (`omarchy-shell notifications <function>`)

All return a string; keep the names and the argument lists.

| Function | Called by |
|----------|-----------|
| `ping()` -> `"ok"` | `omarchy-notification-wait` |
| `toggleDnd()` | `omarchy-toggle-notification-silencing` (the bar's DND button goes through the service members above instead) |
| `dndState()`, `isDnd()`, `setDnd(value)`, `clear()` | no caller found in Omarchy 4.0.4-1's files; they are part of the IPC surface users and scripts may use, so keep them |
| `showHistory()` | key binding Super+Shift+Alt+, |
| `dismissAll()` | Super+Shift+, |
| `dismissOne()` | Super+, |
| `invokeLast()` | Super+Alt+, |
| `dismiss(summary)` | `omarchy-notification-dismiss` |

## D-Bus and the toast surface

- Owns `org.freedesktop.Notifications` through Quickshell's `NotificationServer` (image, actions, body
  markup and hyperlinks, persistence supported). `omarchy-notification-send` calls `Notify` directly
  and relies on these hints: `omarchy-glyph` (a Nerd Font glyph for the icon slot) and
  `omarchy-exec-argv` (the click command's argv, as JSON). Update (`replaces_id`) must keep working.
- The popup layer is namespace `omarchy-notifications` on the overlay layer, one per output,
  click-through except over the cards. The annihilation theme's Hyprland rules (frost, blur) match that
  namespace, so keep it.

## Behaviour callers depend on

- **Do Not Disturb** hides toasts and records them straight into history, except: `omarchy-action`
  toasts always show; `notify-send` at critical urgency shows. Notifications from `notify-send`,
  `omarchy-action` or with the `transient` hint are *ephemeral*: under DND they are dropped and never
  recorded. (The theme's missed-notification tracker and docs rely on this.)
- Lifetimes: low 5 s, normal 8 s (or the sender's timeout if longer), at most 30 s, critical never
  expires. The theme's `MissedTracker.lifetimeFor` mirrors these numbers.
- **With the annihilation theme active, a toast leaves the screen up to 1.1 s later** (times `motion_slowdown`, 1 unless the user changes it in
  `~/.config/omarchy/annihilation-notifications-fork.conf`; 300 ms with `arrival=0`) than its lifetime or its dismissal: it dissolves into the light first
  (`components/ArrivalFlare.qml`, `SlotMotion.dissolve`: the ring that has rested round the card collapses onto it, 1 s) and the slot folds shut over the last of that, and only then is its file
  moved to `history/`. Left-click (which acts at once) and the IPC dismissals are not delayed. The theme's `MissedTracker` cannot know this; the only effect is
  that a toast dismissed in roughly the last 1.5 s of its lifetime can be counted as expired (a false "missed").
- **With the annihilation theme active, the popup window can stay up, empty and click-through, for up to about 2.2 s after
  the last toast has gone**, to finish drawing the spores it left (`components/SporeLayer.qml`). The arrival's ring and halo (`components/ArrivalLayer.qml`) now rest round
  a card and **linger for as long as the toast is up** (at most 3 at a time; they are drawn in the same window, so the window is up anyway), and a ring goes with its
  card (collapsed in the exit, or at once on a click or an IPC dismissal), so it no longer outlasts the toast. It never covers or
  intercepts anything: its input region is the toast column, which is empty by then. The layer namespace is unchanged.
- **With the annihilation theme and the blend look (the default), a toast is a soft-edged body (a rounded rectangle; it was an oval for a while), not a card** (`components/ToastBody.qml`, `BodyLogic.js`; `body=card` in the fork's conf file, or `look=growth`, keeps the
  rectangle). The card item grows by 12 px on each side and 6 above and below (design px; the column is 24 px wider, 404 instead of 380, and a toast 12 px taller) so the text sits well inside the oval; it draws no fill or
  border of its own; the body reaches about 8 px past the card's sides and 4 past its top and bottom, and its soft edge fades out over about 60 px beyond that, so neighbouring toasts' soft edges overlap. The input region is still the toast column: nothing new is clickable.
  With any other theme, or `look=growth`, or `body=card`, the card is Omarchy's own size.
- **Where the toasts are:** top right, as in Omarchy, unless the annihilation theme is active and `position=center` is set in the fork's conf file (read live): then the column is centred
  horizontally at the top of the screen (same top margin, so below the bar). The window, the layer namespace and the input region are unchanged.
- Click runs the toast's default action (`omarchy-exec-argv`, else the sender's `default` action) and
  dismisses; right click dismisses; hovering pauses the countdown.
- Live toasts survive a shell restart (restored from the popup files).

## State files (`~/.local/state/omarchy/notifications/`)

The annihilation theme's `NotificationFeed.qml` and `MissedTracker.qml` read these, with or without
this fork.

- One file per live toast, `<timestamp-ms>-<originalId>.json`, one compact JSON line: `id, originalId,
  app, appIcon, summary, body, image, glyph, execArgv, urgency (0 low, 1 normal, 2 critical),
  expireTimeout, timestamp`. Written when the toast appears (`printf >`, so one `close_write`),
  rewritten in place when the sender updates it, and **moved with `mv`** to `history/` when it leaves
  the screen for any reason. A DND-silenced notification is written straight into `history/`.
- `history/` is trimmed to the newest 10. `images/` holds copies of avatars and images that the
  files reference. `../notifications.json` holds `{ "version": 3, "dnd": bool }`.

## What the theme no longer does (2026-10-31)

The theme used to draw an arrival ring (`ArrivalGlow.qml`, `shaders/arrival.frag`, settings `notifyGlow` and `notifyGlowStrength`) from a fixed
box near the corner of the screen. That is gone from the theme: the arrival is the fork's now (`components/ArrivalFlare.qml`,
`ArrivalLayer.qml`, the setting `arrival` in `~/.config/omarchy/annihilation-notifications-fork.conf`), drawn from each card's own outline and
icon. Without the fork there is no arrival light. The theme still reads this daemon's state files for the sound and the missed marks.

## Shared code this fork imports (a change here can break it without touching our files)

`qs.Commons` (`Style`, `Color`, `Border`, `Util`) and `qs.Ui` (`BorderSurface`). They are in the
watched list in `tools/lib.sh`, so `tools/check-upstream` reports changes to them.
