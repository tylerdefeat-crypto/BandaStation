/obj/effect/turf_decal/siding/thinplating_new/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/thinplating_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/thinplating_new/diagonal/Initialize(mapload)
	var/turf/closed/support = loc
	if(!istype(support) || !(support.smoothing_flags & SMOOTH_DIAGONAL_CORNERS))
		return ..()
	SHOULD_CALL_PARENT(FALSE)
	flags_1 |= INITIALIZED_1
	// The decal element follows subsequent smoothing, including mapload and shuttle moves.
	support.AddElement(/datum/element/decal, icon, icon_state, SOUTH, null, layer, alpha, color, support.smoothing_junction || 0, FALSE, null)
	return INITIALIZE_HINT_QDEL

/obj/effect/turf_decal/siding/thinplating_new/light/diagonal
	parent_type = /obj/effect/turf_decal/siding/thinplating_new/diagonal
	color = /obj/effect/turf_decal/siding/thinplating_new/light::color

/obj/effect/turf_decal/siding/thinplating_new/dark/diagonal
	parent_type = /obj/effect/turf_decal/siding/thinplating_new/diagonal
	color = /obj/effect/turf_decal/siding/thinplating_new/dark::color

/obj/effect/turf_decal/siding/thinplating_new/terracotta/diagonal
	parent_type = /obj/effect/turf_decal/siding/thinplating_new/diagonal
	color = /obj/effect/turf_decal/siding/thinplating_new/terracotta::color
