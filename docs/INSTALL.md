# Installing ntg-hyprland

Use your normal user account. The configs expect the standard `~/.config` and `~/.local/share` paths. The desktop uses Hyprland's Lua configuration introduced in 0.55 and the illogical-impulse Quickshell runtime.

## Fresh Arch Linux

Start from a booted Arch system with networking, the graphics drivers for your machine, and a regular user with working sudo. See the [Arch installation guide](https://wiki.archlinux.org/title/Installation_guide) for those prerequisites.

```sh
sudo pacman -Syu --needed git
git clone https://github.com/shiva-shanmugam/ntg-hyprland.git
cd ntg-hyprland
./install.sh --arch
```

Arch mode upgrades packages and runs the pinned [illogical-impulse installer](https://github.com/end-4/dots-hyprland/tree/21733c3ca7f4edc20faafedea844dc96002c6f7f) in dependency-only mode. Review its package and AUR prompts. The script then copies the NTG configuration and assets into your home directory.

Choose Hyprland from your login manager. From a TTY on current Arch, launch the packaged session with `start-hyprland`. Hardware setup, login manager selection, and optional services are configured separately. See the [Arch Hyprland guide](https://wiki.archlinux.org/title/Hyprland).

## Existing Hyprland installation

Clone this repository and check that your installed Hyprland supports Lua. Config-only mode requires `rsync` and assumes the illogical-impulse dependencies are already installed. Use the Arch path above if you have a bare Hyprland installation and want the shell dependencies installed for you.

```sh
git clone https://github.com/shiva-shanmugam/ntg-hyprland.git
cd ntg-hyprland
./install.sh --config-only --dry-run
./install.sh --config-only
```

Read the preview before applying. Installing overlays the included files in `~/.config` and `~/.local/share`. The installer saves displaced files and logs every copied path. Real directories are required at the destination paths, so review and resolve any directory symlink reported by the installer before trying again. If you have custom Hyprland bindings or monitor settings, review your backup and merge the settings you want to keep.

## First launch and checks

In the Hyprland session, run `hyprctl reload` and `hyprctl configerrors`. Hyprland starts Quickshell during a fresh session. If an existing session runs a different shell, sign out and back in after reviewing your startup configuration.

Apply the bundled wallpaper manually if needed.

```sh
"$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh" --image "$HOME/.config/quickshell/ii/assets/images/default_wallpaper.png"
```

Open the AI sidebar with **Super+A**. For local models, [install and start Ollama](https://docs.ollama.com/linux), then run `ollama pull qwen3:8b`. The optional screen check also needs `ollama pull gemma4:e4b`. See the [desktop guide](../NOTHING_THEME.md) for the Agent and dictation.

## Restore displaced files

Use the backup path printed by the installer. Set `backup` to the exact directory for the install you want to undo.

```sh
backup="$HOME/.local/state/ntg-hyprland/install-XXXXXXXX"
rsync -rlt --omit-dir-times --itemize-changes --dry-run "$backup/files/" "$HOME/"
rsync -rlt --omit-dir-times --itemize-changes "$backup/files/" "$HOME/"
```

Review `changes.log` for paths marked `+++++++++`. Remove individual newly installed files only after confirming they belong to that install. Reopen your Hyprland session to load the restored config.
