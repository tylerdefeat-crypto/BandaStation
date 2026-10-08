# Diagonal thin plating

Add `/diagonal` to the existing `thinplating_new`, `thinplating_new/light`,
`thinplating_new/dark`, or `thinplating_new/terracotta` type path.
Colors are inherited from the existing palette; map overrides of `color` also work.

Place the decal on the diagonal wall/window tile, not the neighboring floor.
In game, the decal follows the host's smoothing and draws along the exposed floor
side of its diagonal edge. It updates when the host changes its smoothing junction.
Non-diagonal junctions hide the trim rather than leave a stray diagonal on the floor.

On ordinary floors, or for the map editor preview, set `dir` to the corner occupied
by the wall/window: NE = 5, SE = 6, NW = 9, SW = 10.

Edit `icons/thinplating_source.png` (the original north-facing trim) and run
`python modular_bandastation/diagonal_turfs/turf_decal_diagonal/build_icons.py`
with Pillow installed to rebuild the DMI. The script checks thickness and symmetry.

## Diagonal trimlines

Use `/obj/effect/turf_decal/trimline/<color>/line/diagonal`.
Colors: white, red, dark_red, green, dark_green, blue, dark_blue, yellow,
purple, brown, neutral, tram, dark. Original alpha, color and holiday pattern are retained.

Example: `/obj/effect/turf_decal/trimline/neutral/line/diagonal`.
Place it on the diagonal wall/window turf to follow smoothing; on a floor, choose
NE=5, SE=6, NW=9, SW=10 manually (the occupied wall corner).
The line retains its original inset from the edge. Small joining pieces are available as `/obj/effect/turf_decal/trimline/<color>/corner/diagonal`.
Place these on the neighboring floor tile, with `dir` pointing to the corner that
contains the short segment (NE=5, SE=6, NW=9, SW=10). Unlike the long line, the small
corner uses manual direction and does not follow wall smoothing.

`icons/trimline_source.png` is the north-facing `trimline` sprite extracted from
`icons/turf/decals.dmi`. The shared `build_icons.py` builds both diagonal DMIs.

## Wood and colored siding

Wood: `/obj/effect/turf_decal/siding/wood/diagonal` and
`/obj/effect/turf_decal/siding/wood/corner/diagonal`.

The same suffixes are available for siding/white, red, dark_red, green,
dark_green, blue, dark_blue, yellow, purple, brown and dark, plus uncolored siding.
Wood keeps its own texture; the other colors use the original plain siding texture.
Long diagonals follow wall/window smoothing; small corners go on the neighboring
floor, with manual NE=5, SE=6, NW=9, SW=10 direction. Map `color` overrides also work.

The north-facing sources are `icons/siding_wood_source.png` and
`icons/siding_plain_source.png`, extracted from `icons/turf/decals.dmi`.
The shared builder verifies symmetry, mask states and continuity into the corner.
