-- Better Context Menu Icons - Extension (B42)
-- Adds icons, in the same style, to context-menu options of other mods (and a few vanilla
-- options) that Better Context Menu Icons leaves without one. Requires Better Context Menu Icons
-- (SuperOl3gContextMenuIcons) and reuses its icon files from its own folder.
-- It only fills options that still have no icon: it never replaces an icon or an item texture.

local B = "media/ui/BetterContextMenuIcons/"   -- original mod icons
local O = "media/ui/BCMIExtension/"            -- icons of this extension

-- Each entry: list of candidates, first one that exists wins.
--   "b:Name"  icon of Better Context Menu Icons
--   "o:Name"  icon of this extension
--   "i:Module.Item"  texture of that item (if the item exists)
--   "t:Texture"  any game texture
local PETROL = { "i:Base.PetrolCan", "i:Base.JerryCan", "i:Base.GasCan", "b:Fill" }
local MAP = {
    -- Take Any Amount
    ContextMenu_GrabAmount = { "b:Take" },
    ContextMenu_PutAmount = { "b:PutInContainer" },
    -- Picking Meister
    ContextMenu_P4PickingMeister_GrabAll = { "b:Take" },
    ContextMenu_P4PickingMeister_GrabAllSelected = { "b:Take" },
    ContextMenu_P4PickingMeister_GrabContents = { "b:Take" },
    ContextMenu_P4PickingMeister_GrabHalf = { "b:Take" },
    ContextMenu_P4PickingMeister_GrabOne = { "b:Take" },
    ContextMenu_P4PickingMeister_UnpackAll = { "b:Unpack" },
    ContextMenu_P4PickingMeister_UnpackAllSelected = { "b:Unpack" },
    ContextMenu_P4PickingMeister_UnpackContents = { "b:Unpack" },
    ContextMenu_P4PickingMeister_UnpackHalf = { "b:Unpack" },
    ContextMenu_P4PickingMeister_UnpackOne = { "b:Unpack" },
    ContextMenu_P4PickingMeister_RetrieveAllAmmo = { "b:UnloadMagazine" },
    ContextMenu_Rack = { "b:LoadMagazine" },
    -- Vanilla options (also used by CleanUI) without icon
    ContextMenu_Apply_Bandage = { "i:Base.Bandage" },
    ContextMenu_CampfireCorpse = { "b:LightFire" },
    ContextMenu_DestroyForFuel = { "b:LightFire" },
    ContextMenu_Change_Fishing_Hook = { "i:Base.FishingHook", "i:Base.Hook", "b:Settings" },
    ContextMenu_Change_Fishing_Line = { "i:Base.FishingLine", "b:Settings" },
    ContextMenu_CheckMap = { "i:Base.Map", "i:Base.MuldraughMap", "b:Read" },
    ContextMenu_Dry_myself = { "i:Base.BathTowel", "b:WringClothes" },
    ContextMenu_DyeBeard = { "i:Base.HairDyeBlack", "i:Base.HairDyeBlonde", "o:Clean" },
    ContextMenu_DyeHair = { "i:Base.HairDyeBlack", "i:Base.HairDyeBlonde", "o:Clean" },
    ContextMenu_Grab_Corpse = { "b:Pickup" },
    ContextMenu_InsertBullets = { "b:LoadMagazine" },
    ContextMenu_InspectTrack = { "b:Info" },
    ContextMenu_Look_at_picture = { "b:Info" },
    ContextMenu_Look_at_pictures = { "b:Info" },
    ContextMenu_ReLook_at_picture = { "b:Info" },
    ContextMenu_ReLook_at_pictures = { "b:Info" },
    ContextMenu_MergeAll = { "b:Full" },
    ContextMenu_MoveToContainer = { "b:PutInContainer" },
    ContextMenu_MoveToFloor = { "b:PlaceItem" },
    ContextMenu_MoveToInventory = { "b:Take" },
    ContextMenu_Move_To = { "b:PutInContainer" },
    ContextMenu_NameThisBag = { "t:Item_Pencil" },
    ContextMenu_NameThisContainer = { "t:Item_Pencil" },
    ContextMenu_OpenAndDrink = { "b:Drink" },
    ContextMenu_OpenAndEat = { "b:Eat" },
    ContextMenu_PlaceAll = { "b:PlaceItem" },
    ContextMenu_PlaceHalf = { "b:PlaceItem" },
    ContextMenu_PlaceOne = { "b:PlaceItem" },
    ContextMenu_Place_Trap = { "b:PlaceItem" },
    ContextMenu_Pour_into = { "b:TransferFluid" },
    ContextMenu_PutInContainer = { "b:PutInContainer" },
    ContextMenu_Put_out_fire = { "b:PourOnGround" },
    ContextMenu_ReRead = { "b:Read" },
    ContextMenu_Read_Note = { "b:Read" },
    ContextMenu_RefillContainer = { "b:Fill" },
    ContextMenu_Remove_fire = { "b:Pickup" },
    ContextMenu_ResearchCraft = { "b:Read" },
    ContextMenu_SetNoRecipes = { "b:Unwanted" },
    ContextMenu_UnsetNoRecipes = { "b:Wanted" },
    ContextMenu_ShowCraftRecipesUsed = { "t:media/ui/Sidebar/64/Crafting_On_64.png", "b:Cooking" },
    ContextMenu_ShowKnownRecipes = { "b:Read" },
    ContextMenu_ShowRecipes = { "b:Read" },
    ContextMenu_ShowRecipesUsedIn = { "b:Read" },
    ContextMenu_StopAlarm = { "b:UnsetAlarm" },
    ContextMenu_TrapControllerTrigger = { "b:TurnOn" },
    ContextMenu_TrapControllerReset = { "b:Rotate" },
    ContextMenu_TrapControllerLinkTo = { "b:Attach" },
    ContextMenu_TrapPlace = { "b:PlaceItem" },
    ContextMenu_TrapSetTimerActivation = { "b:SetAlarm" },
    ContextMenu_TrapSetTimerExplosion = { "b:SetAlarm" },
    ContextMenu_Unjam = { "b:EjectMagazine" },
    ContextMenu_UnloadRounds = { "b:UnloadMagazine" },
    ContextMenu_WearAll = { "b:Unequip" },
    ContextMenu_Write_Note = { "t:Item_Pencil" },
    ContextMenu_AddRandom = { "b:Cooking" },
    ContextMenu_Add_Ingredient = { "b:Cooking" },
    ContextMenu_FromRandom = { "b:Cooking" },
    ContextMenu_From_Ingredient = { "b:Cooking" },
    -- Take A Bath And Shower
    ContextMenu_Bath_Use = { "o:Bath" },
    ContextMenu_Bath_Use_NoHot = { "o:Bath" },
    ContextMenu_TABAS_TakeBath = { "o:Bath" },
    ContextMenu_Shower_Use = { "o:Shower" },
    ContextMenu_Shower_Use_NoHot = { "o:Shower" },
    ContextMenu_TABAS_TakeShowerCold = { "o:Shower" },
    ContextMenu_TABAS_TakeShowerHot = { "o:Shower" },
    ContextMenu_TABAS_AddBathSalt = { "b:AddFluid" },
    ContextMenu_TABAS_CheckBathStatus = { "b:Info" },
    ContextMenu_TABAS_BathActionRadial = { "b:Settings" },
    ContextMenu_TABAS_EmptyTubWater = { "b:PourOnGround" },
    ContextMenu_TABAS_RecoverWater = { "b:PourOnGround" },
    ContextMenu_TABAS_EmptyTubWaterStop = { "b:PlaceItem" },
    ContextMenu_TABAS_PutTubStopper = { "b:PlaceItem" },
    ContextMenu_TABAS_RemoveTubStopper = { "b:Pickup" },
    ContextMenu_TABAS_FaucetMenu = { "b:Fill" },
    ContextMenu_TABAS_FillTubWater = { "b:Fill" },
    ContextMenu_FillOne = { "b:Fill" },
    ContextMenu_TABAS_FillTubWaterStop = { "b:TurnOff" },
    ContextMenu_TABAS_ImproveShower = { "t:Item_Wrench" },
    ContextMenu_TABAS_ImproveTub = { "t:Item_Wrench" },
    ContextMenu_TABAS_PurifyBathWater = { "b:TransferFluid" },
    ContextMenu_TABAS_ReEquipItems = { "b:Unequip" },
    ContextMenu_TABAS_ReEquipItems_Discard = { "b:Unwanted" },
    ContextMenu_TABAS_ReheatTubWater = { "b:LightFire" },
    ContextMenu_TABAS_ReheatTubWaterStop = { "b:TurnOff" },
    ContextMenu_TABAS_RemoveMakeup = { "o:Clean" },
    ContextMenu_TABAS_SetTemperature = { "o:Thermo" },
    ContextMenu_TABAS_UseSoap = { "i:Base.Soap2", "i:Base.Soap", "o:Clean" },
    ContextMenu_TABAS_UseTowel = { "i:Base.BathTowel", "b:WringClothes" },
    ContextMenu_TABAS_WashGrime = { "o:Clean" },
    ContextMenu_ShakeDry = { "b:WringClothes" },
    ContextMenu_Yourself = { "o:Clean" },
    ContextMenu_WashAllBandage = { "i:Base.Bandage", "o:Clean" },
    ContextMenu_WashAllClothing = { "b:Equip" },
    ContextMenu_WashAllContainer = { "b:PutInContainer" },
    ContextMenu_WashAllWeapon = { "b:EquipPrimary" },
    -- Lifestyle
    ContextMenu_Artwork_Remove = { "b:Unwanted" },
    ContextMenu_Bath_Clean = { "o:Clean" },
    ContextMenu_Shower_Clean = { "o:Clean" },
    ContextMenu_Toilet_Clean = { "o:Clean" },
    ContextMenu_CleanRoom = { "o:Clean" },
    ContextMenu_Cleaning_GF = { "o:Clean" },
    ContextMenu_Bath_UseBubble = { "o:Bath" },
    ContextMenu_ChangeClothes = { "b:Unequip" },
    ContextMenu_SetClothes = { "b:Unequip" },
    ContextMenu_BirthdaySuit = { "b:Equip" },
    ContextMenu_Dancing_Option = { "o:Music" },
    ContextMenu_Dancing_Partner_Option = { "o:Music" },
    ContextMenu_DancingPartner_Enable_Option = { "b:TurnOn" },
    ContextMenu_DancingPartner_Disable_Option = { "b:TurnOff" },
    ContextMenu_DiscoBall_TurnOn = { "b:TurnOn" },
    ContextMenu_DiscoBall_TurnOff = { "b:TurnOff" },
    ContextMenu_Select_Disco_Mode = { "b:Settings" },
    ContextMenu_Banjo = { "i:Base.Banjo", "o:Music" },
    ContextMenu_Drums = { "i:Base.Drumstick", "o:Music" },
    ContextMenu_Flute = { "i:Base.Flute", "o:Music" },
    ContextMenu_GuitarAcoustic = { "i:Base.GuitarAcoustic", "o:Music" },
    ContextMenu_GuitarElectric = { "i:Base.GuitarElectricRed", "i:Base.GuitarElectricBlack", "o:Music" },
    ContextMenu_GuitarElectricBass = { "i:Base.GuitarElectricBassBlack", "i:Base.GuitarElectricBassRed", "o:Music" },
    ContextMenu_Harmonica = { "i:Base.Harmonica", "o:Music" },
    ContextMenu_Keytar = { "i:Base.Keytar", "o:Music" },
    ContextMenu_Piano = { "o:Music" },
    ContextMenu_Saxophone = { "i:Base.Saxophone", "o:Music" },
    ContextMenu_Trumpet = { "i:Base.Trumpet", "o:Music" },
    ContextMenu_Violin = { "i:Base.Violin", "o:Music" },
    ContextMenu_VocalF = { "o:Music" },
    ContextMenu_VocalM = { "o:Music" },
    ContextMenu_Play_Duet_Piano = { "o:Music" },
    ContextMenu_Play_Group_Piano = { "o:Music" },
    ContextMenu_Play_Group_Styles = { "o:Music" },
    ContextMenu_Play_Practice_Piano = { "o:Music" },
    ContextMenu_Play_Random_Piano = { "o:Music" },
    ContextMenu_PlayerPlaylist_Main = { "o:Music" },
    ContextMenu_PlayerPlaylist_Play = { "o:Music" },
    ContextMenu_PlayerPlaylist_Manage = { "b:Settings" },
    ContextMenu_PlayerPlaylist_Import = { "b:Take" },
    ContextMenu_Jukebox_Volume = { "b:Settings" },
    ContextMenu_Jukebox_3D = { "b:Settings" },
    ContextMenu_SheetBook_Read = { "b:Read" },
    ContextMenu_GFClock_Display = { "b:Info" },
    ContextMenu_GFClock_Wind = { "b:SetAlarm" },
    ContextMenu_H_Appearance = { "b:Equip" },
    ContextMenu_H_BrushTeeth = { "i:Base.Toothbrush", "o:Clean" },
    ContextMenu_H_CalmDown = { "b:Rest" },
    ContextMenu_H_Dyes = { "i:Base.HairDyeBlack", "o:Clean" },
    ContextMenu_H_GussyUp = { "i:Base.Comb", "o:Clean" },
    ContextMenu_H_Makeups = { "i:Base.MakeupFoundation", "i:Base.Lipstick", "o:Clean" },
    ContextMenu_H_PerfumeUse = { "i:Base.Perfume", "o:Clean" },
    ContextMenu_Info = { "b:Info" },
    ContextMenu_Improvements_ImprovTab = { "t:Item_Wrench" },
    ContextMenu_Inventions_Add = { "b:PutInContainer" },
    ContextMenu_Inventions_AddBattery = { "b:InsertBattery" },
    ContextMenu_Inventions_RemoveBattery = { "b:RemoveBattery" },
    ContextMenu_Inventions_Continue = { "b:TurnOn" },
    ContextMenu_Inventions_Fix = { "t:Item_Wrench" },
    ContextMenu_Inventions_Invent = { "b:Settings" },
    ContextMenu_Inventions_Research = { "b:Read" },
    ContextMenu_Inventions_Stats = { "b:Info" },
    ContextMenu_InvFoodSynthesizer_Add = { "b:PutInContainer" },
    ContextMenu_InvFoodSynthesizer_Get = { "b:Take" },
    ContextMenu_InvFoodSynthesizer_Run = { "b:TurnOn" },
    ContextMenu_InvHarvester_Harvest = { "b:Farming" },
    ContextMenu_InvNeuralHat_Overdrive = { "b:TurnOn" },
    ContextMenu_InvNeuralHat_Overdrive_Off = { "b:TurnOff" },
    ContextMenu_LSBody = { "b:Rest" },
    ContextMenu_LSBody_Yoga = { "b:Rest" },
    ContextMenu_Meditate = { "b:Rest" },
    ContextMenu_LSMP_InteractMain = { "b:Trade" },
    ContextMenu_LSMP_ShareKnowledge = { "b:Read" },
    ContextMenu_Painting_AddCanvas = { "b:PlaceItem" },
    ContextMenu_Painting_CheckArtInfo = { "b:Info" },
    ContextMenu_Painting_GetPainting = { "b:Take" },
    ContextMenu_Painting_PaintSimple = { "i:Base.Paintbrush", "b:Settings" },
    ContextMenu_Painting_RemoveCanvas = { "b:Unwanted" },
    ContextMenu_Painting_SetFrame = { "b:Settings" },
    ContextMenu_Rename = { "t:Item_Pencil" },
    ContextMenu_Sculpting_AddBlock = { "b:PlaceItem" },
    ContextMenu_Sculpting_KnownList = { "b:Read" },
    ContextMenu_Sculpting_Work = { "i:Base.Chisel", "t:Item_Wrench" },
    ContextMenu_Teller_Activate = { "b:Info" },
    ContextMenu_Toilet_Flush = { "o:Toilet" },
    ContextMenu_Toilet_Use = { "o:Toilet" },
    ContextMenu_Toilet_Ground = { "o:Toilet" },
    ContextMenu_Toilet_Refill = { "b:Fill" },
    ContextMenu_Toilet_Unclog = { "i:Base.Plunger", "t:Item_Wrench" },
    -- Tsar's library / trailers / vehicles
    ContextMenu_Add_Gasoline_To_Gasoline_Storage_Tank = PETROL,
    ContextMenu_Fill_Gasoline_Storage_Tank_From_Fuel_Truck = { "b:Fill" },
    ContextMenu_Fill_Gasoline_Storage_Tank_From_Pump = { "b:Fill" },
    ContextMenu_Remove_Gasoline_From_Fuel_Truck = { "b:AddFluid" },
    ContextMenu_Remove_Gasoline_From_Gasoline_Storage_Tank = { "b:AddFluid" },
    ContextMenu_AirCondOn = { "b:TurnOn" },
    ContextMenu_AirCondOff = { "b:TurnOff" },
    ContextMenu_VehicleHeaterOn = { "b:TurnOn" },
    ContextMenu_VehicleHeaterOff = { "b:TurnOff" },
    ContextMenu_BoatCabinelightsOn = { "b:TurnOn" },
    ContextMenu_BoatCabinelightsOff = { "b:TurnOff" },
    ContextMenu_VehicleHeadlightsOn = { "b:TurnOn" },
    ContextMenu_OpenTent = { "o:Tent" },
    ContextMenu_CloseTent = { "o:Tent" },
    ContextMenu_LaunchVehicle = { "b:PlaceItem" },
    ContextMenu_LoadVehicleOntoTrailer = { "b:Pickup" },
    ContextMenu_Lock_Doors = { "o:Lock" },
    ContextMenu_Unlock_Doors = { "b:UnlockDoor" },
    ContextMenu_OpenTuningMenu = { "b:Settings" },
    ContextMenu_VehicleMechanics = { "t:Item_Wrench" },
    ContextMenu_Vehicle_AttachTrailer = { "b:Attach" },
    ContextMenu_Vehicle_DetachTrailer = { "b:Detach" },
    ContextMenu_TCConvertAppliance = { "t:Item_Wrench" },
    ContextMenu_Open_trunk = { "b:OpenDoor" },
    ContextMenu_Close_trunk = { "b:CloseDoor" },
    ContextMenu_Generator = { "i:Base.Generator", "b:ConnectGenerator" },
    ContextMenu_GeneratorAddFuel = PETROL,
    ContextMenu_Turn_On_Generator = { "b:TurnOn" },
    ContextMenu_TrailerSpotlightOn = { "b:TurnOn" },
    ContextMenu_TrailerSpotlightOff = { "b:TurnOff" },
    ContextMenu_VehicleStartEngine = { "b:TurnOn" },
    ContextMenu_VehicleShutOff = { "b:TurnOff" },
    ContextMenu_Vehicle_EGNH = { "t:Item_Pencil" },
    ContextMenu_GetInToRV = { "b:WalkTo" },
    ContextMenu_GetOutFromRV = { "b:WalkTo" },
    ContextMenu_SalvageVehicle = { "t:Item_Wrench" },
    -- Mini Health Panel
    ContextMenu_Bandage = { "i:Base.Bandage" },
    ContextMenu_Remove_Bandage = { "b:Unequip" },
    ContextMenu_Clean_Burn = { "i:Base.Disinfectant", "i:Base.AlcoholWipes", "o:Clean" },
    ContextMenu_Disinfect = { "i:Base.Disinfectant", "i:Base.AlcoholWipes", "o:Clean" },
    ContextMenu_Remove_Bullet = { "i:Base.Tweezers", "b:Pickup" },
    ContextMenu_Remove_Glass = { "i:Base.Tweezers", "b:Pickup" },
    ContextMenu_Splint = { "i:Base.Splint" },
    ContextMenu_Remove_Splint = { "b:Unequip" },
    ContextMenu_Stitch = { "i:Base.SutureNeedle", "t:Item_Needle" },
    ContextMenu_Remove_Stitch = { "i:Base.Tweezers", "b:Pickup" },
    ContextMenu_Medical_Check = { "b:Info" },
    -- Water Pipes
    ContextMenu_WP_AddCharcoal = { "i:Base.Charcoal", "b:PutInContainer" },
    ContextMenu_WP_FixPump = { "t:Item_Wrench" },
    ContextMenu_WP_FlowmeterInfo = { "b:Info" },
    ContextMenu_WP_PumpInfo = { "b:Info" },
    ContextMenu_WP_ValveOpen = { "o:Valve" },
    ContextMenu_WP_ValveClose = { "o:Valve" },
    -- Throw your bag across
    ContextMenu_Throw_Both = { "o:Throw" },
    ContextMenu_Throw_Both_Over = { "o:Throw" },
    ContextMenu_Throw_Both_Through_Window = { "o:Throw" },
    ContextMenu_Throw_Primary = { "o:Throw" },
    ContextMenu_Throw_Primary_Over = { "o:Throw" },
    ContextMenu_Throw_Primary_Through_Window = { "o:Throw" },
    ContextMenu_Throw_Secondary = { "o:Throw" },
    ContextMenu_Throw_Secondary_Over = { "o:Throw" },
    ContextMenu_Throw_Secondary_Through_Window = { "o:Throw" },
    ContextMenu_AuthenticZ_ThrowGlowstick = { "o:Throw" },
    -- Everything Has a Name
    ContextMenu_label_containers = { "t:Item_Pencil" },
    ContextMenu_label_items = { "t:Item_Pencil" },
    ContextMenu_label_vehicles = { "t:Item_Pencil" },
    ContextMenu_renameButton = { "t:Item_Pencil" },
    ContextMenu_renameStackButton = { "t:Item_Pencil" },
    -- Trees Have Loot
    ContextMenu_CutBranchFromTree = { "i:Base.Saw", "i:Base.Axe", "t:Item_Wrench" },
    ContextMenu_SearchInTree = { "b:Info" },
    ContextMenu_Shovel = { "t:Item_Shovel2" },
    ContextMenu_Take_some_clay = { "t:Item_Shovel2" },
    ContextMenu_Take_some_dirt = { "t:Item_Shovel2" },
    ContextMenu_Take_some_gravel = { "t:Item_Shovel2" },
    ContextMenu_Take_some_sands = { "t:Item_Shovel2" },
    -- Smarter Storage / Manage Containers / Nested Containers
    ContextMenu_SmarterStorage_Copy = { "o:Copy" },
    ContextMenu_SmarterStorage_Paste = { "o:Paste" },
    ContextMenu_SmarterStorage_Edit = { "t:Item_Pencil" },
    ContextMenu_SmarterStorage_Presets = { "b:Settings" },
    ContextMenu_SmarterStorage_MyPresets = { "b:Settings" },
    ContextMenu_SmarterStorage_NewPreset = { "b:Settings" },
    ContextMenu_SmarterStorage_Reset = { "b:Rotate" },
    ContextMenu_Configure_Container = { "b:Settings" },
    ContextMenu_Put_Assigned_Containers = { "b:PutInContainer" },
    ContextMenu_NCB42_Menu = { "b:Settings" },
    ContextMenu_NCB42_HideThis = { "b:Unwanted" },
    ContextMenu_NCB42_HideType = { "b:Unwanted" },
    ContextMenu_NCB42_ShowThis = { "b:Wanted" },
    ContextMenu_NCB42_ShowType = { "b:Wanted" },
    ContextMenu_NCB42_ShowAll = { "b:Wanted" },
    -- Pry Open / Simple Lockpicking
    ContextMenu_STA_PryOpen_Pry = { "i:Base.Crowbar", "b:OpenDoor" },
    ContextMenu_PickLock = { "i:Base.Paperclip", "b:UnlockDoor" },
    -- Authentic Z chainsaw
    ContextMenu_Chainsaw_Tree = { "i:Base.Axe", "t:Item_Wrench" },
    ContextMenu_Refuel_Chainsaw = PETROL,
    ContextMenu_RetrieveFuel_Chainsaw = { "b:AddFluid" },
    ContextMenu_Start_Chainsaw = { "b:TurnOn" },
    ContextMenu_Stop_Chainsaw = { "b:TurnOff" },
    -- Livestock Panel Plus / Defecation / misc
    ContextMenu_Feed = { "b:Eat" },
    ContextMenu_Milk = { "b:Fill" },
    ContextMenu_Shear = { "i:Base.Scissors", "b:Settings" },
    ContextMenu_Defecate = { "o:Toilet" },
    ContextMenu_DefecateSterilize = { "i:Base.Disinfectant", "o:Clean" },
    ContextMenu_CarLighter = { "i:Base.Lighter", "b:LightFire" },
    ContextMenu_Empty = { "b:PourOnGround" },
    ContextMenu_Sit = { "b:Rest" },
    ContextMenu_AutoCook_From_Category = { "b:Cooking" },
    ContextMenu_AutoMechanics = { "o:Train" },
    ContextMenu_AutoMechanics_UninstallAll = { "b:VehicleInstall" },
    ContextMenu_AutoTailoring = { "o:Train" },
    ContextMenu_AutoReload = { "o:Train" },
    ContextMenu_P4HasBeenRead_ToDoAutoMark = { "b:TurnOn" },
    ContextMenu_P4HasBeenRead_ToDoNotAutoMark = { "b:TurnOff" },
    ContextMenu_ReloadAllMagazines_LoadAllMagazines = { "b:LoadMagazine" },
    ContextMenu_ReloadAllMagazines_UnloadAllMagazines = { "b:UnloadMagazine" },
    ContextMenu_Trade = { "b:Trade" },
    ContextMenu_TakePropaneFromStorageTank = { "b:InsertPropaneTank" },
    ContextMenu_PumpFuelAmount = { "b:Info" },
    -- Vanilla 42.22: ladders, crowbar, ashes
    ContextMenu_Climb_Ladder = { "b:ClimbWindow" },
    ContextMenu_Climb_Down_Ladder = { "b:ClimbWindow" },
    ContextMenu_Force = { "i:Base.Crowbar", "b:OpenDoor" },
    ContextMenu_Clear_Ashes = { "i:Base.Broom", "t:Item_Shovel2" },
    -- Unified Carts
    ContextMenu_UnifiedCarts_PushCart = { "i:UnifiedCarts.ShoppingCart", "b:Pickup" },
    ContextMenu_UnifiedCarts_PullCart = { "i:UnifiedCarts.ShoppingCart", "b:Pickup" },
    ContextMenu_UnifiedCarts_SwitchToPush = { "b:Rotate" },
    ContextMenu_UnifiedCarts_SwitchToPull = { "b:Rotate" },
    ContextMenu_UnifiedCarts_DropCart = { "b:PlaceItem" },
    ContextMenu_UnifiedCarts_GrabCart = { "b:Take" },
    ContextMenu_UnifiedCarts_GurneyMenu = { "i:UnifiedCarts.Gurney", "b:Rest" },
    ContextMenu_UnifiedCarts_BodiesMenu = { "b:Pickup" },
    ContextMenu_UnifiedCarts_PushGurney = { "i:UnifiedCarts.Gurney", "b:Pickup" },
    ContextMenu_UnifiedCarts_Park = { "b:PlaceItem" },
    ContextMenu_UnifiedCarts_LoadNearby = { "b:Take" },
    ContextMenu_UnifiedCarts_UnloadHere = { "b:PlaceItem" },
    ContextMenu_UnifiedCarts_UnloadGrave = { "t:location_community_cemetary_01_33", "b:PlaceItem" },
    ContextMenu_UnifiedCarts_UnloadWindow = { "b:ClimbWindow" },
    ContextMenu_UnifiedCarts_PutBag = { "i:Base.SleepingBag_Spread", "i:Base.SleepingBag_Green", "b:Sleep" },
    ContextMenu_UnifiedCarts_TakeBag = { "b:Take" },
    ContextMenu_UnifiedCarts_WeldCart = { "i:UnifiedCarts.WeldingCart", "i:Base.BlowTorch" },
    ContextMenu_UnifiedCarts_InstallOxygen = { "b:InsertPropaneTank" },
    ContextMenu_UnifiedCarts_RemoveOxygen = { "b:RemovePropaneTank" },
    ContextMenu_UnifiedCarts_InstallAcetylene = { "b:InsertPropaneTank" },
    ContextMenu_UnifiedCarts_RemoveAcetylene = { "b:RemovePropaneTank" },
    ContextMenu_UnifiedCarts_ConnectTorch = { "i:Base.BlowTorch", "b:Attach" },
    ContextMenu_UnifiedCarts_ReleaseTorch = { "b:Detach" },
    ContextMenu_UnifiedCarts_PushWeldCart = { "i:UnifiedCarts.WeldingCart", "b:Pickup" },
    ContextMenu_UnifiedCarts_TakeCylinder = { "b:Take" },
    ContextMenu_UnifiedCarts_DrumMenu = { "i:UnifiedCarts.DrumCart", "b:Fill" },
    ContextMenu_UnifiedCarts_DrumFill = { "b:Fill" },
    ContextMenu_UnifiedCarts_DrumPour = { "b:TransferFluid" },
    ContextMenu_UnifiedCarts_DrumEmptyAll = { "b:PourOnGround" },
    ContextMenu_UnifiedCarts_DrumFillFrom = { "b:Fill" },
    ContextMenu_UnifiedCarts_DrumPourInto = { "b:TransferFluid" },
    ContextMenu_UnifiedCarts_DrumRefuel = PETROL,
    ContextMenu_UnifiedCarts_DrumSiphon = { "b:AddFluid" },
    ContextMenu_UnifiedCarts_SitWheelchair = { "i:UnifiedCarts.Wheelchair", "b:Rest" },
    ContextMenu_UnifiedCarts_BasketCarry = { "b:Pickup" },
    ContextMenu_UnifiedCarts_BasketPull = { "b:Pickup" },
    ContextMenu_UnifiedCarts_RollerSide = { "b:Pickup" },
    ContextMenu_UnifiedCarts_RollerBack = { "b:Equip" },
    ContextMenu_UnifiedCarts_RollerPull = { "b:Pickup" },
    ContextMenu_UnifiedCarts_PickUpFurniture = { "i:UnifiedCarts.HandTruck", "b:Pickup" },
    ContextMenu_UnifiedCarts_PlaceFurniture = { "b:PlaceItem" },
    ContextMenu_UnifiedCarts_UnpackFurniture = { "b:Unpack" },
    ContextMenu_UnifiedCarts_FridgeTurnOn = { "b:TurnOn" },
    ContextMenu_UnifiedCarts_FridgeTurnOff = { "b:TurnOff" },
    ContextMenu_UnifiedCarts_FridgeInstallBattery = { "b:InsertBattery" },
    ContextMenu_UnifiedCarts_FridgeRemoveBattery = { "b:RemoveBattery" },
    ContextMenu_UnifiedCarts_FridgePlug = { "b:ConnectGenerator" },
    ContextMenu_UnifiedCarts_FridgeUnplug = { "b:DisconnectGenerator" },
    ContextMenu_UnifiedCarts_FoodOvenTemp = { "o:Thermo" },
    ContextMenu_UnifiedCarts_FoodOvenTimer = { "b:SetAlarm" },
    ContextMenu_UnifiedCarts_FoodInsertTank = { "b:InsertPropaneTank" },
    ContextMenu_UnifiedCarts_FoodRemoveTank = { "b:RemovePropaneTank" },
    ContextMenu_UnifiedCarts_FoodInsertBottle = { "b:AddFluid" },
    ContextMenu_UnifiedCarts_FoodRemoveBottle = { "b:Take" },
    ContextMenu_UnifiedCarts_FoodFill = { "b:Fill" },
    ContextMenu_UnifiedCarts_FoodWashYourself = { "o:Clean" },
    ContextMenu_UnifiedCarts_FoodWashItems = { "o:Clean" },
    ContextMenu_UnifiedCarts_FoodWashAll = { "o:Clean" },
    ContextMenu_UnifiedCarts_FoodEmptySink = { "b:PourOnGround" },
    ContextMenu_UnifiedCarts_FoodDrink = { "b:Drink" },
    ContextMenu_UnifiedCarts_TimberHang = { "b:Attach" },
    ContextMenu_UnifiedCarts_TimberSwap = { "b:Rotate" },
    ContextMenu_UnifiedCarts_TimberTakeDown = { "b:Detach" },
    ContextMenu_UnifiedCarts_TimberHangSaw = { "i:Base.Saw", "b:Attach" },
    ContextMenu_UnifiedCarts_TimberHangAxe = { "i:Base.Axe", "b:Attach" },
    ContextMenu_UnifiedCarts_BellhopLoad = { "b:PutInContainer" },
    ContextMenu_UnifiedCarts_BellhopUnload = { "b:Take" },
    ContextMenu_UnifiedCarts_GunTake = { "b:Take" },
    ContextMenu_UnifiedCarts_GunPut = { "b:PutInContainer" },
    ContextMenu_UnifiedCarts_GunRackPut = { "b:PutInContainer" },
    ContextMenu_UnifiedCarts_GunLockboxPut = { "b:PutInContainer" },
    ContextMenu_UnifiedCarts_CarcassLoad = { "b:PutInContainer" },
    ContextMenu_UnifiedCarts_CarcassLoadHeld = { "b:PutInContainer" },
    ContextMenu_UnifiedCarts_CarcassUnload = { "b:Take" },
    ContextMenu_UnifiedCarts_HoseTake = { "i:UnifiedCarts.HoseNozzle", "b:Take" },
    ContextMenu_UnifiedCarts_HosePickUp = { "i:UnifiedCarts.HoseNozzle", "b:Pickup" },
    ContextMenu_UnifiedCarts_HoseDrop = { "b:Drop" },
    ContextMenu_UnifiedCarts_HoseReel = { "b:Rotate" },
    ContextMenu_UnifiedCarts_HosePlug = { "b:Attach" },
    ContextMenu_UnifiedCarts_HoseUnplug = { "b:Detach" },
    ContextMenu_UnifiedCarts_HoseToCone = { "b:Settings" },
    ContextMenu_UnifiedCarts_HoseToJet = { "b:Settings" },
    ContextMenu_UnifiedCarts_HoseWash = { "o:Clean" },
    ContextMenu_UnifiedCarts_HoseWashYourself = { "o:Shower", "o:Clean" },
    ContextMenu_UnifiedCarts_HoseWashClothes = { "o:Clean" },
    ContextMenu_UnifiedCarts_HoseWashWeapons = { "o:Clean" },
    ContextMenu_UnifiedCarts_HoseWashContainers = { "o:Clean" },
    ContextMenu_UnifiedCarts_HoseWashBandages = { "i:Base.Bandage", "o:Clean" },
    ContextMenu_UnifiedCarts_HitchTravois = { "i:UnifiedCarts.Travois", "b:Attach" },
    ContextMenu_UnifiedCarts_UnhitchTravois = { "b:Detach" },
}

----------------------------------------------------------------------
local texCache = {}
local function resolve(spec)
    if texCache[spec] ~= nil then return texCache[spec] or nil end
    local kind, name = spec:sub(1, 1), spec:sub(3)
    local tex = nil
    local ok = pcall(function()
        if kind == "b" then tex = getTexture(B .. name .. ".png")
        elseif kind == "o" then tex = getTexture(O .. name .. ".png")
        elseif kind == "t" then tex = getTexture(name)
        elseif kind == "i" then
            local sm = getScriptManager()
            local script = sm and sm:FindItem(name)
            if script then
                local icon = script:getIcon()
                if icon and icon ~= "" then tex = getTexture("Item_" .. icon) end
            end
        end
    end)
    if not ok then tex = nil end
    texCache[spec] = tex or false
    return tex
end

local function textureFor(list)
    for _, spec in ipairs(list) do
        local t = resolve(spec)
        if t then return t end
    end
    return nil
end

-- Translated option names -> icon list. Options with %1... in their text are matched by pattern.
local exact, patterns = {}, {}
local function escape(s) return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end
local function build()
    exact, patterns = {}, {}
    for key, list in pairs(MAP) do
        -- Ask with placeholder arguments: works for texts with and without %1 and avoids
        -- "missing arguments" warnings in the log. A missing key comes back as the key itself.
        local s = getText(key, "\1", "\2", "\3", "\4")
        if s and s ~= "" and s ~= key then
            if s:find("[\1\2\3\4]") then
                local pat = escape(s):gsub("[\1\2\3\4]", ".-")
                local literal = s:gsub("[\1\2\3\4%s]", "")
                if #literal >= 3 then table.insert(patterns, { "^" .. pat .. "$", list }) end
            else
                exact[s] = list
            end
        end
    end
end

local function apply(context)
    if not context or not context.options then return end
    for _, option in ipairs(context.options) do
        if option.iconTexture == nil and option.itemForTexture == nil and type(option.name) == "string" then
            local list = exact[option.name]
            if not list then
                for _, p in ipairs(patterns) do
                    if option.name:match(p[1]) then list = p[2]; break end
                end
            end
            if list then
                local tex = textureFor(list)
                if tex then option.iconTexture = tex end
            end
        end
        if option.subOption then apply(context:getSubMenu(option.subOption)) end
    end
end

local function safeApply(context)
    local ok, err = pcall(apply, context)
    if not ok then print("[BCMIExtension] " .. tostring(err)) end
end

-- Registered at game start so it runs after Better Context Menu Icons and the mods that add options.
Events.OnGameStart.Add(function()
    build()
    Events.OnFillInventoryObjectContextMenu.Add(function(player, context) safeApply(context) end)
    Events.OnFillWorldObjectContextMenu.Add(function(player, context, objects, test)
        if not test then safeApply(context) end
    end)
end)
