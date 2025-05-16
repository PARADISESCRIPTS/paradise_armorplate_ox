local QBCore = exports['qb-core']:GetCoreObject()
local ox_inventory = exports.ox_inventory

-----------------------------------------------------------
-- Functions
-----------------------------------------------------------

local function canUseVestPlates(source, plates)
    if not plates then return true end
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    
    for _, plate in ipairs(plates) do
        local plateConfig = Config.ArmorPlates[plate.type]
        if plateConfig.jobs then
            if not plateConfig.jobs[playerJob] then
                return false, plateConfig.label or plate.type:upper()
            end
        end
    end
    
    return true
end

local function saveVestMetadata(source, vest, metadata)
    if not vest or not metadata then return end

    metadata.armor = metadata.armor or 0
    metadata.plates = metadata.plates or {}
    
    local maxArmor = 0
    for _, plate in ipairs(metadata.plates) do
        local plateConfig = Config.ArmorPlates[plate.type]
        if plateConfig then
            maxArmor = math.max(maxArmor, plateConfig.maxArmor)
        end
    end
    
    metadata.maxArmor = maxArmor > 0 and maxArmor or 100
    
    local durabilityValue = metadata.maxArmor > 0 and math.floor((metadata.armor / metadata.maxArmor) * 100) or 0
    
    local description = ""
    local plateCount = {}
    
    for _, plate in ipairs(metadata.plates) do
        local plateConfig = Config.ArmorPlates[plate.type]
        local plateName = plateConfig and plateConfig.label or plate.type:upper()
        plateCount[plateName] = (plateCount[plateName] or 0) + 1
    end
    
    for plateName, count in pairs(plateCount) do
        if description ~= "" then
            description = description .. ", "
        end
        description = description .. string.format("%s x%d", plateName, count)
    end
    
    metadata.durability = durabilityValue
    metadata.armor = metadata.armor or 0  -- Ensure armor value exists
    if description ~= "" then
        metadata.description = description
    end
    
    TriggerClientEvent('paradise_armorplate:client:updateArmor', source, metadata.armor)
    
    ox_inventory:SetMetadata(source, vest.slot, metadata)
end

-----------------------------------------------------------
-- Item Setup
-----------------------------------------------------------

for plateType, config in pairs(Config.ArmorPlates) do
    QBCore.Functions.CreateUseableItem(config.item, function(source)
        TriggerClientEvent('paradise_armorplate:client:useArmor', source, plateType)
    end)
end

-----------------------------------------------------------
-- Events
-----------------------------------------------------------

RegisterNetEvent('paradise_armorplate:server:applyPlateToVest', function(plateType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local armorConfig = Config.ArmorPlates[plateType]
    
    local vest = ox_inventory:GetSlotWithItem(src, Config.RequiredVest)
    if not vest then return end
    
    local metadata = vest.metadata or {}
    local currentArmor = metadata.armor or 0
    local plates = metadata.plates or {}
    
    if currentArmor >= armorConfig.maxArmor then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Maximum armor capacity reached!',
            type = 'error'
        })
        return
    end
    
    local newArmor = math.min(currentArmor + armorConfig.armorIncrease, armorConfig.maxArmor)
    
    metadata.armor = newArmor
    table.insert(plates, {
        type = plateType,
        armor = armorConfig.armorIncrease
    })
    metadata.plates = plates
    
    saveVestMetadata(src, vest, metadata)
    ox_inventory:RemoveItem(src, armorConfig.item, 1)
    TriggerClientEvent('paradise_armorplate:client:updateArmor', src, newArmor)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Success',
        description = 'Armor plate applied to vest successfully!',
        type = 'success'
    })
end)

RegisterNetEvent('paradise_armorplate:server:updateVestArmor', function(slotId, newArmorValue)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local vest = ox_inventory:GetSlot(src, slotId)
    if not vest or vest.name ~= Config.RequiredVest then return end
    
    local metadata = vest.metadata or {}
    local maxArmor = metadata.maxArmor or 100
    
    metadata.armor = newArmorValue
    local newDurability = math.floor((newArmorValue / maxArmor) * 100)
    metadata.durability = newDurability
    
    if newDurability <= 0 and metadata.plates then
        metadata.plates = {}
        metadata.maxArmor = 100
        metadata.description = ""
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Warning',
            description = 'Your armor plates have been destroyed!',
            type = 'error'
        })
    elseif metadata.plates and #metadata.plates > 0 then
        local plateCount = {}
        for _, plate in ipairs(metadata.plates) do
            local plateConfig = Config.ArmorPlates[plate.type]
            local plateName = plateConfig and plateConfig.label or plate.type:upper()
            plateCount[plateName] = (plateCount[plateName] or 0) + 1
        end
        
        local description = ""
        for plateName, count in pairs(plateCount) do
            if description ~= "" then
                description = description .. ", "
            end
            description = description .. string.format("%s x%d", plateName, count)
        end
        metadata.description = description
    end
    
    ox_inventory:SetMetadata(src, slotId, metadata)
    
    if metadata.durability <= 25 and metadata.durability > 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Warning',
            description = 'Your armor vest is heavily damaged!',
            type = 'warning'
        })
    end
end)

RegisterNetEvent('paradise_armorplate:server:getVestArmor', function()
    local src = source
    local vest = ox_inventory:Search(src, 'slots', Config.RequiredVest)[1]
    
    if vest then
        local metadata = vest.metadata or {}
        saveVestMetadata(src, vest, metadata)
        TriggerClientEvent('paradise_armorplate:client:updateArmor', src, metadata.armor or 0)
    end
end)

-----------------------------------------------------------
-- Exports
-----------------------------------------------------------

exports('armor_vest', function(event, item, inventory, slot, data)
    if event == 'usingItem' then
        local metadata = item.metadata or {}
        local canUse, restrictedPlate = canUseVestPlates(inventory.id, metadata.plates)
        
        if not canUse then
            TriggerClientEvent('ox_lib:notify', inventory.id, {
                title = 'Error',
                description = string.format('You cannot use this vest - it contains restricted %s!', restrictedPlate),
                type = 'error'
            })
            return false
        end
        return true
    elseif event == 'usedItem' then
        local metadata = item.metadata or {}
        local armorValue = metadata.armor or 0
        TriggerClientEvent('paradise_armorplate:client:updateArmor', inventory.id, armorValue)
        return true
    elseif event == 'removing' then
        TriggerClientEvent('paradise_armorplate:client:updateArmor', inventory.id, 0)
        return true
    end
end)