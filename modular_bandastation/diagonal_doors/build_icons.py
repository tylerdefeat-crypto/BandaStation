"""Rebuild diagonal shutters from the original animation and diagonal window masks.
Run from any directory with Python + Pillow. Assertions check frame counts and clipping.
"""
from pathlib import Path
import re
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(__file__).parent / 'icons/shutters_diagonal.dmi'
DIRECTIONS = (10, 5, 6, 9, 6, 10, 5, 9)  # S, N, E, W, SE, SW, NE, NW
INNER = {5: 21, 6: 38, 9: 137, 10: 74}


def read_dmi(path):
    image = Image.open(path)
    states = {}
    cursor = 0
    for block in image.info['Description'].split('state = ')[1:]:
        name = re.match(r'"([^"]*)"', block)[1]
        dirs = int(re.search(r'dirs = (\d+)', block)[1])
        frames = int(re.search(r'frames = (\d+)', block)[1])
        tiles = []
        for index in range(cursor, cursor + dirs * frames):
            x, y = index % (image.width // 32) * 32, index // (image.width // 32) * 32
            tiles.append(image.crop((x, y, x + 32, y + 32)).convert('RGBA'))
        states[name] = (block.split('# END DMI')[0].rstrip(), dirs, frames, tiles)
        cursor += dirs * frames
    return states


def project(frame, mask, corner):
    tile = Image.new('RGBA', (32, 32))
    for y in range(32):
        for x in range(32):
            alpha = mask.getpixel((x, y))
            if not alpha:
                continue
            # Unfold the diagonal face into the original shutter's roll-down axis.
            if corner == 5:
                u, v = (x + y) // 2, x - y
            elif corner == 10:
                u, v = 31 - (x + y) // 2, y - x
            elif corner == 6:
                u, v = (x + 31 - y) // 2, x + y - 31
            else:
                u, v = (31 - x + y) // 2, 31 - x - y
            r, g, b, a = frame.getpixel((u, v))
            tile.putpixel((x, y), (r, g, b, a * alpha // 255))
    return tile


def main():
    source = read_dmi(ROOT / 'icons/obj/doors/shutters.dmi')
    windows = read_dmi(ROOT / 'modular_bandastation/diagonal_turfs/icons/opsglass_diagonal.dmi')
    metadata = ['# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32']
    output = []
    for inner in (False, True):
        for name, (block, dirs, frames, tiles) in source.items():
            suffix = '-inner' if inner else ''
            metadata.append('state = ' + block.replace('"' + name + '"', '"' + name + suffix + '"', 1).replace('dirs = 4', 'dirs = 8'))
            for frame in range(frames):
                for corner in DIRECTIONS:
                    junction = INNER[corner] if inner else corner
                    mask = windows['plastitanium_window-{}-diagonal'.format(junction)][3][0].getchannel('A')
                    tile = project(tiles[frame * dirs], mask, corner)
                    # Every frame, including the open housing, stays inside the window.
                    assert all(a <= b for a, b in zip(tile.getchannel('A').getdata(), mask.getdata()))
                    output.append(tile)
    metadata.append('# END DMI\n')
    sheet = Image.new('RGBA', (32 * 8, 32 * ((len(output) + 7) // 8)))
    for index, tile in enumerate(output):
        sheet.paste(tile, (index % 8 * 32, index // 8 * 32))
    info = PngImagePlugin.PngInfo()
    info.add_text('Description', '\n'.join(metadata), zip=True)
    sheet.save(OUTPUT, format='PNG', pnginfo=info)
    result = read_dmi(OUTPUT)
    assert len(result) == 8
    for name, (_, _, frames, _) in source.items():
        for suffix in ('', '-inner'):
            block, dirs, count, tiles = result[name + suffix]
            assert dirs == 8 and count == frames
            if frames > 1:
                assert re.search(r'delay = .*', block)[0] == re.search(r'delay = .*', source[name][0])[0]
    print('PASS: {} frames; original animation delays preserved; all directions clipped to window masks.'.format(len(output)))


if __name__ == '__main__':
    main()