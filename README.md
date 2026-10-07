# Survival Status - StreamDeckPZ Complete

**All 13 action types are available as a free download.**

[Download Complete](https://github.com/stefanomontella/StreamDeckPZ-Base/releases/latest) | [Steam Workshop bridge](https://steamcommunity.com/sharedfiles/filedetails/?id=3812767649)

The repository keeps its original StreamDeckPZ-Base name. The latest release contains Complete; the four-action Base package is also retained.

Version **0.8.0.0** — Free download - all 13 action types

This download contains the **Complete Stream Deck plugin** and the **Stream Deck PZ Bridge** game mod.

[Download the latest Complete package](https://github.com/stefanomontella/StreamDeckPZ-Base/releases/latest) | [Game mod on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3812767649)

## Included actions

- Body Temperature
- Wetness
- Calendar
- Vehicle
- Equipped Weapon
- Endurance
- Fatigue
- Mood
- Carry Weight
- Health
- Clock / Temperature
- Hunger
- Thirst

Each key has its own settings. Numeric metrics support configurable flashing alarms; Calendar has no alarm. Nearby-zombie monitoring and hotkeys are excluded.

## Requirements

- Project Zomboid **Build 42**, single-player.
- Elgato Stream Deck software **7.1 or later**.
- Windows 10 or later, or macOS 13 or later. macOS has not been tested here.
- A Stream Deck keypad: MK.2, Mini, XL or the keys on Stream Deck +. Dial/touch-strip actions are not included.

No Node.js, npm or compilation is required for this download.

## Install the game mod

Subscribe to the linked Steam Workshop mod and enable **Stream Deck PZ Bridge** in your single-player save. Create `Zomboid/Lua/StreamDeckPZ` in your user folder before playing.

For manual installation, close Project Zomboid and extract the ZIP; do not run the installer from inside an archive. Choose either Workshop or manual installation to avoid duplicate copies of the same bridge.

On Windows, open PowerShell **inside this extracted folder**, where this README, the installer and `mods` are located, and run:

```powershell
$modDestination = Join-Path $env:USERPROFILE 'Zomboid\mods'
New-Item -ItemType Directory -Path $modDestination -Force | Out-Null
Copy-Item -LiteralPath '.\mods\StreamDeckPZ' -Destination $modDestination -Recurse -Force
New-Item -ItemType Directory -Path (Join-Path $env:USERPROFILE 'Zomboid\Lua\StreamDeckPZ') -Force | Out-Null
```

Alternatively, copy `mods/StreamDeckPZ` to your user's `Zomboid/mods` directory manually and create `Zomboid/Lua/StreamDeckPZ`.

On macOS, copy the same mod folder to `~/Zomboid/mods` and create `~/Zomboid/Lua/StreamDeckPZ`. The paths assume the game's default user directory.

Open the game, enable **Stream Deck PZ Bridge** in Mods and load a single-player save. The bridge writes `state.json` about once per real second to:

- Windows: `%USERPROFILE%\Zomboid\Lua\StreamDeckPZ\state.json`
- macOS: `~/Zomboid/Lua/StreamDeckPZ/state.json`

An already installed bridge exporting Health and Fatigue can be reused. You do not need a second mod when switching editions.

## Install the Stream Deck plugin

1. Double-click **`com.streamdeckpz.status.streamDeckPlugin`** and accept installation in Stream Deck.
2. Fully quit and reopen Stream Deck after an update.
3. Open **Project Zomboid Status Complete** and drag the desired actions onto keys.
4. Select a key to change colours, percentage visibility, thresholds and alarms. Changes apply immediately; game restart is not required for key settings.

The plugin defaults to the `state.json` path above. For a custom game user directory, edit `config.json` in the installed plugin folder, set `statePath` to an absolute JSON file path, and restart Stream Deck. On Windows the plugin folder is `%APPDATA%\Elgato\StreamDeck\Plugins\com.streamdeckpz.status.sdPlugin`; on macOS it is `~/Library/Application Support/com.elgato.StreamDeck/Plugins/com.streamdeckpz.status.sdPlugin`.

Base and Complete have separate plugin/action identifiers and can coexist. Moving from Base to Complete requires assigning the Complete actions and copying any preferred per-key settings. Updating an existing Complete plugin preserves its action identifiers.

## Troubleshooting and limits

- **Game not detected**: load an active save and check `state.json` is updating. Keys become grey after about five seconds without a fresh export. Check the configured path if your game uses a custom user directory.
- **A reading shows `?`**: the installed mod/build may not provide that value. Check `Zomboid/console.txt` for `[StreamDeckPZ]` messages. Unavailable values are not reported as zero.
- Health/Fatigue require a recent bridge. Hunger and thirst percentages indicate need; 20% can already correspond to the game's first red moodle.
- Complete's Clock requires a worn watch. Local air temperature may differ slightly in formatting or refresh timing from the game's display.
- Vehicle, weapon, body temperature, wetness and moon-phase readings still require verification in the user's exact Build 42. In-game APIs can differ by build; unknown optional readings remain unavailable.
- Build 41 and multiplayer are not supported. This distribution is a download bundle, not a Steam Workshop upload container.

The mod includes its in-game poster. Plugin source files, build tools, dependencies, local settings and runtime logs are not included in this download.
