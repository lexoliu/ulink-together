#!/usr/bin/env python3
"""banners-to-srt.py

Convert the SC banner cue list (JSON) into an SRT subtitle file that
Final Cut Pro can import in one click.

Usage:
    python3 scripts/banners-to-srt.py

Outputs:
    output/sc-banners.srt

Then in Final Cut Pro:
    File -> Import -> Captions... -> pick output/sc-banners.srt
"""

from __future__ import annotations

import json
import pathlib
import sys


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
CUES = REPO_ROOT / "sc-banner-cues.json"
OUT = REPO_ROOT / "output" / "sc-banners.srt"


def hms_to_ms(stamp: str) -> int:
    """Accept 'HH:MM:SS' or 'HH:MM:SS.sss'; return total milliseconds."""
    parts = stamp.split(":")
    if len(parts) != 3:
        raise ValueError(f"expected HH:MM:SS, got {stamp!r}")
    h, m, s = parts
    sec = float(s)
    return int(int(h) * 3600_000 + int(m) * 60_000 + sec * 1000)


def ms_to_srt_stamp(ms: int) -> str:
    h, rem = divmod(ms, 3600_000)
    m, rem = divmod(rem, 60_000)
    s, ms = divmod(rem, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def style_prefix(style: str) -> str:
    """Short visual tag so the moderator can tell cue categories apart
    when captions are rendered as plain text."""
    if style == "gap":
        return "⚠ "
    if style == "bonus":
        return "★ "
    return ""


def main() -> int:
    if not CUES.exists():
        print(f"ERROR: cue JSON missing at {CUES}", file=sys.stderr)
        return 1

    cues = json.loads(CUES.read_text())
    # Sort by start time so SRT indices are chronological.
    cues.sort(key=lambda c: hms_to_ms(c["start"]))

    OUT.parent.mkdir(parents=True, exist_ok=True)

    with OUT.open("w") as f:
        for i, cue in enumerate(cues, start=1):
            start = ms_to_srt_stamp(hms_to_ms(cue["start"]))
            end = ms_to_srt_stamp(hms_to_ms(cue["end"]))
            text = style_prefix(cue.get("style", "primary")) + cue["banner_text"]
            f.write(f"{i}\n{start} --> {end}\n{text}\n\n")

    print(f"Wrote {OUT} ({len(cues)} cues)")
    print()
    print("Next step: in Final Cut Pro,")
    print("  File -> Import -> Captions...  and pick")
    print(f"  {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
