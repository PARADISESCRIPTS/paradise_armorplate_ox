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
    
    metadata.durability = (newArmor / armorConfig.maxArmor) * 100
    metadata.description = formatPlateInfo(plates)
    ox_inventory:SetMetadata(src, vest.slot, metadata)
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
    local plates = metadata.plates or {}
    
    metadata.armor = newArmorValue
    metadata.durability = (newArmorValue / (metadata.maxArmor or 100)) * 100
    metadata.description = formatPlateInfo(plates)
    
    ox_inventory:SetMetadata(src, slotId, metadata)
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