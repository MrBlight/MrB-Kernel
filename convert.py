"""
convert.py — converts a PNG (or any Pillow-supported image) into two raw
binary files ready for direct use with VGA Mode 13h:

  <base>_palette.bin   256 × 3 bytes, each component right-shifted by 2
                       (VGA DAC is 6-bit, i.e. values 0-63)
  <base>_pixels.bin    320 × 200 = 64 000 bytes, one byte per pixel,
                       each byte being a palette index 0-255

Usage:
    python3 convert.py tomo.png
    python3 convert.py image1.png image2.png ...
"""

import sys
from PIL import Image


def convert_image(img_file: str) -> None:
    base = img_file.rsplit('.', 1)[0]
    img = Image.open(img_file)

    # Flatten any alpha channel onto a black background
    if img.mode in ('RGBA', 'LA'):
        background = Image.new('RGB', img.size, (0, 0, 0))
        mask = img.split()[3 if img.mode == 'RGBA' else 1]
        background.paste(img, mask=mask)
        img = background
    else:
        img = img.convert('RGB')

    # Scale to the exact Mode 13h resolution
    img = img.resize((320, 200), Image.LANCZOS)

    # Quantise to 256 colours with Floyd–Steinberg dithering for best quality
    img = img.convert('P', palette=Image.ADAPTIVE, colors=256,
                      dither=Image.FLOYDSTEINBERG)

    raw_palette = img.getpalette()[:768]   # 256 × 3 = 768 entries
    pixels      = list(img.getdata())      # 320 × 200 = 64 000 entries

    # Write palette: shift each 8-bit component down to 6-bit for the VGA DAC
    with open(f"{base}_palette.bin", "wb") as f:
        for i in range(256):
            r = raw_palette[i * 3]     >> 2
            g = raw_palette[i * 3 + 1] >> 2
            b = raw_palette[i * 3 + 2] >> 2
            f.write(bytes([r, g, b]))

    # Write pixels (raw palette indices)
    with open(f"{base}_pixels.bin", "wb") as f:
        f.write(bytes(pixels))

    print(f"Converted {img_file}  →  {base}_palette.bin  +  {base}_pixels.bin")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 convert.py image1.png [image2.png ...]")
        sys.exit(1)
    for path in sys.argv[1:]:
        convert_image(path)
