#!/usr/bin/env python3
"""Refine the original icon without changing its artwork. Requires Pillow 11.3.0."""
from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter

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
    # A restrained edge pass keeps the original curves and soft highlights intact.
    return result.filter(ImageFilter.UnsharpMask(radius=1.1, percent=35, threshold=3))


if __name__ == '__main__':
    render_icon().save(DESTINATION)
    print('Enhanced original icon: 1024px RGB, original silhouette and glass preserved.')
