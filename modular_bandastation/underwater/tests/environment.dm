#define SALVAGE_TEST(assertion, reason) if(!(assertion)) { return Fail(reason, __FILE__, __LINE__) }

/datum/unit_test/underwater_salvage/Run()
	var/mob/living/carbon/human/consistent/engineer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/structure/underwater_scrap/scrap = allocate(/obj/structure/underwater_scrap, run_loc_floor_bottom_left)
	var/obj/item/weldingtool/welder = allocate(/obj/item/weldingtool)
	engineer.put_in_active_hand(welder, forced = TRUE)
	scrap.welder_act(engineer, welder)
	SALVAGE_TEST(!QDELETED(scrap), "An unlit welder must not destroy salvage")
	welder.set_welding(TRUE)
	welder.toolspeed = 0
	scrap.welder_act(engineer, welder)
	SALVAGE_TEST(QDELETED(scrap), "Successful welding must remove the salvage")
	var/obj/item/stack/sheet/iron/sheets = locate() in run_loc_floor_bottom_left
	SALVAGE_TEST(sheets, "Salvaging must produce usable iron")
	SALVAGE_TEST(sheets.amount == 5, "One wreck fragment must yield five sheets")
	allocated += sheets
	for(var/flora_type in subtypesof(/obj/structure/flora/underwater) + /obj/structure/flora/underwater)
		var/obj/structure/flora/underwater/flora = allocate(flora_type)
		SALVAGE_TEST(flora.icon_state in icon_states(flora.icon), "Underwater flora must have a valid sprite")

#ifdef FLOODWATER_TEST_ONLY
TEST_FOCUS(/datum/unit_test/underwater_salvage)
#endif

#undef SALVAGE_TEST
