/proc/stationtrauma_parse_flow(value)
	if(value == "max")
		return 200
	var/rate = isnum(value) ? value : text2num("[value]")
	if(!isnum(rate) || !IS_FINITE(rate))
		return null
	return clamp(rate, 0, 200)

/obj/machinery/stationtrauma_pump_controller
	name = "контроллер трюмных помп"
	desc = "ЛКМ — питание и расход в л/с. Управляет помпами своей группы в пределах семи клеток этого отсека. Доступы не требуются."
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/water_controller.dmi'
	icon_state = "controller"
	density = FALSE
	use_power = NO_POWER_USE
	processing_flags = NONE
	var/control_group = "water"
	var/on = FALSE
	var/flow_rate = 100

/obj/machinery/stationtrauma_pump_controller/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	ui_interact(user)

/obj/machinery/stationtrauma_pump_controller/proc/apply_settings()
	for(var/obj/machinery/bilge_pump/pump in range(7, src))
		if(get_area(pump) != get_area(src) || pump.control_group != control_group || istype(pump, /obj/machinery/bilge_pump/portable))
			continue
		pump.drain_rate = flow_rate / FLOOD_WATER_LITRES_PER_CM
		pump.on = on
		if(on)
			pump.begin_processing()
		else
			pump.end_processing()
		pump.update_appearance()
	icon_state = on ? "controller_on" : "controller"

/obj/machinery/stationtrauma_pump_controller/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AtmosPump", name)
		ui.open()

/obj/machinery/stationtrauma_pump_controller/ui_data(mob/user)
	return list("on" = on, "rate" = flow_rate, "max_rate" = 200)

/obj/machinery/stationtrauma_pump_controller/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return
	switch(action)
		if("power")
			on = !on
		if("rate")
			var/rate = stationtrauma_parse_flow(params["rate"])
			if(isnull(rate))
				return FALSE
			flow_rate = rate
		else
			return FALSE
	apply_settings()
	return TRUE

/// The port keeps its empty holder while detached; only a connected open barrel participates in the network.
/datum/component/plumbing/stationtrauma_water/connector
	demand_connects = ALL_CARDINALS
	supply_connects = ALL_CARDINALS

/datum/component/plumbing/stationtrauma_water/connector/send_request(dir)
	var/obj/machinery/stationtrauma_water_device/connector/port = parent
	if(!port.barrel?.valve_open)
		return
	process_request(5000 * SSFLUIDS_DT / max(1, length(ducts)), /datum/reagent/water, dir)

/datum/component/plumbing/stationtrauma_water/connector/can_give(amount, reagent, datum/ductnet/net)
	var/obj/machinery/stationtrauma_water_device/connector/port = parent
	return port.barrel?.valve_open && ..()

/datum/component/plumbing/stationtrauma_water/connector/create_overlays(atom/movable/source, list/overlays)
	return

/obj/machinery/stationtrauma_water_device/connector
	name = "порт водяной бочки"
	desc = "Напольное подключение водяной бочки. Подведите водяную трубу с любой стороны, поставьте бочку сверху и прикрутите ключом."
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/water_controller.dmi'
	icon_state = "port"
	density = FALSE
	plumbing_type = /datum/component/plumbing/stationtrauma_water/connector
	var/obj/machinery/stationtrauma_water_device/barrel/barrel

/obj/machinery/stationtrauma_water_device/connector/Destroy()
	if(barrel)
		barrel.disconnect_port()
	return ..()

/obj/machinery/stationtrauma_water_device/connector/wrench_act(mob/living/user, obj/item/tool)
	if(barrel)
		balloon_alert(user, "сначала снять бочку")
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/stationtrauma_water_device/barrel
	name = "водяная бочка"
	desc = "Переносной резервуар. Поставьте на водяной порт и прикрутите ключом. ЛКМ — клапан, объём, температура и статус подключения. Направление бочки не имеет значения."
	anchored = FALSE
	plumbing_type = null
	var/valve_open = FALSE
	var/start_connected = FALSE
	var/obj/machinery/stationtrauma_water_device/connector/port

/obj/machinery/stationtrauma_water_device/barrel/post_machine_initialize()
	. = ..()
	if(start_connected)
		connect_port()

/obj/machinery/stationtrauma_water_device/barrel/Destroy()
	disconnect_port()
	return ..()

/obj/machinery/stationtrauma_water_device/barrel/proc/connect_port()
	var/obj/machinery/stationtrauma_water_device/connector/found
	for(var/obj/machinery/stationtrauma_water_device/connector/candidate in loc)
		if(candidate.water_level == water_level && !candidate.barrel)
			found = candidate
			break
	if(!found || !found.anchored || found.barrel || QDELETED(found))
		return FALSE
	port = found
	port.barrel = src
	set_anchored(TRUE)
	var/datum/component/plumbing/stationtrauma_water/connector/connection = port.GetComponent(/datum/component/plumbing/stationtrauma_water/connector)
	connection.reagents = reagents
	return TRUE

/obj/machinery/stationtrauma_water_device/barrel/proc/disconnect_port()
	if(port)
		var/datum/component/plumbing/stationtrauma_water/connector/connection = port.GetComponent(/datum/component/plumbing/stationtrauma_water/connector)
		if(connection)
			connection.reagents = port.reagents
		port.barrel = null
		port = null
	set_anchored(FALSE)

/obj/machinery/stationtrauma_water_device/barrel/wrench_act(mob/living/user, obj/item/tool)
	if(port)
		disconnect_port()
		balloon_alert(user, "отсоединена")
	else
		balloon_alert(user, connect_port() ? "подключена" : "нужен свободный порт")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/stationtrauma_water_device/barrel/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	var/list/options = list(valve_open ? "Закрыть клапан" : "Открыть клапан", "Слить рядом")
	var/list/connections = port?.GetComponents(/datum/component/plumbing/stationtrauma_water/connector)
	var/datum/component/plumbing/stationtrauma_water/connector/connection = length(connections) ? connections[1] : null
	var/choice = tgui_input_list(user, "[round(reagents.get_reagent_amount(/datum/reagent/water), 0.1)] / [capacity] л, [round(reagents.chem_temp - T0C, 0.1)] °C. Порт: [port ? "подключена" : "нет"]. Труба: [length(connection?.ducts) ? "подключена" : "нет"]. Клапан: [valve_open ? "открыт" : "закрыт"].", name, options)
	if(QDELETED(src) || !choice || !user.can_perform_action(src, NEED_DEXTERITY | NEED_HANDS | FORBID_TELEKINESIS_REACH))
		return
	if(choice == "Слить рядом")
		if(valve_open)
			prompt_stationtrauma_water_drain(src, user)
		else
			balloon_alert(user, "клапан закрыт")
	else
		valve_open = choice == "Открыть клапан"

/obj/machinery/stationtrauma_water_device/barrel/examine(mob/user)
	. = ..()
	. += span_notice("Клапан [valve_open ? "открыт" : "закрыт"]. Бочка [port ? "подключена к порту" : "не подключена"].")

/datum/component/plumbing/stationtrauma_water/inline_pump/send_request(dir)
	var/obj/machinery/stationtrauma_water_device/inline_pump/pump = parent
	if(!pump.on || !pump.is_operational || pump.flow_rate <= 0)
		return
	var/energy = 750 * SSFLUIDS_DT
	if(pump.use_energy(energy, force = FALSE) < energy)
		return
	process_request(pump.flow_rate * SSFLUIDS_DT, /datum/reagent/water, dir)

/datum/component/plumbing/stationtrauma_water/inline_pump/can_give(amount, reagent, datum/ductnet/net)
	var/obj/machinery/stationtrauma_water_device/inline_pump/pump = parent
	return pump.on && pump.is_operational && ..()

/obj/machinery/stationtrauma_water_device/inline_pump
	name = "насос водяного контура"
	desc = "Направленный насос: вход с запада, выход с востока. ЛКМ — питание и расход в л/с; ключ и Alt+ЛКМ — крепление и поворот."
	icon_state = "liquid_pump"
	icon = 'modular_bandastation/underwater_machinery/pumps/icons/liquid_pump.dmi'
	density = FALSE
	capacity = 10000
	use_power = IDLE_POWER_USE
	idle_power_usage = 5
	plumbing_type = /datum/component/plumbing/stationtrauma_water/inline_pump
	var/on = FALSE
	var/flow_rate = 100

/obj/machinery/stationtrauma_water_device/inline_pump/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	ui_interact(user)

/obj/machinery/stationtrauma_water_device/inline_pump/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AtmosPump", name)
		ui.open()

/obj/machinery/stationtrauma_water_device/inline_pump/ui_data(mob/user)
	return list("on" = on, "rate" = flow_rate, "max_rate" = 200)

/obj/machinery/stationtrauma_water_device/inline_pump/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return
	if(action == "power")
		on = !on
		return TRUE
	if(action == "rate")
		var/rate = stationtrauma_parse_flow(params["rate"])
		if(isnull(rate))
			return FALSE
		flow_rate = rate
		return TRUE
	return FALSE

/obj/machinery/stationtrauma_water_device/outlet/overboard
	name = "забортный выпуск воды"
	desc = "Подведите водяную трубу к западному входу, разверните наружной стороной к соседнему океану. ЛКМ — питание и расход. Выпуск против внешнего давления требует АПЦ."
	capacity = 10000
	var/flow_rate = 100
	var/discharged_volume = 0

/obj/machinery/stationtrauma_water_device/outlet/overboard/process(seconds_per_tick)
	if(!on)
		return PROCESS_KILL
	if(!anchored || !is_operational || !isturf(loc))
		return
	var/turf/open/outside = get_step(src, turn(dir, 90))
	var/datum/component/floodwater/ocean = outside?.GetComponent(/datum/component/floodwater)
	if(!ocean?.infinite_source)
		return
	var/energy = 1200 * seconds_per_tick
	if(use_energy(energy, force = FALSE) < energy)
		return
	var/amount = stationtrauma_water_transfer_amount(reagents, flow_rate * seconds_per_tick, INFINITY)
	if(amount)
		reagents.remove_reagent(/datum/reagent/water, amount)
		discharged_volume += amount

/obj/machinery/stationtrauma_water_device/outlet/overboard/control_outlet(mob/living/user)
	ui_interact(user)

/obj/machinery/stationtrauma_water_device/outlet/overboard/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AtmosPump", name)
		ui.open()

/obj/machinery/stationtrauma_water_device/outlet/overboard/ui_data(mob/user)
	return list("on" = on, "rate" = flow_rate, "max_rate" = 200)

/obj/machinery/stationtrauma_water_device/outlet/overboard/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return
	if(action == "power")
		on = !on
		if(on)
			begin_processing()
		else
			end_processing()
		return TRUE
	if(action == "rate")
		var/rate = stationtrauma_parse_flow(params["rate"])
		if(isnull(rate))
			return FALSE
		flow_rate = rate
		return TRUE
	return FALSE

/obj/machinery/stationtrauma_water_device/outlet/overboard/examine(mob/user)
	. = ..()
	. += span_notice("Сброшено в океан: [round(discharged_volume, 0.1)] л. Расход: [flow_rate] л/с.")
