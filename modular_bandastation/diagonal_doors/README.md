# Diagonal shutters

Types:
- `/obj/machinery/door/poddoor/shutters/diagonal`
- `/obj/machinery/door/poddoor/shutters/diagonal/preopen`

Place on the same tile as `/turf/closed/indestructible/opsglass/diagonal`.
At runtime, shutters follow the turf's diagonal direction and inner/outer corner
after smoothing. They keep the original shutter layers, controls, sounds, and timings.
Opening shutters does not make the underlying closed window turf passable.

For placement on floors, or for the map editor preview, set `dir` to the occupied
corner: `NORTHEAST` (5), `SOUTHEAST` (6), `NORTHWEST` (9), or `SOUTHWEST` (10).
`inner_corner = TRUE` selects the narrow inner corner when mapping without a window.

`build_icons.py` is the editable source for the DMI. Run it with Python and Pillow
to rebuild from the original shutter animation and our diagonal window masks:

```sh
python modular_bandastation/diagonal_doors/build_icons.py
```

The builder checks all frame masks and preserves animation frame counts and delays.
The `diagonal_shutters` unit test checks alignment, animated states, and `preopen`.
