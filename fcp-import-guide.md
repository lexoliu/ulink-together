# Importing SC Banners into Final Cut Pro

> This guide turns the SC banner cue list (`sc-banner-cues.json`) into
> a Final Cut Pro project with every banner placed on the timeline
> above your Criterion D video, ready for you to restyle and export.

---

## Option A — Recommended: FCPXML (one command, native import)

### Prerequisites

- macOS with Final Cut Pro installed
- `python3` (preinstalled on macOS 12+) and `ffprobe` in PATH
  - If `ffprobe` is missing: `brew install ffmpeg`
- Your raw video at `doc/Crit_D_Video.mov` (or `.mp4`)
- `sc-banner-cues.json` at the repo root (already written)

### Step 1. Generate the FCPXML

From the repo root:

```bash
python3 scripts/banners-to-fcpxml.py \
    --video doc/Crit_D_Video.mov \
    --cues  sc-banner-cues.json \
    --out   output/sc-banners.fcpxml
```

This has already been run once — the output is at
`output/sc-banners.fcpxml` (1280×720 @ 60 fps, 6:56.48, 42 banners).

The script will probe the video's frame rate and resolution, then
produce `output/sc-banners.fcpxml` describing:

- one Event called **"Crit D – SC banners"**
- one Project containing your video on the primary storyline
- every cue as a connected **Basic Title** clip placed at the correct
  offset on a lane above the video
- stacked SCs at the same timecode (e.g. SC4 + SC5 + SC7 at 05:38) are
  placed on separate lanes so they don't overlap each other

### Step 2. Import into Final Cut Pro

1. Open Final Cut Pro.
2. **File → Import → XML…** and select `output/sc-banners.fcpxml`.
3. FCP creates a Library entry, an Event, and a Project. Double-click
   the Project to open it on the timeline.

### Step 3. Restyle the banners (one-time)

The FCPXML ships plain white Helvetica titles. Do this once, paste to
the rest:

1. Select the first banner clip on the timeline.
2. In the Inspector → Title tab, apply your preferred style
   (background colour #183153, text colour white, corner radius 8 px,
   font Helvetica Neue Bold 28 px). These controls live in the
   built-in "Basic Title" settings.
3. With that clip still selected: **Edit → Copy**.
4. Select every other banner clip (⌘-click to multi-select, or use
   **Edit → Select All Clips Forward** and then deselect the video
   clip below).
5. **Edit → Paste Attributes…** and tick **Title Attributes / Style**.
6. Do the same once for GAP and BONUS banners with the amber styling
   (`#e65100`).

### Step 4. Verify timing

- Move the playhead across each banner and confirm it starts and ends
  at the right moment relative to the narration.
- If a clip is a frame or two off, nudge with `,` / `.` keys.

### Step 5. Export to MP4 (IB-safe format)

IB handbook p18: **"MP4 format is safest — if the video is not
compatible with the marker's computer they are not obligated to fix it."**
So do NOT export as `.mov`.

**File → Share → Export File…**
- Format: **Computer**
- Video codec: **H.264**
- Resolution: **1280×720** (match source)
- Frame rate: **60 fps** (match source)
- Audio: **AAC 48 kHz stereo**
- Output filename: `Crit_D_Video`
- Output folder: the `doc/` directory of this repo

Final path: `doc/Crit_D_Video.mp4`.

After FCP finishes exporting, re-run the packaging script:

```bash
bash scripts/package-ia.sh
```

The script automatically prefers `Crit_D_Video.mp4` over
`Crit_D_Video.mov`, so the new banner-overlayed MP4 will go into
`output/0011_lyj129/Documentation/Crit_D_Video.mp4` and the
accompanying ZIP.

---

## Option B — Quick-and-dirty: SRT subtitles

If you do not need per-banner styling and only want the SC labels to
appear briefly, convert the JSON to SRT and let FCP's Subtitle track
render them:

```bash
python3 - <<'PY'
import json, pathlib
cues = json.loads(pathlib.Path("sc-banner-cues.json").read_text())

def hmsms(stamp):
    h,m,s = (0, *map(float, stamp.split(":")))[-3:]
    total = h*3600 + m*60 + s
    hh = int(total // 3600); mm = int((total % 3600) // 60)
    ss = int(total % 60); ms = int((total - int(total)) * 1000)
    return f"{hh:02d}:{mm:02d}:{ss:02d},{ms:03d}"

out = []
for i, c in enumerate(cues, 1):
    out.append(f"{i}\n{hmsms(c['start'])} --> {hmsms(c['end'])}\n{c['banner_text']}\n")
pathlib.Path("output/sc-banners.srt").write_text("\n".join(out))
print("Wrote output/sc-banners.srt")
PY
```

Then in Final Cut Pro: **File → Import → Captions…** and select
`output/sc-banners.srt`. The captions will appear on a caption role.
The downside: SRT captions are plain text rendered at the bottom of
the frame — you cannot style them as navy pills in the top-left. Use
Option A for any submission-quality work.

---

## Option C — Manual placement from a reference image

If you just want a visual reference to drop Title cards by hand:

1. Open `sc-banner-cues.json` alongside Final Cut Pro.
2. For each cue, add **Titles → Basic Title** at the cue's start,
   set duration to (end − start), paste the `banner_text` in.

This is only worth it for quick one-off edits — 41 cues by hand is
slow and error-prone.

---

## Troubleshooting

- **"The file could not be imported" on XML import** — open the
  FCPXML in a text editor and check the `version="1.11"` attribute is
  supported by your FCP version (FCP 10.6+ supports 1.11; older
  versions: change to `1.9` or `1.10`).
- **Banner appears at a weird position** — FCP ignores the raw
  `Position` param and uses the title's default centre. Click any
  banner, then in the Viewer's Transform tool drag it to the desired
  location; Copy → Paste Attributes → Transform onto the rest.
- **Two stacked cues overlap** — the script writes them to `lane="1"`
  and `lane="2"`. Make sure you did not delete a lane during editing.
- **ffprobe command not found** — `brew install ffmpeg` installs
  ffprobe alongside ffmpeg.

---

## Checklist before exporting the final MP4

- [ ] Opening Stack bumper (00:00–00:05) renders correctly
- [ ] GAP banners at 01:39 and 03:59 show amber style, not navy
- [ ] BONUS banner at 01:08 shows amber style
- [ ] SC10 banner appears on the iPad leaderboard shot (01:25–01:33)
- [ ] No banner overlaps the burned-in subtitles at the bottom
- [ ] Export matches source resolution and frame rate
- [ ] Final file is at `doc/Crit_D_Video.mp4`, size ≤ 1 GB
- [ ] Video length still ≤ 7:00 (IB hard limit)
- [ ] Re-run `bash scripts/package-ia.sh` to refresh the ZIP
