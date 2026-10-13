#!/usr/bin/env python3
"""Refine the original logo on a background that reaches the icon edges. Requires Pillow 11.3.0."""
from pathlib import Path
import math
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'scripts/artwork/icon-original.png'
DESTINATION = ROOT / 'artifacts/project-istiqamah/assets/images/icon.png'


def render_icon():
    original = Image.open(SOURCE).convert('RGB')
    # Feather the adjustment by green chroma to preserve the neutral glass surround.
    mask = Image.new('L', original.size)
    mask.putdata([round(min(1.0, max(0.0, (g - r - 4) / 24)) * 255)
                  for r, g, b in original.getdata()])
    mask = mask.filter(ImageFilter.GaussianBlur(1.2))
    refined = ImageEnhance.Color(original).enhance(1.10)
    refined = ImageEnhance.Contrast(refined).enhance(1.06)
    result = Image.composite(refined, original, mask)
    result = result.filter(ImageFilter.UnsharpMask(radius=1.1, percent=35, threshold=3))

    # Retain the green artwork, removing the original inset tile, rim and shadow.
    logo_mask = Image.new('L', original.size)
    logo_mask.putdata([255 if g - r > 8 else 0 for r, g, b in original.getdata()])
    # Keep only the dot and body; discard unrelated greenish background pixels.
    for seed in ((510, 230), (510, 600)):
        ImageDraw.floodfill(logo_mask, seed, 64)
    logo_mask = logo_mask.point(lambda value: 255 if value == 64 else 0)
    # Fill enclosed dark highlights, which can have very little green chroma.
    ImageDraw.floodfill(logo_mask, (0, 0), 128)
    logo_mask = logo_mask.point(lambda value: 0 if value == 128 else 255)
    logo_mask = logo_mask.filter(ImageFilter.GaussianBlur(0.6))
    # Broad reflected light fills the canvas; there is no second rounded tile.
    background = Image.new('RGB', original.size)
    pixels = []
    sheen = Image.new('L', original.size)
    sheen_pixels = []
    for y in range(original.height):
        v = y / (original.height - 1)
        for x in range(original.width):
            u = x / (original.width - 1)
            reflected = math.exp(-((v - (0.08 + 0.12*u)) / 0.13)**2)
            diagonal = math.exp(-((u + v - 0.94) / 0.24)**2)
            depth = math.exp(-((u - 0.85)/0.52)**2 - ((v - 0.77)/0.38)**2)
            base = 239 - 15*v + 16*reflected + 7*diagonal - 14*depth
            pixels.append(tuple(round(min(255, max(0, base + shift))) for shift in (-2, 1, 4)))
            # A restrained specular reflection follows the original sculpture.
            reflection = math.exp(-((v - (0.17 + 0.32*u)) / 0.085)**2)
            sheen_pixels.append(round(reflection * 110))
    background.putdata(pixels)
    sheen.putdata(sheen_pixels)
    # Brighter jade glass makes the material change visible at Home Screen size.
    result = Image.blend(result, Image.new('RGB', original.size, (132, 209, 174)), 0.28)
    result = ImageEnhance.Brightness(result).enhance(1.13)
    result = Image.composite(Image.new('RGB', original.size, (240, 255, 247)), result, sheen)

    # An inner bevel follows the original silhouette, not the app-icon boundary.
    inner_rim = ImageChops.subtract(logo_mask, logo_mask.filter(ImageFilter.MinFilter(21)))
    inner_rim = inner_rim.filter(ImageFilter.GaussianBlur(2))
    upper_left = Image.new('L', original.size)
    upper_left.paste(logo_mask, (5, 5))
    highlight = ImageChops.subtract(logo_mask, upper_left).filter(ImageFilter.GaussianBlur(1.1))
    result = Image.composite(Image.new('RGB', original.size, (196, 249, 220)), result,
                             inner_rim.point(lambda value: round(value * 0.55)))
    result = Image.composite(Image.new('RGB', original.size, (248, 255, 251)), result,
                             highlight.point(lambda value: round(value * 0.9)))

    # A diffused shadow and luminous lip give the mark depth, without a tile rim.
    shadow = Image.new('L', original.size)
    shadow.paste(logo_mask, (5, 9))
    shadow = shadow.filter(ImageFilter.GaussianBlur(12)).point(lambda value: round(value * 0.22))
    background = Image.composite(Image.new('RGB', original.size, (118, 143, 137)), background, shadow)
    lip = ImageChops.subtract(logo_mask.filter(ImageFilter.MaxFilter(9)), logo_mask)
    lip = lip.filter(ImageFilter.GaussianBlur(1.8)).point(lambda value: round(value * 0.8))
    background = Image.composite(Image.new('RGB', original.size, (255, 255, 255)), background, lip)
    return Image.composite(result, background, logo_mask)


if __name__ == '__main__':
    render_icon().save(DESTINATION)
    print('Enhanced original icon: 1024px RGB, original logo preserved, background reaches every edge.')
