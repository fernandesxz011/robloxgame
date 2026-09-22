local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CityBuilder = require(script.Parent:WaitForChild("CityBuilder"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local DeliveryRoutes = require(script.Parent:WaitForChild("DeliveryRoutes"))
local WorldCharacters = require(script.Parent:WaitForChild("WorldCharacters"))
local Housing = require(script.Parent:WaitForChild("Housing"))
local JobService = require(script.Parent:WaitForChild("JobService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local ObjectiveService = require(script.Parent:WaitForChild("ObjectiveService"))

local VehicleService = require(script.Parent:WaitForChild("VehicleService"))
local activePlayers = {}
local playerVisualCleanup = {}
local playerObjectiveCleanup = {}
local serverClosing = false

local remotesFolder = ReplicatedStorage:FindFirstChild("LifeSimRemotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "LifeSimRemotes"
    remotesFolder.Parent = ReplicatedStorage
end

local cashUpdate = remotesFolder:FindFirstChild("CashUpdate")
if not cashUpdate then
    cashUpdate = Instance.new("RemoteEvent")
    cashUpdate.Name = "CashUpdate"
    cashUpdate.Parent = remotesFolder
end

local missionUpdate = remotesFolder:FindFirstChild("MissionUpdate")
if not missionUpdate then
    missionUpdate = Instance.new("RemoteEvent")
    missionUpdate.Name = "MissionUpdate"
    missionUpdate.Parent = remotesFolder
end

local vehicleInput = remotesFolder:FindFirstChild("VehicleInput")
if not vehicleInput then
    vehicleInput = Instance.new("RemoteEvent")
    vehicleInput.Name = "VehicleInput"
    vehicleInput.Parent = remotesFolder
end

local missionAction = remotesFolder:FindFirstChild("MissionAction")
if not missionAction then
    missionAction = Instance.new("RemoteEvent")
    missionAction.Name = "MissionAction"
    missionAction.Parent = remotesFolder
end

local jobAction = remotesFolder:FindFirstChild("JobAction")
if not jobAction then
    jobAction = Instance.new("RemoteEvent")
    jobAction.Name = "JobAction"
    jobAction.Parent = remotesFolder
end

local inventoryAction = remotesFolder:FindFirstChild("InventoryAction")
if not inventoryAction then
    inventoryAction = Instance.new("RemoteEvent")
    inventoryAction.Name = "InventoryAction"
    inventoryAction.Parent = remotesFolder
end

local objectiveAction = remotesFolder:FindFirstChild("ObjectiveAction")
if not objectiveAction then
    objectiveAction = Instance.new("RemoteEvent")
    objectiveAction.Name = "ObjectiveAction"
    objectiveAction.Parent = remotesFolder
end

local function claimObjective(player, action, objectiveId)
    if action == "Claim" then ObjectiveService.claim(player, objectiveId) end
end
objectiveAction.OnServerEvent:Connect(claimObjective)

local function cancelJob(player, action)
    if player:GetAttribute("DataReady") ~= true or action ~= "Cancel" then return end
    JobService.cancel(player, "Turno cancelado. A energia usada no início não é devolvida.")
end
jobAction.OnServerEvent:Connect(cancelJob)

local function useInventory(player, action)
    if action == "UseSnack" then InventoryService.useSnack(player) end
end
inventoryAction.OnServerEvent:Connect(useInventory)

local function createPart(parent, name, size, cframe, color, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Anchored = true
    part.Material = material or Enum.Material.SmoothPlastic
    part.Color = color
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local interactions = {}

local function sendStatus(player, data)
    if data.status then player:SetAttribute("StatusText", data.status) end
    cashUpdate:FireClient(player, data)
end

local function notify(player, text)
    player:SetAttribute("StatusText", text)
end

local function updateMissionOffer(player)
    local completed = player:GetAttribute("MissionCompletions") or 0
    local route = DeliveryRoutes.offer(completed)
    local rank, bonus = DeliveryRoutes.rank(completed)
    player:SetAttribute("CourierRank", rank)
    player:SetAttribute("OfferedMissionName", route.title)
    player:SetAttribute("OfferedMissionReward", route.reward + bonus)
    player:SetAttribute("OfferedMissionDuration", route.duration)
end

local function resetMission(player, message)
    player:SetAttribute("MissionRoute", "")
    player:SetAttribute("MissionTargetName", "MainMission")
    player:SetAttribute("MissionTargetLabel", "Central de entregas")
    player:SetAttribute("MissionStage", "None")
    player:SetAttribute("MissionReward", 0)
    player:SetAttribute("MissionExpiresAt", 0)
    player:SetAttribute("CurrentMission", "Nenhuma")
    player:SetAttribute("MissionText", "Siga o indicador até a central para uma nova entrega.")
    notify(player, message)
    updateMissionOffer(player)
end

local function cancelMission(player, action)
    if player:GetAttribute("DataReady") ~= true then return end
    if action ~= "Cancel" then return end
    local stage = player:GetAttribute("MissionStage")
    if stage ~= "Pickup" and stage ~= "Deliver" then return end
    resetMission(player, "Entrega cancelada. Você pode aceitar outra na central.")
end

missionAction.OnServerEvent:Connect(cancelMission)

local function updatePlayerTimers(player, now)
    if player:GetAttribute("DataReady") ~= true then return end
    local expiresAt = player:GetAttribute("MissionExpiresAt") or 0
    if expiresAt > 0 and now >= expiresAt then
        resetMission(player, "O prazo da entrega acabou. Aceite outra na central.")
    end
    local income = player:GetAttribute("PassiveIncome") or 0
    local nextIncome = player:GetAttribute("NextIncomeAt") or 0
    if income > 0 and nextIncome > 0 and now >= nextIncome then
        -- Preserve each owner's cadence, including a delayed server tick.
        local periods = math.floor((now - nextIncome) / 60) + 1
        player:SetAttribute("NextIncomeAt", nextIncome + periods * 60)
        player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + income * periods)
    end
end

local function createMissionMarker(cityRoot, name, position, actionText, objectText, color)
    local marker = createPart(cityRoot, name, Vector3.new(4, 1, 4), CFrame.new(position), color or Color3.fromRGB(88, 255, 128), Enum.Material.Neon)
    marker.Transparency = 0.25
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = actionText
    prompt.ObjectText = objectText
    prompt.MaxActivationDistance = 12
    prompt.HoldDuration = 0.5
    prompt.RequiresLineOfSight = false
    prompt.Parent = marker

    prompt.Triggered:Connect(function(player)
        if player:GetAttribute("DataReady") ~= true then return end
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 then return end
        if (root.Position - marker.Position).Magnitude > 14 then return end
        local now = os.clock()
        if now - (interactions[player] or -math.huge) < 2 then
            notify(player, "Aguarde um instante antes de interagir novamente.")
            return
        end
        interactions[player] = now

        local expiresAt = player:GetAttribute("MissionExpiresAt") or 0
        if expiresAt > 0 and Workspace:GetServerTimeNow() >= expiresAt then
            resetMission(player, "O prazo da entrega acabou. Aceite outra na central.")
            return
        end

        local cash = player:GetAttribute("Cash") or 0
        local energy = player:GetAttribute("Energy") or 100
        local rep = player:GetAttribute("Reputation") or 0
        if actionText == "Descansar" then
            player:SetAttribute("Energy", math.min(100, energy + 35))
            notify(player, "Energia restaurada no hospital.")
        elseif actionText == "Depositar" or actionText == "Sacar" then
            local bank = player:GetAttribute("BankBalance") or 0
            local amount = math.min(250, actionText == "Depositar" and cash or bank)
            if amount <= 0 then notify(player, "Saldo insuficiente para esta operação.") return end
            local delta = actionText == "Depositar" and amount or -amount
            player:SetAttribute("Cash", cash - delta)
            player:SetAttribute("BankBalance", bank + delta)
            notify(player, actionText .. ": $" .. amount)
        elseif actionText == "Comprar" then
            if JobService.isActive(player) then
                notify(player, "Conclua ou cancele o turno antes de entrar em casa.") return
            end
            if (player:GetAttribute("OwnedProperties") or 0) > 0 then
                Housing.enter(player)
                return
            end
            if cash < 850 then notify(player, "O apartamento custa $850.") return end
            player:SetAttribute("Cash", cash - 850)
            player:SetAttribute("OwnedProperties", 1)
            player:SetAttribute("PassiveIncome", 75)
            player:SetAttribute("NextIncomeAt", Workspace:GetServerTimeNow() + 60)
            player:SetAttribute("Reputation", rep + 10)
            notify(player, "Apartamento comprado! Use Entrar para conhecer sua casa. Renda: $75/min.")
        elseif actionText == "Missão principal" then
            if JobService.isActive(player) then
                notify(player, "Conclua ou cancele o turno antes de aceitar uma entrega.") return
            end
            if player:GetAttribute("MissionStage") ~= "None" then
                notify(player, "Conclua a entrega atual antes de aceitar outra.") return
            end
            local route = DeliveryRoutes.offer(player:GetAttribute("MissionCompletions") or 0)
            local _, bonus = DeliveryRoutes.rank(player:GetAttribute("MissionCompletions") or 0)
            player:SetAttribute("CurrentMission", route.title)
            player:SetAttribute("MissionRoute", route.id)
            player:SetAttribute("MissionStage", "Pickup")
            player:SetAttribute("MissionReward", route.reward + bonus)
            player:SetAttribute("MissionExpiresAt", Workspace:GetServerTimeNow() + route.duration)
            player:SetAttribute("MissionTargetName", route.pickup)
            player:SetAttribute("MissionTargetLabel", route.pickupLabel)
            player:SetAttribute("MissionText", "Retire o pacote na garagem. Siga o indicador amarelo.")
            notify(player, "Entrega aceita. Vá até a garagem.")
        elseif actionText == "Retirar pacote" then
            if player:GetAttribute("MissionStage") ~= "Pickup" then
                notify(player, "Aceite uma entrega no ponto central amarelo.") return
            end
            local route = DeliveryRoutes.find(player:GetAttribute("MissionRoute"))
            if not route or name ~= route.pickup then return end
            if energy < 10 then notify(player, "Você precisa de 10 de energia.") return end
            player:SetAttribute("Energy", energy - 10)
            player:SetAttribute("MissionStage", "Deliver")
            player:SetAttribute("MissionTargetName", route.dropoff)
            player:SetAttribute("MissionTargetLabel", route.dropoffLabel)
            player:SetAttribute("MissionText", route.dropoffLabel .. " antes que o prazo termine.")
            notify(player, "Pacote retirado. Siga o indicador até o destino.")
        elseif actionText == "Entregar pacote" then
            if player:GetAttribute("MissionStage") ~= "Deliver" then
                notify(player, "Você ainda não tem um pacote para entregar.") return
            end
            local route = DeliveryRoutes.find(player:GetAttribute("MissionRoute"))
            if not route or name ~= route.dropoff then
                notify(player, "Este pacote tem outro destino. Siga seu indicador.")
                return
            end
            local payment = player:GetAttribute("MissionReward") or 0
            player:SetAttribute("Cash", cash + payment)
            player:SetAttribute("Reputation", rep + 15)
            player:SetAttribute("MissionCompletions", (player:GetAttribute("MissionCompletions") or 0) + 1)
            resetMission(player, "Entrega concluída! +$" .. payment)
        elseif actionText == "Comprar lanche" then
            InventoryService.buySnack(player, marker)
        else
            JobService.start(player, marker)
        end
    end)
    return marker
end

Players.PlayerRemoving:Connect(function(player)
    interactions[player] = nil
    JobService.remove(player)
    InventoryService.remove(player)
    if playerObjectiveCleanup[player] then playerObjectiveCleanup[player]() playerObjectiveCleanup[player] = nil end
    Housing.remove(player)
    if playerVisualCleanup[player] then playerVisualCleanup[player]() playerVisualCleanup[player] = nil end
    PlayerData.save(player, true)
    activePlayers[player] = nil
end)

local function buildCity()
    local cityRoot = CityBuilder.build()

    createMissionMarker(cityRoot, "FastFood", Vector3.new(-30, 2.5, 18), "Iniciar turno", "Restaurante · 18 s / 15 energia", Color3.fromRGB(88, 255, 128))
    createMissionMarker(cityRoot, "Taxi", Vector3.new(34, 2.5, 20), "Iniciar turno", "Central de táxis · 20 s / 20 energia", Color3.fromRGB(88, 255, 128))
    createMissionMarker(cityRoot, "Delivery", Vector3.new(-42, 2.5, -30), "Iniciar turno", "Encomendas · 25 s / 25 energia", Color3.fromRGB(88, 255, 128))
    createMissionMarker(cityRoot, "StreetDeal", Vector3.new(36, 2.5, -30), "Iniciar turno", "Negócio da rua · 30 s / 32 energia", Color3.fromRGB(88, 255, 128))
    createMissionMarker(cityRoot, "Recover", Vector3.new(-10, 2.5, 52), "Descansar", "Hospital", Color3.fromRGB(120, 180, 255))
    createMissionMarker(cityRoot, "BankMarker", Vector3.new(-56, 2.5, -72), "Depositar", "Banco — até $250", Color3.fromRGB(255, 200, 84))
    createMissionMarker(cityRoot, "HouseOffer", Vector3.new(62, 2.5, -12), "Comprar", "Apartamento — $850", Color3.fromRGB(255, 160, 64))
    createMissionMarker(cityRoot, "MainMission", Vector3.new(-2, 2.5, -56), "Missão principal", "Central — confira a oferta no painel", Color3.fromRGB(255, 255, 92))
    createMissionMarker(cityRoot, "SnackShop", Vector3.new(72, 2.5, 10), "Comprar lanche", "Mercadinho · $60 / +25 energia", Color3.fromRGB(255, 145, 190))

    createMissionMarker(cityRoot, "BankWithdraw", Vector3.new(-56, 2.5, -58), "Sacar", "Banco — até $250", Color3.fromRGB(255, 200, 84))
    createMissionMarker(cityRoot, "PackagePickup", Vector3.new(72, 2.5, -48), "Retirar pacote", "Entrega VIP — garagem", Color3.fromRGB(255, 255, 92))
    createMissionMarker(cityRoot, "PackageDropoff", Vector3.new(70, 2.5, 78), "Entregar pacote", "Entrega VIP — clube", Color3.fromRGB(255, 255, 92))
    createMissionMarker(cityRoot, "HospitalDropoff", Vector3.new(10, 2.5, 54), "Entregar pacote", "Entrega hospitalar", Color3.fromRGB(255, 255, 92))
    createMissionMarker(cityRoot, "BankDropoff", Vector3.new(-56, 2.5, -88), "Entregar pacote", "Documentos — banco", Color3.fromRGB(255, 255, 92))

    for _, marker in ipairs(cityRoot:GetChildren()) do
        local prompt = marker:FindFirstChildOfClass("ProximityPrompt")
        if marker:IsA("BasePart") and prompt then
            marker.Size = Vector3.new(4, 0.15, 4)
            marker.Position = Vector3.new(marker.Position.X, 1.05, marker.Position.Z)
            marker.CanCollide = false
            marker.CastShadow = false
            local checkpoint = prompt.ActionText == "Retirar pacote" or prompt.ActionText == "Entregar pacote"
            marker:SetAttribute("MissionCheckpoint", checkpoint)
            marker:SetAttribute("JobMarker", prompt.ActionText == "Iniciar turno")
            if marker.Name ~= "MainMission" and not checkpoint then
                local label = Instance.new("BillboardGui")
                label.Name = "ActivityLabel"
                label.Size = UDim2.fromOffset(160, 40)
                label.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
                label.MaxDistance = 65
                label.Parent = marker
                local text = Instance.new("TextLabel")
                text.Size = UDim2.fromScale(1, 1)
                text.BackgroundColor3 = Color3.fromRGB(19, 27, 37)
                text.BackgroundTransparency = 0.2
                text.BorderSizePixel = 0
                text.Font = Enum.Font.GothamMedium
                text.TextSize = 12
                text.TextColor3 = Color3.fromRGB(255, 255, 255)
                text.TextWrapped = true
                text.Text = prompt.ObjectText
                text.Parent = label
            end
        end
    end

    WorldCharacters.build(cityRoot)
    VehicleService.start(cityRoot, vehicleInput)

    return cityRoot
end

local function setupPlayer(player)
    if activePlayers[player] then return end
    activePlayers[player] = true
    player:SetAttribute("DataReady", false)
    player:SetAttribute("InsideHome", false)
    player:SetAttribute("BankBalance", 0)
    player:SetAttribute("MissionStage", "None")
    player:SetAttribute("MissionExpiresAt", 0)
    player:SetAttribute("MissionCompletions", 0)
    player:SetAttribute("WorkCompletions", 0)
    player:SetAttribute("SnackCount", 0)
    player:SetAttribute("SnacksPurchased", 0)
    player:SetAttribute("ObjectiveClaims", 0)
    player:SetAttribute("ObjectiveReady", false)
    player:SetAttribute("WorkActive", false)
    player:SetAttribute("WorkTitle", "")
    player:SetAttribute("WorkMarkerName", "")
    player:SetAttribute("WorkStartedAt", 0)
    player:SetAttribute("WorkEndsAt", 0)
    player:SetAttribute("WorkReward", 0)
    player:SetAttribute("WorkMessage", "")
    player:SetAttribute("Cash", 1500)
    player:SetAttribute("Energy", 100)
    player:SetAttribute("Reputation", 0)
    player:SetAttribute("Wanted", 0)
    player:SetAttribute("CurrentJob", "Desempregado")
    player:SetAttribute("OwnedProperties", 0)
    player:SetAttribute("PassiveIncome", 0)
    player:SetAttribute("NextIncomeAt", 0)
    player:SetAttribute("CurrentMission", "Nenhuma")
    player:SetAttribute("MissionText", "Siga o indicador amarelo para começar sua primeira entrega.")
    player:SetAttribute("MissionReward", 0)
    player:SetAttribute("MissionWanted", 0)

    if not PlayerData.load(player) then
        if player.Parent and not serverClosing then
            player:Kick(player:GetAttribute("SaveMessage") or "Não foi possível carregar seu progresso. Entre novamente.")
        end
        return
    end
    if player.Parent == nil or serverClosing then return end
    player:SetAttribute("NextIncomeAt", (player:GetAttribute("PassiveIncome") or 0) > 0 and Workspace:GetServerTimeNow() + 60 or 0)
    resetMission(player, "Bem-vindo! Sua próxima entrega está disponível na central.")
    playerVisualCleanup[player] = WorldCharacters.trackPlayer(player)
    playerObjectiveCleanup[player] = ObjectiveService.trackPlayer(player)

    task.spawn(function()
        while player.Parent and not serverClosing do
            task.wait(60)
            if not player.Parent or serverClosing then break end
            PlayerData.save(player, false)
        end
    end)

    sendStatus(player, {
        cash = player:GetAttribute("Cash"),
        energy = 100,
        reputation = player:GetAttribute("Reputation"),
        wanted = 0,
        currentJob = "Desempregado",
        mission = "Explore a cidade",
        status = "Bem-vindo! Abra Objetivos para acompanhar seus primeiros passos e receber bônus."
    })

    local function setupCharacter(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        local hrp = character:WaitForChild("HumanoidRootPart", 10)
        if not humanoid or not hrp or player.Character ~= character then return end
        JobService.cancel(player, "Turno interrompido ao reaparecer.")
        Housing.reset(player)
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        hrp.CFrame = CFrame.new(0, 5, 0)
        humanoid.Died:Connect(function()
            if player.Character ~= character then return end
            JobService.cancel(player, "Turno interrompido. Volte ao trabalho após reaparecer.")
            Housing.reset(player)
            if player:GetAttribute("MissionStage") ~= "None" then
                resetMission(player, "Entrega interrompida. Volte à central após reaparecer.")
            end
        end)
    end
    player.CharacterAdded:Connect(setupCharacter)
    if player.Character then task.spawn(setupCharacter, player.Character) end
end

buildCity()

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(setupPlayer, player)
end

game:BindToClose(function()
    serverClosing = true
    PlayerData.close()
    local pending = 0
    for player in pairs(activePlayers) do
        pending = pending + 1
        task.spawn(function()
            PlayerData.save(player, true)
            pending = pending - 1
        end)
    end
    local deadline = os.clock() + 25
    while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end)

-- Timers run per player; server timestamps also drive the client countdown.
task.spawn(function()
    while true do
        task.wait(1)
        local now = Workspace:GetServerTimeNow()
        for _, player in ipairs(Players:GetPlayers()) do
            if PlayerData.check(player) then
                updatePlayerTimers(player, now)
            elseif player:GetAttribute("SaveState") == "Unavailable" and not serverClosing then
                player:Kick(player:GetAttribute("SaveMessage") or "Entre novamente para carregar seu progresso.")
            end
        end
    end
end)

task.spawn(function()
    while not serverClosing do
        task.wait(0.5)
        if not serverClosing then JobService.tick(Workspace:GetServerTimeNow()) end
    end
end)

while true do
    task.wait(12)
    for _, player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("DataReady") ~= true then continue end
        player:SetAttribute("Energy", math.max(0, (player:GetAttribute("Energy") or 100) - 1))
        local wanted = player:GetAttribute("Wanted") or 0
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if wanted > 0 and root and (root.Position - Vector3.new(-72, 0, 62)).Magnitude < 28 then
            player:SetAttribute("Wanted", wanted - 1)
        end
    end
end
