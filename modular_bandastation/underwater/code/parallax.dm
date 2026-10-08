/// Map configuration set by a landmark, independent of the level's current turfs.
GLOBAL_LIST_EMPTY(ocean_parallax_levels)

/// Ocean backgrounds need the space geometry, but not its screen relay that bypasses lighting.
/atom/movable/screen/plane_master/parallax_white/Initialize(mapload, datum/hud/hud_owner, datum/plane_master_group/home, offset)
	. = ..()
	add_relay_to(GET_NEW_PLANE(RENDER_PLANE_EMISSIVE, offset), relay_layer = EMISSIVE_SPACE_LAYER)
	AddComponent(/datum/component/connect_perspective, home, list(COMSIG_MOVABLE_Z_CHANGED = PROC_REF(update_ocean_fullbright)))
	RegisterSignal(home, COMSIG_PLANE_GROUP_PERSPECTIVE_CHANGED, PROC_REF(update_ocean_fullbright))
	update_ocean_fullbright()

/atom/movable/screen/plane_master/parallax_white/proc/update_ocean_fullbright(datum/source)
	SIGNAL_HANDLER
	var/turf/viewing_from = get_turf(home.get_perspective())
	var/ocean_level = FALSE
	if(viewing_from)
		for(var/level in SSmapping.get_connected_levels(viewing_from))
			if(GET_Z_PLANE_OFFSET(level) == offset)
				ocean_level = !!GLOB.ocean_parallax_levels["[level]"]
				break
	var/atom/movable/render_plane_relay/emissive_relay = get_relay_to(GET_NEW_PLANE(RENDER_PLANE_EMISSIVE, offset))
	emissive_relay.color = ocean_level ? GLOB.em_block_color : null

/obj/effect/landmark/ocean_parallax
	name = "ocean parallax (entire z-level)"
	desc = "Назначает океанский параллакс уровню карты при загрузке."

/obj/effect/landmark/ocean_parallax/Initialize(mapload)
	. = ..()
	GLOB.ocean_parallax_levels["[z]"] = TRUE
	// The marker is only map configuration; the theme remains for the round after it disappears.
	return INITIALIZE_HINT_QDEL

/atom/movable/screen/parallax_home
	var/ocean_parallax = FALSE

/// Preserve the native area listener, selecting the environment from the actual perspective z.
/atom/movable/screen/parallax_home/set_perspective_area(area/new_area)
	var/turf/viewing_from = get_turf(perspective)
	var/is_ocean = !!GLOB.ocean_parallax_levels["[viewing_from?.z]"]
	if(ocean_parallax != is_ocean)
		ocean_parallax = is_ocean
		blend_mode = is_ocean ? BLEND_OVERLAY : initial(blend_mode)
		// Large screen backgrounds must not create HUD borders and rescale the viewport.
		appearance_flags = is_ocean ? (initial(appearance_flags) | TILE_BOUND) : initial(appearance_flags)
		regenerate_layers()
	if(perspective_area == new_area)
		return
	if(perspective_area)
		UnregisterSignal(perspective_area, COMSIG_AREA_PARALLAX_DIR_CHANGED)
	perspective_area = new_area
	RegisterSignal(perspective_area, COMSIG_AREA_PARALLAX_DIR_CHANGED, PROC_REF(area_parallax_dir_changed))

/// Keep native preference/layer lifetime handling, replacing only the underwater layer palette.
/atom/movable/screen/parallax_home/regenerate_layers()
	clear_layers()
	if(layers_to_draw == 0 && !draw_old_space)
		return
	parallax_layers_cached = list()
	if(ocean_parallax)
		var/static/list/ocean_layers = list(
			/atom/movable/screen/parallax_layer/ocean/seafloor,
			/atom/movable/screen/parallax_layer/ocean/seafloor/crests,
			/atom/movable/screen/parallax_layer/ocean/haze,
			/atom/movable/screen/parallax_layer/ocean/fine_silt,
			/atom/movable/screen/parallax_layer/ocean/silt,
		)
		// Both terrain layers form one backdrop; preferences still control the atmosphere layers.
		for(var/index in 1 to min(max(1, layers_to_draw) + 1, length(ocean_layers)))
			var/layer_type = ocean_layers[index]
			parallax_layers_cached += new layer_type(null, null, src)
	else
		for(var/space_layer in 1 to layers_to_draw)
			var/atom/movable/screen/parallax_layer/parallax = generate_space_layer(space_layer)
			if(parallax)
				parallax_layers_cached += parallax
		if(draw_old_space)
			parallax_layers_cached += new /atom/movable/screen/parallax_layer/old(null, null, src)
	display_layers()

/atom/movable/screen/parallax_layer/ocean
	blend_mode = BLEND_OVERLAY
	icon_state = ""
	appearance_flags = APPEARANCE_UI | KEEP_TOGETHER | TILE_BOUND

/// A single distant seabed, never tiled. Its margins cover camera movement and larger views.
/atom/movable/screen/parallax_layer/ocean/seafloor
	icon = 'modular_bandastation/underwater/icons/seafloor.png'
	layer = 1
	speed = 0.25
	absolute = TRUE
	// Distant terrain receives much less light than the nearby water and suspended sediment.
	color = "#303E46"

/atom/movable/screen/parallax_layer/ocean/seafloor/update_overlays()
	return list()

/atom/movable/screen/parallax_layer/ocean/seafloor/update_o(new_view)
	if(working_view == new_view)
		return
	working_view = new_view
	var/list/view_size = getviewsize(new_view)
	var/icon/background = icon(initial(icon))
	var/size = CEILING(max(background.Width(), max(view_size[1], view_size[2]) * ICON_SIZE_ALL + max(world.maxx, world.maxy) * speed * 2 + ICON_SIZE_ALL * 2), 1)
	if(size != background.Width())
		background.Scale(size, size)
	icon = background
	// The native home is centred around a 480px cell; centre our larger image on that cell.
	pixel_x = round((480 - size) / 2)
	pixel_y = pixel_x

/// Raised stone shares the seabed's registration, but receives more of the available light.
/atom/movable/screen/parallax_layer/ocean/seafloor/crests
	icon = 'modular_bandastation/underwater/icons/seafloor_crests.png'
	layer = 2
	color = "#A8CDD6"

/atom/movable/screen/parallax_layer/ocean/haze
	icon = 'modular_bandastation/underwater/icons/haze.png'
	layer = 3
	speed = 0.55
	alpha = 45

/atom/movable/screen/parallax_layer/ocean/haze/Initialize(mapload, datum/hud/hud_owner, atom/movable/screen/parallax_home/home, template = FALSE)
	. = ..()
	if(template)
		return
	animate(src, pixel_x = 12, pixel_y = 6, time = 30 SECONDS, loop = -1, easing = SINE_EASING)
	animate(pixel_x = 0, pixel_y = 0, time = 30 SECONDS, easing = SINE_EASING)

/atom/movable/screen/parallax_layer/ocean/fine_silt
	icon = 'modular_bandastation/underwater/icons/fine_silt.png'
	layer = 4
	speed = 0.9
	alpha = 55

/atom/movable/screen/parallax_layer/ocean/silt
	icon = 'modular_bandastation/underwater/icons/silt.png'
	layer = 5
	speed = 1.35
	alpha = 95

/atom/movable/screen/parallax_layer/ocean/silt/Initialize(mapload, datum/hud/hud_owner, atom/movable/screen/parallax_home/home, template = FALSE)
	. = ..()
	if(template)
		return
	animate(src, pixel_x = 5, pixel_y = -10, time = 18 SECONDS, loop = -1, easing = SINE_EASING)
	animate(pixel_x = 0, pixel_y = 0, time = 18 SECONDS, easing = SINE_EASING)
