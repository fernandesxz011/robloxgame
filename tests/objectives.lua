-- Mocks dispatch changed attributes immediately to exercise callback reentry too.
local function setup()
    local registry, methods = {}, {}
    local instanceMeta = { __index = methods }
    local function instance(className, name, parent)
        local object = setmetatable({ ClassName = className, Name = name, Parent = parent, attributes = {}, signals = {} }, instanceMeta)
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
    function methods:GetAttribute(name) return self.attributes[name] end
    function methods:GetAttributeChangedSignal(name)
        if not self.signals[name] then
            local signal = { connections = {} }
            function signal:Connect(callback)
                local connection = { Connected = true, callback = callback }
                function connection:Disconnect() self.Connected = false end
                table.insert(self.connections, connection)
                return connection
            end
            self.signals[name] = signal
        end
        return self.signals[name]
    end
    function methods:SetAttribute(name, value)
        if self.attributes[name] == value then return end
        self.attributes[name] = value
        local signal = self.signals[name]
        if signal then
            for _, connection in ipairs(signal.connections) do
                if connection.Connected then connection.callback() end
            end
        end
    end
    local players = instance("Players", "Players")
    local game = { GetService = function(_, name)
        assert(name == "Players", "Unexpected service " .. name)
        return players
    end }
    local service = makeModule(game, function(value)
        return type(value) == "table" and getmetatable(value) == instanceMeta and "Instance" or type(value)
    end)
    local e = { service = service, players = players, instance = instance }
    function e.player()
        local player = instance("Player", "Citizen", players)
        for name, value in pairs({
            DataReady = true, Cash = 1500, ObjectiveClaims = 0, WorkCompletions = 0,
            SnacksPurchased = 0, SnackCount = 0, MissionCompletions = 0, BankBalance = 0,
            OwnedProperties = 0, Reputation = 11, Energy = 100,
        }) do player:SetAttribute(name, value) end
        local character = instance("Model", "Character")
        local root = instance("Part", "HumanoidRootPart", character)
        local humanoid = instance("Humanoid", "Humanoid", character)
        humanoid.Health = 100
        player.Character = character
        return player, root, humanoid
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

test("first objective presents progress without paying automatically", function()
    local e = setup()
    local p = e.player()
    e.service.trackPlayer(p)
    expect(p:GetAttribute("ObjectiveId"), "first_shift")
    expect(p:GetAttribute("ObjectiveNumber"), 1)
    expect(p:GetAttribute("ObjectiveTotal"), 7)
    expect(p:GetAttribute("ObjectiveTarget"), 1)
    expect(p:GetAttribute("ObjectiveProgress"), 0)
    expect(p:GetAttribute("ObjectiveReward"), 100)
    expect(p:GetAttribute("ObjectiveMarkerName"), "FastFood")
    expect(p:GetAttribute("ObjectiveReady"), false)
    p:SetAttribute("WorkCompletions", 1)
    expect(p:GetAttribute("ObjectiveProgress"), 1)
    expect(p:GetAttribute("ObjectiveReady"), true)
    expect(p:GetAttribute("Cash"), 1500)
    expect(p:GetAttribute("ObjectiveClaims"), 0)
end)

test("claim pays exactly once and requires the current objective ID", function()
    local e = setup()
    local p = e.player()
    e.service.trackPlayer(p)
    p:SetAttribute("WorkCompletions", 10)
    p:SetAttribute("SnacksPurchased", 1)
    expect(e.service.claim(p, "packed_snack"), false)
    expect(e.service.claim(p, "first_shift"), true)
    expect(e.service.claim(p, "first_shift"), false)
    expect(p:GetAttribute("Cash"), 1600)
    expect(p:GetAttribute("ObjectiveClaims"), 1)
    expect(p:GetAttribute("ObjectiveId"), "packed_snack")
    expect(p:GetAttribute("ObjectiveReady"), true)
    expect(p:GetAttribute("Reputation"), 11)
    expect(p:GetAttribute("Energy"), 100)
end)

test("incomplete objectives cannot be claimed using forged presentation attributes", function()
    local e = setup()
    local p = e.player()
    p:SetAttribute("ObjectiveReady", true)
    p:SetAttribute("ObjectiveProgress", 999)
    p:SetAttribute("ObjectiveReward", 9000000)
    expect(e.service.claim(p, "first_shift"), false)
    p:SetAttribute("WorkCompletions", 1)
    expect(e.service.claim(p, "first_shift"), true)
    expect(p:GetAttribute("Cash"), 1600)
end)

test("an existing snack counts for older profiles and is never consumed by a claim", function()
    local e = setup()
    local p = e.player()
    p:SetAttribute("ObjectiveClaims", 1)
    p:SetAttribute("SnacksPurchased", nil)
    e.service.trackPlayer(p)
    expect(p:GetAttribute("ObjectiveReady"), false)
    p:SetAttribute("SnackCount", 2)
    expect(p:GetAttribute("ObjectiveProgress"), 1)
    expect(e.service.claim(p, "packed_snack"), true)
    expect(p:GetAttribute("SnackCount"), 2)
    expect(p:GetAttribute("Cash"), 1575)
end)

test("purchase history remains sufficient after eating the last snack", function()
    local e = setup()
    local p = e.player()
    p:SetAttribute("ObjectiveClaims", 1)
    e.service.trackPlayer(p)
    p:SetAttribute("SnacksPurchased", 1)
    expect(p:GetAttribute("ObjectiveReady"), true)
    expect(e.service.claim(p, "packed_snack"), true)
end)

test("retroactive progress completes the whole fixed sequence with exact rewards", function()
    local e = setup()
    local p = e.player()
    p:SetAttribute("WorkCompletions", 8)
    p:SetAttribute("SnacksPurchased", 4)
    p:SetAttribute("MissionCompletions", 4)
    p:SetAttribute("BankBalance", 1000)
    p:SetAttribute("OwnedProperties", 1)
    e.service.trackPlayer(p)
    for index, config in ipairs({
        { "first_shift", 100, "FastFood", 1 }, { "packed_snack", 75, "SnackShop", 1 },
        { "first_delivery", 150, "MainMission", 1 }, { "bank_reserve", 125, "BankMarker", 500 },
        { "first_home", 200, "HouseOffer", 1 }, { "steady_work", 250, "FastFood", 5 },
        { "city_courier", 300, "MainMission", 3 },
    }) do
        expect(p:GetAttribute("ObjectiveNumber"), index)
        expect(p:GetAttribute("ObjectiveId"), config[1])
        expect(p:GetAttribute("ObjectiveReward"), config[2])
        expect(p:GetAttribute("ObjectiveMarkerName"), config[3])
        expect(p:GetAttribute("ObjectiveProgress"), config[4])
        expect(p:GetAttribute("ObjectiveTarget"), config[4])
        expect(p:GetAttribute("ObjectiveReady"), true)
        expect(e.service.claim(p, config[1]), true)
    end
    expect(p:GetAttribute("Cash"), 2700)
    expect(p:GetAttribute("ObjectiveClaims"), 7)
    expect(p:GetAttribute("ObjectivesFinished"), true)
    expect(p:GetAttribute("ObjectiveNumber"), 7)
    expect(p:GetAttribute("ObjectiveId"), "")
    expect(p:GetAttribute("ObjectiveMarkerName"), "")
    expect(p:GetAttribute("ObjectiveReward"), 0)
    expect(p:GetAttribute("ObjectiveProgress"), 0)
    expect(p:GetAttribute("ObjectiveTarget"), 0)
    expect(p:GetAttribute("ObjectiveReady"), false)
    expect(p:GetAttribute("ObjectiveTitle"), "Primeiros passos concluídos")
    expect(e.service.claim(p, "city_courier"), false)
    expect(e.service.claim(p, ""), false)
end)

test("withdrawing bank money before claiming invalidates the bank objective", function()
    local e = setup()
    local p = e.player()
    p:SetAttribute("ObjectiveClaims", 3)
    p:SetAttribute("BankBalance", 500)
    e.service.trackPlayer(p)
    expect(p:GetAttribute("ObjectiveReady"), true)
    p:SetAttribute("BankBalance", 499)
    expect(p:GetAttribute("ObjectiveReady"), false)
    expect(p:GetAttribute("ObjectiveProgress"), 499)
    expect(e.service.claim(p, "bank_reserve"), false)
    p:SetAttribute("BankBalance", 500)
    expect(e.service.claim(p, "bank_reserve"), true)
    expect(p:GetAttribute("BankBalance"), 500)
end)

test("readiness must be exactly true and loading cannot pay", function()
    for _, ready in ipairs({ false, 0, 1, "true" }) do
        local e = setup()
        local p = e.player()
        p:SetAttribute("WorkCompletions", 1)
        e.service.trackPlayer(p)
        p:SetAttribute("DataReady", ready)
        expect(p:GetAttribute("ObjectiveReady"), false)
        expect(e.service.claim(p, "first_shift"), false)
        expect(p:GetAttribute("Cash"), 1500)
        p:SetAttribute("DataReady", true)
        expect(p:GetAttribute("ObjectiveReady"), true)
    end
end)

test("dead or missing characters and non-parts cannot claim", function()
    for _, invalid in ipairs({ "dead", "noCharacter", "noRoot", "fakeRoot", "noHumanoid" }) do
        local e = setup()
        local p, root, humanoid = e.player()
        p:SetAttribute("WorkCompletions", 1)
        if invalid == "dead" then humanoid.Health = 0 end
        if invalid == "noCharacter" then p.Character = nil end
        if invalid == "noRoot" then root.Parent = nil end
        if invalid == "fakeRoot" then root.ClassName = "Folder" end
        if invalid == "noHumanoid" then humanoid.Parent = nil end
        expect(e.service.claim(p, "first_shift"), false)
        expect(p:GetAttribute("Cash"), 1500)
    end
end)

test("invalid payloads and players are rejected", function()
    local e = setup()
    local p = e.player()
    p:SetAttribute("WorkCompletions", 1)
    for _, payload in ipairs({ 1, true, {}, "FIRST_SHIFT", "", "first_shift ", "first_shift\0" }) do
        expect(e.service.claim(p, payload), false)
    end
    expect(e.service.claim(p, nil), false)
    expect(e.service.claim(nil, "first_shift"), false)
    expect(e.service.claim({}, "first_shift"), false)
    p.Parent = nil
    expect(e.service.claim(p, "first_shift"), false)
    p.Parent = e.players
    p.ClassName = "Folder"
    expect(e.service.claim(p, "first_shift"), false)
end)

test("cash cap refuses payment without consuming the objective", function()
    local e = setup()
    local p = e.player()
    p:SetAttribute("WorkCompletions", 1)
    p:SetAttribute("Cash", 2000000000 - 99)
    expect(e.service.claim(p, "first_shift"), false)
    expect(p:GetAttribute("ObjectiveClaims"), 0)
    expect(p:GetAttribute("Cash"), 2000000000 - 99)
    assert(#p:GetAttribute("StatusText") > 0)
    p:SetAttribute("Cash", 2000000000 - 100)
    expect(e.service.claim(p, "first_shift"), true)
    expect(p:GetAttribute("Cash"), 2000000000)
end)

test("invalid balances cannot be used to claim", function()
    for _, balance in ipairs({ -1, 10.5, math.huge, -math.huge, 0 / 0, "1500" }) do
        local e = setup()
        local p = e.player()
        p:SetAttribute("WorkCompletions", 1)
        p:SetAttribute("Cash", balance)
        expect(e.service.claim(p, "first_shift"), false)
        expect(p:GetAttribute("ObjectiveClaims"), 0)
    end
end)

test("progress uses bounded finite whole numbers", function()
    local e = setup()
    local p = e.player()
    p:SetAttribute("ObjectiveClaims", 5)
    e.service.trackPlayer(p)
    for _, value in ipairs({ -3, math.huge, -math.huge, 0 / 0, "5" }) do
        p:SetAttribute("WorkCompletions", value)
        expect(p:GetAttribute("ObjectiveProgress"), 0)
        expect(p:GetAttribute("ObjectiveReady"), false)
    end
    p:SetAttribute("WorkCompletions", 3.8)
    expect(p:GetAttribute("ObjectiveProgress"), 3)
    p:SetAttribute("WorkCompletions", 9000)
    expect(p:GetAttribute("ObjectiveProgress"), 5)
end)

test("cleanup disconnects every listener and is safe to call twice", function()
    local e = setup()
    local p = e.player()
    local cleanup = e.service.trackPlayer(p)
    local connected = 0
    for _, signal in pairs(p.signals) do
        for _, connection in ipairs(signal.connections) do
            if connection.Connected then connected += 1 end
        end
    end
    expect(connected, 8)
    cleanup()
    cleanup()
    for _, signal in pairs(p.signals) do
        for _, connection in ipairs(signal.connections) do expect(connection.Connected, false) end
    end
    p:SetAttribute("WorkCompletions", 1)
    expect(p:GetAttribute("ObjectiveProgress"), 0)
    local nextCleanup = e.service.trackPlayer(p)
    expect(p:GetAttribute("ObjectiveProgress"), 1)
    nextCleanup()
end)

test("each player progresses and receives rewards independently", function()
    local e = setup()
    local a = e.player()
    local b = e.player()
    e.service.trackPlayer(a)
    e.service.trackPlayer(b)
    a:SetAttribute("WorkCompletions", 1)
    expect(e.service.claim(a, "first_shift"), true)
    expect(e.service.claim(b, "first_shift"), false)
    expect(b:GetAttribute("ObjectiveId"), "first_shift")
    expect(b:GetAttribute("Cash"), 1500)
    b:SetAttribute("WorkCompletions", 1)
    expect(e.service.claim(b, "first_shift"), true)
    expect(a:GetAttribute("Cash"), 1600)
    expect(b:GetAttribute("Cash"), 1600)
end)

test("attribute callbacks cannot reenter and claim the next ready objective", function()
    local e = setup()
    local p = e.player()
    p:SetAttribute("WorkCompletions", 1)
    p:SetAttribute("SnacksPurchased", 1)
    local nestedResult
    p:GetAttributeChangedSignal("ObjectiveClaims"):Connect(function()
        nestedResult = e.service.claim(p, "packed_snack")
    end)
    expect(e.service.claim(p, "first_shift"), true)
    expect(nestedResult, false)
    expect(p:GetAttribute("Cash"), 1600)
    expect(p:GetAttribute("ObjectiveClaims"), 1)
end)

test("persisted completion and missing legacy claim counter refresh correctly", function()
    local e = setup()
    local p = e.player()
    p:SetAttribute("ObjectiveClaims", nil)
    e.service.trackPlayer(p)
    expect(p:GetAttribute("ObjectiveId"), "first_shift")
    p:SetAttribute("ObjectiveClaims", 7)
    expect(p:GetAttribute("ObjectivesFinished"), true)
    expect(p:GetAttribute("ObjectiveNumber"), 7)
    expect(e.service.claim(p, "first_shift"), false)
    expect(p:GetAttribute("Cash"), 1500)
end)

print(string.format("Objective checks: %d passed, %d failed", passed, failed))
assert(failed == 0, "Objective checks failed")
