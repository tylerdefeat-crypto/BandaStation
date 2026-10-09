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
	for(var/direction in GLOB.cardinals)
		if(direction != EAST)
			allocate(/obj/structure/window/reinforced/fulltile, get_step(floor, direction))
	floor.immediate_calculate_adjacent_turfs()
	floor.set_water_depth(100, FALSE, T0C + 40)
	adjacent.set_water_depth(20, FALSE, T0C + 4)
	water = floor.GetComponent(/datum/component/floodwater)
	water.spread()
	var/datum/component/floodwater/mixture = adjacent.GetComponent(/datum/component/floodwater)
	LIQUID_TEST(floor.get_water_depth() + adjacent.get_water_depth() == 120 && abs(mixture.temperature - (T0C + 16)) < 0.01, "Natural flooding must preserve volume and carry its temperature")
	floor.set_water_depth(0)
	adjacent.set_water_depth(0)

	var/datum/map_template/template = allocate(/datum/map_template, "modular_bandastation/underwater/maps/stationtrauma_test.dmm")
	var/turf/origin = locate(70, 35, floor.z)
	LIQUID_TEST(template.load(origin), "The pipeline fixture must load in a room large enough for its real ducts")
	var/turf/open/intake = locate(origin.x + 7, origin.y + 10, origin.z)
	var/turf/open/reservoir_floor = locate(intake.x + 2, intake.y, intake.z)
	var/turf/open/valve_floor = locate(intake.x + 4, intake.y, intake.z)
	var/turf/open/outlet_floor = locate(intake.x + 6, intake.y, intake.z)
	wet_tiles += list(intake, outlet_floor)
	var/obj/machinery/bilge_pump/plumbed/pump = allocate(/obj/machinery/bilge_pump/plumbed, intake)
	pump.setDir(EAST)
	pump.on = TRUE
	pump.set_machine_stat(pump.machine_stat & ~NOPOWER)
	var/obj/machinery/stationtrauma_water_device/reservoir = allocate(/obj/machinery/stationtrauma_water_device, reservoir_floor)
	var/obj/machinery/stationtrauma_water_device/valve/valve = allocate(/obj/machinery/stationtrauma_water_device/valve, valve_floor)
	var/obj/machinery/stationtrauma_water_device/outlet/outlet = allocate(/obj/machinery/stationtrauma_water_device/outlet, outlet_floor)
	var/list/ducts = list()
	for(var/offset in list(1, 3, 5))
		var/obj/machinery/duct/duct = allocate(/obj/machinery/duct, locate(intake.x + offset, intake.y, intake.z))
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

#ifdef FLOODWATER_TEST_ONLY
TEST_FOCUS(/datum/unit_test/stationtrauma_water_pipes)
TEST_FOCUS(/datum/unit_test/stationtrauma_room_drain)
#endif

#undef LIQUID_TEST
