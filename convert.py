import sys
from PIL import Image

def convert_image(img_file):
    base = img_file.split('.')[0]
    img = Image.open(img_file)

    # Handle alpha with composite on black
    if img.mode in ('RGBA', 'LA'):
        background = Image.new('RGB', img.size, (0, 0, 0))
        if img.mode == 'RGBA':
            background.paste(img, mask=img.split()[3])
        else:
            background.paste(img, mask=img.split()[1])
        img = background
    else:
        img = img.convert('RGB')

    img = img.resize((320, 200), Image.LANCZOS)

    # better quantization using an adaptive palette and dithering for full color use
    img = img.convert('P', palette=Image.ADAPTIVE, colors=256, dither=Image.FLOYDSTEINBERG)

    palette = img.getpalette()[:768]  # force only 768 entries

    pixels = list(img.getdata())

    with open(f"{base}_palette.bin", "wb") as f:
        for i in range(256):
            r = palette[i*3] >> 2
            g = palette[i*3 + 1] >> 2
            b = palette[i*3 + 2] >> 2
            f.write(bytes([r, g, b]))

    with open(f"{base}_pixels.bin", "wb") as f:
        f.write(bytes(pixels))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python convert.py image1.png [image2.png ...]")
        sys.exit(1)
    for img_file in sys.argv[1:]:
        convert_image(img_file)
