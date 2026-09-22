-- Timed shifts are owned by the server. The caller supplies the update loop
-- and connects cancellation and player lifecycle events.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local JobService = {}
local active = {}
local availableAt = {}
local COOLDOWN = 5
local jobs = {
    FastFood = { title = "Restaurante", duration = 18, reward = 180, energy = 15, wanted = 0 },
    Taxi = { title = "Central de táxis", duration = 20, reward = 230, energy = 20, wanted = 0 },
    Delivery = { title = "Centro de encomendas", duration = 25, reward = 300, energy = 25, wanted = 0 },
    StreetDeal = { title = "Negócio da rua", duration = 30, reward = 420, energy = 32, wanted = 3 },
}

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function amount(player, name)
    local value = player:GetAttribute(name)
    return finite(value) and math.max(0, value) or 0
end

local function status(player, message)
    player:SetAttribute("StatusText", message)
end

local function clearAttributes(player)
    player:SetAttribute("WorkActive", false)
    player:SetAttribute("WorkTitle", "")
    player:SetAttribute("WorkMarkerName", "")
    player:SetAttribute("WorkStartedAt", 0)
    player:SetAttribute("WorkEndsAt", 0)
    player:SetAttribute("WorkReward", 0)
    player:SetAttribute("WorkMessage", "")
    player:SetAttribute("CurrentJob", "Desempregado")
end

local function validMarker(marker)
    if typeof(marker) ~= "Instance" or not marker:IsA("BasePart") then return false end
    local city = Workspace:FindFirstChild("Downtown")
    return city ~= nil and marker:IsDescendantOf(city) and jobs[marker.Name] ~= nil
end

local function workCharacter(player)
    if player.Parent ~= Players or player:GetAttribute("DataReady") ~= true then return nil end
    if player:GetAttribute("InsideHome") == true then return nil end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not humanoid or not (humanoid.Health > 0) then return nil end
    if humanoid.Sit or humanoid.SeatPart then return nil end
    return character, root
end

local function endShift(player, now, message)
    -- Remove the private state before touching replicated attributes. Repeated
    -- ticks or cancellation events can never pay the same shift twice.
    active[player] = nil
    availableAt[player] = now + COOLDOWN
    clearAttributes(player)
    status(player, message)
end

function JobService.isActive(player)
    return active[player] ~= nil
end

function JobService.start(player, marker)
    if player.Parent ~= Players or player:GetAttribute("DataReady") ~= true then return false end
    if active[player] then
        status(player, "Você já está em um turno. Termine ou cancele pelo painel.")
        return false
    end
    if not validMarker(marker) then return false end
    local character, root = workCharacter(player)
    if not character or not ((root.Position - marker.Position).Magnitude <= 14) then return false end
    if player:GetAttribute("MissionStage") ~= "None" then
        status(player, "Conclua ou cancele sua entrega antes de começar um turno.")
        return false
    end
    local now = Workspace:GetServerTimeNow()
    if not finite(now) then return false end
    if now < (availableAt[player] or 0) then
        status(player, "Aguarde alguns segundos antes de começar outro turno.")
        return false
    end
    local job = jobs[marker.Name]
    local energy = amount(player, "Energy")
    if energy < job.energy then
        status(player, "Energia insuficiente. Descanse no hospital ou no seu apartamento.")
        return false
    end
    local reward = job.reward + math.floor(amount(player, "Reputation") / 10)
    local shift = {
        character = character,
        marker = marker,
        markerName = marker.Name,
        endsAt = now + job.duration,
        reward = reward,
        wanted = job.wanted,
    }
    active[player] = shift
    player:SetAttribute("Energy", energy - job.energy)
    player:SetAttribute("WorkTitle", job.title)
    player:SetAttribute("WorkMarkerName", marker.Name)
    player:SetAttribute("WorkStartedAt", now)
    player:SetAttribute("WorkEndsAt", shift.endsAt)
    player:SetAttribute("WorkReward", reward)
    player:SetAttribute("WorkMessage", "Fique a até 18 studs, em pé.")
    player:SetAttribute("CurrentJob", job.title)
    player:SetAttribute("WorkActive", true)
    status(player, "Turno iniciado: " .. job.title .. ". Energia reservada: " .. job.energy .. ".")
    return true
end

function JobService.cancel(player, message)
    if not active[player] then return false end
    endShift(player, Workspace:GetServerTimeNow(), message or "Turno cancelado. A energia gasta não é devolvida.")
    return true
end

function JobService.remove(player)
    active[player] = nil
    availableAt[player] = nil
    clearAttributes(player)
end

function JobService.tick(now)
    if not finite(now) then return end
    for player, shift in pairs(active) do
        local character, root = workCharacter(player)
        local valid = character ~= nil and character == shift.character
            and validMarker(shift.marker) and shift.marker.Name == shift.markerName
            and player:GetAttribute("MissionStage") == "None"
            and (root.Position - shift.marker.Position).Magnitude <= 18
        if not valid then
            endShift(player, now, "Turno encerrado sem pagamento. Fique perto do marcador, em pé, até o fim.")
        elseif now >= shift.endsAt then
            endShift(player, now, "Turno concluído! +$" .. shift.reward .. " e +8 de reputação.")
            player:SetAttribute("Cash", amount(player, "Cash") + shift.reward)
            player:SetAttribute("Reputation", amount(player, "Reputation") + 8)
            player:SetAttribute("Wanted", math.min(5, amount(player, "Wanted") + shift.wanted))
            player:SetAttribute("WorkCompletions", amount(player, "WorkCompletions") + 1)
        end
    end
end

return JobService
