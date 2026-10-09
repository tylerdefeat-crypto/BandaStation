/// Water reaches the intake through the existing floodwater flow, never through sealed walls.
/obj/machinery/bilge_pump
	name = "трюмная помпа"
	desc = "Осушает пол под собой. ЛКМ — включить или выключить. Требует питания от АПЦ отсека."
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/drains.dmi'
	icon_state = "active_input"
	density = FALSE
	idle_power_usage = 5
	processing_flags = NONE
	/// Centimetres removed from the intake tile each second.
	var/drain_rate = 20
	var/on = FALSE
	/// Optional TG plumbing buffer; ordinary bilges retain their overboard discharge.
	var/plumbed = FALSE

/obj/machinery/bilge_pump/Initialize(mapload)
	. = ..()
	if(plumbed)
		create_reagents(200, NO_REACT)
		AddComponent(/datum/component/plumbing/stationtrauma_water/supply)
		AddElement(/datum/element/simple_rotation)

/obj/machinery/bilge_pump/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	on = !on
	if(on)
		begin_processing()
	else
		end_processing()
	balloon_alert(user, on ? "включена" : "выключена")
	update_appearance()

/obj/machinery/bilge_pump/examine(mob/user)
	. = ..()
	. += span_notice("Помпа [on ? "включена" : "выключена"]. Скорость осушения у заборника: [drain_rate] см/с.")
	if(plumbed)
		. += span_notice("Буфер: [round(reagents.total_volume, 0.1)] / [reagents.maximum_volume] л; [round(reagents.chem_temp - T0C, 0.1)] °C. Выход подключается к трубам plumbing TG.")

/obj/machinery/bilge_pump/proc/draw_pump_energy(seconds_per_tick)
	if(!is_operational)
		return FALSE
	var/required_energy = 1200 * seconds_per_tick
	return use_energy(required_energy, force = FALSE) >= required_energy

/obj/machinery/bilge_pump/process(seconds_per_tick)
	if(!on)
		return PROCESS_KILL
	if(!anchored || !isopenturf(loc))
		return
	var/turf/open/intake = loc
	var/datum/component/floodwater/water = intake.GetComponent(/datum/component/floodwater)
	if(!water || water.infinite_source || reagents?.holder_full() || !draw_pump_energy(seconds_per_tick))
		return
	water.remove_water(drain_rate * FLOOD_WATER_LITRES_PER_CM * seconds_per_tick, reagents)

/obj/machinery/bilge_pump/plumbed
	name = "трюмная помпа с трубным выходом"
	plumbed = TRUE

/obj/machinery/bilge_pump/wrench_act(mob/living/user, obj/item/tool)
	return default_unfasten_wrench(user, tool)

/obj/machinery/bilge_pump/portable
	name = "аварийный насос"
	desc = "Переносной насос со сменным аккумулятором. Закрепите ключом и включите ЛКМ. Отвёртка открывает отсек батареи, лом извлекает её."
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/liquid_pump.dmi'
	icon_state = "liquid_pump"
	density = TRUE
	anchored = FALSE
	use_power = NO_POWER_USE
	drain_rate = 8
	var/obj/item/stock_parts/power_store/cell/cell

/obj/machinery/bilge_pump/portable/Initialize(mapload)
	. = ..()
	cell = new /obj/item/stock_parts/power_store/cell/high(src)

/obj/machinery/bilge_pump/portable/Destroy()
	QDEL_NULL(cell)
	return ..()

/obj/machinery/bilge_pump/portable/get_cell()
	return cell

/obj/machinery/bilge_pump/portable/plumbed
	name = "аварийный насос с трубным выходом"
	plumbed = TRUE

/obj/machinery/bilge_pump/portable/draw_pump_energy(seconds_per_tick)
	if(!is_operational || panel_open)
		return FALSE
	var/required_energy = 50 * seconds_per_tick
	return cell?.use(required_energy, force = FALSE) >= required_energy

/obj/machinery/bilge_pump/portable/examine(mob/user)
	. = ..()
	. += span_notice("Заряд: [cell ? "[round(cell.percent())]%" : "нет аккумулятора"]. Насос [anchored ? "закреплён" : "не закреплён"].")

/obj/machinery/bilge_pump/portable/screwdriver_act(mob/living/user, obj/item/tool)
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/bilge_pump/portable/crowbar_act(mob/living/user, obj/item/tool)
	if(!panel_open || !cell)
		return NONE
	cell.forceMove(drop_location())
	cell = null
	return ITEM_INTERACT_SUCCESS

/obj/machinery/bilge_pump/portable/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stock_parts/power_store/cell))
		return ..()
	if(!panel_open || cell || !user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	cell = tool
	return ITEM_INTERACT_SUCCESS
