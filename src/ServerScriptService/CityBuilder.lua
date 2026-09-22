-- The city is generated with native Roblox parts so it stays editable in Studio.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local BrazilianCity = require(script.Parent:WaitForChild("BrazilianCity"))

local CityBuilder = {}

local palette = {
    asphalt = Color3.fromRGB(51, 54, 57),
    sidewalk = Color3.fromRGB(203, 192, 170),
    grass = Color3.fromRGB(82, 132, 77),
    dark = Color3.fromRGB(32, 47, 65),
    cream = Color3.fromRGB(226, 215, 192),
    gold = Color3.fromRGB(255, 200, 103),
    window = Color3.fromRGB(108, 151, 165),
    warmWindow = Color3.fromRGB(244, 205, 143),
    white = Color3.fromRGB(241, 234, 216),
}

-- These footprints include the interactions and the three parked vehicles in
-- GameServer. Low paving is allowed here; buildings and street furniture are not.
local reserved = {
    { 0, 0, 10 },
    { -30, 18, 8 }, { 34, 20, 8 }, { -42, -30, 8 },
    { 36, -30, 8 }, { -10, 52, 8 }, { -56, -72, 8 },
    { 62, -12, 8 }, { -2, -56, 8 }, { 72, 10, 8 },
    { -56, -58, 8 }, { 72, -48, 8 }, { 70, 78, 8 },
    { 10, 54, 8 }, { -56, -88, 8 },
    { -18, 36, 8 }, { 18, -36, 8 }, { 52, 34, 8 },
}

local function clearFootprint(x, z, width, depth)
    for _, area in ipairs(reserved) do
        local dx = math.max(math.abs(x - area[1]) - width / 2, 0)
        local dz = math.max(math.abs(z - area[2]) - depth / 2, 0)
        if dx * dx + dz * dz < area[3] * area[3] then
            return false
        end
    end
    return true
end

local function part(parent, name, size, position, color, material)
    local item = Instance.new("Part")
    item.Name = name
    item.Anchored = true
    item.Size = size
    item.Position = position
    item.Color = color
    item.Material = material or Enum.Material.SmoothPlastic
    item.TopSurface = Enum.SurfaceType.Smooth
    item.BottomSurface = Enum.SurfaceType.Smooth
    item.Parent = parent
    return item
end

local function detail(parent, name, size, position, color, material)
    local item = part(parent, name, size, position, color, material)
    item.CanCollide = false
    item.CanTouch = false
    item.CastShadow = false
    return item
end

local function group(parent, name)
    local model = Instance.new("Model")
    model.Name = name
    model.Parent = parent
    return model
end

local function textFace(board, face, title, subtitle, accent)
    local surface = Instance.new("SurfaceGui")
    surface.Name = "Signage"
    surface.Face = face
    surface.CanvasSize = Vector2.new(800, 240)
    surface.LightInfluence = 0.15
    surface.Parent = board

    local heading = Instance.new("TextLabel")
    heading.Name = "Title"
    heading.BackgroundTransparency = 1
    heading.Position = UDim2.fromScale(0.04, 0.08)
    heading.Size = UDim2.fromScale(0.92, 0.53)
    heading.Font = Enum.Font.GothamBold
    heading.Text = title
    heading.TextColor3 = accent or palette.white
    heading.TextScaled = true
    heading.Parent = surface

    local caption = Instance.new("TextLabel")
    caption.Name = "Subtitle"
    caption.BackgroundTransparency = 1
    caption.Position = UDim2.fromScale(0.04, 0.66)
    caption.Size = UDim2.fromScale(0.92, 0.22)
    caption.Font = Enum.Font.GothamMedium
    caption.Text = subtitle
    caption.TextColor3 = palette.white
    caption.TextScaled = true
    caption.Parent = surface
end

local function building(parent, name, x, z, width, depth, height, color, accent, title, subtitle, eastEntrance)
    -- Roofs and canopies extend slightly beyond the walls.
    if not clearFootprint(x, z, width + 2.4, depth + 2.4) then
        return
    end
    local model = group(parent, name)
    part(model, "Facade", Vector3.new(width, height, depth), Vector3.new(x, 0.85 + height / 2, z), color)
    part(model, "Foundation", Vector3.new(width + 0.6, 1, depth + 0.6), Vector3.new(x, 1.35, z), palette.dark)
    part(model, "RoofRim", Vector3.new(width + 1.4, 0.8, depth + 1.4), Vector3.new(x, height + 1.25, z), palette.dark)
    part(model, "RoofInset", Vector3.new(width - 2, 0.5, depth - 2), Vector3.new(x, height + 1.85, z), color)

    -- Familiar rooftop silhouettes, built from editable parts.
    local tank = detail(model, "CaixaDAgua", Vector3.new(2.4, 3.6, 3.6), Vector3.new(x - width / 4, height + 3.3, z - depth / 4), Color3.fromRGB(43, 103, 174))
    tank.Shape = Enum.PartType.Cylinder
    tank.Orientation = Vector3.new(0, 0, 90)
    local tankLid = detail(model, "TampaCaixaDAgua", Vector3.new(0.2, 3.8, 3.8), tank.Position + Vector3.new(0, 1.3, 0), Color3.fromRGB(31, 77, 132))
    tankLid.Shape = Enum.PartType.Cylinder
    tankLid.Orientation = Vector3.new(0, 0, 90)

    local levels = math.clamp(math.floor((height - 5) / 7), 1, 3)
    local columns = width < 20 and 2 or 3
    local windowWidth = (width - 5) / columns - 1
    for level = 1, levels do
        local y = 7 + (level - 1) * (height - 8) / levels
        for column = 1, columns do
            local wx = x - width / 2 + 2.5 + (column - 0.5) * (width - 5) / columns
            local tint = (column + level) % 3 == 0 and palette.warmWindow or palette.window
            for _, side in ipairs({ -1, 1 }) do
                detail(model, "Window", Vector3.new(windowWidth, 3, 0.16), Vector3.new(wx, y, z + side * (depth / 2 + 0.08)), tint)
            end
        end
        for _, side in ipairs({ -1, 1 }) do
            detail(model, "SideWindow", Vector3.new(0.16, 3, depth * 0.42), Vector3.new(x + side * (width / 2 + 0.08), y, z), palette.window)
        end
    end

    if eastEntrance then
        detail(model, "Entrance", Vector3.new(0.2, 4.5, 4), Vector3.new(x + width / 2 + 0.11, 3.1, z), palette.window)
        part(model, "Canopy", Vector3.new(1.1, 0.35, depth * 0.85), Vector3.new(x + width / 2 + 0.45, 6, z), accent)
        local board = detail(model, "Nameplate", Vector3.new(0.3, 3.2, depth * 0.88), Vector3.new(x + width / 2 + 0.3, height - 1.5, z), palette.dark)
        textFace(board, Enum.NormalId.Right, title or name, subtitle or "DOWNTOWN", accent)
    else
        detail(model, "Entrance", Vector3.new(4, 4.5, 0.2), Vector3.new(x, 3.1, z + depth / 2 + 0.11), palette.window)
        part(model, "Canopy", Vector3.new(width * 0.85, 0.35, 1.1), Vector3.new(x, 6, z + depth / 2 + 0.45), accent)
        if title then
            local board = detail(model, "Nameplate", Vector3.new(width * 0.88, 3.2, 0.3), Vector3.new(x, height - 1.5, z + depth / 2 + 0.3), palette.dark)
            textFace(board, Enum.NormalId.Back, title, subtitle or "DOWNTOWN", accent)
            local rear = detail(model, "StreetNameplate", Vector3.new(width * 0.88, 3.2, 0.3), Vector3.new(x, height - 1.5, z - depth / 2 - 0.3), palette.dark)
            textFace(rear, Enum.NormalId.Front, title, subtitle or "DOWNTOWN", accent)
        end
    end
    return model
end

local function tree(parent, x, z)
    if not clearFootprint(x, z, 6, 6) then return end
    local model = group(parent, "StreetTree")
    part(model, "Planter", Vector3.new(5, 0.55, 5), Vector3.new(x, 1.1, z), palette.dark)
    part(model, "Trunk", Vector3.new(0.8, 5, 0.8), Vector3.new(x, 3.6, z), Color3.fromRGB(104, 78, 62), Enum.Material.Wood)
    local crown = part(model, "Crown", Vector3.new(5.7, 5.7, 5.7), Vector3.new(x, 7.5, z), Color3.fromRGB(89, 132, 105))
    crown.Shape = Enum.PartType.Ball
    crown.CanCollide = false
    crown.CanTouch = false
end

local function lamp(parent, x, z)
    if not clearFootprint(x, z, 3, 3) then return end
    local model = group(parent, "StreetLamp")
    part(model, "Pole", Vector3.new(0.35, 10, 0.35), Vector3.new(x, 5.85, z), palette.dark, Enum.Material.Metal)
    part(model, "Cap", Vector3.new(2.2, 0.3, 2.2), Vector3.new(x, 11, z), palette.dark, Enum.Material.Metal)
    local glow = detail(model, "Light", Vector3.new(1.5, 0.4, 1.5), Vector3.new(x, 10.7, z), palette.warmWindow, Enum.Material.Neon)
    local light = Instance.new("PointLight")
    light.Color = palette.warmWindow
    light.Brightness = 0.7
    light.Range = 18
    light.Shadows = false
    light.Parent = glow
end

local function atmosphere()
    Lighting.ClockTime = 15.8
    Lighting.Brightness = 2.2
    Lighting.GlobalShadows = true
    Lighting.Ambient = Color3.fromRGB(110, 108, 128)
    Lighting.OutdoorAmbient = Color3.fromRGB(139, 139, 151)
    Lighting.EnvironmentDiffuseScale = 0.65
    Lighting.EnvironmentSpecularScale = 0.45
    Lighting.ShadowSoftness = 0.35

    local haze = Lighting:FindFirstChild("DowntownAtmosphere")
    if haze then haze:Destroy() end
    haze = Instance.new("Atmosphere")
    haze.Name = "DowntownAtmosphere"
    haze.Density = 0.2
    haze.Offset = 0.2
    haze.Color = Color3.fromRGB(227, 213, 195)
    haze.Decay = Color3.fromRGB(137, 151, 173)
    haze.Haze = 1.2
    haze.Glare = 0.12
    haze.Parent = Lighting

    local grade = Lighting:FindFirstChild("DowntownColor")
    if grade then grade:Destroy() end
    grade = Instance.new("ColorCorrectionEffect")
    grade.Name = "DowntownColor"
    grade.Contrast = 0.06
    grade.Saturation = 0.06
    grade.TintColor = Color3.fromRGB(255, 245, 230)
    grade.Parent = Lighting
end

function CityBuilder.build()
    local previous = Workspace:FindFirstChild("Downtown")
    if previous then previous:Destroy() end
    local city = group(Workspace, "Downtown")
    local streets = group(city, "Streets")
    local buildings = group(city, "Buildings")
    local furniture = group(city, "StreetFurniture")

    part(city, "Ground", Vector3.new(320, 1, 320), Vector3.zero, palette.grass, Enum.Material.Grass)

    local avenues = { -100, -20, 20, 100 }
    local crossStreets = { -104, -36, 36, 104 }
    local columns = { { -150, -109 }, { -91, -27 }, { -13, 13 }, { 27, 91 }, { 109, 150 } }
    local rows = { { -150, -113 }, { -95, -45 }, { -27, 27 }, { 45, 95 }, { 113, 150 } }

    -- Vertical avenues own the intersections; horizontal sections end at them.
    -- The two central avenues are narrower, leaving a pedestrian plaza at spawn.
    for _, x in ipairs(avenues) do
        local width = math.abs(x) == 20 and 14 or 18
        part(streets, "Avenue", Vector3.new(width, 0.2, 300), Vector3.new(x, 0.6, 0), palette.asphalt, Enum.Material.Asphalt)
        for z = -144, 144, 12 do
            local intersection = false
            for _, crossZ in ipairs(crossStreets) do
                if math.abs(z - crossZ) < 14 then intersection = true end
            end
            if not intersection then
                detail(streets, "LaneDash", Vector3.new(0.22, 0.025, 4.5), Vector3.new(x, 0.714, z), palette.gold)
            end
        end
    end

    for _, z in ipairs(crossStreets) do
        for _, span in ipairs(columns) do
            part(streets, "CrossStreet", Vector3.new(span[2] - span[1], 0.2, 18), Vector3.new((span[1] + span[2]) / 2, 0.6, z), palette.asphalt, Enum.Material.Asphalt)
            for x = span[1] + 6, span[2] - 5, 12 do
                detail(streets, "LaneDash", Vector3.new(4.5, 0.025, 0.22), Vector3.new(x, 0.714, z), palette.gold)
            end
        end
    end

    for _, xSpan in ipairs(columns) do
        for _, zSpan in ipairs(rows) do
            part(streets, "CityBlock", Vector3.new(xSpan[2] - xSpan[1], 0.35, zSpan[2] - zSpan[1]), Vector3.new((xSpan[1] + xSpan[2]) / 2, 0.675, (zSpan[1] + zSpan[2]) / 2), palette.sidewalk, Enum.Material.Concrete)
        end
    end

    for _, x in ipairs({ -20, 20 }) do
        for _, z in ipairs({ -36, 36 }) do
            for stripe = -2, 2 do
                for _, side in ipairs({ -1, 1 }) do
                    detail(streets, "Crosswalk", Vector3.new(1.15, 0.028, 3), Vector3.new(x + stripe * 2, 0.717, z + side * 12), palette.white)
                end
            end
        end
    end

    local skylineColors = {
        Color3.fromRGB(214, 151, 108), Color3.fromRGB(109, 164, 184),
        Color3.fromRGB(226, 198, 122), Color3.fromRGB(129, 168, 137),
    }
    local index = 0
    for _, z in ipairs({ -132, 132 }) do
        for _, x in ipairs({ -130, -68, 0, 65, 130 }) do
            index += 1
            local width = x == 0 and 18 or 25
            building(buildings, "CityBuilding" .. index, x, z, width, 24, 22 + (index % 4) * 7, skylineColors[(index - 1) % 4 + 1], palette.cream)
        end
    end
    for _, x in ipairs({ -130, 130 }) do
        for _, z in ipairs({ -70, 70 }) do
            index += 1
            building(buildings, "CityBuilding" .. index, x, z, 24, 28, 23 + (index % 3) * 8, skylineColors[(index - 1) % 4 + 1], palette.cream)
        end
    end

    building(buildings, "Bank", -78, -73, 22, 28, 18, palette.cream, palette.gold, "BANCO DA PRAÇA", "DEPÓSITOS E SAQUES", true)
    building(buildings, "Garage", 72, -72, 28, 24, 11, Color3.fromRGB(106, 143, 127), Color3.fromRGB(163, 233, 183), "GARAGEM 72", "RETIRADA DE ENTREGAS")
    building(buildings, "Club", 70, 59, 28, 18, 13, Color3.fromRGB(72, 63, 91), Color3.fromRGB(244, 136, 172), "CLUBE AURORA", "ENTREGAS VIP")
    building(buildings, "PoliceStation", -73, 68, 28, 26, 17, Color3.fromRGB(120, 145, 167), Color3.fromRGB(146, 196, 245), "DELEGACIA", "CENTRO")
    building(buildings, "Hospital", 0, 77, 18, 22, 18, palette.cream, Color3.fromRGB(150, 211, 237), "HOSPITAL MUNICIPAL", "RECUPERE SUA ENERGIA")
    building(buildings, "Apartments", 81, -12, 18, 24, 32, Color3.fromRGB(193, 149, 124), palette.gold, "RESIDENCIAL", "SEU LUGAR NA CIDADE")
    building(buildings, "Restaurant", -46, 11, 12, 19, 10, Color3.fromRGB(201, 119, 99), palette.gold, "LANCHONETE DA ESQUINA", "PRATO FEITO • CAFÉ • TRABALHO", true)
    building(buildings, "DeliveryOffice", -62, -15, 22, 16, 13, Color3.fromRGB(117, 149, 145), Color3.fromRGB(161, 231, 181), "ENTREGA EXPRESSA", "DAQUI PARA TODO O BAIRRO")
    building(buildings, "BusinessTower", 0, -82, 18, 20, 36, Color3.fromRGB(127, 146, 165), palette.gold, "CENTRO", "DOWNTOWN BRASIL")

    -- Open-front kiosk, beside SnackShop. The marker and approach stay clear.
    local kiosk = group(furniture, "SnackKiosk")
    local pink = Color3.fromRGB(215, 112, 151)
    part(kiosk, "Counter", Vector3.new(7, 2.2, 1.5), Vector3.new(78, 1.95, 11), palette.cream, Enum.Material.Wood)
    part(kiosk, "CounterTop", Vector3.new(7.4, 0.25, 1.8), Vector3.new(78, 3.175, 11), palette.dark)
    part(kiosk, "BackPanel", Vector3.new(8, 5, 0.4), Vector3.new(77, 3.35, 16), pink)
    for _, x in ipairs({ 72.8, 81.2 }) do
        part(kiosk, "CanopyPost", Vector3.new(0.25, 6, 0.25), Vector3.new(x, 3.85, 15.7), palette.dark, Enum.Material.Metal)
    end
    part(kiosk, "Canopy", Vector3.new(9, 0.4, 6.5), Vector3.new(77, 7, 13.1), pink)
    local kioskSign = detail(kiosk, "ShopSign", Vector3.new(8, 1.5, 0.2), Vector3.new(77, 6.05, 10.1), palette.dark)
    textFace(kioskSign, Enum.NormalId.Front, "MERCADINHO DA BIA", "LANCHE $60  •  +25 ENERGIA", palette.gold)
    for _, x in ipairs({ 74.5, 75.3, 78.7, 79.5 }) do
        detail(kiosk, "SnackBox", Vector3.new(0.55, 0.7, 0.5), Vector3.new(x, 3.65, 11), palette.gold)
    end

    -- A low plaza under the spawn keeps the player away from moving traffic.
    detail(city, "SpawnPlaza", Vector3.new(22, 0.05, 36), Vector3.new(0, 0.881, 0), palette.cream, Enum.Material.Concrete)
    for _, x in ipairs({ -8, 8 }) do
        for _, z in ipairs({ -18, 18 }) do
            part(furniture, "BenchSeat", Vector3.new(3.5, 0.4, 1.4), Vector3.new(x, 1.65, z), Color3.fromRGB(144, 102, 76), Enum.Material.Wood)
            part(furniture, "BenchBase", Vector3.new(2.6, 0.7, 1), Vector3.new(x, 1.2, z), palette.dark)
        end
    end
    local welcome = part(furniture, "WelcomeSign", Vector3.new(17, 3.7, 0.4), Vector3.new(0, 6, 23), palette.dark)
    textFace(welcome, Enum.NormalId.Front, "DOWNTOWN • BRASIL", "CENTRO  •  BAIRROS  •  MORROS", palette.gold)
    textFace(welcome, Enum.NormalId.Back, "DOWNTOWN • BRASIL", "ABRA CIDADE PARA EXPLORAR", palette.gold)
    for _, x in ipairs({ -7, 7 }) do
        part(furniture, "SignPost", Vector3.new(0.35, 4, 0.35), Vector3.new(x, 2.85, 23), palette.dark, Enum.Material.Metal)
    end

    for _, x in ipairs({ -88, -30, 30, 88 }) do
        for _, z in ipairs({ -91, -22, 22, 91 }) do
            lamp(furniture, x, z)
        end
    end
    for _, position in ipairs({
        { -145, -93 }, { -115, -93 }, { -145, 93 }, { -115, 93 },
        { 115, -93 }, { 145, -93 }, { 115, 93 }, { 145, 93 },
        { -83, -20 }, { -82, 20 }, { 45, -16 }, { 44, 10 },
        { -43, 86 }, { 41, 84 }, { -39, -85 }, { 42, -84 },
    }) do
        tree(furniture, position[1], position[2])
    end

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "DowntownSpawn"
    spawn.Size = Vector3.new(12, 1, 12)
    spawn.Position = Vector3.new(0, 2, 0)
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Transparency = 1
    spawn.CanCollide = false
    spawn.Parent = city

    -- A municipal bus shelter beside the outer avenue, away from activity points.
    local shelter = group(furniture, "PontoDeOnibus")
    for _, z in ipairs({ -15, -3 }) do
        part(shelter, "Poste", Vector3.new(0.3, 7, 0.3), Vector3.new(117, 4.35, z), palette.dark, Enum.Material.Metal)
    end
    part(shelter, "Cobertura", Vector3.new(6, 0.4, 14), Vector3.new(115, 8, -9), Color3.fromRGB(47, 124, 109), Enum.Material.Metal)
    part(shelter, "Banco", Vector3.new(1.6, 0.5, 9), Vector3.new(116.3, 2.2, -9), palette.cream, Enum.Material.Wood)
    part(shelter, "BaseBanco", Vector3.new(1, 1.1, 7), Vector3.new(116.3, 1.4, -9), palette.dark)
    local busSign = detail(shelter, "Linhas", Vector3.new(0.2, 2.2, 10), Vector3.new(112, 6.8, -9), palette.dark)
    textFace(busSign, Enum.NormalId.Left, "PONTO DE ÔNIBUS", "CENTRO • BELA VISTA • IPÊS", palette.gold)

    local flag = group(furniture, "BandeiraDoBrasil")
    part(flag, "Mastro", Vector3.new(0.2, 13, 0.2), Vector3.new(10, 7.35, -12), palette.white, Enum.Material.Metal)
    detail(flag, "Verde", Vector3.new(4.6, 3, 0.06), Vector3.new(7.65, 12.3, -12), Color3.fromRGB(0, 133, 66))
    local diamond = detail(flag, "Amarelo", Vector3.new(2, 2, 0.08), Vector3.new(7.65, 12.3, -12), Color3.fromRGB(255, 210, 46))
    diamond.Orientation = Vector3.new(0, 0, 45)
    local globe = detail(flag, "Azul", Vector3.new(0.12, 1.35, 1.35), Vector3.new(7.65, 12.3, -12), Color3.fromRGB(27, 59, 135))
    globe.Shape = Enum.PartType.Cylinder
    globe.Orientation = Vector3.new(0, 90, 0)

    BrazilianCity.build(city)
    atmosphere()
    return city
end

return CityBuilder
