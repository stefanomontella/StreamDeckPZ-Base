local StreamDeckPZ = {}

local OUTPUT_PATH = "StreamDeckPZ/state.json"
local UPDATE_INTERVAL_SECONDS = 1
local lastAttemptAt = 0

local function realTimeSeconds()
    -- VERIFICARE: Unix milliseconds and Lua exposure in the installed Build 42.
    return math.floor(getTimestampMs() / 1000)
end

local function round(value)
    return math.floor(value + 0.5)
end

local function statPercent(stats, statType)
    local minimum = statType:getMinimumValue()
    local maximum = statType:getMaximumValue()
    local value = stats:get(statType)

    if maximum <= minimum or value ~= value or value == math.huge or value == -math.huge then
        error("Invalid character statistic")
    end

    local percent = ((value - minimum) / (maximum - minimum)) * 100
    return math.max(0, math.min(100, round(percent)))
end

local function formatNumber(value, decimals)
    return string.format("%." .. decimals .. "f", value):gsub(",", ".")
end

local function hasWornWatch(player)
    -- VERIFICARE: worn-item enumeration and instanceof Lua binding in this Build 42.
    -- Only equipped AlarmClockClothing items count; a clock in a bag does not.
    local worn = player:getWornItems()
    for index = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(index)
        if item ~= nil and instanceof(item, "AlarmClockClothing") then
            return true
        end
    end
    return false
end

local function encodeHealth(health)
    if health == nil then return "null" end
    return string.format('{"percent":%s,"bleeding":%d,"scratches":%d,"bites":%d,"infectedWounds":%d}',
        formatNumber(health.percent, 2), health.bleeding, health.scratches, health.bites, health.infectedWounds)
end

local function encodeStat(stat)
    if stat == nil then return "null" end
    return string.format('{"percent":%d,"moodleLevel":%s}', stat.percent,
        stat.moodleLevel ~= nil and tostring(stat.moodleLevel) or "null")
end

local function encodeMood(mood)
    return '{"stress":' .. encodeStat(mood.stress) .. ',"boredom":' .. encodeStat(mood.boredom)
        .. ',"panic":' .. encodeStat(mood.panic) .. ',"sadness":' .. encodeStat(mood.sadness) .. '}'
end

local function encodeWeight(weight)
    if weight == nil then return "null" end
    return string.format('{"current":%s,"maximum":%s}',
        formatNumber(weight.current, 3), formatNumber(weight.maximum, 3))
end

local function jsonString(value)
    -- Escape translated/modded item names, quotes and every JSON control byte.
    return '"' .. tostring(value):gsub('[%z\1-\31\\"]', function(char)
        if char == '"' then return '\\"' end
        if char == '\\' then return '\\\\' end
        return string.format('\\u%04x', string.byte(char))
    end) .. '"'
end

local function encodeValue(value)
    if value == nil then return "null" end
    if type(value) == "boolean" then return value and "true" or "false" end
    if type(value) == "string" then return jsonString(value) end
    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then error("Invalid JSON number") end
        return formatNumber(value, value == math.floor(value) and 0 or 6)
    end
    if type(value) ~= "table" then error("Unsupported JSON value") end
    local fields = {}
    for key, item in pairs(value) do
        fields[#fields + 1] = jsonString(key) .. ':' .. encodeValue(item)
    end
    return '{' .. table.concat(fields, ',') .. '}'
end

local function encodeState(state)
    return string.format(
        '{"schemaVersion":1,"updatedAt":%d,"timeOfDay":%s,"airTemperatureC":%s,"hungerPercent":%d,"thirstPercent":%d,"hasWatch":%s,"hungerMoodleLevel":%s,"thirstMoodleLevel":%s,"health":%s,"endurance":%s,"fatigue":%s,"mood":%s,"weight":%s,"bodyTemperatureC":%s,"wetness":%s,"calendar":%s,"vehicle":%s,"weapon":%s}\n',
        state.updatedAt,
        formatNumber(state.timeOfDay, 4),
        formatNumber(state.airTemperatureC, 2),
        state.hungerPercent,
        state.thirstPercent,
        state.hasWatch and "true" or "false",
        state.hungerMoodleLevel ~= nil and tostring(state.hungerMoodleLevel) or "null",
        state.thirstMoodleLevel ~= nil and tostring(state.thirstMoodleLevel) or "null",
        encodeHealth(state.health),
        encodeStat(state.endurance),
        encodeStat(state.fatigue),
        encodeMood(state.mood),
        encodeWeight(state.weight),
        encodeValue(state.bodyTemperatureC),
        encodeValue(state.wetness),
        encodeValue(state.calendar),
        encodeValue(state.vehicle),
        encodeValue(state.weapon)
    )
end

-- Optional readings are isolated: unsupported bindings never stop the base export.
local optionalErrors = {}
local function optionalReading(name, callback)
    local ok, value = pcall(callback)
    if not ok then
        if not optionalErrors[name] then
            print("[StreamDeckPZ] " .. name .. " unavailable: " .. tostring(value))
            optionalErrors[name] = true
        end
        return nil
    end
    optionalErrors[name] = nil
    return value
end

local function collectStat(player, statType, moodleType, name)
    local percent = statPercent(player:getStats(), statType)
    -- VERIFICARE: Build 42 Lua bindings and moodle levels for these documented constants.
    local level = optionalReading(name .. " moodle", function()
        local value = player:getMoodles():getMoodleLevel(moodleType)
        if value < 0 or value > 4 or value ~= math.floor(value) then error("Invalid moodle level") end
        return value
    end)
    return { percent = percent, moodleLevel = level }
end

local function collectWeight(player)
    -- VERIFICARE: effective carried weight including equipped bags/weight reduction
    -- and exact agreement with the inventory UI in the installed Build 42.
    local current = player:getInventory():getCapacityWeight()
    local maximum = player:getMaxWeight()
    if current ~= current or current < 0 or current > 100000
        or maximum ~= maximum or maximum <= 0 or maximum > 100000 then
        error("Invalid carry weight")
    end
    -- Game encumbrance units, not physical kilograms. Do not clamp overload to 100%.
    return { current = current, maximum = maximum }
end

local function checkedNumber(value, minimum, maximum)
    if type(value) ~= "number" or value ~= value or value < minimum or value > maximum then
        error("Reading outside supported range")
    end
    return value
end

local function collectCalendar(player)
    -- VERIFICARE: one-based getDayPlusOne, zero-based month and player survival hours.
    local time = getGameTime()
    return {
        year = checkedNumber(time:getYear(), 1, 9999),
        month = checkedNumber(time:getMonth() + 1, 1, 12),
        day = checkedNumber(time:getDayPlusOne(), 1, 31),
        survivedDays = optionalReading("Survival time", function()
            return checkedNumber(player:getHoursSurvived() / 24, 0, 1000000)
        end),
        -- VERIFICARE: ClimateMoon singleton Lua exposure and game-updated phase name.
        -- Read the game's phase; do not update climate or substitute astronomical estimates.
        moonPhase = optionalReading("Moon phase", function()
            local name = ClimateMoon.getInstance():getPhaseName()
            if name == nil then error("Moon phase unavailable") end
            return tostring(name)
        end),
    }
end

local function collectVehicle(player)
    -- VERIFICARE: current occupied vehicle, inherited part getters and battery 0-1 scale.
    local vehicle = player:getVehicle()
    if vehicle == nil then return { present = false } end
    return {
        present = true,
        speedKmh = optionalReading("Vehicle speed", function()
            return checkedNumber(math.abs(vehicle:getCurrentSpeedKmHour()), 0, 1000)
        end),
        fuelPercent = optionalReading("Vehicle fuel", function()
            local tank = vehicle:getGasTank()
            if tank == nil then return nil end
            local capacity = tank:getContainerCapacity()
            if capacity <= 0 then return nil end
            return checkedNumber(tank:getContainerContentAmount() / capacity * 100, 0, 100)
        end),
        enginePercent = optionalReading("Vehicle engine", function()
            local engine = vehicle:getEngine()
            if engine == nil then return nil end
            return checkedNumber(engine:getCondition(), 0, 100)
        end),
        batteryPercent = optionalReading("Vehicle battery", function()
            if vehicle:getBattery() == nil then return nil end
            return checkedNumber(vehicle:getBatteryCharge(), 0, 1) * 100
        end),
    }
end

local function collectWeapon(player)
    -- VERIFICARE: primary-hand weapon binding and condition/max-condition semantics.
    local item = player:getPrimaryHandItem()
    if item == nil or not instanceof(item, "HandWeapon") then return { present = false } end
    local weapon = { present = true, name = tostring(item:getName()), ranged = item:isRanged() }
    weapon.conditionPercent = optionalReading("Weapon condition", function()
        local maximum = item:getConditionMax()
        if maximum <= 0 then return nil end
        return checkedNumber(item:getCondition() / maximum * 100, 0, 100)
    end)
    if weapon.ranged then
        -- VERIFICARE: ammo count excludes chamber on the target firearm; report chamber separately.
        weapon.ammo = optionalReading("Weapon ammo", function()
            return checkedNumber(item:getCurrentAmmoCount(), 0, 100000)
        end)
        weapon.maxAmmo = optionalReading("Weapon ammo capacity", function()
            return checkedNumber(item:getMaxAmmo(), 0, 100000)
        end)
        weapon.chambered = optionalReading("Weapon chamber", function() return item:isRoundChambered() end)
    end
    return weapon
end

local function collectHealth(player)
    -- VERIFICARE: documented Java getters exposed to Lua in the installed Build 42.
    local damage = player:getBodyDamage()
    local percent = damage:getOverallBodyHealth()
    if percent ~= percent or percent < 0 or percent > 100 then error("Invalid overall health") end
    local health = { percent = percent, bleeding = 0, scratches = 0, bites = 0, infectedWounds = 0 }
    local parts = damage:getBodyParts()
    for index = 0, parts:size() - 1 do
        local part = parts:get(index)
        -- VERIFICARE: bandaging suppresses active bleeding while wound flags can remain.
        if part:bleeding() and not part:bandaged() then health.bleeding = health.bleeding + 1 end
        if part:scratched() then health.scratches = health.scratches + 1 end
        if part:bitten() then health.bites = health.bites + 1 end
        -- Wound infection only; no hidden Knox infection state is exported.
        if part:isInfectedWound() then health.infectedWounds = health.infectedWounds + 1 end
    end
    return health
end

local function collectNeedMoodles(player)
    -- VERIFICARE: Lua exposure of the current Build 42 MoodleType constants.
    -- These identifiers are documented; do not infer moodle severity from percentages.
    local moodles = player:getMoodles()
    local hunger = moodles:getMoodleLevel(MoodleType.HUNGRY)
    local thirst = moodles:getMoodleLevel(MoodleType.THIRST)
    if hunger < 0 or hunger > 4 or thirst < 0 or thirst > 4 then
        error("Unexpected hunger/thirst moodle level")
    end
    return hunger, thirst
end

local function collectState(player)
    -- VERIFICARE: accesso ai getter delle statistiche Build 42.
    local stats = player:getStats()
    -- VERIFICARE: getter ambientale disponibile nel client Build 42.
    local climate = getClimateManager()
    local gameTime = getGameTime()

    local healthOk, health = pcall(collectHealth, player)
    if not healthOk then
        if not StreamDeckPZ.healthErrorLogged then
            print("[StreamDeckPZ] Health unavailable: " .. tostring(health))
            StreamDeckPZ.healthErrorLogged = true
        end
        health = nil
    else
        StreamDeckPZ.healthErrorLogged = false
    end

    local moodleOk, hungerLevel, thirstLevel = pcall(collectNeedMoodles, player)
    if not moodleOk then
        if not StreamDeckPZ.moodleErrorLogged then
            print("[StreamDeckPZ] Need moodles unavailable: " .. tostring(hungerLevel))
            StreamDeckPZ.moodleErrorLogged = true
        end
        hungerLevel, thirstLevel = nil, nil
    else
        StreamDeckPZ.moodleErrorLogged = false
    end

    -- A watch API problem must not interrupt the already-working hunger/thirst export.
    local watchOk, watch = pcall(hasWornWatch, player)
    if not watchOk then
        if not StreamDeckPZ.watchErrorLogged then
            print("[StreamDeckPZ] Watch detection unavailable: " .. tostring(watch))
            StreamDeckPZ.watchErrorLogged = true
        end
        watch = false
    else
        StreamDeckPZ.watchErrorLogged = false
    end

    return {
        updatedAt = realTimeSeconds(),
        timeOfDay = gameTime:getTimeOfDay(),
        -- Use air at the player's location, rather than the global outdoor climate.
        -- VERIFICARE: Celsius units and exact agreement with the installed build's
        -- clock UI (including rounding and indoor/vehicle behaviour).
        airTemperatureC = climate:getAirTemperatureForCharacter(player),
        hungerPercent = statPercent(stats, CharacterStat.HUNGER),
        thirstPercent = statPercent(stats, CharacterStat.THIRST),
        hasWatch = watch,
        hungerMoodleLevel = hungerLevel,
        thirstMoodleLevel = thirstLevel,
        health = health,
        -- VERIFICARE: CharacterStat minimum/maximum ranges in the installed Build 42.
        endurance = optionalReading("Endurance", function()
            return collectStat(player, CharacterStat.ENDURANCE, MoodleType.ENDURANCE, "Endurance")
        end),
        fatigue = optionalReading("Fatigue", function()
            return collectStat(player, CharacterStat.FATIGUE, MoodleType.TIRED, "Fatigue")
        end),
        mood = {
            stress = optionalReading("Stress", function()
                return collectStat(player, CharacterStat.STRESS, MoodleType.STRESS, "Stress")
            end),
            boredom = optionalReading("Boredom", function()
                return collectStat(player, CharacterStat.BOREDOM, MoodleType.BORED, "Boredom")
            end),
            panic = optionalReading("Panic", function()
                return collectStat(player, CharacterStat.PANIC, MoodleType.PANIC, "Panic")
            end),
            sadness = optionalReading("Sadness", function()
                return collectStat(player, CharacterStat.UNHAPPINESS, MoodleType.UNHAPPY, "Sadness")
            end),
        },
        weight = optionalReading("Carry weight", function() return collectWeight(player) end),
        -- VERIFICARE: core temperature Celsius and wetness range/moodle in this Build 42.
        bodyTemperatureC = optionalReading("Body temperature", function()
            return checkedNumber(player:getBodyDamage():getThermoregulator():getCoreTemperature(), 0, 60)
        end),
        wetness = optionalReading("Wetness", function()
            return collectStat(player, CharacterStat.WETNESS, MoodleType.WET, "Wetness")
        end),
        calendar = optionalReading("Calendar", function() return collectCalendar(player) end),
        vehicle = optionalReading("Vehicle", function() return collectVehicle(player) end),
        weapon = optionalReading("Weapon", function() return collectWeapon(player) end),
    }
end

local function writeState()
    -- VERIFICARE: il player locale e disponibile nel callback client.
    local player = getPlayer()
    if player == nil then
        return
    end

    local stateOk, state = pcall(collectState, player)
    if not stateOk then
        print("[StreamDeckPZ] Could not collect player state: " .. tostring(state))
        return
    end

    -- Encode before opening: a formatting failure must not truncate the previous JSON.
    local encodeOk, json = pcall(encodeState, state)
    if not encodeOk then
        print("[StreamDeckPZ] Could not encode state: " .. tostring(json))
        return
    end

    -- VERIFICARE: firma, creazione directory annidate e percorso Lua del profilo.
    local openOk, writer = pcall(getFileWriter, OUTPUT_PATH, true, false)
    if not openOk or writer == nil then
        print("[StreamDeckPZ] Could not open state file: " .. tostring(writer))
        return
    end

    local writeOk, writeError = pcall(function()
        writer:write(json)
    end)
    local closeOk, closeError = pcall(function()
        writer:close()
    end)

    if not writeOk then
        print("[StreamDeckPZ] Could not write state file: " .. tostring(writeError))
    end
    if not closeOk then
        print("[StreamDeckPZ] Could not close state file: " .. tostring(closeError))
    end
end

local function updateIfDue()
    local now = realTimeSeconds()
    if now >= lastAttemptAt and now - lastAttemptAt < UPDATE_INTERVAL_SECONDS then
        return
    end

    lastAttemptAt = now
    writeState()
end

function StreamDeckPZ.onTick()
    local ok, err = pcall(updateIfDue)
    if not ok then
        print("[StreamDeckPZ] Unexpected export error: " .. tostring(err))
    end
end

-- VERIFICARE: eventi e timing dei callback nella build 42 installata.
Events.OnGameStart.Add(StreamDeckPZ.onTick)
Events.OnTick.Add(StreamDeckPZ.onTick)
