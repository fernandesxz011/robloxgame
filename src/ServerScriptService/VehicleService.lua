local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VehicleCatalog = require(script.Parent:WaitForChild("VehicleCatalog"))

local VehicleService = {}
local activeCleanup
local UP = Vector3.new(0, 1, 0)
local BLACK = Color3.fromRGB(28, 32, 33)
local CHROME = Color3.fromRGB(181, 188, 186)
local GLASS = Color3.fromRGB(93, 133, 144)

local function rgb(value)
    return Color3.fromRGB(value[1], value[2], value[3])
end

local function finite(value)
    return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function approach(current, target, step)
    return current + math.clamp(target - current, -step, step)
end

local function label(part, face, text, color, background)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "VehicleLettering"
    gui.Face = face
    gui.CanvasSize = Vector2.new(520, 150)
    gui.LightInfluence = 0.2
    gui.MaxDistance = 90
    gui.Parent = part
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.fromScale(1, 1)
    textLabel.BackgroundTransparency = background and 0 or 1
    textLabel.BackgroundColor3 = background or BLACK
    textLabel.Text = text
    textLabel.TextColor3 = color or Color3.fromRGB(245, 238, 216)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Parent = gui
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0.035, 0)
    padding.PaddingRight = UDim.new(0.035, 0)
    padding.Parent = textLabel
    return gui
end

local function buildVehicle(fleet, specification, placement)
    local model = Instance.new("Model")
    model.Name = specification.displayName .. "_" .. placement.plate
    model:SetAttribute("DowntownVehicle", true)
    model:SetAttribute("VehicleId", specification.id)
    model:SetAttribute("DisplayName", specification.displayName)
    model:SetAttribute("Inspiration", specification.inspiration)
    model:SetAttribute("LicensePlate", placement.plate)
    model:SetAttribute("VehicleStyle", specification.style)

    local position = Vector3.new(table.unpack(placement.position))
    local spawnFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(placement.yaw or 0), 0)
    local length, width = specification.length, specification.width
    local paint = placement.taxi and Color3.fromRGB(245, 198, 58) or rgb(specification.color)
    local accent = rgb(specification.accent)
    local style = specification.style
    local wheelY = -0.7
    local wheelX = length * (style == "bus" and 0.32 or 0.30)
    local roofY = specification.roofHeight
    local chassis

    local function part(name, size, offset, color, material, rotation)
        local item = Instance.new("Part")
        item.Name = name
        item.Size = size
        item.CFrame = spawnFrame * CFrame.new(offset) * (rotation or CFrame.identity)
        item.Color = color or paint
        item.Material = material or Enum.Material.SmoothPlastic
        item.TopSurface = Enum.SurfaceType.Smooth
        item.BottomSurface = Enum.SurfaceType.Smooth
        item.Anchored = true
        item.CanCollide = false
        item.CanTouch = false
        item.CanQuery = false
        item.CastShadow = true
        item.Parent = model
        return item
    end

    local function window(name, size, offset, rotation)
        local pane = part(name, size, offset, GLASS, Enum.Material.Glass, rotation)
        pane.Transparency = 0.32
        pane.Reflectance = 0.12
        return pane
    end

    chassis = part("Chassis", Vector3.new(length * 0.82, 0.7, width * 0.88), Vector3.zero, BLACK)
    chassis.CanCollide = true
    chassis.CanQuery = true
    chassis.RootPriority = 127
    chassis.CustomPhysicalProperties = PhysicalProperties.new(1.8, 0, 0, 100, 100)
    model.PrimaryPart = chassis
    part("LowerBody", Vector3.new(length, 0.85, width), Vector3.new(0, 0.42, 0), paint)
    part("SillLeft", Vector3.new(length * 0.77, 0.23, 0.16), Vector3.new(0, -0.08, -width / 2 - 0.02), accent)
    part("SillRight", Vector3.new(length * 0.77, 0.23, 0.16), Vector3.new(0, -0.08, width / 2 + 0.02), accent)

    local cabinX, cabinLength = -0.35, length * 0.48
    if style == "compact" then cabinX, cabinLength = -0.6, length * 0.60 end
    if style == "sedan" then cabinX, cabinLength = -0.5, length * 0.43 end
    if style == "pickup" then cabinX, cabinLength = length * 0.18, length * 0.36 end
    if style == "van" or style == "bus" then cabinX, cabinLength = 0, length * 0.95 end
    local cabinWidth = width - (style == "bus" and 0.1 or 0.45)
    local glassBottom = style == "bus" and 1.55 or 1.05
    local glassHeight = roofY - glassBottom - 0.22
    local glassY = glassBottom + glassHeight / 2
    local frontCabin = cabinX + cabinLength / 2
    local backCabin = cabinX - cabinLength / 2

    part("Roof", Vector3.new(cabinLength, 0.25, cabinWidth), Vector3.new(cabinX, roofY, 0),
        (style == "van" or style == "bus") and accent or paint)
    window("Windshield", Vector3.new(0.14, glassHeight, cabinWidth - 0.28), Vector3.new(frontCabin, glassY, 0))
    window("RearWindow", Vector3.new(0.13, glassHeight * 0.84, cabinWidth - 0.32), Vector3.new(backCabin, glassY, 0))
    for _, side in ipairs({ -1, 1 }) do
        local sideZ = side * cabinWidth / 2
        for _, endX in ipairs({ frontCabin, backCabin }) do
            part("WindowPillar", Vector3.new(0.16, roofY - 0.72, 0.19), Vector3.new(endX, (roofY + 0.72) / 2, sideZ), paint)
        end
        local panes = style == "bus" and 5 or (style == "van" and 4 or (style == "pickup" and 1 or 2))
        local paneLength = (cabinLength - 0.3) / panes
        for index = 1, panes do
            local x = backCabin + 0.15 + paneLength * (index - 0.5)
            window("SideWindow" .. index, Vector3.new(paneLength - 0.13, glassHeight, 0.10), Vector3.new(x, glassY, sideZ))
            if index < panes then
                part("WindowDivider", Vector3.new(0.12, glassHeight + 0.1, 0.17), Vector3.new(x + paneLength / 2, glassY, sideZ), paint)
            end
            if style ~= "bus" and index <= 2 then
                part("DoorHandle", Vector3.new(0.45, 0.10, 0.13), Vector3.new(x - paneLength * 0.25, 0.92, side * (width / 2 + 0.05)), accent)
            end
        end
        local mirrorX = frontCabin - 0.2
        part("MirrorArm", Vector3.new(0.14, 0.13, 0.6), Vector3.new(mirrorX, glassBottom + 0.15, side * (width / 2 + 0.16)), BLACK)
        part("MirrorHousing", Vector3.new(0.38, 0.38, 0.22), Vector3.new(mirrorX, glassBottom + 0.3, side * (width / 2 + 0.5)), accent)
        part("MirrorGlass", Vector3.new(0.05, 0.27, 0.18), Vector3.new(mirrorX - 0.21, glassBottom + 0.3, side * (width / 2 + 0.5)), CHROME, Enum.Material.Metal)
    end

    if style == "beetle" then
        local bonnet = part("RoundedBonnet", Vector3.new(4.1, 1.7, width - 0.25), Vector3.new(length * 0.28, 0.8, 0), paint)
        bonnet.Shape = Enum.PartType.Ball
        local rear = part("RoundedEngineCover", Vector3.new(3.3, 1.5, width - 0.25), Vector3.new(-length * 0.32, 0.8, 0), paint)
        rear.Shape = Enum.PartType.Ball
        local roof = model:FindFirstChild("Roof")
        roof.Shape = Enum.PartType.Ball
        roof.Size = Vector3.new(cabinLength + 0.1, 0.95, cabinWidth + 0.08)
        roof.CFrame = spawnFrame * CFrame.new(cabinX, roofY - 0.2, 0)
        for _, x in ipairs({ wheelX, -wheelX }) do
            for _, side in ipairs({ -1, 1 }) do
                local fender = part("RoundedFender", Vector3.new(2.9, 1.05, 0.8), Vector3.new(x, 0.03, side * (width / 2 - 0.12)), paint)
                fender.Shape = Enum.PartType.Ball
            end
        end
        for index = 1, 5 do
            part("EngineVent", Vector3.new(0.06, 0.06, width * 0.5), Vector3.new(-length / 2 - 0.02, 0.65 + index * 0.12, 0), BLACK)
        end
    elseif style == "pickup" then
        local bedLength = length * 0.43
        local bedX = -length / 2 + bedLength / 2
        part("OpenCargoBed", Vector3.new(bedLength - 0.15, 0.15, width - 0.4), Vector3.new(bedX, 0.93, 0), BLACK)
        for _, side in ipairs({ -1, 1 }) do
            part("CargoBedSide", Vector3.new(bedLength, 0.75, 0.18), Vector3.new(bedX, 1.2, side * (width / 2 - 0.08)), paint)
            part("CargoRail", Vector3.new(bedLength, 0.1, 0.26), Vector3.new(bedX, 1.59, side * (width / 2 - 0.08)), BLACK)
        end
        part("Tailgate", Vector3.new(0.18, 0.75, width), Vector3.new(-length / 2 + 0.05, 1.2, 0), paint)
        for index = 1, 5 do
            part("BedRib", Vector3.new(bedLength - 0.25, 0.05, 0.07), Vector3.new(bedX, 1.025, (index - 3) * 0.65), CHROME)
        end
    elseif style == "van" or style == "bus" then
        part("UpperBodyBand", Vector3.new(length, glassBottom - 0.65, width), Vector3.new(0, (glassBottom + 0.65) / 2, 0), accent)
        if style == "van" then
            part("SplitWindshieldBar", Vector3.new(0.19, glassHeight, 0.12), Vector3.new(frontCabin + 0.05, glassY, 0), accent)
            for _, side in ipairs({ -1, 1 }) do
                local sign = part("FeiraLettering", Vector3.new(4.5, 0.6, 0.07), Vector3.new(-1, 0.42, side * (width / 2 + 0.04)), paint)
                label(sign, side == 1 and Enum.NormalId.Back or Enum.NormalId.Front, "FEIRA DO BAIRRO", BLACK)
                part("RoofRackRail", Vector3.new(length * 0.58, 0.16, 0.14), Vector3.new(-0.8, roofY + 0.4, side * (width * 0.35)), CHROME, Enum.Material.Metal)
            end
            for _, x in ipairs({ -3, 0, 2 }) do
                part("RoofRackCrossbar", Vector3.new(0.13, 0.12, width * 0.76), Vector3.new(x, roofY + 0.25, 0), CHROME, Enum.Material.Metal)
            end
        else
            local destination = part("DestinationDisplay", Vector3.new(0.19, 0.59, width - 0.4), Vector3.new(frontCabin + 0.08, roofY - 0.46, 0), BLACK)
            label(destination, Enum.NormalId.Right, "305  BELA VISTA / CENTRO", Color3.fromRGB(255, 208, 83))
            for _, side in ipairs({ -1, 1 }) do
                local banner = part("MunicipalLivery", Vector3.new(length * 0.77, 0.6, 0.08), Vector3.new(-0.4, 0.45, side * (width / 2 + 0.045)), paint)
                label(banner, side == 1 and Enum.NormalId.Back or Enum.NormalId.Front, "CIRCULAR DA SERRA   •   305")
                for index = 1, 4 do
                    part("PassengerBench", Vector3.new(0.9, 0.2, 1.55), Vector3.new(-5.7 + index * 2.1, 1.1, side * 1.7), Color3.fromRGB(50, 73, 76))
                    part("PassengerBackrest", Vector3.new(0.2, 1.0, 1.55), Vector3.new(-6.1 + index * 2.1, 1.5, side * 1.7), Color3.fromRGB(50, 73, 76))
                end
            end
            part("FrontEntrySteps", Vector3.new(1.4, 0.18, 0.55), Vector3.new(length * 0.3, -0.35, width / 2 + 0.13), CHROME)
        end
    else
        local hoodLength = math.max(0.4, length / 2 - frontCabin)
        part("Hood", Vector3.new(hoodLength, 0.24, width - 0.15), Vector3.new(frontCabin + hoodLength / 2, 0.98, 0), paint)
        if style == "sedan" then
            part("LongTrunk", Vector3.new(length / 2 + backCabin, 0.23, width - 0.15), Vector3.new((-length / 2 + backCabin) / 2, 0.98, 0), paint)
        end
    end

    for _, endSign in ipairs({ -1, 1 }) do
        part("Bumper", Vector3.new(0.26, 0.32, width + 0.2), Vector3.new(endSign * (length / 2 + 0.12), 0.08, 0), accent,
            (style == "beetle" or style == "sedan" or style == "van") and Enum.Material.Metal or Enum.Material.SmoothPlastic)
        local plate = part("BrazilianPlate", Vector3.new(0.09, 0.38, 1.35), Vector3.new(endSign * (length / 2 + 0.29), 0.37, 0), Color3.fromRGB(242, 241, 229))
        local face = endSign == 1 and Enum.NormalId.Right or Enum.NormalId.Left
        label(plate, face, placement.plate, BLACK)
        local strip = part("PlateBlueBand", Vector3.new(0.095, 0.095, 1.35), Vector3.new(endSign * (length / 2 + 0.29), 0.61, 0), Color3.fromRGB(30, 72, 149))
        label(strip, face, "BRASIL", Color3.new(1, 1, 1))
    end
    part("Grille", Vector3.new(0.09, 0.48, width * 0.46), Vector3.new(length / 2 + 0.03, 0.77, 0), BLACK)
    for index = 1, 3 do
        part("GrilleSlat", Vector3.new(0.1, 0.05, width * 0.43), Vector3.new(length / 2 + 0.09, 0.58 + index * 0.11, 0), CHROME)
    end
    local tailLights = {}
    for _, side in ipairs({ -1, 1 }) do
        local headlight = part("Headlight", Vector3.new(0.13, 0.54, 0.73), Vector3.new(length / 2 + 0.11, 0.79, side * width * 0.35), Color3.fromRGB(255, 235, 174), Enum.Material.Neon)
        if style == "beetle" or style == "van" then
            headlight.Shape = Enum.PartType.Cylinder
            headlight.Size = Vector3.new(0.15, 0.69, 0.69)
        end
        local tail = part("TailLight", Vector3.new(0.12, 0.49, 0.53), Vector3.new(-length / 2 - 0.1, 0.71, side * width * 0.37), Color3.fromRGB(154, 39, 30), Enum.Material.Neon)
        table.insert(tailLights, tail)
        part("Indicator", Vector3.new(0.14, 0.21, 0.29), Vector3.new(length / 2 + 0.11, 0.41, side * width * 0.39), Color3.fromRGB(244, 155, 40), Enum.Material.Neon)
    end

    local wheelOffsets = {}
    for _, x in ipairs({ wheelX, -wheelX }) do
        for _, side in ipairs({ -1, 1 }) do
            local radius = specification.wheelRadius
            local z = side * (width / 2 - 0.02)
            local offset = Vector3.new(x, wheelY, z)
            table.insert(wheelOffsets, offset)
            local tire = part("Tire", Vector3.new(0.54, radius * 2, radius * 2), offset, BLACK, Enum.Material.Rubber, CFrame.Angles(0, math.pi / 2, 0))
            tire.Shape = Enum.PartType.Cylinder
            tire.CanCollide = true
            -- The arcade controller supplies grip; free-sliding round contacts climb ramps.
            tire.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100)
            local hub = part("WheelHub", Vector3.new(0.07, radius * 1.23, radius * 1.23), Vector3.new(x, wheelY, z + side * 0.30), CHROME, Enum.Material.Metal, CFrame.Angles(0, math.pi / 2, 0))
            hub.Shape = Enum.PartType.Cylinder
            local cap = part("Hubcap", Vector3.new(0.09, radius * 0.45, radius * 0.45), Vector3.new(x, wheelY, z + side * 0.35), style == "beetle" and CHROME or BLACK, Enum.Material.Metal, CFrame.Angles(0, math.pi / 2, 0))
            cap.Shape = Enum.PartType.Cylinder
            for spoke = 0, 3 do
                local angle = spoke * math.pi / 2
                part("WheelBolt", Vector3.new(0.1, 0.09, 0.06), Vector3.new(x + math.cos(angle) * radius * 0.37, wheelY + math.sin(angle) * radius * 0.37, z + side * 0.35), BLACK)
            end
        end
    end

    local seatX = (style == "bus" or style == "van") and length * 0.32 or cabinX + 0.45
    local seat = Instance.new("VehicleSeat")
    seat.Name = "DriverSeat"
    seat.Size = Vector3.new(1.4, 0.35, 1.5)
    seat.CFrame = spawnFrame * CFrame.new(seatX, 0.4, -width * 0.22) * CFrame.Angles(0, -math.pi / 2, 0)
    seat.Color = BLACK
    seat.Material = Enum.Material.Fabric
    seat.CanCollide = false
    seat.CanTouch = false
    seat.HeadsUpDisplay = false
    seat.Anchored = true
    seat.Parent = model
    part("DriverBackrest", Vector3.new(0.24, 1.05, 1.3), Vector3.new(seatX - 0.75, 0.88, -width * 0.22), BLACK, Enum.Material.Fabric)
    part("Dashboard", Vector3.new(0.55, 0.26, cabinWidth - 0.25), Vector3.new(frontCabin - 0.43, 1.10, 0), BLACK)
    local steeringWheel = part("SteeringWheel", Vector3.new(0.1, 0.7, 0.7), Vector3.new(seatX + 0.8, 1.1, -width * 0.22), BLACK)
    steeringWheel.Shape = Enum.PartType.Cylinder
    if placement.taxi then
        local taxiSign = part("TaxiRoofSign", Vector3.new(0.8, 0.52, 1.8), Vector3.new(cabinX, roofY + 0.36, 0), Color3.fromRGB(255, 233, 149))
        label(taxiSign, Enum.NormalId.Right, "TÁXI", BLACK)
        label(taxiSign, Enum.NormalId.Left, "TÁXI", BLACK)
        model:SetAttribute("ServiceType", "Taxi")
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "EnterVehicle"
    prompt.ActionText = "Dirigir"
    prompt.ObjectText = specification.displayName
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.25
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Parent = seat

    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("BasePart") then
            if item ~= chassis then
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = chassis
                weld.Part1 = item
                weld.Parent = item
                item.Massless = true
            end
            item.Anchored = false
        end
    end
    local attachment = Instance.new("Attachment")
    attachment.Name = "VehicleMotion"
    attachment.Parent = chassis
    local drive = Instance.new("LinearVelocity")
    drive.Name = "GroundDrive"
    drive.Attachment0 = attachment
    drive.RelativeTo = Enum.ActuatorRelativeTo.World
    drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
    drive.PrimaryTangentAxis = Vector3.new(1, 0, 0)
    drive.SecondaryTangentAxis = Vector3.new(0, 0, 1)
    drive.ForceLimitsEnabled = true
    drive.ForceLimitMode = Enum.ForceLimitMode.Magnitude
    drive.MaxForce = 90000
    drive.Enabled = false
    drive.Parent = chassis
    -- CFrame is rebuilt from the actual ground normal, including pitch and roll.
    -- https://create.roblox.com/docs/physics/constraints/align-orientation
    local align = Instance.new("AlignOrientation")
    align.Name = "GroundSteering"
    align.Attachment0 = attachment
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.RigidityEnabled = false
    align.Responsiveness = 16
    align.MaxTorque = 150000
    align.MaxAngularVelocity = 3.5
    align.CFrame = spawnFrame.Rotation
    align.Enabled = false
    align.Parent = chassis
    model.Parent = fleet
    chassis:SetNetworkOwner(nil)

    return {
        model = model, chassis = chassis, seat = seat, prompt = prompt,
        drive = drive, align = align, specification = specification,
        spawnFrame = spawnFrame, wheelOffsets = wheelOffsets, tailLights = tailLights,
        throttle = 0, steer = 0, updatedAt = 0, speed = 0,
        heading = math.rad(placement.yaw or 0), normal = UP,
        overturnedFor = 0, connections = {},
    }
end

local VehicleUnits = require(game:GetService("ReplicatedStorage"):WaitForChild("VehicleUnits"))

local function motionSettings(specification)
    local function converted(metric, legacy, default)
        if finite(metric) and metric > 0 then return VehicleUnits.kmhToStudsPerSecond(metric) end
        if finite(legacy) and legacy > 0 then return legacy end
        return default
    end
    return {
        speed = converted(specification.speedKmh, specification.speed, 40),
        reverseSpeed = converted(specification.reverseSpeedKmh, specification.reverseSpeed, 14),
        acceleration = converted(specification.accelerationKmhPerSecond, specification.acceleration, 14),
        brake = converted(specification.brakeKmhPerSecond, nil, 28),
    }
end

local function advanceSpeed(current, throttle, motion, dt)
    local requested = throttle * (throttle >= 0 and motion.speed or motion.reverseSpeed)
    local reversing = current * requested < 0
    local braking = throttle == 0 or reversing or math.abs(requested) < math.abs(current)
    -- Brake to a complete stop before accelerating in the opposite direction.
    if reversing then requested = 0 end
    return approach(current, requested, (braking and motion.brake or motion.acceleration) * dt), braking
end

function VehicleService.start(cityRoot, vehicleInputRemote)
    if activeCleanup then activeCleanup() end
    local fleet = Instance.new("Folder")
    fleet.Name = "Vehicles"
    fleet:SetAttribute("LibraryName", "Garagem Brasileira")
    fleet:SetAttribute("CatalogCount", #VehicleCatalog.models)
    fleet.Parent = cityRoot
    local vehicles, controlsBySeat, connections = {}, {}, {}
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.RespectCanCollide = true
    local cleaned = false
    local filterElapsed = 1

    local function resetInput(vehicle)
        vehicle.throttle, vehicle.steer, vehicle.updatedAt = 0, 0, 0
    end

    local function available(vehicle)
        return not cleaned and not vehicle.released and fleet:IsDescendantOf(Workspace)
            and vehicle.model:IsDescendantOf(fleet)
            and vehicle.chassis:IsDescendantOf(vehicle.model)
            and vehicle.seat:IsDescendantOf(vehicle.model)
    end

    local function releaseVehicle(vehicle)
        if vehicle.released then return end
        vehicle.released = true
        resetInput(vehicle)
        controlsBySeat[vehicle.seat] = nil
        for _, connection in ipairs(vehicle.connections) do connection:Disconnect() end
        table.clear(vehicle.connections)
        vehicle.prompt.Enabled = false
        vehicle.drive.Enabled = false
        vehicle.align.Enabled = false
    end

    for _, placement in ipairs(VehicleCatalog.fleet) do
        local specification = assert(VehicleCatalog.get(placement.id), "Unknown vehicle: " .. placement.id)
        local vehicle = buildVehicle(fleet, specification, placement)
        vehicle.motion = motionSettings(specification)
        vehicle.model:SetAttribute("MaxSpeedKmh", VehicleUnits.studsPerSecondToKmh(vehicle.motion.speed))
        vehicle.model:SetAttribute("ReverseSpeedKmh", VehicleUnits.studsPerSecondToKmh(vehicle.motion.reverseSpeed))
        table.insert(vehicles, vehicle)
        controlsBySeat[vehicle.seat] = vehicle
        table.insert(vehicle.connections, vehicle.model.Destroying:Connect(function()
            releaseVehicle(vehicle)
        end))
        table.insert(vehicle.connections, vehicle.prompt.Triggered:Connect(function(player)
            if not available(vehicle) or not vehicle.prompt.Enabled or player.Parent ~= Players
                or player:GetAttribute("DataReady") ~= true then return end
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not root or not root:IsA("BasePart") or not character:IsDescendantOf(Workspace)
                or not humanoid or humanoid.Health <= 0 or humanoid.Sit or humanoid.SeatPart
                or vehicle.seat.Occupant then return end
            local distance = (root.Position - vehicle.seat.Position).Magnitude
            if not finite(distance) or distance > 11 then return end
            vehicle.seat:Sit(humanoid)
        end))
        table.insert(vehicle.connections, vehicle.seat:GetPropertyChangedSignal("Occupant"):Connect(function()
            if not available(vehicle) then return end
            resetInput(vehicle)
            local occupant = vehicle.seat.Occupant
            vehicle.prompt.Enabled = occupant == nil
            if occupant then
                local player = Players:GetPlayerFromCharacter(occupant.Parent)
                if not player or player.Parent ~= Players or player.Character ~= occupant.Parent
                    or player:GetAttribute("DataReady") ~= true or occupant.Health <= 0 then
                    occupant.Sit = false
                end
            end
            if vehicle.chassis:IsDescendantOf(Workspace) then vehicle.chassis:SetNetworkOwner(nil) end
        end))
    end

    table.insert(connections, vehicleInputRemote.OnServerEvent:Connect(function(player, throttle, steer)
        if cleaned or player.Parent ~= Players or player:GetAttribute("DataReady") ~= true
            or not finite(throttle) or not finite(steer) then return end
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        local seat = humanoid and humanoid.SeatPart
        local vehicle = seat and controlsBySeat[seat]
        if not vehicle or not available(vehicle) or humanoid.Health <= 0 or seat.Occupant ~= humanoid then return end
        local now = os.clock()
        if now - vehicle.updatedAt < 1 / 30 then return end
        vehicle.throttle = math.clamp(throttle, -1, 1)
        vehicle.steer = math.clamp(steer, -1, 1)
        vehicle.updatedAt = now
    end))

    local function cleanup()
        if cleaned then return end
        cleaned = true
        for _, connection in ipairs(connections) do connection:Disconnect() end
        for _, vehicle in ipairs(vehicles) do releaseVehicle(vehicle) end
        table.clear(vehicles)
        table.clear(controlsBySeat)
        if fleet.Parent then fleet:Destroy() end
        if activeCleanup == cleanup then activeCleanup = nil end
    end
    activeCleanup = cleanup

    table.insert(connections, RunService.Heartbeat:Connect(function(deltaTime)
        if not fleet:IsDescendantOf(Workspace) then cleanup() return end
        local dt = math.min(deltaTime, 0.1)
        filterElapsed = filterElapsed + deltaTime
        if filterElapsed >= 1 then
            filterElapsed = 0
            local excluded = { fleet }
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then table.insert(excluded, player.Character) end
            end
            raycastParams.FilterDescendantsInstances = excluded
        end
        local now = os.clock()
        for index = #vehicles, 1, -1 do
            local vehicle = vehicles[index]
            local chassis, seat = vehicle.chassis, vehicle.seat
            if not available(vehicle) then
                releaseVehicle(vehicle)
                table.remove(vehicles, index)
                continue
            end
            local occupant = seat.Occupant
            local driver = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
            local active = occupant and occupant.Health > 0 and occupant.SeatPart == seat
                and driver and driver.Parent == Players and driver.Character == occupant.Parent
                and driver:GetAttribute("DataReady") == true
                and now - vehicle.updatedAt < 0.5
            local throttle, steer = active and vehicle.throttle or 0, active and vehicle.steer or 0
            local spec = vehicle.specification
            local braking
            vehicle.speed, braking = advanceSpeed(vehicle.speed, throttle, vehicle.motion, dt)

            local normals, contactCount = Vector3.zero, 0
            for _, offset in ipairs(vehicle.wheelOffsets) do
                local origin = chassis.CFrame:PointToWorldSpace(Vector3.new(offset.X, 0, offset.Z)) + UP * 3
                local hit = Workspace:Raycast(origin, -UP * (spec.wheelRadius + 5.1), raycastParams)
                if hit and hit.Normal.Y > 0.65 then
                    normals = normals + hit.Normal
                    contactCount = contactCount + 1
                end
            end
            local grounded = contactCount >= 2
            local groundNormal = grounded and normals.Unit or UP
            vehicle.normal = vehicle.normal:Lerp(groundNormal, 1 - math.exp(-9 * dt)).Unit
            -- Signed speed makes steering reverse naturally; no turning in place.
            local turning = math.clamp(vehicle.speed / 12, -1, 1)
            local speedKmh = math.abs(VehicleUnits.studsPerSecondToKmh(vehicle.speed))
            local steeringGrip = math.max(0.22, 1 / (1 + (speedKmh / 45) ^ 2))
            if grounded then vehicle.heading = vehicle.heading - steer * turning * steeringGrip * spec.turnRate * dt end
            local flatForward = Vector3.new(math.cos(vehicle.heading), 0, -math.sin(vehicle.heading))
            local forward = (flatForward - vehicle.normal * flatForward:Dot(vehicle.normal)).Unit
            local right = forward:Cross(vehicle.normal).Unit
            vehicle.align.CFrame = CFrame.fromMatrix(Vector3.zero, forward, vehicle.normal, right)
            vehicle.align.Enabled = grounded
            vehicle.drive.Enabled = grounded
            vehicle.drive.PrimaryTangentAxis = forward
            vehicle.drive.SecondaryTangentAxis = right
            vehicle.drive.PlaneVelocity = Vector2.new(vehicle.speed, 0)
            -- Gravity remains free along the ground normal; ramps do not pin Y.
            -- https://create.roblox.com/docs/physics/constraints/linear-velocity
            for _, light in ipairs(vehicle.tailLights) do
                light.Color = braking and math.abs(vehicle.speed) > 0.8 and Color3.fromRGB(255, 59, 42) or Color3.fromRGB(154, 39, 30)
            end
            if chassis.CFrame.UpVector.Y < 0.25 then
                vehicle.overturnedFor = vehicle.overturnedFor + dt
            else
                vehicle.overturnedFor = 0
            end
            if chassis.Position.Y < -30 or vehicle.overturnedFor >= 5 then
                resetInput(vehicle)
                vehicle.speed, vehicle.overturnedFor = 0, 0
                vehicle.normal = UP
                vehicle.heading = math.atan2(-vehicle.spawnFrame.RightVector.Z, vehicle.spawnFrame.RightVector.X)
                vehicle.drive.PlaneVelocity = Vector2.zero
                vehicle.align.CFrame = vehicle.spawnFrame.Rotation
                vehicle.model:PivotTo(vehicle.spawnFrame)
                chassis.AssemblyLinearVelocity = Vector3.zero
                chassis.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end))
    table.insert(connections, fleet.Destroying:Connect(cleanup))
    table.insert(connections, cityRoot.Destroying:Connect(cleanup))
    return cleanup
end

return VehicleService
