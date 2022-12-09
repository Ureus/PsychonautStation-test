/**
 *	MEZMERIZE
 *	 Locks a target in place for a certain amount of time.
 *
 * 	Level 2: Additionally mutes
 * 	Level 3: Can be used through face protection
 * 	Level 5: Doesn't need to be facing you anymore
 * 	Level 6: Causes the target to fall asleep
 */

/datum/action/bloodsucker/targeted/mesmerize
	name = "Mesmerize"
	desc = "Dominate the mind of a mortal who can see your eyes."
	button_icon_state = "power_mez"
	power_explanation = "Mesmerize:\n\
		Click any player to attempt to mesmerize them.\n\
		You cannot wear anything covering your face, and both parties must be facing eachother. Obviously, both parties need to not be blind. \n\
		If your target is already mesmerized or a Monster Hunter, the Power will fail.\n\
		Once mesmerized, the target will be unable to move for a certain amount of time, scaling with level.\n\
		At level 2, your target will additionally be Muted.\n\
		At level 3, you will be able to use the power through items covering your face.\n\
		At level 5, you will be able to mesmerize regardless of your target's direction.\n\
		At level 6, you will cause your target to fall asleep.\n\
		Higher levels will increase the time of the mesmerize's freeze."
	power_flags = NONE
	check_flags = BP_CANT_USE_IN_TORPOR|BP_CANT_USE_IN_FRENZY|BP_CANT_USE_WHILE_INCAPACITATED|BP_CANT_USE_WHILE_UNCONSCIOUS
	purchase_flags = BLOODSUCKER_CAN_BUY|VASSAL_CAN_BUY
	bloodcost = 30
	cooldown = 20 SECONDS
	target_range = 8
	power_activates_immediately = FALSE
	prefire_message = "Whom will you subvert to your will?"
	///Our mesmerized target - Prevents several mesmerizes.
	var/datum/weakref/target_ref

/datum/action/bloodsucker/targeted/mesmerize/CheckCanUse(mob/living/carbon/user)
	. = ..()
	if(!.) // Default checks
		return FALSE
	if(!user.getorganslot(ORGAN_SLOT_EYES))
		// Cant use balloon alert, they've got no eyes!
		to_chat(user, span_warning("You have no eyes with which to mesmerize."))
		return FALSE
	// Check: Eyes covered?
	if(istype(user) && (user.is_eyes_covered() && level_current <= 2) || !isturf(user.loc))
		user.balloon_alert(user, "your eyes are concealed from sight.")
		return FALSE
	return TRUE

/datum/action/bloodsucker/targeted/mesmerize/CheckValidTarget(atom/target_atom)
	. = ..()
	if(!.)
		return FALSE
	return isliving(target_atom)

/datum/action/bloodsucker/targeted/mesmerize/CheckCanTarget(atom/target_atom)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/current_target = target_atom // We already know it's carbon due to CheckValidTarget()
	// No mind
	if(!current_target.mind)
		owner.balloon_alert(owner, "[current_target] is mindless.")
		return FALSE
	// Bloodsucker
	if(IS_BLOODSUCKER(current_target))
		owner.balloon_alert(owner, "bloodsuckers are immune to [src].")
		return FALSE
	// Dead/Unconscious
	if(current_target.stat > CONSCIOUS)
		owner.balloon_alert(owner, "[current_target] is not [(current_target.stat == DEAD || HAS_TRAIT(current_target, TRAIT_FAKEDEATH)) ? "alive" : "conscious"].")
		return FALSE
	// Target has eyes?
	if(!current_target.getorganslot(ORGAN_SLOT_EYES) && !issilicon(current_target))
		owner.balloon_alert(owner, "[current_target] has no eyes.")
		return FALSE
	// Target blind?
	if(current_target.eye_blind > 0 && !issilicon(current_target))
		owner.balloon_alert(owner, "[current_target] is blind.")
		return FALSE
	// Facing target?
	if(!is_source_facing_target(owner, current_target)) // in unsorted.dm
		owner.balloon_alert(owner, "you must be facing [current_target].")
		return FALSE
	// Target facing me? (On the floor, they're facing everyone)
	if(((current_target.mobility_flags & MOBILITY_STAND) && !is_source_facing_target(current_target, owner) && level_current <= 4))
		owner.balloon_alert(owner, "[current_target] must be facing you.")
		return FALSE

	// Gone through our checks, let's mark our guy.
	target_ref = WEAKREF(current_target)
	return TRUE

/datum/action/bloodsucker/targeted/mesmerize/FireTargetedPower(atom/target_atom)
	. = ..()

	var/mob/living/user = owner
	var/mob/living/carbon/mesmerized_target = target_ref.resolve()

	if(issilicon(mesmerized_target))
		var/mob/living/silicon/mesmerized = mesmerized_target
		mesmerized.emp_act(EMP_HEAVY)
		owner.balloon_alert(owner, "temporarily shut [mesmerized] down.")
		PowerActivatedSuccessfully() // PAY COST! BEGIN COOLDOWN!
		return

	if(istype(mesmerized_target))
		owner.balloon_alert(owner, "attempting to hypnotically gaze [mesmerized_target]...")

	if(!do_mob(user, mesmerized_target, 4 SECONDS, NONE, TRUE, extra_checks = CALLBACK(src, .proc/ContinueActive, user, mesmerized_target)))
		return

	var/power_time = 9 SECONDS + level_current * 1.5 SECONDS
	if(IS_MONSTERHUNTER(mesmerized_target))
		to_chat(mesmerized_target, span_notice("You feel your eyes burn for a while, but it passes."))
		return
	if(HAS_TRAIT_FROM(mesmerized_target, TRAIT_MUTE, BLOODSUCKER_TRAIT))
		owner.balloon_alert(owner, "[mesmerized_target] is already in a hypnotic gaze.")
		return
	if(iscarbon(mesmerized_target))
		owner.balloon_alert(owner, "successfully mesmerized [mesmerized_target].")
		if(level_current >= 6)
			ADD_TRAIT(mesmerized_target, TRAIT_KNOCKEDOUT, BLOODSUCKER_TRAIT)
		else if(level_current >= 2)
			ADD_TRAIT(mesmerized_target, TRAIT_MUTE, BLOODSUCKER_TRAIT)
		mesmerized_target.Immobilize(power_time)
		mesmerized_target.adjust_silence(power_time)
		//mesmerized_target.silent += power_time / 10 // Silent isn't based on ticks.
		mesmerized_target.next_move = world.time + power_time // <--- Use direct change instead. We want an unmodified delay to their next move // mesmerized_target.changeNext_move(power_time) // check click.dm
		mesmerized_target.notransform = TRUE // <--- Fuck it. We tried using next_move, but they could STILL resist. We're just doing a hard freeze.
		addtimer(CALLBACK(src, .proc/end_mesmerize, user, mesmerized_target), power_time)
	PowerActivatedSuccessfully() // PAY COST! BEGIN COOLDOWN!

/datum/action/bloodsucker/targeted/mesmerize/DeactivatePower()
	target_ref = null
	. = ..()

/datum/action/bloodsucker/targeted/mesmerize/proc/end_mesmerize(mob/living/user, mob/living/target)
	target.notransform = FALSE
	REMOVE_TRAIT(target, TRAIT_KNOCKEDOUT, BLOODSUCKER_TRAIT)
	REMOVE_TRAIT(target, TRAIT_MUTE, BLOODSUCKER_TRAIT)
	// They Woke Up! (Notice if within view)
	if(istype(user) && target.stat == CONSCIOUS && (target in view(6, get_turf(user))))
		owner.balloon_alert(owner, "[target] snapped out of their trance.")

/datum/action/bloodsucker/targeted/mesmerize/ContinueActive(mob/living/user, mob/living/target)
	return ..() && CheckCanUse(user) && CheckCanTarget(target)
