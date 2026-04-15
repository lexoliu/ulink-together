#!/usr/bin/env python3
"""burn-banners-fast.py

Same result as burn-banners.py but 20-50× faster:
  1. Pillow pre-renders every banner + narration caption to PNG.
  2. ffmpeg consumes the source video once, stacks all PNG overlays via
     a single filter_complex graph, and encodes with VideoToolbox on
     Apple Silicon (h264_videotoolbox).

Run:
    .venv/bin/python scripts/burn-banners-fast.py
"""

from __future__ import annotations

import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass

from PIL import Image, ImageDraw, ImageFont


REPO = pathlib.Path(__file__).resolve().parent.parent
# Prefer 1080p source; fall back to 720p .mov if present.
_CANDIDATES = [REPO / "doc" / "Crit_D_Video.m4v", REPO / "doc" / "Crit_D_Video.mov"]
RAW_VIDEO = next((p for p in _CANDIDATES if p.exists()), _CANDIDATES[0])
BANNER_JSON = REPO / "sc-banner-cues.json"
NARRATION_SRT = pathlib.Path(
    "/Users/lexoliu/Downloads/IBDP-CS-IA - HD 720p_srtCaptionSuffix_English.srt"
)
OUT_MP4 = REPO / "doc" / "Crit_D_Video.mp4"


NAVY = (24, 49, 83, 235)
AMBER = (230, 81, 0, 235)
WHITE = (255, 255, 255, 255)
BLACK_60 = (0, 0, 0, 153)

FONT = "/System/Library/Fonts/HelveticaNeue.ttc"

# All sizes are tuned for 1080p; 720p used 1.5× smaller numbers.
BANNER_FONT_SIZE = 32
BANNER_PAD_X, BANNER_PAD_Y = 22, 10
BANNER_RADIUS = 14
BANNER_ROW_H = 60
BANNER_LEFT = 36
BANNER_TOP = 36

NAR_FONT_SIZE = 34
NAR_MAX_RATIO = 0.9
NAR_PAD_X, NAR_PAD_Y = 22, 14
NAR_BOTTOM_MARGIN = 56


# ── Helpers ───────────────────────────────────────────────────

def hms_to_sec(stamp: str) -> float:
    stamp = stamp.replace(",", ".")
    h, m, s = stamp.split(":")
    return int(h) * 3600 + int(m) * 60 + float(s)


_SRT_TIMING = re.compile(
    r"(\d\d:\d\d:\d\d[,.]\d{3})\s*-->\s*(\d\d:\d\d:\d\d[,.]\d{3})"
)


@dataclass
class SrtCue:
    start: float
    end: float
    text: str


def parse_srt(path: pathlib.Path) -> list[SrtCue]:
    blocks = re.split(r"\n\s*\n", path.read_text(encoding="utf-8-sig").strip())
    cues: list[SrtCue] = []
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
                continue
            text_lines.append(ln)
        if not timing or not text_lines:
            continue
        text = " ".join(text_lines)
        text = re.sub(r"</?font[^>]*>", "", text)
        text = re.sub(r"<[^>]+>", "", text).strip()
        cues.append(SrtCue(*timing, text))
    return cues


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT, size=size, index=1 if bold else 0)


def _tsize(draw: ImageDraw.ImageDraw, text: str, font) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def render_banner(text: str, fill) -> Image.Image:
    font = _font(BANNER_FONT_SIZE, bold=True)
    scratch = Image.new("RGBA", (10, 10))
    d = ImageDraw.Draw(scratch)
    tw, th = _tsize(d, text, font)
    w = tw + 2 * BANNER_PAD_X
    h = th + 2 * BANNER_PAD_Y
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([(0, 0), (w - 1, h - 1)], radius=BANNER_RADIUS, fill=fill)
    bbox = d.textbbox((0, 0), text, font=font)
    d.text(
        ((w - (bbox[2] - bbox[0])) // 2 - bbox[0],
         (h - (bbox[3] - bbox[1])) // 2 - bbox[1]),
        text, font=font, fill=WHITE,
    )
    return img


def render_narration(text: str, video_w: int) -> Image.Image:
    font = _font(NAR_FONT_SIZE, bold=False)
    max_w = int(video_w * NAR_MAX_RATIO) - 2 * NAR_PAD_X
    scratch = Image.new("RGBA", (10, 10))
    sd = ImageDraw.Draw(scratch)
    words = text.split()
    lines, cur = [], []
    for w in words:
        candidate = " ".join(cur + [w])
        if _tsize(sd, candidate, font)[0] <= max_w or not cur:
            cur.append(w)
        else:
            lines.append(" ".join(cur))
            cur = [w]
    if cur:
        lines.append(" ".join(cur))
    sizes = [_tsize(sd, ln, font) for ln in lines]
    block_w = max(w for w, _ in sizes)
    line_h = max(h for _, h in sizes)
    gap = 4
    block_h = len(lines) * line_h + (len(lines) - 1) * gap
    W = block_w + 2 * NAR_PAD_X
    H = block_h + 2 * NAR_PAD_Y
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([(0, 0), (W - 1, H - 1)], radius=10, fill=BLACK_60)
    y = NAR_PAD_Y
    for ln, (lw, _) in zip(lines, sizes):
        d.text(((W - lw) // 2, y), ln, font=font, fill=WHITE)
        y += line_h + gap
    return img


def probe_size(path: pathlib.Path) -> tuple[int, int]:
    out = subprocess.check_output(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height",
         "-of", "csv=p=0:s=x", str(path)],
        text=True,
    ).strip()
    w, h = out.split("x")
    return int(w), int(h)


def probe_has_videotoolbox() -> bool:
    try:
        out = subprocess.check_output(
            ["ffmpeg", "-hide_banner", "-encoders"],
            text=True, stderr=subprocess.STDOUT,
        )
        return "h264_videotoolbox" in out
    except Exception:
        return False


def main() -> int:
    for p in (RAW_VIDEO, BANNER_JSON, NARRATION_SRT):
        if not p.exists():
            print(f"ERROR: missing input {p}", file=sys.stderr)
            return 1

    video_w, video_h = probe_size(RAW_VIDEO)
    print(f"Video: {RAW_VIDEO.name} ({video_w}x{video_h})")

    tmp = pathlib.Path(tempfile.mkdtemp(prefix="burn-"))
    print(f"Temp dir: {tmp}")

    banner_cues = json.loads(BANNER_JSON.read_text())
    # Sort by start time so earlier cues get lower rows when possible.
    resolved: list[dict] = []
    for cue in sorted(banner_cues, key=lambda c: (hms_to_sec(c["start"]), hms_to_sec(c["end"]))):
        resolved.append({
            **cue,
            "_start": hms_to_sec(cue["start"]),
            "_end": hms_to_sec(cue["end"]),
        })

    # Greedy row assignment: for each cue, find the lowest row whose
    # existing cues have all ended before this cue starts. Cues that
    # overlap in time (even partially) land on different rows.
    row_last_end: list[float] = []   # index = row, value = latest end time assigned to that row
    assignments: list[int] = []       # parallel to `resolved`
    for cue in resolved:
        placed = False
        for row, last_end in enumerate(row_last_end):
            if cue["_start"] >= last_end:
                row_last_end[row] = cue["_end"]
                assignments.append(row)
                placed = True
                break
        if not placed:
            assignments.append(len(row_last_end))
            row_last_end.append(cue["_end"])

    overlays: list[tuple[pathlib.Path, int, int, float, float]] = []
    for i, (cue, row) in enumerate(zip(resolved, assignments)):
        style = cue.get("style", "primary")
        fill = AMBER if style in ("gap", "bonus") else NAVY
        img = render_banner(cue["banner_text"], fill)
        p = tmp / f"banner-{i:03d}.png"
        img.save(p)
        overlays.append((
            p, BANNER_LEFT, BANNER_TOP + row * BANNER_ROW_H,
            cue["_start"], cue["_end"],
        ))
    print(f"Banners: {len(resolved)} PNGs across {len(row_last_end)} row(s)")

    nar_cues = parse_srt(NARRATION_SRT)
    j = 0
    for cue in nar_cues:
        img = render_narration(cue.text, video_w)
        p = tmp / f"nar-{j:03d}.png"
        img.save(p)
        iw, ih = img.size
        overlays.append((p, (video_w - iw) // 2, video_h - ih - NAR_BOTTOM_MARGIN, cue.start, cue.end))
        j += 1
    print(f"Narrations: {j} PNGs")
    print(f"Total overlays: {len(overlays)}")

    cmd: list[str] = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "warning", "-stats"]
    cmd += ["-i", str(RAW_VIDEO)]
    for path, *_ in overlays:
        cmd += ["-i", str(path)]

    filter_parts: list[str] = []
    last_label = "0:v"
    for idx, (_, x, y, start, end) in enumerate(overlays, start=1):
        out_label = f"v{idx}"
        filter_parts.append(
            f"[{last_label}][{idx}:v]overlay=x={x}:y={y}:"
            f"enable='between(t,{start:.3f},{end:.3f})'[{out_label}]"
        )
        last_label = out_label

    filter_complex = ";".join(filter_parts)
    cmd += ["-filter_complex", filter_complex]
    cmd += ["-map", f"[{last_label}]", "-map", "0:a?"]

    if probe_has_videotoolbox():
        # 1080p @ 60fps → 8000 kbps keeps UI text sharp; 720p needs ~4000.
        bitrate = "8000k" if video_h >= 1000 else "4000k"
        cmd += [
            "-c:v", "h264_videotoolbox",
            "-b:v", bitrate,
            "-profile:v", "high",
            "-pix_fmt", "yuv420p",
        ]
        print(f"Encoder: h264_videotoolbox (Apple Silicon HW), {bitrate}")
    else:
        cmd += [
            "-c:v", "libx264",
            "-preset", "medium",
            "-crf", "20",
            "-pix_fmt", "yuv420p",
        ]
        print("Encoder: libx264 (software fallback)")

    cmd += ["-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"]
    cmd += [str(OUT_MP4)]

    print(f"\nRunning ffmpeg with {len(overlays)} overlay inputs…\n")
    t0 = time.monotonic()
    proc = subprocess.run(cmd)
    elapsed = time.monotonic() - t0

    if proc.returncode != 0:
        print(f"ffmpeg failed with exit code {proc.returncode}", file=sys.stderr)
        return proc.returncode

    size_mb = OUT_MP4.stat().st_size / (1024 * 1024)
    print(f"\nDone in {elapsed:.1f}s → {OUT_MP4} ({size_mb:.1f} MB)")
    shutil.rmtree(tmp, ignore_errors=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
