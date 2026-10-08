/// Smooth falloff with zero slope at both ends.
/proc/caustics_falloff(distance, reach)
	var/amount = clamp(1 - distance / reach, 0, 1)
	return amount * amount * (3 - 2 * amount)

/// Cached radial masks; callers get a copy so clipping cannot alter the cache.
/proc/caustics_gradient_mask(reach, offset_x = 0, offset_y = 0)
	var/static/list/cache = list()
	var/key = "[reach],[offset_x],[offset_y]"
	if(cache[key])
		return icon(cache[key])
	var/icon/mask = icon('modular_bandastation/underwater_caustics/icons/mask.png')
	for(var/px in 1 to 32)
		for(var/py in 1 to 32)
			var/dx = (px - 16.5) / 32 + offset_x
			var/dy = (py - 16.5) / 32 + offset_y
			var/value = round(255 * caustics_falloff(sqrt(dx ** 2 + dy ** 2), reach))
			mask.DrawBox(rgb(255, 255, 255, value), px, py)
	cache[key] = mask
	return icon(mask)

/// Only the exposed FLOOR triangle of a smoothed closed turf can receive caustics.
/proc/caustics_is_floor(turf/target)
	return isfloorturf(target) || isindestructiblefloor(target)

/proc/caustics_floor_direction(turf/closed/support)
	if(!istype(support) || !(support.smoothing_flags & SMOOTH_DIAGONAL_CORNERS))
		return NONE
	if(!(support.smoothing_junction in list(5, 6, 9, 10, 21, 38, 74, 137)))
		return NONE
	if(support.fixed_underlay?["space"])
		return NONE
	var/floor_direction = REVERSE_DIR(reverse_ndir(support.smoothing_junction))
	if(support.fixed_underlay)
		return floor_direction
	// Match set_smoothed_icon_state(): N/S, E/W, then diagonal; space wins over a later floor.
	for(var/direction in list(floor_direction & (NORTH|SOUTH), floor_direction & (EAST|WEST), floor_direction))
		var/turf/neighbor = get_step(support, direction)
		if(isclosedturf(neighbor))
			continue
		return caustics_is_floor(neighbor) ? floor_direction : NONE
	return NONE

/proc/caustics_floor_mask(direction)
	var/static/list/cache = list()
	var/key = "[direction]"
	if(cache[key])
		return cache[key]
	var/icon/mask = icon('modular_bandastation/underwater_caustics/icons/mask.png')
	mask.DrawBox(rgb(0, 0, 0, 0), 1, 1, 32, 32)
	for(var/py in 1 to 32)
		var/width = (direction & NORTH) ? py - 1 : 32 - py
		if(!width)
			continue
		if(direction & EAST)
			mask.DrawBox(COLOR_WHITE, 33 - width, py, 32, py)
		else
			mask.DrawBox(COLOR_WHITE, 1, py, width, py)
	cache[key] = mask
	return mask

/// Seeing the front of an opaque diagonal wall does not expose the floor behind it.
/proc/caustics_can_receive(turf/target, list/visible)
	if(caustics_is_floor(target))
		return TRUE
	var/direction = caustics_floor_direction(target)
	if(!direction)
		return FALSE
	if(!IS_OPAQUE_TURF(target))
		return TRUE
	for(var/side in list(direction & (NORTH|SOUTH), direction & (EAST|WEST)))
		var/turf/neighbor = get_step(target, side)
		if(caustics_is_floor(neighbor) && !IS_OPAQUE_TURF(neighbor) && (neighbor in visible))
			return TRUE
	return FALSE

/obj/effect/caustics
	abstract_type = /obj/effect/caustics
	name = "caustics controller"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x2"
	invisibility = INVISIBILITY_ABSTRACT
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE
	var/effect_range = 5
	var/effect_alpha = 90
	var/effect_color = "#72DCE8"
	var/list/obj/effect/caustics_tile/visuals = list()

/obj/effect/caustics/Initialize(mapload)
	. = ..()
	effect_range = clamp(effect_range, 1, 12)
	effect_alpha = clamp(effect_alpha, 0, 255)
	return INITIALIZE_HINT_LATELOAD

/obj/effect/caustics/LateInitialize()
	// Atoms late-initialize before smoothing, so diagonal floor underlays do not exist yet.
	if(!SSicon_smooth.initialized)
		RegisterSignal(SSicon_smooth, COMSIG_SUBSYSTEM_POST_INITIALIZE, PROC_REF(smoothing_ready))
		return
	rebuild()

/obj/effect/caustics/proc/smoothing_ready()
	SIGNAL_HANDLER
	UnregisterSignal(SSicon_smooth, COMSIG_SUBSYSTEM_POST_INITIALIZE)
	INVOKE_ASYNC(src, PROC_REF(rebuild))

/obj/effect/caustics/Destroy()
	QDEL_LIST(visuals)
	return ..()

/// ponytail: static mapped geometry; call rebuild() after changing walls/doors or moving the marker.
/obj/effect/caustics/proc/rebuild()
	QDEL_LIST(visuals)
	visuals = list()
	effect_range = clamp(effect_range, 1, 12)
	effect_alpha = clamp(effect_alpha, 0, 255)

/// Assemble floor-clipped masks, then upload one filter per 4x4 block.
/obj/effect/caustics/proc/render_masks(list/masks)
	var/list/blocks = list()
	for(var/turf/target as anything in masks)
		var/icon/gradient = masks[target]
		if(!caustics_is_floor(target))
			var/floor_direction = caustics_floor_direction(target)
			if(!floor_direction)
				continue
			gradient.AddAlphaMask(caustics_floor_mask(floor_direction))
		var/turf/anchor = locate(target.x - (target.x - 1) % 4, target.y - (target.y - 1) % 4, target.z)
		var/icon/block_mask = blocks[anchor]
		if(!block_mask)
			block_mask = icon('modular_bandastation/underwater_caustics/icons/mask.png')
			block_mask.Scale(128, 128)
			block_mask.DrawBox(rgb(0, 0, 0, 0), 1, 1, 128, 128)
			blocks[anchor] = block_mask
		block_mask.Blend(gradient, ICON_OVERLAY, 1 + (target.x - anchor.x) * 32, 1 + (target.y - anchor.y) * 32)
		CHECK_TICK
	for(var/turf/anchor as anything in blocks)
		var/obj/effect/caustics_tile/visual = new(anchor)
		visual.color = effect_color
		visual.alpha = effect_alpha
		visual.add_filter("caustics_falloff", 1, alpha_mask_filter(icon = blocks[anchor]))
		visuals += visual

/obj/effect/caustics/source
	name = "caustics - invisible light source"
	light_power = 0.6

/obj/effect/caustics/source/rebuild()
	. = ..()
	var/turf/origin = get_turf(src)
	if(!origin || IS_OPAQUE_TURF(origin))
		return
	set_light(effect_range, light_power, effect_color)
	var/list/masks = list()
	var/list/visible = view(CEILING(effect_range + 0.5, 1), origin)
	for(var/turf/target in visible)
		if(!caustics_can_receive(target, visible))
			continue
		var/dx = target.x - origin.x
		var/dy = target.y - origin.y
		if(sqrt(dx ** 2 + dy ** 2) > effect_range + 0.71)
			continue
		masks[target] = caustics_gradient_mask(effect_range, dx, dy)
		CHECK_TICK
	render_masks(masks)

/// Shared 128px animation: one object/filter per block, below walls, furniture and mobs.
/obj/effect/caustics_tile
	name = "caustics"
	icon = 'modular_bandastation/underwater_caustics/icons/caustics.dmi'
	icon_state = "caustics"
	plane = FLOOR_PLANE
	layer = ABOVE_OPEN_TURF_LAYER
	blend_mode = BLEND_ADD
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE
	appearance_flags = RESET_COLOR | RESET_ALPHA
	bound_width = 128
	bound_height = 128
