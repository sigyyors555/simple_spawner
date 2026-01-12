local spawnedHerds = {}
local playerBreakingHorse = nil
local lastBrokenHorse = nil

function LoadModel(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 50 do
        Wait(50)
        timeout = timeout + 1
    end
    return HasModelLoaded(hash)
end

function GetSafeGroundZ(x, y, z)
    -- Method 1: Native Ground Z
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 50.0, false)
    if found then return groundZ end

    -- Method 2: Raycast downward
    local ray = StartShapeTestRay(x, y, z + 100.0, x, y, z - 100.0, 1, 0)
    local _, hit, hitCoords, _, _ = GetShapeTestResult(ray)
    if hit == 1 then return hitCoords.z end

    return z -- Fallback
end

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        for index, herdData in ipairs(Config.Herds) do
            local dist = #(playerCoords - herdData.coords)

            -- SPAWN LOGIC
            if dist < Config.SpawnDistance then
                if not spawnedHerds[index] then
                    spawnedHerds[index] = {}
                    
                    for i = 1, herdData.amount do
                        local randomModel = herdData.models[math.random(#herdData.models)]
                        
                        if LoadModel(randomModel) then
                            -- Calculate Random Position
                            local randomAngle = math.random() * 2 * math.pi
                            local randomRadius = math.sqrt(math.random()) * herdData.radius
                            local spawnX = herdData.coords.x + (randomRadius * math.cos(randomAngle))
                            local spawnY = herdData.coords.y + (randomRadius * math.sin(randomAngle))
                            local spawnZ = GetSafeGroundZ(spawnX, spawnY, herdData.coords.z)

                            -- Create Ped as LOCAL entity (try non-network)
                            local ped = CreatePed(GetHashKey(randomModel), spawnX, spawnY, spawnZ, math.random(0, 360) + 0.0, false, false, 0, 0)

                            if DoesEntityExist(ped) then
                                -- FIX INVISIBILITY & COAT: Set Random Outfit Variation
                                Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- Sets random outfit

                                -- RANDOMIZE COAT (Ensures proper coat variation)
                                local numOutfits = Citizen.InvokeNative(0x5D5CAFF661DDF6FC, GetHashKey(randomModel)) -- _GET_NUM_COMPONENT_CATEGORIES
                                if numOutfits and numOutfits > 0 then
                                    for componentId = 0, numOutfits - 1 do
                                        local numDrawables = Citizen.InvokeNative(0x90403E8107B60E81, GetHashKey(randomModel), componentId) -- _GET_NUM_META_PED_OUTFITS
                                        if numDrawables and numDrawables > 0 then
                                            local randomDrawable = math.random(0, numDrawables - 1)
                                            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, randomDrawable, true, true, false) -- _SET_RANDOM_OUTFIT_VARIATION
                                        end
                                    end
                                end
                                Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) -- _UPDATE_PED_VARIATION

                                -- GROUND SNAPPING FIRST
                                PlaceObjectOnGroundProperly(ped)
                                FreezeEntityPosition(ped, true)

                                -- Wait for collision
                                local timer = 0
                                while not HasCollisionLoadedAroundEntity(ped) and timer < 20 do
                                    Wait(100)
                                    timer = timer + 1
                                end

                                -- MINIMAL WILD HORSE SETUP - Let game handle the rest

                                -- CRITICAL FLAGS ONLY
                                SetPedConfigFlag(ped, 297, true) -- PCF_HorseWild - REQUIRED for breaking
                                SetPedConfigFlag(ped, 209, false) -- PCF_DisableHorseBreaking - MUST be false

                                -- Set as untamed
                                Citizen.InvokeNative(0xAEB97D84CDF3C00B, ped, false) -- _SET_PED_TAMED (false)
                                Citizen.InvokeNative(0x931B241409216C1F, ped, 0) -- _SET_PED_BONDING_LEVEL (0)

                                -- Ensure no saddle/ownership
                                Citizen.InvokeNative(0xD2CB4AC6  -- Remove saddle if any
                                , ped)
                                Citizen.InvokeNative(0x5A7B86617D8CDFC3, ped, 0) -- Clear any owner

                                -- Set relationship to WILD ANIMAL (will flee from players)
                                SetPedRelationshipGroupHash(ped, GetHashKey("REL_WILD_ANIMAL"))

                                -- Make visible
                                SetEntityVisible(ped, true)
                                SetEntityAlpha(ped, 255, false)
                                SetModelAsNoLongerNeeded(GetHashKey(randomModel))

                                if herdData.invincible then
                                    SetEntityInvincible(ped, true)
                                end

                                FreezeEntityPosition(ped, false)

                                -- Simple wild behavior - horses will wander and graze
                                if herdData.wander then
                                    TaskWanderStandard(ped, 10.0, 10)
                                else
                                    TaskStartScenarioInPlace(ped, GetHashKey("WORLD_ANIMAL_HORSE_GRAZING"), -1, true, false, false, false)
                                end
                                
                                                                -- DEBUG BLIP (Remove later if not needed)                                local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, ped) -- BLIP_STYLE_ENEMY (Simple dot)
                                SetBlipSprite(blip, 1664425300, 1) -- HORSE SPRITE (or generic)
                                SetBlipScale(blip, 0.5)
                                Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Wild Horse") -- SetBlipName

                                table.insert(spawnedHerds[index], { entity = ped, blip = blip })
                            end
                        end
                    end
                end
            
            -- DESPAWN LOGIC
            elseif dist > Config.DespawnDistance then
                if spawnedHerds[index] then
                    for _, data in ipairs(spawnedHerds[index]) do
                        if DoesEntityExist(data.entity) then
                            DeleteEntity(data.entity)
                        end
                        if data.blip then
                            RemoveBlip(data.blip)
                        end
                    end
                    spawnedHerds[index] = nil
                end
            end
        end

        Wait(2000)
    end
end)

-- Custom Breaking System for Spawned Horses
local breakingInProgress = false
local breakingProgress = 0
local maxBreakingProgress = 100
local breakingHorse = nil

Citizen.CreateThread(function()
    while true do
        Wait(0)
        local playerPed = PlayerPedId()
        local mount = GetMount(playerPed)

        if mount and mount ~= 0 and not breakingInProgress then
            -- Check if this is one of our spawned wild horses
            local isWild = GetPedConfigFlag(mount, 297, false)

            if isWild then
                -- Check if this horse is from our spawned list
                local isOurHorse = false
                for _, herd in pairs(spawnedHerds) do
                    for _, data in ipairs(herd) do
                        if data.entity == mount then
                            isOurHorse = true
                            break
                        end
                    end
                    if isOurHorse then break end
                end

                if isOurHorse then
                    -- Start breaking minigame
                    breakingInProgress = true
                    breakingProgress = 0
                    breakingHorse = mount
                    StartHorseBreaking(mount)
                end
            end
        end

        Wait(500)
    end
end)

function StartHorseBreaking(horse)
    local playerPed = PlayerPedId()

    exports.ox_lib:notify({
        title = 'Wild Horse!',
        description = 'Press SPACEBAR repeatedly to calm the horse and break it!',
        type = 'inform',
        duration = 5000
    })

    CreateThread(function()
        local lastPressTime = 0
        while breakingInProgress and GetMount(playerPed) == horse do
            Wait(0)

            -- Display progress on screen
            local progressPercent = math.floor((breakingProgress / maxBreakingProgress) * 100)

            -- Draw text using native
            local str = CreateVarString(10, "LITERAL_STRING", "Breaking Progress: " .. progressPercent .. "% | Press SPACEBAR")
            SetTextScale(0.5, 0.5)
            SetTextColor(255, 255, 255, 215)
            SetTextCentre(true)
            SetTextDropshadow(1, 0, 0, 0, 255)
            Citizen.InvokeNative(0xADA9255D, 10, "LITERAL_STRING", str, Citizen.ResultAsLong())
            Citizen.InvokeNative(0xBE5261BF, 0.5, 0.85)

            -- Check for key press
            local currentTime = GetGameTimer()
            local keyPressed = false

            -- Check for SPACEBAR, ENTER, or E key
            if IsControlJustPressed(0, 0xD9D0E1C0) or -- SPACEBAR
               IsDisabledControlJustPressed(0, 0xD9D0E1C0) or
               IsControlJustPressed(0, 0xC7B5340A) or -- ENTER
               IsControlJustPressed(0, 0xCEFD9220) then -- E key
                keyPressed = true
            end

            if keyPressed and (currentTime - lastPressTime) > 200 then
                lastPressTime = currentTime
                breakingProgress = breakingProgress + math.random(3, 7)

                -- Random chance horse bucks (lose progress)
                if math.random(100) < 20 then
                    breakingProgress = breakingProgress - math.random(5, 10)
                    exports.ox_lib:notify({
                        description = 'The horse resists!',
                        type = 'error',
                        duration = 1000
                    })
                end

                -- Clamp progress
                if breakingProgress > maxBreakingProgress then
                    breakingProgress = maxBreakingProgress
                end
                if breakingProgress < 0 then
                    breakingProgress = 0
                end
            end

            -- Check if breaking is complete
            if breakingProgress >= maxBreakingProgress then
                -- Successfully broken!
                SetPedConfigFlag(horse, 297, false) -- No longer wild
                Citizen.InvokeNative(0xAEB97D84CDF3C00B, horse, true) -- Set as tamed
                Citizen.InvokeNative(0x931B241409216C1F, horse, 1) -- Set bonding level to 1

                local modelHash = GetEntityModel(horse)
                local modelName = Citizen.InvokeNative(0xDCB90FB85C3FFF98, modelHash)

                exports.ox_lib:notify({
                    title = 'Horse Broken!',
                    description = 'You successfully broke the wild horse!\n\nYou can now:\n• Ride it anywhere\n• Sell it for $30 at Wild Horse Buyers\n• Adopt it for $600 to add it to your stable',
                    type = 'success',
                    duration = 10000
                })

                breakingInProgress = false
                breakingHorse = nil
                break
            end
        end

        -- Player dismounted before finishing
        if GetMount(playerPed) ~= horse then
            exports.ox_lib:notify({
                description = 'Horse breaking cancelled - you dismounted',
                type = 'error',
                duration = 3000
            })
            breakingInProgress = false
            breakingHorse = nil
        end
    end)
end

function DisplayText(text, x, y)
    Citizen.InvokeNative(0xADA9255D, 10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    Citizen.InvokeNative(0xBE5261BF, x, y)
end

function CreateVarString(p0, p1, variadic)
    return Citizen.InvokeNative(0xFA925AC00EB830B9, p0, p1, variadic, Citizen.ResultAsLong())
end

-- Cleanup on stop
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    for _, herd in pairs(spawnedHerds) do
        for _, data in ipairs(herd) do
            if DoesEntityExist(data.entity) then DeleteEntity(data.entity) end
            if data.blip then RemoveBlip(data.blip) end
        end
    end
end)
