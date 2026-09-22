-- Paste into the Studio command bar at the start of Play, in server view.
-- Reads the generated map and reports geometry that can block streets or access.
local city = assert(workspace:FindFirstChild("Downtown"), "Downtown has not loaded")
local districts = assert(city:FindFirstChild("BrazilianDistricts"), "Brazilian districts have not loaded")
local relief = assert(districts:FindFirstChild("Relevo"), "Relief has not loaded")
local roads = assert(districts:FindFirstChild("RuasELadeiras"), "Roads have not loaded")
local problems, roadCount, stairs, buildings = {}, 0, 0, 0
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { city }

for _, object in ipairs(districts:GetDescendants()) do
    if object.Name == "PaintedMasonry" then buildings += 1 end
    if object:IsA("BasePart") and object.Name == "Asphalt" and object:IsDescendantOf(roads) then
        roadCount += 1
        local grade = math.deg(math.asin(math.abs(object.CFrame.LookVector.Y)))
        if grade > districts:GetAttribute("MaximumRoadGradeDegrees") + 0.01 then
            table.insert(problems, "Road exceeds allowed grade: " .. object.Parent.Name)
        end
        -- A 6-stud vertical corridor above traffic catches walls, posts and low
        -- awnings. Road slabs and low curbs sit below the checked space.
        local frame = object.CFrame * CFrame.new(0, object.Size.Y / 2 + 3.7, 0)
        for _, obstruction in ipairs(workspace:GetPartBoundsInBox(frame,
            Vector3.new(object.Size.X - 1, 6, object.Size.Z - 0.5), overlap)) do
            if obstruction.CanCollide and not obstruction:IsDescendantOf(roads)
                and not obstruction:IsDescendantOf(relief) then
                table.insert(problems, object.Parent.Name .. " blocked by " .. obstruction:GetFullName())
            end
        end
    end
end

local terrainRay = RaycastParams.new()
terrainRay.FilterType = Enum.RaycastFilterType.Include
terrainRay.FilterDescendantsInstances = { relief }
for _, object in ipairs(districts:GetDescendants()) do
    if object.Name == "DoorwayStair" then
        stairs += 1
        local bottom = object.Position - Vector3.new(0, object.Size.Y / 2, 0)
        local ground = workspace:Raycast(bottom + Vector3.new(0, 5, 0), Vector3.new(0, -15, 0), terrainRay)
        if not ground or bottom.Y > ground.Position.Y + 0.05 then
            table.insert(problems, "Floating hillside stair at " .. tostring(object.Position))
        end
    end
end

local destinations = { "GarageDestination", "BelaVistaDestination", "IpesDestination", "FeiraDestination", "MiranteDestination" }
local floorRay = RaycastParams.new()
floorRay.FilterType = Enum.RaycastFilterType.Include
floorRay.FilterDescendantsInstances = { districts }
for _, name in ipairs(destinations) do
    local marker = city:FindFirstChild(name)
    if not marker or not marker:IsA("BasePart") then
        table.insert(problems, "Missing destination: " .. name)
    else
        local count = 0
        for _, child in ipairs(city:GetChildren()) do
            if child.Name == name then count += 1 end
        end
        if count ~= 1 then table.insert(problems, "Duplicate destination: " .. name) end
        if marker.CanCollide or marker.CanQuery or marker.Transparency ~= 1 then
            table.insert(problems, "Destination marker is not invisible and passable: " .. name)
        end
        local ground = workspace:Raycast(marker.Position + Vector3.new(0, 1, 0), Vector3.new(0, -6, 0), floorRay)
        if not ground or math.abs(ground.Position.Y - marker.Position.Y) > 2 then
            table.insert(problems, "Destination has no nearby supporting floor: " .. name)
        end
        for _, obstruction in ipairs(workspace:GetPartBoundsInBox(CFrame.new(marker.Position + Vector3.new(0, 3, 0)),
            Vector3.new(4, 4, 4), overlap)) do
            if obstruction.CanCollide then
                table.insert(problems, name .. " blocked by " .. obstruction:GetFullName())
            end
        end
    end
end

if roadCount == 0 or stairs == 0 then table.insert(problems, "Map geometry is incomplete") end
if buildings ~= districts:GetAttribute("BuildingCount") then table.insert(problems, "Building count does not match generated homes and shops") end
local result = { roads = roadCount, stairs = stairs, buildings = buildings, destinations = #destinations, problems = problems }
print("STUDIO_CITY_CHECK", game:GetService("HttpService"):JSONEncode(result))
assert(#problems == 0, "City geometry check found " .. #problems .. " issues")
print("STUDIO_CITY_CHECK_OK")
