from __future__ import annotations

from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "review_shots"
OUTPUT_DIR = ROOT / "store-assets" / "screenshots"
CANVAS = (1080, 1920)


FONT_REGULAR = Path(r"C:\Windows\Fonts\segoeui.ttf")
FONT_BOLD = Path(r"C:\Windows\Fonts\segoeuib.ttf")
FONT_SERIF = Path(r"C:\Windows\Fonts\georgiab.ttf")


SLIDES = [
    {
        "name": "aso-v2-01-sort-potions.png",
        "source": "main_menu.png",
        "headline": ["SORT POTIONS.", "CAST SPELLS."],
        "subline": "Offline dungeon runs • No account required",
        "tag": "START YOUR RUN",
        "accent": (211, 162, 63),
    },
    {
        "name": "aso-v2-02-tactical-combat.png",
        "source": "battle_sigils.png",
        "headline": ["EVERY MATCH", "IS A SPELL."],
        "subline": "Read enemy intent • Match one color • Deal damage",
        "tag": "TACTICAL POTION COMBAT",
        "accent": (90, 197, 232),
    },
    {
        "name": "aso-v2-03-branching-runs.png",
        "source": "map.png",
        "headline": ["EVERY PATH", "CHANGES THE RUN."],
        "subline": "Choose your route • Risk more • Find better rewards",
        "tag": "BRANCHING DUNGEON ROUTES",
        "accent": (194, 119, 244),
    },
    {
        "name": "aso-v2-04-build-your-brewer.png",
        "source": "kit_select_v2.png",
        "headline": ["CHOOSE A BREWER.", "SHAPE YOUR BUILD."],
        "subline": "4 kits • Different skills • Different strategies",
        "tag": "BUILD YOUR PLAYSTYLE",
        "accent": (103, 225, 135),
    },
    {
        "name": "aso-v2-05-five-realms.png",
        "source": "area_select_v2.png",
        "headline": ["FIVE REALMS.", "COUNTLESS RUNS."],
        "subline": "Bosses, hazards, challenges, and new ways to adapt",
        "tag": "EXPLORE THE CAMPAIGN",
        "accent": (248, 166, 86),
    },
    {
        "name": "aso-v2-06-persistent-choices.png",
        "source": "storyboard-v28/event-reveal-hero.png",
        "headline": ["YOUR CHOICES", "CARRY FORWARD."],
        "subline": "Permanent decisions make every expedition personal",
        "tag": "STORY-DRIVEN RUNS",
        "accent": (174, 125, 255),
    },
    {
        "name": "aso-v2-07-permanent-upgrades.png",
        "source": "shop_v2.png",
        "headline": ["MAKE EVERY RUN", "STRONGER."],
        "subline": "Permanent upgrades • Relics • Build synergy",
        "tag": "MASTER THE ALCHEMY",
        "accent": (231, 185, 75),
    },
    {
        "name": "aso-v2-08-remove-ads.png",
        "source": "store-assets/screenshots/08-settings-accessibility.png",
        "headline": ["PLAY FREE.", "REMOVE ADS FOR US$4.99."],
        "subline": "One-time purchase • Optional rewarded ads stay your choice",
        "tag": "NO BANNERS • NO INTERSTITIALS",
        "accent": (213, 114, 244),
    },
]


def load_font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    if path.exists():
        return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def fit_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = max(0, (resized.width - target_w) // 2)
    top = max(0, (resized.height - target_h) // 2)
    return resized.crop((left, top, left + target_w, top + target_h))


def fit_contain(image: Image.Image, size: tuple[int, int], background: tuple[int, int, int, int]) -> Image.Image:
    target_w, target_h = size
    scale = min(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, background)
    left = (target_w - resized.width) // 2
    top = (target_h - resized.height) // 2
    canvas.alpha_composite(resized, (left, top))
    return canvas


def rounded_layer(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, image.width - 1, image.height - 1), radius=radius, fill=255)
    clipped = Image.new("RGBA", image.size, (0, 0, 0, 0))
    clipped.paste(image, (0, 0), mask)
    return clipped


def text_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont) -> int:
    box = draw.textbbox((0, 0), text, font=font)
    return box[2] - box[0]


def centered_text(draw: ImageDraw.ImageDraw, y: int, lines: Iterable[str], font: ImageFont.FreeTypeFont, fill: tuple[int, int, int, int], spacing: int = 8) -> int:
    lines = list(lines)
    line_height = font.getbbox("Ag")[3] - font.getbbox("Ag")[1]
    for line in lines:
        x = (CANVAS[0] - text_width(draw, line, font)) // 2
        draw.text((x, y), line, font=font, fill=fill, stroke_width=2, stroke_fill=(4, 5, 16, 180))
        y += line_height + spacing
    return y


def gradient_overlay(size: tuple[int, int], accent: tuple[int, int, int]) -> Image.Image:
    width, height = size
    overlay = Image.new("RGBA", size, (0, 0, 0, 0))
    pixels = overlay.load()
    for y in range(height):
        top_alpha = int(190 * max(0, 1 - y / 520))
        bottom_alpha = int(160 * max(0, (y - height * 0.58) / (height * 0.42)))
        glow_alpha = int(38 * max(0, 1 - abs(y - height * 0.42) / (height * 0.32)))
        for x in range(width):
            edge = abs(x - width / 2) / (width / 2)
            alpha = min(255, top_alpha + bottom_alpha + int(90 * edge))
            r, g, b = accent
            pixels[x, y] = (r // 4, g // 4, b // 4, alpha)
            if glow_alpha > 0 and 0.22 < x / width < 0.78:
                pixels[x, y] = (r, g, b, max(pixels[x, y][3], glow_alpha))
    return overlay


def resolve_source(source: str) -> Path:
    direct = ROOT / source
    if direct.exists():
        return direct
    return SOURCE_DIR / source


def build_slide(slide: dict) -> None:
    source_path = resolve_source(slide["source"])
    source = Image.open(source_path).convert("RGBA")
    accent = tuple(slide["accent"])

    background = fit_cover(source, CANVAS).filter(ImageFilter.GaussianBlur(22))
    background = ImageEnhance.Brightness(background).enhance(0.25)
    canvas = background.copy()
    canvas.alpha_composite(gradient_overlay(CANVAS, accent))

    draw = ImageDraw.Draw(canvas, "RGBA")
    # Quiet top panel keeps copy legible without hiding the game atmosphere.
    draw.rounded_rectangle((34, 34, 1046, 394), radius=34, fill=(5, 7, 20, 205), outline=(*accent, 150), width=2)
    draw.line((74, 368, 1006, 368), fill=(*accent, 120), width=2)
    draw.polygon(((540, 348), (552, 360), (540, 372), (528, 360)), fill=(*accent, 230))

    eyebrow = load_font(FONT_BOLD, 22)
    headline = load_font(FONT_SERIF, 62)
    body = load_font(FONT_REGULAR, 24)
    tag_font = load_font(FONT_BOLD, 20)
    tiny = load_font(FONT_BOLD, 18)

    brand = "POTION ROGUE  •  SORT PUZZLE RPG"
    draw.text(((CANVAS[0] - text_width(draw, brand, eyebrow)) // 2, 72), brand, font=eyebrow, fill=(*accent, 255))
    centered_text(draw, 124, slide["headline"], headline, (247, 243, 236, 255), spacing=6)
    subline_w = text_width(draw, slide["subline"], body)
    draw.text(((CANVAS[0] - subline_w) // 2, 310), slide["subline"], font=body, fill=(213, 218, 235, 255))

    card_size = (900, 1280)
    card_x = (CANVAS[0] - card_size[0]) // 2
    card_y = 440
    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow, "RGBA")
    shadow_draw.rounded_rectangle((card_x + 8, card_y + 16, card_x + card_size[0] + 8, card_y + card_size[1] + 16), radius=34, fill=(0, 0, 0, 210))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas.alpha_composite(shadow)

    card = fit_contain(source, card_size, (8, 9, 20, 255))
    card = rounded_layer(card, 30)
    canvas.alpha_composite(card, (card_x, card_y))
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.rounded_rectangle((card_x, card_y, card_x + card_size[0], card_y + card_size[1]), radius=30, outline=(*accent, 230), width=4)
    draw.rounded_rectangle((card_x + 12, card_y + 12, card_x + card_size[0] - 12, card_y + card_size[1] - 12), radius=22, outline=(255, 255, 255, 32), width=2)

    # The bottom label is short enough to remain readable in the Play preview.
    tag_box = (84, 1760, 996, 1840)
    draw.rounded_rectangle(tag_box, radius=22, fill=(11, 8, 26, 235), outline=(*accent, 220), width=3)
    tag = slide["tag"]
    draw.text(((CANVAS[0] - text_width(draw, tag, tag_font)) // 2, 1787), tag, font=tag_font, fill=(249, 239, 212, 255))
    index = SLIDES.index(slide) + 1
    page = f"{index:02d} / 08"
    draw.text((88, 1868), page, font=tiny, fill=(*accent, 210))
    footer = "FREE TO PLAY  •  OFFLINE  •  GOOGLE PLAY"
    draw.text((CANVAS[0] - 88 - text_width(draw, footer, tiny), 1868), footer, font=tiny, fill=(195, 200, 219, 220))

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUTPUT_DIR / slide["name"], format="PNG", optimize=True)


def main() -> None:
    for slide in SLIDES:
        build_slide(slide)
        print(f"built {slide['name']}")


if __name__ == "__main__":
    main()
