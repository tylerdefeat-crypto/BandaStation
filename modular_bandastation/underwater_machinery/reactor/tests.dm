#define REACTOR_TEST(assertion, reason) if(!(assertion)) { return Fail(reason, __FILE__, __LINE__) }

/datum/unit_test/stationtrauma_reactor/Run()
	var/turf/floor = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/engineer = allocate(/mob/living/carbon/human/consistent, floor)
	var/obj/machinery/power/stationtrauma_reactor/reactor = allocate(/obj/machinery/power/stationtrauma_reactor, floor)
	REACTOR_TEST(reactor.icon_state == "reactor_off", "A cold stopped reactor must show the donor's inactive sprite")
	REACTOR_TEST(reactor.pixel_x == -32 && reactor.pixel_y == -32, "The original 96-pixel sprite must remain centred on the machine")
	REACTOR_TEST(reactor.control_rod.icon_state in icon_states(reactor.control_rod.icon), "The physical control rod must have its donor sprite")
	REACTOR_TEST(!reactor.set_output(1), "A reactor without fuel must not start")
	var/obj/item/stationtrauma_fuel_rod/rod = allocate(/obj/item/stationtrauma_fuel_rod)
	engineer.put_in_active_hand(rod, forced = TRUE)
	REACTOR_TEST(reactor.item_interaction(engineer, rod, list()) == ITEM_INTERACT_SUCCESS, "A cold reactor must accept a real held fuel cartridge")
	REACTOR_TEST(reactor.fuel_rod == rod && rod.loc == reactor, "The loaded cartridge must physically enter the reactor")
	var/datum/powernet/grid = allocate(/datum/powernet)
	reactor.powernet = grid
	REACTOR_TEST(reactor.set_output(0.5), "An intact fuelled reactor must accept half power")
	REACTOR_TEST(reactor.icon_state == "reactor_on", "A running cold reactor must show the donor's active sprite")
	var/fuel_before = rod.fuel_remaining
	reactor.process(2)
	REACTOR_TEST(reactor.generated_power == 15000 && grid.newavail == 30000, "Output must enter the native powernet as energy")
	REACTOR_TEST(rod.fuel_remaining == fuel_before - 1, "Fuel burn must follow elapsed time and requested output")
	REACTOR_TEST(reactor.core_temperature > T20C, "Running must heat the core")
	var/hot_temperature = reactor.core_temperature
	reactor.scram()
	REACTOR_TEST(reactor.core_temperature == hot_temperature && reactor.rod_insertion == 1, "SCRAM must insert the rod without erasing stored heat")
	reactor.process(2)
	REACTOR_TEST(reactor.generated_power == 0 && reactor.core_temperature > hot_temperature, "Residual heat must remain after power generation stops")
	var/datum/gas_mixture/gas = allocate(/datum/gas_mixture)
	gas.moles[/datum/gas/nitrogen] = 100
	gas.temperature = T0C + 4
	var/energy_before = reactor.core_temperature * 5000 + gas.temperature * gas.heat_capacity()
	REACTOR_TEST(reactor.exchange_heat(gas) > 0, "Cold real gas must accept heat from the stopped core")
	// BYOND numbers have single-precision rounding at these energy magnitudes.
	REACTOR_TEST(abs(energy_before - (reactor.core_temperature * 5000 + gas.temperature * gas.heat_capacity())) < energy_before * 0.000001, "Heat exchange must conserve thermal energy within floating-point precision")
	gas.temperature = reactor.core_temperature + 10
	REACTOR_TEST(reactor.exchange_heat(gas) == 0, "Hot coolant must not magically cool the core")
	reactor.core_temperature = T0C + 460
	REACTOR_TEST(!reactor.set_output(1), "An overheated reactor must reject restart")
	reactor.running = TRUE
	reactor.process(1)
	REACTOR_TEST(!reactor.running && reactor.generated_power == 0, "Overheat must trigger automatic SCRAM")
	REACTOR_TEST(reactor.icon_state == "reactor_overheat", "A hot stopped reactor must retain a visible overheat indication")
	reactor.core_temperature = T0C + 510
	var/integrity_before = reactor.get_integrity()
	reactor.process(1)
	REACTOR_TEST(reactor.get_integrity() < integrity_before, "Continued loss of cooling must damage the casing locally")
	reactor.core_temperature = T20C
	rod.fuel_remaining = 0.25
	REACTOR_TEST(reactor.set_output(1), "The last fraction of usable fuel may run")
	reactor.process(1)
	REACTOR_TEST(rod.fuel_remaining == 0 && reactor.generated_power == 7500, "The final partial fuel charge must not create a full tick of free energy")
	reactor.process(1)
	REACTOR_TEST(!reactor.running && reactor.generated_power == 0, "Exhausted fuel must shut down generation")
	QDEL_NULL(reactor.control_rod)
	rod.fuel_remaining = 10
	REACTOR_TEST(!reactor.set_output(1), "Removing the physical control rod must prevent startup")
	REACTOR_TEST(rod.icon_state in icon_states(rod.icon), "The fuel cartridge must have a valid sprite")

#ifdef FLOODWATER_TEST_ONLY
TEST_FOCUS(/datum/unit_test/stationtrauma_reactor)
#endif

#undef REACTOR_TEST
