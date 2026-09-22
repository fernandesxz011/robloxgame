-- Standard Roblox scale: 1 stud = 0.28 metres.
-- https://create.roblox.com/docs/physics/units
local VehicleUnits = {}

VehicleUnits.STUD_METERS = 0.28
VehicleUnits.KMH_PER_STUD_PER_SECOND = VehicleUnits.STUD_METERS * 3.6

function VehicleUnits.studsPerSecondToKmh(value)
    return value * VehicleUnits.KMH_PER_STUD_PER_SECOND
end

function VehicleUnits.kmhToStudsPerSecond(value)
    return value / VehicleUnits.KMH_PER_STUD_PER_SECOND
end

return table.freeze(VehicleUnits)
