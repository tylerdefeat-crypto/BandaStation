SUBSYSTEM_DEF(floodwater)
	name = "Floodwater"
	wait = 1 SECONDS
	priority = FIRE_PRIORITY_DEFAULT
	ss_flags = SS_NO_INIT | SS_BACKGROUND
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	var/list/active = list()
	var/list/currentrun = list()

/datum/controller/subsystem/floodwater/fire(resumed = FALSE)
	if(!resumed)
		currentrun = active.Copy()
	while(length(currentrun))
		var/datum/component/floodwater/water = currentrun[length(currentrun)]
		currentrun.len--
		active -= water
		if(!QDELETED(water))
			water.spread()
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/floodwater/stat_entry(msg)
	return ..("Active:[length(active)]")

/datum/component/floodwater/proc/wake(datum/source)
	SIGNAL_HANDLER
	SSfloodwater.active[src] = TRUE

/datum/component/floodwater/proc/wake_neighbours()
	var/turf/tile = parent
	for(var/direction in GLOB.cardinals)
		var/turf/next_tile = get_step(tile, direction)
		var/datum/component/floodwater/next_water = next_tile?.GetComponent(/datum/component/floodwater)
		next_water?.wake()

/datum/component/floodwater/proc/spread()
	var/turf/open/tile = parent
	// shortcut: equal-height, single-z tiles; add elevation/head pressure only if maps need them.
	for(var/turf/open/next_tile as anything in tile.atmos_adjacent_turfs)
		if(next_tile.z != tile.z || get_dist(tile, next_tile) != 1 || !(get_dir(tile, next_tile) in GLOB.cardinals))
			continue
		if(istype(next_tile, /turf/open/water))
			continue
		var/datum/component/floodwater/next_water = next_tile.GetComponent(/datum/component/floodwater)
		if(next_water?.infinite_source)
			continue
		var/next_depth = next_water?.depth || 0
		var/difference = depth - next_depth
		if(difference <= FLOOD_WATER_FLOW_EPSILON)
			continue
		var/amount = min(FLOOD_WATER_FLOW, difference / 2)
		var/accepted = next_tile.add_water(amount * FLOOD_WATER_LITRES_PER_CM, temperature)
		remove_water(accepted, allow_ocean = TRUE)
		if(infinite_source)
			wake()
