-- All inventory changes are synchronous and server-owned. Only successful
-- purchases/uses change Cash, SnackCount, SnacksPurchased or Energy; failed attempts still share
-- the short action cooldown after the player is ready and alive.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local InventoryService = {}
local lastActions = {}
local SNACK_PRICE = 60
local SNACK_ENERGY = 25
local SNACK_CAPACITY = 5
local ACTION_COOLDOWN = 2

local function liveCharacter(player)
    if player.Parent ~= Players or player:GetAttribute("DataReady") ~= true then return nil end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not humanoid or not (humanoid.Health > 0) then return nil end
    return root, humanoid
end

local function beginAction(player)
    local root, humanoid = liveCharacter(player)
    if not root then return nil end
    local now = Workspace:GetServerTimeNow()
    local previous = lastActions[player]
    if previous and now - previous < ACTION_COOLDOWN then return nil end
    lastActions[player] = now
    return root, humanoid
end

local function stat(player, name, default)
    local value = player:GetAttribute(name)
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return default end
    return value
end

function InventoryService.buySnack(player, marker)
    local root, humanoid = beginAction(player)
    if not root then return false end
    local city = Workspace:FindFirstChild("Downtown")
    local shop = city and city:FindFirstChild("SnackShop")
    if not shop or marker ~= shop or not shop:IsA("BasePart") then return false end
    if player:GetAttribute("InsideHome") == true or humanoid.Sit or humanoid.SeatPart then
        player:SetAttribute("StatusText", "Aproxime-se do mercadinho a pé para comprar.")
        return false
    end
    if not ((root.Position - shop.Position).Magnitude <= 14) then
        player:SetAttribute("StatusText", "Aproxime-se do mercadinho para comprar um lanche.")
        return false
    end
    local count = math.max(0, math.floor(stat(player, "SnackCount", 0)))
    if count >= SNACK_CAPACITY then
        player:SetAttribute("StatusText", "Mochila cheia: você já tem 5 lanches.")
        return false
    end
    local cash = stat(player, "Cash", 0)
    if cash < SNACK_PRICE then
        player:SetAttribute("StatusText", "O lanche custa $60. Você precisa de mais dinheiro na carteira.")
        return false
    end
    player:SetAttribute("Cash", cash - SNACK_PRICE)
    player:SetAttribute("SnackCount", count + 1)
    local purchased = math.clamp(math.floor(stat(player, "SnacksPurchased", 0)), 0, 10000000)
    player:SetAttribute("SnacksPurchased", math.min(purchased + 1, 10000000))
    player:SetAttribute("StatusText", string.format("Lanche comprado por $60 · mochila %d/5. Use para recuperar 25 de energia.", count + 1))
    return true
end

function InventoryService.useSnack(player)
    if not beginAction(player) then return false end
    local count = math.max(0, math.floor(stat(player, "SnackCount", 0)))
    if count < 1 then
        player:SetAttribute("StatusText", "Você está sem lanches. Compre no mercadinho por $60.")
        return false
    end
    local energy = math.clamp(stat(player, "Energy", 100), 0, 100)
    if energy >= 100 then
        player:SetAttribute("StatusText", "Sua energia está cheia. Guarde o lanche para depois.")
        return false
    end
    local restored = math.min(SNACK_ENERGY, 100 - energy)
    player:SetAttribute("SnackCount", count - 1)
    player:SetAttribute("Energy", energy + restored)
    player:SetAttribute("StatusText", string.format("Lanche consumido: +%d de energia · %d na mochila.", restored, count - 1))
    return true
end

function InventoryService.remove(player)
    lastActions[player] = nil
end

return InventoryService
