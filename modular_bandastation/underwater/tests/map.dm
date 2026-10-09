#define MAP_TEST(assertion, reason) if(!(assertion)) { return Fail(reason, __FILE__, __LINE__) }

/// Loads the manual test template through the same native loader as the admin placement verb.
/datum/unit_test/stationtrauma_map/Run()
	var/datum/map_template/template = allocate(/datum/map_template, "modular_bandastation/underwater/maps/stationtrauma_test.dmm")
	MAP_TEST(template.width == 34, "Test template width changed")
	MAP_TEST(template.height == 24, "Test template height changed")
	var/turf/origin = locate(70, 70, run_loc_floor_bottom_left.z)
	MAP_TEST(template.load(origin), "The StationTrauma template must load and initialize")
	var/list/loaded_turfs = template.get_affected_turfs(origin)
	var/pumps = 0
	var/doors = 0
	var/ocean_tiles = 0
	var/obj/machinery/power/stationtrauma_reactor/reactor
	var/obj/machinery/atmospherics/components/binary/stationtrauma_coolant_pump/cooling
	var/obj/machinery/atmospherics/components/unary/stationtrauma_ocean_exchanger/exchanger
	var/obj/machinery/stationtrauma_water_device/reservoir
	var/obj/machinery/stationtrauma_water_device/drain_receiver
	var/obj/machinery/stationtrauma_water_device/valve/valve
	var/obj/machinery/stationtrauma_water_device/outlet/outlet
	for(var/turf/tile as anything in loaded_turfs)
		if(istype(tile, /turf/open/space/ocean))
			ocean_tiles++
		for(var/obj/machinery/bilge_pump/pump in tile)
			pumps++
		for(var/obj/machinery/door/airlock/highsecurity/underwater/door in tile)
			doors++
		for(var/obj/machinery/power/stationtrauma_reactor/found in tile)
			reactor = found
		for(var/obj/machinery/atmospherics/components/binary/stationtrauma_coolant_pump/found in tile)
			cooling = found
		for(var/obj/machinery/atmospherics/components/unary/stationtrauma_ocean_exchanger/found in tile)
			exchanger = found
		for(var/obj/machinery/stationtrauma_water_device/found in tile)
			if(found.capacity == 50000)
				drain_receiver = found
			else if(found.type == /obj/machinery/stationtrauma_water_device)
				reservoir = found
			else if(istype(found, /obj/machinery/stationtrauma_water_device/valve))
				valve = found
			else if(istype(found, /obj/machinery/stationtrauma_water_device/outlet))
				outlet = found
	MAP_TEST(pumps == 3, "The test map must provide two stationary pumps and one portable pump")
	MAP_TEST(drain_receiver && drain_receiver.reagents.maximum_volume == 50000, "The drainage room must have its mapped receiver capacity")
	var/list/drain_connections = drain_receiver.GetComponents(/datum/component/plumbing/stationtrauma_water)
	MAP_TEST(length(drain_connections) == 1, "The drainage receiver must have one plumbing component")
	var/datum/component/plumbing/stationtrauma_water/drain_connection = drain_connections[1]
	MAP_TEST(drain_connection.ducts["8"], "The room pump must connect to its receiver through a real duct")
	MAP_TEST(doors == 6, "The test map must provide compartment doors, a two-door exit, and a controlled breach")
	MAP_TEST(ocean_tiles > 200, "The test template must include an external ocean")
	MAP_TEST(reactor && cooling && exchanger, "The rig must contain a reactor and a real gas cooling loop")
	MAP_TEST(reservoir && valve && outlet, "The rig must also contain a water reservoir, valve and outlet")
	MAP_TEST(reservoir.reagents.total_volume == 500 && reservoir.reagents.chem_temp == T0C + 40, "The manual water fixture must start with 500 litres at 40 C")
	var/list/valve_connections = valve.GetComponents(/datum/component/plumbing/stationtrauma_water)
	var/list/outlet_connections = outlet.GetComponents(/datum/component/plumbing/stationtrauma_water/outlet)
	MAP_TEST(length(valve_connections) == 1 && length(outlet_connections) == 1, "Each liquid fixture must register one plumbing component")
	var/datum/component/plumbing/stationtrauma_water/valve_connection = valve_connections[1]
	var/datum/component/plumbing/stationtrauma_water/outlet/outlet_connection = outlet_connections[1]
	MAP_TEST(valve_connection.ducts["8"] && outlet_connection.ducts["8"], "The map's real liquid ducts must connect after loading")
	valve_connection.process()
	MAP_TEST(valve.reagents.total_volume == 0, "The mapped closed valve must retain the warm test charge")
	valve.valve_open = TRUE
	outlet.on = TRUE
	outlet.set_machine_stat(outlet.machine_stat & ~NOPOWER)
	for(var/tick in 1 to 5)
		valve_connection.process()
		outlet_connection.process()
		outlet.process(1)
	var/turf/open/discharge_floor = outlet.loc
	var/datum/component/floodwater/discharged_water = discharge_floor.GetComponent(/datum/component/floodwater)
	MAP_TEST(discharged_water && discharged_water.depth == 50 && discharged_water.temperature == T0C + 40, "The loaded rig must release the complete 500-litre charge at its original temperature")
	MAP_TEST(reactor.powernet && cooling.nodes[1] && cooling.nodes[2] && exchanger.nodes[1], "Power and coolant fixtures must really connect after loading")
	reactor.core_temperature = T0C + 300
	cooling.on = TRUE
	cooling.set_machine_stat(cooling.machine_stat & ~NOPOWER)
	cooling.process_atmos(1)
	MAP_TEST(reactor.core_temperature < T0C + 300, "The powered map's gas loop must cool the core")
	var/cooled_temperature = reactor.core_temperature
	cooling.set_machine_stat(cooling.machine_stat | NOPOWER)
	cooling.process_atmos(1)
	MAP_TEST(reactor.core_temperature == cooled_temperature, "Loss of pump power must stop core cooling")
	cooling.set_machine_stat(cooling.machine_stat & ~NOPOWER)
	cooling.on = FALSE
	cooling.process_atmos(1)
	MAP_TEST(reactor.core_temperature == cooled_temperature, "A switched-off coolant pump must not transfer heat")
	cooling.on = TRUE
	var/datum/pipeline/loop = cooling.parents[1]
	loop.reconcile_air()
	reactor.fuel_rod = allocate(/obj/item/stationtrauma_fuel_rod, reactor)
	reactor.core_temperature = T20C
	MAP_TEST(reactor.set_output(1), "The test rig must start at full output")
	for(var/tick in 1 to 300)
		reactor.process(1)
		cooling.process_atmos(1)
		loop.reconcile_air()
		exchanger.process_atmos(1)
		loop.reconcile_air()
	MAP_TEST(reactor.running && reactor.core_temperature < T0C + 450, "The supplied cooling loop must sustain five minutes of full output without auto-SCRAM")
	reactor.scram()
	var/datum/gas_mixture/radiator_air = exchanger.airs[1]
	radiator_air.temperature = T0C + 200
	exchanger.process_atmos(1)
	MAP_TEST(radiator_air.temperature < T0C + 200, "The external radiator must cool gas against the ocean")
	cooled_temperature = reactor.core_temperature
	qdel(cooling.nodes[1])
	cooling.process_atmos(1)
	MAP_TEST(!cooling.nodes[1] && reactor.core_temperature == cooled_temperature, "A real broken intake pipe must stop cooling")
	qdel(template)

#ifdef FLOODWATER_TEST_ONLY
TEST_FOCUS(/datum/unit_test/stationtrauma_map)
#endif

#undef MAP_TEST
