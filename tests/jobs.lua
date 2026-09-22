-- Roblox substitutes execute the production module, including its private state.
local vectorMeta = {}
local function vector(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vectorMeta) end
vectorMeta.__sub = function(a, b) return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vectorMeta.__index = function(value, key)
    if key == "Magnitude" then return math.sqrt(value.X ^ 2 + value.Y ^ 2 + value.Z ^ 2) end
end

local function setup()
    local registry, methods = {}, {}
    local instanceMeta = { __index = methods }
    local function instance(className, name, parent)
        local object = setmetatable({ ClassName = className, Name = name, Parent = parent, attributes = {} }, instanceMeta)
        table.insert(registry, object)
        return object
    end
    function methods:FindFirstChild(name)
        for _, child in ipairs(registry) do
            if child.Parent == self and child.Name == name then return child end
        end
    end
    function methods:FindFirstChildOfClass(className)
        for _, child in ipairs(registry) do
            if child.Parent == self and child.ClassName == className then return child end
        end
    end
    function methods:IsA(className)
        return self.ClassName == className or (className == "BasePart" and self.ClassName == "Part")
    end
    function methods:IsDescendantOf(ancestor)
        local parent = self.Parent
        while parent do
            if parent == ancestor then return true end
            parent = parent.Parent
        end
        return false
    end
    function methods:SetAttribute(name, value) self.attributes[name] = value end
    function methods:GetAttribute(name) return self.attributes[name] end
    local players = instance("Players", "Players")
    local workspace = instance("Workspace", "Workspace")
    local city = instance("Model", "Downtown", workspace)
    local currentTime = 100
    function workspace:GetServerTimeNow() return currentTime end
    local game = { GetService = function(_, name)
        if name == "Players" then return players end
        if name == "Workspace" then return workspace end
        error("Unexpected service: " .. name)
    end }
    local deterministicMath = setmetatable({ random = function() error("Shifts must not use random rewards") end }, { __index = math })
    local jobs = makeModule(game, function(value)
        return type(value) == "table" and getmetatable(value) == instanceMeta and "Instance" or type(value)
    end, deterministicMath)
    local markers = {}
    for _, name in ipairs({ "FastFood", "Taxi", "Delivery", "StreetDeal" }) do
        local marker = instance("Part", name, city)
        marker.Position = vector(0, 0, 0)
        markers[name] = marker
    end
    local e = { jobs = jobs, markers = markers, city = city, workspace = workspace, instance = instance }
    function e.player()
        local player = instance("Player", "Worker", players)
        for name, value in pairs({
            DataReady = true, InsideHome = false, MissionStage = "None", Cash = 450, Energy = 100,
            Reputation = 29, Wanted = 0, WorkCompletions = 0, WorkActive = false, CurrentJob = "Desempregado",
            CurrentMission = "Nenhuma", MissionText = "Siga para a central", MissionTargetName = "MainMission",
        }) do player:SetAttribute(name, value) end
        local character = instance("Model", "Character", workspace)
        local root = instance("Part", "HumanoidRootPart", character)
        root.Position = vector(0, 0, 0)
        local humanoid = instance("Humanoid", "Humanoid", character)
        humanoid.Health, humanoid.Sit = 100, false
        player.Character = character
        return player, root, humanoid
    end
    function e.setTime(now) currentTime = now end
    function e.tick(now)
        currentTime = now
        jobs.tick(now)
    end
    return e
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
local function expectClear(e, player)
    expect(e.jobs.isActive(player), false)
    expect(player:GetAttribute("WorkActive"), false)
    for _, name in ipairs({ "WorkTitle", "WorkMarkerName", "WorkMessage" }) do expect(player:GetAttribute(name), "") end
    for _, name in ipairs({ "WorkStartedAt", "WorkEndsAt", "WorkReward" }) do expect(player:GetAttribute(name), 0) end
    expect(player:GetAttribute("CurrentJob"), "Desempregado")
end

for _, config in ipairs({
    { "FastFood", "Restaurante", 18, 180, 15, 0 },
    { "Taxi", "Central de táxis", 20, 230, 20, 0 },
    { "Delivery", "Centro de encomendas", 25, 300, 25, 0 },
    { "StreetDeal", "Negócio da rua", 30, 420, 32, 3 },
}) do
    test(config[1] .. " reserves energy and pays its fixed amount only after the full duration", function()
        local e = setup()
        local p = e.player()
        expect(e.jobs.start(p, e.markers[config[1]]), true)
        expect(e.jobs.isActive(p), true)
        expect(p:GetAttribute("WorkActive"), true)
        expect(p:GetAttribute("WorkTitle"), config[2])
        expect(p:GetAttribute("CurrentJob"), config[2])
        expect(p:GetAttribute("WorkMarkerName"), config[1])
        expect(p:GetAttribute("WorkStartedAt"), 100)
        expect(p:GetAttribute("WorkEndsAt"), 100 + config[3])
        expect(p:GetAttribute("WorkReward"), config[4] + 2)
        expect(p:GetAttribute("Energy"), 100 - config[5])
        expect(p:GetAttribute("Cash"), 450)
        assert(#p:GetAttribute("WorkMessage") > 0)
        e.tick(100 + config[3] - 0.001)
        expect(p:GetAttribute("Cash"), 450)
        e.tick(100 + config[3])
        expect(p:GetAttribute("Cash"), 450 + config[4] + 2)
        expect(p:GetAttribute("Energy"), 100 - config[5])
        expect(p:GetAttribute("Reputation"), 37)
        expect(p:GetAttribute("Wanted"), config[6])
        expect(p:GetAttribute("WorkCompletions"), 1)
        expectClear(e, p)
    end)
end

test("readiness, active-state attributes and isActive use exact booleans", function()
    for _, ready in ipairs({ false, 0, 1, "true" }) do
        local e = setup()
        local p = e.player()
        p:SetAttribute("DataReady", ready)
        expect(e.jobs.start(p, e.markers.FastFood), false)
        expect(e.jobs.isActive(p), false)
        expect(type(e.jobs.isActive(p)), "boolean")
        expect(p:GetAttribute("WorkActive"), false)
        expect(p:GetAttribute("Energy"), 100)
    end
    local e = setup()
    local p = e.player()
    p:SetAttribute("DataReady", nil)
    expect(e.jobs.start(p, e.markers.FastFood), false)
    p:SetAttribute("DataReady", true)
    p:SetAttribute("WorkActive", true)
    expect(e.jobs.isActive(p), false)
    expect(e.jobs.start(p, e.markers.FastFood), true)
end)

test("start rejects distant, dead, seated, indoor, disconnected or malformed characters", function()
    local invalid = {
        function(_, p) p.Parent = nil end,
        function(_, p) p.Character = nil end,
        function(_, p) p:SetAttribute("InsideHome", true) end,
        function(_, _, root) root.Position = vector(14.01, 0, 0) end,
        function(_, _, root) root.Position = vector(0 / 0, 0, 0) end,
        function(_, _, root) root.ClassName = "Folder" end,
        function(_, _, root) root.Parent = nil end,
        function(_, _, _, humanoid) humanoid.Health = 0 end,
        function(_, _, _, humanoid) humanoid.Health = 0 / 0 end,
        function(_, _, _, humanoid) humanoid.Sit = true end,
        function(_, _, _, humanoid) humanoid.SeatPart = {} end,
        function(_, _, _, humanoid) humanoid.Parent = nil end,
    }
    for _, invalidate in ipairs(invalid) do
        local e = setup()
        local p, root, humanoid = e.player()
        invalidate(e, p, root, humanoid)
        expect(e.jobs.start(p, e.markers.FastFood), false)
        expect(e.jobs.isActive(p), false)
        expect(p:GetAttribute("Energy"), 100)
        expect(p:GetAttribute("Cash"), 450)
    end
end)

test("start accepts the 14-stud boundary and tick accepts the 18-stud boundary", function()
    local e = setup()
    local p, root = e.player()
    root.Position = vector(14, 0, 0)
    expect(e.jobs.start(p, e.markers.FastFood), true)
    root.Position = vector(18, 0, 0)
    e.tick(118)
    expect(p:GetAttribute("Cash"), 632)
end)

test("only configured BaseParts within the current Downtown can start shifts", function()
    for _, invalid in ipairs({
        function(e) return e.instance("Folder", "FastFood", e.city) end,
        function(e) return e.instance("Part", "UnknownJob", e.city) end,
        function(e) return e.instance("Part", "FastFood", e.workspace) end,
        function() return {} end,
        function() return "FastFood" end,
        function() return false end,
        function(e) e.city.Parent = nil return e.markers.FastFood end,
    }) do
        local e = setup()
        local p = e.player()
        expect(e.jobs.start(p, invalid(e)), false)
        expect(p:GetAttribute("Energy"), 100)
    end
    local e = setup()
    local p = e.player()
    expect(e.jobs.start(p, nil), false)
    e.markers.FastFood.Parent = e.instance("Folder", "Jobs", e.city)
    expect(e.jobs.start(p, e.markers.FastFood), true)
end)

test("an active delivery blocks work without changing any mission attributes", function()
    for _, stage in ipairs({ "Pickup", "Deliver" }) do
        local e = setup()
        local p = e.player()
        p:SetAttribute("MissionStage", stage)
        p:SetAttribute("MissionReward", 650)
        p:SetAttribute("MissionExpiresAt", 240)
        expect(e.jobs.start(p, e.markers.FastFood), false)
        expect(p:GetAttribute("MissionStage"), stage)
        expect(p:GetAttribute("MissionReward"), 650)
        expect(p:GetAttribute("MissionExpiresAt"), 240)
        expect(p:GetAttribute("MissionTargetName"), "MainMission")
        expect(p:GetAttribute("Energy"), 100)
    end
end)

test("insufficient or invalid energy never starts a shift or changes the economy", function()
    for _, energy in ipairs({ 0, 14, -10, "100", math.huge, 0 / 0 }) do
        local e = setup()
        local p = e.player()
        p:SetAttribute("Energy", energy)
        expect(e.jobs.start(p, e.markers.FastFood), false)
        expect(p:GetAttribute("Cash"), 450)
        expect(p:GetAttribute("Reputation"), 29)
        expect(e.jobs.isActive(p), false)
    end
    local e = setup()
    local p = e.player()
    p:SetAttribute("Energy", 15)
    expect(e.jobs.start(p, e.markers.FastFood), true)
    expect(p:GetAttribute("Energy"), 0)
end)

test("repeated starts cannot reserve energy twice or replace the existing shift", function()
    local e = setup()
    local p = e.player()
    expect(e.jobs.start(p, e.markers.FastFood), true)
    e.setTime(110)
    for _ = 1, 20 do expect(e.jobs.start(p, e.markers.StreetDeal), false) end
    expect(p:GetAttribute("WorkMarkerName"), "FastFood")
    expect(p:GetAttribute("WorkEndsAt"), 118)
    expect(p:GetAttribute("Energy"), 85)
    e.tick(118)
    expect(p:GetAttribute("Cash"), 632)
    expect(p:GetAttribute("Wanted"), 0)
end)

test("completion pays exactly once even after duplicate or delayed ticks and cancellation", function()
    local e = setup()
    local p = e.player()
    expect(e.jobs.start(p, e.markers.FastFood), true)
    e.tick(200)
    for _ = 1, 30 do e.tick(200) end
    e.tick(2000)
    expect(e.jobs.cancel(p), false)
    expect(p:GetAttribute("Cash"), 632)
    expect(p:GetAttribute("Reputation"), 37)
    expect(p:GetAttribute("WorkCompletions"), 1)
end)

test("reward snapshots starting reputation and ignores changed replicated shift attributes", function()
    local e = setup()
    local p = e.player()
    expect(e.jobs.start(p, e.markers.FastFood), true)
    p:SetAttribute("Reputation", 900)
    p:SetAttribute("Cash", 500)
    p:SetAttribute("WorkReward", 999999)
    p:SetAttribute("WorkEndsAt", 100)
    p:SetAttribute("WorkMarkerName", "StreetDeal")
    p:SetAttribute("WorkActive", false)
    e.tick(101)
    expect(p:GetAttribute("Cash"), 500)
    expect(e.jobs.isActive(p), true)
    e.tick(118)
    expect(p:GetAttribute("Cash"), 682)
    expect(p:GetAttribute("Reputation"), 908)
    expect(p:GetAttribute("Wanted"), 0)
end)

test("cancel clears presentation without refund, reward or mission reset", function()
    local e = setup()
    local p = e.player()
    expect(e.jobs.start(p, e.markers.FastFood), true)
    p:SetAttribute("MissionText", "Preserve esta instrução")
    p:SetAttribute("MissionReward", 650)
    p:SetAttribute("MissionExpiresAt", 999)
    expect(e.jobs.cancel(p, "Cancelado pelo jogador."), true)
    expectClear(e, p)
    expect(p:GetAttribute("StatusText"), "Cancelado pelo jogador.")
    expect(p:GetAttribute("Energy"), 85)
    expect(p:GetAttribute("MissionText"), "Preserve esta instrução")
    expect(p:GetAttribute("MissionReward"), 650)
    expect(p:GetAttribute("MissionExpiresAt"), 999)
    expect(p:GetAttribute("MissionStage"), "None")
    e.tick(118)
    expect(p:GetAttribute("Cash"), 450)
    expect(p:GetAttribute("Reputation"), 29)
    expect(p:GetAttribute("WorkCompletions"), 0)
end)

test("cancellation still prevents payment when the deadline passed between server ticks", function()
    local e = setup()
    local p = e.player()
    expect(e.jobs.start(p, e.markers.FastFood), true)
    e.setTime(119)
    expect(e.jobs.cancel(p), true)
    e.tick(120)
    expect(p:GetAttribute("Cash"), 450)
    expect(p:GetAttribute("Energy"), 85)
end)

test("invalid worker or marker cancels before payment including exactly at the deadline", function()
    local invalid = {
        function(_, p) p.Parent = nil end,
        function(_, p) p.Character = nil end,
        function(e, p) p.Character = e.player().Character end,
        function(_, p) p:SetAttribute("DataReady", false) end,
        function(_, p) p:SetAttribute("DataReady", 1) end,
        function(_, p) p:SetAttribute("InsideHome", true) end,
        function(_, p) p:SetAttribute("MissionStage", "Pickup") end,
        function(_, _, root) root.Position = vector(18.001, 0, 0) end,
        function(_, _, root) root.Position = vector(0 / 0, 0, 0) end,
        function(_, _, root) root.Parent = nil end,
        function(_, _, _, humanoid) humanoid.Health = 0 end,
        function(_, _, _, humanoid) humanoid.Sit = true end,
        function(_, _, _, humanoid) humanoid.SeatPart = {} end,
        function(e) e.markers.FastFood.Parent = nil end,
        function(e) e.markers.FastFood.Parent = e.workspace end,
        function(e) e.markers.FastFood.Name = "Taxi" end,
        function(e) e.city.Parent = nil end,
    }
    for _, invalidate in ipairs(invalid) do
        local e = setup()
        local p, root, humanoid = e.player()
        expect(e.jobs.start(p, e.markers.FastFood), true)
        invalidate(e, p, root, humanoid)
        e.tick(118)
        expectClear(e, p)
        expect(p:GetAttribute("Cash"), 450)
        expect(p:GetAttribute("Energy"), 85)
        expect(p:GetAttribute("Reputation"), 29)
        expect(p:GetAttribute("WorkCompletions"), 0)
    end
end)

test("leaving the work area cancels early and returning cannot revive the shift", function()
    local e = setup()
    local p, root = e.player()
    expect(e.jobs.start(p, e.markers.FastFood), true)
    root.Position = vector(19, 0, 0)
    e.tick(105)
    expectClear(e, p)
    root.Position = vector(0, 0, 0)
    e.tick(118)
    expect(p:GetAttribute("Cash"), 450)
end)

test("a lost ready state can be cancelled safely without payment or blocked cleanup", function()
    local e = setup()
    local p = e.player()
    expect(e.jobs.start(p, e.markers.FastFood), true)
    p:SetAttribute("DataReady", false)
    expect(e.jobs.cancel(p), true)
    expectClear(e, p)
    e.tick(118)
    expect(p:GetAttribute("Cash"), 450)
    p:SetAttribute("DataReady", true)
    expect(e.jobs.start(p, e.markers.FastFood), true)
end)

test("completion cooldown lasts five seconds and rejected starts do not extend it", function()
    local e = setup()
    local p = e.player()
    expect(e.jobs.start(p, e.markers.FastFood), true)
    e.tick(118)
    expect(e.jobs.start(p, e.markers.FastFood), false)
    e.setTime(122.999)
    expect(e.jobs.start(p, e.markers.FastFood), false)
    expect(p:GetAttribute("Energy"), 85)
    e.setTime(123)
    expect(e.jobs.start(p, e.markers.FastFood), true)
    expect(p:GetAttribute("Energy"), 70)
end)

test("cancel cooldown lasts five seconds and repeated cancellation cannot extend it", function()
    local e = setup()
    local p = e.player()
    expect(e.jobs.start(p, e.markers.FastFood), true)
    e.setTime(104)
    expect(e.jobs.cancel(p), true)
    e.setTime(108.999)
    expect(e.jobs.cancel(p), false)
    expect(e.jobs.start(p, e.markers.FastFood), false)
    e.setTime(109)
    expect(e.jobs.start(p, e.markers.FastFood), true)
end)

test("concurrent workers have independent progress, rewards and cooldowns", function()
    local e = setup()
    local a = e.player()
    local b = e.player()
    expect(e.jobs.start(a, e.markers.FastFood), true)
    expect(e.jobs.start(b, e.markers.FastFood), true)
    e.tick(118)
    expect(a:GetAttribute("Cash"), 632)
    expect(b:GetAttribute("Cash"), 632)
    expect(a:GetAttribute("WorkCompletions"), 1)
    expect(b:GetAttribute("WorkCompletions"), 1)
    e.setTime(123)
    expect(e.jobs.start(a, e.markers.FastFood), true)
    expect(e.jobs.start(b, e.markers.Taxi), true)
    expect(e.jobs.cancel(a), true)
    e.tick(143)
    expect(a:GetAttribute("Cash"), 632)
    expect(b:GetAttribute("Cash"), 865)
    expect(b:GetAttribute("WorkCompletions"), 2)
end)

test("street work caps wanted at five and ordinary jobs retain the existing level", function()
    local e = setup()
    local p = e.player()
    p:SetAttribute("Wanted", 4)
    expect(e.jobs.start(p, e.markers.StreetDeal), true)
    e.tick(130)
    expect(p:GetAttribute("Wanted"), 5)
    e.setTime(135)
    expect(e.jobs.start(p, e.markers.FastFood), true)
    e.tick(153)
    expect(p:GetAttribute("Wanted"), 5)
end)

test("remove clears shift and cooldown and later ticks cannot pay a removed worker", function()
    local e = setup()
    local p = e.player()
    expect(e.jobs.start(p, e.markers.FastFood), true)
    e.jobs.remove(p)
    expectClear(e, p)
    e.tick(118)
    expect(p:GetAttribute("Cash"), 450)
    expect(e.jobs.start(p, e.markers.FastFood), true)
    expect(e.jobs.cancel(p), true)
    expect(e.jobs.start(p, e.markers.FastFood), false)
    e.jobs.remove(p)
    expect(e.jobs.start(p, e.markers.FastFood), true)
end)

test("invalid timestamps do not advance or complete work", function()
    local e = setup()
    local p = e.player()
    e.setTime(0 / 0)
    expect(e.jobs.start(p, e.markers.FastFood), false)
    e.setTime(100)
    expect(e.jobs.start(p, e.markers.FastFood), true)
    for _, timestamp in ipairs({ 0 / 0, math.huge, -math.huge, "118" }) do e.jobs.tick(timestamp) end
    e.jobs.tick(nil)
    expect(e.jobs.isActive(p), true)
    expect(p:GetAttribute("Cash"), 450)
    e.tick(118)
    expect(p:GetAttribute("Cash"), 632)
end)

print(string.format("Job checks: %d passed, %d failed", passed, failed))
assert(failed == 0, "Job checks failed")
