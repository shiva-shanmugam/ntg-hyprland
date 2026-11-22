"""Scoped file tools, Git staging and reversible apply for the desktop agent."""
import ast
from collections import deque
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import selectors
import shutil
import signal
import stat
import subprocess
from string import Template
import tempfile
import time
import tomllib
from uuid import uuid4

CONFIG_DIRS = (
    ".config/hypr", ".config/quickshell/ii", ".config/illogical-impulse",
    ".config/nothing-theme", ".config/kitty", ".config/foot", ".config/fish",
    ".config/eza", ".config/fuzzel", ".config/gtk-3.0", ".config/gtk-4.0",
    ".config/Kvantum", ".config/fontconfig", ".config/btop", ".config/cava",
    ".config/fastfetch", ".config/matugen", ".local/share/icons/Graphite",
    ".local/share/color-schemes",
)
CONFIG_FILES = (".config/starship.toml", ".config/kdeglobals", "NOTHING_THEME.md", "prompt.txt")
PRIVATE_NAMES = {
    ".git", ".ssh", ".gnupg", ".aws", ".azure", ".codex", ".netrc", ".local",
    "node_modules", "__pycache__", ".venv", "keyrings", "credentials", "secrets",
}
PROTECTED_FILES = {
    ".config/quickshell/ii/scripts/ai/assistant-agent.py",
    ".config/quickshell/ii/scripts/ai/agent_workspace.py",
    ".config/quickshell/ii/scripts/ai/desktop_components.py",
    ".config/quickshell/ii/scripts/ai/assistant-backend.py",
    ".config/quickshell/ii/services/ConfigAgent.qml",
    ".config/quickshell/ii/modules/ii/sidebarLeft/AgentPanel.qml",
}
TEXT_LIMIT = 512 * 1024
OUTPUT_LIMIT = 1024 * 1024
MAX_EDITS = 24
QML_FORMAT = "/usr/lib/qt6/bin/qmlformat"

COMMANDS = ("git", "rg", "qs", "hyprctl", "luac", "bash", "python3", "grim")
SESSION_ENV = {key: os.environ[key] for key in (
    "HOME", "LANG", "LC_ALL", "TZ", "XDG_CONFIG_HOME", "XDG_CACHE_HOME",
    "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_RUNTIME_DIR", "DISPLAY", "WAYLAND_DISPLAY",
    "XDG_SESSION_TYPE", "XDG_SESSION_ID",
    "HYPRLAND_INSTANCE_SIGNATURE", "DBUS_SESSION_BUS_ADDRESS"
) if key in os.environ}
SESSION_ENV.update({
    "PATH": "/usr/local/bin:/usr/bin:/bin", "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_TERMINAL_PROMPT": "0",
})


class ToolError(Exception):
    """A tool failed and its result can be reported to the model."""


def command_args(args):
    executable = args[0]
    if executable in COMMANDS:
        executable = shutil.which(executable, path=SESSION_ENV["PATH"])
    elif executable != QML_FORMAT:
        raise ToolError("Unsupported command")
    if not executable or not os.access(executable, os.X_OK):
        raise ToolError(f"{args[0]} is unavailable")
    return [executable, *map(str, args[1:])]


def terminate(process):
    if process.poll() is None:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()


def command(args, *, cwd=None, data=None, timeout=12, allowed=(0,), limit=OUTPUT_LIMIT):
    with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as errors:
        process = subprocess.Popen(
            command_args(args), cwd=cwd, env=SESSION_ENV,
            stdin=subprocess.PIPE if data is not None else subprocess.DEVNULL,
            stdout=output, stderr=errors, start_new_session=True,
        )
        try:
            process.communicate(input=data, timeout=timeout)
        except subprocess.TimeoutExpired:
            raise ToolError(f"{args[0]} timed out") from None
        finally:
            terminate(process)
        if process.returncode not in allowed:
            errors.seek(0)
            output.seek(0)
            detail = (errors.read(4000) or output.read(4000)).decode(errors="replace").strip()
            raise ToolError(f"{args[0]} exited with {process.returncode}" + (f": {detail}" if detail else ""))
        output.seek(0)
        value = output.read(limit + 1)
        if len(value) > limit:
            raise ToolError(f"{args[0]} output was too large. Narrow the query.")
        return value


def rg_records(args, directory, separator):
    """Yield search records and stop the scan as soon as the caller has enough."""
    deadline = time.monotonic() + 12
    with tempfile.TemporaryFile() as errors, selectors.DefaultSelector() as ready:
        process = subprocess.Popen(
            command_args(args), cwd=directory, env=SESSION_ENV, stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=errors, start_new_session=True,
        )
        pending = b""
        try:
            ready.register(process.stdout, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not ready.select(remaining):
                    raise ToolError("Search timed out. Narrow the query or pick a smaller directory.")
                data = os.read(process.stdout.fileno(), 32768)
                if not data:
                    break
                records = (pending + data).split(separator)
                pending = records.pop()
                if len(pending) > OUTPUT_LIMIT:
                    raise ToolError("Search emitted an unexpectedly large record")
                yield from records
            if pending:
                yield pending
            try:
                result = process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                raise ToolError("Search did not finish") from None
            if result not in (0, 1):
                errors.seek(0)
                raise ToolError(errors.read(600).decode(errors="replace").strip() or "Search failed")
        finally:
            terminate(process)
            process.stdout.close()


def atomic_write(path, content, mode=0o600):
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".agent-", delete=False) as output:
        temporary = Path(output.name)
        try:
            output.write(content)
            output.flush()
            os.fchmod(output.fileno(), mode)
            os.fsync(output.fileno())
            output.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def save_json(path, data):
    atomic_write(path, json.dumps(data, ensure_ascii=False).encode())


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def read_regular(path, limit=TEXT_LIMIT):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as file:
        info = os.fstat(file.fileno())
        if not stat.S_ISREG(info.st_mode):
            raise ToolError("Choose a regular file")
        if info.st_size > limit:
            raise ToolError(f"File exceeds the {limit // 1024} KiB limit")
        data = file.read(limit + 1)
        if len(data) > limit:
            raise ToolError("File grew past the size limit")
        return data, stat.S_IMODE(info.st_mode)


def text_content(data):
    if b"\x00" in data:
        raise ToolError("This file contains binary data")
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        raise ToolError("This file is not UTF-8 text") from None


def within(path, prefix):
    return path == prefix or path.startswith(prefix + "/")


def private_part(part):
    name = part.lower()
    return (name in PRIVATE_NAMES or name == ".env" or name.startswith(".env.")
            or name in {"id_rsa", "id_ed25519", "credentials.json", "secrets.json", "fish_variables"}
            or name.endswith((".pem", ".key", ".kdbx")))


class Workspace:
    def __init__(self, root, desktop, editable, job):
        self.root = Path(root).resolve(strict=True)
        self.desktop = desktop
        self.editable = editable
        self.job = job
        self.repo = job / "checkpoint"
        self.stage = job / "staged"
        self.read_hashes = {}
        self.originals = {}
        self.checked = []
        if not self.root.is_dir():
            raise ToolError("Choose a directory")
        if not desktop and (
            not self.root.is_relative_to(Path.home().resolve()) or self.root == Path.home().resolve()
            or any(private_part(part) for part in self.root.relative_to(Path.home().resolve()).parts)
        ):
            raise ToolError("Choose a project folder inside your home directory")

    def resolve(self, path, write=False):
        if not isinstance(path, str) or not path or len(path) > 600:
            raise ToolError("Provide a workspace-relative path")
        relative = PurePosixPath(path)
        parts = relative.parts
        if relative.is_absolute() or ".." in parts or any(ch in path for ch in "\x00\n\r"):
            raise ToolError("Use a relative path within the workspace")
        normalized = relative.as_posix()
        if self.desktop:
            if normalized not in CONFIG_FILES and not any(within(normalized, folder) for folder in CONFIG_DIRS):
                raise ToolError(f"Outside the Desktop workspace: {path}")
            # The two explicitly scoped XDG data directories are valid roots.
            private = [part for part in parts if part != ".local"]
        else:
            private = parts
        if any(private_part(part) for part in private) or normalized.lower().endswith((".backup", ".bak")):
            raise ToolError("This file is outside the agent's file scope")
        actual = self.root / normalized
        if actual.resolve() != actual:
            raise ToolError("Choose a path without symbolic links")
        if write:
            if not self.editable:
                raise ToolError("This job is in Inspect mode")
            desktop_path = (self.root / normalized).relative_to(Path.home().resolve()).as_posix()
            if desktop_path in PROTECTED_FILES:
                raise ToolError("The agent's own execution and permission files are protected")
            if self.desktop and actual.suffix.lower() in {".sh", ".py", ".fish", ".service"}:
                raise ToolError("The Desktop scope permits config edits. Use a project job for executable source.")
        return normalized, actual

    def search_roots(self, directory):
        if directory != ".":
            return [self.resolve(directory)[0]]
        if not self.desktop:
            return ["."]
        return [item for item in (*CONFIG_DIRS, *CONFIG_FILES)
                if (self.root / item).exists() and (self.root / item).resolve() == self.root / item]

    def rg(self, mode, query, directory, limit, context=0):
        if not isinstance(query, str) or len(query) > 200:
            raise ToolError("Use a query of at most 200 characters")
        maximum = small_int(limit, 1, 75, "limit")
        roots = self.search_roots(directory)
        if not roots:
            return {"matches": [], "truncated": False}
        ignore = [item for name in sorted(PRIVATE_NAMES - {".local"}) for item in ("-g", f"!{name}")]
        ignore += [item for name in (".env*", "*.pem", "*.key", "*.kdbx", "*.backup", "*.bak")
                   for item in ("-g", "!" + name)]
        args = ["rg", "--hidden", "--no-config", "--color", "never"]
        results = []
        if mode == "files":
            if query:
                args += ["-g", query]
            with closing(rg_records([*args, *ignore, "--files", "-0", "--", *roots], self.root, b"\x00")) as items:
                for item in items:
                    path = item.decode(errors="replace")
                    if path and self.allowed_result(path):
                        results.append(path.removeprefix("./"))
                        if len(results) > maximum:
                            break
        else:
            if not query.strip():
                raise ToolError("Enter a search query")
            context = small_int(context, 0, 2, "context")
            search = [
                *args, *ignore, "--json", "--fixed-strings", "--smart-case", "--max-filesize", "512K",
                "--max-count", "2", "--max-columns", "480", "-C", str(context), "--", query, *roots,
            ]
            with closing(rg_records(search, self.root, b"\n")) as lines:
                for line in lines:
                    event = json.loads(line)
                    if event["type"] not in {"match", "context"}:
                        continue
                    data = event["data"]
                    path = data["path"].get("text", "")
                    if not path or not self.allowed_result(path):
                        continue
                    results.append({"path": path.removeprefix("./"), "line": data["line_number"],
                                    "text": data["lines"].get("text", "").rstrip()[:400]})
                    if len(results) > maximum:
                        break
        return {"matches": results[:maximum], "truncated": len(results) > maximum}

    def allowed_result(self, path):
        try:
            self.resolve(path)
        except ToolError:
            return False
        return True

    def find_files(self, pattern="", directory=".", limit=35):
        return self.rg("files", pattern, directory, limit)

    def search_text(self, query, directory=".", context=1, limit=24):
        return self.rg("text", query, directory, limit, context)

    def read_lines(self, path, start=1, end=None):
        relative, file = self.resolve(path)
        start = small_int(start, 1, 1_000_000, "start")
        end = small_int(start + 79 if end is None else end, start, start + 159, "end")
        staged = relative in self.originals
        data, _ = read_regular(self.stage / relative if staged else file)
        if not staged:
            self.read_hashes[relative] = digest(data)
        lines = text_content(data).splitlines()
        result = []
        size = 0
        for number in range(start, min(end, len(lines)) + 1):
            line = lines[number - 1]
            # Keep numbered excerpts small even in minified or generated files.
            size += len(line)
            if size > 6500:
                break
            result.append({"line": number, "text": line})
        return {"path": relative, "total": len(lines), "view": "staged" if staged else "live",
                "lines": result, "clipped": len(result) < min(end, len(lines)) - start + 1}

    def git(self, args, where=None, **options):
        return command(["git", "-C", where or self.stage, *args], **options)

    def prepare(self):
        if self.stage.exists():
            return
        self.repo.mkdir(mode=0o700)
        self.git(["init", "-q"], self.repo)
        self.git(["-c", "user.name=Desktop Agent", "-c", "user.email=agent@localhost",
                  "-c", "commit.gpgSign=false", "commit", "-q", "--allow-empty", "-m", "Before agent edit"], self.repo)
        self.git(["worktree", "add", "-q", "--detach", self.stage, "HEAD"], self.repo)

    def stage_bytes(self, path, data, *, create=False):
        relative, live = self.resolve(path, write=True)
        text_content(data)
        if len(data) > TEXT_LIMIT:
            raise ToolError("The proposed file is too large")
        if relative not in self.originals and len(self.originals) >= MAX_EDITS:
            raise ToolError("This job reached its file limit")
        if create and (live.exists() or relative in self.originals):
            raise ToolError(f"File already exists: {relative}")
        self.prepare()
        target = self.stage / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if relative not in self.originals:
            if create:
                atomic_write(target, data, 0o644)
                self.git(["add", "-N", "--", relative])
                self.originals[relative] = {"before": None, "mode": 0o644}
                return
            original, mode = read_regular(live)
            if self.read_hashes.get(relative) != digest(original):
                raise ToolError(f"Read the current file again before editing: {relative}")
            atomic_write(target, original, mode)
            self.git(["add", "--", relative])
            self.originals[relative] = {"before": digest(original), "mode": mode}
        atomic_write(target, data, self.originals[relative]["mode"])

    def replace_text(self, path, old_text, new_text):
        relative, live = self.resolve(path, write=True)
        if not isinstance(old_text, str) or not old_text or not isinstance(new_text, str):
            raise ToolError("Provide exact old and new text")
        if len(old_text) + len(new_text) > 16_000:
            raise ToolError("Split large edits into smaller replacements")
        data, _ = read_regular(self.stage / relative if relative in self.originals else live)
        current = text_content(data)
        if current.count(old_text) != 1:
            raise ToolError("The old text must match exactly once. Read the relevant lines again.")
        if old_text == new_text:
            raise ToolError("The replacement is identical")
        if self.desktop and EXECUTION_PATTERN.findall(old_text) != EXECUTION_PATTERN.findall(new_text):
            raise ToolError("Desktop edits may not add or change command-launching code")
        self.stage_bytes(relative, current.replace(old_text, new_text, 1).encode())
        return {"staged": relative}

    def create_file(self, path, text):
        if not isinstance(text, str):
            raise ToolError("Provide text for the new file")
        if self.desktop and EXECUTION_PATTERN.search(text):
            raise ToolError("Desktop edits may not add command-launching code")
        self.stage_bytes(path, text.encode(), create=True)
        return {"staged": path}

    def diff(self):
        if not self.originals:
            return b""
        return self.git(["diff", "--no-ext-diff", "--no-textconv", "--binary", "--"])

    def changed_files(self):
        changed = []
        for relative, original in self.originals.items():
            data, _ = read_regular(self.stage / relative)
            if digest(data) != original["before"]:
                changed.append(relative)
        return sorted(changed)

    def validate(self):
        results = []
        for relative in self.changed_files():
            file = self.stage / relative
            text = text_content(read_regular(file)[0])
            suffix = file.suffix.lower()
            if suffix == ".json":
                json.loads(text)
            elif suffix == ".toml":
                tomllib.loads(text)
            elif suffix == ".py":
                ast.parse(text, filename=relative)
            elif suffix == ".qml":
                command([QML_FORMAT, "--ignore-settings", file])
            elif suffix == ".lua":
                command(["luac", "-p", file])
            elif suffix == ".sh":
                command(["bash", "--noprofile", "--norc", "-n", file])
            check = "syntax" if suffix in {".json", ".toml", ".py", ".qml", ".lua", ".sh"} else "UTF-8"
            results.append({"path": relative, "check": check})
        self.checked = results
        return results

    def manifest(self):
        files = []
        for relative in self.changed_files():
            original = self.originals[relative]
            after, mode = read_regular(self.stage / relative)
            files.append({"path": relative, **original, "after": digest(after), "after_mode": mode})
        return {"root": str(self.root), "desktop": self.desktop, "files": files}

    def check_live(self, files, expected):
        for entry in files:
            relative, live = self.resolve(entry["path"], write=True)
            try:
                content, mode = read_regular(live)
                current = digest(content)
            except FileNotFoundError:
                current, mode = None, None
            expected_mode = entry["mode" if expected == "before" else "after_mode"]
            if current != entry[expected] or (current is not None and mode != expected_mode):
                raise ToolError(f"File changed outside this job: {relative}")

    def apply(self, manifest, reverse=False, *, record_success=None):
        files = manifest["files"]
        desired = "before" if reverse else "after"
        previous = "after" if reverse else "before"
        self.check_live(files, previous)
        patch = (self.job / "change.patch").read_bytes()
        args = ["git", f"--git-dir={self.repo / '.git'}", f"--work-tree={self.root}",
                "-c", "core.autocrlf=false", "apply", "--check"]
        if reverse:
            args.append("--reverse")
        command([*args, "-"], cwd=self.root, data=patch)
        written = []
        previous_mask = None
        try:
            for entry in files:
                self.check_live([entry], previous)
                written.append(entry)
                self.restore_file(entry, desired)
            checks = self.reload(files)
            if record_success is not None:
                # Publish the checkpoint before a pending Stop can interrupt the worker.
                previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM, signal.SIGALRM})
                record_success(checks)
        except (Exception, KeyboardInterrupt):
            for entry in reversed(written):
                try:
                    self.check_live([entry], desired)
                    self.restore_file(entry, previous)
                except (OSError, ToolError):
                    # Preserve an independent edit made after this transaction's write.
                    continue
            if written:
                try:
                    self.reload(written, verify=False)
                except (OSError, ToolError):
                    pass
            raise
        finally:
            if previous_mask is not None:
                signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        return checks

    def restore_file(self, entry, version):
        relative, live = self.resolve(entry["path"], write=True)
        if entry[version] is None:
            live.unlink(missing_ok=True)
            return
        if version == "before":
            content = self.git(["show", f":{relative}"])
            mode = entry["mode"]
        else:
            content, mode = read_regular(self.stage / relative)
        if digest(content) != entry[version]:
            raise ToolError(f"Checkpoint does not match its recorded hash: {relative}")
        live.parent.mkdir(parents=True, exist_ok=True)
        atomic_write(live, content, mode)

    def reload(self, files, verify=True):
        checks = []
        if not self.desktop:
            return checks
        paths = [entry["path"] for entry in files]
        if any(within(path, ".config/hypr") for path in paths):
            command(["hyprctl", "reload"])
            if verify:
                errors = command(["hyprctl", "configerrors"]).decode().strip()
                if errors:
                    raise ToolError("Hyprland config errors: " + errors[:1800])
                checks.append("Hyprland reload and configerrors")
        if any(within(path, ".config/quickshell/ii") for path in paths):
            marker = uuid4().hex
            command(["qs", "ipc", "-c", "ii", "--any-display", "call", "agentShell", "reloadConfig", marker])
            if verify:
                self.wait_for_shell(marker)
                checks.append("Quickshell reload confirmed")
        return checks

    def wait_for_shell(self, marker):
        deadline = time.monotonic() + 55
        while time.monotonic() < deadline:
            log = command(["qs", "log", "-c", "ii", "--any-display", "--no-color", "--tail", "110"]).decode(errors="replace")
            _, found, fresh = log.rpartition("Desktop Agent reload " + marker)
            if found:
                if "Failed to load" in fresh or "config reload failed" in fresh.lower():
                    raise ToolError("Quickshell rejected the changed configuration")
                if "Configuration Loaded" in fresh:
                    return
            time.sleep(0.35)
        raise ToolError("Quickshell did not confirm a reload")

    def rebuild_theme(self):
        if not self.desktop or not self.editable:
            raise ToolError("Theme rebuild needs a Desktop job with editing enabled")
        relative = ".config/nothing-theme"
        source = self.root / relative
        self.resolve(relative)
        mode_path, mode_file = self.resolve(relative + "/mode")
        mode_source = self.stage / mode_path if mode_path in self.originals else mode_file
        mode = text_content(read_regular(mode_source)[0]).strip() if mode_source.is_file() else "dark"
        palette_path, palette = self.resolve(relative + ("/palette-light.json" if mode == "light" else "/palette.json"))
        current = self.stage / palette_path if palette_path in self.originals else palette
        palette = json.loads(text_content(read_regular(current)[0]))
        if not isinstance(palette, dict) or not all(
            isinstance(value, str) and re.fullmatch(r"#[a-fA-F0-9]{6}", value) for value in palette.values()
        ):
            raise ToolError("The theme palette must contain six-digit hex colors")
        # Use the same palette tokens as nothing-theme/render.py without executing workspace code.
        tokens = {**palette, "corner_radius": 8, "dark_mode": "false" if mode == "light" else "true", **{name + "_hex": value[1:] for name, value in palette.items()}}
        templates = source / "templates"
        candidates = []
        for path in sorted(templates.rglob("*.in")):
            name, _ = self.resolve(path.relative_to(self.root).as_posix())
            current = self.stage / name if name in self.originals else path
            output = path.relative_to(templates).with_suffix("").as_posix()
            pattern = text_content(read_regular(current)[0])
            if mode == "light" and output.endswith("/NothingDark.colors"):
                output = output.removesuffix("NothingDark.colors") + "NothingLight.colors"
                pattern = pattern.replace("Name=Nothing Dark", "Name=Nothing Light").replace("ColorScheme=NothingDark", "ColorScheme=NothingLight")
            relative_path, live = self.resolve(output, write=True)
            generated = Template(pattern).substitute(tokens).encode()
            if EXECUTION_PATTERN.search(generated.decode()) and output.endswith((".qml", ".lua")):
                raise ToolError("Theme templates may not add command-launching code")
            try:
                before, _ = read_regular(live)
            except FileNotFoundError:
                candidates.append((relative_path, generated, None))
            else:
                if before != generated or relative_path in self.originals:
                    candidates.append((relative_path, generated, digest(before)))
        active_path, active_file = self.resolve(relative + "/active.json", write=True)
        active = {key: palette[key] for key in ("black", "panel", "surface", "raised", "line", "outline", "muted", "text", "red")}
        active.update(dark=mode != "light", cornerRadius=8)
        data = (json.dumps(active, indent=2) + "\n").encode()
        if active_file.is_file():
            before = read_regular(active_file)[0]
            if before != data:
                candidates.append((active_path, data, digest(before)))
        else:
            candidates.append((active_path, data, None))
        for path, data, before in candidates:
            if before is not None:
                self.read_hashes[path] = before
            self.stage_bytes(path, data, create=before is None and path not in self.originals)
        return {"staged": [path for path, _, _ in candidates]}


# Inspect each affected line so replacing unrelated settings can keep existing launchers.
EXECUTION_PATTERN = re.compile(
    r"\b(?:exec_cmd|execDetached|exec|spawn|Popen|Process|eval|loadstring|loadfile|dofile|os\.execute|io\.popen)\b[^\n]*"
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def small_int(value, low, high, name):
    if type(value) is not int or not low <= value <= high:
        raise ToolError(f"{name} must be between {low} and {high}")
    return value


def desktop_logs(source, limit=35):
    limit = small_int(limit, 1, 90, "limit")
    if source == "quickshell":
        args = ["qs", "log", "-c", "ii", "--any-display", "--tail", str(limit), "--log-times", "--no-color"]
    elif source == "hyprland":
        args = ["hyprctl", "configerrors"]
    else:
        raise ToolError("Choose quickshell or hyprland")
    lines = command(args).decode(errors="replace").splitlines()
    return {"source": source, "lines": [line[:350] for line in deque(lines, maxlen=limit)]}
