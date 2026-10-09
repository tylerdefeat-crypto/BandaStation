/// Circulates real TG gas through the adjacent core; disconnected or unpowered pipes cannot cool it.
/obj/machinery/atmospherics/components/binary/stationtrauma_coolant_pump
	name = "насос охлаждения AGCNR"
	desc = "Прокачивает газ через соседний реактор. ЛКМ — включить или выключить. Контур должен возвращаться через океанский теплообменник."
	icon_state = "pump_map-3"
	pipe_state = "pump"
	shift_underlay_only = FALSE
	can_unwrench = FALSE
	var/flow_rate = 100

/obj/machinery/atmospherics/components/binary/stationtrauma_coolant_pump/attack_hand(mob/living/user, list/modifiers)
	if(..())
		return
	set_on(!on)
	balloon_alert(user, on ? "включён" : "выключен")

/obj/machinery/atmospherics/components/binary/stationtrauma_coolant_pump/update_icon_nopipes()
	icon_state = "pump_[on && is_operational ? "on" : "off"]-[set_overlay_offset(piping_layer)]"

/obj/machinery/atmospherics/components/binary/stationtrauma_coolant_pump/process_atmos(seconds_per_tick)
	if(!on || !is_operational || !nodes[1] || !nodes[2] || !parents[1] || !parents[2])
		return
	var/datum/gas_mixture/input = airs[1]
	if(input.total_moles() <= 0)
		return
	var/required_energy = 750 * seconds_per_tick
	if(use_energy(required_energy, force = FALSE) < required_energy)
		return
	var/datum/gas_mixture/packet = input.remove_ratio(min(1, flow_rate * seconds_per_tick / input.volume))
	for(var/obj/machinery/power/stationtrauma_reactor/reactor in orange(1, src))
		reactor.exchange_heat(packet)
		break
	var/datum/gas_mixture/output = airs[2]
	output.merge(packet)
	update_parents()

/// Initial charge for the manual test rig; normal devices require a filled pipeline.
/obj/machinery/atmospherics/components/binary/stationtrauma_coolant_pump/precharged/Initialize(mapload)
	. = ..()
	var/datum/gas_mixture/input = airs[1]
	input.moles[/datum/gas/nitrogen] = 400
	input.temperature = T0C + 4

/obj/machinery/atmospherics/components/unary/stationtrauma_ocean_exchanger
	name = "океанский теплообменник"
	desc = "Отводит тепло из газового контура в соседний внешний океан. Работает пассивно; затопление комнаты не заменяет внешний океан."
	icon_state = "he1"
	pipe_state = "heunary"
	use_power = NO_POWER_USE
	can_unwrench = FALSE

/obj/machinery/atmospherics/components/unary/stationtrauma_ocean_exchanger/process_atmos(seconds_per_tick)
	if(!is_operational || !nodes[1] || !parents[1])
		return
	var/turf/open/space/ocean/ocean
	for(var/turf/open/space/ocean/nearby in orange(1, src))
		ocean = nearby
		break
	if(!ocean)
		return
	var/datum/gas_mixture/coolant = airs[1]
	var/capacity = coolant.heat_capacity()
	if(capacity <= MINIMUM_HEAT_CAPACITY || coolant.temperature <= ocean.temperature)
		return
	var/energy = min(150000 * seconds_per_tick, (coolant.temperature - ocean.temperature) * capacity)
	coolant.temperature -= energy / capacity
	update_parents()
