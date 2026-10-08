"""Deterministic, spatially tileable and temporally periodic caustics. Requires numpy/Pillow."""
from pathlib import Path
import numpy as np
from PIL import Image, PngImagePlugin

FOLDER = Path(__file__).resolve().parent / 'icons'
SIZE = 128
FRAMES = 64
DELAY = 0.8  # Deciseconds: 12.5 fps, 5.12-second seamless loop.
RNG = np.random.default_rng(173)
centers = np.array([(x, y) for y in range(6) for x in range(6)], dtype=float) * SIZE / 6
centers += RNG.uniform(2, 16, centers.shape)
phases = RNG.uniform(0, 2 * np.pi, centers.shape)


def texture(phase, x, y):
    phase %= 2 * np.pi
    moving = centers + 3 * np.sin(phase + phases)
    # Periodic domain warping bends the cell edges into flowing optical filaments.
    u = x + 4 * np.sin(2 * np.pi * y / SIZE * 2 + phase) + 2 * np.cos(2 * np.pi * x / SIZE + phase)
    v = y + 4 * np.sin(2 * np.pi * x / SIZE * 2 - phase) + 2 * np.cos(2 * np.pi * y / SIZE - phase)
    dx = (u[..., None] - moving[:, 0] + SIZE / 2) % SIZE - SIZE / 2
    dy = (v[..., None] - moving[:, 1] + SIZE / 2) % SIZE - SIZE / 2
    nearest = np.partition(dx * dx + dy * dy, 1, axis=-1)[..., :2]
    gap = np.sqrt(nearest[..., 1]) - np.sqrt(nearest[..., 0])
    glow = 205 * np.exp(-(gap / 0.85) ** 2) + 40 * np.exp(-(gap / 2.1) ** 2)
    return np.clip(glow, 0, 255).astype('uint8')


def main():
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(float)
    x += 0.5
    y += 0.5
    first = texture(0, x, y)
    assert np.array_equal(first, texture(2 * np.pi, x, y))
    assert np.max(np.abs(first.astype(int) - texture(0, x + SIZE, y).astype(int))) <= 1
    assert np.max(np.abs(first.astype(int) - texture(0, x, y + SIZE).astype(int))) <= 1
    frames = []
    for frame in range(FRAMES):
        alpha = texture(2 * np.pi * frame / FRAMES, x, y)
        rgba = np.full((SIZE, SIZE, 4), 255, dtype='uint8')
        rgba[:, :, 3] = alpha
        frames.append(Image.fromarray(rgba))
    # One animated appearance/filter per 4x4 block, not sixteen filtered cells.
    atlas = Image.new('RGBA', (SIZE * 8, SIZE * 8))
    description = '# BEGIN DMI\nversion = 4.0\n\twidth = 128\n\theight = 128\n'
    description += 'state = "caustics"\n\tdirs = 1\n\tframes = {}\n\tdelay = {}\n'.format(FRAMES, ','.join([str(DELAY)] * FRAMES))
    for index, frame in enumerate(frames):
        atlas.paste(frame, (index % 8 * SIZE, index // 8 * SIZE))
    metadata = PngImagePlugin.PngInfo()
    metadata.add_text('Description', description + '# END DMI\n', zip=True)
    atlas.save(FOLDER / 'caustics.dmi', format='PNG', pnginfo=metadata)
    Image.new('RGBA', (32, 32), (255, 255, 255, 255)).save(FOLDER / 'mask.png')
    assert len(frames) == FRAMES
    print('PASS: seamless 4x4 block, 64 frames, spatial wrapping and temporal loop verified.')


if __name__ == '__main__':
    main()
