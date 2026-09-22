-- Execute the real mesh builder and controller; emulate only the engine API.
-- These substitutes check geometry and authorization, not collision response.
local vectorMeta = {}
local function vector(x, y, z)
    return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
end
vectorMeta.__add = function(a, b) return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vectorMeta.__sub = function(a, b) return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vectorMeta.__unm = function(a) return vector(-a.X, -a.Y, -a.Z) end
vectorMeta.__mul = function(a, b)
    if type(a) == "number" then a, b = b, a end
    return vector(a.X * b, a.Y * b, a.Z * b)
end
vectorMeta.__div = function(a, b) return vector(a.X / b, a.Y / b, a.Z / b) end
local vectorMethods = {}
function vectorMethods:Dot(b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
function vectorMethods:Cross(b)
    return vector(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X)
end
function vectorMethods:Lerp(b, fraction) return self + (b - self) * fraction end
vectorMeta.__index = function(v, key)
    if key == "Magnitude" then return math.sqrt(v:Dot(v)) end
    if key == "Unit" then return v / v.Magnitude end
    return vectorMethods[key]
end
local Vector3 = { new = vector, zero = vector(0, 0, 0) }
local X, Y, Z = vector(1, 0, 0), vector(0, 1, 0), vector(0, 0, 1)
local frameMeta, frameMethods = {}, {}
local function frame(position, right, up, back)
    return setmetatable({ Position = position, RightVector = right or X, UpVector = up or Y, BackVector = back or Z }, frameMeta)
end
function frameMethods:VectorToWorldSpace(v)
    return self.RightVector * v.X + self.UpVector * v.Y + self.BackVector * v.Z
end
function frameMethods:PointToWorldSpace(v) return self.Position + self:VectorToWorldSpace(v) end
function frameMethods:Inverse()
    local r, u, b = self.RightVector, self.UpVector, self.BackVector
    local rotation = frame(Vector3.zero, vector(r.X, u.X, b.X), vector(r.Y, u.Y, b.Y), vector(r.Z, u.Z, b.Z))
    rotation.Position = rotation:VectorToWorldSpace(-self.Position)
    return rotation
end
frameMeta.__index = function(f, key)
    if key == "Rotation" then return frame(Vector3.zero, f.RightVector, f.UpVector, f.BackVector) end
    if key == "LookVector" then return -f.BackVector end
    return frameMethods[key]
end
frameMeta.__mul = function(a, b)
    return frame(a:PointToWorldSpace(b.Position), a:VectorToWorldSpace(b.RightVector), a:VectorToWorldSpace(b.UpVector), a:VectorToWorldSpace(b.BackVector))
end
local CFrame = {
    new = function(x, y, z) return frame(type(x) == "table" and x or vector(x or 0, y or 0, z or 0)) end,
    Angles = function(x, yaw, z)
        assert(x == 0 and z == 0, "Mock only needs yaw rotations")
        return frame(Vector3.zero, vector(math.cos(yaw), 0, -math.sin(yaw)), Y, vector(math.sin(yaw), 0, math.cos(yaw)))
    end,
    fromMatrix = frame,
    identity = frame(Vector3.zero),
}
local Color3 = { fromRGB = function(...) return { ... } end, new = function(...) return { ... } end }
local Vector2 = { new = function(x, y) return { X = x, Y = y } end, zero = { X = 0, Y = 0 } }
local UDim2 = { fromScale = function(...) return { ... } end }
local UDim = { new = function(...) return { ... } end }
local PhysicalProperties = { new = function(...) return { ... } end }
local RaycastParams = { new = function() return {} end }
local Enum = setmetatable({}, { __index = function(_, category)
    return setmetatable({}, { __index = function(_, name) return category .. "." .. name end })
end })

local function signal()
    local event = { connections = {} }
    function event:Connect(callback)
        local connection = { Connected = true, callback = callback }
        function connection:Disconnect() self.Connected = false end
        table.insert(self.connections, connection)
        return connection
    end
    function event:Fire(...)
        for _, connection in ipairs(table.clone(self.connections)) do
            if connection.Connected then connection.callback(...) end
        end
    end
    function event:count()
        local count = 0
        for _, connection in ipairs(self.connections) do
            if connection.Connected then count += 1 end
        end
        return count
    end
    return event
end

local function setup(allModels, specificationOverrides)
    local methods, meta = {}, {}
    meta.__index = function(object, key)
        if key == "Position" then return object._properties.CFrame.Position end
        if object._properties[key] ~= nil then return object._properties[key] end
        return methods[key]
    end
    meta.__newindex = function(object, key, value)
        if key == "Parent" then
            local previous = object.Parent
            if previous then
                local index = table.find(previous._children, object)
                if index then table.remove(previous._children, index) end
            end
            if value then table.insert(value._children, object) end
        elseif key == "Position" then
            object.CFrame = frame(value, object.CFrame.RightVector, object.CFrame.UpVector, object.CFrame.BackVector)
            return
        end
        local changed = object._properties[key] ~= value
        object._properties[key] = value
        if changed and object._signals[key] then object._signals[key]:Fire() end
    end
    function methods:GetChildren() return table.clone(self._children) end
    function methods:GetDescendants()
        local result = {}
        for _, child in ipairs(self:GetChildren()) do
            table.insert(result, child)
            for _, descendant in ipairs(child:GetDescendants()) do table.insert(result, descendant) end
        end
        return result
    end
    function methods:FindFirstChild(name)
        for _, child in ipairs(self:GetChildren()) do if child.Name == name then return child end end
    end
    function methods:FindFirstChildOfClass(name)
        for _, child in ipairs(self:GetChildren()) do if child:IsA(name) then return child end end
    end
    function methods:IsA(name)
        return name == self.ClassName or (name == "BasePart" and (self.ClassName == "Part" or self.ClassName == "VehicleSeat"))
    end
    function methods:IsDescendantOf(ancestor)
        local cursor = self.Parent
        while cursor do
            if cursor == ancestor then return true end
            cursor = cursor.Parent
        end
        return false
    end
    function methods:SetAttribute(name, value) self._attributes[name] = value end
    function methods:GetAttribute(name) return self._attributes[name] end
    function methods:GetPropertyChangedSignal(name)
        if not self._signals[name] then self._signals[name] = signal() end
        return self._signals[name]
    end
    function methods:SetNetworkOwner(owner) self.owner, self.ownerAssigned = owner, true end
    function methods:Sit(humanoid)
        if self.Occupant then return end
        humanoid.Sit, humanoid.SeatPart = true, self
        self.Occupant = humanoid
    end
    function methods:Destroy()
        if self.destroying or self.destroyed then return end
        self.destroying = true
        self.Destroying:Fire()
        for _, child in ipairs(self:GetChildren()) do child:Destroy() end
        self.Parent = nil
        self.destroyed = true
    end
    function methods:PivotTo(target)
        local delta = target * self.PrimaryPart.CFrame:Inverse()
        for _, child in ipairs(self:GetDescendants()) do
            if child:IsA("BasePart") then child.CFrame = delta * child.CFrame end
        end
    end
    local Instance = {}
    function Instance.new(className)
        local object = setmetatable({
            _properties = { ClassName = className, Name = className, CFrame = CFrame.identity, Enabled = true },
            _children = {}, _attributes = {}, _signals = {},
        }, meta)
        object.Destroying = signal()
        if className == "ProximityPrompt" then object.Triggered = signal() end
        return object
    end
    local workspace, players = Instance.new("Workspace"), Instance.new("Players")
    local city = Instance.new("Model")
    city.Parent = workspace
    local heartbeat = signal()
    local remote = { OnServerEvent = signal() }
    local clock = 100
    local services = {
        Workspace = workspace, Players = players, RunService = { Heartbeat = heartbeat },
        ReplicatedStorage = { WaitForChild = function(_, name) return name end },
    }
    local game = { GetService = function(_, name) return assert(services[name], name) end }
    function players:GetPlayers() return self:GetChildren() end
    function players:GetPlayerFromCharacter(character)
        for _, player in ipairs(self:GetPlayers()) do if player.Character == character then return player end end
    end
    local env = { workspace = workspace, city = city, players = players, heartbeat = heartbeat, remote = remote,
        contactNormal = Y, contactCount = 4, rayCount = 0, Instance = Instance }
    function workspace:Raycast(origin, direction, parameters)
        env.rayCount += 1
        env.raycastFilter = parameters.FilterDescendantsInstances
        env.lastRayDirection = direction
        if (env.rayCount - 1) % 4 < env.contactCount then return { Normal = env.contactNormal } end
    end
    local catalog = { models = {}, fleet = allModels and Catalog.fleet or { Catalog.fleet[1], Catalog.fleet[2] } }
    for _, source in ipairs(Catalog.models) do
        local specification = table.clone(source)
        for name, value in pairs(specificationOverrides or {}) do specification[name] = value end
        table.insert(catalog.models, specification)
    end
    function catalog.get(id)
        for _, specification in ipairs(catalog.models) do
            if specification.id == id then return specification end
        end
    end
    env.specification = catalog.get(catalog.fleet[1].id)
    local function requireModule(name)
        if name == "VehicleUnits" then return VehicleUnits end
        if name == "VehicleCatalog" then return catalog end
        error("Unexpected module: " .. tostring(name))
    end
    env.service = makeModule(game, Instance, Vector3, CFrame, Color3, Vector2, UDim2, UDim, Enum,
        PhysicalProperties, RaycastParams, { clock = function() return clock end }, requireModule,
        { Parent = { WaitForChild = function(_, name) return name end } })
    env.cleanup = env.service.start(city, remote)
    env.fleet = assert(city:FindFirstChild("Vehicles"))
    env.model = env.fleet:GetChildren()[1]
    env.chassis = env.model.PrimaryPart
    env.seat = env.model:FindFirstChild("DriverSeat")
    env.prompt = env.seat:FindFirstChild("EnterVehicle")
    env.drive = env.chassis:FindFirstChild("GroundDrive")
    env.align = env.chassis:FindFirstChild("GroundSteering")
    function env.player()
        local player = Instance.new("Player")
        player.Parent = players
        player:SetAttribute("DataReady", true)
        local character = Instance.new("Model")
        character.Parent = workspace
        local root = Instance.new("Part")
        root.Name, root.Position, root.Parent = "HumanoidRootPart", env.seat.Position, character
        local humanoid = Instance.new("Humanoid")
        humanoid.Health, humanoid.Sit, humanoid.Parent = 100, false, character
        player.Character = character
        return player, root, humanoid
    end
    function env.enter(player) env.prompt.Triggered:Fire(player) end
    function env.input(player, throttle, steer) remote.OnServerEvent:Fire(player, throttle, steer) end
    function env.advance(seconds) clock += seconds end
    function env.step(seconds)
        seconds = seconds or 0.1
        env.advance(seconds)
        heartbeat:Fire(seconds)
    end
    function env.leave()
        local occupant = env.seat.Occupant
        if occupant then occupant.Sit, occupant.SeatPart = false, nil end
        env.seat.Occupant = nil
    end
    return env
end
