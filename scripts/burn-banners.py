#!/usr/bin/env python3
"""burn-banners.py

Burn SC banners + narration SRT into the final Crit D video.

Inputs (paths are relative to repo root):
    doc/Crit_D_Video.mov                    — raw screen recording
    /Users/lexoliu/Downloads/IBDP-CS-IA - HD 720p_srtCaptionSuffix_English.srt
                                             — narration captions
    sc-banner-cues.json                     — SC banner cue list

Output:
    doc/Crit_D_Video.mp4                    — final banner-overlaid MP4

Design:
  * Each banner is a Pillow-rendered rounded pill (navy #183153 for
    primary / amber #e65100 for gap + bonus) composited at the top-left.
  * Stacked banners on the same timerange sit in separate rows that
    don't overlap.
  * Narration SRT is burned as centered bottom captions with a
    semi-transparent pill behind the text for legibility.
  * Output is H.264 MP4, preserving source resolution and frame rate.

Run:
    .venv/bin/python scripts/burn-banners.py
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
from dataclasses import dataclass
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont
import numpy as np

from moviepy import (
    VideoFileClip,
    ImageClip,
    CompositeVideoClip,
)


# ── Paths ─────────────────────────────────────────────────────

REPO = pathlib.Path(__file__).resolve().parent.parent
RAW_VIDEO = REPO / "doc" / "Crit_D_Video.mov"
BANNER_JSON = REPO / "sc-banner-cues.json"
NARRATION_SRT = pathlib.Path(
    "/Users/lexoliu/Downloads/IBDP-CS-IA - HD 720p_srtCaptionSuffix_English.srt"
)
OUT_MP4 = REPO / "doc" / "Crit_D_Video.mp4"

# ── Visual tokens ─────────────────────────────────────────────

NAVY = (24, 49, 83, 235)          # primary banner fill
AMBER = (230, 81, 0, 235)         # gap + bonus banner fill
WHITE = (255, 255, 255, 255)
BLACK_60 = (0, 0, 0, 153)         # narration caption backdrop

FONT_BOLD = "/System/Library/Fonts/HelveticaNeue.ttc"
FONT_REGULAR = "/System/Library/Fonts/HelveticaNeue.ttc"

# Banner sizing (pixels, tuned for 1280×720 source).
BANNER_FONT_SIZE = 22
BANNER_PADDING_X = 16
BANNER_PADDING_Y = 8
BANNER_CORNER_RADIUS = 10
BANNER_ROW_HEIGHT = 44       # distance between stacked rows
BANNER_MARGIN_LEFT = 24
BANNER_MARGIN_TOP = 24

# Narration caption sizing.
NARRATION_FONT_SIZE = 24
NARRATION_MAX_WIDTH_RATIO = 0.9
NARRATION_PADDING_X = 16
NARRATION_PADDING_Y = 10
NARRATION_MARGIN_BOTTOM = 40


# ── Time helpers ──────────────────────────────────────────────

def hms_to_sec(stamp: str) -> float:
    """Accept 'HH:MM:SS', 'HH:MM:SS,fff', or 'HH:MM:SS.fff'."""
    stamp = stamp.replace(",", ".")
    h, m, s = stamp.split(":")
    return int(h) * 3600 + int(m) * 60 + float(s)


# ── SRT parsing ───────────────────────────────────────────────

_SRT_TIMING = re.compile(
    r"(\d\d:\d\d:\d\d[,.]\d{3})\s*-->\s*(\d\d:\d\d:\d\d[,.]\d{3})"
)


@dataclass
class Cue:
    start: float
    end: float
    text: str


def parse_srt(path: pathlib.Path) -> list[Cue]:
    """Parse an SRT file and strip common HTML-style tags."""
    blocks = re.split(r"\n\s*\n", path.read_text(encoding="utf-8-sig").strip())
    cues: list[Cue] = []
    for block in blocks:
        lines = [ln for ln in block.splitlines() if ln.strip()]
        if len(lines) < 2:
            continue
        timing = None
        text_lines: list[str] = []
        for ln in lines:
            m = _SRT_TIMING.search(ln)
            if m and timing is None:
                timing = (hms_to_sec(m.group(1)), hms_to_sec(m.group(2)))
                continue
            if ln.isdigit() and timing is None:
                continue  # SRT index line
            text_lines.append(ln)
        if not timing or not text_lines:
            continue
        text = " ".join(text_lines)
        # strip inline font tags, e.g. <font color="#ffffff">...</font>
        text = re.sub(r"</?font[^>]*>", "", text)
        text = re.sub(r"<[^>]+>", "", text).strip()
        cues.append(Cue(start=timing[0], end=timing[1], text=text))
    return cues


# ── Pillow rendering ──────────────────────────────────────────

def _load_font(path: str, size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    # HelveticaNeue.ttc — index 0 Regular, index 1 Bold.
    try:
        return ImageFont.truetype(path, size=size, index=1 if bold else 0)
    except Exception:
        return ImageFont.load_default()


def _text_size(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def render_banner_png(text: str, fill: tuple[int, int, int, int]) -> Image.Image:
    """Render a pill-shaped banner as an RGBA PIL Image."""
    font = _load_font(FONT_BOLD, BANNER_FONT_SIZE, bold=True)
    # Measure the text on a scratch surface.
    scratch = Image.new("RGBA", (10, 10))
    draw = ImageDraw.Draw(scratch)
    tw, th = _text_size(draw, text, font)

    w = tw + 2 * BANNER_PADDING_X
    h = th + 2 * BANNER_PADDING_Y

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(
        [(0, 0), (w - 1, h - 1)],
        radius=BANNER_CORNER_RADIUS,
        fill=fill,
    )
    # Re-measure with baseline-anchor for clean vertical centring.
    ascent, descent = font.getmetrics()
    # Pillow draws from top-left of the glyph box; measure bbox again.
    bbox = d.textbbox((0, 0), text, font=font)
    text_x = (w - (bbox[2] - bbox[0])) // 2 - bbox[0]
    text_y = (h - (bbox[3] - bbox[1])) // 2 - bbox[1]
    d.text((text_x, text_y), text, font=font, fill=WHITE)
    return img


def render_narration_png(text: str, video_width: int) -> Image.Image:
    """Render a centered narration caption with a soft pill backdrop.

    Wraps to multiple lines if the text would exceed the target width.
    """
    font = _load_font(FONT_REGULAR, NARRATION_FONT_SIZE, bold=False)
    max_text_width = int(video_width * NARRATION_MAX_WIDTH_RATIO) - 2 * NARRATION_PADDING_X

    # Simple greedy word-wrap to fit max_text_width.
    scratch = Image.new("RGBA", (10, 10))
    sd = ImageDraw.Draw(scratch)
    words = text.split()
    lines: list[str] = []
    current: list[str] = []
    for word in words:
        candidate = " ".join(current + [word])
        w, _ = _text_size(sd, candidate, font)
        if w <= max_text_width or not current:
            current.append(word)
        else:
            lines.append(" ".join(current))
            current = [word]
    if current:
        lines.append(" ".join(current))

    # Measure block.
    line_sizes = [_text_size(sd, ln, font) for ln in lines]
    block_w = max(w for w, _ in line_sizes)
    line_h = max(h for _, h in line_sizes)
    line_gap = 4
    block_h = len(lines) * line_h + (len(lines) - 1) * line_gap

    w = block_w + 2 * NARRATION_PADDING_X
    h = block_h + 2 * NARRATION_PADDING_Y

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(
        [(0, 0), (w - 1, h - 1)],
        radius=10,
        fill=BLACK_60,
    )
    y = NARRATION_PADDING_Y
    for ln, (lw, lh) in zip(lines, line_sizes):
        x = (w - lw) // 2
        d.text((x, y), ln, font=font, fill=WHITE)
        y += line_h + line_gap
    return img


# ── MoviePy clip builders ─────────────────────────────────────

def banner_clips(cues: list[dict]) -> list[ImageClip]:
    """Turn the SC banner JSON into positioned ImageClips.

    Stacked SCs on the same timerange get different vertical rows.
    """
    # Group by (start, end) so stacked banners know their row index.
    groups: dict[tuple[float, float], list[dict]] = {}
    for cue in cues:
        key = (hms_to_sec(cue["start"]), hms_to_sec(cue["end"]))
        groups.setdefault(key, []).append(cue)

    clips: list[ImageClip] = []
    for (start, end), stack in groups.items():
        duration = max(end - start, 0.1)
        for row, cue in enumerate(stack):
            style = cue.get("style", "primary")
            fill = AMBER if style in ("gap", "bonus") else NAVY
            img = render_banner_png(cue["banner_text"], fill)
            arr = np.array(img)
            clip = (
                ImageClip(arr, transparent=True)
                .with_start(start)
                .with_duration(duration)
                .with_position((
                    BANNER_MARGIN_LEFT,
                    BANNER_MARGIN_TOP + row * BANNER_ROW_HEIGHT,
                ))
            )
            clips.append(clip)
    return clips


def narration_clips(cues: list[Cue], video_width: int, video_height: int) -> list[ImageClip]:
    """Turn the narration SRT into bottom-centered ImageClips."""
    clips: list[ImageClip] = []
    for cue in cues:
        duration = max(cue.end - cue.start, 0.1)
        img = render_narration_png(cue.text, video_width)
        arr = np.array(img)
        w, h = img.size
        clip = (
            ImageClip(arr, transparent=True)
            .with_start(cue.start)
            .with_duration(duration)
            .with_position((
                (video_width - w) // 2,
                video_height - h - NARRATION_MARGIN_BOTTOM,
            ))
        )
        clips.append(clip)
    return clips


# ── Main ──────────────────────────────────────────────────────

def main() -> int:
    if not RAW_VIDEO.exists():
        print(f"ERROR: raw video missing at {RAW_VIDEO}", file=sys.stderr)
        return 1
    if not NARRATION_SRT.exists():
        print(f"ERROR: narration SRT missing at {NARRATION_SRT}", file=sys.stderr)
        return 1
    if not BANNER_JSON.exists():
        print(f"ERROR: banner JSON missing at {BANNER_JSON}", file=sys.stderr)
        return 1

    print(f"Loading video: {RAW_VIDEO}")
    base = VideoFileClip(str(RAW_VIDEO))
    print(f"  {base.w}x{base.h} @ {base.fps} fps, {base.duration:.2f}s")

    banner_cues = json.loads(BANNER_JSON.read_text())
    print(f"Banners: {len(banner_cues)}")
    banners = banner_clips(banner_cues)

    narration = parse_srt(NARRATION_SRT)
    print(f"Narration cues: {len(narration)}")
    captions = narration_clips(narration, base.w, base.h)

    print("Compositing …")
    final = CompositeVideoClip([base, *banners, *captions], size=(base.w, base.h))
    final = final.with_duration(base.duration)

    print(f"Rendering → {OUT_MP4}")
    final.write_videofile(
        str(OUT_MP4),
        codec="libx264",
        audio_codec="aac",
        fps=base.fps,
        preset="medium",
        threads=4,
        bitrate="4000k",
    )
    base.close()
    final.close()
    size_mb = OUT_MP4.stat().st_size / (1024 * 1024)
    print(f"Done. Wrote {OUT_MP4} ({size_mb:.1f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
