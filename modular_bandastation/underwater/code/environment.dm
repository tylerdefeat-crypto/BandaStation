// Flora artwork and salvage concept: CeladonSS13/Nodalec; see ATTRIBUTION.md.
/obj/structure/flora/underwater
	name = "водоросли"
	desc = "Морская растительность, колышущаяся в темноте."
	icon = 'modular_bandastation/underwater/icons/ocean_flora.dmi'
	icon_state = "seaweed1"
	harvestable = FALSE

/obj/structure/flora/underwater/long
	icon_state = "longseaweed1"

/obj/structure/flora/underwater/glowing
	name = "светящиеся водоросли"
	icon_state = "glowweed1"
	light_color = LIGHT_COLOR_CYAN
	light_range = 1.5

/obj/structure/flora/underwater/coral
	name = "коралл"
	icon_state = "coral1"
	density = TRUE

/obj/structure/underwater_scrap
	name = "ржавый металлолом"
	desc = "Обломок затонувшей конструкции. Его можно разобрать сваркой."
	icon = 'modular_bandastation/underwater/icons/scrap.dmi'
	icon_state = "scrap1"
	anchored = TRUE
	density = TRUE

/obj/structure/underwater_scrap/welder_act(mob/living/user, obj/item/tool)
	if(!tool.tool_start_check(user, amount = 0))
		return ITEM_INTERACT_BLOCKING
	if(!tool.use_tool(src, user, 5 SECONDS, volume = 50))
		return ITEM_INTERACT_BLOCKING
	new /obj/item/stack/sheet/iron(drop_location(), 5)
	qdel(src)
	return ITEM_INTERACT_SUCCESS
