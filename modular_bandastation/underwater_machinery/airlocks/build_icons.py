"""Deterministic pixel-art airlocks. Run with Python + Pillow; includes DMI checks."""
from math import cos, sin, pi
from pathlib import Path
import re
from PIL import Image, ImageChops, ImageDraw, PngImagePlugin

FOLDER = Path(__file__).parent / 'icons'
STEEL = '#555859'
DARK = '#202223'
EDGE = '#343738'
LIGHT = '#83847e'
OCHRE = '#8b692f'
GOLD = '#b08b43'


def blank(size):
    return Image.new('RGBA', (size, 32))


def octagon(box, corner=3):
    x0, y0, x1, y1 = box
    return [(x0+corner, y0), (x1-corner, y0), (x1, y0+corner), (x1, y1-corner),
            (x1-corner, y1), (x0+corner, y1), (x0, y1-corner), (x0, y0+corner)]


def aperture(size):
    mask = Image.new('L', (size, 32))
    ImageDraw.Draw(mask).polygon(octagon((5, 5, size-9, 26), 6), fill=255)
    return mask


def clipped(image, mask):
    result = image.copy()
    result.putalpha(ImageChops.multiply(image.getchannel('A'), mask))
    return result


def bolt(d, x, y):
    d.rectangle((x-1, y-1, x+1, y+1), fill=DARK)
    d.line((x, y-1, x+1, y-1), fill=LIGHT)
    d.point((x, y), fill=STEEL)


def housing(size):
    image = blank(size)
    d = ImageDraw.Draw(image)
    d.rectangle((0, 0, size-1, 31), fill=DARK)
    d.rectangle((1, 1, size-2, 30), fill=EDGE)
    d.line((1, 1, size-2, 1), fill='#666866')
    d.line((1, 2, 1, 29), fill=STEEL)
    d.rectangle((2, 2, size-3, 29), outline='#17191a')
    for inset, color in ((0, DARK), (1, LIGHT), (2, STEEL), (3, '#2a2d2d')):
        d.polygon(octagon((2+inset, 2+inset, size-6-inset, 29-inset), 6), fill=color)
    d.polygon(octagon((5, 5, size-9, 26), 6), fill=(0, 0, 0, 0))
    # The solid right jamb occludes the leaf as it retracts into its pocket.
    d.rectangle((size-7, 0, size-1, 31), fill=DARK)
    d.rectangle((size-6, 1, size-2, 30), fill='#3c3f40')
    d.line((size-6, 2, size-6, 29), fill='#6b6c66')
    for y in (4, 7, 10, 22, 25, 28):
        d.line((size-5, y, size-2, y), fill='#202323')
        d.line((size-4, y+1, size-2, y+1), fill=STEEL)
    d.rectangle((size-5, 12, size-2, 20), fill='#151818')
    d.line((size-4, 13, size-3, 13), fill=LIGHT)
    d.rectangle((size-4, 15, size-3, 17), fill=OCHRE)
    d.point((size-3, 19), fill='#7c817a')
    d.rectangle((0, 10, 3, 21), fill='#181a1b')
    d.line((1, 11, 1, 20), fill=LIGHT)
    d.line((3, 12, 3, 19), fill='#686a65')
    for x in (3, size-4):
        for y in (3, 28):
            bolt(d, x, y)
    for x in (8, size-14):
        d.rectangle((x, 2, x+3, 3), fill=OCHRE)
        d.line((x, 2, x+2, 2), fill=GOLD)
    for x in (6, size-14):
        d.rectangle((x-1, 28, x+6, 31), fill=DARK)
        d.line((x, 29, x+4, 29), fill='#44463e')
    return image


def wheel(size, engagement, angle=0):
    image = blank(size)
    d = ImageDraw.Draw(image)
    cx, cy = (size-4)//2, 16
    r = 4 if size == 32 else 5
    # Four radial dogs retract before the leaf starts moving.
    for a in (0, pi/2, pi, 3*pi/2):
        start = r+2
        reach = (size-16)//2 if a in (0, pi) else 8
        end = start + (reach-start)*engagement
        points = (round(cx + cos(a)*start), round(cy + sin(a)*start),
                  round(cx + cos(a)*end), round(cy + sin(a)*end))
        d.line(points, fill=DARK, width=3)
        d.line(points, fill='#898981', width=1)
    d.ellipse((cx-r-1, cy-r, cx+r+1, cy+r+2), fill=DARK)
    d.ellipse((cx-r, cy-r, cx+r, cy+r), outline=OCHRE, width=2)
    d.arc((cx-r, cy-r, cx+r, cy+r), 185, 340, fill=GOLD)
    for a in (angle, angle + 2*pi/3, angle + 4*pi/3):
        d.line((cx, cy, round(cx + cos(a)*(r-1)), round(cy + sin(a)*(r-1))), fill='#888a83')
    d.rectangle((cx-1, cy-1, cx+1, cy+1), fill='#424648')
    d.point((cx, cy), fill='#b3b5aa')
    return clipped(image, aperture(size))


def leaf(size):
    image = blank(size)
    d = ImageDraw.Draw(image)
    for inset, color in ((0, DARK), (1, '#74766f'), (2, '#414545')):
        d.polygon(octagon((4+inset, 4+inset, size-8-inset, 27-inset), 6), fill=color)
    d.line((9, 7, size-13, 7), fill='#5b5f5b')
    d.line((9, 25, size-13, 25), fill='#292d2e')
    for y in range(9, 24):
        for x in range(8, size-12):
            if (x*3 + y*7) % 31 == 0:
                d.point((x, y), fill='#4c5050' if y < 16 else '#383c3d')
    cx = (size-4)//2
    for y in (8, 23):
        d.rectangle((cx-6, y, cx+6, y+1), fill=DARK)
        for x in range(cx-6, cx+7):
            for dy in (0, 1):
                if (x-dy) % 7 < 4:
                    d.point((x, y+dy), fill=GOLD if dy == 0 else OCHRE)
    for x in (7, size-12):
        d.line((x, 12, x, 19), fill='#1d2021', width=2)
        d.line((x-1, 12, x-1, 19), fill='#797b73')
        bolt(d, x, 11)
        bolt(d, x, 21)
    if size == 64:
        for x in (13, 43):
            d.rectangle((x, 11, x+3, 21), fill='#303435', outline='#585d59')
            for y in (13, 16, 19):
                d.line((x+1, y, x+2, y), fill='#1c2021')
        d.line((20, 16, 40, 16), fill='#222526', width=3)
        d.line((20, 15, 40, 15), fill='#777970')
    return image


def moved(image, shift):
    result = blank(image.width)
    result.paste(image, (shift, 0))
    return clipped(result, aperture(image.width))


def lamps(size, color):
    image = blank(size)
    d = ImageDraw.Draw(image)
    for x in (6, size-14):
        d.rectangle((x, 29, x+4, 30), fill=color)
        d.line((x, 29, x+3, 29), fill='#b4c9a1')
    return image


def make_states(size):
    base, plate = housing(size), leaf(size)
    states = {}
    def add(name, images, loop=True):
        states[name] = (images if isinstance(images, list) else [images], loop)
    for name in ('closed', 'open', 'deny', 'construction'):
        add(name, base)
    opening = []
    fills = []
    for i, shift in enumerate((0, 0, size//7, size//3, size*2//3, size)):
        opening.append(base)
        moving_plate = plate.copy()
        moving_plate.alpha_composite(wheel(size, 1 - min(i/2, 1), i*pi/4))
        fills.append(moved(moving_plate, shift))
    add('opening', opening, False)
    add('closing', list(reversed(opening)), False)
    add('fill_opening', fills, False)
    add('fill_closing', list(reversed(fills)), False)
    add('fill_closed', clipped(plate, aperture(size)))
    add('fill_open', blank(size))
    add('fill_construction', blank(size))
    add('wheel_unlocked', wheel(size, 0))
    add('wheel_locked', wheel(size, 1, pi/2))
    locking = [wheel(size, i/9, i*pi/18) for i in range(10)]
    add('wheel_locking', locking, False)
    add('wheel_unlocking', list(reversed(locking)), False)
    for name, color in {
        'poweron': '#8db04b', 'poweron_open': '#8db04b',
        'bolts': '#b94f37', 'bolts_open': '#b94f37',
        'emergency': '#b89a4a', 'emergency_open': '#b89a4a',
        'reta': '#6592ac', 'reta_open': '#6592ac',
    }.items():
        add('lights_' + name, lamps(size, color))
    for name, color in (('opening', '#8db04b'), ('closing', '#b89a4a'), ('denied', '#b94f37')):
        add('lights_' + name, [lamps(size, color) if i % 2 == 0 else blank(size) for i in range(6)], False)
    for frame in ('closed', 'open', 'opening', 'closing'):
        panel = blank(size)
        d = ImageDraw.Draw(panel)
        d.rectangle((size-6, 11, size-2, 21), fill=DARK, outline=STEEL)
        d.line((size-4, 13, size-3, 18), fill=OCHRE)
        for suffix in ('', '_protected'):
            add('panel_' + frame + suffix, panel)
        for kind in ('note', 'note_words', 'photo'):
            note = blank(size)
            if frame == 'closed':
                d = ImageDraw.Draw(note)
                d.rectangle((size//2-6, 9, size//2-3, 12), fill='#b3ad91', outline=EDGE)
            add(kind + '_' + frame, note)
    for stage in range(1, 5):
        add('panel_c' + str(stage), states['panel_open'][0][0])
    weld = blank(size)
    ImageDraw.Draw(weld).line((8, 24, size-12, 8), fill='#9b7547')
    add('welded', weld)
    seal = blank(size)
    ImageDraw.Draw(seal).rectangle((6, 14, size-10, 17), fill=OCHRE, outline=DARK)
    add('sealed', seal)
    for name in ('sparks', 'sparks_broken', 'sparks_damaged', 'sparks_open'):
        spark = blank(size)
        ImageDraw.Draw(spark).line((size-3, 12, size-6, 10, size-5, 13), fill='#fff7b0')
        add(name, [spark, blank(size), blank(size), blank(size)])
    return states


def directions(image):
    # Square DMI cells hold 64x32 / 32x64 art without any tile overhang.
    size = image.width
    horizontal = Image.new('RGBA', (size, size))
    horizontal.paste(image, (0, size-32))
    vertical = Image.new('RGBA', (size, size))
    vertical.paste(image.transpose(Image.Transpose.ROTATE_90), (0, 0))
    return (horizontal, horizontal, vertical, vertical)


def write_dmi(size, states, path):
    metadata = ['# BEGIN DMI', 'version = 4.0', '\twidth = {}'.format(size), '\theight = {}'.format(size)]
    tiles = []
    for name, (frames, loop) in states.items():
        metadata += ['state = "{}"'.format(name), '\tdirs = 4', '\tframes = {}'.format(len(frames))]
        if len(frames) > 1:
            metadata += ['\tdelay = ' + ','.join(['1']*len(frames))]
            if not loop:
                metadata += ['\tloop = 1']
        for frame in frames:
            tiles.extend(directions(frame))
    metadata.append('# END DMI')
    atlas = Image.new('RGBA', (size*8, size*((len(tiles)+7)//8)))
    for i, tile in enumerate(tiles):
        atlas.paste(tile, (i % 8*size, i // 8*size))
    info = PngImagePlugin.PngInfo()
    info.add_text('Description', '\n'.join(metadata) + '\n', zip=True)
    atlas.save(path, format='PNG', pnginfo=info)
    saved = Image.open(path)
    assert len(re.findall('state = ', saved.info['Description'])) == len(states)
    assert saved.size == atlas.size and saved.convert('RGBA').tobytes() == atlas.tobytes()
    assert states['fill_closed'][0][0].getpixel(((size-4)//2, 16))[3] == 255
    assert states['open'][0][0].getpixel(((size-4)//2, 16))[3] == 0
    assert states['fill_opening'][0][-1].getbbox() is None
    assert states['fill_closing'][0][0].tobytes() == states['fill_opening'][0][-1].tobytes()
    assert states['wheel_locked'][0][0].tobytes() != states['wheel_unlocked'][0][0].tobytes()
    closed = states['closed'][0][0].copy()
    closed.alpha_composite(states['fill_closed'][0][0])
    assert closed.getchannel('A').getextrema() == (255, 255), 'Closed door must fill every pixel, including corners'
    for frames, _ in states.values():
        for frame in frames:
            south, north, east, west = directions(frame)
            if size > 32:
                assert south.crop((0, 0, size, size-32)).getbbox() is None
                assert east.crop((32, 0, size, size)).getbbox() is None
    for frame in states['fill_opening'][0] + states['wheel_locking'][0]:
        assert ImageChops.subtract(frame.getchannel('A'), aperture(size)).getbbox() is None, 'Moving machinery escaped the frame aperture'
    print('PASS: {} — {} states, {} directional frames'.format(path.name, len(states), len(tiles)))


def main():
    FOLDER.mkdir(exist_ok=True)
    preview = Image.new('RGB', (64*6, 100), '#2b2d2e')
    art = {size: make_states(size) for size in (32, 64)}
    for size, filename, row in ((32, 'airlock.dmi', 12), (64, 'airlock_large.dmi', 60)):
        states = art[size]
        write_dmi(size, states, FOLDER / filename)
        ImageDraw.Draw(preview).text((3, row-12), '{} x 32'.format(size), fill='#b4b1a2')
        samples = []
        for engagement in (0, 1):
            sample = states['closed'][0][0].copy()
            sample.alpha_composite(states['fill_closed'][0][0])
            sample.alpha_composite(wheel(size, engagement, engagement*pi/2))
            sample.alpha_composite(lamps(size, '#b94f37' if engagement else '#8db04b'))
            samples.append(sample)
        for i in (1, 3, 4):
            sample = states['opening'][0][i].copy()
            sample.alpha_composite(states['fill_opening'][0][i])
            sample.alpha_composite(lamps(size, '#8db04b'))
            samples.append(sample)
        sample = states['open'][0][0].copy()
        sample.alpha_composite(lamps(size, '#8db04b'))
        samples.append(sample)
        for i, sample in enumerate(samples):
            preview.paste(sample, (i*64 + (64-size)//2, row), sample)
    preview.resize((1152, 300), Image.Resampling.NEAREST).save(FOLDER / 'preview.png')
    # Pauses at endpoints let the viewer inspect the mechanism and the hidden leaf.
    gif = []
    durations = []
    for state, count in (('wheel_locking', 10), ('wheel_unlocking', 10), ('fill_opening', 6), ('fill_closing', 6)):
        for i in range(count):
            canvas = Image.new('RGB', (120, 40), '#2b2d2e')
            for size, x in ((32, 4), (64, 48)):
                states = art[size]
                sample = states['closed'][0][0].copy()
                if state.startswith('wheel'):
                    sample.alpha_composite(states['fill_closed'][0][0])
                sample.alpha_composite(states[state][0][i])
                sample.alpha_composite(lamps(size, '#b94f37' if state == 'wheel_locking' else '#8db04b'))
                canvas.paste(sample, (x, 4), sample)
            gif.append(canvas.resize((600, 200), Image.Resampling.NEAREST))
            durations.append(500 if i == count-1 else 100)
    gif[0].save(FOLDER / 'preview.gif', save_all=True, append_images=gif[1:], duration=durations, loop=0)


if __name__ == '__main__':
    main()
