Config = {}

Config.ArmorPlates = {
    criminal = {
        item = "armor_plate1",
        label = "Light Plate",
        armorIncrease = 25,
        maxArmor = 75,
        useTime = 3000,
        jobs = nil
    },
    police = {
        item = "armor_plate2",
        label = "Heavy Plate",
        armorIncrease = 35,
        maxArmor = 100,
        useTime = 2000,
        jobs = {
            ["police"] = true
        }
    }
}

Config.RequiredVest = "armor_vest"

Config.Clothing = {
    enabled = true,
    male = {
        components = {
            [9] = { -- Vest slot
                drawable = 15,
                texture = 0
            }
        }
    },
    female = {
        components = {
            [9] = { -- Vest slot
                drawable = 17,
                texture = 0
            }
        }
    }
}