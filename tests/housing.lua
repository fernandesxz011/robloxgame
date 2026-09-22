-- Object substitutes exercise server authorization and lifecycle, not rendering,
-- Roblox physics, replication or the engine's ProximityPrompt hold behavior.
local vectorMeta = {}
local function vector(x, y, z)
    return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
end
vectorMeta.__add = function(a, b) return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vectorMeta.__sub = function(a, b) return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vectorMeta.__index = function(value, key)
    if key == "Magnitude" then return math.sqrt(value.X ^ 2 + value.Y ^ 2 + value.Z ^ 2) end
end
local Vector3 = { new = vector, zero = vector(0, 0, 0) }
local CFrame = {
    new = function(position) return { Position = position } end,
    lookAt = function(position, target) return { Position = position, Target = target } end,
}
local Color3 = { fromRGB = function(...) return { ... } end }
local Vector2 = { new = function(...) return { ... } end }
local UDim2 = { fromScale = function(...) return { ... } end }
local Enum = setmetatable({}, { __index = function(_, category)
    return setmetatable({}, { __index = function(_, name) return category .. "." .. name end })
end })

local function setup()
    local registry, methods = {}, {}
    local meta = {
        __index = function(object, key)
            if key == "Parent" then return rawget(object, "_parent") end
            return methods[key]
        end,
        __newindex = function(object, key, value)
            if key == "Parent" then rawset(object, "_parent", value) return end
            if key == "CFrame" then rawset(object, "Position", value.Position) end
            rawset(object, key, value)
        end,
    }
    function methods:GetChildren()
        local children = {}
        for _, object in ipairs(registry) do
            if object.Parent == self then table.insert(children, object) end
        end
        return children
    end
    function methods:FindFirstChild(name)
        for _, child in ipairs(self:GetChildren()) do
            if child.Name == name then return child end
        end
    end
    function methods:FindFirstChildOfClass(name)
        for _, child in ipairs(self:GetChildren()) do
            if child.ClassName == name then return child end
        end
    end
    function methods:IsA(name) return self.ClassName == name or (name == "BasePart" and self.ClassName == "Part") end
    function methods:SetAttribute(name, value) self.attributes[name] = value end
    function methods:GetAttribute(name) return self.attributes[name] end
    function methods:Destroy()
        for _, child in ipairs(self:GetChildren()) do child:Destroy() end
        if self.Triggered then self.Triggered.connections = {} end
        self.Parent = nil
        self.destroyed = true
    end
    function methods:PivotTo(target)
        if self.failMove then error("Simulated move failure") end
        self:FindFirstChild("HumanoidRootPart").Position = target.Position
    end
    local Instance = {}
    function Instance.new(className)
        local object = setmetatable({ ClassName = className, attributes = {} }, meta)
        if className == "ProximityPrompt" then
            local event = { connections = {} }
            function event:Connect(callback)
                table.insert(self.connections, callback)
            end
            function event:Fire(player)
                for _, callback in ipairs(self.connections) do callback(player) end
            end
            object.Triggered = event
        end
        table.insert(registry, object)
        return object
    end
    local players, workspace = Instance.new("Players"), Instance.new("Workspace")
    players.MaxPlayers = 2
    local city = Instance.new("Model")
    city.Name, city.Parent = "Downtown", workspace
    local marker = Instance.new("Part")
    marker.Name, marker.Position, marker.Parent = "HouseOffer", vector(62, 2.5, -12), city
    local clock = 100
    local game = { GetService = function(_, name)
        if name == "Players" then return players end
        if name == "Workspace" then return workspace end
        error("Unexpected service: " .. name)
    end }
    local housing = makeModule(game, Instance, Vector3, CFrame, Color3, Vector2, UDim2, Enum, { clock = function() return clock end })
    local nextId = 0
    local env = { housing = housing, workspace = workspace, marker = marker }
    function env.player()
        nextId += 1
        local player = Instance.new("Player")
        player.UserId, player.Parent = nextId, players
        for name, value in pairs({ DataReady = true, OwnedProperties = 1, Energy = 20, Cash = 450, InsideHome = false }) do
            player:SetAttribute(name, value)
        end
        local character = Instance.new("Model")
        local root = Instance.new("Part")
        root.Name, root.Position, root.Parent = "HumanoidRootPart", marker.Position, character
        local humanoid = Instance.new("Humanoid")
        humanoid.Health, humanoid.Sit, humanoid.Parent = 100, false, character
        player.Character = character
        return player, root, humanoid
    end
    function env.home(player)
        local container = workspace:FindFirstChild("DowntownHomes")
        return container and container:FindFirstChild("Apartment_" .. tostring(player.UserId))
    end
    function env.fire(player, name, visitor)
        local home = assert(env.home(player))
        local host = home:FindFirstChild(name == "RestAtHome" and "Mattress" or "FrontDoor")
        host:FindFirstChild(name).Triggered:Fire(visitor or player)
    end
    function env.near(player, name)
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        root.Position = assert(env.home(player)):FindFirstChild(name).Position + vector(0, 3, 0)
    end
    function env.advance(seconds) clock += seconds end
    return env
end

local passed, failed = 0, 0
local function expect(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, callback)
    local ok, message = pcall(callback)
    if ok then passed += 1 print("PASS " .. name)
    else failed += 1 print("FAIL " .. name .. ": " .. tostring(message)) end
end

test("entry rejects unready, unowned, distant, dead and seated players before construction", function()
    local invalid = {
        function(p) p:SetAttribute("DataReady", false) end,
        function(p) p:SetAttribute("OwnedProperties", 0) end,
        function(_, root) root.Position = vector(0, 0, 0) end,
        function(_, root) root.Position = vector(0 / 0, 0, 0) end,
        function(_, _, humanoid) humanoid.Health = 0 end,
        function(_, _, humanoid) humanoid.Sit = true end,
        function(_, _, humanoid) humanoid.SeatPart = {} end,
        function(p) p.Parent = nil end,
    }
    for _, invalidate in ipairs(invalid) do
        local e = setup()
        local p, root, humanoid = e.player()
        invalidate(p, root, humanoid)
        expect(e.housing.enter(p), false)
        expect(e.home(p), nil)
        expect(p:GetAttribute("InsideHome"), false)
    end
end)

test("entry creates one apartment and preserves the player's economy", function()
    local e = setup()
    local p, root = e.player()
    expect(e.housing.enter(p), true)
    expect(p:GetAttribute("InsideHome"), true)
    expect(root.Position.X, 690)
    expect(root.Position.Y, 124.5)
    expect(p:GetAttribute("Cash"), 450)
    expect(e.home(p):GetAttribute("OwnerUserId"), p.UserId)
    expect(e.housing.enter(p), false)
    expect(#e.workspace:FindFirstChild("DowntownHomes"):GetChildren(), 1)
end)

test("missing exterior marker and failed teleport do not mark the player as inside", function()
    local e = setup()
    local p = e.player()
    e.marker.Parent = nil
    expect(e.housing.enter(p), false)
    expect(e.home(p), nil)
    e = setup()
    p = e.player()
    p.Character.failMove = true
    expect(e.housing.enter(p), false)
    expect(p:GetAttribute("InsideHome"), false)
end)

test("only the owner can use the apartment prompts", function()
    local e = setup()
    local owner = e.player()
    local visitor = e.player()
    expect(e.housing.enter(owner), true)
    e.near(owner, "Mattress")
    visitor.Character:FindFirstChild("HumanoidRootPart").Position = owner.Character:FindFirstChild("HumanoidRootPart").Position
    e.fire(owner, "RestAtHome", visitor)
    expect(visitor:GetAttribute("Energy"), 20)
    expect(owner:GetAttribute("Energy"), 20)
    e.fire(owner, "LeaveApartment", visitor)
    expect(owner:GetAttribute("InsideHome"), true)
end)

test("rest restores energy with a two-second hold and an enforced cooldown", function()
    local e = setup()
    local p = e.player()
    expect(e.housing.enter(p), true)
    e.near(p, "Mattress")
    expect(e.home(p):FindFirstChild("Mattress"):FindFirstChild("RestAtHome").HoldDuration, 2)
    e.fire(p, "RestAtHome")
    expect(p:GetAttribute("Energy"), 100)
    p:SetAttribute("Energy", 30)
    e.fire(p, "RestAtHome")
    expect(p:GetAttribute("Energy"), 30)
    e.advance(8)
    e.fire(p, "RestAtHome")
    expect(p:GetAttribute("Energy"), 100)
    expect(p:GetAttribute("Cash"), 450)
end)

test("rest rejects distant, unready, dead and replaced characters", function()
    local invalid = {
        function(_, _, root) root.Position = vector(0, 0, 0) end,
        function(_, p) p:SetAttribute("DataReady", false) end,
        function(_, p) p:SetAttribute("InsideHome", false) end,
        function(_, p) p:SetAttribute("OwnedProperties", 0) end,
        function(_, _, _, humanoid) humanoid.Health = 0 end,
        function(e, p) p.Character = e.player().Character end,
    }
    for _, invalidate in ipairs(invalid) do
        local e = setup()
        local p, root, humanoid = e.player()
        expect(e.housing.enter(p), true)
        e.near(p, "Mattress")
        invalidate(e, p, root, humanoid)
        e.fire(p, "RestAtHome")
        expect(p:GetAttribute("Energy"), 20)
    end
end)

test("exit returns the owner to clear ground west of HouseOffer", function()
    local e = setup()
    local p, root = e.player()
    expect(e.housing.enter(p), true)
    e.near(p, "FrontDoor")
    e.fire(p, "LeaveApartment")
    expect(p:GetAttribute("InsideHome"), false)
    expect(root.Position.X, 57)
    expect(root.Position.Y, 6.5)
    expect(root.Position.Z, -12)
    expect(e.housing.leave(p), false)
end)

test("exit rejects distance, unavailable data, death and a failed move", function()
    local invalid = {
        function(_, _, root) root.Position = vector(0, 0, 0) end,
        function(_, p) p:SetAttribute("DataReady", false) end,
        function(_, _, _, humanoid) humanoid.Health = 0 end,
        function(e) e.marker.Parent = nil end,
        function(_, p) p.Character.failMove = true end,
    }
    for _, invalidate in ipairs(invalid) do
        local e = setup()
        local p, root, humanoid = e.player()
        expect(e.housing.enter(p), true)
        e.near(p, "FrontDoor")
        invalidate(e, p, root, humanoid)
        expect(e.housing.leave(p), false)
        expect(p:GetAttribute("InsideHome"), true)
    end
end)

test("reentry reuses the room and cannot reset the rest cooldown", function()
    local e = setup()
    local p, root = e.player()
    expect(e.housing.enter(p), true)
    local firstHome = e.home(p)
    e.near(p, "Mattress")
    e.fire(p, "RestAtHome")
    e.near(p, "FrontDoor")
    expect(e.housing.leave(p), true)
    expect(e.housing.enter(p), true)
    expect(e.home(p), firstHome)
    p:SetAttribute("Energy", 15)
    e.near(p, "Mattress")
    e.fire(p, "RestAtHome")
    expect(p:GetAttribute("Energy"), 15)
    expect(root.Position.X > 600, true)
end)

test("reset destroys prompts and frees a slot without moving the character", function()
    local e = setup()
    local p, root = e.player()
    expect(e.housing.enter(p), true)
    local room = e.home(p)
    local rest = room:FindFirstChild("Mattress"):FindFirstChild("RestAtHome")
    local position = root.Position
    e.housing.reset(p)
    expect(room.destroyed, true)
    expect(e.home(p), nil)
    expect(p:GetAttribute("InsideHome"), false)
    expect(root.Position, position)
    rest.Triggered:Fire(p)
    expect(p:GetAttribute("Energy"), 20)
    root.Position = e.marker.Position
    expect(e.housing.enter(p), true)
    expect(root.Position.X, 690)
end)

test("room slots remain bounded and are reused after removing a player", function()
    local e = setup()
    local first, firstRoot = e.player()
    local second, secondRoot = e.player()
    local third, thirdRoot = e.player()
    expect(e.housing.enter(first), true)
    expect(e.housing.enter(second), true)
    expect(firstRoot.Position.X, 690)
    expect(secondRoot.Position.X, 780)
    expect(e.housing.enter(third), false)
    e.housing.remove(first)
    expect(e.housing.enter(third), true)
    expect(thirdRoot.Position.X, 690)
    expect(second:GetAttribute("InsideHome"), true)
    e.housing.remove(first)
    expect(e.housing.leave(first), false)
end)

print(string.format("Housing: %d passed, %d failed", passed, failed))
assert(failed == 0, "Housing checks failed")
