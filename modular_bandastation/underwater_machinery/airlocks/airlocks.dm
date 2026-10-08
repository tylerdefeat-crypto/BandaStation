/obj/machinery/door/airlock/highsecurity/underwater
	name = "гермодверь"
	desc = "Тяжёлая круглая створка на боковых направляющих. Вентиль управляет механическими запорами."
	icon = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock.dmi'
	overlays_file = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock.dmi'
	note_overlay_file = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock.dmi'
	assemblytype = /obj/structure/door_assembly/underwater
	normal_integrity = 400
	security_level = 6
	air_tight = TRUE
	has_open_lights = TRUE
	doorOpen = 'sound/machines/airlock/airlockopen.ogg'
	doorClose = 'sound/machines/airlock/airlockclose.ogg'
	/// Mechanical dogs are independent of the powered airlock bolts.
	var/handwheel_locked = FALSE
	var/handwheel_turning = FALSE

/obj/machinery/door/airlock/highsecurity/underwater/examine(mob/user)
	. = ..()
	. += span_notice("Вентиль [handwheel_locked ? "закручен: механические запоры закрыты" : "откручен: механические запоры открыты"]. Alt+ЛКМ — повернуть вентиль, даже без питания.")

/obj/machinery/door/airlock/highsecurity/underwater/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(density && !operating && !handwheel_turning && Adjacent(user))
		context[SCREENTIP_CONTEXT_ALT_LMB] = handwheel_locked ? "Открутить вентиль" : "Закрутить вентиль"
		return CONTEXTUAL_SCREENTIP_SET

/obj/machinery/door/airlock/highsecurity/underwater/click_alt(mob/user)
	if(!isliving(user) || !user.can_perform_action(src, NEED_DEXTERITY | NEED_HANDS | FORBID_TELEKINESIS_REACH))
		return CLICK_ACTION_BLOCKING
	if(!density || operating || handwheel_turning)
		to_chat(user, span_warning("Вентиль можно повернуть только на неподвижной закрытой двери."))
		return CLICK_ACTION_BLOCKING
	if(isElectrified() && shock(user, 100))
		return CLICK_ACTION_BLOCKING
	add_fingerprint(user)
	handwheel_turning = TRUE
	update_appearance()
	user.visible_message(span_notice("[user] поворачивает вентиль [src]."), span_notice("Вы [handwheel_locked ? "откручиваете" : "закручиваете"] вентиль [src]."))
	var/completed = do_after(user, 1 SECONDS, src)
	if(QDELETED(src))
		return CLICK_ACTION_BLOCKING
	handwheel_turning = FALSE
	if(completed && density && !operating)
		handwheel_locked = !handwheel_locked
		playsound(src, handwheel_locked ? boltDown : boltUp, 30, FALSE, 3)
	update_appearance()
	return CLICK_ACTION_SUCCESS

/obj/machinery/door/airlock/highsecurity/underwater/open(forced = DEFAULT_DOOR_CHECKS, mob/living/opener)
	if(handwheel_locked || handwheel_turning)
		return FALSE
	return ..()

/obj/machinery/door/airlock/highsecurity/underwater/update_overlays()
	. = ..()
	if(density && !operating)
		var/wheel_state = "wheel_[handwheel_locked || locked ? "locked" : "unlocked"]"
		if(handwheel_turning)
			wheel_state = "wheel_[handwheel_locked ? "unlocking" : "locking"]"
		. += get_airlock_overlay(wheel_state, icon, src, em_block = TRUE)
		if(handwheel_locked && feedback && hasPower())
			. += get_airlock_overlay("lights_bolts", overlays_file, src, em_block = FALSE)

/obj/machinery/door/airlock/highsecurity/underwater/multi_tile
	name = "большая гермодверь"
	icon = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock_large.dmi'
	overlays_file = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock_large.dmi'
	note_overlay_file = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock_large.dmi'
	assemblytype = /obj/structure/door_assembly/multi_tile/underwater
	multi_tile = TRUE

/obj/machinery/door/airlock/highsecurity/underwater/multi_tile/setDir(newdir)
	. = ..()
	set_bounds()
	if(filler)
		set_filler()

/obj/structure/door_assembly/underwater
	parent_type = /obj/structure/door_assembly/door_assembly_highsecurity
	base_name = "гермодверь"
	icon = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock.dmi'
	overlays_file = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock.dmi'
	airlock_type = /obj/machinery/door/airlock/highsecurity/underwater

/obj/structure/door_assembly/multi_tile/underwater
	base_name = "большая гермодверь"
	icon = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock_large.dmi'
	overlays_file = 'modular_bandastation/underwater_machinery/airlocks/icons/airlock_large.dmi'
	airlock_type = /obj/machinery/door/airlock/highsecurity/underwater/multi_tile
	glass_type = null
	glass = FALSE
	noglass = TRUE
	material_type = /obj/item/stack/sheet/plasteel
	custom_materials = list(/datum/material/alloy/plasteel = SHEET_MATERIAL_AMOUNT * 8)
