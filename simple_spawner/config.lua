Config = {}

-- Distance to spawn the herd
Config.SpawnDistance = 150.0
-- Distance to delete the herd (must be larger than SpawnDistance)
Config.DespawnDistance = 170.0

Config.Herds = {
    {
        name = "Valentine Herd",
        coords = vector3(-5590.86, -3059.03, 1.74), -- Center of the herd
        radius = 15.0, -- Radius to spread the horses
        amount = 4, -- Number of horses to spawn
        models = { -- List of models to randomly choose from
            "a_c_horse_arabian_white",
            "a_c_horse_morgan_bay",
            "a_c_horse_tennesseewalker_chestnut",
            "a_c_horse_thoroughbred_dapple"
        },
        wander = true,
        invincible = false, -- Must be false to be tamed/killed
        visible = true,
    }, 
    {
        name = "Strawberry Field",
        coords = vector3(-5575.56, -3034.74, 0.32),
        radius = 20.0,
        amount = 5,
        models = {
            "a_c_horse_arabian_black",
        },
        wander = true,
        invincible = false,
        visible = true,
    }
}