"""Resolve desktop vocabulary to scoped QML components and navigation links."""

from pathlib import Path
import re

from agent_workspace import load_json

ROOT = ".config/quickshell/ii/modules/ii"
LABEL = re.compile(r'(?:Translation\.tr\(|buttonIcon:\s*)"([^"\n]+)"')
COMPONENT = re.compile(r'^\s*([A-Z][A-Za-z0-9]+)\s*\{', re.M)


def words(value):
    return " " + " ".join(re.findall(r"\w+", value.casefold().replace("_", " "))) + " "


def locate(workspace, query):
    catalog = load_json(Path(__file__).with_name("desktop-components.json"))
    term = words(query)
    ranked = []
    for name, spec in catalog.items():
        folder = f"{ROOT}/{spec['folder']}"
        entry = f"{folder}/{spec['entry']}"
        matches = [alias for alias in spec["aliases"] if words(alias) in term]
        hints = []
        sources = workspace.find_files("*.qml", folder, limit=75)["matches"]
        for path in sources:
            if path.rsplit("/", 1)[0] != folder:
                continue
            _, source = workspace.resolve(path)
            code = source.read_text(encoding="utf-8")
            labels = LABEL.findall(code)
            hits = sorted({label for label in labels if len(label) > 2 and words(label) in term})
            if hits:
                hints.append({"path": path, "matches": hits[:6]})
        if not (matches or hints):
            continue
        _, source = workspace.resolve(entry)
        code = source.read_text(encoding="utf-8")
        shared = sorted({f"{folder}/{part}.qml" for part in COMPONENT.findall(code)} & set(sources))
        links = [{"handler_file": entry, "handler": handler, "opens": target,
                  "opened_file": f"{ROOT}/{catalog[target]['folder']}/{catalog[target]['entry']}"}
                 for handler, target in spec.get("opens", {}).items() if handler in code]
        ranked.append((len(matches) * 4 + min(len(hints), 3), {
            "component": name, "entry": entry, "matching_files": hints[:6],
            "local_components": shared[:12], "navigation": links,
        }))
    return [entry for _, entry in sorted(ranked, key=lambda item: -item[0])][:4]
