// A small TG-native prototype inspired by NSV AGCNR; no NSV gas or ship dependencies.
#define ST_REACTOR_WARNING (T0C + 350)
#define ST_REACTOR_SCRAM (T0C + 450)
#define ST_REACTOR_DAMAGE (T0C + 500)
#define ST_REACTOR_SERVICE (T0C + 80)

/obj/item/stationtrauma_fuel_rod
	name = "топливная кассета AGCNR"
	desc = "Сменная кассета упрощённого газоохлаждаемого реактора."
	icon = 'icons/obj/stack_objects.dmi'
	icon_state = "sheet-uranium"
	w_class = WEIGHT_CLASS_NORMAL
	/// Full-power operating seconds remaining; retained when the cartridge is removed.
	var/fuel_remaining = 1800

/obj/item/stationtrauma_fuel_rod/examine(mob/user)
	. = ..()
	. += span_notice("Остаток топлива: [round(100 * fuel_remaining / initial(fuel_remaining))]%.")

/obj/item/stationtrauma_control_rod
	name = "управляющий стержень AGCNR"
	desc = "Поглотитель, необходимый для управления реакцией и аварийной остановки."
	icon = 'icons/obj/stack_objects.dmi'
	icon_state = "rods"
	w_class = WEIGHT_CLASS_NORMAL

/obj/machinery/power/stationtrauma_reactor
	name = "газоохлаждаемый реактор AGCNR"
	desc = "ЛКМ — мощность или SCRAM. Лом извлекает кассету, затем управляющий стержень из остановленного холодного реактора. Охлаждающий насос должен стоять рядом."
	icon_state = "rtg"
	density = TRUE
	max_integrity = 400
	integrity_failure = 0.5
	var/obj/item/stationtrauma_fuel_rod/fuel_rod
	var/obj/item/stationtrauma_control_rod/control_rod
	var/core_temperature = T20C
	var/running = FALSE
	/// One means fully inserted, zero means full requested output.
	var/rod_insertion = 1
	var/decay_heat = 0
	var/generated_power = 0
	var/warning = FALSE

/obj/machinery/power/stationtrauma_reactor/Initialize(mapload)
	. = ..()
	control_rod = new(src)
	connect_to_network()

/obj/machinery/power/stationtrauma_reactor/Destroy()
	// Preserve removable parts when the casing is destroyed.
	fuel_rod?.forceMove(drop_location())
	control_rod?.forceMove(drop_location())
	fuel_rod = null
	control_rod = null
	return ..()

/obj/machinery/power/stationtrauma_reactor/proc/set_output(fraction)
	if(!is_operational || !fuel_rod || fuel_rod.fuel_remaining <= 0 || !control_rod || core_temperature >= ST_REACTOR_SCRAM)
		return FALSE
	rod_insertion = 1 - clamp(fraction, 0, 1)
	running = rod_insertion < 1
	update_appearance()
	return TRUE

/obj/machinery/power/stationtrauma_reactor/proc/scram()
	running = FALSE
	rod_insertion = 1
	generated_power = 0
	update_appearance()

/obj/machinery/power/stationtrauma_reactor/process(seconds_per_tick)
	if(running && (!is_operational || !control_rod || !fuel_rod || fuel_rod.fuel_remaining <= 0 || core_temperature >= ST_REACTOR_SCRAM))
		scram()
		visible_message(span_warning("[src]: аварийная остановка! Охлаждение необходимо сохранять."))
	generated_power = 0
	var/thermal_power = 0
	if(running)
		var/fraction = min(1 - rod_insertion, fuel_rod.fuel_remaining / seconds_per_tick)
		fuel_rod.fuel_remaining = max(0, fuel_rod.fuel_remaining - fraction * seconds_per_tick)
		thermal_power = 60000 * fraction
		decay_heat = max(decay_heat, thermal_power * 0.15)
		generated_power = 30000 * fraction
		add_avail(generated_power * seconds_per_tick)
	// shortcut: lumped heat capacity and residual heat, replace only if engineering playtests need more states.
	core_temperature += (thermal_power + decay_heat) * seconds_per_tick / 5000
	decay_heat *= 0.995 ** seconds_per_tick
	var/new_warning = core_temperature >= ST_REACTOR_WARNING
	if(new_warning && !warning)
		visible_message(span_danger("[src]: перегрев активной зоны! Проверьте охлаждение."))
		playsound(src, 'sound/machines/warning-buzzer.ogg', 40, FALSE)
	warning = new_warning
	if(core_temperature >= ST_REACTOR_DAMAGE)
		scram()
		take_damage(20 * seconds_per_tick, BURN, FIRE)

/obj/machinery/power/stationtrauma_reactor/proc/exchange_heat(datum/gas_mixture/coolant)
	var/gas_capacity = coolant.heat_capacity()
	if(gas_capacity <= MINIMUM_HEAT_CAPACITY || coolant.temperature >= core_temperature)
		return 0
	var/energy = (core_temperature - coolant.temperature) / (1 / 5000 + 1 / gas_capacity)
	core_temperature -= energy / 5000
	coolant.temperature += energy / gas_capacity
	return energy

/obj/machinery/power/stationtrauma_reactor/examine(mob/user)
	. = ..()
	. += span_notice("Состояние: [running ? "работает" : "SCRAM"]. Температура: [round(core_temperature - T0C)] °C. Мощность: [round(generated_power / 1000)] кВт. Стержень введён на [round(rod_insertion * 100)]%.")
	. += span_notice("Топливо: [fuel_rod ? "[round(100 * fuel_rod.fuel_remaining / initial(fuel_rod.fuel_remaining))]%" : "нет кассеты"]. Управляющий стержень: [control_rod ? "установлен" : "отсутствует"]. Остаточное тепло: [round(decay_heat / 1000, 0.1)] кВт.")
	if(warning)
		. += span_danger("Перегрев! Авто-SCRAM при 450 °C, повреждение корпуса при 500 °C.")

/obj/machinery/power/stationtrauma_reactor/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	var/choice = tgui_input_list(user, "Зона: [round(core_temperature - T0C)] °C. Мощность: [round(generated_power / 1000)] кВт. После SCRAM сохраняйте охлаждение.", name, list("SCRAM", "Мощность 25%", "Мощность 50%", "Мощность 100%"))
	if(!choice || !user.can_perform_action(src, NEED_DEXTERITY | NEED_HANDS))
		return
	if(choice == "SCRAM")
		scram()
		balloon_alert(user, "аварийная остановка")
		return
	var/list/outputs = list("Мощность 25%" = 0.25, "Мощность 50%" = 0.5, "Мощность 100%" = 1)
	balloon_alert(user, set_output(outputs[choice]) ? "мощность задана" : "запуск запрещён")

/obj/machinery/power/stationtrauma_reactor/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stationtrauma_fuel_rod) && !istype(tool, /obj/item/stationtrauma_control_rod))
		return ..()
	if(running || core_temperature > ST_REACTOR_SERVICE)
		balloon_alert(user, "сначала остановите и охладите")
		return ITEM_INTERACT_BLOCKING
	if((istype(tool, /obj/item/stationtrauma_fuel_rod) && fuel_rod) || (istype(tool, /obj/item/stationtrauma_control_rod) && control_rod))
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	if(istype(tool, /obj/item/stationtrauma_fuel_rod))
		fuel_rod = tool
	else
		control_rod = tool
	return ITEM_INTERACT_SUCCESS

/obj/machinery/power/stationtrauma_reactor/crowbar_act(mob/living/user, obj/item/tool)
	if(running || core_temperature > ST_REACTOR_SERVICE)
		balloon_alert(user, "сначала остановите и охладите")
		return ITEM_INTERACT_BLOCKING
	var/obj/item/removed = fuel_rod || control_rod
	if(!removed || !tool.use_tool(src, user, 1 SECONDS, volume = 30))
		return ITEM_INTERACT_BLOCKING
	if(running || core_temperature > ST_REACTOR_SERVICE || removed.loc != src)
		return ITEM_INTERACT_BLOCKING
	if(removed == fuel_rod)
		fuel_rod = null
	else
		control_rod = null
	removed.forceMove(drop_location())
	return ITEM_INTERACT_SUCCESS

#undef ST_REACTOR_WARNING
#undef ST_REACTOR_SCRAM
#undef ST_REACTOR_DAMAGE
#undef ST_REACTOR_SERVICE
