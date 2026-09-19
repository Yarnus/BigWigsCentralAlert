# BigWigs Central Alert

BigWigs Central Alert mirrors the **shortest remaining eligible BigWigs or LittleWigs bar** as centered text with its original icon, color, and a native countdown.

![World of Warcraft Retail](https://img.shields.io/badge/WoW-Retail-blue)

## Behavior

- Can independently include important (emphasized) and normal BigWigs bars; both are enabled by default.
- Shows only bars inside a configurable 0–20 second lead-time window.
- Selects the eligible bar with the earliest expiration.
- Automatically switches when that bar stops, pauses, expires, or changes importance.
- Hides when no eligible bar remains.
- Uses the effective BigWigs bar label, including user renames, plus the original icon and text color; there are no encounter-specific rules.
- Supports BigWigs raid bars and LittleWigs dungeon bars.

## Performance

The addon is event-driven. It does not poll bars and does not run a Lua `OnUpdate` countdown. Visible time is updated by WoW's native `C_DurationUtil` and `DurationTextBinding`. One transition timer wakes the addon when the next bar enters the configured lead-time window.

The original bar label and countdown use separate font strings. This allows secret encounter text to be passed directly to the UI without concatenating or reading it in Lua.

## Configuration

Open the configuration window with:

```text
/bwca
```

Commands:

```text
/bwca test
/bwca lock
/bwca reset
```

Settings include:

- LibSharedMedia fonts
- font size, outline, monochrome, and shadow
- original BigWigs text color and event icon
- important and normal bar filters
- 0–20 second lead-time window
- single-line or two-line layout
- spacing and screen position
- countdown brackets and rounding
- movable preview and position locking

## Installation

1. Install [BigWigs](https://www.curseforge.com/wow/addons/big-wigs).
2. Install [LittleWigs](https://www.curseforge.com/wow/addons/little-wigs) if dungeon timers are needed.
3. Copy this repository to:

   ```text
   World of Warcraft/_retail_/Interface/AddOns/BigWigsCentralAlert
   ```

## Compatibility note

BigWigs `v424.8` emits `BigWigs_BarCreated` and `BigWigs_BarEmphasized`, which expose the effective bar label (including renames), icon, color, and importance. BigWigs currently marks its bar-object callbacks as deprecated for eventual removal. That integration is isolated in `BigWigsAdapter.lua` so a future replacement does not affect selection, display, or configuration code.

## Development

Run the Lua 5.1-compatible selector test:

```bash
luajit tests/test_selector.lua
```

Check every Lua file for syntax errors:

```bash
for file in *.lua tests/*.lua; do luajit -e "assert(loadfile('$file'))"; done
```

In-game verification is still required because Blizzard UI objects, secret values, and BigWigs callbacks are not available in a standalone Lua runtime.

## License

[MIT](LICENSE)
