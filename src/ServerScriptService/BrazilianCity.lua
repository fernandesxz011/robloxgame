-- Southeast-inspired urban districts built entirely with editable Roblox parts.
-- Heights below describe road surfaces. Terrain is local to this model, never
-- Workspace.Terrain, so rebuilding the city does not affect player housing.
local BrazilianCity = {}

local C = {
    grass = Color3.fromRGB(91, 126, 82), earth = Color3.fromRGB(131, 92, 67),
    asphalt = Color3.fromRGB(49, 53, 57), paving = Color3.fromRGB(206, 198, 177),
    white = Color3.fromRGB(244, 238, 216), dark = Color3.fromRGB(44, 61, 63),
    yellow = Color3.fromRGB(246, 196, 63), brick = Color3.fromRGB(177, 91, 64),
    tile = Color3.fromRGB(170, 78, 48), blue = Color3.fromRGB(52, 123, 183),
    wood = Color3.fromRGB(125, 84, 56), glass = Color3.fromRGB(104, 162, 175),
    green = Color3.fromRGB(48, 113, 79), pink = Color3.fromRGB(218, 116, 165),
}
local houseColors = {
    Color3.fromRGB(227, 172, 80), Color3.fromRGB(111, 170, 181),
    Color3.fromRGB(214, 131, 112), Color3.fromRGB(153, 181, 144),
    Color3.fromRGB(204, 178, 198), Color3.fromRGB(231, 214, 183),
}

local function group(parent, name)
    local model = Instance.new("Model")
    model.Name = name
    model.Parent = parent
    return model
end

local function part(parent, name, size, position, color, material, decorative)
    local item = Instance.new("Part")
    item.Name = name
    item.Size = size
    item.Position = position
    item.Anchored = true
    item.Material = material or Enum.Material.SmoothPlastic
    item.Color = color
    item.TopSurface = Enum.SurfaceType.Smooth
    item.BottomSurface = Enum.SurfaceType.Smooth
    if decorative then
        item.CanCollide = false
        item.CanTouch = false
        item.CastShadow = false
    end
    item.Parent = parent
    return item
end

local function signText(board, title, subtitle)
    for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
        local gui = Instance.new("SurfaceGui")
        gui.Name = "BrazilianSignage"
        gui.Face = face
        gui.CanvasSize = Vector2.new(720, 220)
        gui.LightInfluence = 0.25
        gui.Parent = board
        local heading = Instance.new("TextLabel")
        heading.BackgroundTransparency = 1
        heading.Position = UDim2.fromScale(0.035, 0.04)
        heading.Size = UDim2.fromScale(0.93, 0.62)
        heading.Text = title
        heading.TextScaled = true
        heading.TextColor3 = C.white
        heading.Font = Enum.Font.GothamBold
        heading.Parent = gui
        local caption = heading:Clone()
        caption.Position = UDim2.fromScale(0.035, 0.70)
        caption.Size = UDim2.fromScale(0.93, 0.23)
        caption.Text = subtitle or ""
        caption.Font = Enum.Font.GothamMedium
        caption.Parent = gui
    end
end

local function streetSign(parent, x, y, z, title, subtitle, width)
    local model = group(parent, "Placa_" .. title)
    part(model, "Post", Vector3.new(0.4, 7, 0.4), Vector3.new(x, y + 3.5, z), C.dark, Enum.Material.Metal)
    local board = part(model, "Sign", Vector3.new(width or 14, 3.2, 0.3), Vector3.new(x, y + 7, z), C.green)
    signText(board, title, subtitle)
    return model
end

-- Align a slab's TOP surface to the endpoints. This keeps ramp joins flush,
-- including the thickness offset on a slope; no invisible vertical step.
local function surface(parent, name, a, b, width, thickness, color, material, decorative)
    local direction = b - a
    local frame = CFrame.lookAt((a + b) * 0.5, b)
    local slab = part(parent, name, Vector3.new(width, thickness, direction.Magnitude), Vector3.zero, color, material, decorative)
    slab.CFrame = frame * CFrame.new(0, -thickness / 2, 0)
    return slab, frame
end

local function road(parent, name, a, b, width)
    local model = group(parent, name)
    local roadWidth = width or 24
    local asphalt, frame = surface(model, "Asphalt", a, b, roadWidth, 0.4, C.asphalt, Enum.Material.Asphalt)
    local length = (b - a).Magnitude
    local horizontal = Vector2.new(b.X - a.X, b.Z - a.Z).Magnitude
    model:SetAttribute("MaxGradeDegrees", math.deg(math.atan2(math.abs(b.Y - a.Y), horizontal)))
    model:SetAttribute("RoadWidth", roadWidth)
    for offset = -length / 2 + 8, length / 2 - 5, 14 do
        local dash = part(model, "CenterLine", Vector3.new(0.28, 0.02, 6), Vector3.zero, C.yellow, nil, true)
        dash.CFrame = frame * CFrame.new(0, 0.025, offset)
    end
    for _, side in ipairs({ -1, 1 }) do
        local edge = part(model, "EdgeLine", Vector3.new(0.2, 0.02, length), Vector3.zero, C.white, nil, true)
        edge.CFrame = frame * CFrame.new(side * (roadWidth / 2 - 1), 0.02, 0)
        -- Sidewalks follow the same grade as the road and stay outside traffic.
        local walk = part(model, "Sidewalk", Vector3.new(3.4, 0.32, length), Vector3.zero, C.paving, Enum.Material.Concrete)
        walk.CFrame = frame * CFrame.new(side * (roadWidth / 2 + 2), -0.05, 0)
    end
    return asphalt
end

local function ground(parent, name, xmin, xmax, zmin, zmax, top)
    return part(parent, name, Vector3.new(xmax - xmin, top + 9, zmax - zmin),
        Vector3.new((xmin + xmax) / 2, (top - 9) / 2, (zmin + zmax) / 2), C.grass, Enum.Material.Grass)
end

local function hillside(parent, name, startZ, endZ, height)
    local model = group(parent, name)
    local a, b = Vector3.new(0, 0.5, startZ), Vector3.new(0, height + 0.5, endZ)
    surface(model, "ContinuousGrassSlope", a, b, 1020, 2, C.grass, Enum.Material.Grass)
    -- Earth below the continuous grass slab closes its exposed sides. The top
    -- of each support remains below the low edge of the grass in that strip.
    for index = 0, 13 do
        local t0, t1 = index / 14, (index + 1) / 14
        local z0, z1 = startZ + (endZ - startZ) * t0, startZ + (endZ - startZ) * t1
        local top = height * t0 - 1.8
        part(model, "EarthSupport", Vector3.new(1019.8, top + 9, math.abs(z1 - z0)),
            Vector3.new(0, (top - 9) / 2, (z0 + z1) / 2), C.earth, Enum.Material.Ground)
    end
end

local function tank(parent, frame, roofY)
    local body = part(parent, "CaixaDAgua", Vector3.new(3.2, 4.5, 4.5), Vector3.zero, C.blue)
    body.Shape = Enum.PartType.Cylinder
    body.CFrame = frame * CFrame.new(5, roofY + 1.7, -3) * CFrame.Angles(0, 0, math.pi / 2)
    local lid = part(parent, "WaterTankLid", Vector3.new(0.35, 4.9, 4.9), Vector3.zero, Color3.fromRGB(34, 90, 151))
    lid.Shape = Enum.PartType.Cylinder
    lid.CFrame = frame * CFrame.new(5, roofY + 3.45, -3) * CFrame.Angles(0, 0, math.pi / 2)
end

local function house(parent, index, x, y, z, options)
    options = options or {}
    local model = group(parent, options.name or ("Sobrado" .. index))
    local frame = CFrame.new(x, y, z) * CFrame.Angles(0, options.yaw or 0, 0)
    local width, depth = options.width or 23, options.depth or 18
    local levels = options.levels or (index % 3 == 0 and 2 or 1)
    local height = levels * 7.5
    local color = houseColors[(index - 1) % #houseColors + 1]
    local function block(name, size, offset, tint, material, decorative)
        local item = part(model, name, size, Vector3.zero, tint, material, decorative)
        item.CFrame = frame * CFrame.new(offset)
        return item
    end
    block("Foundation", Vector3.new(width + 0.8, 1, depth + 0.8), Vector3.new(0, 0.3, 0), C.paving, Enum.Material.Concrete)
    block("PaintedMasonry", Vector3.new(width, height, depth), Vector3.new(0, 0.7 + height / 2, 0), color)
    block("Door", Vector3.new(3.1, 5.5, 0.2), Vector3.new(-width * 0.27, 3.55, depth / 2 + 0.12), C.wood, Enum.Material.Wood, true)
    block("DoorStep", Vector3.new(4.2, 0.35, 2.3), Vector3.new(-width * 0.27, 0.65, depth / 2 + 0.8), C.paving)
    for floor = 1, levels do
        for _, wx in ipairs({ -width * 0.29, width * 0.26 }) do
            if floor > 1 or wx > 0 then
                block("WindowFrame", Vector3.new(5, 3.5, 0.2), Vector3.new(wx, floor * 7.5 - 2.6, depth / 2 + 0.13), C.white, nil, true)
                block("Window", Vector3.new(4.4, 2.9, 0.22), Vector3.new(wx, floor * 7.5 - 2.6, depth / 2 + 0.25), C.glass, nil, true)
            end
        end
        block("SideWindow", Vector3.new(0.2, 3, 4.3), Vector3.new(width / 2 + 0.1, floor * 7.5 - 2.6, 0), C.glass, nil, true)
    end
    if index % 4 == 0 then
        block("ExposedBrickPanel", Vector3.new(width * 0.36, 5.8, 0.13), Vector3.new(width * 0.3, 3.65, -depth / 2 - 0.08), C.brick, Enum.Material.Brick, true)
    end
    local roofY = height + 0.8
    if index % 3 == 1 then
        for _, side in ipairs({ -1, 1 }) do
            local roof = block("CeramicRoof", Vector3.new(width / 2 + 1.5, 0.65, depth + 2), Vector3.new(side * width / 4, roofY + 2, 0), C.tile)
            roof.CFrame *= CFrame.Angles(0, 0, -side * math.rad(18))
        end
        block("RoofRidge", Vector3.new(0.8, 0.55, depth + 2.1), Vector3.new(0, roofY + 2 + math.sin(math.rad(18)) * width / 4, 0), C.tile)
    else
        block("ConcreteRoof", Vector3.new(width + 1.2, 0.55, depth + 1.2), Vector3.new(0, roofY, 0), C.paving, Enum.Material.Concrete)
        block("RoofParapet", Vector3.new(width + 1.2, 0.9, 0.4), Vector3.new(0, roofY + 0.65, -depth / 2 - 0.35), color)
        tank(model, frame, roofY + 0.3)
    end
    if options.shop then
        local board = block("ShopSign", Vector3.new(width - 1, 2.2, 0.25), Vector3.new(0, 6.7, depth / 2 + 0.3), C.green)
        signText(board, options.shop, options.subtitle or "COMÉRCIO DO BAIRRO")
        block("Awning", Vector3.new(width + 0.6, 0.4, 4), Vector3.new(0, 5.25, depth / 2 + 1.6), C.yellow)
    else
        local number = block("HouseNumber", Vector3.new(1.7, 1, 0.2), Vector3.new(-width * 0.1, 4.2, depth / 2 + 0.13), C.dark, nil, true)
        signText(number, tostring(100 + index * 7), "")
    end
    return model
end

local function tree(parent, x, y, z, kind, seed)
    local model = group(parent, kind == "palm" and "PalmeiraUrbana" or "Ipe")
    local height = kind == "palm" and 16 or 9 + (seed or 0) % 3
    part(model, "Trunk", Vector3.new(1, height, 1), Vector3.new(x, y + height / 2, z), C.wood, Enum.Material.Wood)
    if kind == "palm" then
        for index = 0, 4 do
            local angle = index * math.pi * 2 / 5
            local leaf = part(model, "PalmLeaf", Vector3.new(3, 0.7, 9), Vector3.zero, C.green, Enum.Material.Grass, true)
            leaf.CFrame = CFrame.new(x, y + height, z) * CFrame.Angles(0, angle, 0) * CFrame.new(0, -0.9, 3.5) * CFrame.Angles(math.rad(18), 0, 0)
        end
    else
        local tint = (seed or 0) % 3 == 0 and C.yellow or ((seed or 0) % 3 == 1 and C.pink or Color3.fromRGB(109, 148, 76))
        for _, offset in ipairs({ Vector3.new(-2.2, 0, 0), Vector3.new(2, 0, 0), Vector3.new(0, 2.5, 0) }) do
            local crown = part(model, "Crown", Vector3.new(7, 6, 7), Vector3.new(x, y + height, z) + offset, tint, nil, true)
            crown.Shape = Enum.PartType.Ball
        end
    end
end

local function lamp(parent, x, y, z)
    local model = group(parent, "PosteDeRua")
    part(model, "Pole", Vector3.new(0.5, 12, 0.5), Vector3.new(x, y + 6, z), C.dark, Enum.Material.Metal)
    part(model, "Arm", Vector3.new(3.5, 0.3, 0.4), Vector3.new(x + 1.5, y + 11.8, z), C.dark, Enum.Material.Metal)
    part(model, "Lamp", Vector3.new(2, 0.25, 1.1), Vector3.new(x + 2.5, y + 11.6, z), C.white, Enum.Material.Neon, true)
end

local function bench(parent, x, y, z, yaw)
    local model = group(parent, "BancoDePraca")
    local frame = CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
    for _, spec in ipairs({
        { "Seat", Vector3.new(7, 0.35, 2), Vector3.new(0, 1.5, 0), C.wood },
        { "Back", Vector3.new(7, 1.8, 0.3), Vector3.new(0, 2.4, -0.8), C.wood },
        { "Leg", Vector3.new(0.5, 1.4, 1.6), Vector3.new(-2.5, 0.7, 0), C.dark },
        { "Leg", Vector3.new(0.5, 1.4, 1.6), Vector3.new(2.5, 0.7, 0), C.dark },
    }) do
        local item = part(model, spec[1], spec[2], Vector3.zero, spec[4])
        item.CFrame = frame * CFrame.new(spec[3])
    end
end

local function marketStall(parent, x, z, index, title, subtitle)
    local model = group(parent, "Barraca" .. index)
    local tint = index % 2 == 0 and C.green or C.yellow
    part(model, "Counter", Vector3.new(14, 2.7, 6), Vector3.new(x, 1.85, z), C.wood, Enum.Material.Wood)
    for _, side in ipairs({ -1, 1 }) do
        part(model, "Post", Vector3.new(0.35, 7, 0.35), Vector3.new(x + side * 6.5, 4, z + 2.5), C.dark)
    end
    for stripe = -3, 3 do
        part(model, "StripedCanopy", Vector3.new(2.3, 0.3, 10), Vector3.new(x + stripe * 2.2, 7.7, z), stripe % 2 == 0 and tint or C.white)
    end
    local board = part(model, "Sign", Vector3.new(14.7, 1.8, 0.25), Vector3.new(x, 6.5, z - 4.7), C.green)
    signText(board, title, subtitle)
    for item = -2, 2 do
        part(model, "ProduceCrate", Vector3.new(2, 0.9, 2.8), Vector3.new(x + item * 2.6, 3.65, z), index % 2 == 0 and Color3.fromRGB(110, 162, 71) or Color3.fromRGB(237, 176, 59))
    end
    if index == 2 then
        for cane = 0, 4 do
            local stalk = part(model, "SugarCane", Vector3.new(0.3, 6, 0.3), Vector3.new(x + 5 + cane * 0.25, 4.5, z + 3.3), Color3.fromRGB(139, 153, 79))
            stalk.Orientation = Vector3.new(0, 0, 10)
        end
    end
end

local function plaza(parent)
    local model = group(parent, "PracaDaEstacao")
    model:SetAttribute("DistrictName", "Praça da Estação")
    part(model, "PortuguesePaving", Vector3.new(107, 0.25, 121), Vector3.new(-220, 0.65, 9), C.paving, Enum.Material.Cobblestone)
    -- Contrasting geometric paving references urban Portuguese-stone squares.
    for stripe = -3, 3 do
        local band = part(model, "PavingMosaic", Vector3.new(3, 0.025, 38), Vector3.new(-220 + stripe * 12, 0.79, 42), C.dark, nil, true)
        band.Orientation = Vector3.new(0, stripe % 2 == 0 and 24 or -24, 0)
    end
    local base = part(model, "CoretoBase", Vector3.new(1.1, 23, 23), Vector3.new(-220, 1.2, -8), C.paving, Enum.Material.Concrete)
    base.Shape = Enum.PartType.Cylinder
    base.Orientation = Vector3.new(0, 0, 90)
    for i = 0, 5 do
        local angle = i * math.pi / 3
        part(model, "CoretoColumn", Vector3.new(0.55, 8, 0.55), Vector3.new(-220 + math.cos(angle) * 8.5, 5.4, -8 + math.sin(angle) * 8.5), C.white)
    end
    for tier = 0, 2 do
        local roof = part(model, "CoretoRoof", Vector3.new(0.8, 25 - tier * 6, 25 - tier * 6), Vector3.new(-220, 9.7 + tier * 0.7, -8), C.tile)
        roof.Shape = Enum.PartType.Cylinder
        roof.Orientation = Vector3.new(0, 0, 90)
    end
    surface(model, "CoretoAccessRamp", Vector3.new(-220, 0.8, 13), Vector3.new(-220, 1.75, 2), 7, 0.3, C.paving, Enum.Material.Concrete)
    for _, x in ipairs({ -257, -183 }) do
        for _, z in ipairs({ -30, 20, 59 }) do
            tree(model, x, 0.8, z, "ipe", z)
        end
    end
    for _, x in ipairs({ -244, -196 }) do
        bench(model, x, 0.8, 12, 0)
        bench(model, x, 0.8, -34, math.pi)
    end
    streetSign(model, -249, 0.8, 73, "PRAÇA DA ESTAÇÃO", "CORETO • CONVIVÊNCIA • CULTURA", 23)
    local mural = part(model, "CulturalMural", Vector3.new(33, 9, 0.5), Vector3.new(-221, 5.1, -50), C.blue)
    signText(mural, "A CIDADE É DE TODOS", "MÚSICA • ARTE • MEMÓRIA DO BAIRRO")
    for i = -2, 2 do
        local accent = part(model, "MuralColor", Vector3.new(4, 7, 0.05), Vector3.new(-221 + i * 6, 4.7, -50.3), houseColors[i + 3], nil, true)
        accent.Orientation = Vector3.new(0, 0, i * 8)
    end
end

local function footballCourt(parent)
    local model = group(parent, "QuadraDosIpes")
    local y, x, z = 18.75, 310, 412
    part(model, "CourtApron", Vector3.new(111, 0.3, 88), Vector3.new(x, y - 0.2, z), C.paving, Enum.Material.Concrete)
    part(model, "Court", Vector3.new(100, 0.08, 76), Vector3.new(x, y, z), Color3.fromRGB(49, 128, 110))
    for _, side in ipairs({ -1, 1 }) do
        part(model, "TouchLine", Vector3.new(94, 0.025, 0.3), Vector3.new(x, y + 0.06, z + side * 34), C.white, nil, true)
        part(model, "EndLine", Vector3.new(0.3, 0.025, 68), Vector3.new(x + side * 47, y + 0.06, z), C.white, nil, true)
        for _, goalZ in ipairs({ -11, 11 }) do
            part(model, "GoalPost", Vector3.new(0.45, 8, 0.45), Vector3.new(x + side * 45, y + 4, z + goalZ), C.white, Enum.Material.Metal)
        end
        part(model, "GoalBar", Vector3.new(0.45, 0.45, 22.4), Vector3.new(x + side * 45, y + 8, z), C.white, Enum.Material.Metal)
        for netZ = -9, 9, 3 do
            part(model, "GoalNet", Vector3.new(0.08, 7.5, 0.08), Vector3.new(x + side * 48, y + 3.75, z + netZ), C.white, nil, true)
        end
        for netY = 2, 6, 2 do
            part(model, "GoalNet", Vector3.new(0.08, 0.08, 22), Vector3.new(x + side * 48, y + netY, z), C.white, nil, true)
        end
        part(model, "FenceRail", Vector3.new(108, 0.18, 0.18), Vector3.new(x, y + 7, z + side * 42), C.dark, Enum.Material.Metal)
        for postX = -54, 54, 18 do
            part(model, "FencePost", Vector3.new(0.22, 7, 0.22), Vector3.new(x + postX, y + 3.5, z + side * 42), C.dark, Enum.Material.Metal)
        end
        for row = 0, 2 do
            part(model, "Grandstand", Vector3.new(45, 0.55 + row * 0.65, 2.4), Vector3.new(x, y + (0.55 + row * 0.65) / 2, z + side * (43 + row * 2.5)), C.brick, Enum.Material.Concrete)
        end
    end
    part(model, "HalfwayLine", Vector3.new(0.3, 0.025, 68), Vector3.new(x, y + 0.06, z), C.white, nil, true)
    for segment = 0, 19 do
        local angle = segment * math.pi / 10
        local line = part(model, "CenterCircle", Vector3.new(0.26, 0.025, 3.55), Vector3.new(x + math.cos(angle) * 11, y + 0.06, z + math.sin(angle) * 11), C.white, nil, true)
        line.Orientation = Vector3.new(0, -math.deg(angle), 0)
    end
    streetSign(model, 243, 18.7, 392, "QUADRA DOS IPÊS", "ESPORTE E ENCONTRO DO BAIRRO", 22)
end

local function lookout(parent)
    local model = group(parent, "MiranteDaSerra")
    part(model, "Deck", Vector3.new(73, 0.6, 27), Vector3.new(-384, 30.8, -452), C.wood, Enum.Material.WoodPlanks)
    surface(model, "AccessRamp", Vector3.new(-350, 30.7, -427), Vector3.new(-350, 31.1, -439), 8, 0.3, C.paving, Enum.Material.Concrete)
    for _, z in ipairs({ -464.5, -439.5 }) do
        -- Leave the front entrance open for the access ramp.
        part(model, "Rail", Vector3.new(z == -439.5 and 54 or 73, 0.25, 0.3), Vector3.new(z == -439.5 and -393 or -384, 34.1, z), C.dark, Enum.Material.Metal)
        for x = -418, -360, 10 do
            part(model, "RailPost", Vector3.new(0.3, 3.1, 0.3), Vector3.new(x, 32.6, z), C.dark, Enum.Material.Metal)
        end
    end
    for _, x in ipairs({ -418, -378 }) do bench(model, x + 5, 31.1, -455, 0) end
    streetSign(model, -399, 31.1, -450, "MIRANTE DA SERRA", "BELA VISTA • CONTEMPLE A CIDADE", 23)
    tree(model, -438, 30.5, -445, "ipe", 0)
    tree(model, -332, 30.5, -449, "ipe", 1)
end

local function destination(cityRoot, name, position, label)
    local previous = cityRoot:FindFirstChild(name)
    if previous and previous:GetAttribute("BrazilianCityDestination") then previous:Destroy() end
    local marker = part(cityRoot, name, Vector3.new(1, 1, 1), position, C.white, nil, true)
    marker.Transparency = 1
    marker.CanQuery = false
    marker:SetAttribute("BrazilianCityDestination", true)
    marker:SetAttribute("DestinationLabel", label)
end

function BrazilianCity.build(cityRoot)
    local previous = cityRoot:FindFirstChild("BrazilianDistricts")
    if previous then previous:Destroy() end
    local root = group(cityRoot, "BrazilianDistricts")
    root:SetAttribute("RegionalInspiration", "Sudeste: morros e bairros urbanos")
    root:SetAttribute("MapExtent", 510)
    root:SetAttribute("MaximumRoadGradeDegrees", 8)
    local relief = group(root, "Relevo")
    -- Four strips preserve the original 320 x 320 centre and all its missions.
    ground(relief, "WestGround", -510, -160, -160, 160, 0.5)
    ground(relief, "EastGround", 160, 510, -160, 160, 0.5)
    ground(relief, "NorthGround", -510, 510, -510, -160, 0.5)
    ground(relief, "SouthGround", -510, 510, 160, 510, 0.5)
    hillside(relief, "MorroBelaVista", -175, -390, 30)
    hillside(relief, "MorroDosIpes", 175, 315, 18)
    ground(relief, "BelaVistaPlateau", -510, 510, -510, -390, 30.5)
    ground(relief, "IpesPlateau", -510, 510, 315, 510, 18.5)

    local roads = group(root, "RuasELadeiras")
    for _, x in ipairs({ 100, -280 }) do
        road(roads, "AcessoNorte", Vector3.new(x, 0.7, x == 100 and -150 or 104), Vector3.new(x, 0.7, -175))
        road(roads, "LadeiraBelaVista", Vector3.new(x, 0.7, -175), Vector3.new(x, 30.7, -390))
        road(roads, "AlamedaBelaVista", Vector3.new(x, 30.7, -390), Vector3.new(x, 30.7, -498))
        road(roads, "AcessoSul", Vector3.new(x, 0.7, x == 100 and 150 or 104), Vector3.new(x, 0.7, 175))
        road(roads, "LadeiraDosIpes", Vector3.new(x, 0.7, 175), Vector3.new(x, 18.7, 315))
        road(roads, "AlamedaDosIpes", Vector3.new(x, 18.7, 315), Vector3.new(x, 18.7, 485))
    end
    road(roads, "RuaDaEstacao", Vector3.new(-150, 0.7, 104), Vector3.new(-474, 0.7, 104))
    road(roads, "AvenidaDaGaragem", Vector3.new(150, 0.7, 104), Vector3.new(467, 0.7, 104))
    -- The flat apron belongs to the public garage; keep this entire box empty.
    part(root, "GarageApron", Vector3.new(100, 0.2, 70), Vector3.new(240, 0.6, 70), C.asphalt, Enum.Material.Asphalt)
    for _, z in ipairs({ -420, -480 }) do
        road(roads, "RuaBelaVista", Vector3.new(-465, 30.7, z), Vector3.new(465, 30.7, z))
    end
    for _, z in ipairs({ 350, 474 }) do
        road(roads, "RuaDosIpes", Vector3.new(-466, 18.7, z), Vector3.new(466, 18.7, z))
    end
    road(roads, "RuaDaQuadra", Vector3.new(420, 18.7, 350), Vector3.new(420, 18.7, 474))

    local north = group(root, "BelaVista")
    north:SetAttribute("DistrictName", "Bela Vista")
    north:SetAttribute("Elevation", 30.5)
    local south = group(root, "VilaDosIpes")
    south:SetAttribute("DistrictName", "Vila dos Ipês")
    south:SetAttribute("Elevation", 18.5)
    local west = group(root, "EstacaoEFeira")
    west:SetAttribute("DistrictName", "Estação e Feira")
    local east = group(root, "DistritoDasOficinas")
    east:SetAttribute("DistrictName", "Distrito das Oficinas")

    local index = 0
    for _, z in ipairs({ -450, -502 }) do
        for _, x in ipairs({ -220, -174, -128, -82, -36, 10, 166, 213, 260, 310, 359, 406, 455 }) do
            index += 1
            house(north, index, x, 30.5, z, { depth = z == -502 and 13 or 18, yaw = z == -450 and 0 or 0 })
        end
    end
    -- Painted homes step up both sides of the hill. Deep foundations meet the
    -- slope and a short exterior stair reaches each downhill-facing doorway.
    for _, z in ipairs({ -224, -269, -314, -358 }) do
        local height = 0.5 + ((-z - 175) / 215) * 30
        for _, x in ipairs({ -322, -238, 58, 142 }) do
            index += 1
            local platformTop = height + 1.9
            part(north, "HillsideFoundation", Vector3.new(27, 4.5, 23), Vector3.new(x, platformTop - 2.25, z), C.earth, Enum.Material.Brick)
            house(north, index, x, platformTop, z, { width = 24, depth = 19, levels = 2 })
            local slopeGrade = 30 / 215
            local stairStart = height - 18 * slopeGrade
            local doorstepTop = platformTop + 0.825
            for step = 1, 9 do
                local offset = 18.5 - step
                local top = stairStart + (doorstepTop - stairStart) * step / 9
                local bottom = height - (offset + 0.5) * slopeGrade - 0.2
                part(north, "DoorwayStair", Vector3.new(5, top - bottom, 1),
                    Vector3.new(x - 6.4, (top + bottom) / 2, z + offset), C.paving, Enum.Material.Concrete)
            end
        end
    end
    for _, z in ipairs({ 382, 435 }) do
        for _, x in ipairs({ -444, -393, -342, -220, -169, -118, -67, -16, 35, 182 }) do
            index += 1
            house(south, index, x, 18.5, z, { yaw = z == 382 and math.pi or 0, levels = index % 2 + 1 })
        end
    end
    house(south, 91, 365, 18.5, 325, { shop = "PADARIA DOS IPÊS", subtitle = "PÃO QUENTINHO • CAFÉ", width = 38, depth = 18 })
    house(south, 92, 226, 18.5, 324.5, { shop = "CENTRO CULTURAL", subtitle = "OFICINAS • MÚSICA • LEITURA", width = 58, depth = 19, levels = 2 })
    house(west, 94, -397, 0.5, -113, { shop = "ARMAZÉM DA ESTAÇÃO", width = 52, depth = 29, levels = 2 })
    house(west, 95, -328, 0.5, -114, { shop = "PADARIA BOM DIA", width = 45, depth = 27 })
    house(east, 96, 370, 0.5, 55, { shop = "AUTOPEÇAS UNIÃO", width = 48, depth = 28, levels = 2 })
    house(east, 97, 437, 0.5, 54, { shop = "BORRACHARIA DO BAIRRO", width = 52, depth = 30 })
    house(east, 98, 250, 0.5, -32, { shop = "OFICINA BRASIL", subtitle = "CUIDADO COM O SEU VEÍCULO", width = 48, depth = 32 })
    house(east, 99, 357, 0.5, -66, { shop = "MERCADO AVENIDA", width = 60, depth = 37, levels = 2 })
    house(east, 100, 447, 0.5, -67, { shop = "MATERIAIS DE CONSTRUÇÃO", width = 58, depth = 37 })

    plaza(west)
    local feira = group(west, "FeiraDaEstacao")
    part(feira, "MarketPaving", Vector3.new(150, 0.25, 139), Vector3.new(-391, 0.65, 6), C.paving, Enum.Material.Concrete)
    local stalls = {
        { -437, -33, "PASTEL DA PRAÇA", "FEITO NA HORA" },
        { -402, -33, "CALDO DE CANA", "GELADO E FRESQUINHO" },
        { -367, -33, "HORTIFRUTI", "DA FEIRA PRA SUA MESA" },
        { -437, 33, "PÃO DE QUEIJO", "CAFÉ E BOA CONVERSA" },
        { -402, 33, "ARTESANATO", "FEITO NO BAIRRO" },
        { -367, 33, "FLORES E TEMPEROS", "CORES DA NOSSA CIDADE" },
    }
    for i, stall in ipairs(stalls) do marketStall(feira, stall[1], stall[2], i, stall[3], stall[4]) end
    streetSign(feira, -423, 0.8, 78, "FEIRA DA ESTAÇÃO", "SABORES • CULTURA • ENCONTROS", 28)
    for _, x in ipairs({ -458, -336 }) do
        for _, z in ipairs({ -57, 3, 67 }) do tree(feira, x, 0.8, z, "ipe", z) end
    end
    for _, x in ipairs({ -435, -394, -355 }) do bench(feira, x, 0.8, 62, math.pi) end
    footballCourt(south)
    lookout(north)

    local greenery = group(root, "Arborizacao")
    for _, x in ipairs({ -482, -305, 75, 125, 484 }) do
        for _, z in ipairs({ -404, 329, 496 }) do
            tree(greenery, x, z < 0 and 30.5 or 18.5, z, "ipe", x + z)
        end
    end
    for _, z in ipairs({ -180, -247, -320, -380 }) do
        local y = 0.5 + ((-z - 175) / 215) * 30
        for _, x in ipairs({ -451, -392, -171, 222, 385, 462 }) do tree(greenery, x, y, z, "ipe", x + z) end
    end
    for _, z in ipairs({ 199, 254, 298 }) do
        local y = 0.5 + (z - 175) / 140 * 18
        for _, x in ipairs({ -440, -350, -180, -70, 210, 325, 452 }) do tree(greenery, x, y, z, "ipe", x + z) end
    end
    for _, p in ipairs({ { 180, -126 }, { 289, -112 }, { 404, -127 }, { 488, 17 }, { 328, 121 }, { -480, -102 } }) do
        tree(greenery, p[1], 0.5, p[2], "palm", 0)
    end
    local furniture = group(root, "SinalizacaoEMobiliario")
    for _, z in ipairs({ -186, -253, -328, -398 }) do
        local y = z < -390 and 30.7 or 0.7 + ((-z - 175) / 215) * 30
        lamp(furniture, 117, y, z)
        lamp(furniture, -297, y, z)
    end
    for _, z in ipairs({ 188, 244, 302, 369, 452 }) do
        local y = z > 315 and 18.7 or 0.7 + (z - 175) / 140 * 18
        lamp(furniture, 117, y, z)
        lamp(furniture, -297, y, z)
    end
    for _, x in ipairs({ -453, -348, -207, 181, 309, 451 }) do
        lamp(furniture, x, 0.7, 122)
        lamp(furniture, x == -348 and -341 or x, 30.7, -437)
        lamp(furniture, x, 18.7, 490)
    end
    streetSign(furniture, 127, 0.7, -164, "BELA VISTA", "LADEIRA • MIRANTE DA SERRA", 20)
    streetSign(furniture, 127, 0.7, 164, "VILA DOS IPÊS", "QUADRA • CENTRO CULTURAL", 21)
    streetSign(furniture, -180, 0.7, 123, "ESTAÇÃO E FEIRA", "PRAÇA • COMÉRCIO LOCAL", 22)
    streetSign(furniture, 183, 0.7, 123, "GARAGEM BRASILEIRA", "AVENIDA DAS OFICINAS", 24)
    streetSign(furniture, 127, 30.7, -405, "DEVAGAR", "BAIRRO RESIDENCIAL • 30", 12)
    streetSign(furniture, 127, 18.7, 329, "DEVAGAR", "ESCOLA • PEDESTRES • 30", 12)

    destination(cityRoot, "GarageDestination", Vector3.new(240, 1.5, 108), "Garagem Brasileira")
    destination(cityRoot, "BelaVistaDestination", Vector3.new(78, 31.5, -420), "Bela Vista")
    destination(cityRoot, "IpesDestination", Vector3.new(78, 19.5, 350), "Vila dos Ipês")
    destination(cityRoot, "FeiraDestination", Vector3.new(-365, 1.5, 73), "Feira da Estação")
    destination(cityRoot, "MiranteDestination", Vector3.new(-350, 31.5, -440), "Mirante da Serra")
    root:SetAttribute("BuildingCount", index + 9)
    return root
end

return BrazilianCity
