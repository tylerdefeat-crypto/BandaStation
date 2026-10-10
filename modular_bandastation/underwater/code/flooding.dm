SUBSYSTEM_DEF(floodwater)
	name = "Floodwater"
	wait = 1 SECONDS
	priority = FIRE_PRIORITY_DEFAULT
	ss_flags = SS_NO_INIT | SS_BACKGROUND
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	var/list/active = list()
	var/list/currentrun = list()
	var/list/depths = list()

/datum/controller/subsystem/floodwater/fire(resumed = FALSE)
	if(!resumed)
		currentrun = active.Copy()
		active = list()
		depths = list()
		for(var/datum/component/floodwater/water as anything in currentrun)
			if(QDELETED(water))
				continue
			var/turf/open/tile = water.parent
			depths[tile] = water.depth
			for(var/direction in GLOB.cardinals)
				var/turf/open/neighbor = get_step(tile, direction)
				if(isopenturf(neighbor))
					depths[neighbor] = neighbor.get_water_depth()
	while(length(currentrun))
		var/datum/component/floodwater/water = currentrun[length(currentrun)]
		currentrun.len--
		if(!QDELETED(water))
			water.spread(depths)
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

/datum/component/floodwater/proc/spread(list/depths)
	var/turf/open/tile = parent
	var/source_depth = isnull(depths?[tile]) ? depth : depths[tile]
	for(var/direction in GLOB.cardinals)
		var/turf/open/next_tile = get_step(tile, direction)
		if(!isopenturf(next_tile) || istype(next_tile, /turf/open/water) || !tile.can_pass_stationtrauma_water(next_tile))
			continue
		var/datum/component/floodwater/next_water = next_tile.GetComponent(/datum/component/floodwater)
		if(next_water?.infinite_source)
			continue
		var/next_depth = isnull(depths?[next_tile]) ? (next_water?.depth || 0) : depths[next_tile]
		var/difference = source_depth - next_depth
		if(difference <= (infinite_source ? FLOOD_WATER_FLOW_EPSILON : 0))
			continue
		// A snapshot prevents newly arrived water crossing another tile in this same tick.
		var/flow = infinite_source ? min(FLOOD_WATER_OCEAN_FLOW, difference) : min(25, difference / 4, depth)
		var/accepted = next_tile.add_water(flow * FLOOD_WATER_LITRES_PER_CM, temperature)
		if(accepted)
			if(infinite_source)
				wake()
			else
				remove_water(accepted)
				if(QDELETED(src))
					return

/turf/open/proc/stationtrauma_water_intake()
	var/list/intake = list(src)
	for(var/direction in GLOB.cardinals)
		var/turf/open/neighbor = get_step(src, direction)
		if(isopenturf(neighbor) && can_pass_stationtrauma_water(neighbor))
			var/datum/component/floodwater/water = neighbor.GetComponent(/datum/component/floodwater)
			if(water && !water.infinite_source)
				intake += neighbor
	return intake

/// Collect the local intake proportionally without losing fractional water to holder rounding.
/proc/drain_stationtrauma_water_room(turf/open/intake, volume, datum/reagents/receiver, residual_depth = 0, list/room)
	if(!isopenturf(intake) || QDELETED(receiver) || !isnum(volume) || !IS_FINITE(volume) || volume <= 0)
		return 0
	var/datum/component/floodwater/source_water = intake.GetComponent(/datum/component/floodwater)
	if(source_water?.infinite_source)
		return 0
	room ||= intake.stationtrauma_water_intake()
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
	var/stored_before = receiver.get_reagent_amount(/datum/reagent/water)
	var/heat_before = receiver.heat_capacity()
	var/temperature_before = receiver.chem_temp
	var/mixed_temperature = thermal_total / available
	var/accepted = receiver.add_reagent(/datum/reagent/water, amount, reagtemp = mixed_temperature, no_react = TRUE)
	var/datum/reagent/water/collected = receiver.has_reagent(/datum/reagent/water)
	if(collected && (accepted > 0 || amount < CHEMICAL_QUANTISATION_LEVEL))
		// Keep the real floor volume when TG rounds the addition, including a final tiny tail.
		collected.volume = stored_before + amount
		receiver.set_temperature((heat_before * temperature_before + collected.specific_heat * amount * mixed_temperature) / receiver.heat_capacity())
		accepted = amount
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
