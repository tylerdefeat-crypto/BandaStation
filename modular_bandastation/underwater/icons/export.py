"""Package the generated 4x4 water animation sheet as a native 32px DMI."""
import sys
from pathlib import Path

from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from tools.dmi import Dmi

directory = Path(__file__).resolve().parent
sheet = Image.open(directory / "sources/water_volume.png").convert("RGBA")


def stitch_edges(frame):
    """Match opposite values and slopes inside the outer three pixels only."""
    band = 3
    for _ in range(2):
        pixels = frame.load()
        for y in range(frame.height):
            row = [pixels[x, y] for x in range(frame.width)]
            output = [list(pixel) for pixel in row]
            for channel in range(3):
                delta = (row[-1][channel] - row[0][channel]) / 2
                slope = ((row[-1][channel] - row[-2][channel])
                         - (row[1][channel] - row[0][channel])) / 2
                for offset in range(band):
                    t = offset / band
                    weight = 1 - 3 * t * t + 2 * t * t * t
                    tangent = band * (t - 2 * t * t + t * t * t)
                    output[offset][channel] = max(0, min(255, round(
                        row[offset][channel] + delta * weight + slope * tangent)))
                    output[-1 - offset][channel] = max(0, min(255, round(
                        row[-1 - offset][channel] - delta * weight + slope * tangent)))
            for x, pixel in enumerate(output):
                pixels[x, y] = tuple(pixel)
        frame = frame.transpose(Image.Transpose.TRANSPOSE)
    return frame


dmi = Dmi(32, 32)
# Opaque geometry for /tg/'s PLANE_SPACE whitifier; never drawn above the seabed.
dmi.state("ocean_mask").frame(Image.new("RGBA", (32, 32), "#061b20"))
volume = dmi.state("volume", rewind=True)
for row in range(4):
    for column in range(4):
        bounds = (
            column * sheet.width // 4,
            row * sheet.height // 4,
            (column + 1) * sheet.width // 4,
            (row + 1) * sheet.height // 4,
        )
        frame = sheet.crop(bounds).resize((32, 32), Image.Resampling.LANCZOS)
        stitched = stitch_edges(frame.copy())
        assert stitched.crop((3, 3, 29, 29)).tobytes() == frame.crop((3, 3, 29, 29)).tobytes()
        volume.frame(stitched, delay=2)
dmi.to_file(directory / "water.dmi")

check = Dmi.from_file(directory / "water.dmi")
assert (check.width, check.height) == (32, 32)
assert check.get_state("ocean_mask").frames[0].getextrema()[3] == (255, 255)
animation = check.get_state("volume")
assert animation.framecount == 16 and animation.rewind and animation.loop == 0
assert animation.delays == [2] * 16
assert len({frame.tobytes() for frame in animation.frames}) == 16
assert all(frame.getextrema()[3] == (255, 255) for frame in animation.frames)
assert all(red < green and green >= blue * 0.8 for red, green, blue, _ in
           (ImageStat.Stat(frame).mean for frame in animation.frames))
assert all(sum(abs(a - b) for a, b in zip(left.tobytes(), right.tobytes())) / (32 * 32 * 4) < 5
           for left, right in zip(animation.frames, animation.frames[1:]))
# Check actual matching edges, rather than hiding mismatches by flattening the artwork.
for frame in animation.frames:
    assert all(frame.getpixel((0, i)) == frame.getpixel((31, i))
               and frame.getpixel((i, 0)) == frame.getpixel((i, 31)) for i in range(32))
    assert min(ImageStat.Stat(frame).stddev[1:3]) > 5, "Water texture lost its visible pattern"
assert Image.open(directory / "seafloor.png").width >= 1024
for name in ("haze", "fine_silt", "silt"):
    layer = Image.open(directory / f"{name}.png")
    assert layer.size == (480, 480)
    assert layer.convert("RGBA").getextrema()[3][0] == 0
print("Water icon and parallax assets verified.")
