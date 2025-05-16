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

local function formatPlateInfo(plates)
    local plateCount = {}
    for _, plate in ipairs(plates) do
        plateCount[plate.type] = (plateCount[plate.type] or 0) + 1
    end
    
    local description = ""
    for plateType, count in pairs(plateCount) do
        local plateName = Config.ArmorPlates[plateType].label or plateType:upper()
        description = description .. string.format("%s: %d\n", plateName, count)
    end
    
    return description
end

local function saveVestMetadata(source, vest, metadata)
    if not vest or not metadata then return end

    metadata.armor = metadata.armor or 0
    metadata.plates = metadata.plates or {}
    metadata.durability = metadata.durability or 0
    metadata.description = formatPlateInfo(metadata.plates)
    
    local maxArmor = 0
    local totalDurability = 0
    for _, plate in ipairs(metadata.plates) do
        local plateConfig = Config.ArmorPlates[plate.type]
        if plateConfig then
            maxArmor = math.max(maxArmor, plateConfig.maxArmor)
            totalDurability = totalDurability + ((plateConfig.armorIncrease / plateConfig.maxArmor) * 100)
        end
    end
    
    metadata.maxArmor = maxArmor > 0 and maxArmor or 100
    metadata.durability = math.min(totalDurability, 100)
    
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
    metadata.armor = newArmorValue
    saveVestMetadata(src, vest, metadata)
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