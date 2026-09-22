-- Server-owned apartments built with editable Roblox parts. The caller invokes
-- reset on character replacement and remove on PlayerRemoving. These rooms are
-- isolated in world space; Workspace replication does not make them private.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Housing = {}
local homes = {}
local slots = {}
local REST_COOLDOWN = 8
local palette = {
    cream = Color3.fromRGB(226, 215, 192),
    white = Color3.fromRGB(241, 234, 216),
    dark = Color3.fromRGB(32, 47, 65),
    wood = Color3.fromRGB(154, 113, 79),
    green = Color3.fromRGB(96, 145, 119),
    gold = Color3.fromRGB(255, 200, 103),
    window = Color3.fromRGB(108, 151, 165),
}

local function part(model, origin, name, size, offset, color, material)
    local object = Instance.new("Part")
    object.Name = name
    object.Size = size
    object.CFrame = CFrame.new(origin + offset)
    object.Color = color
    object.Material = material or Enum.Material.SmoothPlastic
    object.Anchored = true
    object.TopSurface = Enum.SurfaceType.Smooth
    object.BottomSurface = Enum.SurfaceType.Smooth
    object.Parent = model
    return object
end

local function detail(model, origin, name, size, offset, color, material)
    local object = part(model, origin, name, size, offset, color, material)
    object.CanCollide = false
    object.CanTouch = false
    return object
end

local function sign(board, title, subtitle)
    local face = Instance.new("SurfaceGui")
    face.Face = Enum.NormalId.Back
    face.CanvasSize = Vector2.new(700, 180)
    face.LightInfluence = 0.1
    face.Parent = board
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.TextColor3 = palette.white
    text.TextScaled = true
    text.Text = title .. "\n" .. subtitle
    text.Parent = face
end

local function prompt(parent, name, action, object, hold, range)
    local interaction = Instance.new("ProximityPrompt")
    interaction.Name = name
    interaction.ActionText = action
    interaction.ObjectText = object
    interaction.HoldDuration = hold
    interaction.MaxActivationDistance = range
    interaction.RequiresLineOfSight = false
    interaction.Parent = parent
    return interaction
end

local function liveCharacter(player)
    if player.Parent ~= Players or player:GetAttribute("DataReady") ~= true then return nil end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not humanoid or not (humanoid.Health > 0) then return nil end
    return character, root, humanoid
end

local function exteriorDoor()
    local city = Workspace:FindFirstChild("Downtown")
    local marker = city and city:FindFirstChild("HouseOffer")
    if marker and marker:IsA("BasePart") then return marker end
    return nil
end

local function reserveSlot(player)
    -- Reuse the lowest available slot instead of growing coordinates on rejoin.
    for slot = 1, math.max(1, Players.MaxPlayers) do
        if not slots[slot] then
            slots[slot] = player
            return slot
        end
    end
    return nil
end

local function interiorPlayer(player, home, marker, distance)
    if homes[player] ~= home or player:GetAttribute("InsideHome") ~= true then return nil end
    local character, root, humanoid = liveCharacter(player)
    if not character or character ~= home.character or not home.model.Parent then return nil end
    if not ((root.Position - marker.Position).Magnitude <= distance) then return nil end
    return character, root, humanoid
end

local function build(player, home)
    local container = Workspace:FindFirstChild("DowntownHomes")
    if not container then
        container = Instance.new("Folder")
        container.Name = "DowntownHomes"
        container.Parent = Workspace
    end
    local model = Instance.new("Model")
    model.Name = "Apartment_" .. tostring(player.UserId)
    model:SetAttribute("OwnerUserId", player.UserId)
    home.model = model
    local origin = Vector3.new(600 + home.slot * 90, 120, 0)
    local function solid(name, size, offset, color, material)
        return part(model, origin, name, size, offset, color, material)
    end
    local function decor(name, size, offset, color, material)
        return detail(model, origin, name, size, offset, color, material)
    end

    solid("Floor", Vector3.new(30, 1, 24), Vector3.zero, palette.wood, Enum.Material.WoodPlanks)
    solid("WestWall", Vector3.new(0.6, 11, 24), Vector3.new(-15, 6, 0), palette.cream)
    solid("EastWall", Vector3.new(0.6, 11, 24), Vector3.new(15, 6, 0), palette.cream)
    solid("NorthWall", Vector3.new(30, 11, 0.6), Vector3.new(0, 6, 12), palette.cream)
    solid("SouthWallLeft", Vector3.new(12.5, 11, 0.6), Vector3.new(-8.75, 6, -12), palette.cream)
    solid("SouthWallRight", Vector3.new(12.5, 11, 0.6), Vector3.new(8.75, 6, -12), palette.cream)
    solid("DoorLintel", Vector3.new(5, 3, 0.6), Vector3.new(0, 10, -12), palette.cream)
    solid("Ceiling", Vector3.new(30.6, 0.5, 24.6), Vector3.new(0, 11.75, 0), palette.white)
    home.exit = solid("FrontDoor", Vector3.new(5, 8, 0.4), Vector3.new(0, 4.5, -11.9), palette.dark, Enum.Material.Wood)
    decor("DoorHandle", Vector3.new(0.2, 0.8, 0.3), Vector3.new(1.7, 4, -11.55), palette.gold, Enum.Material.Metal)
    local plaque = decor("WelcomeSign", Vector3.new(8, 1.5, 0.12), Vector3.new(0, 9.5, -11.6), palette.dark)
    sign(plaque, "SEU APARTAMENTO", "Descanse e volte para a cidade")
    decor("EntranceMat", Vector3.new(5.5, 0.06, 2), Vector3.new(0, 0.54, -9.4), palette.dark, Enum.Material.Fabric)
    decor("LivingRoomRug", Vector3.new(11, 0.06, 10), Vector3.new(-6, 0.54, 3), palette.green, Enum.Material.Fabric)

    -- The center aisle stays clear from the entrance to both interactions.
    solid("SofaBase", Vector3.new(3.3, 1.3, 8), Vector3.new(-11, 1.3, 3), palette.dark)
    solid("SofaBack", Vector3.new(0.8, 3.5, 8), Vector3.new(-12.3, 2.3, 3), palette.green, Enum.Material.Fabric)
    for _, z in ipairs({ -0.6, 6.6 }) do
        solid("SofaArm", Vector3.new(3.3, 2.3, 0.8), Vector3.new(-11, 1.8, z), palette.green, Enum.Material.Fabric)
    end
    for _, z in ipairs({ 1.3, 4.7 }) do
        solid("SofaCushion", Vector3.new(2.6, 0.5, 3), Vector3.new(-10.7, 2.1, z), palette.white, Enum.Material.Fabric)
    end
    solid("CoffeeTable", Vector3.new(3.8, 0.35, 5), Vector3.new(-5.8, 2.1, 3), palette.wood, Enum.Material.Wood)
    solid("TableSupport", Vector3.new(2.5, 1.4, 3), Vector3.new(-5.8, 1.25, 3), palette.dark)
    decor("Book", Vector3.new(1.2, 0.15, 1.8), Vector3.new(-5.8, 2.35, 3), palette.gold)

    solid("BedFrame", Vector3.new(7, 1.1, 9), Vector3.new(9, 1.15, 6), palette.dark, Enum.Material.Wood)
    solid("BedHeadboard", Vector3.new(7.4, 4, 0.6), Vector3.new(9, 2.55, 10.7), palette.wood, Enum.Material.Wood)
    home.bed = solid("Mattress", Vector3.new(6.7, 0.8, 8.7), Vector3.new(9, 2.1, 6), palette.white, Enum.Material.Fabric)
    decor("BedCover", Vector3.new(6.8, 0.15, 5.6), Vector3.new(9, 2.55, 4.6), palette.green, Enum.Material.Fabric)
    for _, x in ipairs({ 7.4, 10.6 }) do
        decor("Pillow", Vector3.new(2.6, 0.35, 1.8), Vector3.new(x, 2.7, 9), palette.cream, Enum.Material.Fabric)
    end
    solid("BedsideTable", Vector3.new(1.8, 2, 2), Vector3.new(3.8, 1.55, 9.3), palette.wood, Enum.Material.Wood)
    solid("LampStem", Vector3.new(0.2, 1.3, 0.2), Vector3.new(3.8, 3.15, 9.3), palette.dark)
    local lamp = decor("BedsideLamp", Vector3.new(1.3, 0.9, 1.3), Vector3.new(3.8, 4.15, 9.3), palette.gold, Enum.Material.Neon)

    solid("KitchenCabinets", Vector3.new(8, 3, 3), Vector3.new(8.7, 2.05, -9.5), palette.green)
    solid("KitchenCounter", Vector3.new(8.4, 0.3, 3.3), Vector3.new(8.7, 3.7, -9.5), palette.white, Enum.Material.Marble)
    for _, x in ipairs({ 5.6, 7.6, 9.6, 11.6 }) do
        decor("CabinetHandle", Vector3.new(0.7, 0.12, 0.2), Vector3.new(x, 2.8, -7.9), palette.gold, Enum.Material.Metal)
    end
    decor("Sink", Vector3.new(2, 0.07, 1.9), Vector3.new(6.4, 3.9, -9.5), palette.dark, Enum.Material.Metal)
    solid("Faucet", Vector3.new(0.18, 1, 0.18), Vector3.new(6.4, 4.25, -10.5), palette.window, Enum.Material.Metal)
    decor("Stove", Vector3.new(2.6, 0.08, 2.4), Vector3.new(10.7, 3.9, -9.5), palette.dark, Enum.Material.Metal)
    for _, x in ipairs({ 10.1, 11.3 }) do
        for _, z in ipairs({ -10.1, -8.9 }) do
            decor("Burner", Vector3.new(0.7, 0.06, 0.7), Vector3.new(x, 3.98, z), palette.window, Enum.Material.Metal)
        end
    end
    solid("Fridge", Vector3.new(3, 6, 3), Vector3.new(-10.5, 3.55, -9.5), palette.white, Enum.Material.Metal)
    decor("FridgeHandle", Vector3.new(0.15, 1.6, 0.25), Vector3.new(-9.5, 3.6, -7.9), palette.dark, Enum.Material.Metal)
    decor("FridgeDivider", Vector3.new(2.9, 0.05, 0.08), Vector3.new(-10.5, 4.4, -7.95), palette.dark)

    decor("WindowFrame", Vector3.new(0.12, 5.5, 10), Vector3.new(-14.62, 6.5, 3), palette.dark)
    decor("WindowGlass", Vector3.new(0.14, 4.8, 9.3), Vector3.new(-14.54, 6.5, 3), palette.window, Enum.Material.Glass)
    decor("WindowMullion", Vector3.new(0.15, 4.8, 0.2), Vector3.new(-14.45, 6.5, 3), palette.white)
    decor("ArtworkFrame", Vector3.new(5.5, 3.5, 0.15), Vector3.new(-5, 6.5, 11.6), palette.dark)
    decor("Artwork", Vector3.new(4.9, 2.9, 0.16), Vector3.new(-5, 6.5, 11.45), palette.green)
    decor("ArtworkSun", Vector3.new(1.3, 1.3, 0.17), Vector3.new(-3.8, 7, 11.33), palette.gold)

    local ceilingLight = decor("CeilingLight", Vector3.new(4, 0.18, 3), Vector3.new(0, 11.4, 0), palette.white, Enum.Material.Neon)
    for _, lightSource in ipairs({ ceilingLight, lamp }) do
        local light = Instance.new("PointLight")
        light.Color = palette.gold
        light.Brightness = lightSource == ceilingLight and 1.6 or 0.6
        light.Range = lightSource == ceilingLight and 32 or 12
        light.Shadows = false
        light.Parent = lightSource
    end

    home.entry = CFrame.lookAt(origin + Vector3.new(0, 4.5, -7), origin + Vector3.new(0, 4.5, 1))
    prompt(home.exit, "LeaveApartment", "Sair", "Voltar para Downtown", 0.5, 8).Triggered:Connect(function(visitor)
        if visitor ~= player then return end
        Housing.leave(player)
    end)
    prompt(home.bed, "RestAtHome", "Dormir", "Recuperar toda a energia", 2, 8).Triggered:Connect(function(visitor)
        if visitor ~= player or player:GetAttribute("OwnedProperties") ~= 1 then return end
        local character = interiorPlayer(player, home, home.bed, 10)
        if not character then return end
        local now = os.clock()
        if now - home.lastRest < REST_COOLDOWN then
            player:SetAttribute("StatusText", "Aguarde um instante antes de descansar novamente.")
            return
        end
        home.lastRest = now
        player:SetAttribute("Energy", 100)
        player:SetAttribute("StatusText", "Descanso em casa concluído. Energia completa!")
    end)
    model.Parent = container
end

local function teleport(character, root, target)
    -- A failed move never marks the player as inside or outside the apartment.
    local moved = pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        character:PivotTo(target)
    end)
    return moved
end

function Housing.enter(player)
    if player:GetAttribute("OwnedProperties") ~= 1 or player:GetAttribute("InsideHome") == true then return false end
    local character, root, humanoid = liveCharacter(player)
    local marker = exteriorDoor()
    if not character or not marker then return false end
    if not ((root.Position - marker.Position).Magnitude <= 14) then return false end
    if humanoid.SeatPart or humanoid.Sit then
        player:SetAttribute("StatusText", "Saia do veículo antes de entrar no apartamento.")
        return false
    end
    local home = homes[player]
    if home and (not home.model or not home.model.Parent) then
        Housing.reset(player)
        home = nil
    end
    if not home then
        local slot = reserveSlot(player)
        if not slot then
            player:SetAttribute("StatusText", "O apartamento está indisponível. Tente novamente em instantes.")
            return false
        end
        home = { slot = slot, lastRest = -math.huge }
        homes[player] = home
        local built = pcall(build, player, home)
        if not built then
            Housing.reset(player)
            player:SetAttribute("StatusText", "Não foi possível abrir o apartamento. Tente novamente.")
            return false
        end
    end
    if not teleport(character, root, home.entry) then return false end
    home.character = character
    player:SetAttribute("InsideHome", true)
    player:SetAttribute("StatusText", "Bem-vindo ao seu apartamento! Use a cama para recuperar energia.")
    return true
end

function Housing.leave(player)
    local home = homes[player]
    if not home then return false end
    local character, root, humanoid = interiorPlayer(player, home, home.exit, 12)
    local marker = exteriorDoor()
    if not character or not marker or humanoid.SeatPart or humanoid.Sit then return false end
    -- HouseOffer is east of the road: the west offset lands on clear pavement,
    -- away from its building facade. Height gives the character room to settle.
    local position = marker.Position + Vector3.new(-5, 4, 0)
    local target = CFrame.lookAt(position, position + Vector3.new(-1, 0, 0))
    if not teleport(character, root, target) then return false end
    home.character = nil
    player:SetAttribute("InsideHome", false)
    player:SetAttribute("StatusText", "Você voltou para Downtown.")
    return true
end

function Housing.reset(player)
    local home = homes[player]
    homes[player] = nil
    if home then
        slots[home.slot] = nil
        if home.model then home.model:Destroy() end
    end
    player:SetAttribute("InsideHome", false)
end

function Housing.remove(player)
    Housing.reset(player)
end

return Housing
