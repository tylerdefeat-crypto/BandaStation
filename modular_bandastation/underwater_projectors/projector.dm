/// Animated sediment cone with native directional lighting.
/obj/effect/overlay/spotlight/underwater
	name = "underwater light overlay"
	icon = MAP_SWITCH('modular_bandastation/underwater_projectors/icons/projector.dmi', 'modular_bandastation/underwater_projectors/icons/projector_preview.dmi')
	icon_state = "beam_dust"
	dir = NORTH
	pixel_x = -208
	pixel_y = -208
	plane = ABOVE_LIGHTING_PLANE
	layer = LIGHTING_ABOVE_ALL
	blend_mode = BLEND_ADD
	color = "#8CDCE8"
	alpha = 100
	anchored = TRUE
	blocks_emissive = EMISSIVE_BLOCK_NONE
	appearance_flags = RESET_COLOR | RESET_ALPHA
	light_flags = LIGHT_IGNORE_OFFSET
	light_color = "#8CDCE8"
	light_power = 1.5
	/// Length and terminal width in tiles; the tip is at the center of this turf.
	var/beam_range = 6
	var/beam_width = 3
	var/show_particles = TRUE

/obj/effect/overlay/spotlight/underwater/Initialize(mapload)
	. = ..()
	// Also use the animated asset if someone compiles without the CBT define.
	icon = 'modular_bandastation/underwater_projectors/icons/projector.dmi'
	update_beam()

/obj/effect/overlay/spotlight/underwater/setDir(newdir)
	. = ..()
	if(flags_1 & INITIALIZED_1)
		update_beam()

/obj/effect/overlay/spotlight/underwater/set_light_on(new_value)
	. = ..()
	invisibility = light_on ? initial(invisibility) : INVISIBILITY_ABSTRACT

/// Reapply after VV changes to beam size, color or particles.
/obj/effect/overlay/spotlight/underwater/proc/update_beam()
	beam_range = clamp(beam_range, 0.5, 12)
	beam_width = clamp(beam_width, 0.5, 12)
	icon_state = show_particles ? "beam_dust" : "beam"
	transform = matrix().Scale(beam_width / 3, beam_range / 6).Turn(dir2angle(dir))
	set_light(l_range = beam_range, l_color = color, l_angle = 2 * arctan(beam_width / (2 * beam_range)), l_dir = dir, l_on = light_on)
