/area/shuttle/stationtrauma
	name = "StationTrauma: подлодка"
	requires_power = TRUE

/turf/open/floor/iron/stationtrauma_hull
	baseturfs = list(/turf/open/space/ocean, /turf/baseturf_skipover/shuttle, /turf/open/space/ocean)

/turf/open/floor/plating/stationtrauma_hull
	baseturfs = list(/turf/open/space/ocean, /turf/baseturf_skipover/shuttle, /turf/open/space/ocean)

/turf/closed/wall/stationtrauma_hull
	baseturfs = list(/turf/open/space/ocean, /turf/baseturf_skipover/shuttle, /turf/open/space/ocean)

/// Hooks only our hull, including dry cells whose destination may have been external ocean.
/datum/element/stationtrauma_hull
	element_flags = ELEMENT_DETACH_ON_HOST_DESTROY

/datum/element/stationtrauma_hull/Attach(turf/target)
	. = ..()
	if(!isturf(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_TURF_ON_SHUTTLE_MOVE, PROC_REF(move_water), override = TRUE)
	RegisterSignal(target, COMSIG_TURF_CHANGE, PROC_REF(hull_changed), override = TRUE)

/datum/element/stationtrauma_hull/Detach(turf/source)
	UnregisterSignal(source, list(COMSIG_TURF_ON_SHUTTLE_MOVE, COMSIG_TURF_CHANGE))
	return ..()

/datum/element/stationtrauma_hull/proc/move_water(turf/source, turf/destination)
	SIGNAL_HANDLER
	// CopyOnTop filters duplicate ocean layers; keep a movable breach above the boundary for later damage.
	if(destination.baseturf_at_depth(1) == /turf/baseturf_skipover/shuttle)
		destination.insert_baseturf(destination.count_baseturfs() + 1, /turf/open/space/ocean)
	if(isopenturf(destination))
		var/datum/component/floodwater/water = source.GetComponent(/datum/component/floodwater)
		var/depth = water?.depth || 0
		var/infinite = water?.infinite_source || FALSE
		var/water_temperature = water?.temperature
		var/turf/open/intake = destination
		// CopyOnTop may retain destination-ocean water; replace it with the vessel's exact state.
		intake.set_water_depth(0)
		if(depth)
			intake.set_water_depth(depth, infinite, water_temperature)
	destination.AddElement(/datum/element/stationtrauma_hull)
	source.RemoveElement(/datum/element/stationtrauma_hull)

/datum/element/stationtrauma_hull/proc/hull_changed(turf/source, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER
	post_change_callbacks += CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(restore_stationtrauma_hull))

/proc/restore_stationtrauma_hull(turf/tile)
	if(istype(get_area(tile), /area/shuttle/stationtrauma))
		tile.AddElement(/datum/element/stationtrauma_hull)

/obj/docking_port/mobile/stationtrauma
	name = "StationTrauma"
	shuttle_id = "stationtrauma"
	area_type = /area/shuttle/stationtrauma
	callTime = 20 SECONDS
	movement_force = list("KNOCKDOWN" = 0, "THROW" = 0)

/obj/docking_port/mobile/stationtrauma/request(obj/docking_port/stationary/target)
	if(mode != SHUTTLE_IDLE || !istype(target, /obj/docking_port/stationary/stationtrauma) || target.dir != dir || !check_dock(target, silent = TRUE) || !canMove())
		return DOCKING_BLOCKED
	var/list/current_turfs = return_turfs()
	for(var/turf/tile as anything in return_ordered_turfs(target.x, target.y, target.z, target.dir))
		if(tile in current_turfs)
			return DOCKING_BLOCKED
	destination = target
	mode = SHUTTLE_CALL
	setTimer(callTime)
	// shortcut: stay at the departure point until arrival, add an ocean transit zone if expeditions need it.
	return DOCKING_SUCCESS

/obj/docking_port/mobile/stationtrauma/check()
	if(mode != SHUTTLE_CALL || timeLeft(1) > 0)
		return
	if(QDELETED(destination) || initiate_docking(destination) != DOCKING_SUCCESS)
		visible_message(span_warning("[src]: стыковка невозможна, переход отменён."))
	mode = SHUTTLE_IDLE
	timer = 0
	destination = null

/obj/docking_port/stationary/stationtrauma
	area_type = /area/space/ocean
	width = 14
	height = 10

/obj/docking_port/stationary/stationtrauma/base
	name = "Подводная база"
	shuttle_id = "stationtrauma_base"

/obj/docking_port/stationary/stationtrauma/wreck
	name = "Затонувший пост"
	shuttle_id = "stationtrauma_wreck"

/obj/machinery/computer/shuttle/stationtrauma
	name = "навигация подлодки"
	desc = "Маршрут между фиксированными подводными точками. Переход занимает 20 секунд; интерьер, вещи и повреждения остаются с подлодкой."
	shuttleId = "stationtrauma"
	possible_destinations = "stationtrauma_base;stationtrauma_wreck"
	no_destination_swap = TRUE
	req_access = list()

/obj/machinery/computer/shuttle/stationtrauma/post_machine_initialize()
	. = ..()
	// InitializeAtoms shares its late-loader queue: never nest it inside post_machine_initialize.
	addtimer(CALLBACK(src, PROC_REF(prepare_vessel)), 0)

/obj/machinery/computer/shuttle/stationtrauma/proc/prepare_vessel()
	var/area/shuttle/stationtrauma/interior = get_area(src)
	if(!istype(interior))
		return
	var/obj/docking_port/mobile/stationtrauma/vessel = locate() in interior
	if(!vessel)
		return
	if(vessel.registered)
		return
	// Generic template placement deliberately leaves mobile ports for their template to initialize.
	if(!(vessel.flags_1 & INITIALIZED_1))
		SSatoms.InitializeAtoms(list(vessel))
	if(!vessel.registered)
		vessel.shuttle_areas[interior] = TRUE
		vessel.calculate_docking_port_information()
		vessel.register()
	for(var/turf/tile as anything in vessel.return_turfs())
		if(get_area(tile) == interior)
			// Normal templates filter ocean baseturfs as space; restore our ocean below and above the movement boundary.
			tile.baseturfs = list(/turf/open/space/ocean, /turf/baseturf_skipover/shuttle, /turf/open/space/ocean)
			tile.AddElement(/datum/element/stationtrauma_hull)
	vessel.linkup()
