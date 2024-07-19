/// Voidwalker eyes with nightvision and thermals
/obj/item/organ/internal/eyes/voidwalker
	name = "blackened orbs"
	desc = "These orbs will withstand the light of the sun, yet still see within the darkest voids."
	eye_icon_state = null
	pepperspray_protect = TRUE
	flash_protect = FLASH_PROTECTION_WELDER
	color_cutoffs = list(20, 10, 40)
	sight_flags = SEE_MOBS

/// Voidwalker brain stacked with a lot of the abilities
/obj/item/organ/internal/brain/voidwalker
	name = "cosmic brain"
	desc = "A mind fully integrated into the cosmic thread."
	icon = 'icons/obj/medical/organs/shadow_organs.dmi'

	/// Alpha we have in space
	var/space_alpha = 15
	/// Alpha we have elsewhere
	var/non_space_alpha = 255
	/// We settle the un
	var/datum/action/unsettle = /datum/action/cooldown/spell/pointed/unsettle
	/// Regen effect we have in space
	var/datum/status_effect/regen = /datum/status_effect/space_regeneration
	/// Speed modifier given when in gravity
	var/datum/movespeed_modifier/speed_modifier = /datum/movespeed_modifier/grounded_voidwalker
	/// The void eater weapon
	var/obj/item/glass_breaker = /obj/item/void_eater

/obj/item/organ/internal/brain/voidwalker/on_mob_insert(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()

	RegisterSignal(organ_owner, COMSIG_ATOM_ENTERING, PROC_REF(on_atom_entering))

	organ_owner.AddComponent(/datum/component/space_camo, space_alpha, non_space_alpha, 2 SECONDS)
	organ_owner.apply_status_effect(regen)

	unsettle = new unsettle(organ_owner)
	unsettle.Grant(organ_owner)

	glass_breaker = new/obj/item/void_eater
	organ_owner.put_in_hands(glass_breaker)

/obj/item/organ/internal/brain/voidwalker/on_mob_remove(mob/living/carbon/organ_owner, special)
	. = ..()

	UnregisterSignal(organ_owner, COMSIG_ENTER_AREA)
	alpha = 255

	qdel(organ_owner.GetComponent(/datum/component/space_camo))
	organ_owner.remove_status_effect(regen)

	unsettle.Remove(organ_owner)
	unsettle = initial(unsettle)

	if(glass_breaker)
		qdel(glass_breaker)

/obj/item/organ/internal/brain/voidwalker/proc/on_atom_entering(mob/living/carbon/organ_owner, atom/entering)
	SIGNAL_HANDLER

	if(!isturf(entering))
		return

	var/turf/new_turf = entering

	//apply debufs for being in gravity
	if(new_turf.has_gravity())
		organ_owner.add_movespeed_modifier(speed_modifier)
	//remove debufs for not being in gravity
	else
		organ_owner.remove_movespeed_modifier(speed_modifier)

/obj/item/organ/internal/brain/voidwalker/on_death()
	. = ..()

	var/turf/spawn_loc = get_turf(owner)
	new /obj/effect/spawner/glass_shards (spawn_loc)
	new /obj/item/cosmic_skull (spawn_loc)
	playsound(get_turf(owner), SFX_SHATTER, 100)

	qdel(owner)

/obj/item/implant/radio/voidwalker
	radio_key = /obj/item/encryptionkey/heads/captain
	actions_types = null

/obj/effect/spawner/glass_shards
	/// Weighted list for the shards we spawn
	var/list/shards = list(/obj/item/shard = 2, /obj/item/shard/plasma = 1, /obj/item/shard/titanium = 1, /obj/item/shard/plastitanium = 1)
	/// Min shards we generate
	var/min_spawn = 4
	/// Max shards we generate
	var/max_spawn = 6
	/// The we can apply when generating
	var/pixel_offset = 16

/obj/effect/spawner/glass_shards/Initialize(mapload)
	. = ..()

	for(var/i in 1 to rand(min_spawn, max_spawn))
		var/shard_type = pick_weight(shards)
		var/obj/shard = new shard_type (loc)
		shard.pixel_x = rand(-pixel_offset, pixel_offset)
		shard.pixel_y = rand(-pixel_offset, pixel_offset)

/obj/effect/spawner/glass_shards/mini
	min_spawn = 1
	max_spawn = 2
