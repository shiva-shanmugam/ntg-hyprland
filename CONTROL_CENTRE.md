# Floating Control Center

The Control Center opens from the right-hand bar icon, the existing sidebar shortcut, or `qs ipc -c ii call sidebarRight toggle`. Hyprland blurs the live desktop under the translucent tiles, and a soft shadow fades around each tile. The gaps let clicks through. Hover a tile to see its name and any available status.

## Controls

| Tile | Interaction |
| --- | --- |
| Bluetooth | Click to toggle the adapter. Hold or right-click for the device list. Scroll over the hero tile to cycle connected devices. |
| Wi-Fi | Click to toggle Wi-Fi. Hold or right-click for networks. |
| Volume and brightness | Drag or scroll their dot rows. Click the speaker to mute. Right-click volume or microphone for device and mixer controls. |
| Media | Use the three playback buttons. Drag the progress dots when the player supports seeking. |
| Dark mode / Light mode | Switch the active NTG palette and app preferences. |
| Notifications | Click the tile to see notification history. The ringing bell indicates unread items. |
| Lock, Sleep, Restart and Shutdown | Click once to arm. Click the same tile within three seconds to confirm. Escape cancels. |
| Session and Settings | Open the existing session menu and shell settings. Right-click Settings to reload Hyprland and Quickshell. |

The date on the bar opens the calendar. Use its arrows or scroll over the calendar to browse months. Click the clock or battery again to close its card, or click outside. Bar tooltips use click mode by default. Tray icons keep their normal left and right clicks, and a middle click opens their information card.

## Layout and appearance

Edit `~/.config/quickshell/ii/modules/ii/sidebarRight/nothing/TileLayout.js`. Move a tile in the list to change placement. Sizes are `[columns, rows]`, with `[1, 1]`, `[2, 1]`, `[2, 2]`, and `[1, 2]` as useful starting points. Shapes are `circle`, `pill`, `square`, and `card`. The packer fills available cells from left to right. The grid scrolls when the viewport is shorter than the layout.

`NothingMetrics.qml` defines the unit, gap, radii, dot sizes, and transition timings. Colors come from the active NTG palette through `modules/common/DesktopPalette.qml`. Set `sidebar.nothingActiveStyle` to `"red"` in `~/.config/illogical-impulse/config.json` to use red active fills. The default is `"inverted"`, with white active fills for ordinary toggles.

`ControlGlyph.qml` maps control names to Material Symbols. `DeviceArt.js` selects the Bluetooth symbol from the device name or BlueZ icon. Put specific name rules ahead of general ones. `DotArt.js` supplies the dot patterns in the standalone preview.

Run the standalone glyph preview from your graphical session.

```sh
qs -p "$HOME/.config/quickshell/ii/control-centre-preview.qml"
```

## Service availability

Bluetooth uses the adapter and device objects already exposed by Quickshell and BlueZ. A device’s battery appears when the service exposes it. Left, right, and case figures require independently reported batteries for matching devices. The hero tile remembers the most recent device name and art until another one connects.

Wi-Fi uses the existing NetworkManager service. Airplane mode turns Wi-Fi and Bluetooth off and remembers which radios to restore. Brightness needs a supported backlight, and the playback controls need an MPRIS player. The Power Profiles tile is disabled when a compatible provider is absent. Screen recording uses the existing shell recorder and shows its active state.

## Reload and roll back

The shell watches its files. To explicitly reload the compositor and shell while keeping the session open, run the following.

```sh
hyprctl reload
hyprctl configerrors
qs ipc -c ii --any-display call agentShell reloadConfig "$(tr -d '-' </proc/sys/kernel/random/uuid)"
qs log -c ii --any-display --tail 50
```

Turn off **Floating Control Center** under **Shell settings → Interface → Sidebars** to return to the legacy layout. The same switch is `sidebar.nothingControlCentre` in the shell config. The date still owns the calendar in either layout.

The private baseline is in `~/dotfiles-backup-controlcentre-YYYYMMDD` on the machine where the change was applied. To reverse just this phase, set `change` to the commit that added this guide, then check and reverse its live config patch. The check catches intervening edits.

```sh
cd ~/ntg-hyprland
change=COMMIT
git diff --binary "$change^" "$change" -- .config/quickshell .config/hypr |
    git -C "$HOME" apply --reverse --check
git diff --binary "$change^" "$change" -- .config/quickshell .config/hypr |
    git -C "$HOME" apply --reverse
```

The bar tooltip preference can be restored separately under **Shell settings → Bar → Tooltips**. Reload with the commands above after restoring files.

## Phase checks

| Phase | Files and replay |
| --- | --- |
| Recon and backup | The baseline Git commit contains the original Quickshell directory, live options, and Hyprland custom rules. |
| Foundations | `NothingMetrics.qml`, `NothingTile.qml`, and `TileLayout.js` define the tile sizes, shapes, animations, and placement. |
| Dot art | Run the standalone preview to check the built-in 5×7 text and device shapes. |
| Bluetooth | Open details and check adapter, connected, and no-battery states. |
| Tile wiring | Open the grid from the usual bar icon. Check connectivity, output, brightness, media, and the first press on a power tile. |
| Popups and polish | Hover the bar, then click its date or battery. Check empty gaps and Escape in the floating grid. |
