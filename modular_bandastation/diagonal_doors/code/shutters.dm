/obj/machinery/door/poddoor/shutters/diagonal
	icon = 'modular_bandastation/diagonal_doors/icons/shutters_diagonal.dmi'
	dir = NORTHEAST
	/// The narrow inner corner follows the window's diagonal smoothing state.
	var/inner_corner = FALSE

/obj/machinery/door/poddoor/shutters/diagonal/Initialize(mapload)
	. = ..()
	var/static/list/loc_connections = list(
		COMSIG_ATOM_SMOOTHED_ICON = PROC_REF(match_diagonal_turf),
	)
	AddElement(/datum/element/connect_loc, loc_connections)
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(match_diagonal_turf))
	match_diagonal_turf()

/obj/machinery/door/poddoor/shutters/diagonal/proc/match_diagonal_turf()
	SIGNAL_HANDLER
	var/turf/closed/support = get_turf(src)
	if(!istype(support) || !(support.smoothing_flags & SMOOTH_DIAGONAL_CORNERS))
		return
	var/junction = support.smoothing_junction
	// These are the eight corner states supported by closed-turf smoothing.
	if(!(junction in list(5, 6, 9, 10, 21, 38, 74, 137)))
		return
	var/new_dir = junction & CARDINAL_SMOOTHING_JUNCTIONS
	var/new_inner_corner = junction != new_dir
	if(dir == new_dir && inner_corner == new_inner_corner)
		return
	setDir(new_dir)
	inner_corner = new_inner_corner
	update_appearance(UPDATE_ICON)

/obj/machinery/door/poddoor/shutters/diagonal/update_icon_state()
	. = ..()
	if(inner_corner)
		icon_state += "-inner"

/obj/machinery/door/poddoor/shutters/diagonal/preopen
	icon_state = "open"
	density = FALSE
	opacity = FALSE
