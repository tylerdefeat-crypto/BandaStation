/// A local RPD catalogue keeps the ordinary station dispenser and gas recipes unchanged.
/obj/item/pipe_dispenser/stationtrauma
	name = "RPD водяных систем"
	desc = "Обычный RPD с каталогом «Вода»: секции водяных труб, порт, бочка, насос, вентиль, теплообменник, выпуск и контроллер. Водяная сеть отделена от газовых труб и химических duct."
	var/water_recipe = 1
	mode = (1<<0) | (1<<1)
	var/static/list/water_recipes = list(
		"Водяная мультитруба" = /obj/machinery/duct/stationtrauma,
		"Межуровневый коллектор" = /obj/machinery/duct/stationtrauma/manifold,
		"Порт бочки" = /obj/machinery/stationtrauma_water_device/connector,
		"Бочка 1000 л" = /obj/machinery/stationtrauma_water_device/barrel,
		"Трубный насос" = /obj/machinery/stationtrauma_water_device/inline_pump,
		"Вентиль" = /obj/machinery/stationtrauma_water_device/valve,
		"Забортный выпуск" = /obj/machinery/stationtrauma_water_device/outlet/overboard,
		"Выпуск на пол" = /obj/machinery/stationtrauma_water_device/outlet,
		"Трюмная помпа" = /obj/machinery/bilge_pump,
		"Контроллер помп" = /obj/machinery/stationtrauma_pump_controller,
		"Переносной насос" = /obj/machinery/bilge_pump/portable,
		"Водяной теплообменник" = /obj/machinery/stationtrauma_water_device/ocean_exchanger,
	)

/obj/item/pipe_dispenser/stationtrauma/ui_data(mob/user)
	. = ..()
	if(category != 0)
		return
	var/list/choices = list()
	for(var/index in 1 to length(water_recipes))
		var/list/previews = list()
		for(var/direction in GLOB.cardinals)
			previews += list(list("selected" = water_recipe == index && p_dir == direction, "dir" = dir2text(direction), "dir_name" = dir2text(direction), "icon_state" = index <= 2 ? "manifold4w" : "connector", "flipped" = FALSE))
		choices += list(list(
			"pipe_name" = water_recipes[index],
			"pipe_desc" = "Водяное устройство. Мультитрубы автоматически соединяются на выбранных уровнях. Коллектор объединяет уровни. South: насос/вентиль — вход West, выход East. Бочки и порты не требуют ориентации.",
			"pipe_index" = index,
			"previews" = previews,
		))
	.["categories"] += list(list("cat_name" = "Вода", "recipes" = choices))
	if(water_recipe)
		.["selected_category"] = "Вода"
		.["selected_recipe"] = water_recipes[water_recipe]

/obj/item/pipe_dispenser/stationtrauma/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(action == "pipe_type" && params["category"] == "Вода")
		var/index = text2num(params["pipe_type"])
		if(!isnum(index) || !IS_FINITE(index) || index != round(index) || index < 1 || index > length(water_recipes))
			return FALSE
		water_recipe = index
		p_dir = SOUTH
		return TRUE
	if(action == "pipe_type" || action == "category")
		water_recipe = 0
	return ..()

/obj/item/pipe_dispenser/stationtrauma/proc/build_water_fixture(turf/target, index, direction, water_level = 3)
	if(!isnum(index) || index != round(index) || index < 1 || index > length(water_recipes) || !(direction in GLOB.cardinals) || !isnum(water_level) || water_level != round(water_level) || !(water_level in 1 to 5))
		return null
	var/path = water_recipes[water_recipes[index]]
	if(!isopenturf(target) && !(isclosedturf(target) && path == /obj/machinery/stationtrauma_water_device/outlet/overboard))
		return null
	var/layer_bit = path == /obj/machinery/duct/stationtrauma/manifold ? (31 << 5) : STATIONTRAUMA_WATER_LAYER_BIT(water_level)
	if(path != /obj/machinery/stationtrauma_water_device/barrel && path != /obj/machinery/stationtrauma_pump_controller && ducting_layer_check(target, layer_bit))
		return null
	if(path == /obj/machinery/stationtrauma_water_device/barrel)
		if(locate(/obj/machinery/stationtrauma_water_device/barrel) in target)
			return null
	if(path == /obj/machinery/stationtrauma_pump_controller)
		if(locate(/obj/machinery/stationtrauma_pump_controller) in target)
			return null
	var/obj/machinery/built
	if(ispath(path, /obj/machinery/duct/stationtrauma))
		built = new path(target, null, direction, water_level)
	else
		built = new path(target, water_level)
	if(QDELETED(built))
		return null
	built.setDir(direction)
	if(istype(built, /obj/machinery/duct/stationtrauma))
		var/obj/machinery/duct/stationtrauma/pipe = built
		pipe.rebuild_water_connections()
	else if(!istype(built, /obj/machinery/stationtrauma_water_device/barrel) && !istype(built, /obj/machinery/stationtrauma_pump_controller) && !istype(built, /obj/machinery/bilge_pump/portable))
		// Native plumbing scans its surroundings when anchored after rotation.
		built.set_anchored(FALSE)
		built.set_anchored(TRUE)
	return built

/obj/item/pipe_dispenser/stationtrauma/proc/dispense_water_selection(turf/tile, index, direction, list/levels)
	var/list/built = list()
	for(var/water_level in levels)
		if(!isnum(water_level) || water_level != round(water_level) || !(water_level in 1 to 5))
			continue
		if(index <= 2 && !(mode & (1<<1)))
			var/obj/item/stationtrauma_water_pipe_fitting/fitting = new(tile)
			fitting.water_level = water_level
			fitting.bridges_levels = index == 2
			fitting.update_appearance(UPDATE_ICON)
			built += fitting
			continue
		var/obj/machinery/device = build_water_fixture(tile, index, direction, water_level)
		if(device)
			built += device
	return built

/obj/item/pipe_dispenser/stationtrauma/proc/collect_water_fitting(obj/item/stationtrauma_water_pipe_fitting/fitting)
	if(!istype(fitting) || !(mode & (1<<2)))
		return FALSE
	qdel(fitting)
	return TRUE

/obj/item/pipe_dispenser/stationtrauma/interact_with_atom(atom/target, mob/living/user, list/modifiers)
	if(!ISADVANCEDTOOLUSER(user) || !user.can_perform_action(target, NEED_DEXTERITY | NEED_HANDS))
		return ITEM_INTERACT_BLOCKING
	if(collect_water_fitting(target))
		return ITEM_INTERACT_SUCCESS
	if(!water_recipe || category != 0)
		return ..()
	if((mode & (1<<2)) && (istype(target, /obj/machinery/duct/stationtrauma) || istype(target, /obj/machinery/stationtrauma_water_device) || istype(target, /obj/machinery/bilge_pump) || istype(target, /obj/machinery/stationtrauma_pump_controller)))
		qdel(target)
		return ITEM_INTERACT_SUCCESS
	if(!(mode & (1<<0)))
		return ITEM_INTERACT_BLOCKING
	var/turf/tile = get_turf(target)
	if(!isopenturf(tile) && !isclosedturf(tile))
		return ITEM_INTERACT_BLOCKING
	var/index = water_recipe
	var/direction = p_dir
	var/list/levels = list()
	for(var/level in 1 to 5)
		if(pipe_layers & (1 << (level - 1)))
			levels += level
	if(!do_after(user, 0.4 SECONDS, target = tile))
		return ITEM_INTERACT_BLOCKING
	var/list/built = dispense_water_selection(tile, index, direction, levels)
	balloon_alert(user, length(built) ? "установлено: [length(built)]" : "место занято")
	return length(built) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING

/obj/item/pipe_dispenser/stationtrauma/interact_with_atom_secondary(atom/target, mob/living/user, list/modifiers)
	var/obj/machinery/duct/stationtrauma/pipe = target
	if(istype(pipe) && user.can_perform_action(target, NEED_DEXTERITY | NEED_HANDS))
		pipe_layers = (1 << (pipe.water_level - 1))
		balloon_alert(user, "уровень [pipe.water_level]")
		return ITEM_INTERACT_SUCCESS
	return ..()
