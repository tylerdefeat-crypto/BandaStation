#define LIQUID_TEST(assertion, reason) if(!(assertion)) { return Fail(reason, __FILE__, __LINE__) }

/datum/unit_test/stationtrauma_water_pipes
	var/list/wet_tiles = list()

/datum/unit_test/stationtrauma_water_pipes/Destroy()
	for(var/obj/machinery/machine in allocated)
		machine.reagents?.clear_reagents()
	for(var/turf/open/tile as anything in wet_tiles)
		tile.set_water_depth(0)
	return ..()

/datum/unit_test/stationtrauma_water_pipes/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	wet_tiles += floor
	floor.set_water_depth(20, FALSE, T0C + 4)
	LIQUID_TEST(floor.add_water(200, T0C + 40) == 200, "The floor must accept a measured warm-water volume")
	var/datum/component/floodwater/water = floor.GetComponent(/datum/component/floodwater)
	LIQUID_TEST(water.depth == 40 && abs(water.temperature - (T0C + 22)) < 0.01, "Equal cold and warm volumes must conserve volume and mix to 22 C")
	var/datum/reagents/receiver = allocate(/datum/reagents, 200, NO_REACT)
	receiver.add_reagent(/datum/reagent/water, 100, reagtemp = T0C + 40)
	LIQUID_TEST(water.remove_water(300, receiver) == 100, "A full receiver must limit intake without deleting the remainder")
	LIQUID_TEST(water.depth == 30 && abs(receiver.chem_temp - (T0C + 31)) < 0.01, "The TG holder must mix temperatures and the floor must retain the exact remainder")
	LIQUID_TEST(water.remove_water(1, receiver) == 0 && water.depth == 30, "A full buffer must stop extraction")
	floor.set_water_depth(219, FALSE, T0C + 4)
	LIQUID_TEST(floor.receive_water(receiver, 100) == 10, "The ceiling must limit a pipe discharge to the ten available litres")
	LIQUID_TEST(receiver.total_volume == 190 && floor.get_water_depth() == 220, "Rejected overflow must remain in its holder")
	LIQUID_TEST(floor.receive_water(receiver, 100) == 0 && receiver.total_volume == 190, "A saturated floor must not delete stored water")
	floor.set_water_depth(220, TRUE, T0C + 4)
	water = floor.GetComponent(/datum/component/floodwater)
	LIQUID_TEST(water.remove_water(100) == 0 && water.depth == 220, "The shared pump API must protect infinite ocean water")
	LIQUID_TEST(drain_stationtrauma_water_room(floor, 100, receiver) == 0 && water.depth == 220, "Room collection must also protect the infinite ocean")
	floor.set_water_depth(0)
	var/datum/reagents/precise_source = allocate(/datum/reagents, 200, NO_REACT)
	var/datum/reagents/precise_target = allocate(/datum/reagents, 200, NO_REACT)
	precise_source.add_reagent(/datum/reagent/water, 1.0149, reagtemp = T0C + 35)
	var/precise_volume = precise_source.get_reagent_amount(/datum/reagent/water)
	LIQUID_TEST(abs(transfer_stationtrauma_water(precise_source, precise_target, 200) - precise_volume) < 0.0001 && precise_source.total_volume == 0, "A water transfer must use actual reagent volume instead of TG's rounded holder total")
	precise_source.add_reagent(/datum/reagent/water, 0.0149, reagtemp = T0C + 35)
	precise_target.clear_reagents()
	precise_target.add_reagent(/datum/reagent/water, 199.99, reagtemp = T0C + 4)
	var/precise_total = precise_source.get_reagent_amount(/datum/reagent/water) + precise_target.get_reagent_amount(/datum/reagent/water)
	transfer_stationtrauma_water(precise_source, precise_target, 200)
	LIQUID_TEST(precise_source.get_reagent_amount(/datum/reagent/water) >= CHEMICAL_VOLUME_ROUNDING, "A nearly full receiver must leave a recoverable tail instead of TG deleting it")
	LIQUID_TEST(abs(precise_source.get_reagent_amount(/datum/reagent/water) + precise_target.get_reagent_amount(/datum/reagent/water) - precise_total) < 0.0001, "Partial water transfer must conserve the source tail and receiver charge")

	var/turf/open/adjacent = get_step(floor, EAST)
	wet_tiles += adjacent
	for(var/turf/open/tile as anything in list(floor, adjacent))
		for(var/direction in GLOB.cardinals)
			var/turf/neighbor = get_step(tile, direction)
			if(neighbor != floor && neighbor != adjacent && isopenturf(neighbor))
				allocate(/obj/structure/window/reinforced/fulltile, neighbor)
	floor.immediate_calculate_adjacent_turfs()
	floor.set_water_depth(100, FALSE, T0C + 40)
	adjacent.set_water_depth(20, FALSE, T0C + 4)
	water = floor.GetComponent(/datum/component/floodwater)
	var/list/pass = list()
	water.spread(pass)
	var/datum/component/floodwater/mixture = adjacent.GetComponent(/datum/component/floodwater)
	LIQUID_TEST(floor.get_water_depth() == 60 && adjacent.get_water_depth() == 60 && abs(mixture.temperature - (T0C + 34)) < 0.01, "Natural flooding must preserve volume and carry its temperature")
	adjacent.add_water(20, T0C + 34)
	mixture.spread(pass)
	LIQUID_TEST(floor.get_water_depth() == 61 && adjacent.get_water_depth() == 61, "A later inflow during the same subsystem pass must invalidate the previous equalization")
	floor.set_water_depth(0)
	adjacent.set_water_depth(0)

	var/datum/map_template/template = allocate(/datum/map_template, "modular_bandastation/underwater/maps/stationtrauma_test.dmm")
	var/turf/origin = locate(70, 35, floor.z)
	initialize_stationtrauma_test_boundary(template, origin)
	LIQUID_TEST(template.load(origin), "The pipeline fixture must load in a room large enough for its real ducts")
	var/turf/open/intake = locate(origin.x + 7, origin.y + 10, origin.z)
	var/turf/open/reservoir_floor = locate(intake.x + 2, intake.y, intake.z)
	var/turf/open/valve_floor = locate(intake.x + 4, intake.y, intake.z)
	var/turf/open/outlet_floor = locate(intake.x + 6, intake.y, intake.z)
	wet_tiles += list(intake, outlet_floor)
	var/obj/machinery/bilge_pump/plumbed/pump = allocate(/obj/machinery/bilge_pump/plumbed, intake)
	pump.drain_rate = 20
	pump.reagents.maximum_volume = 200
	pump.setDir(EAST)
	pump.on = TRUE
	pump.set_machine_stat(pump.machine_stat & ~NOPOWER)
	var/obj/machinery/stationtrauma_water_device/reservoir = allocate(/obj/machinery/stationtrauma_water_device, reservoir_floor)
	var/obj/machinery/stationtrauma_water_device/valve/valve = allocate(/obj/machinery/stationtrauma_water_device/valve, valve_floor)
	var/obj/machinery/stationtrauma_water_device/outlet/outlet = allocate(/obj/machinery/stationtrauma_water_device/outlet, outlet_floor)
	var/list/ducts = list()
	for(var/offset in list(1, 3, 5))
		var/obj/machinery/duct/duct = allocate(/obj/machinery/duct/stationtrauma, locate(intake.x + offset, intake.y, intake.z))
		if(!duct.net)
			duct.post_machine_initialize()
		ducts += duct
	var/list/tank_connections = reservoir.GetComponents(/datum/component/plumbing/stationtrauma_water)
	var/list/valve_connections = valve.GetComponents(/datum/component/plumbing/stationtrauma_water)
	var/list/outlet_connections = outlet.GetComponents(/datum/component/plumbing/stationtrauma_water/outlet)
	LIQUID_TEST(length(tank_connections) == 1 && length(valve_connections) == 1 && length(outlet_connections) == 1, "Each water fixture must have exactly one active plumbing component")
	var/datum/component/plumbing/stationtrauma_water/tank_connection = tank_connections[1]
	var/datum/component/plumbing/stationtrauma_water/valve_connection = valve_connections[1]
	var/datum/component/plumbing/stationtrauma_water/outlet/outlet_connection = outlet_connections[1]
	LIQUID_TEST(tank_connection.ducts["8"] && valve_connection.ducts["8"] && outlet_connection.ducts["8"], "Physical TG ducts must connect the intake, tank, valve and outlet")
	intake.set_water_depth(100, FALSE, T0C + 4)
	pump.process(1)
	LIQUID_TEST(pump.reagents.total_volume == 200 && intake.get_water_depth() == 80, "A plumbed bilge must collect water instead of deleting it")
	pump.process(1)
	LIQUID_TEST(intake.get_water_depth() == 80, "A blocked pipeline must back up and stop a full bilge buffer")
	reservoir.reagents.add_reagent(/datum/reagent/water, 100, reagtemp = T0C + 40)
	tank_connection.process()
	LIQUID_TEST(reservoir.reagents.total_volume == 300 && pump.reagents.total_volume == 0 && abs(reservoir.reagents.chem_temp - (T0C + 16)) < 0.01, "The real duct network must transfer and mix cold intake with warm stored water")
	valve_connection.process()
	LIQUID_TEST(valve.reagents.total_volume == 0 && reservoir.reagents.total_volume == 300, "A closed valve must stop incoming flow")
	valve.valve_open = TRUE
	valve_connection.process()
	valve_connection.process()
	LIQUID_TEST(valve.reagents.total_volume == 300, "An open valve must admit stored water through the connected pipe")
	valve.valve_open = FALSE
	outlet_connection.process()
	LIQUID_TEST(outlet.reagents.total_volume == 0 && valve.reagents.total_volume == 300, "Closing a charged valve must also stop its outgoing flow")
	valve.valve_open = TRUE
	outlet_connection.process()
	LIQUID_TEST(outlet.reagents.total_volume == 200 && valve.reagents.total_volume == 100, "Downstream capacity must leave excess water in the valve buffer")
	outlet.on = TRUE
	outlet.set_machine_stat(outlet.machine_stat | NOPOWER)
	outlet.process(1)
	LIQUID_TEST(outlet_floor.get_water_depth() == 0 && outlet.reagents.total_volume == 200, "Power loss must stop discharge without deleting its water")
	outlet.set_machine_stat(outlet.machine_stat & ~NOPOWER)
	outlet.process(1)
	var/datum/component/floodwater/discharged = outlet_floor.GetComponent(/datum/component/floodwater)
	LIQUID_TEST(discharged && discharged.depth == 10 && abs(discharged.temperature - (T0C + 16)) < 0.01, "A powered outlet must put the same measured warm water onto the floor")
	LIQUID_TEST(intake.get_water_depth() * 10 + pump.reagents.total_volume + reservoir.reagents.total_volume + valve.reagents.total_volume + outlet.reagents.total_volume + outlet_floor.get_water_depth() * 10 == 1100, "Floor-to-pipe-to-floor circulation must conserve the complete finite volume")
	qdel(ducts[1])
	pump.process(1)
	var/stored_before = reservoir.reagents.total_volume
	tank_connection.process()
	LIQUID_TEST(reservoir.reagents.total_volume == stored_before && pump.reagents.total_volume == 200, "Breaking a real duct must stop transfer and retain the collected water")

	intake.set_water_depth(0)
	outlet_floor.set_water_depth(0)
	var/turf/open/portable_floor = get_step(intake, NORTH)
	wet_tiles += portable_floor
	var/obj/machinery/bilge_pump/portable/plumbed/portable = allocate(/obj/machinery/bilge_pump/portable/plumbed, portable_floor)
	portable.set_anchored(TRUE)
	portable.on = TRUE
	portable_floor.set_water_depth(20, FALSE, T0C + 35)
	var/charge_before = portable.cell.charge
	portable.process(1)
	LIQUID_TEST(portable.reagents.total_volume == 80 && portable_floor.get_water_depth() == 12 && portable.cell.charge < charge_before, "The portable plumbed pump must use the same volume API and real battery")
	LIQUID_TEST(abs(portable.reagents.chem_temp - (T0C + 35)) < 0.01, "Portable collection must retain the intake temperature")
	portable.cell.charge = 0
	portable.process(1)
	LIQUID_TEST(portable_floor.get_water_depth() == 12 && portable.reagents.total_volume == 80, "An empty portable battery must stop collection without losing stored water")

/datum/unit_test/stationtrauma_room_drain
	var/list/wet_tiles = list()

/datum/unit_test/stationtrauma_room_drain/Destroy()
	for(var/obj/machinery/machine in allocated)
		machine.reagents?.clear_reagents()
	for(var/turf/open/tile as anything in wet_tiles)
		tile.set_water_depth(0)
	return ..()

/datum/unit_test/stationtrauma_room_drain/proc/stored_volume(list/row, obj/machinery/bilge_pump/pump, obj/machinery/stationtrauma_water_device/tank)
	. = tank.reagents.get_reagent_amount(/datum/reagent/water) + pump.reagents.get_reagent_amount(/datum/reagent/water)
	for(var/turf/open/tile as anything in row)
		. += tile.get_water_depth() * FLOOD_WATER_LITRES_PER_CM

/datum/unit_test/stationtrauma_room_drain/Run()
	var/turf/open/intake = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/list/row = list()
	var/list/sealed = list()
	for(var/offset in 0 to 3)
		var/turf/open/tile = locate(intake.x + offset, intake.y, intake.z)
		row += tile
		wet_tiles += tile
	for(var/turf/open/tile as anything in row)
		for(var/direction in GLOB.cardinals)
			var/turf/neighbor = get_step(tile, direction)
			if(!isopenturf(neighbor) || (neighbor in row) || (neighbor in sealed))
				continue
			allocate(/obj/structure/window/reinforced/fulltile, neighbor)
			sealed += neighbor
			tile.immediate_calculate_adjacent_turfs()
	var/turf/open/tank_floor = get_step(intake, WEST)
	wet_tiles += tank_floor
	var/obj/machinery/bilge_pump/pump = allocate(/obj/machinery/bilge_pump, intake)
	pump.setDir(WEST)
	pump.residual_depth = 0.5
	pump.on = TRUE
	pump.set_machine_stat(pump.machine_stat & ~NOPOWER)
	var/obj/machinery/stationtrauma_water_device/tank = allocate(/obj/machinery/stationtrauma_water_device, tank_floor)
	tank.set_anchored(FALSE)
	tank.setDir(NORTH)
	tank.set_anchored(TRUE)
	var/list/connections = tank.GetComponents(/datum/component/plumbing/stationtrauma_water)
	var/datum/component/plumbing/stationtrauma_water/connection = connections[1]
	LIQUID_TEST(connection.ducts["4"], "The collection tank must connect to the real pump's west-facing output")
	var/obj/machinery/door/airlock/highsecurity/underwater/barrier = allocate(/obj/machinery/door/airlock/highsecurity/underwater, row[3])
	barrier.autoclose = FALSE
	for(var/turf/open/tile as anything in row)
		tile.immediate_calculate_adjacent_turfs()
		tile.set_water_depth(10, FALSE, T0C + 35)
	for(var/cycle in 1 to 150)
		for(var/turf/open/tile as anything in row)
			var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
			water?.spread()
		LIQUID_TEST(abs(stored_volume(row, pump, tank) - 400) < 0.001, "Volume after closed-room flow at cycle [cycle]: [stored_volume(row, pump, tank)]")
		pump.process(1)
		LIQUID_TEST(abs(stored_volume(row, pump, tank) - 400) < 0.001, "Volume after closed-room pump at cycle [cycle]: [stored_volume(row, pump, tank)]")
		connection.process()
		LIQUID_TEST(abs(stored_volume(row, pump, tank) - 400) < 0.001, "Volume after closed-room pipe at cycle [cycle]: [stored_volume(row, pump, tank)]")
	var/turf/open/nearby = row[2]
	var/turf/open/isolated = row[4]
	LIQUID_TEST(abs(intake.get_water_depth() - 0.5) < 0.001 && nearby.get_water_depth() <= 0.53, "A single intake must drain its connected room to the residual layer: intake=[intake.get_water_depth()], nearby=[nearby.get_water_depth()]")
	LIQUID_TEST(isolated.get_water_depth() == 10, "A closed underwater airlock must isolate the other room from the pump")
	LIQUID_TEST(barrier.open(BYPASS_DOOR_CHECKS), "The unlocked underwater test door must open")
	for(var/turf/open/tile as anything in row)
		tile.immediate_calculate_adjacent_turfs()
	for(var/cycle in 1 to 150)
		for(var/turf/open/tile as anything in row)
			var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
			water?.spread()
		LIQUID_TEST(abs(stored_volume(row, pump, tank) - 400) < 0.001, "Volume after open-room flow at cycle [cycle]: [stored_volume(row, pump, tank)]")
		pump.process(1)
		LIQUID_TEST(abs(stored_volume(row, pump, tank) - 400) < 0.001, "Volume after open-room pump at cycle [cycle]: [stored_volume(row, pump, tank)]")
		connection.process()
		LIQUID_TEST(abs(stored_volume(row, pump, tank) - 400) < 0.001, "Volume after open-room pipe at cycle [cycle]: [stored_volume(row, pump, tank)]")
	var/remaining = 0
	for(var/turf/open/tile as anything in row)
		LIQUID_TEST(tile.get_water_depth() >= 0.49 && tile.get_water_depth() <= 0.54, "Opening the door must allow the whole connected corridor to drain")
		remaining += tile.get_water_depth() * FLOOD_WATER_LITRES_PER_CM
	LIQUID_TEST(abs(stored_volume(row, pump, tank) - 400) < 0.01, "Connected drainage must preserve 400 litres: floor=[remaining], tank=[tank.reagents.get_reagent_amount(/datum/reagent/water)], pump=[pump.reagents.get_reagent_amount(/datum/reagent/water)]")
	LIQUID_TEST(abs(tank.reagents.chem_temp - (T0C + 35)) < 0.01, "Room collection must preserve the water's temperature")

	pump.on = FALSE
	qdel(pump)
	var/obj/machinery/bilge_pump/portable/portable = allocate(/obj/machinery/bilge_pump/portable, intake)
	portable.set_anchored(TRUE)
	portable.on = TRUE
	for(var/cycle in 1 to 150)
		for(var/turf/open/tile as anything in row)
			var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
			water?.spread()
		portable.process(1)
	var/residual = 0
	for(var/turf/open/tile as anything in row)
		LIQUID_TEST(tile.get_water_depth() < 0.05, "The portable pump must collect residual puddles through actual inflow")
		residual += tile.get_water_depth() * FLOOD_WATER_LITRES_PER_CM
	LIQUID_TEST(abs(portable.reagents.get_reagent_amount(/datum/reagent/water) + residual - remaining) < 0.01, "Residual collection must retain the same measured volume")
	var/stored = portable.reagents.get_reagent_amount(/datum/reagent/water)
	LIQUID_TEST(drain_stationtrauma_water(portable, isolated) == 0 && portable.reagents.get_reagent_amount(/datum/reagent/water) == stored, "Manual discharge must reject a remote floor")
	nearby.set_water_depth(219, FALSE, T0C + 4)
	LIQUID_TEST(drain_stationtrauma_water(portable, nearby) == 10, "Manual discharge must respect available floor capacity")
	LIQUID_TEST(abs(portable.reagents.get_reagent_amount(/datum/reagent/water) - (stored - 10)) < 0.01 && nearby.get_water_depth() == 220, "Overflow must stay in the portable tank")
	portable.forceMove(nearby)
	LIQUID_TEST(barrier.close(BYPASS_DOOR_CHECKS), "The test door must close for discharge isolation")
	LIQUID_TEST(drain_stationtrauma_water(portable, row[3]) == 0, "Manual discharge must not cross a closed door")
	LIQUID_TEST(barrier.open(BYPASS_DOOR_CHECKS), "The test door must reopen for normal discharge")
	var/turf/open/discharge = row[3]
	discharge.set_water_depth(0)
	var/returned = portable.reagents.get_reagent_amount(/datum/reagent/water)
	LIQUID_TEST(abs(drain_stationtrauma_water(portable, discharge) - returned) < 0.01 && portable.reagents.total_volume == 0, "An accessible floor must receive the exact remaining portable charge")
	var/datum/component/floodwater/returned_water = discharge.GetComponent(/datum/component/floodwater)
	LIQUID_TEST(returned_water && abs(returned_water.temperature - (T0C + 35)) < 0.01, "Manual discharge must retain the stored temperature")

	tank_floor.set_water_depth(220, FALSE, T0C + 4)
	tank.reagents.clear_reagents()
	tank.reagents.add_reagent(/datum/reagent/water, 1000, reagtemp = T0C + 35)
	qdel(tank)
	var/obj/item/stationtrauma_water_canister/remainder = locate() in tank_floor
	LIQUID_TEST(remainder && abs(remainder.reagents.total_volume - 1000) < 0.01, "Destroying a charged tank above a full isolated floor must retain its entire charge in recoverable debris")
	tank_floor.set_water_depth(0)
	LIQUID_TEST(drain_stationtrauma_water(remainder, tank_floor) == 1000 && remainder.reagents.total_volume == 0, "Recoverable debris must return its stored water to the world")


	for(var/turf/open/tile as anything in row)
		tile.set_water_depth(0)
	var/obj/machinery/bilge_pump/complete = allocate(/obj/machinery/bilge_pump, intake)
	complete.on = TRUE
	complete.set_machine_stat(complete.machine_stat & ~NOPOWER)
	isolated.set_water_depth(12.34567, FALSE, T0C + 35)
	LIQUID_TEST(complete.residual_depth == 0, "Stationary drainage must default to zero residual depth")
	complete.process(1)
	for(var/turf/open/tile as anything in row)
		LIQUID_TEST(tile.get_water_depth() == 0, "A dry intake must collect the entire connected compartment, including fractional tails")
	LIQUID_TEST(abs(complete.reagents.get_reagent_amount(/datum/reagent/water) - 123.4567) < 0.0001, "Complete room drainage must preserve its fractional volume")
	LIQUID_TEST(barrier.close(BYPASS_DOOR_CHECKS), "The wet door must close for a stranded-door regression")
	var/turf/open/door_floor = row[3]
	door_floor.set_water_depth(220)
	isolated.set_water_depth(10)
	for(var/cycle in 1 to 5)
		var/datum/component/floodwater/stranded = door_floor.GetComponent(/datum/component/floodwater)
		stranded.spread()
		complete.process(1)
	LIQUID_TEST(intake.get_water_depth() == 0 && nearby.get_water_depth() == 0 && door_floor.get_water_depth() == 220 && isolated.get_water_depth() == 10, "Water trapped under a closed door must never refill the dried compartment")

/datum/unit_test/stationtrauma_water_controls
	var/list/wet_tiles = list()

/datum/unit_test/stationtrauma_water_controls/Destroy()
	for(var/obj/machinery/machine in allocated)
		machine.reagents?.clear_reagents()
	for(var/turf/open/tile as anything in wet_tiles)
		tile.set_water_depth(0)
	return ..()

/datum/unit_test/stationtrauma_water_controls/Run()
	var/turf/open/base = run_loc_floor_bottom_left
	var/obj/item/pipe_dispenser/stationtrauma/rpd = allocate(/obj/item/pipe_dispenser/stationtrauma, base)
	var/obj/machinery/stationtrauma_water_device/connector/port = rpd.build_water_fixture(base, rpd.water_recipes.Find("Порт бочки"), SOUTH)
	var/obj/machinery/stationtrauma_water_device/barrel/barrel = rpd.build_water_fixture(base, rpd.water_recipes.Find("Бочка 1000 л"), EAST)
	LIQUID_TEST(port && barrel && barrel.connect_port(), "RPD must build a same-tile port and barrel that connect without barrel orientation")
	allocated += list(port, barrel)
	barrel.reagents.add_reagent(/datum/reagent/water, 500, reagtemp = T0C + 40)
	var/obj/machinery/stationtrauma_water_device/inline_pump/inline = rpd.build_water_fixture(get_step(base, EAST), rpd.water_recipes.Find("Трубный насос"), SOUTH)
	var/obj/machinery/stationtrauma_water_device/outlet/overboard/outlet = rpd.build_water_fixture(get_step(get_step(base, EAST), EAST), rpd.water_recipes.Find("Забортный выпуск"), SOUTH)
	LIQUID_TEST(inline && outlet, "RPD must build the directed pump and overboard outlet")
	allocated += list(inline, outlet)
	var/datum/component/plumbing/stationtrauma_water/inline_pump/pump_connection = inline.GetComponent(/datum/component/plumbing/stationtrauma_water/inline_pump)
	var/datum/component/plumbing/stationtrauma_water/outlet/outlet_connection = outlet.GetComponent(/datum/component/plumbing/stationtrauma_water/outlet)
	inline.on = TRUE
	inline.flow_rate = 100
	inline.set_machine_stat(inline.machine_stat & ~NOPOWER)
	pump_connection.process()
	LIQUID_TEST(barrel.reagents.total_volume == 500 && inline.reagents.total_volume == 0, "A closed barrel valve must retain its entire charge")
	barrel.valve_open = TRUE
	inline.on = FALSE
	pump_connection.process()
	LIQUID_TEST(inline.reagents.total_volume == 0, "A switched-off inline pump must not draw from the barrel")
	inline.on = TRUE
	pump_connection.process()
	LIQUID_TEST(inline.reagents.total_volume == 100 * SSFLUIDS_DT, "Inline flow must obey its selected litres-per-second rate")
	outlet_connection.process()
	outlet.on = TRUE
	outlet.set_machine_stat(outlet.machine_stat & ~NOPOWER)
	var/buffered = outlet.reagents.total_volume
	outlet.process(1)
	LIQUID_TEST(buffered > 0 && outlet.reagents.total_volume == buffered && outlet.discharged_volume == 0, "An overboard outlet must retain water when no adjacent ocean exists")
	var/turf/open/ocean = get_step(outlet, EAST)
	wet_tiles += ocean
	ocean.set_water_depth(220, TRUE, T0C + 4)
	outlet.set_machine_stat(outlet.machine_stat | NOPOWER)
	outlet.process(1)
	LIQUID_TEST(outlet.reagents.total_volume == buffered, "Unpowered discharge against the ocean must stop")
	outlet.set_machine_stat(outlet.machine_stat & ~NOPOWER)
	outlet.process(1)
	LIQUID_TEST(outlet.reagents.total_volume == 0 && outlet.discharged_volume == buffered && barrel.reagents.total_volume + buffered == 500, "Powered ocean discharge must account for every litre removed from the finite circuit")
	barrel.disconnect_port()
	LIQUID_TEST(!barrel.anchored && !port.barrel && barrel.reagents.total_volume == 500 - buffered, "Disconnecting a barrel must retain its stored charge")

	var/turf/open/first_floor = locate(base.x + 1, base.y + 2, base.z)
	var/turf/open/second_floor = get_step(first_floor, EAST)
	var/obj/machinery/duct/stationtrauma/first_pipe = rpd.build_water_fixture(first_floor, rpd.water_recipes.Find("Водяная мультитруба"), SOUTH)
	var/obj/machinery/duct/stationtrauma/second_pipe = rpd.build_water_fixture(second_floor, rpd.water_recipes.Find("Водяная мультитруба"), EAST)
	LIQUID_TEST(first_pipe && second_pipe && first_pipe.net == second_pipe.net, "Smart water sections must connect automatically regardless of selected orientation")
	allocated += list(first_pipe, second_pipe)
	var/obj/machinery/duct/chemical = allocate(/obj/machinery/duct, get_step(second_floor, SOUTH))
	LIQUID_TEST(!(chemical in second_pipe.neighbours), "Water pipes must not connect to ordinary chemical ducts")
	LIQUID_TEST(!rpd.build_water_fixture(second_floor, 1, SOUTH), "RPD must reject overlapping water sections")

	var/turf/open/intake = locate(base.x + 3, base.y + 3, base.z)
	wet_tiles += intake
	var/obj/machinery/bilge_pump/bilge = allocate(/obj/machinery/bilge_pump, intake)
	var/obj/machinery/stationtrauma_pump_controller/controller = allocate(/obj/machinery/stationtrauma_pump_controller, get_step(intake, WEST))
	controller.on = TRUE
	controller.flow_rate = 1000
	controller.apply_settings()
	intake.set_water_depth(220)
	bilge.set_machine_stat(bilge.machine_stat & ~NOPOWER)
	bilge.process(2)
	LIQUID_TEST(intake.get_water_depth() == 20 && bilge.reagents.total_volume == 2000, "The controller's 1000 L/s setting must work at the real two-second machinery interval")
	controller.on = FALSE
	controller.apply_settings()
	bilge.process(2)
	LIQUID_TEST(intake.get_water_depth() == 20 && !bilge.on, "The controller must switch its stationary group off")
	LIQUID_TEST(isnull(stationtrauma_parse_flow("nonsense")) && stationtrauma_parse_flow(-20) == 0 && stationtrauma_parse_flow("max") == 5000, "Flow input must reject invalid values and enforce the supported range")
	var/datum/component/floodwater/water = intake.GetComponent(/datum/component/floodwater)
	water.show_puddle = TRUE
	intake.set_water_depth(0.5)
	LIQUID_TEST(water.stage == 0 && water.water_overlay?.icon_state == "wet_floor_static", "A residual puddle must replace the full flood overlay")
	water.show_puddle = FALSE
	intake.set_water_depth(1)
	intake.set_water_depth(0.5)
	LIQUID_TEST(!water.water_overlay && intake.get_water_depth() == 0.5, "A visually dry residual cell must still retain its measured water")
	water.show_puddle = TRUE
	water.remove_water(5)
	LIQUID_TEST(intake.get_water_depth() == 0 && intake.GetComponent(/datum/component/wet_floor), "Complete drainage must leave occasional native wet-floor puddles without retaining a flood overlay")

	var/turf/open/exchanger_floor = locate(base.x + 1, base.y + 4, base.z)
	var/turf/open/cold_ocean = get_step(exchanger_floor, WEST)
	wet_tiles += cold_ocean
	cold_ocean.set_water_depth(220, TRUE, T0C + 4)
	var/obj/machinery/stationtrauma_water_device/ocean_exchanger/exchanger = allocate(/obj/machinery/stationtrauma_water_device/ocean_exchanger, exchanger_floor)
	exchanger.reagents.add_reagent(/datum/reagent/water, 1000, reagtemp = T0C + 40)
	exchanger.process(1)
	LIQUID_TEST(exchanger.reagents.total_volume == 1000 && exchanger.reagents.chem_temp < T0C + 40 && exchanger.reagents.chem_temp >= T0C + 4, "A water-loop exchanger must reject heat without deleting its finite charge")


/datum/unit_test/stationtrauma_multilayer_pipes/Run()
	var/turf/open/base = run_loc_floor_bottom_left
	var/turf/open/center = locate(base.x + 2, base.y + 1, base.z)
	var/obj/item/pipe_dispenser/stationtrauma/rpd = allocate(/obj/item/pipe_dispenser/stationtrauma, base)
	var/list/stacked = rpd.dispense_water_selection(center, 1, SOUTH, list(1, 2, 3, 4, 5))
	allocated += stacked
	LIQUID_TEST(length(stacked) == 5, "A multilayer RPD click must build five independent overlapping water sections")
	for(var/obj/machinery/duct/stationtrauma/pipe as anything in stacked)
		LIQUID_TEST(pipe.duct_layer == STATIONTRAUMA_WATER_LAYER_BIT(pipe.water_level) && pipe.pixel_x == (pipe.water_level - 3) * 5, "Each water level must have its own network bit and native-style offset")
		for(var/obj/machinery/duct/stationtrauma/other as anything in stacked)
			LIQUID_TEST(pipe == other || pipe.net != other.net, "Overlapping levels must never mix their networks implicitly")
	var/obj/machinery/duct/stationtrauma/middle = stacked[3]
	var/list/arms = list()
	for(var/direction in list(NORTH, EAST, WEST, SOUTH))
		var/obj/machinery/duct/stationtrauma/arm = rpd.build_water_fixture(get_step(center, direction), 1, SOUTH, 3)
		allocated += arm
		arms += arm
		LIQUID_TEST(arm && arm.net == middle.net, "Every smart branch must join without rotating the pipe")
		if(length(arms) == 2)
			LIQUID_TEST(middle.icon_state == "pipe_5", "Two adjacent branches must automatically draw an elbow: state=[middle.icon_state], neighbors=[length(middle.neighbours)], shape=[middle.pipe_shape]")
		if(length(arms) == 3)
			LIQUID_TEST(middle.icon_state == "pipe_13", "A third branch must automatically draw a tee")
	middle.rebuild_water_connections()
	middle.rebuild_water_connections()
	LIQUID_TEST(middle.icon_state == "pipe_15", "Repeated connection rebuilds must preserve the cross directions")
	LIQUID_TEST(middle.icon_state == "pipe_15", "Four branches must automatically draw a cross")
	middle.on_deconstruction()
	qdel(middle)
	var/obj/item/stationtrauma_water_pipe_fitting/removed = locate() in center
	LIQUID_TEST(removed && removed.water_level == 3 && removed.pipe_shape == "smart", "Unwrenching must preserve the selected water level in the loose section")
	for(var/obj/machinery/duct/stationtrauma/arm as anything in arms)
		LIQUID_TEST(length(arm.neighbours) == 0, "Removing the center must update every neighboring connection")
	LIQUID_TEST(removed.wrench_act(null, null) == ITEM_INTERACT_SUCCESS, "A loose smart section must reconnect by wrench on its original free level")
	var/obj/machinery/duct/stationtrauma/reconnected
	for(var/obj/machinery/duct/stationtrauma/pipe in center)
		if(pipe.water_level == 3)
			reconnected = pipe
	allocated += reconnected
	LIQUID_TEST(reconnected && reconnected.icon_state == "pipe_15", "Reattaching the section must restore its automatic cross")
	for(var/obj/machinery/duct/stationtrauma/arm as anything in arms)
		LIQUID_TEST(arm.net == reconnected.net, "Reattaching must merge all four previously separated networks")

	rpd.mode = (1<<0)
	var/list/loose = rpd.dispense_water_selection(base, 1, SOUTH, list(1, 5))
	allocated += loose
	LIQUID_TEST(length(loose) == 2 && istype(loose[1], /obj/item/stationtrauma_water_pipe_fitting), "Disabling Connect must dispense loose sections on every selected level")
	rpd.mode = (1<<2)
	for(var/obj/item/stationtrauma_water_pipe_fitting/fitting as anything in loose)
		LIQUID_TEST(rpd.collect_water_fitting(fitting) && QDELETED(fitting), "Destroy mode must collect disconnected water sections")
	rpd.mode = (1<<0) | (1<<1)
	var/turf/open/bridge_floor = locate(base.x + 2, base.y + 4, base.z)
	var/obj/machinery/duct/stationtrauma/left = rpd.build_water_fixture(get_step(bridge_floor, WEST), 1, SOUTH, 1)
	var/obj/machinery/duct/stationtrauma/right = rpd.build_water_fixture(get_step(bridge_floor, EAST), 1, SOUTH, 5)
	allocated += list(left, right)
	LIQUID_TEST(left && right && left.net != right.net, "Separate water levels must start isolated")
	var/obj/machinery/duct/stationtrauma/manifold/bridge = rpd.build_water_fixture(bridge_floor, 2, SOUTH)
	allocated += bridge
	LIQUID_TEST(bridge && left.net == right.net && left.net == bridge.net, "An explicit collector must connect different water levels")
	LIQUID_TEST(!rpd.build_water_fixture(bridge_floor, 1, SOUTH, 2), "The collector must reserve all five levels on its cell")
	qdel(bridge)
	LIQUID_TEST(left.net != right.net, "Removing the collector must isolate the different levels again")
	var/turf/open/port_floor = get_step(get_turf(right), EAST)
	var/obj/machinery/stationtrauma_water_device/connector/port = rpd.build_water_fixture(port_floor, rpd.water_recipes.Find("Порт бочки"), SOUTH, 5)
	var/obj/machinery/stationtrauma_water_device/barrel/barrel = rpd.build_water_fixture(port_floor, rpd.water_recipes.Find("Бочка 1000 л"), NORTH, 5)
	allocated += list(port, barrel)
	LIQUID_TEST(port && barrel && barrel.connect_port(), "A barrel and its same-tile connector must support the selected water level")
	var/datum/component/plumbing/stationtrauma_water/connection = port.GetComponent(/datum/component/plumbing/stationtrauma_water)
	LIQUID_TEST(connection.ducting_layer == STATIONTRAUMA_WATER_LAYER_BIT(5) && connection.ducts["8"] == right.net, "A level-five device must connect only to its level-five pipe")

#ifdef FLOODWATER_TEST_ONLY
TEST_FOCUS(/datum/unit_test/stationtrauma_water_pipes)
TEST_FOCUS(/datum/unit_test/stationtrauma_room_drain)
TEST_FOCUS(/datum/unit_test/stationtrauma_water_controls)
TEST_FOCUS(/datum/unit_test/stationtrauma_multilayer_pipes)
#endif

#undef LIQUID_TEST
