#!/usr/bin/env python3
"""banners-to-fcpxml.py

Convert an SC banner cue list (JSON) and a source video file into a
FCPXML v1.11 document that can be imported into Final Cut Pro.

Each cue becomes a Basic Title clip on a connected storyline above
the main video, positioned so that multiple SCs stacked on the same
timerange (e.g. SC4+SC5+SC7 at 05:38) render on separate rows.

Usage:
    python3 scripts/banners-to-fcpxml.py \\
        --video doc/Crit_D_Video.mp4 \\
        --cues  doc/sc-banner-cues.json \\
        --out   output/sc-banners.fcpxml

Then in Final Cut Pro:
    File -> Import -> XML ... -> pick sc-banners.fcpxml
    A new Event + Project will appear. Open the Project; the video
    is on the primary storyline, the banners are connected Title
    clips above it. Re-style the Titles once and paste-attributes
    onto the rest.
"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
import subprocess
import sys
import uuid
import xml.etree.ElementTree as ET
from fractions import Fraction
from typing import List, Tuple


# ── Timecode ────────────────────────────────────────────────

# FCPXML uses rational-number time expressed in the project's timebase.
# We pin the timebase to 30000/1001 (29.97 fps, NTSC) by default but
# probe the video for the real frame rate.

def probe_video_fps(path: pathlib.Path) -> Fraction:
    """Return the video's frame rate as a Fraction."""
    try:
        out = subprocess.check_output(
            [
                "ffprobe", "-v", "error", "-select_streams", "v:0",
                "-show_entries", "stream=r_frame_rate",
                "-of", "default=nokey=1:noprint_wrappers=1",
                str(path),
            ],
            text=True,
        ).strip()
        num, den = (int(x) for x in out.split("/"))
        return Fraction(num, den)
    except Exception:
        return Fraction(30000, 1001)


def probe_video_duration_seconds(path: pathlib.Path) -> float:
    out = subprocess.check_output(
        [
            "ffprobe", "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=nokey=1:noprint_wrappers=1",
            str(path),
        ],
        text=True,
    ).strip()
    return float(out)


def probe_video_size(path: pathlib.Path) -> Tuple[int, int]:
    out = subprocess.check_output(
        [
            "ffprobe", "-v", "error", "-select_streams", "v:0",
            "-show_entries", "stream=width,height",
            "-of", "csv=p=0:s=x",
            str(path),
        ],
        text=True,
    ).strip()
    w, h = out.split("x")
    return int(w), int(h)


def hms_to_seconds(stamp: str) -> float:
    """Accept 'HH:MM:SS', 'MM:SS', or 'SS'."""
    parts = [float(p) for p in stamp.split(":")]
    if len(parts) == 3:
        h, m, s = parts
    elif len(parts) == 2:
        h, m, s = 0, parts[0], parts[1]
    else:
        h, m, s = 0, 0, parts[0]
    return h * 3600 + m * 60 + s


def seconds_to_fcp_time(seconds: float, fps: Fraction) -> str:
    """Return FCPXML rational time like '12012/6000s'.

    FCPXML time is expressed as numerator/denominator, where the
    denominator is the timebase (usually timebase * 2). We keep it
    simple and use the fraction (seconds * fps.denominator * fps.numerator).
    The safest universal form is frames/fps where the denominator is
    fps.denominator * fps.numerator and the numerator is round(seconds * fps).
    """
    # Use a common tick base that is an integer multiple of the fps.
    # 24000 works for 23.976, 25, 29.97 and 30 fps.
    tickbase = 24000
    ticks = round(seconds * tickbase)
    return f"{ticks}/{tickbase}s"


# ── FCPXML generation ───────────────────────────────────────

FCPXML_VERSION = "1.11"


def build_fcpxml(
    video_path: pathlib.Path,
    cues: List[dict],
    fps: Fraction,
    width: int,
    height: int,
    duration_seconds: float,
) -> ET.ElementTree:
    # Frame duration: expressed as a rational (1001/30000s for 29.97).
    frame_duration = f"{fps.denominator}/{fps.numerator}s"

    fcpxml = ET.Element("fcpxml", version=FCPXML_VERSION)

    # Resources: a format, the video asset, and the built-in
    # "Basic Title" effect.
    resources = ET.SubElement(fcpxml, "resources")

    fmt_id = "r1"
    ET.SubElement(
        resources, "format",
        id=fmt_id,
        name=f"FFVideoFormat{width}x{height}p{float(fps):.2f}".replace(".", ""),
        frameDuration=frame_duration,
        width=str(width),
        height=str(height),
        colorSpace="1-1-1 (Rec. 709)",
    )

    asset_id = "r2"
    asset = ET.SubElement(
        resources, "asset",
        id=asset_id,
        name=video_path.stem,
        start="0s",
        hasVideo="1",
        hasAudio="1",
        format=fmt_id,
        duration=seconds_to_fcp_time(duration_seconds, fps),
    )
    ET.SubElement(
        asset, "media-rep",
        kind="original-media",
        src=video_path.resolve().as_uri(),
    )

    # Built-in Basic Title effect. FCP ships this at a known uid.
    effect_id = "r3"
    ET.SubElement(
        resources, "effect",
        id=effect_id,
        name="Basic Title",
        uid=".../Titles.localized/Build In:Out.localized/Basic Title.localized/Basic Title.moti",
    )

    # Library / event / project / sequence ------------------------------
    library = ET.SubElement(fcpxml, "library")
    event = ET.SubElement(library, "event", name="Crit D – SC banners")
    project = ET.SubElement(event, "project", name="Crit D Video with SC Banners")
    sequence = ET.SubElement(
        project, "sequence",
        format=fmt_id,
        duration=seconds_to_fcp_time(duration_seconds, fps),
        tcStart="0s",
        tcFormat="NDF",
        audioLayout="stereo",
        audioRate="48k",
    )
    spine = ET.SubElement(sequence, "spine")

    # Primary storyline: the video ------------------------------------
    clip = ET.SubElement(
        spine, "asset-clip",
        name=video_path.stem,
        ref=asset_id,
        offset="0s",
        duration=seconds_to_fcp_time(duration_seconds, fps),
        start="0s",
        format=fmt_id,
        tcFormat="NDF",
        audioRole="dialogue",
    )

    # Group cues by (start, end) so stacked SCs on the same range get
    # different row offsets.
    def key(c):
        return (c["start"], c["end"])

    grouped: dict[Tuple[str, str], List[dict]] = {}
    for cue in cues:
        grouped.setdefault(key(cue), []).append(cue)

    # Each title is a connected clip off the primary asset-clip.
    for (start_str, end_str), stack in grouped.items():
        start_s = hms_to_seconds(start_str)
        end_s = hms_to_seconds(end_str)
        duration_s = max(end_s - start_s, 0.1)

        for row, cue in enumerate(stack):
            text = cue["banner_text"]
            style = cue.get("style", "primary")
            ts_id = f"ts-{uuid.uuid4().hex[:8]}"

            title = ET.SubElement(
                clip, "title",
                name=text,
                lane=str(row + 1),
                offset=seconds_to_fcp_time(start_s, fps),
                ref=effect_id,
                duration=seconds_to_fcp_time(duration_s, fps),
                start=seconds_to_fcp_time(start_s, fps),
            )

            # FCPXML DTD requires strict order inside <title>:
            #   (param* , text* , text-style-def* , ...)

            # 1. param elements come FIRST.
            # Position (pixels from centre; +y is up). Each stacked row
            # sits ~90 px below the previous one so they don't overlap.
            x_offset = -width * 0.22
            y_offset = height * 0.40 - row * 90
            ET.SubElement(
                title, "param",
                name="Position",
                key="9999/999166631/999166633/1/100/101",
                value=f"{x_offset:.0f} {y_offset:.0f}",
            )

            # 2. text element(s) — hold the visible caption.
            text_el = ET.SubElement(title, "text")
            ts = ET.SubElement(text_el, "text-style", ref=ts_id)
            ts.text = text

            # 3. text-style-def(s) — define the style referenced above.
            text_style_def = ET.SubElement(
                title, "text-style-def",
                id=ts_id,
            )
            ET.SubElement(
                text_style_def, "text-style",
                font="Helvetica Neue",
                fontSize="56",
                fontColor=_color_for_style(style),
                bold="1",
                alignment="center",
            )

    tree = ET.ElementTree(fcpxml)
    return tree


def _color_for_style(style: str) -> str:
    """Return FCPXML RGBA color string for the banner style."""
    if style == "gap":
        # amber
        return "0.902 0.318 0 1"
    if style == "bonus":
        # amber (same family, slightly different shade)
        return "0.902 0.318 0 1"
    # primary — white text on navy bg; FCP title can only set text colour,
    # so use white and the operator can add a navy background shape later.
    return "1 1 1 1"


# ── Main ────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--video", required=True, type=pathlib.Path)
    ap.add_argument("--cues", required=True, type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    args = ap.parse_args()

    if not args.video.exists():
        print(f"ERROR: video not found: {args.video}", file=sys.stderr)
        return 1
    if not args.cues.exists():
        print(f"ERROR: cues JSON not found: {args.cues}", file=sys.stderr)
        return 1

    cues = json.loads(args.cues.read_text())
    if not isinstance(cues, list) or not cues:
        print("ERROR: cues JSON must be a non-empty list.", file=sys.stderr)
        return 1

    fps = probe_video_fps(args.video)
    width, height = probe_video_size(args.video)
    duration = probe_video_duration_seconds(args.video)

    print(f"Video: {args.video} ({width}x{height} @ {float(fps):.3f} fps, {duration:.2f}s)")
    print(f"Cues : {len(cues)}")

    tree = build_fcpxml(args.video, cues, fps, width, height, duration)
    args.out.parent.mkdir(parents=True, exist_ok=True)

    # Pretty-print
    ET.indent(tree, space="  ", level=0)
    tree.write(args.out, xml_declaration=True, encoding="utf-8")

    print(f"Wrote {args.out}")
    print("")
    print("Next step: in Final Cut Pro, File -> Import -> XML... and pick")
    print(f"           {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
