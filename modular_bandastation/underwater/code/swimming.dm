/datum/movespeed_modifier/floodwater
	variable = TRUE

/// Occupants, rather than every ocean tile, process swimming and breathing.
/datum/status_effect/floodwater
	id = "floodwater"
	alert_type = null
	status_type = STATUS_EFFECT_UNIQUE
	tick_interval = 2 SECONDS

/datum/status_effect/floodwater/on_apply()
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(update_water))
	RegisterSignal(owner, COMSIG_CARBON_PRE_BREATHE, PROC_REF(before_breath))
	return TRUE

/datum/status_effect/floodwater/on_remove()
	UnregisterSignal(owner, list(COMSIG_MOVABLE_MOVED, COMSIG_CARBON_PRE_BREATHE))
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/floodwater)
	owner.refresh_gravity()

/datum/status_effect/floodwater/proc/current_water()
	if(!isopenturf(owner.loc))
		return null
	return owner.loc.GetComponent(/datum/component/floodwater)

/datum/status_effect/floodwater/proc/update_water()
	SIGNAL_HANDLER
	var/datum/component/floodwater/water = current_water()
	if(!water)
		qdel(src)
		return
	var/slowdown = water.affects(owner) && !HAS_TRAIT(owner, TRAIT_SWIMMER) ? water.stage * 0.75 : 0
	owner.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/floodwater, multiplicative_slowdown = slowdown)

/// Keep the normal lungs/species/tank checks, including empty tanks and invalid masks.
/datum/status_effect/floodwater/proc/before_breath(mob/living/carbon/swimmer)
	SIGNAL_HANDLER
	var/datum/component/floodwater/water = current_water()
	if(!water?.head_underwater(swimmer) || HAS_TRAIT(swimmer, TRAIT_NODROWN) || HAS_TRAIT(swimmer, TRAIT_NOBREATH))
		return
	if(swimmer.invalid_internals())
		swimmer.cutoff_internals()
	if(!swimmer.internal && !swimmer.external)
		// The standard breathe() now checks an empty breath instead of inhaling the room's air.
		swimmer.losebreath = max(swimmer.losebreath, 1)

/datum/status_effect/floodwater/tick(seconds_between_ticks)
	var/datum/component/floodwater/water = current_water()
	if(!water)
		qdel(src)
		return
	update_water()
	if(owner.stat == DEAD || !water.affects(owner))
		return
	if(water.depth >= FLOOD_WATER_DEEP && !HAS_TRAIT(owner, TRAIT_SWIMMER))
		var/skill = owner.mind?.get_skill_level(/datum/skill/athletics) || 0
		var/cost = max(0.5, 2 - skill * 0.25) * seconds_between_ticks
		owner.apply_damage(HAS_TRAIT(owner, TRAIT_STRENGTH) ? cost / 2 : cost, STAMINA)
	if(isbasicmob(owner) && water.head_underwater(owner) && !HAS_TRAIT(owner, TRAIT_NODROWN) && !HAS_TRAIT(owner, TRAIT_NOBREATH))
		var/mob/living/basic/swimmer = owner
		if(swimmer.unsuitable_atmos_damage)
			swimmer.adjust_oxy_loss(2 * seconds_between_ticks)
