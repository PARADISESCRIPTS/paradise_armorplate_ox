local QBCore = exports['qb-core']:GetCoreObject()
local ox_inventory = exports.ox_inventory
local lastArmorValue = 0
local originalClothing = {}

-----------------------------------------------------------
-- Functions
-----------------------------------------------------------

local function HasArmorVest()
    return ox_inventory:Search('count', Config.RequiredVest) > 0
end

local function CanUseArmorType(armorType)
    local Player = QBCore.Functions.GetPlayerData()
    local jobName = Player.job.name
    
    if Config.ArmorPlates[armorType].jobs == nil then
        return true
    end
    
    return Config.ArmorPlates[armorType].jobs[jobName] == true
end

local function ApplyArmorPlate(plateType)
    local armorConfig = Config.ArmorPlates[plateType]
    
    if not HasArmorVest() then
        lib.notify({
            title = 'Error',
            description = 'You need an armor vest to apply plates!',
            type = 'error'
        })
        return
    end
    
    if not CanUseArmorType(plateType) then
        lib.notify({
            title = 'Error',
            description = 'You cannot use this type of armor plate!',
            type = 'error'
        })
        return
    end
    
    if lib.progressBar({
        duration = armorConfig.useTime,
        label = 'Applying Armor Plate...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
        anim = {
            dict = 'clothingshirt',
            clip = 'try_shirt_positive_d',
            flag = 49
        },
    }) then
        TriggerServerEvent('paradise_armorplate:server:applyPlateToVest', plateType)
    else
        lib.notify({
            title = 'Cancelled',
            description = 'Cancelled applying armor plate!',
            type = 'error'
        })
    end
end

local function UpdateVestMetadata(newArmorValue)
    if newArmorValue == lastArmorValue then return end
    
    local vest = ox_inventory:Search('slots', Config.RequiredVest)[1]
    if not vest then return end
    
    if newArmorValue < lastArmorValue then
        TriggerServerEvent('paradise_armorplate:server:updateVestArmor', vest.slot, newArmorValue)
    end
    
    lastArmorValue = newArmorValue
end

local function SaveOriginalClothing()
    local ped = PlayerPedId()
    originalClothing = {}
    
    if Config.Clothing.enabled then
        for component, _ in pairs(Config.Clothing[IsPedMale(ped) and 'male' or 'female'].components) do
            originalClothing[component] = {
                drawable = GetPedDrawableVariation(ped, component),
                texture = GetPedTextureVariation(ped, component)
            }
        end
    end
end

local function ApplyVestClothing()
    if not Config.Clothing.enabled then return end
    
    local ped = PlayerPedId()
    local clothingConfig = Config.Clothing[IsPedMale(ped) and 'male' or 'female']
    
    for component, data in pairs(clothingConfig.components) do
        SetPedComponentVariation(ped, component, data.drawable, data.texture, 0)
    end
end

local function RemoveVestClothing()
    if not Config.Clothing.enabled then return end
    
    local ped = PlayerPedId()
    -- Set vest component (9) to 0
    SetPedComponentVariation(ped, 9, 0, 0, 0)
end

-----------------------------------------------------------
-- Events
-----------------------------------------------------------

RegisterNetEvent('paradise_armorplate:client:openPlateMenu', function(slotId)
    local item = exports.ox_inventory:GetPlayerItems()
    if not item then return end
    
    local vest
    for _, item in ipairs(item) do
        if item.slot == slotId then
            vest = item
            break
        end
    end
    
    if not vest then return end
    
    local metadata = vest.metadata or {}
    local plates = metadata.plates or {}
    
    if #plates == 0 then
        lib.notify({
            title = 'Error',
            description = 'No plates installed in this vest!',
            type = 'error'
        })
        return
    end
    
    local options = {}
    
    for i, plate in ipairs(plates) do
        local plateName = Config.ArmorPlates[plate.type].label or plate.type:upper()
        table.insert(options, {
            title = string.format('%s (Slot #%d)', plateName, i),
            description = 'Click to remove this plate',
            onSelect = function()
                TriggerServerEvent('paradise_armorplate:server:removePlate', slotId, i)
            end,
            metadata = {
                {label = 'Armor Value', value = string.format('+%d', plate.armor)},
                {label = 'Type', value = plateName}
            }
        })
    end
    
    lib.registerContext({
        id = 'vest_plate_management',
        title = 'Installed Armor Plates',
        menu = 'ox_inventory',
        onBack = function()
            exports.ox_inventory:openInventory()
        end,
        options = options
    })
    
    lib.showContext('vest_plate_management')
end)

RegisterNetEvent('paradise_armorplate:client:useArmor', function(plateType)
    ApplyArmorPlate(plateType)
end)

RegisterNetEvent('paradise_armorplate:client:updateArmor', function(armorValue)
    SetPedArmour(PlayerPedId(), armorValue)
    if armorValue > 0 then
        ApplyVestClothing()
    else
        RemoveVestClothing()
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(1500)
    SaveOriginalClothing()
    local vest = ox_inventory:Search('slots', Config.RequiredVest)[1]
    if vest then
        local metadata = vest.metadata or {}
        lastArmorValue = metadata.armor or 0
        SetPedArmour(PlayerPedId(), lastArmorValue)
        if lastArmorValue > 0 then
            ApplyVestClothing()
        end
    end
    TriggerServerEvent('paradise_armorplate:server:getVestArmor')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    SetPedArmour(PlayerPedId(), 0)
    RemoveVestClothing()
end)

AddEventHandler('ox_inventory:updateInventory', function(changes)
    if not changes then return end
    
    local currentVestCount = ox_inventory:Search('count', Config.RequiredVest)
    
    if currentVestCount == 0 then
        SetPedArmour(PlayerPedId(), 0)
        lastArmorValue = 0
        RemoveVestClothing()
        return
    end
    
    for _, change in pairs(changes) do
        if type(change) == 'table' and change.name == Config.RequiredVest then
            if not change.count or change.count == 0 then
                SetPedArmour(PlayerPedId(), 0)
                lastArmorValue = 0
                RemoveVestClothing()
                return
            end
            
            if change.count and change.count > 0 then
                local metadata = change.metadata or {}
                local armorValue = metadata.armor or 0
                SetPedArmour(PlayerPedId(), armorValue)
                lastArmorValue = armorValue
                
                if armorValue > 0 then
                    ApplyVestClothing()
                else
                    RemoveVestClothing()
                end
                
                TriggerServerEvent('paradise_armorplate:server:getVestArmor')
                return
            end
        end
    end
end)

AddEventHandler('ox_inventory:itemRemoved', function(name, count, metadata, slot)
    if name == Config.RequiredVest then
        SetPedArmour(PlayerPedId(), 0)
        lastArmorValue = 0
        RemoveVestClothing()
    end
end)

-----------------------------------------------------------
-- Threads
-----------------------------------------------------------

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local currentArmor = GetPedArmour(ped)
        
        UpdateVestMetadata(currentArmor)
        
        Wait(1000) -- Check every second
    end
end)