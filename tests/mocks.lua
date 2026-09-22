-- Minimal Roblox substitutes for the prompt handler, not an engine simulation.
local clock = 100
local os = { clock = function() return clock end }
local Workspace = { GetServerTimeNow = function() return clock end }
local Players = {}
local city = { children = {}, Parent = Workspace }
function city:FindFirstChild(name) return self.children[name] end
function Workspace:FindFirstChild(name) return name == "Downtown" and city or nil end
local game = { GetService = function(_, name) return name == "Players" and Players or Workspace end }
local realTypeof = typeof
local function typeof(value) return type(value) == "table" and value.IsA and "Instance" or realTypeof(value) end
local interactions = {}
local lastPrompt
local Housing = { entered = {} }
function Housing.enter(player)
    Housing.entered[player] = (Housing.entered[player] or 0) + 1
    return true
end
local missionAction = { OnServerEvent = {} }
function missionAction.OnServerEvent:Connect(callback)
    missionAction.fire = callback
end
local jobAction = { OnServerEvent = {} }
function jobAction.OnServerEvent:Connect(callback) jobAction.fire = callback end
local inventoryAction = { OnServerEvent = {} }
function inventoryAction.OnServerEvent:Connect(callback) inventoryAction.fire = callback end
local objectiveAction = { OnServerEvent = {} }
function objectiveAction.OnServerEvent:Connect(callback) objectiveAction.fire = callback end

local vectorMeta = {}
local function vector(x, y, z)
    return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
end
vectorMeta.__sub = function(a, b)
    return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
vectorMeta.__index = function(v, key)
    if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
end
local Vector3 = { new = vector }
local CFrame = { new = function(position) return position end }
local Color3 = { fromRGB = function(...) return { ... } end }
local Enum = { Material = { Neon = "Neon" } }

local Instance = {}
function Instance.new(className)
    assert(className == "ProximityPrompt", "Unexpected mocked instance: " .. className)
    local prompt = { Triggered = {} }
    function prompt.Triggered:Connect(callback)
        prompt.fire = callback
    end
    lastPrompt = prompt
    return prompt
end

local function createPart(parent, name, _size, position, _color, _material)
    local part = { Name = name, Position = position, Parent = parent }
    function part:IsA(className) return className == "BasePart" or className == "Part" end
    function part:IsDescendantOf(ancestor) return self.Parent == ancestor end
    if parent == city then city.children[name] = part end
    return part
end

local function notify(player, message)
    player:SetAttribute("StatusText", message)
end

local function newPlayer(overrides)
    local attributes = {
        DataReady = true, MissionRoute = "vip", Cash = 1000, BankBalance = 500, Energy = 100, Reputation = 0,
        Wanted = 0, OwnedProperties = 0, PassiveIncome = 0, NextIncomeAt = 0,
        MissionStage = "None", MissionReward = 0, CurrentMission = "Nenhuma",
        MissionExpiresAt = 0, MissionCompletions = 0, MissionText = "",
        WorkActive = false, WorkCompletions = 0, SnackCount = 0, InsideHome = false,
        ObjectiveClaims = 0, SnacksPurchased = 0,
    }
    for key, value in pairs(overrides or {}) do attributes[key] = value end
    local player = { attributes = attributes, Parent = Players }
    function player:IsA(className) return className == "Player" end
    function player:GetAttribute(name) return self.attributes[name] end
    local attributeSignals = {}
    function player:GetAttributeChangedSignal(name)
        if not attributeSignals[name] then
            local signal = { callbacks = {} }
            function signal:Connect(callback)
                local connection = { Connected = true }
                function connection:Disconnect() self.Connected = false end
                table.insert(self.callbacks, { connection = connection, callback = callback })
                return connection
            end
            attributeSignals[name] = signal
        end
        return attributeSignals[name]
    end
    function player:SetAttribute(name, value)
        if self.attributes[name] == value then return end
        self.attributes[name] = value
        local signal = attributeSignals[name]
        if signal then
            for _, item in ipairs(signal.callbacks) do
                if item.connection.Connected then item.callback() end
            end
        end
    end
    local character = {
        root = createPart(nil, "HumanoidRootPart", nil, vector(0, 0, 0)),
        humanoid = { Health = 100 },
    }
    function character:FindFirstChild(name)
        if name == "HumanoidRootPart" then return self.root end
    end
    function character:FindFirstChildOfClass(name)
        if name == "Humanoid" then return self.humanoid end
    end
    player.Character = character
    return player
end
