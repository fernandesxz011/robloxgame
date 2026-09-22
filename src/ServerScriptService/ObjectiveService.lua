-- Welcome objectives derive their progress from server-owned player data.
-- The caller connects the claim remote and disposes trackPlayer on removal.
local Players = game:GetService("Players")

local ObjectiveService = {}
local CASH_LIMIT = 2000000000
local claiming = {}
local objectives = {
    { id = "first_shift", title = "Primeiro trabalho", text = "Conclua um turno em qualquer ponto verde.", stat = "WorkCompletions", target = 1, reward = 100, marker = "FastFood" },
    { id = "packed_snack", title = "Lanche na mochila", text = "Compre um lanche no mercadinho.", stat = "SnacksPurchased", target = 1, reward = 75, marker = "SnackShop" },
    { id = "first_delivery", title = "Primeira entrega", text = "Conclua uma entrega da central.", stat = "MissionCompletions", target = 1, reward = 150, marker = "MainMission" },
    { id = "bank_reserve", title = "Sua reserva", text = "Guarde $500 no banco.", stat = "BankBalance", target = 500, reward = 125, marker = "BankMarker" },
    { id = "first_home", title = "Seu apartamento", text = "Compre o apartamento no ponto laranja.", stat = "OwnedProperties", target = 1, reward = 200, marker = "HouseOffer" },
    { id = "steady_work", title = "Rotina de trabalho", text = "Conclua cinco turnos.", stat = "WorkCompletions", target = 5, reward = 250, marker = "FastFood" },
    { id = "city_courier", title = "Entregador da cidade", text = "Conclua três entregas.", stat = "MissionCompletions", target = 3, reward = 300, marker = "MainMission" },
}
local watched = {
    "DataReady", "ObjectiveClaims", "WorkCompletions", "SnackCount", "SnacksPurchased",
    "MissionCompletions", "BankBalance", "OwnedProperties",
}

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function amount(player, attribute)
    local value = player:GetAttribute(attribute)
    return finite(value) and math.max(0, math.floor(value)) or 0
end

local function currentObjective(player)
    local claims = math.min(#objectives, amount(player, "ObjectiveClaims"))
    local objective = objectives[claims + 1]
    if not objective then return claims, nil, 0 end
    local progress = amount(player, objective.stat)
    if objective.id == "packed_snack" then
        -- Existing inventory also counts for profiles created before purchase tracking.
        progress = math.max(progress, amount(player, "SnackCount"))
    end
    return claims, objective, math.min(objective.target, progress)
end

function ObjectiveService.refresh(player)
    local claims, objective, progress = currentObjective(player)
    player:SetAttribute("ObjectiveTotal", #objectives)
    player:SetAttribute("ObjectiveNumber", math.min(claims + 1, #objectives))
    player:SetAttribute("ObjectivesFinished", objective == nil)
    player:SetAttribute("ObjectiveId", objective and objective.id or "")
    player:SetAttribute("ObjectiveTitle", objective and objective.title or "Primeiros passos concluídos")
    player:SetAttribute("ObjectiveText", objective and objective.text or "Continue explorando a cidade, trabalhando e fazendo entregas.")
    player:SetAttribute("ObjectiveProgress", progress)
    player:SetAttribute("ObjectiveTarget", objective and objective.target or 0)
    player:SetAttribute("ObjectiveReward", objective and objective.reward or 0)
    player:SetAttribute("ObjectiveMarkerName", objective and objective.marker or "")
    player:SetAttribute("ObjectiveReady", player:GetAttribute("DataReady") == true and objective ~= nil and progress >= objective.target)
end

function ObjectiveService.trackPlayer(player)
    local connections = {}
    for _, attribute in ipairs(watched) do
        table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(function()
            ObjectiveService.refresh(player)
        end))
    end
    ObjectiveService.refresh(player)
    return function()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections)
    end
end

function ObjectiveService.claim(player, objectiveId)
    if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return false end
    if player:GetAttribute("DataReady") ~= true or claiming[player] or type(objectiveId) ~= "string" then return false end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not humanoid or not (humanoid.Health > 0) then return false end
    local claims, objective, progress = currentObjective(player)
    if not objective or objectiveId ~= objective.id or progress < objective.target then return false end
    local cash = player:GetAttribute("Cash")
    if not finite(cash) or cash < 0 or cash % 1 ~= 0 or cash > CASH_LIMIT - objective.reward then
        player:SetAttribute("StatusText", "Abra espaço na carteira antes de receber a recompensa do objetivo.")
        return false
    end
    -- Advance the authoritative counter first, before callbacks can see a paid objective.
    claiming[player] = true
    player:SetAttribute("ObjectiveClaims", claims + 1)
    player:SetAttribute("Cash", cash + objective.reward)
    player:SetAttribute("StatusText", "Objetivo concluído! +$" .. tostring(objective.reward) .. ".")
    ObjectiveService.refresh(player)
    claiming[player] = nil
    return true
end

return ObjectiveService
