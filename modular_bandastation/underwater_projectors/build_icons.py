"""Deterministic soft beam and suspended dust; one shared client-side animation."""
from pathlib import Path
import numpy as np
from PIL import Image, PngImagePlugin

SIZE, LENGTH, FRAMES = 448, 192, 48
FOLDER = Path(__file__).resolve().parent / 'icons'
y, x = np.mgrid[:SIZE, :SIZE].astype(float)
x += 0.5 - SIZE / 2
y = SIZE / 2 - y - 0.5
t = np.clip(y / LENGTH, 0, 1)
half_width = 2 + 46 * t
edge = np.clip((1 - np.abs(x) / half_width) / 0.3, 0, 1)
envelope = edge * edge * (3 - 2 * edge) * (1 - t) ** 1.6
envelope *= (y >= 0) & (y < LENGTH)
core = np.exp(-2 * (x / half_width) ** 2)
beam = envelope * (65 + 85 * core)
rng = np.random.default_rng(771)
specks = [(rng.uniform(10, 182), rng.uniform(-0.8, 0.8), rng.uniform(0, 2*np.pi)) for _ in range(48)]


def frame(phase, dust=True):
    phase %= 2 * np.pi
    alpha = beam.copy()
    if dust:
        for distance, across, shift in specks:
            cy = distance + 3 * np.sin(phase + shift)
            cx = across * (2 + 46 * cy / LENGTH) + 2 * np.cos(phase + shift)
            # Tiny antialiased flecks drift less than a pixel between frames.
            dot = np.exp(-((x-cx)**2 + (y-cy)**2) / 0.8)
            alpha += dot * envelope * (95 + 45*np.sin(phase+shift))
    rgba = np.full((SIZE, SIZE, 4), 255, dtype=np.uint8)
    rgba[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    return Image.fromarray(rgba)


def main():
    FOLDER.mkdir(exist_ok=True)
    animation = [frame(i * 2*np.pi / FRAMES) for i in range(FRAMES)]
    assert animation[0].tobytes() == frame(2*np.pi).tobytes()
    assert animation[0].tobytes() != animation[FRAMES // 4].tobytes()
    for image in animation:
        a = np.asarray(image)[:, :, 3]
        assert not a[y < 0].any(), 'No light behind the projector'
        assert not a[envelope == 0].any(), 'Dust escaped the beam'
    assert np.max(np.abs(np.asarray(animation[-1])[:, :, 3].astype(int) - np.asarray(animation[0])[:, :, 3].astype(int))) < 40
    tiles = [frame(0, dust=False)] + animation
    atlas = Image.new('RGBA', (SIZE * 8, SIZE * 7))
    for i, tile in enumerate(tiles):
        atlas.paste(tile, (i % 8 * SIZE, i // 8 * SIZE))
    desc = f'# BEGIN DMI\nversion = 4.0\n\twidth = {SIZE}\n\theight = {SIZE}\n'
    desc += 'state = "beam"\n\tdirs = 1\n\tframes = 1\n'
    desc += f'state = "beam_dust"\n\tdirs = 1\n\tframes = {FRAMES}\n\tdelay = ' + ','.join(['1'] * FRAMES) + '\n'
    info = PngImagePlugin.PngInfo()
    info.add_text('Description', desc + '# END DMI\n', zip=True)
    atlas.save(FOLDER / 'projector.dmi', format='PNG', pnginfo=info)
    # StrongDMM does not execute Initialize()/matrix rotations. Give it native dirs.
    # DMI direction order: S, N, E, W, SE, SW, NE, NW; Pillow angles are CCW.
    directions = ((180, 0, -1), (0, 0, 1), (-90, 1, 0), (90, -1, 0),
                  (-135, 1, -1), (135, -1, -1), (-45, 1, 1), (45, -1, 1))
    preview = Image.new('RGBA', (SIZE * 8, SIZE * 2))
    preview_desc = f'# BEGIN DMI\nversion = 4.0\n\twidth = {SIZE}\n\theight = {SIZE}\n'
    for row, (state, source) in enumerate((('beam', tiles[0]), ('beam_dust', animation[0]))):
        preview_desc += f'state = "{state}"\n\tdirs = 8\n\tframes = 1\n'
        for column, (angle, dx, dy) in enumerate(directions):
            rotated = source.rotate(angle, resample=Image.Resampling.BICUBIC)
            weights = np.asarray(rotated)[:, :, 3].astype(float)
            cx = (weights * x).sum() / weights.sum()
            cy = (weights * y).sum() / weights.sum()
            assert cx * dx + cy * dy > 20, f'{state}: incorrect facing at {angle}'
            assert abs(cx * dy - cy * dx) < 2, f'{state}: off-axis preview'
            preview.paste(rotated, (column * SIZE, row * SIZE))
    preview_info = PngImagePlugin.PngInfo()
    preview_info.add_text('Description', preview_desc + '# END DMI\n', zip=True)
    preview.save(FOLDER / 'projector_preview.dmi', format='PNG', pnginfo=preview_info)
    print('PASS: seamless 48-frame loop, static variant, dust stays inside forward cone.')
    print('PASS: both map-preview states face all 8 DMI directions correctly.')


if __name__ == '__main__':
    main()
