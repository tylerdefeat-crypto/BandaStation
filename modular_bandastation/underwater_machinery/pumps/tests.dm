#define PUMP_TEST(assertion, reason) if(!(assertion)) { return Fail(reason, __FILE__, __LINE__) }

/datum/unit_test/bilge_pump/Run()
	var/turf/open/intake = run_loc_floor_bottom_left
	var/turf/open/neighbour = get_step(intake, EAST)
	var/obj/machinery/bilge_pump/pump = allocate(/obj/machinery/bilge_pump, intake)
	intake.set_water_depth(100)
	pump.process(1)
	PUMP_TEST(intake.get_water_depth() == 100, "A switched-off pump must not drain water")
	pump.on = TRUE
	pump.set_machine_stat(pump.machine_stat | NOPOWER)
	pump.process(1)
	PUMP_TEST(intake.get_water_depth() == 100, "An unpowered stationary pump must not drain water")
	pump.set_machine_stat(pump.machine_stat & ~NOPOWER)
	pump.process(1)
	PUMP_TEST(intake.get_water_depth() == 80, "A powered pump must drain its intake at the configured rate")
	neighbour.set_water_depth(100)
	pump.process(1)
	PUMP_TEST(neighbour.get_water_depth() == 100, "A pump must not directly drain neighbouring rooms")
	intake.set_water_depth(220, TRUE)
	pump.process(1)
	PUMP_TEST(intake.get_water_depth() == 220, "A pump must not delete the external ocean")
	intake.set_water_depth(0)
	intake.set_water_depth(1)
	pump.process(1)
	PUMP_TEST(intake.get_water_depth() == 0, "Draining the last water must clean up the component")
	var/obj/machinery/bilge_pump/portable/portable = allocate(/obj/machinery/bilge_pump/portable, intake)
	portable.on = TRUE
	intake.set_water_depth(100)
	portable.process(1)
	PUMP_TEST(intake.get_water_depth() == 100, "An unsecured portable pump must not operate")
	portable.anchored = TRUE
	var/charge_before = portable.cell.charge
	portable.process(1)
	PUMP_TEST(intake.get_water_depth() == 92, "The secured portable pump must drain without area power")
	PUMP_TEST(portable.cell.charge < charge_before, "Portable pumping must consume real battery charge")
	portable.cell.charge = 0
	portable.process(1)
	PUMP_TEST(intake.get_water_depth() == 92, "An empty battery must stop pumping")
	intake.set_water_depth(0)
	neighbour.set_water_depth(0)

#ifdef FLOODWATER_TEST_ONLY
TEST_FOCUS(/datum/unit_test/bilge_pump)
TEST_FOCUS(/datum/unit_test/underwater_airlocks)
#endif

#undef PUMP_TEST
