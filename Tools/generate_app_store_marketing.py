#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "AppStore" / "Marketing"
ICON = ROOT / "MManger" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"


INK = (36, 39, 52)
MUTED = (111, 114, 132)
VIOLET = (144, 92, 245)
LAVENDER = (196, 155, 255)
TEAL = (34, 190, 171)
MINT = (111, 221, 188)
CORAL = (255, 113, 126)
GOLD = (255, 203, 92)
LINE = (232, 226, 238)
PAPER = (255, 252, 252)


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    candidates = {
        "regular": [
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
        ],
        "bold": [
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/System/Library/Fonts/SFNS.ttf",
        ],
    }
    for candidate in candidates.get(weight, candidates["regular"]):
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


@dataclass(frozen=True)
class Shot:
    slug: str
    title: str
    subtitle: str
    screen: str


SHOTS = [
    Shot(
        "01-dashboard",
        "See your month clearly",
        "Income, spending, budgets, and trends in one private money view.",
        "dashboard",
    ),
    Shot(
        "02-import-review",
        "Import from any source",
        "Review PDF, CSV, Excel, or pasted SMS rows before saving.",
        "import",
    ),
    Shot(
        "03-ai-categories",
        "Smart category suggestions",
        "Apply merchant rules and AI-style suggestions with one tap.",
        "ai",
    ),
    Shot(
        "04-budgets",
        "Plan what is safe to spend",
        "Track monthly budgets, recurring bills, and remaining cashflow.",
        "budgets",
    ),
    Shot(
        "05-drilldown",
        "Drill into every category",
        "Open a category, inspect transactions, and edit details anytime.",
        "drilldown",
    ),
    Shot(
        "06-private-backup",
        "Local-first and private",
        "No ads, no tracking, no bank-sync server. Export only when you choose.",
        "privacy",
    ),
]


def rounded(draw: ImageDraw.ImageDraw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text(draw: ImageDraw.ImageDraw, xy, value, size, fill=INK, weight="regular", anchor=None, align="left", spacing=8):
    draw.multiline_text(xy, value, font=font(size, weight), fill=fill, anchor=anchor, align=align, spacing=spacing)


def wrap(draw: ImageDraw.ImageDraw, value: str, fnt: ImageFont.FreeTypeFont, max_width: int) -> str:
    words = value.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if draw.textlength(candidate, font=fnt) <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return "\n".join(lines)


def gradient(size: tuple[int, int]) -> Image.Image:
    w, h = size
    small = (max(w // 8, 160), max(h // 8, 160))
    sw, sh = small
    img = Image.new("RGB", small, (250, 248, 255))
    pix = img.load()
    for y in range(sh):
        for x in range(sw):
            t = (x / max(sw - 1, 1)) * 0.55 + (y / max(sh - 1, 1)) * 0.45
            r = int(253 * (1 - t) + 238 * t)
            g = int(247 * (1 - t) + 250 * t)
            b = int(255 * (1 - t) + 246 * t)
            pix[x, y] = (r, g, b)
    img = img.resize(size, Image.Resampling.BICUBIC)
    overlay = Image.new("RGBA", size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for color, cx, cy, rx in [
        (MINT + (92,), int(w * 0.16), int(h * 0.18), int(w * 0.36)),
        (LAVENDER + (102,), int(w * 0.86), int(h * 0.20), int(w * 0.40)),
        (CORAL + (82,), int(w * 0.72), int(h * 0.77), int(w * 0.44)),
        (GOLD + (76,), int(w * 0.12), int(h * 0.84), int(w * 0.34)),
    ]:
        od.ellipse((cx - rx, cy - rx, cx + rx, cy + rx), fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(int(w * 0.07)))
    return Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")


def paste_icon(canvas: Image.Image, size: int, center: tuple[int, int]):
    icon = Image.open(ICON).convert("RGBA").resize((size, size), Image.LANCZOS)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    x = center[0] - size // 2
    y = center[1] - size // 2
    sd.rounded_rectangle((x, y + size * 0.08, x + size, y + size * 1.08), radius=size // 4, fill=(82, 50, 130, 44))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size // 8))
    canvas.alpha_composite(shadow)
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 0, size, size), radius=size // 4, fill=255)
    canvas.paste(icon, (x, y), mask)


def draw_phone(canvas: Image.Image, box: tuple[int, int, int, int], kind: str):
    x0, y0, x1, y1 = box
    w = x1 - x0
    h = y1 - y0
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x0, y0 + 24, x1, y1 + 24), radius=70, fill=(54, 31, 91, 54))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.alpha_composite(shadow)

    d = ImageDraw.Draw(canvas)
    rounded(d, (x0, y0, x1, y1), 70, (28, 30, 42), None)
    inset = int(w * 0.035)
    sx0, sy0, sx1, sy1 = x0 + inset, y0 + inset, x1 - inset, y1 - inset
    rounded(d, (sx0, sy0, sx1, sy1), 54, (251, 250, 255), None)
    notch_w = int(w * 0.32)
    rounded(d, (x0 + (w - notch_w) // 2, y0 + inset, x0 + (w + notch_w) // 2, y0 + inset + 30), 15, (28, 30, 42), None)

    screen = Image.new("RGBA", (sx1 - sx0, sy1 - sy0), (251, 250, 255, 255))
    draw_screen(screen, kind)
    mask = Image.new("L", screen.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 0, screen.size[0], screen.size[1]), radius=54, fill=255)
    canvas.paste(screen, (sx0, sy0), mask)


def pill(draw, x, y, label, color, scale=1):
    pad_x = int(18 * scale)
    pad_y = int(7 * scale)
    f = font(int(21 * scale), "bold")
    tw = int(draw.textlength(label, font=f))
    rounded(draw, (x, y, x + tw + pad_x * 2, y + int(38 * scale)), int(15 * scale), color, None)
    draw.text((x + pad_x, y + pad_y), label, font=f, fill=(255, 255, 255))
    return x + tw + pad_x * 2


def card(draw, box, title=None):
    rounded(draw, box, 22, (255, 255, 255), LINE, 1)
    if title:
        text(draw, (box[0] + 24, box[1] + 18), title, 24, INK, "bold")


def draw_header(draw, title="AI Money Manager", sub="June 2026"):
    text(draw, (36, 42), title, 34, INK, "bold")
    text(draw, (36, 84), sub, 21, MUTED, "regular")
    rounded(draw, (436, 44, 518, 84), 20, (239, 234, 255), None)
    text(draw, (477, 56), "AED", 18, VIOLET, "bold", anchor="ma")


def draw_tabs(draw, active="Stats"):
    tabs = ["Stats", "Import", "Search", "More"]
    x = 34
    y = 1090
    for tab in tabs:
        active_tab = tab == active
        fill = (244, 238, 255) if active_tab else (255, 255, 255)
        color = VIOLET if active_tab else (151, 151, 162)
        rounded(draw, (x, y, x + 116, y + 58), 20, fill, None)
        text(draw, (x + 58, y + 16), tab, 18, color, "bold", anchor="ma")
        x += 124


def draw_screen(img: Image.Image, kind: str):
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, img.size[0], img.size[1]), fill=(250, 249, 255))
    draw_header(draw)
    if kind == "dashboard":
        draw_dashboard(draw)
        draw_tabs(draw, "Stats")
    elif kind == "import":
        draw_import(draw)
        draw_tabs(draw, "Import")
    elif kind == "ai":
        draw_ai(draw)
        draw_tabs(draw, "Search")
    elif kind == "budgets":
        draw_budgets(draw)
        draw_tabs(draw, "Stats")
    elif kind == "drilldown":
        draw_drilldown(draw)
        draw_tabs(draw, "Stats")
    else:
        draw_privacy(draw)
        draw_tabs(draw, "More")


def draw_dashboard(draw):
    card(draw, (30, 132, 520, 308))
    text(draw, (54, 158), "This month", 24, MUTED, "bold")
    text(draw, (54, 196), "AED 45,090", 45, INK, "bold")
    text(draw, (54, 254), "Expense  |  Income AED 41,975", 20, MUTED)
    pill(draw, 336, 158, "Safe AED 7.2k", TEAL, 0.72)
    card(draw, (30, 330, 520, 678), "Category share")
    cx, cy, r = 275, 515, 125
    start = -90
    for pct, color in [(78, CORAL), (10, (255, 151, 78)), (4, GOLD), (4, (255, 224, 0)), (3, (188, 232, 56)), (1, TEAL)]:
        draw.pieslice((cx - r, cy - r, cx + r, cy + r), start, start + pct * 3.6, fill=color)
        start += pct * 3.6
    draw.ellipse((cx - 54, cy - 54, cx + 54, cy + 54), fill=(255, 255, 255))
    text(draw, (cx, cy - 20), "78%", 30, CORAL, "bold", anchor="ma")
    text(draw, (cx, cy + 16), "Housing", 16, MUTED, "bold", anchor="ma")
    rows = [("Housing", "AED 35,000", CORAL), ("Travel", "AED 4,627", (255, 151, 78)), ("Food", "AED 1,868", GOLD)]
    y = 700
    for name, amount, color in rows:
        rounded(draw, (30, y, 520, y + 80), 18, (255, 255, 255), LINE, 1)
        rounded(draw, (54, y + 22, 102, y + 58), 12, color, None)
        text(draw, (126, y + 22), name, 23, INK, "bold")
        text(draw, (496, y + 22), amount, 23, INK, "bold", anchor="ra")
        y += 94


def draw_import(draw):
    card(draw, (30, 132, 520, 288))
    text(draw, (54, 158), "Import Review Center", 27, INK, "bold")
    text(draw, (54, 198), "PDF, CSV, Excel, SMS paste", 22, MUTED, "regular")
    pill(draw, 54, 236, "42 ready", TEAL, 0.7)
    pill(draw, 176, 236, "5 duplicates", GOLD, 0.7)
    rows = [
        ("AMAZON GROCERY", "Food / Groceries", "AED 128.40", TEAL),
        ("CAREEM HALA", "Transportation / Taxi", "AED 42.00", TEAL),
        ("CARD PAYMENT", "Review only", "AED 5,000", LAVENDER),
        ("AGODA HOTEL", "Travel / Hotel", "AED 1,240", TEAL),
    ]
    y = 324
    for merchant, category, amount, color in rows:
        card(draw, (30, y, 520, y + 132))
        text(draw, (54, y + 24), merchant, 22, INK, "bold")
        text(draw, (54, y + 58), category, 19, MUTED)
        text(draw, (496, y + 26), amount, 21, INK, "bold", anchor="ra")
        pill(draw, 54, y + 88, "Approve", color, 0.62)
        rounded(draw, (390, y + 88, 496, y + 124), 14, (245, 242, 250), None)
        text(draw, (443, y + 96), "Edit", 17, MUTED, "bold", anchor="ma")
        y += 148


def draw_ai(draw):
    card(draw, (30, 132, 520, 302))
    text(draw, (54, 158), "Uncategorized", 27, INK, "bold")
    text(draw, (54, 198), "Suggestions learned locally from merchant rules.", 19, MUTED)
    pill(draw, 54, 240, "High confidence", TEAL, 0.7)
    items = [
        ("CAREEM FOOD", "Food / Delivery", "High"),
        ("ADNOC", "Transportation / Fuel", "High"),
        ("TIM HORTONS", "Food / Coffee", "Medium"),
        ("UNKNOWN STORE", "No suggestion yet", "Low"),
    ]
    y = 332
    for merchant, suggestion, confidence in items:
        card(draw, (30, y, 520, y + 128))
        text(draw, (54, y + 22), merchant, 21, INK, "bold")
        text(draw, (54, y + 56), suggestion, 19, MUTED)
        color = TEAL if confidence == "High" else GOLD if confidence == "Medium" else (186, 186, 196)
        pill(draw, 54, y + 88, confidence, color, 0.58)
        if confidence != "Low":
            rounded(draw, (397, y + 82, 496, y + 118), 14, VIOLET, None)
            text(draw, (446, y + 90), "Apply", 16, (255, 255, 255), "bold", anchor="ma")
        y += 144


def draw_budgets(draw):
    card(draw, (30, 132, 520, 292))
    text(draw, (54, 158), "Safe to spend", 24, MUTED, "bold")
    text(draw, (54, 196), "AED 7,240", 48, TEAL, "bold")
    text(draw, (54, 254), "After bills and planned budgets", 20, MUTED)
    rows = [
        ("Housing", 0.78, CORAL, "AED 35,000 / 45,000"),
        ("Food", 0.42, GOLD, "AED 1,868 / 4,500"),
        ("Travel", 0.91, LAVENDER, "AED 4,627 / 5,000"),
        ("Subscriptions", 0.56, VIOLET, "AED 420 / 750"),
    ]
    y = 330
    for name, pct, color, amount in rows:
        card(draw, (30, y, 520, y + 122))
        text(draw, (54, y + 22), name, 22, INK, "bold")
        text(draw, (496, y + 24), amount, 18, MUTED, "bold", anchor="ra")
        rounded(draw, (54, y + 72, 496, y + 94), 11, (239, 236, 245), None)
        rounded(draw, (54, y + 72, 54 + int(442 * pct), y + 94), 11, color, None)
        y += 140


def draw_drilldown(draw):
    card(draw, (30, 132, 520, 292))
    text(draw, (54, 158), "Food", 34, INK, "bold")
    text(draw, (54, 204), "AED 1,868 this month", 24, MUTED, "bold")
    pill(draw, 54, 246, "Groceries 64%", GOLD, 0.66)
    pill(draw, 210, 246, "Coffee 12%", TEAL, 0.66)
    rows = [
        ("Union Coop", "Groceries", "AED 214.60"),
        ("Cotti Coffee", "Coffee", "AED 24.00"),
        ("Careem Food", "Delivery", "AED 67.50"),
        ("Al Maya", "Groceries", "AED 146.80"),
    ]
    y = 330
    for merchant, category, amount in rows:
        card(draw, (30, y, 520, y + 112))
        text(draw, (54, y + 20), merchant, 22, INK, "bold")
        text(draw, (54, y + 56), category, 18, MUTED)
        text(draw, (496, y + 34), amount, 21, INK, "bold", anchor="ra")
        y += 128


def draw_privacy(draw):
    card(draw, (30, 132, 520, 318))
    text(draw, (54, 158), "Private by design", 31, INK, "bold")
    text(draw, (54, 206), "Your finance data stays on this device unless you export a backup.", 20, MUTED)
    checks = [("No ads", TEAL), ("No tracking", VIOLET), ("No bank server", CORAL)]
    y = 352
    for label, color in checks:
        card(draw, (30, y, 520, y + 112))
        rounded(draw, (54, y + 28, 98, y + 72), 22, color, None)
        text(draw, (76, y + 36), "✓", 25, (255, 255, 255), "bold", anchor="ma")
        text(draw, (122, y + 32), label, 24, INK, "bold")
        y += 132
    card(draw, (30, 760, 520, 914))
    text(draw, (54, 790), "Backup and restore", 24, INK, "bold")
    text(draw, (54, 832), "Export JSON or CSV only when you choose.", 20, MUTED)
    pill(draw, 54, 876, "User controlled", TEAL, 0.7)


def make_screenshot(shot: Shot, size: tuple[int, int], out_path: Path):
    w, h = size
    canvas = gradient(size).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    paste_icon(canvas, int(w * 0.145), (int(w * 0.14), int(h * 0.085)))
    title_font = font(int(w * 0.067), "bold")
    subtitle_font = font(int(w * 0.033), "regular")
    title = wrap(draw, shot.title, title_font, int(w * 0.72))
    subtitle = wrap(draw, shot.subtitle, subtitle_font, int(w * 0.72))
    draw.multiline_text((int(w * 0.235), int(h * 0.055)), title, font=title_font, fill=INK, spacing=8)
    draw.multiline_text((int(w * 0.235), int(h * 0.128)), subtitle, font=subtitle_font, fill=MUTED, spacing=8)
    phone_w = int(w * 0.48)
    phone_h = int(phone_w * 2.18)
    phone_x = (w - phone_w) // 2
    phone_y = int(h * 0.262)
    draw_phone(canvas, (phone_x, phone_y, phone_x + phone_w, phone_y + phone_h), shot.screen)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path, "PNG", optimize=True)


def make_social():
    out = OUT / "Social"
    out.mkdir(parents=True, exist_ok=True)
    canvas = gradient((1600, 900)).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    paste_icon(canvas, 190, (210, 185))
    text(draw, (340, 112), "AI Money Manager", 72, INK, "bold")
    text(draw, (342, 202), "Private budgeting, smart imports, and local AI-style money insights.", 34, MUTED)
    draw_phone(canvas, (990, 90, 1340, 855), "dashboard")
    rounded(draw, (342, 308, 766, 386), 26, VIOLET, None)
    text(draw, (554, 328), "Local-first finance tracker", 29, (255, 255, 255), "bold", anchor="ma")
    canvas.convert("RGB").save(out / "social-preview-1600x900.png", "PNG", optimize=True)

    icon = Image.open(ICON).convert("RGB")
    icon.save(out / "app-icon-1024.png", "PNG", optimize=True)


def write_copy():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "AppStoreListing.md").write_text(
        """# AI Money Manager App Store Listing Draft

## Subtitle
Private budget and import tracker

## Promotional Text
Import bank PDFs, CSV, Excel, or pasted SMS messages, review every transaction, and manage your monthly budget locally on your iPhone.

## Short Description
AI Money Manager is a local-first personal finance app for people who want control without bank-sync tracking. Import statements or copied bank messages, review suggested categories, manage accounts and budgets, and export your own backup when needed.

## Keywords
budget,expense,spending,finance,money,tracker,pdf,csv,statement,private

## Screenshot Captions
1. See income, expenses, safe-to-spend, and category totals.
2. Import PDF, CSV, Excel, or pasted SMS transactions.
3. Review smart category suggestions before saving.
4. Plan monthly budgets and recurring spending.
5. Drill into category totals and edit transactions.
6. Keep finance data local and export only when you choose.

## Review Notes
The app stores finance data locally using SwiftData. It does not include analytics, advertising, tracking SDKs, or bank-sync APIs. User-selected files are parsed on device. Export files are created only when the user chooses to export.
""",
        encoding="utf-8",
    )
    (OUT / "README.md").write_text(
        """# Marketing Asset Pack

Generated App Store materials for AI Money Manager.

## Included

- `Screenshots/iPhone_6_9_1320x2868`: 6 modern iPhone portrait PNG screenshots.
- `Screenshots/iPhone_6_7_1290x2796`: 6 compatible iPhone portrait PNG screenshots.
- `Social/social-preview-1600x900.png`: website/social preview image.
- `Social/app-icon-1024.png`: App Store icon copy.
- `AppStoreListing.md`: listing copy, keywords, screenshot captions, and review notes.

## Regenerate

Run:

```bash
python3 Tools/generate_app_store_marketing.py
```

Apple's screenshot specification allows PNG/JPEG screenshots and up to 10 screenshots per device display class. Use the 1320x2868 or 1290x2796 set for the modern iPhone screenshot slot.
""",
        encoding="utf-8",
    )


def main():
    specs = [
        ("iPhone_6_9_1320x2868", (1320, 2868)),
        ("iPhone_6_7_1290x2796", (1290, 2796)),
    ]
    for folder, size in specs:
        for shot in SHOTS:
            make_screenshot(shot, size, OUT / "Screenshots" / folder / f"{shot.slug}.png")
    make_social()
    write_copy()
    print(f"Wrote marketing assets to {OUT}")


if __name__ == "__main__":
    main()
