"""Render and apply either NTG desktop palette."""
import argparse
from contextlib import suppress
import fcntl
from pathlib import Path
import json
import os
import re
import shutil
import signal
from string import Template
import subprocess
import sys
from tempfile import NamedTemporaryFile

THEME = Path(__file__).resolve().parent
TEMPLATES = THEME / "templates"
MODE_FILE = ".config/nothing-theme/mode"
ACTIVE_FILE = ".config/nothing-theme/active.json"
MODES = ("dark", "light")


def palette(mode):
    path = THEME / ("palette.json" if mode == "dark" else "palette-light.json")
    colors = json.loads(path.read_text())
    for key in ("black", "panel", "surface", "raised", "line", "outline", "muted", "text", "red"):
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", colors.get(key, "")):
            raise ValueError(f"Invalid color {key} in {path.name}")
    return {**colors, "corner_radius": 8, "dark_mode": str(mode == "dark").lower(),
            **{key + "_hex": value[1:] for key, value in colors.items()}}


def replace_keys(text, group, entries):
    """Update only owned keys, including files with KDE group suffixes."""
    header = re.compile(r"^\[" + re.escape(group) + r"\][ \t]*$", re.M)
    match = header.search(text)
    if not match:
        prefix = text.rstrip("\n")
        lines = "".join(f"{key}={value}\n" for key, value in entries.items())
        return (prefix + "\n\n" if prefix else "") + f"[{group}]\n" + lines
    start = match.end()
    next_group = re.search(r"^\[", text[start:], re.M)
    end = start + next_group.start() if next_group else len(text)
    existing = text[start:end].splitlines()
    items = [line for line in existing if line.partition("=")[0].strip() not in entries]
    rest = "\n".join(items).strip("\n")
    body = "".join(f"{key}={value}\n" for key, value in entries.items())
    return text[:start] + "\n" + body + (rest + "\n" if rest else "") + ("\n" if next_group else "") + text[end:]


def write_atomic(path, content, mode=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        raise ValueError(f"Refusing to replace the symlink at {path}")
    if path.is_file() and path.read_bytes() == content:
        return
    prior = path.stat().st_mode & 0o777 if path.exists() else 0o644
    with NamedTemporaryFile(dir=path.parent, delete=False) as file:
        temp = Path(file.name)
        try:
            file.write(content)
            file.flush()
            os.fchmod(file.fileno(), prior if mode is None else mode)
            os.replace(temp, path)
        finally:
            temp.unlink(missing_ok=True)


def existing(path):
    return path.read_text() if path.is_file() else ""


def light_kvantum(content):
    def flip(match):
        value = match.group(0)
        rgb = [int(value[i:i + 2], 16) for i in (1, 3, 5)]
        if len(set(rgb)) != 1:
            return value
        shade = rgb[0]
        # Keep the same relative shading while swapping the monochrome endpoints.
        light = min(253, max(20, 255 - shade))
        return "#" + f"{light:02x}" * 3
    return re.sub(r"#[0-9a-fA-F]{6}\b", flip, content)


def outputs(root, mode):
    colors = palette(mode)
    files = {}
    for template in sorted(TEMPLATES.rglob("*.in")):
        path = template.relative_to(TEMPLATES).with_suffix("")
        render = Template(template.read_text())
        if path.name == "NothingDark.colors":
            for variant in MODES:
                dest = path.with_name(f"Nothing{variant.title()}.colors")
                scheme = render.substitute(palette(variant))
                if variant == "light":
                    scheme = scheme.replace("Name=Nothing Dark", "Name=Nothing Light").replace("ColorScheme=NothingDark", "ColorScheme=NothingLight")
                files[dest] = scheme
        else:
            files[path] = render.substitute(colors)

    for toolkit in ("gtk-3.0", "gtk-4.0"):
        path = Path(".config") / toolkit / "settings.ini"
        entries = {"gtk-application-prefer-dark-theme": "1" if mode == "dark" else "0"}
        if toolkit == "gtk-3.0":
            entries["gtk-theme-name"] = "adw-gtk3-dark" if mode == "dark" else "adw-gtk3"
        files[path] = replace_keys(existing(root / path), "Settings", entries)

    scheme_id = f"Nothing{mode.title()}"
    path = Path(".config/kdeglobals")
    source = files[Path(f".local/share/color-schemes/{scheme_id}.colors")]
    kde = replace_keys(existing(root / path), "General", {"ColorScheme": scheme_id})
    for group, contents in re.findall(r"(?m)^\[(Colors:[^\]]+)\]\n([^\[]+)", source):
        entries = dict(line.split("=", 1) for line in contents.splitlines() if "=" in line)
        kde = replace_keys(kde, group, entries)
        if group == "Colors:Header":
            kde = replace_keys(kde, "Colors:Header][Inactive", entries)
    files[path] = kde
    wm_path = Path(".config/Kvantum/kvantum.kvconfig")
    dark_style = root / ".config/Kvantum/NothingDark"
    if dark_style.is_dir():
        for suffix in (("svg", "kvconfig") if mode == "light" else ()):
            source = dark_style / f"NothingDark.{suffix}"
            if source.is_file():
                name = Path(f".config/Kvantum/NothingLight/NothingLight.{suffix}")
                files[name] = light_kvantum(source.read_text())
        files[wm_path] = replace_keys(existing(root / wm_path), "General", {"theme": scheme_id})

    files[Path(MODE_FILE)] = mode + "\n"
    # Publish the live QML values after the native configuration.
    active = {key: colors[key] for key in ("black", "panel", "surface", "raised", "line", "outline", "muted", "text", "red")}
    active.update(dark=mode == "dark", cornerRadius=colors["corner_radius"])
    files[Path(ACTIVE_FILE)] = json.dumps(active, indent=2) + "\n"
    return files


def apply_files(root, mode, refresh_kde):
    files = outputs(root, mode)
    saved = {}
    for rel in files:
        path = root / rel
        if path.is_symlink():
            raise ValueError(f"Refusing to replace the symlink at {path}")
        saved[path] = (path.read_bytes(), path.stat().st_mode & 0o777) if path.is_file() else None
    replaced = []
    try:
        for rel, text in files.items():
            target = root / rel
            replaced.append(target)
            if refresh_kde and rel == Path(".config/kdeglobals"):
                if invoke("plasma-apply-colorscheme", f"Nothing{mode.title()}"):
                    continue
            write_atomic(target, text.encode())
    except BaseException:
        for path in reversed(replaced):
            original = saved[path]
            if original is None:
                path.unlink(missing_ok=True)
            else:
                write_atomic(path, *original)
        raise


def invoke(*command):
    if not shutil.which(command[0]):
        return False
    try:
        subprocess.run(command, check=True, timeout=15, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        return True
    except (OSError, subprocess.SubprocessError):
        print(f"{command[0]} could not refresh the running session", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.home())
    parser.add_argument("--mode", choices=MODES)
    parser.add_argument("--apply", action="store_true", help="Refresh desktop settings in the current session")
    args = parser.parse_args()
    root = args.root.resolve()
    if args.apply and root != Path.home().resolve():
        parser.error("--apply requires the current home directory")
    state = root / MODE_FILE
    state.parent.mkdir(parents=True, exist_ok=True)
    with state.with_name(".render.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        old = existing(state).strip()
        mode = args.mode or (old if old in MODES else "dark")
        apply_files(root, mode, refresh_kde=args.apply)
        if args.apply:
            invoke("gsettings", "set", "org.gnome.desktop.interface", "color-scheme", f"prefer-{mode}")
            invoke("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "adw-gtk3-dark" if mode == "dark" else "adw-gtk3")
            invoke("hyprctl", "reload")
            # Kitty supports reloading its configuration with SIGUSR1.
            try:
                values = subprocess.check_output(("pgrep", "-u", str(os.getuid()), "-x", "kitty"), text=True)
            except (OSError, subprocess.CalledProcessError):
                values = ""
            for pid in values.split():
                with suppress(ProcessLookupError, PermissionError):
                    os.kill(int(pid), signal.SIGUSR1)
        print(f"NTG {mode} theme")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        if "--apply" in sys.argv:
            invoke("notify-send", "NTG appearance", str(error))
        raise
