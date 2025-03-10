#define REGENERATION_DELAY 60  // After taking damage, how long it takes for automatic regeneration to begin for megacarps (ty robustin!)

/mob/living/simple_animal/hostile/carp
	name = "space carp"
	desc = "A ferocious, fang-bearing creature that resembles a fish."
	icon = 'icons/mob/carp.dmi'
	icon_state = "base"
	icon_living = "base"
	icon_dead = "base_dead"
	icon_gib = "carp_gib"
	mob_biotypes = MOB_ORGANIC|MOB_BEAST
	movement_type = FLYING
	ai_controller = /datum/ai_controller/hostile_friend
	speak_chance = 0
	turns_per_move = 5
	butcher_results = list(/obj/item/food/fishmeat/carp = 2, /obj/item/stack/sheet/animalhide/carp = 1)
	response_help_continuous = "pets"
	response_help_simple = "pet"
	response_disarm_continuous = "gently pushes aside"
	response_disarm_simple = "gently push aside"
	emote_taunt = list("gnashes")
	taunt_chance = 30
	speed = 0
	maxHealth = 25
	health = 25
	search_objects = 1
	wanted_objects = list(/obj/item/storage/cans)
	harm_intent_damage = 8
	obj_damage = 50
	melee_damage_lower = 20
	melee_damage_upper = 20
	attack_verb_continuous = "bites"
	attack_verb_simple = "bite"
	attack_sound = 'sound/weapons/bite.ogg'
	attack_vis_effect = ATTACK_EFFECT_BITE
	speak_emote = list("gnashes")
	//Space carp aren't affected by cold.
	atmos_requirements = list("min_oxy" = 0, "max_oxy" = 0, "min_plas" = 0, "max_plas" = 0, "min_co2" = 0, "max_co2" = 0, "min_n2" = 0, "max_n2" = 0)
	minbodytemp = 0
	maxbodytemp = 1500
	faction = list("carp")
	//pressure_resistance = 200
	gold_core_spawnable = HOSTILE_SPAWN
	/// If the carp uses random coloring
	var/random_color = TRUE
	/// The chance for a rare color variant
	var/rarechance = 1
	// The color of this specific carp
	var/our_color
	// If the carp gets a sparkle effect
	var/shiny = FALSE
	/// List of usual carp colors
	var/static/list/carp_colors = list(
		"light purple" = "#c3a2ff",
		"light pink" = "#da77a8",
		"dark pink" = "#aa336a",
		"mauve" = "#e0b0ff",
		"puce" = "#a95c68",
		"periwinkle" = "#aeaef0",
		"purple" = "#800080",
		"grape" = "#b339c4",
		"light violet" = "#cf9fff",
		"violet" = "#7f00ff",
		"iris" = "#5d3fd3",
		"orchid" = "#da70d6",
		"eggplant" = "#684a68",
		"plum" = "#673147",
		"red purple" = "#953553",
		"burgundy" = "#800020"
	)
	/// List of rare carp colors
	var/static/list/carp_colors_rare = list(
		"turquoise" = "#04e1ed",
		"golden" = "#ffc61b",
		"blue" = "#09bae1",
		"teal" = "#20e28e",
		"green" = "#70ff25",
		"silver" = "#fdfbf3"
	)

/mob/living/simple_animal/hostile/carp/Initialize(mapload, mob/tamer)
	AddElement(/datum/element/simple_flying)
	if(random_color)
		set_greyscale(new_config=/datum/greyscale_config/carp)
		carp_randomify(rarechance)
		update_icon()
	. = ..()
	ADD_TRAIT(src, TRAIT_HEALS_FROM_CARP_RIFTS, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_SPACEWALK, INNATE_TRAIT)
	add_cell_sample()
	if(ai_controller)
		ai_controller.blackboard[BB_HOSTILE_ATTACK_WORD] = pick(speak_emote)
		if(tamer)
			tamed(tamer)
		else
			make_tameable()

/mob/living/simple_animal/hostile/carp/proc/make_tameable()
	AddComponent(/datum/component/tameable, food_types = list(/obj/item/food/meat), tame_chance = 20, bonus_tame_chance = 10, after_tame = CALLBACK(src, PROC_REF(tamed)))

/mob/living/simple_animal/hostile/carp/proc/tamed(mob/living/tamer)
	can_buckle = TRUE
	buckle_lying = 0
	AddElement(/datum/element/ridable, /datum/component/riding/creature/carp)
	if(ai_controller)
		var/datum/ai_controller/hostile_friend/ai_current_controller = ai_controller
		ai_current_controller.befriend(tamer)
		can_have_ai = FALSE
		toggle_ai(AI_OFF)


/mob/living/simple_animal/hostile/carp/add_cell_sample()
	AddElement(/datum/element/swabable, CELL_LINE_TABLE_CARP, CELL_VIRUS_TABLE_GENERIC_MOB, 1, 5)

/**
 * Randomly assigns a color to a carp from either a common or rare color variant lists
 *
 * Arguments:
 * * rare The chance of the carp receiving color from the rare color variant list
 */
/mob/living/simple_animal/hostile/carp/proc/carp_randomify(rarechance)
	if(prob(rarechance))
		our_color = pick(carp_colors_rare)
		set_greyscale(colors=list(carp_colors_rare[our_color]))
		name = "shiny [name]"
		shiny = TRUE
		particles = new /particles/sparkles
	else
		our_color = pick(carp_colors)
		set_greyscale(colors=list(carp_colors[our_color]))

/mob/living/simple_animal/hostile/carp/death(gibbed)
	if(shiny)
		QDEL_NULL(particles)
	return ..()


/particles/sparkles
	icon = 'icons/effects/particles/sparkles.dmi'
	icon_state = list("sparkle_1" = 1, "sparkle_2" = 1)
	width = 100
	height = 100
	count = 1000
	spawning = 0.5
	lifespan = 1.5 SECONDS
	fade = 1 SECONDS
	velocity = generator("circle", -1, 1, NORMAL_RAND)
	position = generator("box", list(-9, -9, NORMAL_RAND), list(9, 9, NORMAL_RAND))
	grow = -0.05

/mob/living/simple_animal/hostile/carp/revive(full_heal = FALSE, admin_revive = FALSE)
	. = ..()
	if(.)
		update_icon()

/mob/living/simple_animal/hostile/carp/examine(mob/user)
	. = ..()
	if(random_color)
		. += span_notice("Oh, [p_their()] scales are [our_color][shiny ? "!" : "."]")

/mob/living/simple_animal/hostile/carp/proc/chomp_plastic()
	var/obj/item/storage/cans/tasty_plastic = locate(/obj/item/storage/cans) in view(1, src)
	if(tasty_plastic && Adjacent(tasty_plastic))
		visible_message(span_notice("[src] gets its head stuck in [tasty_plastic], and gets cut breaking free from it!"), span_notice("You try to avoid [tasty_plastic], but it looks so... delicious... Ow! It cuts the inside of your mouth!"))

		new /obj/effect/decal/cleanable/plastic(loc)

		adjustBruteLoss(5)
		qdel(tasty_plastic)

/mob/living/simple_animal/hostile/carp/Life(delta_time = SSMOBS_DT, times_fired)
	. = ..()
	if(stat == CONSCIOUS)
		chomp_plastic()

/mob/living/simple_animal/hostile/carp/update_overlays()
	. = ..()
	if(stat == CONSCIOUS)
		. += mutable_appearance('icons/mob/carp.dmi', "eyes_overlay")


/mob/living/simple_animal/hostile/carp/shiny
	rarechance = 100//guarenteed rare color


/mob/living/simple_animal/hostile/carp/holocarp
	icon_state = "holocarp"
	icon_living = "holocarp"
	maxbodytemp = INFINITY
	ai_controller = null
	gold_core_spawnable = NO_SPAWN
	del_on_death = 1
	random_color = FALSE


/mob/living/simple_animal/hostile/carp/holocarp/add_cell_sample()
	return

/mob/living/simple_animal/hostile/carp/megacarp
	icon = 'icons/mob/broadMobs.dmi'
	name = "Mega Space Carp"
	desc = "A ferocious, fang bearing creature that resembles a shark. This one seems especially ticked off."
	icon_state = "megacarp"
	icon_living = "megacarp"
	icon_dead = "megacarp_dead"
	icon_gib = "megacarp_gib"
	health_doll_icon = "megacarp"
	ai_controller = null
	maxHealth = 20
	health = 20
	pixel_x = -16
	base_pixel_x = -16
	mob_size = MOB_SIZE_LARGE
	random_color = FALSE

	obj_damage = 80
	melee_damage_lower = 20
	melee_damage_upper = 20
	butcher_results = list(/obj/item/food/fishmeat/carp = 2, /obj/item/stack/sheet/animalhide/carp = 3)
	var/regen_cooldown = 0

/mob/living/simple_animal/hostile/carp/megacarp/Initialize(mapload)
	. = ..()
	name = "[pick(GLOB.megacarp_first_names)] [pick(GLOB.megacarp_last_names)]"
	melee_damage_lower += rand(2, 10)
	melee_damage_upper += rand(10,20)
	maxHealth += rand(30,60)
	move_to_delay = rand(3,7)


/mob/living/simple_animal/hostile/carp/megacarp/add_cell_sample()
	AddElement(/datum/element/swabable, CELL_LINE_TABLE_MEGACARP, CELL_VIRUS_TABLE_GENERIC_MOB, 1, 5)

/mob/living/simple_animal/hostile/carp/megacarp/adjustHealth(amount, updating_health = TRUE, forced = FALSE)
	. = ..()
	if(.)
		regen_cooldown = world.time + REGENERATION_DELAY

/mob/living/simple_animal/hostile/carp/megacarp/Login()
	. = ..()
	if(!. || !client)
		return FALSE

	AddElement(/datum/element/ridable, /datum/component/riding/creature/megacarp)
	can_buckle = TRUE
	buckle_lying = 0

/mob/living/simple_animal/hostile/carp/megacarp/Life(delta_time = SSMOBS_DT, times_fired)
	. = ..()
	if(regen_cooldown < world.time)
		heal_overall_damage(2 * delta_time)

/mob/living/simple_animal/hostile/carp/lia
	name = "Lia"
	real_name = "Lia"
	desc = "A failed experiment of Nanotrasen to create weaponised carp technology. This less than intimidating carp now serves as the Head of Security's pet."
	gender = FEMALE
	speak_emote = list("squeaks")
	ai_controller = null
	gold_core_spawnable = NO_SPAWN
	faction = list("neutral")
	health = 200
	icon_dead = "magicarp_dead"
	icon_gib = "magicarp_gib"
	icon_living = "magicarp"
	icon_state = "magicarp"
	maxHealth = 200
	random_color = FALSE

/mob/living/simple_animal/hostile/carp/lia/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/pet_bonus, "bloops happily!")


/mob/living/simple_animal/hostile/carp/cayenne
	name = "Cayenne"
	real_name = "Cayenne"
	desc = "A failed Syndicate experiment in weaponized space carp technology, it now serves as a lovable mascot."
	gender = FEMALE
	speak_emote = list("squeaks")
	ai_controller = null
	gold_core_spawnable = NO_SPAWN
	faction = list(ROLE_SYNDICATE)
	rarechance = 10
	/// Keeping track of the nuke disk for the functionality of storing it.
	var/obj/item/disk/nuclear/disky
	/// Location of the file storing disk overlays
	var/icon/disk_overlay_file = 'icons/mob/carp.dmi'
	/// Colored disk mouth appearance for adding it as a mouth overlay
	var/mutable_appearance/colored_disk_mouth

/mob/living/simple_animal/hostile/carp/cayenne/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/pet_bonus, "bloops happily!")
	colored_disk_mouth = mutable_appearance(SSgreyscale.GetColoredIconByType(/datum/greyscale_config/carp/disk_mouth, greyscale_colors), "disk_mouth")
	ADD_TRAIT(src, TRAIT_DISK_VERIFIER, INNATE_TRAIT) //carp can verify disky
	ADD_TRAIT(src, TRAIT_CAN_STRIP, INNATE_TRAIT) //carp can take the disk off the captain
	ADD_TRAIT(src, TRAIT_CAN_USE_NUKE, INNATE_TRAIT) //carp SMART

/mob/living/simple_animal/hostile/carp/cayenne/death(gibbed)
	if(disky)
		disky.forceMove(drop_location())
		disky = null
	return ..()

/mob/living/simple_animal/hostile/carp/cayenne/Destroy(force)
	QDEL_NULL(disky)
	return ..()

/mob/living/simple_animal/hostile/carp/cayenne/examine(mob/user)
	. = ..()
	if(disky)
		. += span_notice("Wait... is that [disky] in [p_their()] mouth?")

/mob/living/simple_animal/hostile/carp/cayenne/AttackingTarget(atom/attacked_target)
	if(istype(attacked_target, /obj/item/disk/nuclear))
		var/obj/item/disk/nuclear/potential_disky = attacked_target
		if(potential_disky.anchored)
			return
		potential_disky.forceMove(src)
		disky = potential_disky
		to_chat(src, span_nicegreen("YES!! You manage to pick up [disky]. (Click anywhere to place it back down.)"))
		update_icon()
		if(!disky.fake)
			client.give_award(/datum/award/achievement/misc/cayenne_disk, src)
		return
	if(disky)
		if(isopenturf(attacked_target))
			to_chat(src, span_notice("You place [disky] on [attacked_target]"))
			disky.forceMove(attacked_target)
			disky = null
			update_icon()
		else
			disky.melee_attack_chain(src, attacked_target)
		return

	if(istype(attacked_target, /obj/machinery/nuclearbomb))
		var/obj/machinery/nuclearbomb/nuke = attacked_target
		nuke.ui_interact(src)
		return
	return ..()

/mob/living/simple_animal/hostile/carp/cayenne/Exited(atom/movable/gone, direction)
	. = ..()
	if(disky == gone)
		disky = null
		update_icon()

/mob/living/simple_animal/hostile/carp/cayenne/update_overlays()
	. = ..()
	if(!disky || stat == DEAD)
		return
	. += colored_disk_mouth
	. += mutable_appearance(disk_overlay_file, "disk_overlay")

#undef REGENERATION_DELAY
