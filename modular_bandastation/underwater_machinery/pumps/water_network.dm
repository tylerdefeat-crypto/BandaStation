/// Separate water geometry and layer; reuse TG's liquid network splitting instead of mixing water into gas mixtures.
/obj/machinery/duct/stationtrauma
	name = "водяная труба"
	desc = "Труба водяного контура. Ключ — снять, водяной RPD — проложить. Не соединяется с газовыми трубами или химическими duct."
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/water_pipes.dmi'
	icon_state = "pipe_0"
	duct_layer = STATIONTRAUMA_WATER_LAYER
	var/pipe_shape = "smart"
	var/connection_mask = ALL_CARDINALS
	var/water_level = 3
	var/bridges_levels = FALSE

/obj/machinery/duct/stationtrauma/manifold
	name = "межуровневый водяной коллектор"
	desc = "Объединяет соседние водяные линии всех пяти уровней. Занимает все уровни на своей клетке. Ключ — снять."
	bridges_levels = TRUE

/obj/machinery/duct/stationtrauma/straight
	pipe_shape = "straight"

/obj/machinery/duct/stationtrauma/elbow
	pipe_shape = "elbow"

/obj/machinery/duct/stationtrauma/tee
	pipe_shape = "tee"

/obj/machinery/duct/stationtrauma/cross
	pipe_shape = "cross"

/obj/machinery/duct/stationtrauma/Initialize(mapload, new_shape, new_direction, new_level)
	if(new_level in 1 to 5)
		water_level = new_level
	duct_layer = bridges_levels ? (31 << 5) : STATIONTRAUMA_WATER_LAYER_BIT(water_level)
	if(new_shape)
		pipe_shape = new_shape
	if(new_direction)
		dir = new_direction
	switch(pipe_shape)
		if("straight")
			connection_mask = NORTH | SOUTH
		if("elbow")
			connection_mask = NORTH | EAST
		if("tee")
			connection_mask = NORTH | EAST | WEST
		else
			connection_mask = ALL_CARDINALS
	var/rotated_mask = NONE
	for(var/direction in GLOB.cardinals)
		if(connection_mask & direction)
			rotated_mask |= turn(direction, 180 - dir2angle(dir))
	connection_mask = rotated_mask
	return ..(mapload)

/obj/machinery/duct/stationtrauma/proc/accepts(direction)
	return !!(connection_mask & direction)

/obj/machinery/duct/stationtrauma/post_machine_initialize()
	// The native duct pass must not join ends outside this water section's geometry.
	var/water_layer = duct_layer
	duct_layer = NONE
	. = ..()
	duct_layer = water_layer
	rebuild_water_connections()
	pixel_x = (water_level - 3) * 5
	pixel_y = (water_level - 3) * 5

/obj/machinery/duct/stationtrauma/proc/rebuild_water_connections()
	if(!net)
		net = new(src)
	LAZYINITLIST(neighbours)
	for(var/direction in GLOB.cardinals)
		if(!accepts(direction))
			continue
		var/opposite = REVERSE_DIR(direction)
		for(var/atom/movable/neighbor in get_step(src, direction))
			var/obj/machinery/duct/stationtrauma/pipe = neighbor
			if(istype(pipe))
				if(!(pipe.duct_layer & duct_layer) || !pipe.accepts(opposite))
					continue
				if(!pipe.net)
					pipe.net = net
					net.ducts |= pipe
				else if(pipe.net != net)
					var/datum/ductnet/other = pipe.net
					for(var/datum/component/plumbing/component as anything in other.suppliers + other.demanders)
						for(var/key in component.ducts)
							if(component.ducts[key] == other)
								component.ducts[key] = net
						if(component in other.suppliers)
							net.suppliers |= component
						if(component in other.demanders)
							net.demanders |= component
					for(var/obj/machinery/duct/member as anything in other.ducts)
						member.net = net
						net.ducts |= member
					other.suppliers.Cut()
					other.demanders.Cut()
					qdel(other)
				neighbours[pipe] = direction
				LAZYINITLIST(pipe.neighbours)
				pipe.neighbours[src] = opposite
				pipe.update_appearance(UPDATE_ICON)
				continue
			for(var/datum/component/plumbing/stationtrauma_water/component as anything in neighbor.GetComponents(/datum/component/plumbing/stationtrauma_water))
				if(!component.active() || !(component.ducting_layer & duct_layer) || !(opposite & (component.demand_connects | component.supply_connects)))
					continue
				if(component.ducts["[opposite]"] != net)
					net.add_plumber(component, opposite)
				neighbours[neighbor] = direction
	update_appearance(UPDATE_ICON)

/obj/machinery/duct/stationtrauma/update_icon_state()
	. = ..()
	var/mask = connection_mask
	if(pipe_shape == "smart")
		mask = NONE
		for(var/neighbor in neighbours)
			mask |= neighbours[neighbor]
	icon_state = "pipe_[mask]"

/obj/machinery/duct/stationtrauma/examine(mob/user)
	. = list(desc, span_notice("Секция: [pipe_shape], уровень [water_level]. Сеть водяная; газ и химические duct не подключаются."))

/obj/machinery/duct/stationtrauma/on_deconstruction()
	var/obj/item/stationtrauma_water_pipe_fitting/fitting = new(drop_location())
	fitting.pipe_shape = pipe_shape
	fitting.dir = dir
	fitting.water_level = water_level
	fitting.bridges_levels = bridges_levels

/obj/item/stationtrauma_water_pipe_fitting
	name = "секция водяной трубы"
	desc = "Положите на свободную клетку и прикрутите ключом. Alt+ЛКМ — поворот."
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/water_pipes.dmi'
	icon_state = "pipe_15"
	var/pipe_shape = "smart"
	var/water_level = 3
	var/bridges_levels = FALSE

/obj/item/stationtrauma_water_pipe_fitting/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/simple_rotation)

/obj/item/stationtrauma_water_pipe_fitting/examine(mob/user)
	. = ..()
	. += span_notice(bridges_levels ? "Межуровневый коллектор: соединяет все пять уровней." : "Уровень водяной трубы: [water_level].")

/obj/item/stationtrauma_water_pipe_fitting/wrench_act(mob/living/user, obj/item/tool)
	var/turf/tile = get_turf(src)
	if(!isopenturf(tile) || ducting_layer_check(tile, bridges_levels ? (31 << 5) : STATIONTRAUMA_WATER_LAYER_BIT(water_level)))
		balloon_alert(user, "место занято")
		return ITEM_INTERACT_BLOCKING
	var/path = bridges_levels ? /obj/machinery/duct/stationtrauma/manifold : /obj/machinery/duct/stationtrauma
	var/obj/machinery/duct/stationtrauma/pipe = new path(tile, pipe_shape, dir, water_level)
	pipe.rebuild_water_connections()
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/datum/component/plumbing/stationtrauma_water/enable()
	if(demand_connects)
		START_PROCESSING(SSplumbing, src)
	for(var/direction in GLOB.cardinals)
		if(!(direction & (demand_connects | supply_connects)))
			continue
		var/opposite = REVERSE_DIR(direction)
		for(var/atom/movable/neighbor in get_step(parent, direction))
			var/obj/machinery/duct/stationtrauma/pipe = neighbor
			if(istype(pipe))
				if(!(pipe.duct_layer & ducting_layer) || !pipe.accepts(opposite))
					continue
				if(!pipe.net)
					pipe.rebuild_water_connections()
				pipe.neighbours[parent] = opposite
				pipe.net.add_plumber(src, direction)
				pipe.update_appearance(UPDATE_ICON)
				continue
			for(var/datum/component/plumbing/stationtrauma_water/other as anything in neighbor.GetComponents(/datum/component/plumbing/stationtrauma_water))
				if(other.active() && (other.ducting_layer & ducting_layer) && ((other.demand_connects & opposite) && (supply_connects & direction) || (other.supply_connects & opposite) && (demand_connects & direction)))
					if(other.ducts["[opposite]"] == ducts["[direction]"] && ducts["[direction]"])
						continue
					var/datum/ductnet/network = new
					network.add_plumber(src, direction)
					network.add_plumber(other, opposite)

/datum/component/plumbing/stationtrauma_water/create_overlays(atom/movable/source, list/overlays)
	if(tile_covered)
		return
	for(var/direction in GLOB.cardinals)
		if(direction & (supply_connects | demand_connects))
			var/mutable_appearance/branch = mutable_appearance('modular_bandastation/underwater_machinery/pumps/icons/water_pipes.dmi', "pipe_[direction]", PLUMBING_PIPE_VISIBILE_LAYER)
			branch.pixel_x = (stationtrauma_water_level(ducting_layer) - 3) * 5 - source.pixel_x
			branch.pixel_y = (stationtrauma_water_level(ducting_layer) - 3) * 5 - source.pixel_y
			overlays += branch

/// A water-only exchanger for a closed loop; heat goes into the infinite ocean, not into room air.
/datum/component/plumbing/stationtrauma_water/ocean_exchanger/process()
	. = ..()
	var/obj/machinery/stationtrauma_water_device/ocean_exchanger/exchanger = parent
	exchanger.process(SSFLUIDS_DT)

/obj/machinery/stationtrauma_water_device/ocean_exchanger
	name = "водяной теплообменник"
	desc = "Охлаждает проходящую воду соседним океаном до 4 °C. Вход с запада, выход с востока. Замкните контур водяным насосом."
	capacity = 10000
	plumbing_type = /datum/component/plumbing/stationtrauma_water/ocean_exchanger
	icon_state = "filter"

/obj/machinery/stationtrauma_water_device/ocean_exchanger/process(seconds_per_tick)
	if(!anchored || !reagents.get_reagent_amount(/datum/reagent/water))
		return
	for(var/direction in GLOB.cardinals)
		var/turf/open/tile = get_step(src, direction)
		var/datum/component/floodwater/ocean = tile?.GetComponent(/datum/component/floodwater)
		if(ocean?.infinite_source)
			var/heat_capacity = reagents.get_reagent_amount(/datum/reagent/water) * 4184
			if(heat_capacity && reagents.chem_temp > ocean.temperature)
				reagents.set_temperature(max(ocean.temperature, reagents.chem_temp - 150000 * seconds_per_tick / heat_capacity))
			return

/proc/stationtrauma_water_level(layer_bit)
	for(var/level in 1 to 5)
		if(layer_bit == STATIONTRAUMA_WATER_LAYER_BIT(level))
			return level
	return 3

/datum/component/plumbing/stationtrauma_water/Initialize(new_layer)
	for(var/level in 1 to 5)
		if(new_layer == STATIONTRAUMA_WATER_LAYER_BIT(level))
			ducting_layer = new_layer
	return ..()
