
/obj/item/bodypart/proc/can_dismember(obj/item/item)
	if(dismemberable)
		return TRUE

///Remove target limb from it's owner, with side effects.
/obj/item/bodypart/proc/dismember(dismember_type = DROPLIMB_EDGE, silent=TRUE, clean = FALSE)
	if(!owner || !dismemberable)
		return FALSE

	var/mob/living/carbon/limb_owner = owner

	if(limb_owner.status_flags & GODMODE)
		return FALSE
	if(HAS_TRAIT(limb_owner, TRAIT_NODISMEMBER))
		return FALSE

	var/obj/item/bodypart/affecting = limb_owner.get_bodypart(BODY_ZONE_CHEST)
	affecting.receive_damage(clamp(brute_dam/2 * affecting.body_damage_coeff, 15, 50), clamp(burn_dam/2 * affecting.body_damage_coeff, 0, 50)) //Damage the chest based on limb's existing damage
	if(!silent)
		limb_owner.visible_message(span_danger("<B>[limb_owner]'s [name] is violently dismembered!</B>"))

	INVOKE_ASYNC(limb_owner, TYPE_PROC_REF(/mob, emote), "scream")
	playsound(get_turf(limb_owner), 'sound/effects/dismember.ogg', 80, TRUE)

	SEND_SIGNAL(limb_owner, COMSIG_ADD_MOOD_EVENT, "dismembered", /datum/mood_event/dismembered)

	limb_owner.mind?.add_memory(MEMORY_DISMEMBERED, list(DETAIL_LOST_LIMB = src, DETAIL_PROTAGONIST = limb_owner), story_value = STORY_VALUE_AMAZING)
	drop_limb()

	limb_owner.update_equipment_speed_mods() // Update in case speed affecting item unequipped by dismemberment
	var/turf/owner_location = limb_owner.loc
	if(istype(owner_location))
		limb_owner.add_splatter_floor(owner_location)

	if(QDELETED(src)) //Could have dropped into lava/explosion/chasm/whatever
		return TRUE

	var/obj/item/bodypart/chest/parent_chest = limb_owner.get_bodypart(BODY_ZONE_CHEST)
	if(!QDELETED(parent_chest))
		var/datum/wound/lost_limb/W = new(src, dismember_type, clean, parent_chest)
		LAZYADD(parent_chest.wounds, W)

	if(dismember_type == DROPLIMB_BURN)
		burn()
		return TRUE

	add_mob_blood(limb_owner)
	limb_owner.bleed(rand(20, 40))
	var/direction = pick(GLOB.cardinals)

	if(!clean)
		var/t_range = rand(2,max(throw_range/2, 2))
		var/turf/target_turf = get_turf(src)
		for(var/i in 1 to t_range-1)
			var/turf/new_turf = get_step(target_turf, direction)
			if(!new_turf)
				break
			target_turf = new_turf
			if(new_turf.density)
				break
		throw_at(target_turf, throw_range, throw_speed)

		if(dismember_type == DROPLIMB_BLUNT)
			limb_owner.spray_blood(direction, 2)

	return TRUE


/obj/item/bodypart/chest/dismember()
	if(!owner)
		return FALSE

	var/mob/living/carbon/chest_owner = owner
	if(!dismemberable)
		return FALSE

	if(HAS_TRAIT(chest_owner, TRAIT_NODISMEMBER))
		return FALSE
	. = list()
	if(isturf(chest_owner.loc))
		chest_owner.add_splatter_floor(chest_owner.loc)
	playsound(get_turf(chest_owner), 'sound/misc/splort.ogg', 80, TRUE)
	for(var/obj/item/organ/organ as anything in chest_owner.internal_organs)
		var/org_zone = check_zone(organ.zone)
		if(org_zone != BODY_ZONE_CHEST)
			continue
		organ.Remove(chest_owner)
		organ.forceMove(chest_owner.loc)
		. += organ

	for(var/obj/item/organ/external/ext_organ as anything in src.external_organs)
		if(!(ext_organ.organ_flags & ORGAN_UNREMOVABLE))
			ext_organ.Remove(chest_owner)
			ext_organ.forceMove(chest_owner.loc)
			. += ext_organ

	if(cavity_item)
		cavity_item.forceMove(chest_owner.loc)
		. += cavity_item
		cavity_item = null



///limb removal. The "special" argument is used for swapping a limb with a new one without the effects of losing a limb kicking in.
/obj/item/bodypart/proc/drop_limb(special, dismembered)
	if(!owner)
		return
	var/atom/drop_loc = owner.drop_location()

	SEND_SIGNAL(owner, COMSIG_CARBON_REMOVE_LIMB, src, dismembered)
	update_limb(1)

	owner.remove_bodypart(src)

	if(held_index)
		if(owner.hand_bodyparts[held_index] == src)
			// We only want to do this if the limb being removed is the active hand part.
			// This catches situations where limbs are "hot-swapped" such as augmentations and roundstart prosthetics.
			owner.dropItemToGround(owner.get_item_for_held_index(held_index), 1)
			owner.hand_bodyparts[held_index] = null

	for(var/obj/item/organ/external/ext_organ as anything in external_organs)
		ext_organ.transfer_to_limb(src, null) //Null is the second arg because the bodypart is being removed from it's owner.

	var/mob/living/carbon/phantom_owner = set_owner(null) // so we can still refer to the guy who lost their limb after said limb forgets 'em

	for(var/datum/surgery/surgery as anything in phantom_owner.surgeries) //if we had an ongoing surgery on that limb, we stop it.
		if(surgery.operated_bodypart == src)
			phantom_owner.surgeries -= surgery
			qdel(surgery)
			break

	for(var/obj/item/embedded in embedded_objects)
		embedded.forceMove(src) // It'll self remove via signal reaction, just need to move it
	if(!phantom_owner.has_embedded_objects())
		phantom_owner.clear_alert(ALERT_EMBEDDED_OBJECT)
		SEND_SIGNAL(phantom_owner, COMSIG_CLEAR_MOOD_EVENT, "embedded")


	for(var/datum/wound/W as anything in wounds)
		W.unregister_from_mob(phantom_owner)

	if(!special)
		if(phantom_owner.dna)
			for(var/datum/mutation/human/mutation as anything in phantom_owner.dna.mutations) //some mutations require having specific limbs to be kept.
				if(mutation.limb_req && mutation.limb_req == body_zone)
					to_chat(phantom_owner, span_warning("You feel your [mutation] deactivating from the loss of your [body_zone]!"))
					phantom_owner.dna.force_lose(mutation)

		for(var/obj/item/organ/organ as anything in phantom_owner.internal_organs) //internal organs inside the dismembered limb are dropped.
			var/org_zone = check_zone(organ.zone)
			if(org_zone != body_zone)
				continue
			organ.transfer_to_limb(src, phantom_owner)

	for(var/trait in bodypart_traits)
		REMOVE_TRAIT(phantom_owner, trait, bodypart_trait_source)

	update_icon_dropped()
	synchronize_bodytypes(phantom_owner)
	phantom_owner.update_health_hud() //update the healthdoll
	phantom_owner.update_body()
	phantom_owner.update_body_parts()

	if(!drop_loc) // drop_loc = null happens when a "dummy human" used for rendering icons on prefs screen gets its limbs replaced.
		if(!QDELETED(src))
			qdel(src)
		return

	if(is_pseudopart)
		drop_organs(phantom_owner) //Psuedoparts shouldn't have organs, but just in case
		if(!QDELETED(src))
			qdel(src)
		return

	forceMove(drop_loc)

///Transfers the organ to the limb, and to the limb's owner, if it has one. This is done on drop_limb().
/obj/item/organ/proc/transfer_to_limb(obj/item/bodypart/bodypart, mob/living/carbon/bodypart_owner)
	Remove(bodypart_owner)
	add_to_limb(bodypart)

///Adds the organ to a bodypart, used in transfer_to_limb()
/obj/item/organ/proc/add_to_limb(obj/item/bodypart/bodypart)
	forceMove(bodypart)

///Removes the organ from the limb, placing it into nullspace.
/obj/item/organ/proc/remove_from_limb()
	moveToNullspace()

/obj/item/organ/internal/brain/transfer_to_limb(obj/item/bodypart/head/head, mob/living/carbon/human/head_owner)
	Remove(head_owner) //Changeling brain concerns are now handled in Remove
	forceMove(head)
	head.brain = src
	if(brainmob)
		head.brainmob = brainmob
		brainmob = null
		head.brainmob.forceMove(head)
		head.brainmob.set_stat(DEAD)

/obj/item/organ/internal/eyes/transfer_to_limb(obj/item/bodypart/head/head, mob/living/carbon/human/head_owner)
	head.eyes = src
	..()

/obj/item/organ/internal/ears/transfer_to_limb(obj/item/bodypart/head/head, mob/living/carbon/human/head_owner)
	head.ears = src
	..()

/obj/item/organ/internal/tongue/transfer_to_limb(obj/item/bodypart/head/head, mob/living/carbon/human/head_owner)
	head.tongue = src
	..()

/obj/item/bodypart/chest/drop_limb(special)
	if(special)
		return ..()

/obj/item/bodypart/arm/right/drop_limb(special)
	. = ..()

	var/mob/living/carbon/arm_owner = owner
	if(arm_owner && !special)
		if(arm_owner.handcuffed)
			arm_owner.handcuffed.forceMove(drop_location())
			arm_owner.handcuffed.dropped(arm_owner)
			arm_owner.set_handcuffed(null)
			arm_owner.update_handcuffed()
		if(arm_owner.hud_used)
			var/atom/movable/screen/inventory/hand/R_hand = arm_owner.hud_used.hand_slots["[held_index]"]
			if(R_hand)
				R_hand.update_appearance()
		if(arm_owner.gloves)
			arm_owner.dropItemToGround(arm_owner.gloves, TRUE)
		arm_owner.update_worn_gloves() //to remove the bloody hands overlay


/obj/item/bodypart/arm/left/drop_limb(special)
	var/mob/living/carbon/arm_owner = owner
	. = ..()
	if(arm_owner && !special)
		if(arm_owner.handcuffed)
			arm_owner.handcuffed.forceMove(drop_location())
			arm_owner.handcuffed.dropped(arm_owner)
			arm_owner.set_handcuffed(null)
			arm_owner.update_handcuffed()
		if(arm_owner.hud_used)
			var/atom/movable/screen/inventory/hand/L_hand = arm_owner.hud_used.hand_slots["[held_index]"]
			if(L_hand)
				L_hand.update_appearance()
		if(arm_owner.gloves)
			arm_owner.dropItemToGround(arm_owner.gloves, TRUE)
		arm_owner.update_worn_gloves() //to remove the bloody hands overlay


/obj/item/bodypart/leg/right/drop_limb(special)
	if(owner && !special)
		if(owner.legcuffed)
			owner.legcuffed.forceMove(owner.drop_location()) //At this point bodypart is still in nullspace
			owner.legcuffed.dropped(owner)
			owner.legcuffed = null
			owner.update_worn_legcuffs()
		if(owner.shoes)
			owner.dropItemToGround(owner.shoes, TRUE)
	return ..()

/obj/item/bodypart/leg/left/drop_limb(special) //copypasta
	if(owner && !special)
		if(owner.legcuffed)
			owner.legcuffed.forceMove(owner.drop_location())
			owner.legcuffed.dropped(owner)
			owner.legcuffed = null
			owner.update_worn_legcuffs()
		if(owner.shoes)
			owner.dropItemToGround(owner.shoes, TRUE)
	return ..()

/obj/item/bodypart/head/drop_limb(special)
	if(!special)
		//Drop all worn head items
		for(var/obj/item/head_item as anything in list(owner.glasses, owner.ears, owner.wear_mask, owner.head))
			owner.dropItemToGround(head_item, force = TRUE)

	qdel(owner.GetComponent(/datum/component/creamed)) //clean creampie overlay flushed emoji

	//Handle dental implants
	for(var/datum/action/item_action/hands_free/activate_pill/pill_action in owner.actions)
		pill_action.Remove(owner)
		var/obj/pill = pill_action.target
		if(pill)
			pill.forceMove(src)

	name = "[owner.real_name]'s head"
	return ..()

///Try to attach this bodypart to a mob, while replacing one if it exists, does nothing if it fails.
/obj/item/bodypart/proc/replace_limb(mob/living/carbon/limb_owner, special)
	if(!istype(limb_owner))
		return
	var/obj/item/bodypart/old_limb = limb_owner.get_bodypart(body_zone)
	if(old_limb)
		old_limb.drop_limb(TRUE)

	. = attach_limb(limb_owner, special)
	if(!.) //If it failed to replace, re-attach their old limb as if nothing happened.
		old_limb.attach_limb(limb_owner, TRUE)

///Attach src to target mob if able.
/obj/item/bodypart/proc/attach_limb(mob/living/carbon/new_limb_owner, special)
	if(SEND_SIGNAL(new_limb_owner, COMSIG_CARBON_ATTACH_LIMB, src, special) & COMPONENT_NO_ATTACH)
		return FALSE

	var/obj/item/bodypart/chest/mob_chest = new_limb_owner.get_bodypart(BODY_ZONE_CHEST)
	if(mob_chest && !(mob_chest.acceptable_bodytype & bodytype) && !special)
		return FALSE

	moveToNullspace()
	set_owner(new_limb_owner)
	new_limb_owner.add_bodypart(src)
	if(held_index)
		if(held_index > new_limb_owner.hand_bodyparts.len)
			new_limb_owner.hand_bodyparts.len = held_index
		new_limb_owner.hand_bodyparts[held_index] = src
		if(new_limb_owner.dna.species.mutanthands && !is_pseudopart)
			new_limb_owner.put_in_hand(new new_limb_owner.dna.species.mutanthands(), held_index)
		if(new_limb_owner.hud_used)
			var/atom/movable/screen/inventory/hand/hand = new_limb_owner.hud_used.hand_slots["[held_index]"]
			if(hand)
				hand.update_appearance()
		new_limb_owner.update_worn_gloves()

	if(special) //non conventional limb attachment
		for(var/datum/surgery/attach_surgery as anything in new_limb_owner.surgeries) //if we had an ongoing surgery to attach a new limb, we stop it.
			var/surgery_zone = check_zone(attach_surgery.location)
			if(surgery_zone == body_zone)
				new_limb_owner.surgeries -= attach_surgery
				qdel(attach_surgery)
				break

	for(var/obj/item/organ/limb_organ in contents)
		limb_organ.Insert(new_limb_owner, TRUE)

	for(var/datum/wound/W as anything in wounds)
		W.register_to_mob(new_limb_owner)

	if(check_bones() & CHECKBONES_BROKEN)
		apply_bone_break(new_limb_owner)

	//Remove any stumps that may be present there, since we have a limb now
	if(mob_chest)
		for(var/datum/wound/lost_limb/W in mob_chest.wounds)
			if(W.zone == src.body_zone)
				qdel(W)
				break

	update_bodypart_damage_state()
	if(can_be_disabled)
		update_disabled()

	for(var/trait in bodypart_traits)
		ADD_TRAIT(owner, trait, bodypart_trait_source)

	// Bodyparts need to be sorted for leg masking to be done properly. It also will allow for some predictable
	// behavior within said bodyparts list. We sort it here, as it's the only place we make changes to bodyparts.
	new_limb_owner.bodyparts = sort_list(new_limb_owner.bodyparts, GLOBAL_PROC_REF(cmp_bodypart_by_body_part_asc))
	synchronize_bodytypes(new_limb_owner)
	new_limb_owner.updatehealth()
	new_limb_owner.update_body()
	new_limb_owner.update_damage_overlays()
	return TRUE

/obj/item/bodypart/head/attach_limb(mob/living/carbon/new_head_owner, special = FALSE, abort = FALSE)
	// These are stored before calling super. This is so that if the head is from a different body, it persists its appearance.
	var/real_name = src.real_name

	. = ..()
	if(!.)
		return .
	//Transfer some head appearance vars over
	if(brain)
		if(brainmob)
			brainmob.container = null //Reset brainmob head var.
			brainmob.forceMove(brain) //Throw mob into brain.
			brain.brainmob = brainmob //Set the brain to use the brainmob
			brainmob = null //Set head brainmob var to null
		brain.Insert(new_head_owner) //Now insert the brain proper
		brain = null //No more brain in the head

	if(tongue)
		tongue = null
	if(ears)
		ears = null
	if(eyes)
		eyes = null

	if(real_name)
		new_head_owner.real_name = real_name
	real_name = ""

	//Handle dental implants
	for(var/obj/item/reagent_containers/pill/pill in src)
		for(var/datum/action/item_action/hands_free/activate_pill/pill_action in pill.actions)
			pill.forceMove(new_head_owner)
			pill_action.Grant(new_head_owner)
			break

	///Transfer existing hair properties to the new human.
	if(!special && ishuman(new_head_owner))
		var/mob/living/carbon/human/sexy_chad = new_head_owner
		sexy_chad.hairstyle = hair_style
		sexy_chad.hair_color = hair_color
		sexy_chad.facial_hair_color = facial_hair_color
		sexy_chad.facial_hairstyle = facial_hairstyle
		if(hair_gradient_style || facial_hair_gradient_style)
			LAZYSETLEN(sexy_chad.grad_style, GRADIENTS_LEN)
			LAZYSETLEN(sexy_chad.grad_color, GRADIENTS_LEN)
			sexy_chad.grad_style[GRADIENT_HAIR_KEY] =  hair_gradient_style
			sexy_chad.grad_color[GRADIENT_HAIR_KEY] =  hair_gradient_color
			sexy_chad.grad_style[GRADIENT_FACIAL_HAIR_KEY] = facial_hair_gradient_style
			sexy_chad.grad_color[GRADIENT_FACIAL_HAIR_KEY] = facial_hair_gradient_color

	new_head_owner.updatehealth()
	new_head_owner.update_body()
	new_head_owner.update_damage_overlays()

///Makes sure that the owner's bodytype flags match the flags of all of it's parts.
/obj/item/bodypart/proc/synchronize_bodytypes(mob/living/carbon/carbon_owner)
	if(!carbon_owner?.dna?.species) //carbon_owner and dna can somehow be null during garbage collection, at which point we don't care anyway.
		return
	var/all_limb_flags
	for(var/obj/item/bodypart/limb as anything in carbon_owner.bodyparts)
		for(var/obj/item/organ/external/ext_organ as anything in limb.external_organs)
			all_limb_flags = all_limb_flags | ext_organ.external_bodytypes
		all_limb_flags = all_limb_flags | limb.bodytype

	carbon_owner.dna.species.bodytype = all_limb_flags

//Regenerates all limbs. Returns amount of limbs regenerated
/mob/living/proc/regenerate_limbs(list/excluded_zones = list())
	SEND_SIGNAL(src, COMSIG_LIVING_REGENERATE_LIMBS, excluded_zones)

/mob/living/carbon/regenerate_limbs(list/excluded_zones = list())
	SEND_SIGNAL(src, COMSIG_LIVING_REGENERATE_LIMBS, excluded_zones)
	var/list/zone_list = list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_R_ARM, BODY_ZONE_L_ARM, BODY_ZONE_R_LEG, BODY_ZONE_L_LEG)
	if(length(excluded_zones))
		zone_list -= excluded_zones
	for(var/limb_zone in zone_list)
		regenerate_limb(limb_zone)

/mob/living/proc/regenerate_limb(limb_zone)
	return

/mob/living/carbon/regenerate_limb(limb_zone)
	var/obj/item/bodypart/limb
	if(get_bodypart(limb_zone))
		return FALSE
	limb = newBodyPart(limb_zone, 0, 0)
	if(limb)
		if(!limb.attach_limb(src, 1))
			qdel(limb)
			return FALSE
		limb.update_limb(is_creating = TRUE)
		//Copied from /datum/species/proc/on_species_gain()
		for(var/obj/item/organ/external/organ_path as anything in dna.species.external_organs)
			//Load a persons preferences from DNA
			var/zone = initial(organ_path.zone)
			if(zone != limb_zone)
				continue
			var/obj/item/organ/external/new_organ = SSwardrobe.provide_type(organ_path)
			new_organ.Insert(src)

		update_body_parts()
		return TRUE
