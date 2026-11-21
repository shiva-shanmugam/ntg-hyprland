# Commands to run in interactive sessions can go here
if status is-interactive
    # No greeting
    set fish_greeting

    # Use starship
    function starship_transient_prompt_func
        starship module character
    end
    if test "$TERM" != "linux"
        starship init fish | source
        enable_transience
    end
    
    # Apply wallpaper colors only when explicitly enabled.
    set -l config_dir (test -n "$XDG_CONFIG_HOME"; and printf '%s\n' "$XDG_CONFIG_HOME"; or printf '%s\n' "$HOME/.config")
    set -l state_dir (test -n "$XDG_STATE_HOME"; and printf '%s\n' "$XDG_STATE_HOME"; or printf '%s\n' "$HOME/.local/state")
    set -l terminal_sequences "$state_dir/quickshell/user/generated/terminal/sequences.txt"
    if test "$TERM" != linux
        and test -r "$terminal_sequences"
        and jq -e '.appearance.wallpaperTheming.enableTerminal == true' "$config_dir/illogical-impulse/config.json" >/dev/null 2>&1
        cat "$terminal_sequences"
    end

    # Aliases
    # kitty doesn't clear properly so we need to do this weird printing
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias pamcan pacman
    alias q 'qs -c ii'
    if test "$TERM" != "linux"
        alias ls 'eza --icons'
    end
    if test "$TERM" = "xterm-kitty"
        alias ssh 'kitten ssh'
    end
end
