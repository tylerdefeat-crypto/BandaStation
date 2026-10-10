/// Water-only adapters over TG's duct networks; one holder unit represents one litre here.
// shortcut: use a sealed vessel circuit, rebuild boundary duct networks before supporting dock-side hoses.
/datum/component/plumbing/stationtrauma_water
	dupe_mode = COMPONENT_DUPE_UNIQUE
	demand_connects = WEST
	supply_connects = EAST
	ducting_layer = STATIONTRAUMA_WATER_LAYER

/datum/component/plumbing/stationtrauma_water/send_request(dir)
	var/obj/machinery/machine = parent
	if(!machine.anchored || (machine.machine_stat & BROKEN))
		return
	if(istype(machine, /obj/machinery/stationtrauma_water_device/valve))
		var/obj/machinery/stationtrauma_water_device/valve/valve = machine
		if(!valve.valve_open)
			return
	var/rate = 5000
	if(istype(machine, /obj/machinery/stationtrauma_water_device/outlet/overboard))
		var/obj/machinery/stationtrauma_water_device/outlet/overboard/outlet = machine
		rate = outlet.flow_rate
	process_request(rate * SSFLUIDS_DT, /datum/reagent/water, dir)

/datum/component/plumbing/stationtrauma_water/can_give(amount, reagent, datum/ductnet/net)
	var/obj/machinery/machine = parent
	if(!machine.anchored || (machine.machine_stat & BROKEN) || (reagent && reagent != /datum/reagent/water))
		return FALSE
	if(istype(machine, /obj/machinery/stationtrauma_water_device/valve))
		var/obj/machinery/stationtrauma_water_device/valve/valve = machine
		if(!valve.valve_open)
			return FALSE
	return ..(amount, /datum/reagent/water, net)

/datum/component/plumbing/stationtrauma_water/transfer_to(datum/component/plumbing/target, amount, reagent, datum/ductnet/net, round_robin = TRUE)
	return transfer_stationtrauma_water(reagents, target.recipient_reagents_holder(), amount)

/datum/component/plumbing/stationtrauma_water/supply
	demand_connects = NONE
	supply_connects = SOUTH

/datum/component/plumbing/stationtrauma_water/outlet
	demand_connects = WEST
	supply_connects = NONE

/obj/machinery/stationtrauma_water_device
	name = "водяной резервуар"
	desc = "Резервуар водяного контура. Вход — с запада, выход — с востока; обычные трубы plumbing TG. Ключ — крепление, Alt+ЛКМ — поворот после открепления."
	icon = 'icons/obj/pipes_n_cables/hydrochem/plumbers.dmi'
	icon_state = "tank"
	density = TRUE
	use_power = NO_POWER_USE
	processing_flags = NONE
	var/capacity = 1000
	/// Mapper charge for test fixtures; normal reservoirs start empty.
	var/initial_water = 0
	var/initial_temperature = T0C + 4
	var/water_level = 3
	var/plumbing_type = /datum/component/plumbing/stationtrauma_water

/obj/machinery/stationtrauma_water_device/Initialize(mapload, new_level)
	if(new_level in 1 to 5)
		water_level = new_level
	. = ..()
	create_reagents(capacity, NO_REACT)
	reagents.set_temperature(initial_temperature)
	if(initial_water > 0)
		reagents.add_reagent(/datum/reagent/water, initial_water, reagtemp = initial_temperature, no_react = TRUE)
	if(plumbing_type)
		AddComponent(plumbing_type, STATIONTRAUMA_WATER_LAYER_BIT(water_level))
		AddElement(/datum/element/simple_rotation)

/obj/machinery/stationtrauma_water_device/Destroy()
	release_stationtrauma_water(src)
	return ..()

/obj/machinery/stationtrauma_water_device/examine(mob/user)
	. = ..()
	. += span_notice("Вода: [round(reagents.get_reagent_amount(/datum/reagent/water), 0.1)] / [reagents.maximum_volume] л. Температура: [round(reagents.chem_temp - T0C, 0.1)] °C. Уровень труб: [water_level].")

/obj/machinery/stationtrauma_water_device/wrench_act(mob/living/user, obj/item/tool)
	return default_unfasten_wrench(user, tool)

/obj/machinery/stationtrauma_water_device/valve
	name = "клапан водяного контура"
	desc = "ЛКМ — открыть или закрыть. Закрытый клапан не принимает и не отдаёт воду. Вход — с запада, выход — с востока."
	icon_state = "filter"
	density = FALSE
	capacity = 10000
	var/valve_open = FALSE

/obj/machinery/stationtrauma_water_device/valve/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	valve_open = !valve_open
	balloon_alert(user, valve_open ? "открыт" : "закрыт")
	update_appearance()

/obj/machinery/stationtrauma_water_device/valve/examine(mob/user)
	. = ..()
	. += span_notice("Клапан [valve_open ? "открыт" : "закрыт"].")

/obj/machinery/stationtrauma_water_device/outlet
	name = "выпуск водяного контура"
	desc = "ЛКМ — включить или выключить. Выпускает до 100 л/с на пол под собой; требует питания АПЦ. Вход трубы — с запада."
	icon_state = "pipe_output"
	density = FALSE
	capacity = 200
	plumbing_type = /datum/component/plumbing/stationtrauma_water/outlet
	use_power = IDLE_POWER_USE
	idle_power_usage = 5
	var/on = FALSE

/obj/machinery/stationtrauma_water_device/outlet/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	control_outlet(user)

/obj/machinery/stationtrauma_water_device/outlet/proc/control_outlet(mob/living/user)
	on = !on
	if(on)
		begin_processing()
	else
		end_processing()
	balloon_alert(user, on ? "включён" : "выключен")

/obj/machinery/stationtrauma_water_device/outlet/process(seconds_per_tick)
	if(!on)
		return PROCESS_KILL
	if(!anchored || !is_operational || !isopenturf(loc) || !reagents.get_reagent_amount(/datum/reagent/water))
		return
	var/turf/open/tile = loc
	var/datum/component/floodwater/water = tile.GetComponent(/datum/component/floodwater)
	if(water?.infinite_source || tile.get_water_depth() >= FLOOD_WATER_MAX_DEPTH)
		return
	var/required_energy = 750 * seconds_per_tick
	if(use_energy(required_energy, force = FALSE) < required_energy)
		return
	tile.receive_water(reagents, 100 * seconds_per_tick)

/obj/machinery/stationtrauma_water_device/outlet/examine(mob/user)
	. = ..()
	. += span_notice("Выпуск [on ? "включён" : "выключен"].")

/proc/drain_stationtrauma_water(atom/movable/source, turf/open/target)
	if(!source)
		return 0
	var/turf/open/origin = get_turf(source)
	if(!isopenturf(origin) || !isopenturf(target) || QDELETED(source.reagents))
		return 0
	if(target != origin && !origin.can_pass_stationtrauma_water(target))
		return 0
	return target.receive_water(source.reagents, source.reagents.get_reagent_amount(/datum/reagent/water))

/proc/prompt_stationtrauma_water_drain(atom/movable/source, mob/living/user)
	var/list/directions = list("Под собой" = NONE, "Север" = NORTH, "Юг" = SOUTH, "Запад" = WEST, "Восток" = EAST)
	var/choice = tgui_input_list(user, "Куда слить воду? Переполнение останется в баке.", "Слив воды", directions)
	if(QDELETED(source) || !choice || !user.can_perform_action(source, NEED_DEXTERITY | NEED_HANDS | FORBID_TELEKINESIS_REACH))
		return
	var/turf/open/origin = get_turf(source)
	var/turf/open/target = directions[choice] ? get_step(origin, directions[choice]) : origin
	var/volume = drain_stationtrauma_water(source, target)
	source.balloon_alert(user, volume ? "слито [round(volume, 0.1)] л" : "слив невозможен")

/proc/release_stationtrauma_water(atom/movable/source)
	if(!source.reagents?.total_volume)
		return
	var/turf/open/origin = get_turf(source)
	if(isopenturf(origin))
		drain_stationtrauma_water(source, origin)
		for(var/direction in GLOB.cardinals)
			var/turf/open/target = get_step(origin, direction)
			drain_stationtrauma_water(source, target)
	if(source.reagents.total_volume)
		var/obj/item/stationtrauma_water_canister/remainder = new(source.drop_location())
		var/volume = source.reagents.get_reagent_amount(/datum/reagent/water)
		remainder.create_reagents(max(volume, CHEMICAL_VOLUME_ROUNDING), NO_REACT)
		transfer_stationtrauma_water(source.reagents, remainder.reagents, volume)

/obj/item/stationtrauma_water_canister
	name = "ёмкость с остатком воды"
	desc = "Вода из разобранного или разрушенного прибора. Используйте в руке, чтобы слить её на доступный пол."
	icon = 'icons/obj/pipes_n_cables/hydrochem/plumbers.dmi'
	icon_state = "tank"
	w_class = WEIGHT_CLASS_BULKY

/obj/item/stationtrauma_water_canister/examine(mob/user)
	. = ..()
	. += span_notice("Вода: [round(reagents?.total_volume, 0.1)] л; [round((reagents?.chem_temp || FLOOD_WATER_TEMPERATURE) - T0C, 0.1)] °C.")

/obj/item/stationtrauma_water_canister/attack_self(mob/user)
	if(isliving(user))
		prompt_stationtrauma_water_drain(src, user)
