#define SUBMARINE_TEST(assertion, reason) if(!(assertion)) { return Fail(reason, __FILE__, __LINE__) }

/datum/unit_test/stationtrauma_submarine
	var/list/ports = list()

/datum/unit_test/stationtrauma_submarine/Destroy()
	for(var/obj/docking_port/port as anything in ports)
		qdel(port, force = TRUE)
	return ..()

/datum/unit_test/stationtrauma_submarine/Run()
	var/datum/map_template/template = allocate(/datum/map_template, "modular_bandastation/underwater/maps/stationtrauma_route.dmm")
	var/turf/origin = locate(140, 80, run_loc_floor_bottom_left.z)
	SUBMARINE_TEST(template.load(origin), "The route template must load through the native loader")
	var/obj/docking_port/mobile/stationtrauma/vessel
	var/obj/docking_port/stationary/stationtrauma/base/base
	var/obj/docking_port/stationary/stationtrauma/wreck/wreck
	var/obj/machinery/computer/shuttle/stationtrauma/console
	var/obj/machinery/power/stationtrauma_reactor/reactor
	var/obj/machinery/atmospherics/components/binary/stationtrauma_coolant_pump/vessel_cooling
	for(var/turf/tile as anything in template.get_affected_turfs(origin))
		for(var/obj/docking_port/port in tile)
			ports += port
			if(istype(port, /obj/docking_port/mobile/stationtrauma))
				vessel = port
			else if(istype(port, /obj/docking_port/stationary/stationtrauma/base))
				base = port
			else if(istype(port, /obj/docking_port/stationary/stationtrauma/wreck))
				wreck = port
		for(var/obj/machinery/computer/shuttle/stationtrauma/found in tile)
			console = found
		for(var/obj/machinery/power/stationtrauma_reactor/found in tile)
			reactor = found
		for(var/obj/machinery/atmospherics/components/binary/stationtrauma_coolant_pump/cooling in tile)
			cooling.on = FALSE
			vessel_cooling = cooling
	SUBMARINE_TEST(vessel && base && wreck && console, "Both fixed points and the vessel's console must exist")
	console.prepare_vessel()
	SUBMARINE_TEST(vessel.registered && SSshuttle.getShuttle(console.shuttleId) == vessel, "Manual template loading must register and link the mobile port")
	SUBMARINE_TEST(vessel.width == 14 && vessel.height == 10, "The whole interior must belong to the mobile port")
	SUBMARINE_TEST(vessel.get_docked() == base, "The vessel must start docked at the base")
	SUBMARINE_TEST(reactor && reactor.powernet, "The vessel must carry a reactor connected to its real cable network")
	var/obj/machinery/stationtrauma_water_device/water_tank = locate() in locate(base.x + 2, base.y + 1, base.z)
	var/obj/machinery/stationtrauma_water_device/receiving_tank = locate() in locate(base.x + 6, base.y + 1, base.z)
	var/obj/machinery/stationtrauma_water_device/valve/water_valve = locate() in locate(base.x + 4, base.y + 1, base.z)
	var/obj/machinery/duct/water_pipe = locate() in locate(base.x + 3, base.y + 1, base.z)
	SUBMARINE_TEST(water_tank && receiving_tank && water_valve && water_pipe && !water_valve.valve_open, "The route must provide a sealed charged water circuit")
	SUBMARINE_TEST(water_tank.reagents.total_volume == 500 && abs(water_tank.reagents.chem_temp - (T0C + 40)) < 0.01 && receiving_tank.reagents.total_volume == 100 && abs(receiving_tank.reagents.chem_temp - (T0C + 4)) < 0.01, "The loaded tanks must contain their mapped charge: warm=[water_tank.reagents.total_volume]/[water_tank.reagents.chem_temp], cold=[receiving_tank.reagents.total_volume]/[receiving_tank.reagents.chem_temp]")
	reactor.core_temperature = T0C + 100
	reactor.fuel_rod = allocate(/obj/item/stationtrauma_fuel_rod, reactor)
	reactor.fuel_rod.fuel_remaining = 100
	var/turf/open/wet = locate(base.x + 6, base.y + 3, base.z)
	var/turf/open/dry = locate(base.x + 4, base.y + 3, base.z)
	wet.set_water_depth(80, FALSE, T0C + 35)
	allocate(/obj/structure/window/reinforced/fulltile, wet)
	wet.immediate_calculate_adjacent_turfs()
	var/mob/living/carbon/human/consistent/crew = allocate(/mob/living/carbon/human/consistent, dry)
	var/obj/item/wrench/cargo = allocate(/obj/item/wrench, wet)
	var/obj/machinery/door/airlock/highsecurity/underwater/door = locate() in locate(base.x, base.y + 4, base.z)
	SUBMARINE_TEST(door, "The vessel must contain its exit door")
	door.take_damage(30, BRUTE, MELEE)
	door.handwheel_locked = TRUE
	var/door_integrity = door.get_integrity()
	var/turf/closed/wall/hull = locate(base.x, base.y, base.z)
	var/turf/open/space/ocean/breach = hull.ScrapeAway(1)
	SUBMARINE_TEST(istype(breach) && breach.depth_to_find_baseturf(/turf/baseturf_skipover/shuttle), "A broken hull must retain its movable ocean breach")
	SUBMARINE_TEST(length(console.get_valid_destinations()) == 1, "Only the other route point must be offered")
	var/original_direction = wreck.dir
	wreck.dir = EAST
	SUBMARINE_TEST(vessel.request(wreck) != DOCKING_SUCCESS, "The prototype must refuse unsupported dock rotations")
	wreck.dir = original_direction
	var/obj/docking_port/stationary/stationtrauma/overlapping = allocate(/obj/docking_port/stationary/stationtrauma, locate(base.x + 1, base.y, base.z))
	ports += overlapping
	SUBMARINE_TEST(vessel.request(overlapping) != DOCKING_SUCCESS, "An overlapping dock must be rejected before any state moves")
	var/old_x = vessel.x
	SUBMARINE_TEST(vessel.request(wreck) == DOCKING_SUCCESS, "A valid route request must begin travel")
	SUBMARINE_TEST(vessel.x == old_x && vessel.mode == SHUTTLE_CALL, "The prototype must keep the interior at departure until its timer expires")
	SUBMARINE_TEST(vessel.request(base) != DOCKING_SUCCESS, "A second request during travel must be refused")
	vessel.timer = world.time
	vessel.check()
	SUBMARINE_TEST(vessel.get_docked() == wreck && vessel.mode == SHUTTLE_IDLE, "The timed route must arrive at the wreck")
	var/turf/open/arrived_wet = get_turf(cargo)
	SUBMARINE_TEST(arrived_wet.get_water_depth() == 80, "Finite water must travel with its cell without becoming an ocean source")
	var/datum/component/floodwater/arrived_water = arrived_wet.GetComponent(/datum/component/floodwater)
	SUBMARINE_TEST(!arrived_water.infinite_source, "Finite interior water must remain finite")
	SUBMARINE_TEST(arrived_water.temperature == T0C + 35, "The interior water's temperature must survive docking")
	var/turf/open/arrived_dry = get_turf(crew)
	SUBMARINE_TEST(arrived_dry.get_water_depth() == 0 && crew.x == wreck.x + 4, "A dry cell and its occupant must remain dry when docking over ocean")
	SUBMARINE_TEST(door.get_integrity() == door_integrity && door.handwheel_locked, "Damage and the mechanical door lock must survive docking")
	SUBMARINE_TEST(reactor.core_temperature == T0C + 100 && reactor.fuel_rod.fuel_remaining == 100, "Core heat and the physical fuel cartridge must survive docking")
	SUBMARINE_TEST(reactor.powernet, "The reactor must reconnect to the vessel's cable network after movement")
	var/turf/closed/wall/arrived_hull = locate(wreck.x + 1, wreck.y, wreck.z)
	SUBMARINE_TEST(arrived_hull.baseturf_at_depth(1) == /turf/open/space/ocean, "An intact hull must still open into the ocean when broken after arrival")
	var/turf/open/space/ocean/arrived_breach = locate(wreck.x, wreck.y, wreck.z)
	var/datum/component/floodwater/breach_water = arrived_breach.GetComponent(/datum/component/floodwater)
	SUBMARINE_TEST(istype(arrived_breach) && breach_water?.infinite_source, "An unrepaired ocean breach must remain a breach at arrival")
	var/turf/open/left_behind = locate(base.x + 4, base.y + 3, base.z)
	var/datum/component/floodwater/ocean_water = left_behind.GetComponent(/datum/component/floodwater)
	SUBMARINE_TEST(istype(left_behind, /turf/open/space/ocean) && ocean_water?.infinite_source, "The vacated dock must restore the external ocean")
	SUBMARINE_TEST(vessel.request(base) == DOCKING_SUCCESS, "The vessel must be able to return to base")
	vessel.timer = world.time
	vessel.check()
	SUBMARINE_TEST(vessel.get_docked() == base && crew.x == base.x + 4, "Crew must return with the same interior")
	var/turf/open/returned_wet = get_turf(cargo)
	SUBMARINE_TEST(returned_wet.get_water_depth() == 80, "Water must survive the return trip too")
	var/datum/component/floodwater/returned_water = returned_wet.GetComponent(/datum/component/floodwater)
	SUBMARINE_TEST(returned_water.temperature == T0C + 35, "Returning must not reset the interior water's temperature")
	SUBMARINE_TEST(water_tank.x == base.x + 2 && receiving_tank.x == base.x + 6 && water_pipe.x == base.x + 3, "The sealed liquid circuit must return with the vessel")
	SUBMARINE_TEST(water_tank.reagents.total_volume == 500 && abs(water_tank.reagents.chem_temp - (T0C + 40)) < 0.01 && receiving_tank.reagents.total_volume == 100 && abs(receiving_tank.reagents.chem_temp - (T0C + 4)) < 0.01, "Stored charges must survive both docks: warm=[water_tank.reagents.total_volume]/[water_tank.reagents.chem_temp], cold=[receiving_tank.reagents.total_volume]/[receiving_tank.reagents.chem_temp], valve=[water_valve.valve_open]/[water_valve.reagents.total_volume]")
	var/list/receiving_connections = receiving_tank.GetComponents(/datum/component/plumbing/stationtrauma_water)
	var/list/valve_connections = water_valve.GetComponents(/datum/component/plumbing/stationtrauma_water)
	SUBMARINE_TEST(length(receiving_connections) == 1 && length(valve_connections) == 1, "The returning circuit must retain its plumbing components")
	var/datum/component/plumbing/stationtrauma_water/receiving_connection = receiving_connections[1]
	var/datum/component/plumbing/stationtrauma_water/valve_connection = valve_connections[1]
	water_valve.valve_open = TRUE
	for(var/cycle in 1 to 3)
		valve_connection.process()
		receiving_connection.process()
	SUBMARINE_TEST(water_tank.reagents.total_volume == 0 && water_valve.reagents.total_volume == 0 && receiving_tank.reagents.total_volume == 600 && abs(receiving_tank.reagents.chem_temp - (T0C + 34)) < 0.01, "The relocated real liquid pipe must still transfer and mix its stored water")
	SUBMARINE_TEST(door.get_integrity() == door_integrity, "Repeated travel must preserve damage")
	SUBMARINE_TEST(reactor.core_temperature == T0C + 100 && reactor.fuel_rod.fuel_remaining == 100, "Returning must not reset reactor heat or refuel its cartridge")
	SUBMARINE_TEST(vessel_cooling.nodes[1] && vessel_cooling.nodes[2] && vessel_cooling.parents[1] && vessel_cooling.parents[2], "The real gas loop must remain connected after both moves")
	vessel_cooling.on = TRUE
	vessel_cooling.process_atmos(1)
	SUBMARINE_TEST(reactor.core_temperature < T0C + 100, "The relocated powered gas pump must still cool the same reactor")

#ifdef FLOODWATER_TEST_ONLY
TEST_FOCUS(/datum/unit_test/stationtrauma_submarine)
#endif

#undef SUBMARINE_TEST
