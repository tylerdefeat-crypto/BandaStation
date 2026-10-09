/// Water-only adapters over TG's duct networks; one holder unit represents one litre here.
// shortcut: use a sealed vessel circuit, rebuild boundary duct networks before supporting dock-side hoses.
/datum/component/plumbing/stationtrauma_water
	demand_connects = WEST
	supply_connects = EAST

/datum/component/plumbing/stationtrauma_water/send_request(dir)
	var/obj/machinery/machine = parent
	if(!machine.anchored || (machine.machine_stat & BROKEN))
		return
	if(istype(machine, /obj/machinery/stationtrauma_water_device/valve))
		var/obj/machinery/stationtrauma_water_device/valve/valve = machine
		if(!valve.valve_open)
			return
	process_request(200 * SSFLUIDS_DT, /datum/reagent/water, dir)

/datum/component/plumbing/stationtrauma_water/can_give(amount, reagent, datum/ductnet/net)
	var/obj/machinery/machine = parent
	if(!machine.anchored || (machine.machine_stat & BROKEN) || (reagent && reagent != /datum/reagent/water))
		return FALSE
	if(istype(machine, /obj/machinery/stationtrauma_water_device/valve))
		var/obj/machinery/stationtrauma_water_device/valve/valve = machine
		if(!valve.valve_open)
			return FALSE
	return ..(amount, /datum/reagent/water, net)

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
	var/plumbing_type = /datum/component/plumbing/stationtrauma_water

/obj/machinery/stationtrauma_water_device/Initialize(mapload)
	. = ..()
	create_reagents(capacity, NO_REACT)
	reagents.set_temperature(initial_temperature)
	if(initial_water > 0)
		reagents.add_reagent(/datum/reagent/water, initial_water, reagtemp = initial_temperature, no_react = TRUE)
	AddComponent(plumbing_type)
	AddElement(/datum/element/simple_rotation)

/obj/machinery/stationtrauma_water_device/examine(mob/user)
	. = ..()
	. += span_notice("Вода: [round(reagents.get_reagent_amount(/datum/reagent/water), 0.1)] / [reagents.maximum_volume] л. Температура: [round(reagents.chem_temp - T0C, 0.1)] °C.")

/obj/machinery/stationtrauma_water_device/wrench_act(mob/living/user, obj/item/tool)
	return default_unfasten_wrench(user, tool)

/obj/machinery/stationtrauma_water_device/valve
	name = "клапан водяного контура"
	desc = "ЛКМ — открыть или закрыть. Закрытый клапан не принимает и не отдаёт воду. Вход — с запада, выход — с востока."
	icon_state = "filter"
	density = FALSE
	capacity = 400
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
