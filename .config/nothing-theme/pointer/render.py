"""Build the Graphite Pointer XCursor files from the desktop palette."""
import argparse
import io
import json
import struct
import subprocess
from pathlib import Path

from PIL import Image

SIZES = (24, 32, 48, 64)
IMAGE_TYPE = 0xFFFD0002
PALETTE = Path(__file__).resolve().parents[1] / "palette.json"


def pointer_shapes(colors):
    outline, white, red = (colors[key] for key in ("surface", "text", "red"))
    arrow = f"""
      <path d="M4 3 20 12.5 13 14l3.6 6.1-3.1 1.8-3.6-6.2L4 20Z"
            fill="{white}" stroke="{outline}" stroke-width="1.75" stroke-linejoin="round"/>
      <circle cx="7.6" cy="11.2" r="1.55" fill="{red}"/>"""
    hand = f"""
      <path d="M9 13V5a1.6 1.6 0 0 1 3.2 0v5.5l1.5-1 2 1 1.7-.5 2.5 1.6v3.9
               c0 2.1-.6 3.6-1.9 5.5h-7.3L5 14.6a1.6 1.6 0 0 1 2.2-2.2L9 14Z"
            fill="{white}" stroke="{outline}" stroke-width="1.65" stroke-linejoin="round"/>
      <circle cx="10.5" cy="6.5" r="1" fill="{red}"/>"""
    beam = "M8 4h8m-4 0v16m-4 0h8"
    text = f"""
      <path d="{beam}" fill="none" stroke="{outline}" stroke-width="3.5" stroke-linecap="round"/>
      <path d="{beam}" fill="none" stroke="{white}" stroke-width="2" stroke-linecap="round"/>
      <path d="M12 9v6" stroke="{red}" stroke-width="2" stroke-linecap="round"/>"""
    return (
        ("left_ptr", (4, 3), arrow, ("default", "arrow", "top_left_arrow")),
        ("hand2", (11, 3.5), hand, ("pointer", "pointing_hand", "9d800788f1b08800ae810202380a0822")),
        ("xterm", (12, 12), text, ("text", "ibeam")),
        ("vertical-text", (12, 12), f'<g transform="rotate(90 12 12)">{text}</g>', ()),
    )


def render_chunk(shape, hotspot, size):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">{shape}</svg>'
    png = subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size)],
        input=svg.encode(), capture_output=True, check=True,
    ).stdout
    with Image.open(io.BytesIO(png)) as image:
        red, green, blue, alpha = image.convert("RGBa").split()
        pixels = Image.merge("RGBA", (blue, green, red, alpha)).tobytes()
    x, y = (round(coord * size / 24) for coord in hotspot)
    return struct.pack("<9I", 36, IMAGE_TYPE, size, 1, size, size, x, y, 0) + pixels


def build_cursor(shape, hotspot):
    header = struct.pack("<4s3I", b"Xcur", 16, 0x10000, len(SIZES))
    offset = len(header) + 12 * len(SIZES)
    entries, chunks = [], []
    for size in SIZES:
        chunk = render_chunk(shape, hotspot, size)
        entries.append(struct.pack("<3I", IMAGE_TYPE, size, offset))
        chunks.append(chunk)
        offset += len(chunk)
    return header + b"".join(entries) + b"".join(chunks)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.home())
    root = parser.parse_args().root
    directory = root / ".local/share/icons/Graphite-Pointer/cursors"
    directory.mkdir(parents=True, exist_ok=True)
    colors = json.loads(PALETTE.read_text())
    for name, hotspot, shape, aliases in pointer_shapes(colors):
        (directory / name).write_bytes(build_cursor(shape, hotspot))
        for alias in aliases:
            link = directory / alias
            if link.is_symlink() and link.readlink() == Path(name):
                continue
            link.symlink_to(name)


if __name__ == "__main__":
    main()
