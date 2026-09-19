# BigWigs Central Alert

BigWigs Central Alert mirrors the **shortest remaining emphasized BigWigs or LittleWigs bar** as centered text with a native countdown.

![World of Warcraft Retail](https://img.shields.io/badge/WoW-Retail-blue)

## Behavior

- Tracks bars only after BigWigs moves them into its emphasized area.
- Shows the emphasized bar with the earliest expiration.
- Automatically switches when that bar stops, pauses, or expires.
- Hides when no emphasized bar remains.
- Uses the original BigWigs bar label; there are no encounter-specific rules.
- Supports BigWigs raid bars and LittleWigs dungeon bars.

## Performance

The addon is event-driven. It does not scan bars and does not run a Lua `OnUpdate` countdown. Visible time is updated by WoW's native `C_DurationUtil` and `DurationTextBinding`. Selection is recalculated only when a bar changes lifecycle state.

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
- BigWigs bar color following or custom text/countdown colors
- single-line or two-line layout
- spacing and screen position
- countdown brackets, localized seconds suffix, and rounding
- movable preview and position locking

## Installation

1. Install [BigWigs](https://www.curseforge.com/wow/addons/big-wigs).
2. Install [LittleWigs](https://www.curseforge.com/wow/addons/little-wigs) if dungeon timers are needed.
3. Copy this repository to:

   ```text
   World of Warcraft/_retail_/Interface/AddOns/BigWigsCentralAlert
   ```

## Compatibility note

BigWigs `v424.8` emits `BigWigs_BarEmphasized`, which provides the exact bar chosen by BigWigs. BigWigs currently marks its bar-object callbacks as deprecated for eventual removal. That integration is isolated in `BigWigsAdapter.lua` so a future replacement does not affect selection, display, or configuration code.

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
