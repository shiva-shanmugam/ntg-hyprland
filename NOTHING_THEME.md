# Graphite desktop guide

The desktop uses a fixed black and graphite palette. Red marks active workspaces, notifications, recording, errors, and the Kitty cursor. Panel Matrix supplies the clock numerals. The bar puts the Command Center to the left of the clock and battery, and the battery tooltip shows the percentage.

## Palette and cursor

Edit `~/.config/nothing-theme/palette.json`, then rebuild the generated config files.

```sh
python3 "$HOME/.config/nothing-theme/render.py"
hyprctl reload
hyprctl configerrors
```

The renderer updates the Hyprland, Quickshell, Kitty, eza, GTK, KDE, Fuzzel, CAVA, btop, and hyprlock palettes. Reopen applications that cache their colors. KDE users can reselect **Nothing Dark** in System Settings.

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
