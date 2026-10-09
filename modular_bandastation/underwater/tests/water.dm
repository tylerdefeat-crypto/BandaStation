#define WATER_TEST(assertion, reason) if(!(assertion)) { return Fail(reason, __FILE__, __LINE__) }

/// Exercises real atmos barriers, conservation, depth transitions, and the normal breathing chain.
/datum/unit_test/breath/floodwater
	var/list/wet_tiles = list()
	var/turf/changed_tile
	var/original_tile_type
	var/original_baseturfs
	var/parallax_level_key
	var/original_parallax_setting
	var/area/original_area

/datum/unit_test/breath/floodwater/Destroy()
	for(var/turf/open/tile as anything in wet_tiles)
		tile.set_water_depth(0)
		tile.initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	if(changed_tile)
		if(original_area)
			set_turf_to_area(changed_tile, original_area)
		changed_tile.ChangeTurf(original_tile_type, original_baseturfs)
	if(parallax_level_key)
		if(isnull(original_parallax_setting))
			GLOB.ocean_parallax_levels -= parallax_level_key
		else
			GLOB.ocean_parallax_levels[parallax_level_key] = original_parallax_setting
	return ..()

/datum/unit_test/breath/floodwater/Run()
	var/turf/open/first = run_loc_floor_bottom_left
	var/turf/open/second = get_step(first, EAST)
	var/turf/open/third = get_step(second, EAST)
	var/list/row = list(first, second, third)
	wet_tiles = row
	var/list/sealed = list()
	for(var/turf/open/tile as anything in row)
		for(var/direction in GLOB.cardinals)
			var/turf/neighbor = get_step(tile, direction)
			if(!isopenturf(neighbor) || (neighbor in row) || (neighbor in sealed))
				continue
			allocate(/obj/structure/window/reinforced/fulltile, neighbor)
			sealed += neighbor
		// Atmospheric updates in the tests are synchronous.
		tile.immediate_calculate_adjacent_turfs()

	var/obj/machinery/door/airlock/barrier = allocate(/obj/machinery/door/airlock/instant, second)
	second.immediate_calculate_adjacent_turfs()
	var/datum/component/floodwater/source = first.set_water_depth(FLOOD_WATER_MAX_DEPTH + 100, TRUE)
	WATER_TEST(source.depth == 220, "Floodwater must stop at the compartment ceiling of 220 cm")
	source.spread()
	WATER_TEST(second.get_water_depth() == 0, "A closed airlock must hold back the ocean")
	barrier.open()
	second.immediate_calculate_adjacent_turfs()
	WATER_TEST(!barrier.density && (second in first.atmos_adjacent_turfs), "The open test airlock must connect the source to the room (density=[barrier.density], first=[first.contents.Join(", ")], second=[second.contents.Join(", ")])")
	source.spread()
	WATER_TEST(second.get_water_depth() > 0 && second.get_water_depth() < FLOOD_WATER_MAX_DEPTH, "Flooding must begin gradually after opening a breach (source=[source.depth], destination=[second.get_water_depth()])")
	WATER_TEST(first.get_water_depth() == FLOOD_WATER_MAX_DEPTH, "The ocean is an infinite reservoir")
	barrier.close()
	second.immediate_calculate_adjacent_turfs()
	var/sealed_depth = second.get_water_depth()
	source.spread()
	WATER_TEST(second.get_water_depth() == sealed_depth, "Closing the breach must stop incoming water")
	barrier.open()
	second.immediate_calculate_adjacent_turfs()
	for(var/cycle in 1 to 60)
		for(var/turf/open/tile as anything in row)
			var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
			water?.spread()
	WATER_TEST(third.get_water_depth() >= FLOOD_WATER_SUBMERGED, "Water must reach and submerge the far end of a room")

	first.set_water_depth(0)
	second.set_water_depth(0)
	third.set_water_depth(0)
	first.set_water_depth(100)
	for(var/cycle in 1 to 20)
		for(var/turf/open/tile as anything in row)
			var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
			water?.spread()
	WATER_TEST(first.get_water_depth() + second.get_water_depth() + third.get_water_depth() == 100, "Finite water must conserve volume")
	for(var/turf/open/tile as anything in row)
		tile.set_water_depth(0)

	var/mob/living/carbon/human/consistent/diver = allocate(/mob/living/carbon/human/consistent, first)
	first.initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	first.air = first.create_gas_mixture()
	first.set_water_depth(30)
	diver.breathe()
	WATER_TEST(!diver.failed_last_breath, "Shallow water must leave the head above water")
	first.set_water_depth(80)
	diver.set_body_position(LYING_DOWN)
	diver.breathe()
	WATER_TEST(diver.failed_last_breath, "A prone human must drown in waist-deep water")
	diver.set_body_position(STANDING_UP)
	diver.breathe()
	WATER_TEST(!diver.failed_last_breath, "Standing up in waist-deep water must uncover the head")
	first.set_water_depth(FLOOD_WATER_MAX_DEPTH)
	var/body_temperature_before = diver.bodytemperature
	var/room_temperature_before = first.air.temperature
	var/datum/status_effect/floodwater/cold_water = diver.has_status_effect(/datum/status_effect/floodwater)
	cold_water.tick(2)
	WATER_TEST(diver.bodytemperature < body_temperature_before, "Cold floodwater must cool an unprotected occupant")
	WATER_TEST(first.air.temperature == room_temperature_before, "Water cooling must not overwrite the room's gas temperature")
	var/cold_body_temperature = diver.bodytemperature
	cold_water.current_water().temperature = T0C + 40
	cold_water.tick(2)
	WATER_TEST(diver.bodytemperature > cold_body_temperature, "Warm floodwater must use its own measured temperature for heat transfer")
	cold_water.current_water().temperature = FLOOD_WATER_TEMPERATURE
	diver.breathe()
	WATER_TEST(diver.failed_last_breath, "Submerged humans must not inhale the room's air")
	var/obj/item/tank/internals/tank = equip_labrat_internals(diver, /obj/item/tank/internals/emergency_oxygen)
	WATER_TEST(tank.toggle_internals(diver), "Could not enable the diver's tank")
	var/moles_before = tank.air_contents.total_moles()
	diver.breathe()
	WATER_TEST(!diver.failed_last_breath, "A working mask and tank must allow underwater breathing")
	WATER_TEST(tank.air_contents.total_moles() < moles_before, "Underwater breathing must consume tank gas")
	tank.air_contents.remove_ratio(1)
	tank.air_contents.assert_gas(/datum/gas/nitrogen)
	tank.air_contents.moles[/datum/gas/nitrogen] = 100
	diver.breathe()
	WATER_TEST(diver.failed_last_breath, "A nitrogen tank must not let a human breathe underwater")
	tank.air_contents.remove_ratio(1)
	diver.breathe()
	WATER_TEST(diver.failed_last_breath, "An empty tank must not protect against drowning")
	tank.air_contents.assert_gas(/datum/gas/oxygen)
	tank.air_contents.moles[/datum/gas/oxygen] = 100
	diver.dropItemToGround(diver.wear_mask)
	diver.open_internals(tank)
	diver.breathe()
	WATER_TEST(diver.failed_last_breath && !diver.internal, "A tank without a valid mask must not protect against drowning")
	diver.cutoff_internals()
	ADD_TRAIT(diver, TRAIT_NODROWN, TRAIT_SOURCE_UNIT_TESTS)
	diver.breathe()
	WATER_TEST(!diver.failed_last_breath, "Aquatic adaptation must protect against drowning")
	REMOVE_TRAIT(diver, TRAIT_NODROWN, TRAIT_SOURCE_UNIT_TESTS)
	diver.forceMove(second)
	WATER_TEST(!diver.has_status_effect(/datum/status_effect/floodwater), "Leaving water must remove its status immediately")
	WATER_TEST(!diver.has_movespeed_modifier(/datum/movespeed_modifier/floodwater), "Leaving water must remove its slowdown")
	diver.breathe()
	WATER_TEST(!diver.failed_last_breath, "Breathing must recover on dry land")
	first.set_water_depth(0)
	first.initial_gas_mix = OPENTURF_DEFAULT_ATMOS

	// Check the actual mapper-facing space subtype, including its inherited space behaviour.
	original_tile_type = first.type
	original_baseturfs = islist(first.baseturfs) ? first.baseturfs.Copy() : first.baseturfs
	original_area = get_area(first)
	changed_tile = first
	parallax_level_key = "[first.z]"
	original_parallax_setting = GLOB.ocean_parallax_levels[parallax_level_key]
	var/turf/open/space/ocean/surface = first.ChangeTurf(/turf/open/space/ocean/shallow)
	diver.forceMove(surface)
	diver.breathe()
	WATER_TEST(!diver.failed_last_breath, "Surface ocean turfs must override space's missing breath")
	diver.breathe()
	WATER_TEST(!diver.failed_last_breath && surface.return_air().return_pressure() > 90, "The shared ocean environment must survive repeated breaths")
	var/turf/open/space/ocean/ocean = surface.ChangeTurf(/turf/open/space/ocean)
	var/datum/component/floodwater/ocean_water = ocean.GetComponent(/datum/component/floodwater)
	WATER_TEST(ocean_water.infinite_source && ocean_water.depth == FLOOD_WATER_MAX_DEPTH, "The ocean turf must initialize an infinite reservoir")
	WATER_TEST(ocean.temperature == FLOOD_WATER_TEMPERATURE && ocean.air.temperature == FLOOD_WATER_TEMPERATURE, "The exterior ocean must remain at four degrees Celsius")
	WATER_TEST(ocean.icon_state == "ocean_mask" && ocean.plane == MUTATE_PLANE(PLANE_SPACE, ocean), "Ocean turfs must supply geometry to the native parallax whitifier, including builds without CBT")
	var/icon/ocean_mask = icon(ocean.icon, ocean.icon_state)
	WATER_TEST(ocean_mask.GetPixel(1, 1) == "#061b20" && ocean_mask.GetPixel(32, 32) == "#061b20", "The parallax mask must cover the whole ocean tile")
	WATER_TEST(ocean_water.water_overlay.plane == MUTATE_PLANE(FLOOR_PLANE, ocean) && ocean_water.water_overlay.alpha <= 64, "Ocean water must remain translucent above the seabed")
	WATER_TEST(GLOB.ocean_parallax_levels[parallax_level_key] == original_parallax_setting, "Ocean turfs must not select a map's parallax")
	WATER_TEST(ocean_water.water_overlay.icon == 'modular_bandastation/underwater/icons/water.dmi' && ocean_water.water_overlay.icon_state == "volume", "Floodwater must use the water-column artwork instead of surface foam")
	var/exterior_water_alpha = ocean_water.water_overlay.alpha
	// The southwest corner must ask its western ocean neighbour after the southern wall.
	var/second_tile_type = second.type
	var/second_baseturfs = islist(second.baseturfs) ? second.baseturfs.Copy() : second.baseturfs
	var/turf/closed/indestructible/riveted/plastinum/corner = second.ChangeTurf(/turf/closed/indestructible/riveted/plastinum)
	corner.underlays.Cut()
	corner.set_smoothed_icon_state(NORTH_JUNCTION | EAST_JUNCTION)
	var/list/corner_underlays = corner.underlays.Copy()
	corner.ChangeTurf(second_tile_type, second_baseturfs)
	WATER_TEST(length(corner_underlays) == 1, "A diagonal wall bordering the ocean must receive one ocean underlay")
	var/mutable_appearance/ocean_underlay = corner_underlays[1]
	WATER_TEST(ocean_underlay.icon == ocean.icon && ocean_underlay.icon_state == "ocean_mask" && ocean_underlay.plane == MUTATE_PLANE(PLANE_SPACE, ocean), "Diagonal corners must extend the ocean parallax geometry")
	WATER_TEST(length(ocean_underlay.overlays) == 1, "An ocean corner must not inherit space's starlight or lighting masks")
	var/mutable_appearance/corner_water = ocean_underlay.overlays[1]
	WATER_TEST(corner_water.icon_state == "volume" && corner_water.icon == ocean_water.water_overlay.icon && corner_water.alpha == exterior_water_alpha && corner_water.plane == MUTATE_PLANE(FLOOR_PLANE, ocean), "Diagonal corners must preserve the ocean's animation, transparency and lighting plane")
	WATER_TEST(diver.Process_Spacemove(EAST), "Swimming must allow movement without space push-off points")
	diver.breathe()
	WATER_TEST(diver.failed_last_breath, "An ocean must submerge a standing human")
	var/turf/open/repaired = ocean.ChangeTurf(/turf/open/floor/plating)
	var/datum/component/floodwater/remaining_water = repaired.GetComponent(/datum/component/floodwater)
	WATER_TEST(remaining_water && remaining_water.depth == FLOOD_WATER_MAX_DEPTH && !remaining_water.infinite_source, "Floor replacement must preserve finite floodwater without creating a new ocean")
	WATER_TEST(remaining_water.temperature == FLOOD_WATER_TEMPERATURE, "Replacing an ocean turf must retain the water temperature")
	WATER_TEST(remaining_water.water_overlay.alpha > exterior_water_alpha, "Flooded floors must show denser water than the transparent exterior")
	WATER_TEST(GLOB.ocean_parallax_levels[parallax_level_key] == original_parallax_setting, "Replacing turfs must not change a map's parallax")
	diver.forceMove(second)

	var/other_level_setting = GLOB.ocean_parallax_levels["[run_loc_floor_bottom_left.z - 1]"]
	allocate(/obj/effect/landmark/ocean_parallax, repaired)
	WATER_TEST(GLOB.ocean_parallax_levels[parallax_level_key], "A runtime map landmark must select the ocean background without ocean turfs")
	WATER_TEST(GLOB.ocean_parallax_levels["[run_loc_floor_bottom_left.z - 1]"] == other_level_setting, "The map landmark must affect only its own z-level")
	repaired.set_water_depth(0)
	repaired.ChangeTurf(original_tile_type, original_baseturfs)
	WATER_TEST(GLOB.ocean_parallax_levels[parallax_level_key], "Draining water and replacing the marker's turf must preserve the map background")

	// Template initialization allows checking the artwork without a connected client.
	var/atom/movable/screen/parallax_layer/ocean/seafloor/background = allocate(/atom/movable/screen/parallax_layer/ocean/seafloor, null, null, null, TRUE)
	background.update_o("45x33")
	var/icon/seafloor = icon(background.icon)
	WATER_TEST(seafloor.Width() >= 45 * ICON_SIZE_ALL + max(world.maxx, world.maxy) * background.speed * 2, "The single seabed image must cover large views and camera travel")
	WATER_TEST(!length(background.update_overlays()) && background.absolute && background.blend_mode == BLEND_OVERLAY, "The seabed must not repeat or use additive space blending")
	WATER_TEST(background.appearance_flags & TILE_BOUND, "The oversized seabed must not create screen borders that rescale the viewport")
	WATER_TEST(background.color == "#303e46", "Distant terrain must be attenuated independently of nearby sediment")
	var/atom/movable/screen/parallax_layer/ocean/seafloor/crests/crests = allocate(/atom/movable/screen/parallax_layer/ocean/seafloor/crests, null, null, null, TRUE)
	crests.update_o("45x33")
	var/icon/raised_stone = icon(crests.icon)
	WATER_TEST(raised_stone.Width() == seafloor.Width() && raised_stone.Height() == seafloor.Height() && crests.speed == background.speed && crests.pixel_x == background.pixel_x && crests.pixel_y == background.pixel_y, "Raised rocks must stay registered with the seabed at large views, without doubled silhouettes")
	WATER_TEST(!raised_stone.GetPixel(round(raised_stone.Width() / 2), round(raised_stone.Height() / 2)), "The crest layer must leave the deep central channel transparent")
	WATER_TEST(crests.color == "#a8cdd6" && crests.layer > background.layer && crests.plane == background.plane, "Raised stone must be brighter than the bottom while remaining in the ordinary lit parallax plane")
	WATER_TEST(!length(crests.update_overlays()) && (crests.appearance_flags & TILE_BOUND), "Raised rocks must neither tile nor enlarge viewport borders")
	// Test the actual screen relay: checking turf lumcounts cannot catch fullbright parallax.
	var/datum/plane_master_group/hudless/render_group = allocate(/datum/plane_master_group/hudless)
	render_group.our_mob = diver
	render_group.set_perspective(diver)
	var/atom/movable/screen/plane_master/parallax_white/space_plane = render_group.get_plane(MUTATE_PLANE(PLANE_SPACE, first))
	var/emissive_plane = MUTATE_PLANE(RENDER_PLANE_EMISSIVE, first)
	var/atom/movable/screen/plane_master/floor/floor_plane = render_group.get_plane(MUTATE_PLANE(FLOOR_PLANE, first))
	var/floor_block_color = floor_plane.get_relay_to(emissive_plane).color
	WATER_TEST(space_plane.get_relay_to(emissive_plane)?.color ~= floor_block_color, "Ocean geometry must block fullbright at the screen relay, like an ordinary floor")
	WATER_TEST(space_plane.get_relay_to(MUTATE_PLANE(RENDER_PLANE_UNLIT_GAME, first)) && space_plane.get_relay_to(MUTATE_PLANE(RENDER_PLANE_LIGHT_MASK, first)), "Darkening the ocean must preserve the parallax backdrop and visibility mask")
	var/turf/normal_level
	for(var/level in 1 to world.maxz)
		if(!GLOB.ocean_parallax_levels["[level]"])
			normal_level = locate(1, 1, level)
			break
	WATER_TEST(normal_level, "The render check needs an ordinary level outside the ocean")
	diver.forceMove(normal_level)
	var/atom/movable/screen/plane_master/parallax_white/normal_space_plane = render_group.get_plane(MUTATE_PLANE(PLANE_SPACE, normal_level))
	WATER_TEST(isnull(normal_space_plane.get_relay_to(MUTATE_PLANE(RENDER_PLANE_EMISSIVE, normal_level))?.color), "Leaving the ocean must restore the native space fullbright relay")
	diver.forceMove(second)
	WATER_TEST(space_plane.get_relay_to(emissive_plane)?.color ~= floor_block_color, "Returning to the ocean must block fullbright again")
	render_group.set_perspective(null)
	qdel(render_group)

	var/area/space/ocean/dark_area = allocate(/area/space/ocean)
	set_turf_to_area(first, dark_area)
	var/turf/open/space/ocean/dark_ocean = first.ChangeTurf(/turf/open/space/ocean)
	var/turf/forward_tile = get_step(dark_ocean, NORTH)
	SSlighting.fire(FALSE, TRUE)
	WATER_TEST(dark_area.static_lighting && !dark_area.base_lighting_alpha && dark_ocean.lighting_object && !dark_ocean.get_static_lumcount(), "Runtime-loaded ocean areas must have native darkness without ambient light")
	dark_ocean.enable_starlight()
	WATER_TEST(!dark_ocean.light_on, "Native neighbouring lighting updates must not switch ocean starlight back on")
	// Compare along the beam beyond its narrow tip, in an otherwise fullbright fixture.
	var/turf/near_tile = locate(dark_ocean.x, dark_ocean.y + 2, dark_ocean.z)
	var/turf/far_tile = locate(dark_ocean.x, dark_ocean.y + 4, dark_ocean.z)
	var/list/sample_areas = list()
	for(var/turf/sample as anything in list(near_tile, far_tile))
		sample_areas[sample] = get_area(sample)
		set_turf_to_area(sample, dark_area)
		sample.lighting_build_overlay()
	var/obj/effect/overlay/spotlight/underwater/projector = allocate(/obj/effect/overlay/spotlight/underwater, dark_ocean)
	SSlighting.fire(FALSE, TRUE)
	var/near_lumcount = near_tile.get_static_lumcount()
	var/far_lumcount = far_tile.get_static_lumcount()
	for(var/turf/sample as anything in sample_areas)
		set_turf_to_area(sample, sample_areas[sample])
		sample.lighting_clear_overlay()
	WATER_TEST(projector.light && projector.light_angle < 90 && projector.light_dir == NORTH && forward_tile.get_static_lumcount() > 0, "Projectors must illuminate the water with real directional light")
	WATER_TEST(near_lumcount > far_lumcount && far_lumcount > 0, "The projector's light must fade gradually with distance (near=[near_lumcount], far=[far_lumcount])")
	var/list/light_offset = calculate_light_offset(projector)
	WATER_TEST(!light_offset[1] && !light_offset[2], "The large beam sprite must not shift its light source away from the mounting turf")
	projector.setDir(SOUTH)
	SSlighting.fire(FALSE, TRUE)
	WATER_TEST(projector.light_dir == SOUTH && !forward_tile.get_static_lumcount(), "Rotating a projector must move its light away from the old beam direction")
	projector.set_light(l_on = FALSE)
	SSlighting.fire(FALSE, TRUE)
	WATER_TEST(!projector.light && projector.invisibility == INVISIBILITY_ABSTRACT, "Switching a projector off must remove both its light and decorative beam")
	projector.update_beam()
	WATER_TEST(!projector.light && projector.invisibility == INVISIBILITY_ABSTRACT, "Refreshing an inactive beam must not turn it back on")
	var/turf/wall_mount = get_step(dark_ocean, SOUTH)
	WATER_TEST(IS_OPAQUE_TURF(wall_mount), "The wall-mounted beam check requires the fixture's southern wall")
	projector.forceMove(wall_mount)
	projector.setDir(NORTH)
	projector.beam_range = 8
	projector.beam_width = 4
	projector.update_beam()
	projector.set_light(l_on = TRUE)
	SSlighting.fire(FALSE, TRUE)
	WATER_TEST(projector.light_range == 8 && projector.light_dir == NORTH && dark_ocean.get_static_lumcount() > 0 && projector.invisibility != INVISIBILITY_ABSTRACT, "Resized wall-mounted projectors must light the adjacent ocean and restore their visible beam")
	projector.set_light(l_on = FALSE)
	SSlighting.fire(FALSE, TRUE)
	WATER_TEST(!dark_ocean.get_static_lumcount(), "The ocean must return to darkness when its last light source is off")

	// Handheld lights use the native overlay renderer, independently of stationary lights.
	diver.forceMove(dark_ocean)
	diver.setDir(NORTH)
	var/obj/item/flashlight/torch = allocate(/obj/item/flashlight, dark_ocean)
	WATER_TEST(diver.put_in_hands(torch), "The diver must be able to hold the test flashlight")
	torch.set_light_on(TRUE)
	var/datum/component/overlay_lighting/torch_light = torch.GetComponent(/datum/component/overlay_lighting)
	WATER_TEST(torch_light?.current_holder == diver && torch_light.directional && torch_light.currently_displaying, "A held flashlight must display its native directional lighting on the diver")
	WATER_TEST(torch_light.visible_mask.plane == MUTATE_PLANE(O_LIGHTING_VISUAL_PLANE, diver) && torch_light.directional_offset_y > torch_light.directional_offset_x && forward_tile.get_dynamic_lumcount() > 0, "The flashlight must cast forward into the dark ocean using the ordinary lighting renderer")
	diver.setDir(EAST)
	WATER_TEST(torch_light.current_direction == EAST && torch_light.directional_offset_x > torch_light.directional_offset_y, "Turning the diver must turn the flashlight's light")
	var/datum/component/floodwater/lit_water = dark_ocean.GetComponent(/datum/component/floodwater)
	WATER_TEST(lit_water.water_overlay.alpha == exterior_water_alpha && dark_ocean.icon_state == "ocean_mask", "Lighting must preserve water transparency and the seabed mask")
	torch.set_light_on(FALSE)
	WATER_TEST(!torch_light.currently_displaying && !dark_ocean.get_dynamic_lumcount(), "Switching the flashlight off must restore the ocean's darkness")

	var/datum/parsed_map/mission = new(file("_maps/map_files/syndie_underwater/syndie_underwater_base.dmm"))
	WATER_TEST(mission.bounds && !mission.check_for_errors(), "The furnished away map and its parallax landmark must pass the native map loader's validation")
	var/list/mission_models = mission.build_cache(FALSE)
	var/ocean_models = 0
	for(var/key in mission_models)
		var/list/model = mission_models[key]
		if(!islist(model))
			continue
		var/list/members = model[1]
		WATER_TEST(!(/area/centcom/heretic_backdoor in members), "The underwater mission must not inherit Mansus blindness or lighting")
		for(var/member in members)
			if(ispath(member, /turf/open/space))
				WATER_TEST(/area/space/ocean in members, "All exterior space/ocean turfs must use the illuminated ocean area (model [key])")
				ocean_models++
	WATER_TEST(ocean_models, "The furnished mission must contain ocean lighting areas")

#ifdef FLOODWATER_TEST_ONLY
TEST_FOCUS(/datum/unit_test/breath/floodwater)
#endif

#undef WATER_TEST
