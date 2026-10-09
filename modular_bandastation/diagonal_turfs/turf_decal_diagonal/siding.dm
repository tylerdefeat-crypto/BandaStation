/obj/effect/turf_decal/siding/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/diagonal/Initialize(mapload)
	SHOULD_CALL_PARENT(FALSE)
	var/turf/closed/support = loc
	if(!istype(support) || !(support.smoothing_flags & SMOOTH_DIAGONAL_CORNERS))
		return ..()
	flags_1 |= INITIALIZED_1
	support.AddElement(/datum/element/decal, icon, icon_state, SOUTH, null, layer, alpha, color, support.smoothing_junction || 0, FALSE, null)
	return INITIALIZE_HINT_QDEL

/obj/effect/turf_decal/siding/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/white/diagonal
	parent_type = /obj/effect/turf_decal/siding/diagonal
	color = /obj/effect/turf_decal/siding/white::color

/obj/effect/turf_decal/siding/white/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/red/diagonal
	parent_type = /obj/effect/turf_decal/siding/diagonal
	color = /obj/effect/turf_decal/siding/red::color

/obj/effect/turf_decal/siding/red/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/dark_red/diagonal
	parent_type = /obj/effect/turf_decal/siding/diagonal
	color = /obj/effect/turf_decal/siding/dark_red::color

/obj/effect/turf_decal/siding/dark_red/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/green/diagonal
	parent_type = /obj/effect/turf_decal/siding/diagonal
	color = /obj/effect/turf_decal/siding/green::color

/obj/effect/turf_decal/siding/green/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/dark_green/diagonal
	parent_type = /obj/effect/turf_decal/siding/diagonal
	color = /obj/effect/turf_decal/siding/dark_green::color

/obj/effect/turf_decal/siding/dark_green/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/blue/diagonal
	parent_type = /obj/effect/turf_decal/siding/diagonal
	color = /obj/effect/turf_decal/siding/blue::color

/obj/effect/turf_decal/siding/blue/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/dark_blue/diagonal
	parent_type = /obj/effect/turf_decal/siding/diagonal
	color = /obj/effect/turf_decal/siding/dark_blue::color

/obj/effect/turf_decal/siding/dark_blue/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/yellow/diagonal
	parent_type = /obj/effect/turf_decal/siding/diagonal
	color = /obj/effect/turf_decal/siding/yellow::color

/obj/effect/turf_decal/siding/yellow/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/purple/diagonal
	parent_type = /obj/effect/turf_decal/siding/diagonal
	color = /obj/effect/turf_decal/siding/purple::color

/obj/effect/turf_decal/siding/purple/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/brown/diagonal
	parent_type = /obj/effect/turf_decal/siding/diagonal
	color = /obj/effect/turf_decal/siding/brown::color

/obj/effect/turf_decal/siding/brown/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/dark/diagonal
	parent_type = /obj/effect/turf_decal/siding/diagonal
	color = /obj/effect/turf_decal/siding/dark::color

/obj/effect/turf_decal/siding/dark/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_plain_diagonal.dmi'
	dir = NORTHEAST

/obj/effect/turf_decal/siding/wood/diagonal
	parent_type = /obj/effect/turf_decal/siding/diagonal
	color = /obj/effect/turf_decal/siding/wood::color
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_wood_diagonal.dmi'
	icon_state = "siding_wood"

/obj/effect/turf_decal/siding/wood/corner/diagonal
	icon = 'modular_bandastation/diagonal_turfs/turf_decal_diagonal/icons/siding_wood_diagonal.dmi'
	dir = NORTHEAST

