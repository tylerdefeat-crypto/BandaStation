/turf/closed/indestructible/opsglass/diagonal
	icon = 'modular_bandastation/diagonal_turfs/icons/opsglass_diagonal.dmi'
	smoothing_flags = SMOOTH_BITMASK | SMOOTH_DIAGONAL_CORNERS
	smoothing_groups = SMOOTH_GROUP_SHUTTLE_PARTS + SMOOTH_GROUP_WINDOW_FULLTILE_PLASTITANIUM + SMOOTH_GROUP_WALLS + SMOOTH_GROUP_PLASTINUM_WALLS
	canSmoothWith = SMOOTH_GROUP_WINDOW_FULLTILE_PLASTITANIUM + SMOOTH_GROUP_WALLS

/turf/closed/indestructible/opsglass/diagonal/Initialize(mapload)
	. = ..()
	// The icon already includes plating and grille, clipped to the diagonal corners.
	underlays.Cut()

// Diagonal walls and windows must retain the neighboring floor's tint and orientation.
/turf/open/floor/get_smooth_underlay_icon(mutable_appearance/underlay_appearance, turf/asking_turf, adjacency_dir)
	. = ..()
	underlay_appearance.color = color
	underlay_appearance.dir = dir
	underlay_appearance.appearance_flags |= RESET_COLOR
