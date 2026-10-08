/datum/unit_test/diagonal_shutters/Run()
	var/turf/closed/indestructible/opsglass/diagonal/window = run_loc_floor_bottom_left.ChangeTurf(/turf/closed/indestructible/opsglass/diagonal)
	var/obj/machinery/door/poddoor/shutters/diagonal/shutter = allocate(/obj/machinery/door/poddoor/shutters/diagonal, window)
	var/obj/machinery/door/poddoor/shutters/diagonal/preopen/open_shutter = allocate(/obj/machinery/door/poddoor/shutters/diagonal/preopen, window)
	for(var/junction in list(5, 6, 9, 10, 21, 38, 74, 137))
		window.set_smoothed_icon_state(junction)
		SEND_SIGNAL(window, COMSIG_ATOM_SMOOTHED_ICON)
		var/expected_dir = junction & CARDINAL_SMOOTHING_JUNCTIONS
		var/suffix = junction == expected_dir ? "" : "-inner"
		if(shutter.dir != expected_dir || open_shutter.dir != expected_dir)
			Fail("Shutters did not align with window junction [junction].")
		if(shutter.icon_state != "closed[suffix]" || open_shutter.icon_state != "open[suffix]")
			Fail("Shutter corner or preopen state is wrong for junction [junction].")
		for(var/door_animation in list(DOOR_OPENING_ANIMATION, DOOR_CLOSING_ANIMATION))
			shutter.animation = door_animation
			shutter.update_icon_state()
			if(!(shutter.icon_state in icon_states(shutter.icon)))
				Fail("Missing animated icon state [shutter.icon_state].")
		shutter.animation = null
		shutter.update_icon_state()
	if(open_shutter.density || open_shutter.opacity)
		Fail("Preopen shutters must start non-dense and transparent.")
