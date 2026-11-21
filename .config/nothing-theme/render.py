"""Render the theme's dedicated config files below the selected home directory."""
import argparse
import json
from pathlib import Path
from string import Template

parser = argparse.ArgumentParser()
parser.add_argument("--root", type=Path, default=Path.home())
args = parser.parse_args()
theme = Path(__file__).resolve().parent
colors = json.loads((theme / "palette.json").read_text())
tokens = dict(colors)
# Match the original 8 px corners on the 40 px top bar.
tokens["corner_radius"] = 8
tokens.update({key + "_hex": value[1:] for key, value in colors.items()})
for template in sorted((theme / "templates").rglob("*.in")):
    target = args.root / template.relative_to(theme / "templates").with_suffix("")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(Template(template.read_text()).substitute(tokens))
