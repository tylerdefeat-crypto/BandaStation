#define LIQUID_TEST(assertion, reason) if(!(assertion)) { return Fail(reason, __FILE__, __LINE__) }

/datum/unit_test/stationtrauma_water_pipes
	var/list/wet_tiles = list()

/datum/unit_test/stationtrauma_water_pipes/Destroy()
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

#ifdef FLOODWATER_TEST_ONLY
TEST_FOCUS(/datum/unit_test/stationtrauma_water_pipes)
#endif

#undef LIQUID_TEST
