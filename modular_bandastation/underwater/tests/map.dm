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
	for(var/turf/tile as anything in loaded_turfs)
		if(istype(tile, /turf/open/space/ocean))
			ocean_tiles++
		for(var/obj/machinery/bilge_pump/pump in tile)
			pumps++
		for(var/obj/machinery/door/airlock/highsecurity/underwater/door in tile)
			doors++
	MAP_TEST(pumps == 3, "The test map must provide two stationary pumps and one portable pump")
	MAP_TEST(doors == 6, "The test map must provide compartment doors, a two-door exit, and a controlled breach")
	MAP_TEST(ocean_tiles > 200, "The test template must include an external ocean")
	qdel(template)

#ifdef FLOODWATER_TEST_ONLY
TEST_FOCUS(/datum/unit_test/stationtrauma_map)
#endif

#undef MAP_TEST
