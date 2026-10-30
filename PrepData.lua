----------------------------------------------------------------------
-- VoidGear PrepData  (GENERATED -- do not hand-edit)
--
-- From Blizzard's game tables (build 12.1.5.70575), current expansion only:
--   enchants[enchantID] = { tier = crafted quality of that enchant, name = scroll name,
--                           items = the scrolls (one per quality; read each one's quality in game) }
--   sameName[itemID]    = every item with that name (a gem or kit at each quality)
--   consumables[job]    = candidate items per job (flask, potion, food, oil, rune), each
--                         a same-name group; the addon scores them from their tooltips
-- Regenerate: voidscout-data/tools/cmd/prep-data --db2 <csv folder> --out ../../VoidGear/PrepData.lua
----------------------------------------------------------------------
VoidGear = VoidGear or {}
VoidGear.PrepData = { build = "12.1.5.70575",
enchants = {
    [7934] = { tier = 1, name = "Sunfire Silk Spellthread", items = { 240094, 240133 } },
    [7935] = { tier = 2, name = "Sunfire Silk Spellthread", items = { 240094, 240133 } },
    [7936] = { tier = 1, name = "Arcanoweave Spellthread", items = { 240154, 240155 } },
    [7937] = { tier = 2, name = "Arcanoweave Spellthread", items = { 240154, 240155 } },
    [7938] = { tier = 1, name = "Bright Linen Spellthread", items = { 240156, 240157 } },
    [7939] = { tier = 2, name = "Bright Linen Spellthread", items = { 240156, 240157 } },
    [7956] = { tier = 1, name = "Enchant Chest - Mark of Nalorakk", items = { 243946, 243947 } },
    [7957] = { tier = 2, name = "Enchant Chest - Mark of Nalorakk", items = { 243946, 243947 } },
    [7958] = { tier = 1, name = "Enchant Helm - Hex of Leeching", items = { 243948, 243949 } },
    [7959] = { tier = 2, name = "Enchant Helm - Hex of Leeching", items = { 243948, 243949 } },
    [7960] = { tier = 1, name = "Enchant Helm - Empowered Hex of Leeching", items = { 243950, 243951 } },
    [7961] = { tier = 2, name = "Enchant Helm - Empowered Hex of Leeching", items = { 243950, 243951 } },
    [7962] = { tier = 1, name = "Enchant Boots - Lynx's Dexterity", items = { 243952, 243953 } },
    [7963] = { tier = 2, name = "Enchant Boots - Lynx's Dexterity", items = { 243952, 243953 } },
    [7964] = { tier = 1, name = "Enchant Ring - Amani Mastery", items = { 243954, 243955 } },
    [7965] = { tier = 2, name = "Enchant Ring - Amani Mastery", items = { 243954, 243955 } },
    [7966] = { tier = 1, name = "Enchant Ring - Eyes of the Eagle", items = { 243956, 243957 } },
    [7967] = { tier = 2, name = "Enchant Ring - Eyes of the Eagle", items = { 243956, 243957 } },
    [7968] = { tier = 1, name = "Enchant Ring - Zul'jin's Mastery", items = { 243958, 243959 } },
    [7969] = { tier = 2, name = "Enchant Ring - Zul'jin's Mastery", items = { 243958, 243959 } },
    [7970] = { tier = 1, name = "Enchant Shoulders - Flight of the Eagle", items = { 243960, 243961 } },
    [7971] = { tier = 2, name = "Enchant Shoulders - Flight of the Eagle", items = { 243960, 243961 } },
    [7972] = { tier = 1, name = "Enchant Shoulders - Akil'zon's Swiftness", items = { 243962, 243963 } },
    [7973] = { tier = 2, name = "Enchant Shoulders - Akil'zon's Swiftness", items = { 243962, 243963 } },
    [7974] = { tier = 1, name = "Enchant Tool - Amani Perception", items = { 243964, 243965 } },
    [7975] = { tier = 2, name = "Enchant Tool - Amani Perception", items = { 243964, 243965 } },
    [7976] = { tier = 1, name = "Enchant Tool - Amani Resourcefulness", items = { 243966, 243967 } },
    [7977] = { tier = 2, name = "Enchant Tool - Amani Resourcefulness", items = { 243966, 243967 } },
    [7978] = { tier = 1, name = "Enchant Weapon - Strength of Halazzi", items = { 243968, 243969 } },
    [7979] = { tier = 2, name = "Enchant Weapon - Strength of Halazzi", items = { 243968, 243969 } },
    [7980] = { tier = 1, name = "Enchant Weapon - Jan'alai's Precision", items = { 243970, 243971 } },
    [7981] = { tier = 2, name = "Enchant Weapon - Jan'alai's Precision", items = { 243970, 243971 } },
    [7982] = { tier = 1, name = "Enchant Weapon - Berserker's Rage", items = { 243972, 243973 } },
    [7983] = { tier = 2, name = "Enchant Weapon - Berserker's Rage", items = { 243972, 243973 } },
    [7984] = { tier = 1, name = "Enchant Chest - Mark of the Rootwarden", items = { 243974, 243975 } },
    [7985] = { tier = 2, name = "Enchant Chest - Mark of the Rootwarden", items = { 243974, 243975 } },
    [7986] = { tier = 1, name = "Enchant Chest - Mark of the Worldsoul", items = { 243976, 243977 } },
    [7987] = { tier = 2, name = "Enchant Chest - Mark of the Worldsoul", items = { 243976, 243977 } },
    [7988] = { tier = 1, name = "Enchant Helm - Blessing of Speed", items = { 243978, 243979 } },
    [7989] = { tier = 2, name = "Enchant Helm - Blessing of Speed", items = { 243978, 243979 } },
    [7990] = { tier = 1, name = "Enchant Helm - Empowered Blessing of Speed", items = { 243980, 243981 } },
    [7991] = { tier = 2, name = "Enchant Helm - Empowered Blessing of Speed", items = { 243980, 243981 } },
    [7992] = { tier = 1, name = "Enchant Boots - Shaladrassil's Roots", items = { 243982, 243983 } },
    [7993] = { tier = 2, name = "Enchant Boots - Shaladrassil's Roots", items = { 243982, 243983 } },
    [7994] = { tier = 1, name = "Enchant Ring - Nature's Wrath", items = { 243984, 243985 } },
    [7995] = { tier = 2, name = "Enchant Ring - Nature's Wrath", items = { 243984, 243985 } },
    [7996] = { tier = 1, name = "Enchant Ring - Nature's Fury", items = { 243986, 243987 } },
    [7997] = { tier = 2, name = "Enchant Ring - Nature's Fury", items = { 243986, 243987 } },
    [7998] = { tier = 1, name = "Enchant Shoulders - Nature's Grace", items = { 243988, 243989 } },
    [7999] = { tier = 2, name = "Enchant Shoulders - Nature's Grace", items = { 243988, 243989 } },
    [8000] = { tier = 1, name = "Enchant Shoulders - Amirdrassil's Grace", items = { 243990, 243991 } },
    [8001] = { tier = 2, name = "Enchant Shoulders - Amirdrassil's Grace", items = { 243990, 243991 } },
    [8002] = { tier = 1, name = "Enchant Tool - Haranir Finesse", items = { 243992, 243993 } },
    [8003] = { tier = 2, name = "Enchant Tool - Haranir Finesse", items = { 243992, 243993 } },
    [8004] = { tier = 1, name = "Enchant Tool - Haranir Multicrafting", items = { 243994, 243995 } },
    [8005] = { tier = 2, name = "Enchant Tool - Haranir Multicrafting", items = { 243994, 243995 } },
    [8006] = { tier = 1, name = "Enchant Weapon - Worldsoul Cradle", items = { 243996, 243997 } },
    [8007] = { tier = 2, name = "Enchant Weapon - Worldsoul Cradle", items = { 243996, 243997 } },
    [8008] = { tier = 1, name = "Enchant Weapon - Worldsoul Aegis", items = { 243998, 243999 } },
    [8009] = { tier = 2, name = "Enchant Weapon - Worldsoul Aegis", items = { 243998, 243999 } },
    [8010] = { tier = 1, name = "Enchant Weapon - Worldsoul Tenacity", items = { 244000, 244001 } },
    [8011] = { tier = 2, name = "Enchant Weapon - Worldsoul Tenacity", items = { 244000, 244001 } },
    [8012] = { tier = 1, name = "Enchant Chest - Mark of the Magister", items = { 244002, 244003 } },
    [8013] = { tier = 2, name = "Enchant Chest - Mark of the Magister", items = { 244002, 244003 } },
    [8014] = { tier = 1, name = "Enchant Helm - Rune of Avoidance", items = { 244004, 244005 } },
    [8015] = { tier = 2, name = "Enchant Helm - Rune of Avoidance", items = { 244004, 244005 } },
    [8016] = { tier = 1, name = "Enchant Helm - Empowered Rune of Avoidance", items = { 244006, 244007 } },
    [8017] = { tier = 2, name = "Enchant Helm - Empowered Rune of Avoidance", items = { 244006, 244007 } },
    [8018] = { tier = 1, name = "Enchant Boots - Farstrider's Hunt", items = { 244008, 244009 } },
    [8019] = { tier = 2, name = "Enchant Boots - Farstrider's Hunt", items = { 244008, 244009 } },
    [8020] = { tier = 1, name = "Enchant Ring - Thalassian Haste", items = { 244010, 244011 } },
    [8021] = { tier = 2, name = "Enchant Ring - Thalassian Haste", items = { 244010, 244011 } },
    [8022] = { tier = 1, name = "Enchant Ring - Thalassian Versatility", items = { 244012, 244013 } },
    [8023] = { tier = 2, name = "Enchant Ring - Thalassian Versatility", items = { 244012, 244013 } },
    [8024] = { tier = 1, name = "Enchant Ring - Silvermoon's Alacrity", items = { 244014, 244015 } },
    [8025] = { tier = 2, name = "Enchant Ring - Silvermoon's Alacrity", items = { 244014, 244015 } },
    [8026] = { tier = 1, name = "Enchant Ring - Silvermoon's Tenacity", items = { 244016, 244017 } },
    [8027] = { tier = 2, name = "Enchant Ring - Silvermoon's Tenacity", items = { 244016, 244017 } },
    [8028] = { tier = 1, name = "Enchant Shoulders - Thalassian Recovery", items = { 244018, 244019 } },
    [8029] = { tier = 2, name = "Enchant Shoulders - Thalassian Recovery", items = { 244018, 244019 } },
    [8030] = { tier = 1, name = "Enchant Shoulders - Silvermoon's Mending", items = { 244020, 244021 } },
    [8031] = { tier = 2, name = "Enchant Shoulders - Silvermoon's Mending", items = { 244020, 244021 } },
    [8032] = { tier = 1, name = "Enchant Tool - Sin'dorei Deftness", items = { 244022, 244023 } },
    [8033] = { tier = 2, name = "Enchant Tool - Sin'dorei Deftness", items = { 244022, 244023 } },
    [8034] = { tier = 1, name = "Enchant Tool - Ren'dorei Ingenuity", items = { 244024, 244025 } },
    [8035] = { tier = 2, name = "Enchant Tool - Ren'dorei Ingenuity", items = { 244024, 244025 } },
    [8036] = { tier = 1, name = "Enchant Weapon - Flames of the Sin'dorei", items = { 244026, 244027 } },
    [8037] = { tier = 2, name = "Enchant Weapon - Flames of the Sin'dorei", items = { 244026, 244027 } },
    [8038] = { tier = 1, name = "Enchant Weapon - Acuity of the Ren'dorei", items = { 244028, 244029 } },
    [8039] = { tier = 2, name = "Enchant Weapon - Acuity of the Ren'dorei", items = { 244028, 244029 } },
    [8040] = { tier = 1, name = "Enchant Weapon - Arcane Mastery", items = { 244030, 244031 } },
    [8041] = { tier = 2, name = "Enchant Weapon - Arcane Mastery", items = { 244030, 244031 } },
    [8042] = { tier = 1, name = "Illusory Adornment - Blooming Light", items = { 244032, 244033 } },
    [8043] = { tier = 2, name = "Illusory Adornment - Blooming Light", items = { 244032, 244033 } },
    [8044] = { tier = 1, name = "Illusory Adornment - Nature's Embrace", items = { 244034, 244035 } },
    [8045] = { tier = 2, name = "Illusory Adornment - Nature's Embrace", items = { 244034, 244035 } },
    [8046] = { tier = 1, name = "Illusory Adornment - Voidtouched", items = { 244036, 244037 } },
    [8047] = { tier = 2, name = "Illusory Adornment - Voidtouched", items = { 244036, 244037 } },
    [8051] = { tier = 1, name = "Thalassian Phoenix Oil", items = { 243733, 243734 } },
    [8052] = { tier = 2, name = "Thalassian Phoenix Oil", items = { 243733, 243734 } },
    [8053] = { tier = 1, name = "Oil of Dawn", items = { 243735, 243736 } },
    [8054] = { tier = 2, name = "Oil of Dawn", items = { 243735, 243736 } },
    [8055] = { tier = 1, name = "Smuggler's Enchanted Edge", items = { 243737, 243738 } },
    [8056] = { tier = 2, name = "Smuggler's Enchanted Edge", items = { 243737, 243738 } },
    [8158] = { tier = 1, name = "Forest Hunter's Armor Kit", items = { 244640, 244641 } },
    [8159] = { tier = 2, name = "Forest Hunter's Armor Kit", items = { 244640, 244641 } },
    [8160] = { tier = 1, name = "Thalassian Scout Armor Kit", items = { 244644, 244645 } },
    [8161] = { tier = 2, name = "Thalassian Scout Armor Kit", items = { 244644, 244645 } },
    [8162] = { tier = 1, name = "Blood Knight's Armor Kit", items = { 244642, 244643 } },
    [8163] = { tier = 2, name = "Blood Knight's Armor Kit", items = { 244642, 244643 } },
    [8608] = { tier = 1, name = "Laced Zoomshots", items = { 257749, 257750 } },
    [8609] = { tier = 2, name = "Laced Zoomshots", items = { 257749, 257750 } },
    [8610] = { tier = 1, name = "Weighted Boomshots", items = { 257751, 257752 } },
    [8611] = { tier = 2, name = "Weighted Boomshots", items = { 257751, 257752 } },
    [8612] = { tier = 1, name = "Smuggler's Lynxeye", items = { 257747, 257748 } },
    [8613] = { tier = 2, name = "Smuggler's Lynxeye", items = { 257747, 257748 } },
    [8614] = { tier = 1, name = "Farstrider's Hawkeye", items = { 257745, 257746 } },
    [8615] = { tier = 2, name = "Farstrider's Hawkeye", items = { 257745, 257746 } },
    [8638] = { tier = 1, name = "Midnight Angler's Grand Line", items = { 262796 } },
    [8688] = { tier = 1, name = "Enchant Weapon - Rite of the Hash'ey", items = { 273071, 273072 } },
    [8689] = { tier = 2, name = "Enchant Weapon - Rite of the Hash'ey", items = { 273071, 273072 } },
    [8702] = { tier = 1, name = "Schematic: R0CKY", items = { 278330 } },
    [8727] = { tier = 1, name = "Ancient Hash'ey Battle Art: Falco Strikes", items = { 280563 } },
    [8728] = { tier = 1, name = "Ancient Hash'ey Battle Art: Ursine's Ironhide", items = { 283997 } },
    [8729] = { tier = 1, name = "Ancient Hash'ey Battle Art: Heat Wave", items = { 283996 } },
    [8730] = { tier = 1, name = "Ancient Hash'ey Battle Art: Eye of the Lynx", items = { 283998 } },
},
sameName = {
    -- Quick Peridot
    [240855] = { 240855, 240856 },
    [240856] = { 240855, 240856 },
    -- Deadly Peridot
    [240857] = { 240857, 240858 },
    [240858] = { 240857, 240858 },
    -- Masterful Peridot
    [240859] = { 240859, 240860 },
    [240860] = { 240859, 240860 },
    -- Versatile Peridot
    [240861] = { 240861, 240862 },
    [240862] = { 240861, 240862 },
    -- Masterful Amethyst
    [240863] = { 240863, 240864 },
    [240864] = { 240863, 240864 },
    -- Deadly Amethyst
    [240865] = { 240865, 240866 },
    [240866] = { 240865, 240866 },
    -- Quick Amethyst
    [240867] = { 240867, 240868 },
    [240868] = { 240867, 240868 },
    -- Versatile Amethyst
    [240869] = { 240869, 240870 },
    [240870] = { 240869, 240870 },
    -- Deadly Garnet
    [240871] = { 240871, 240872 },
    [240872] = { 240871, 240872 },
    -- Quick Garnet
    [240873] = { 240873, 240874 },
    [240874] = { 240873, 240874 },
    -- Masterful Garnet
    [240875] = { 240875, 240876 },
    [240876] = { 240875, 240876 },
    -- Versatile Garnet
    [240877] = { 240877, 240878 },
    [240878] = { 240877, 240878 },
    -- Versatile Lapis
    [240879] = { 240879, 240880 },
    [240880] = { 240879, 240880 },
    -- Deadly Lapis
    [240881] = { 240881, 240882 },
    [240882] = { 240881, 240882 },
    -- Quick Lapis
    [240883] = { 240883, 240884 },
    [240884] = { 240883, 240884 },
    -- Masterful Lapis
    [240885] = { 240885, 240886 },
    [240886] = { 240885, 240886 },
    -- Flawless Quick Peridot
    [240887] = { 240887, 240888 },
    [240888] = { 240887, 240888 },
    -- Flawless Deadly Peridot
    [240889] = { 240889, 240890 },
    [240890] = { 240889, 240890 },
    -- Flawless Masterful Peridot
    [240891] = { 240891, 240892 },
    [240892] = { 240891, 240892 },
    -- Flawless Versatile Peridot
    [240893] = { 240893, 240894 },
    [240894] = { 240893, 240894 },
    -- Flawless Masterful Amethyst
    [240895] = { 240895, 240896 },
    [240896] = { 240895, 240896 },
    -- Flawless Deadly Amethyst
    [240897] = { 240897, 240898 },
    [240898] = { 240897, 240898 },
    -- Flawless Quick Amethyst
    [240899] = { 240899, 240900 },
    [240900] = { 240899, 240900 },
    -- Flawless Versatile Amethyst
    [240901] = { 240901, 240902 },
    [240902] = { 240901, 240902 },
    -- Flawless Deadly Garnet
    [240903] = { 240903, 240904 },
    [240904] = { 240903, 240904 },
    -- Flawless Quick Garnet
    [240905] = { 240905, 240906 },
    [240906] = { 240905, 240906 },
    -- Flawless Masterful Garnet
    [240907] = { 240907, 240908 },
    [240908] = { 240907, 240908 },
    -- Flawless Versatile Garnet
    [240909] = { 240909, 240910 },
    [240910] = { 240909, 240910 },
    -- Flawless Versatile Lapis
    [240911] = { 240911, 240912 },
    [240912] = { 240911, 240912 },
    -- Flawless Deadly Lapis
    [240913] = { 240913, 240914 },
    [240914] = { 240913, 240914 },
    -- Flawless Quick Lapis
    [240915] = { 240915, 240916 },
    [240916] = { 240915, 240916 },
    -- Flawless Masterful Lapis
    [240917] = { 240917, 240918 },
    [240918] = { 240917, 240918 },
    -- Powerful Eversong Diamond
    [240966] = { 240966, 240967 },
    [240967] = { 240966, 240967 },
    -- Telluric Eversong Diamond
    [240968] = { 240968, 240969 },
    [240969] = { 240968, 240969 },
    -- Stoic Eversong Diamond
    [240970] = { 240970, 240971 },
    [240971] = { 240970, 240971 },
    -- Indecipherable Eversong Diamond
    [240982] = { 240982, 240983 },
    [240983] = { 240982, 240983 },
    -- Forest Hunter's Armor Kit
    [244640] = { 244640, 244641 },
    [244641] = { 244640, 244641 },
    -- Blood Knight's Armor Kit
    [244642] = { 244642, 244643 },
    [244643] = { 244642, 244643 },
    -- Thalassian Scout Armor Kit
    [244644] = { 244644, 244645 },
    [244645] = { 244644, 244645 },
},
consumables = {
    flask = {
        { 241320, 241321 },  -- Flask of Thalassian Resistance
        { 241324, 241325 },  -- Flask of the Blood Knights
        { 241322, 241323 },  -- Flask of the Magisters
        { 241326, 241327 },  -- Flask of the Shattered Sun
        { 245926, 245927 },  -- Fleeting Flask of Thalassian Resistance
        { 245930, 245931 },  -- Fleeting Flask of the Blood Knights
        { 245932, 245933 },  -- Fleeting Flask of the Magisters
        { 245928, 245929 },  -- Fleeting Flask of the Shattered Sun
    },
    potion = {
        { 271889, 271890 },  -- Alluring Nostrum
        { 241298, 241299 },  -- Amani Extract
        { 271883, 271884 },  -- Concentrated Silvermoon Health Potion
        { 241292, 241293 },  -- Draught of Rampant Abandon
        { 241338, 241339 },  -- Enlightenment Tonic
        { 268954, 268955 },  -- Entropic Extract
        { 274765 },  -- Fleeting Alluring Nostrum
        { 245910, 245911 },  -- Fleeting Draught of Rampant Abandon
        { 245897, 245898 },  -- Fleeting Light's Potential
        { 245916, 245917 },  -- Fleeting Lightfused Mana Potion
        { 274763, 274764 },  -- Fleeting Liquid Luster
        { 245904, 245905 },  -- Fleeting Potion of Devoured Dreams
        { 245902, 245903 },  -- Fleeting Potion of Recklessness
        { 245900, 245901 },  -- Fleeting Potion of Zealotry
        { 245918, 245919 },  -- Fleeting Silvermoon Health Potion
        { 274774 },  -- Frost-Injected Vapor
        { 274780 },  -- Fungal Spore Vapor
        { 241308, 241309 },  -- Light's Potential
        { 241286, 241287 },  -- Light's Preservation
        { 241300, 241301 },  -- Lightfused Mana Potion
        { 271886, 271887 },  -- Liquid Luster
        { 274793 },  -- Mana Barrier Projector
        { 282427 },  -- Nalorakk's Ferocity
        { 278035 },  -- Ornate Healing Potion
        { 241294, 241295 },  -- Potion of Devoured Dreams
        { 280409 },  -- Potion of Liquid Undeath
        { 241288, 241289 },  -- Potion of Recklessness
        { 279550 },  -- Potion of Venomous Return
        { 241296, 241297 },  -- Potion of Zealotry
        { 241306, 241307 },  -- Refreshing Serum
        { 274794 },  -- Shockwave Amplifier
        { 241304, 241305 },  -- Silvermoon Health Potion
        { 274782 },  -- Tether-Severing Vapor
        { 274775 },  -- Void Hungerer's Vapor
        { 259245 },  -- Void Phase Potion
        { 241302, 241303 },  -- Void-Shrouded Tincture
        { 259092 },  -- Void-Tinged Free Action Potion
    },
    food = {
        { 280425 },  -- Afterlife Ale
        { 260276 },  -- Akil'stew
        { 275264 },  -- Amani Cornucopia
        { 242287 },  -- Arcano Cutlets
        { 242298 },  -- Argentleaf Tea
        { 260292 },  -- Asteroid Soup
        { 260298 },  -- Astral Apple Pie
        { 242301 },  -- Azeroot Tea
        { 264992 },  -- Blood Knight Burger
        { 242296 },  -- Bloodthistle-Wrapped Cutlets
        { 260261 },  -- Bloom Nectar
        { 242302 },  -- Bloom Skewers
        { 260270 },  -- Bog Legs
        { 260911, 267240 },  -- Boon of Fortitude
        { 260878, 267239 },  -- Boon of Possibilities
        { 260882, 267238 },  -- Boon of Potency
        { 260879, 267237 },  -- Boon of Power
        { 264668, 267236, 267242 },  -- Boon of Speed
        { 260884, 267241 },  -- Boon of Temperance
        { 267647, 267648, 267649 },  -- Boon of Vigor
        { 260910, 267235, 267243 },  -- Boon of Vitality
        { 242276 },  -- Braised Blood Hunter
        { 265667 },  -- Bright Claw
        { 265664 },  -- Budding Light
        { 242280 },  -- Buttered Root Crab
        { 242274 },  -- Champion's Bento
        { 265665 },  -- Chanterelle Shandy
        { 280182 },  -- Coiled Curry
        { 265097 },  -- Conjured Cinnamon Roll
        { 265098 },  -- Conjured Croissant
        { 265096 },  -- Conjured Souffle
        { 265099 },  -- Conjured Tea
        { 242277 },  -- Crimson Calamari
        { 260272 },  -- Crisp Bluff Bock
        { 264984 },  -- Darkwell Draft
        { 264985 },  -- Dawnmosa
        { 264993 },  -- Delicate Dart Legs
        { 260274 },  -- Denshroom Deep Roast
        { 264989 },  -- Dragonhawk Flight
        { 247672 },  -- Eversong Fizz
        { 242292 },  -- Eversong Pudding
        { 260259 },  -- Everspring Water
        { 260285 },  -- Extract of Lightbloom
        { 264990 },  -- Fairbreeze Franciacorta
        { 242309 },  -- Farstrider Rations
        { 242286 },  -- Fel-Kissed Filet
        { 242294 },  -- Felberry Figs
        { 265669 },  -- Fermented Rift Water
        { 255848 },  -- Flora Frenzy
        { 242306 },  -- Forager's Medley
        { 242291 },  -- Fried Bloomtail
        { 249689 },  -- Ghostflower Tea with Sunfruit
        { 260257 },  -- Ghostlands Pepper
        { 242281 },  -- Glitter Skewers
        { 264995 },  -- Goldenbough Preserves
        { 264981 },  -- Goldengrove Juice
        { 264973 },  -- Goldenmist Gouda
        { 260283 },  -- Grotto Gulp
        { 265668 },  -- Har'kuai Mai Tai
        { 255846 },  -- Harandar Celebration
        { 280183 },  -- Harrier Hotcakes
        { 242295 },  -- Hearthflame Supper
        { 275267 },  -- Hearty Amani Cornucopia
        { 242759 },  -- Hearty Arcano Cutlets
        { 242768 },  -- Hearty Bloodthistle-Wrapped Cutlets
        { 242769 },  -- Hearty Bloom Skewers
        { 242748 },  -- Hearty Braised Blood Hunter
        { 242752 },  -- Hearty Buttered Root Crab
        { 242746 },  -- Hearty Champion's Bento
        { 242749 },  -- Hearty Crimson Calamari
        { 242764 },  -- Hearty Eversong Pudding
        { 242776 },  -- Hearty Farstrider Rations
        { 242758 },  -- Hearty Fel-Kissed Filet
        { 242766 },  -- Hearty Felberry Figs
        { 268680 },  -- Hearty Flora Frenzy
        { 242773 },  -- Hearty Forager's Medley
        { 242763 },  -- Hearty Fried Bloomtail
        { 242753 },  -- Hearty Glitter Skewers
        { 266996 },  -- Hearty Harandar Celebration
        { 242767 },  -- Hearty Hearthflame Supper
        { 268679 },  -- Hearty Impossibly Royal Roast
        { 275268 },  -- Hearty Loa's Gathering
        { 242770 },  -- Hearty Mana-Infused Stew
        { 242754 },  -- Hearty Null and Void Plate
        { 242775 },  -- Hearty Portable Snack
        { 275262 },  -- Hearty Puffer Plate
        { 242744 },  -- Hearty Quel'dorei Medley
        { 242774 },  -- Hearty Quick Sandwich
        { 242747 },  -- Hearty Royal Roast
        { 266985 },  -- Hearty Silvermoon Parade
        { 242772 },  -- Hearty Silvermoon Standard
        { 242761 },  -- Hearty Spellfire Filet
        { 242771 },  -- Hearty Spiced Biscuits
        { 242755 },  -- Hearty Sun-Seared Lumifin
        { 242765 },  -- Hearty Sunwell Delight
        { 275263 },  -- Hearty Sweet-And-Sour Skewers
        { 242750 },  -- Hearty Tasty Smoked Tetra
        { 242760 },  -- Hearty Twilight Angler's Medley
        { 275259 },  -- Hearty Venom-Spiced Cutlets
        { 242756 },  -- Hearty Void-Kissed Fish Rolls
        { 242757 },  -- Hearty Warped Wise Wings
        { 242762 },  -- Hearty Wise Tails
        { 255847 },  -- Impossibly Royal Roast
        { 260269 },  -- Jerk Boar Jerky
        { 260254 },  -- Kale'thas Sunsalad
        { 260284 },  -- Lashroom Quencher
        { 260279 },  -- Lightbloomin' Onion
        { 275265 },  -- Loa's Gathering
        { 260256 },  -- Luxurious Omelette
        { 264987 },  -- Magister's Mead
        { 242297 },  -- Mana Lily Tea
        { 242303 },  -- Mana-Infused Stew
        { 260255 },  -- Managi Roll
        { 260275 },  -- Mukleech Curry
        { 264991 },  -- Murder Roe
        { 242282 },  -- Null and Void Plate
        { 260268 },  -- Pango and Mash
        { 264994 },  -- Pickled Bloom Shoots
        { 242308 },  -- Portable Snack
        { 260278 },  -- Potatoad Salad
        { 275260 },  -- Puffer Plate
        { 260258 },  -- Purified Cordial
        { 260295 },  -- Purified Storm Water
        { 260264 },  -- Quel'Danas Rations
        { 260290 },  -- Quel'Thalas Cheese
        { 242272 },  -- Quel'dorei Medley
        { 242307 },  -- Quick Sandwich
        { 260282 },  -- Refreshing Ahl'ua Water
        { 263974 },  -- Relaxing Tisane
        { 260289 },  -- Ren'dorei Rations
        { 260299 },  -- Roasted Abyssal Eel
        { 260271 },  -- Root Juice
        { 242275 },  -- Royal Roast
        { 245573 },  -- Salmon
        { 264391 },  -- Sanctified Touch
        { 242299 },  -- Sanguithorn Tea
        { 260280 },  -- Sauteed Fungal Tubers
        { 260277 },  -- Sedge Crawler Gumbo
        { 260296 },  -- Shadeleaf Tea
        { 260286 },  -- Shrooms and Nectar
        { 255845 },  -- Silvermoon Parade
        { 247673 },  -- Silvermoon Sin'gria
        { 260263 },  -- Silvermoon Soiree Spread
        { 242305 },  -- Silvermoon Standard
        { 246376 },  -- Solaarian Sintalia
        { 273288 },  -- Sou'jin Soup
        { 242289 },  -- Spellfire Filet
        { 242304 },  -- Spiced Biscuits
        { 280422 },  -- Spirit Sprouts
        { 260260 },  -- Springrunner Sparkling
        { 260291 },  -- Stargazer Pudding
        { 260267 },  -- Steamed Hexx'alor Lobster
        { 260281 },  -- Stir-Fried Saptor Sirloin
        { 246383 },  -- Sun-Basted Ceviche
        { 242283 },  -- Sun-Seared Lumifin
        { 242293 },  -- Sunwell Delight
        { 264983 },  -- Sunwell Shot
        { 275261 },  -- Sweet-And-Sour Skewers
        { 280184 },  -- Sweetsaw Surprise
        { 265674 },  -- Tasty Meat
        { 242278 },  -- Tasty Smoked Tetra
        { 260273 },  -- Tea of Mists and Rain
        { 242300 },  -- Tranquility Bloom Tea
        { 242288 },  -- Twilight Angler's Medley
        { 275258 },  -- Venom-Spiced Cutlets
        { 273307 },  -- Vial of Intrepid Lemonade
        { 260293 },  -- Void Port
        { 242284 },  -- Void-Kissed Fish Rolls
        { 260297 },  -- Voidfarer's Respite
        { 260294 },  -- Voidwyrm Absinthe
        { 242285 },  -- Warped Wise Wings
        { 264982 },  -- Wine Not
        { 242290 },  -- Wise Tails
        { 265666 },  -- World Root Beer
        { 260287 },  -- World Roots Banquet
    },
    oil = {
        { 237372, 237373 },  -- Refulgent Razorstone
        { 237367, 237369 },  -- Refulgent Weightstone
        { 237370, 237371 },  -- Refulgent Whetstone
        { 243733, 243734 },  -- Thalassian Phoenix Oil
    },
    rune = {
        { 259085 },  -- Void-Touched Augment Rune
    },
},
}
