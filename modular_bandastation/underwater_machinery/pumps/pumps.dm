/// Water reaches the intake through the existing floodwater flow, never through sealed walls.
/obj/machinery/bilge_pump
	name = "трюмная помпа"
	desc = "Собирает воду в трубный буфер. Включается контроллером помп; ЛКМ открывает ближайший контроллер своей группы. Требует АПЦ; оставляет слой 0,5 см. Выход водяной трубы — на юге."
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/drains.dmi'
	icon_state = "active_input"
	density = FALSE
	idle_power_usage = 5
	processing_flags = NONE
	/// Centimetres removed from the intake tile each second.
	var/drain_rate = 100
	var/on = FALSE
	var/residual_depth = 0.5
	var/buffer_capacity = 10000
	var/control_group = "water"

/obj/machinery/bilge_pump/Initialize(mapload)
	. = ..()
	create_reagents(buffer_capacity, NO_REACT)
	AddComponent(/datum/component/plumbing/stationtrauma_water/supply)
	AddElement(/datum/element/simple_rotation)

/obj/machinery/bilge_pump/Destroy()
	release_stationtrauma_water(src)
	return ..()

/obj/machinery/bilge_pump/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	control_pump(user)

/obj/machinery/bilge_pump/proc/control_pump(mob/living/user)
	for(var/obj/machinery/stationtrauma_pump_controller/controller in range(7, src))
		if(get_area(controller) == get_area(src) && controller.control_group == control_group)
			controller.ui_interact(user)
			return
	balloon_alert(user, "нужен контроллер")

/obj/machinery/bilge_pump/proc/toggle_pump(mob/living/user)
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
	. += span_notice("Буфер: [round(reagents.total_volume, 0.1)] / [reagents.maximum_volume] л; [round(reagents.chem_temp - T0C, 0.1)] °C. Выход подключается к водяным трубам.")

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
	if(!water || water.infinite_source || water.depth <= residual_depth || reagents.holder_full() || !draw_pump_energy(seconds_per_tick))
		return
	water.remove_water(min(drain_rate * seconds_per_tick, water.depth - residual_depth) * FLOOD_WATER_LITRES_PER_CM, reagents)

/obj/machinery/bilge_pump/plumbed
	name = "трюмная помпа с трубным выходом"

/obj/machinery/bilge_pump/wrench_act(mob/living/user, obj/item/tool)
	return default_unfasten_wrench(user, tool)

/obj/machinery/bilge_pump/portable
	name = "аварийный насос"
	desc = "Переносной насос с баком 200 л и аккумулятором. Ключ — крепление, ЛКМ — меню сбора и слива. Выход водяной трубы — на юге. Отвёртка открывает отсек батареи, лом извлекает её."
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/liquid_pump.dmi'
	icon_state = "liquid_pump"
	density = TRUE
	anchored = FALSE
	use_power = NO_POWER_USE
	drain_rate = 8
	residual_depth = 0
	buffer_capacity = 200
	control_group = "portable"
	var/obj/item/stock_parts/power_store/cell/cell

/obj/machinery/bilge_pump/portable/Initialize(mapload)
	. = ..()
	cell = new /obj/item/stock_parts/power_store/cell/high(src)

/obj/machinery/bilge_pump/portable/Destroy()
	QDEL_NULL(cell)
	return ..()

/obj/machinery/bilge_pump/portable/get_cell()
	return cell

/obj/machinery/bilge_pump/portable/control_pump(mob/living/user)
	var/list/connections = GetComponents(/datum/component/plumbing/stationtrauma_water/supply)
	var/datum/component/plumbing/stationtrauma_water/supply/connection = length(connections) ? connections[1] : null
	var/status = !on ? "выключен" : reagents.holder_full() ? "бак заполнен" : !anchored ? "не закреплён" : panel_open ? "отсек батареи открыт" : !is_operational ? "неисправен" : !cell?.charge ? "нет заряда" : "сбор"
	var/choice = tgui_input_list(user, "Режим: [status]. Бак: [round(reagents.total_volume, 0.1)] / 200 л, [round(reagents.chem_temp - T0C, 0.1)] °C. Заряд: [cell ? round(cell.percent()) : 0]%. Труба: [length(connection?.ducts) ? "подключена" : "нет"].", name, list(on ? "Выключить" : "Включить", "Слить рядом"))
	if(QDELETED(src) || !choice || !user.can_perform_action(src, NEED_DEXTERITY | NEED_HANDS | FORBID_TELEKINESIS_REACH))
		return
	if(choice == "Слить рядом")
		prompt_stationtrauma_water_drain(src, user)
	else if((choice == "Включить") != on)
		toggle_pump(user)

/obj/machinery/bilge_pump/portable/plumbed
	name = "аварийный насос с трубным выходом"

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
