#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'HELP'
Usage
  ./install.sh --config-only        Install user configs and assets
  ./install.sh --arch               Install Arch dependencies, then user configs
  ./install.sh --config-only --dry-run
                                   Preview the files on an existing setup
HELP
}

fail() { printf '%s\n' "$*" >&2; exit 1; }

mode=
preview=false
while (($#)); do
    case "$1" in
        --arch|--config-only)
            [[ -z $mode ]] || fail 'Select one installation mode.'
            mode=$1
            ;;
        --dry-run) preview=true ;;
        -h|--help) usage; exit ;;
        *) fail "Unknown option $1" ;;
    esac
    shift
done
[[ -n $mode ]] || { usage; exit 2; }
(( EUID != 0 )) || fail 'Run as your regular user.'
[[ $mode != --arch || $preview == false ]] || fail 'Use --config-only --dry-run for a file preview.'
[[ ${XDG_CONFIG_HOME:-$HOME/.config} == "$HOME/.config" ]] || fail 'This configuration uses ~/.config.'
[[ ${XDG_DATA_HOME:-$HOME/.local/share} == "$HOME/.local/share" ]] || fail 'This configuration uses ~/.local/share.'

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd "$repo"
sources=(./.config ./.local/share)
[[ -d .config/hypr && -d .local/share ]] || fail 'Run from a complete checkout.'

check_destinations() {
    [[ ! -L $HOME/.local && ( ! -e $HOME/.local || -d $HOME/.local ) ]] ||
        fail "Expected a real directory at $HOME/.local"
    while IFS= read -r -d '' src; do
        dst=$HOME/${src#./}
        if [[ -d $src && ! -L $src ]]; then
            [[ ! -L $dst && ( ! -e $dst || -d $dst ) ]] ||
                fail "Expected a real directory at $dst"
        else
            [[ ! -d $dst || -L $dst ]] || fail "A directory occupies the file path $dst"
        fi
    done < <(find "${sources[@]}" -print0)
}
check_destinations

if [[ $mode == --arch ]]; then
    [[ -r /etc/os-release ]] || fail 'Cannot identify this distribution.'
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ ${ID:-} == arch ]] || fail 'The --arch mode requires Arch Linux.'
    command -v sudo >/dev/null || fail 'Set up sudo for your regular user first.'
    sudo pacman -Syu --needed base-devel git rsync lua ripgrep grim
    checkout=$(mktemp -d)
    trap 'rm -rf -- "$checkout"' EXIT
    git -C "$checkout" init --quiet
    git -C "$checkout" fetch --depth=1 https://github.com/end-4/dots-hyprland.git 21733c3ca7f4edc20faafedea844dc96002c6f7f
    git -C "$checkout" checkout --quiet --detach FETCH_HEAD
    "$checkout/setup" install-deps
fi

command -v rsync >/dev/null || fail 'Install rsync first.'
args=(-rlt --omit-dir-times --checksum --itemize-changes --relative)
if $preview; then
    rsync "${args[@]}" --dry-run "${sources[@]}" "$HOME/"
    exit
fi

check_destinations
backup_home=${XDG_STATE_HOME:-$HOME/.local/state}/ntg-hyprland
mkdir -p -- "$backup_home"
backup=$(mktemp -d "$backup_home/install-XXXXXXXX")
mkdir -p -- "$backup/files"
printf 'Backup and change log are in %s\n' "$backup"
rsync "${args[@]}" --backup --backup-dir="$backup/files" "${sources[@]}" "$HOME/" | tee "$backup/changes.log"
printf '%s\n' 'Installed. See docs/INSTALL.md for first launch and rollback.'
