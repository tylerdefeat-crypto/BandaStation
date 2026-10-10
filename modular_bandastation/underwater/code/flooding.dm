SUBSYSTEM_DEF(floodwater)
	name = "Floodwater"
	wait = 1 SECONDS
	priority = FIRE_PRIORITY_DEFAULT
	ss_flags = SS_NO_INIT | SS_BACKGROUND
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	var/list/active = list()
	var/list/currentrun = list()
	var/list/equalized = list()

/datum/controller/subsystem/floodwater/fire(resumed = FALSE)
	if(!resumed)
		currentrun = active.Copy()
		equalized = list()
	while(length(currentrun))
		var/datum/component/floodwater/water = currentrun[length(currentrun)]
		currentrun.len--
		active -= water
		if(!QDELETED(water))
			water.spread(equalized)
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

/// Check objects directly: the asynchronous atmos cache can still describe an airlock that has just closed.
/turf/open/proc/can_pass_stationtrauma_water(turf/open/other)
	if(!isopenturf(other) || other.z != z || blocks_air || other.blocks_air || get_dist(src, other) != 1 || !(get_dir(src, other) in GLOB.cardinals))
		return FALSE
	for(var/obj/obstacle in contents + other.contents)
		var/turf/target = obstacle.loc == src ? other : src
		if(!CANATMOSPASS(obstacle, target, FALSE))
			return FALSE
	return TRUE

/turf/open/proc/stationtrauma_water_room()
	var/list/room = list(src)
	var/list/visited = list()
	visited[src] = TRUE
	var/index = 1
	while(index <= length(room))
		var/turf/open/tile = room[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/open/neighbor = get_step(tile, direction)
			if(!isopenturf(neighbor) || visited[neighbor] || istype(neighbor, /turf/open/water) || !tile.can_pass_stationtrauma_water(neighbor))
				continue
			var/datum/component/floodwater/water = neighbor.GetComponent(/datum/component/floodwater)
			if(water?.infinite_source || (isspaceturf(neighbor) && !water))
				continue
			visited[neighbor] = TRUE
			room += neighbor
	return room

/datum/component/floodwater/proc/spread(list/equalized)
	var/turf/open/tile = parent
	// shortcut: connected floors share one elevation; add height-aware flow if stepped decks are introduced.
	if(!infinite_source)
		var/list/previous = equalized?[tile]
		if(previous && previous[1] == depth && previous[2] == temperature)
			return
		var/list/room = tile.stationtrauma_water_room()
		var/total_depth = 0
		var/thermal_total = 0
		var/uniform = TRUE
		for(var/turf/open/member as anything in room)
			var/datum/component/floodwater/water = member.GetComponent(/datum/component/floodwater)
			if(!water || water.depth != depth || water.temperature != temperature)
				uniform = FALSE
			total_depth += water?.depth || 0
			thermal_total += (water?.depth || 0) * (water?.temperature || 0)
		if(uniform || total_depth <= 0)
			if(equalized)
				var/list/state = list(depth, temperature)
				for(var/turf/open/member as anything in room)
					equalized[member] = state
			return
		var/level = total_depth / length(room)
		var/mixed_temperature = thermal_total / total_depth
		var/list/state = list(level, mixed_temperature)
		for(var/turf/open/member as anything in room)
			var/datum/component/floodwater/water = member.GetComponent(/datum/component/floodwater)
			if(!water || water.depth != level || water.temperature != mixed_temperature)
				member.set_water_depth(level, FALSE, mixed_temperature)
			if(equalized)
				equalized[member] = state
		return
	for(var/direction in GLOB.cardinals)
		var/turf/open/next_tile = get_step(tile, direction)
		if(!isopenturf(next_tile) || istype(next_tile, /turf/open/water) || !tile.can_pass_stationtrauma_water(next_tile))
			continue
		var/datum/component/floodwater/next_water = next_tile.GetComponent(/datum/component/floodwater)
		if(next_water?.infinite_source)
			continue
		var/difference = depth - (next_water?.depth || 0)
		if(difference <= FLOOD_WATER_FLOW_EPSILON)
			continue
		var/accepted = next_tile.add_water(min(FLOOD_WATER_OCEAN_FLOW, difference) * FLOOD_WATER_LITRES_PER_CM, temperature)
		if(accepted)
			wake()

/// Collect the connected compartment proportionally, including the final thin layer, without losing water to holder rounding.
/proc/drain_stationtrauma_water_room(turf/open/intake, volume, datum/reagents/receiver, residual_depth = 0, list/room)
	if(!isopenturf(intake) || QDELETED(receiver) || !isnum(volume) || !IS_FINITE(volume) || volume <= 0)
		return 0
	var/datum/component/floodwater/source_water = intake.GetComponent(/datum/component/floodwater)
	if(source_water?.infinite_source)
		return 0
	room ||= intake.stationtrauma_water_room()
	var/available = 0
	var/thermal_total = 0
	for(var/turf/open/tile as anything in room)
		var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
		var/litres = max(0, (water?.depth || 0) - residual_depth) * FLOOD_WATER_LITRES_PER_CM
		available += litres
		thermal_total += litres * (water?.temperature || 0)
	if(available <= 0 || volume <= 0)
		return 0
	var/free_space = receiver.maximum_volume
	for(var/datum/reagent/reagent as anything in receiver.reagent_list)
		free_space -= reagent.volume
	var/amount = min(available, volume, max(0, free_space))
	if(amount <= 0)
		return 0
	var/accepted = receiver.add_reagent(/datum/reagent/water, amount, reagtemp = thermal_total / available, no_react = TRUE)
	if(accepted <= 0)
		return 0
	var/fraction = min(1, accepted / available)
	for(var/turf/open/tile as anything in room)
		var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
		if(!water || water.depth <= residual_depth)
			continue
		if(fraction == 1 && residual_depth == 0)
			if(water.show_puddle && !isspaceturf(tile))
				tile.MakeSlippery(TURF_WET_WATER, 1 MINUTES, 0, 1 MINUTES)
		water.set_depth(max(residual_depth, water.depth - (water.depth - residual_depth) * fraction))
	return accepted
