"""Build pixel-aligned diagonal trim from the editable north-facing source. Requires Pillow."""
from pathlib import Path
from PIL import Image, PngImagePlugin

FOLDER = Path(__file__).resolve().parent / 'icons'
DIRECTIONS = (10, 5, 6, 9, 6, 10, 5, 9)  # S, N, E, W, SE, SW, NE, NW


def project(source, corner, wrap=False):
    tile = Image.new('RGBA', (32, 32))
    for y in range(32):
        for x in range(32):
            if corner == 5:
                along, depth = (x + y) // 2, y - x - 1
            elif corner == 10:
                along, depth = (62 - x - y) // 2, x - y - 1
            elif corner == 6:
                along, depth = (x + 31 - y) // 2, 30 - x - y
            else:
                along, depth = (31 - x + y) // 2, x + y - 32
            if wrap:
                depth += 32
            if 0 <= depth < 32:
                tile.putpixel((x, y), source.getpixel((along, depth)))
    return tile


def build(name, state, corner_state=None):
    source = Image.open(FOLDER / f'{name}_source.png').convert('RGBA')
    assert source.size == (32, 32)
    sheet = Image.new('RGBA', (256, 32))
    for index, corner in enumerate(DIRECTIONS):
        tile = project(source, corner)
        assert tile.getbbox() is not None
        if name == 'thinplating':
            assert sum(bool(a) for a in tile.getchannel('A').tobytes()) == 145
        assert sum(bool(a) for a in tile.getchannel('A').tobytes()) > 0
        sheet.paste(tile, (index * 32, 0))
    # Opposite occupied corners must be exact half-turns, without subpixel seams.
    assert sheet.crop((0, 0, 32, 32)).transpose(Image.Transpose.ROTATE_180).tobytes() == sheet.crop((32, 0, 64, 32)).tobytes()
    assert sheet.crop((64, 0, 96, 32)).transpose(Image.Transpose.ROTATE_180).tobytes() == sheet.crop((96, 0, 128, 32)).tobytes()
    # Keep the manual state for floors; the existing decal element selects numbered
    # states from its host's smoothing junction on diagonal walls and windows.
    atlas = Image.new('RGBA', (256, 32 * (34 if corner_state else 33)))
    atlas.paste(sheet, (0, 0))
    description = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\nstate = "STATE"\n\tdirs = 8\n\tframes = 1\n'
    description = description.replace('STATE', state)
    corners = (5, 6, 9, 10, 21, 38, 74, 137)
    for junction in range(256):
        tile = Image.new('RGBA', (32, 32))
        if junction in corners:
            index = DIRECTIONS.index(junction & 15)
            tile = sheet.crop((index * 32, 0, index * 32 + 32, 32))
            assert sum(bool(a) for a in tile.getchannel('A').tobytes()) > 0
        else:
            assert tile.getbbox() is None
        index = 8 + junction
        atlas.paste(tile, (index % 8 * 32, index // 8 * 32))
        description += 'state = "{}-{}"\n\tdirs = 1\n\tframes = 1\n'.format(state, junction)
    if corner_state:
        # NW filler in the neighboring floor joins both long diagonal segments.
        line = project(source, 9)
        filler = project(source, 9, wrap=True)
        for pixel in range(31):
            assert line.getpixel((31, pixel + 1))[3] == filler.getpixel((0, pixel))[3]
            assert line.getpixel((pixel + 1, 31))[3] == filler.getpixel((pixel, 0))[3]
        description += f'state = "{corner_state}"\n\tdirs = 8\n\tframes = 1\n'
        for index, corner in enumerate(DIRECTIONS):
            tile = project(source, corner, wrap=True)
            assert tile.getbbox() is not None
            assert sum(bool(a) for a in tile.getchannel('A').tobytes()) < 50
            opposite = {5: 10, 10: 5, 6: 9, 9: 6}[corner]
            assert tile.transpose(Image.Transpose.ROTATE_180).tobytes() == project(source, opposite, wrap=True).tobytes()
            atlas.paste(tile, (index * 32, 33 * 32))
    metadata = PngImagePlugin.PngInfo()
    metadata.add_text('Description', description + '# END DMI\n', zip=True)
    atlas.save(FOLDER / f'{name}_diagonal.dmi', format='PNG', pnginfo=metadata)
    print('PASS: manual directions and all 256 smoothing states; 8 diagonal borders; non-corners transparent.')


if __name__ == '__main__':
    build('thinplating', 'siding_thinplating_new')
    build('trimline', 'trimline', 'trimline_corner')
    build('siding_wood', 'siding_wood', 'siding_wood_corner')
    build('siding_plain', 'siding_plain', 'siding_plain_corner')
