/mob/living/carbon
	blood_volume = BLOOD_VOLUME_NORMAL
	gender = MALE
	//pressure_resistance = 15
	hud_possible = list(HEALTH_HUD,STATUS_HUD,ANTAG_HUD,GLAND_HUD)
	has_limbs = TRUE
	held_items = list(null, null)
	num_legs = 0 //Populated on init through list/bodyparts
	usable_legs = 0 //Populated on init through list/bodyparts
	num_hands = 0 //Populated on init through list/bodyparts
	usable_hands = 0 //Populated on init through list/bodyparts
	mobility_flags = MOBILITY_FLAGS_CARBON_DEFAULT
	blocks_emissive = NONE
	zmm_flags = ZMM_MANGLE_PLANES //Emissive eyes :holding_back_tears:

	///List of [/obj/item/organ/internal] in the mob. They don't go in the contents for some reason I don't want to know.
	var/list/obj/item/organ/internal/internal_organs = list()
	///Same as [above][/mob/living/carbon/var/internal_organs], but stores "slot ID" - "organ" pairs for easy access.
	var/list/internal_organs_slot = list()
	///List of [/obj/item/organ/external] in the mob, similarly used as internal_organs.
	var/list/obj/item/organ/external/external_organs = list()
	///Same as [above][/mob/living/carbon/var/external_organs], but stores "ID" = "organ" pairs.
	var/list/external_organs_slot = list()
	///Can't talk. Value goes down every life proc. NOTE TO FUTURE CODERS: DO NOT INITIALIZE NUMERICAL VARS AS NULL OR I WILL MURDER YOU.
	var/silent = 0
	///How many dream images we have left to send
	var/dreaming = 0

	///Whether or not the mob is handcuffed
	var/obj/item/handcuffed = null
	///Same as handcuffs but for legs. Bear traps use this.
	var/obj/item/legcuffed = null

	/// Measure of how disgusted we are. See DISGUST_LEVEL_GROSS and friends
	var/disgust = 0
	/// How disgusted we were LAST time we processed disgust. Helps prevent unneeded work
	var/old_disgust = 0

	//inventory slots
	var/obj/item/back = null
	var/obj/item/clothing/mask/wear_mask = null
	var/obj/item/clothing/neck/wear_neck = null
	var/obj/item/tank/internal = null
	var/obj/item/clothing/head = null

	///only used by humans
	var/obj/item/clothing/gloves = null
	///only used by humans.
	var/obj/item/clothing/shoes/shoes = null
	///only used by humans.
	var/obj/item/clothing/glasses/glasses = null
	///only used by humans.
	var/obj/item/clothing/ears = null

	/// Carbon
	var/datum/dna/dna = null
	///last mind to control this mob, for blood-based cloning
	var/datum/mind/last_mind = null

	///This is used to determine if the mob failed a breath. If they did fail a brath, they will attempt to breathe each tick, otherwise just once per 4 ticks.
	var/failed_last_breath = FALSE

	var/co2overloadtime = null
	var/obj/item/food/meat/slab/type_of_meat = /obj/item/food/meat/slab

	var/gib_type = /obj/effect/decal/cleanable/blood/gibs

	var/rotate_on_lying = 1

	/// Total level of visualy impairing items
	var/tinttotal = 0

	///Gets filled up in [create_bodyparts()][/mob/living/carbon/proc/create_bodyparts]
	var/list/bodyparts = list(
		/obj/item/bodypart/chest,
		/obj/item/bodypart/head,
		/obj/item/bodypart/arm/left,
		/obj/item/bodypart/arm/right,
		/obj/item/bodypart/leg/right,
		/obj/item/bodypart/leg/left,
	)

	/// A collection of arms (or actually whatever the fug /bodyparts you monsters use to wreck my systems)
	var/list/hand_bodyparts = list()

	///A cache of bodypart = icon to prevent excessive icon creation.
	var/list/icon_render_keys = list()

	//halucination vars
	var/hal_screwyhud = SCREWYHUD_NONE
	var/next_hallucination = 0
	var/damageoverlaytemp = 0

	///used to halt stamina regen temporarily
	var/stam_regen_start_time = 0

	/// Protection (insulation) from the heat, Value 0-1 corresponding to the percentage of protection
	var/heat_protection = 0 // No heat protection
	/// Protection (insulation) from the cold, Value 0-1 corresponding to the percentage of protection
	var/cold_protection = 0 // No cold protection

	/// Timer id of any transformation
	var/transformation_timer

	/// Simple modifier for whether this mob can handle greater or lesser skillchip complexity. See /datum/mutation/human/biotechcompat/ for example.
	var/skillchip_complexity_modifier = 0

	/// Can other carbons be shoved into this one to make it fall?
	var/can_be_shoved_into = FALSE

	/// Only load in visual organs
	var/visual_only_organs = FALSE

	COOLDOWN_DECLARE(bleeding_message_cd)
