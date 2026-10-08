/obj/effect/turf_decal/trimline/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/diagonal/Initialize(mapload)
	var/turf/closed/support = loc
	if(!istype(support) || !(support.smoothing_flags & SMOOTH_DIAGONAL_CORNERS))
		return ..()
	SHOULD_CALL_PARENT(FALSE)
	flags_1 |= INITIALIZED_1
#ifndef MAP_TEST
	if(use_holiday_colors)
		var/custom_color = request_decoration_colors(src, pattern)
		if(custom_color)
			color = custom_color
			alpha = /obj/effect/turf_decal/trimline::alpha
#endif
	support.AddElement(/datum/element/decal, icon, icon_state, SOUTH, null, layer, alpha, color, support.smoothing_junction || 0, FALSE, null)
	return INITIALIZE_HINT_QDEL

/obj/effect/turf_decal/trimline/white/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/white/line::color
	alpha = /obj/effect/turf_decal/trimline/white/line::alpha
	pattern = /obj/effect/turf_decal/trimline/white/line::pattern

/obj/effect/turf_decal/trimline/red/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/red/line::color
	alpha = /obj/effect/turf_decal/trimline/red/line::alpha
	pattern = /obj/effect/turf_decal/trimline/red/line::pattern

/obj/effect/turf_decal/trimline/dark_red/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/dark_red/line::color
	alpha = /obj/effect/turf_decal/trimline/dark_red/line::alpha
	pattern = /obj/effect/turf_decal/trimline/dark_red/line::pattern

/obj/effect/turf_decal/trimline/green/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/green/line::color
	alpha = /obj/effect/turf_decal/trimline/green/line::alpha
	pattern = /obj/effect/turf_decal/trimline/green/line::pattern

/obj/effect/turf_decal/trimline/dark_green/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/dark_green/line::color
	alpha = /obj/effect/turf_decal/trimline/dark_green/line::alpha
	pattern = /obj/effect/turf_decal/trimline/dark_green/line::pattern

/obj/effect/turf_decal/trimline/blue/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/blue/line::color
	alpha = /obj/effect/turf_decal/trimline/blue/line::alpha
	pattern = /obj/effect/turf_decal/trimline/blue/line::pattern

/obj/effect/turf_decal/trimline/dark_blue/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/dark_blue/line::color
	alpha = /obj/effect/turf_decal/trimline/dark_blue/line::alpha
	pattern = /obj/effect/turf_decal/trimline/dark_blue/line::pattern

/obj/effect/turf_decal/trimline/yellow/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/yellow/line::color
	alpha = /obj/effect/turf_decal/trimline/yellow/line::alpha
	pattern = /obj/effect/turf_decal/trimline/yellow/line::pattern

/obj/effect/turf_decal/trimline/purple/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/purple/line::color
	alpha = /obj/effect/turf_decal/trimline/purple/line::alpha
	pattern = /obj/effect/turf_decal/trimline/purple/line::pattern

/obj/effect/turf_decal/trimline/brown/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/brown/line::color
	alpha = /obj/effect/turf_decal/trimline/brown/line::alpha
	pattern = /obj/effect/turf_decal/trimline/brown/line::pattern

/obj/effect/turf_decal/trimline/neutral/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/neutral/line::color
	alpha = /obj/effect/turf_decal/trimline/neutral/line::alpha
	pattern = /obj/effect/turf_decal/trimline/neutral/line::pattern

/obj/effect/turf_decal/trimline/tram/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/tram/line::color
	alpha = /obj/effect/turf_decal/trimline/tram/line::alpha
	pattern = /obj/effect/turf_decal/trimline/tram/line::pattern

/obj/effect/turf_decal/trimline/dark/line/diagonal
	parent_type = /obj/effect/turf_decal/trimline/diagonal
	color = /obj/effect/turf_decal/trimline/dark/line::color
	alpha = /obj/effect/turf_decal/trimline/dark/line::alpha
	pattern = /obj/effect/turf_decal/trimline/dark/line::pattern

/obj/effect/turf_decal/trimline/white/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/red/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/dark_red/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/green/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/dark_green/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/blue/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/dark_blue/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/yellow/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/purple/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/brown/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/neutral/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/tram/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

/obj/effect/turf_decal/trimline/dark/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/trimline_diagonal.dmi'
	icon_state = "trimline_corner"
	dir = NORTHEAST

