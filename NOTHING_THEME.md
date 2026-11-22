# Graphite desktop guide

NTG uses graphite and warm-white palettes with a shared red accent. Panel Matrix supplies the clock numerals. Open the calendar by clicking the date and check battery percentage by clicking the battery.

## Appearance and cursor

Use **Settings → Quick → Appearance**, the **Dark mode / Light mode** tile in Control Center, or **Ctrl+Super+Shift+D**. The mode is saved in `~/.config/nothing-theme/mode`. Quickshell updates as soon as it reads the active palette.

The renderer refreshes GTK preferences, the KDE color scheme, Kvantum, Hyprland, Kitty and the generated config used by Foot, Fuzzel, eza, CAVA, btop and hyprlock. Reopen applications that cache their theme or specify their own appearance. The wallpaper stays selected across both modes.

Edit `~/.config/nothing-theme/palette.json` for dark or `palette-light.json` for light. Run the renderer to regenerate the current mode.

```sh
python3 "$HOME/.config/nothing-theme/render.py" --apply
hyprctl configerrors
```

To update the Graphite Pointer assets after a palette change, run the pointer renderer with `xcursorgen` installed.

```sh
python3 "$HOME/.config/nothing-theme/pointer/render.py"
hyprctl setcursor Graphite-Pointer 24
```

## Chat and Translator

Open the sidebar with **Super+A**. Chat defaults to Qwen3 8B over local Ollama. Use `/model` to switch models and `/models` to refresh discovery. Attach UTF-8 text or, on a vision model, PNG, JPEG, or WebP images.

Automatic chat history is off by default. Use `/save NAME` and `/load NAME` for named conversations. Chat tools start off and require approval for each settings write when enabled. The separate Translator tab uses Google Translate.

Optional local dictation uses `whisper-cli` from [whisper.cpp](https://github.com/ggml-org/whisper.cpp) and the English model at `~/.local/share/whisper.cpp/models/ggml-base.en.bin`.

## Agent

Choose **Agent** in the AI sidebar. The Desktop workspace covers Hyprland, Quickshell, and the themed application configs. **Choose project** scopes a job to one folder under your home directory.

- **Run** starts an inspection. Ask the agent to find a file, read relevant lines, or diagnose recent desktop logs.
- **Edit & apply** authorizes edits for that job. The agent stages a Git patch, checks file syntax, and checks a live Hyprland or Quickshell reload when affected. The agent restores the previous files if the reload check fails.
- **View diff** shows the applied patch. **Undo last change** restores the most recent checkpoint after verifying the files still match the job's changes.
- **Screen access** allows a Desktop job to send a screenshot to local Gemma for a visual check. The worker processes the screenshot in memory.
- Jobs continue while the sidebar is closed. Open it again to see the progress or press **Stop**. Job state and checkpoints are stored under `~/.local/state/quickshell/user/agent`.

For a first task, try “Find the battery indicator and show where the percentage tooltip is defined.”
