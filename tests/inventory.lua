-- These checks exercise server economy and authorization. They do not simulate
-- Roblox replication, UI, physics, or DataStore persistence.
local vectorMeta = {}
local function vector(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vectorMeta) end
vectorMeta.__sub = function(a, b) return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vectorMeta.__index = function(value, key)
    if key == "Magnitude" then return math.sqrt(value.X ^ 2 + value.Y ^ 2 + value.Z ^ 2) end
end

local function setup()
    local methods = {}
    function methods:IsA(name) return self.ClassName == name or (name == "BasePart" and self.ClassName == "Part") end
    function methods:FindFirstChild(name) return self.children[name] end
    function methods:FindFirstChildOfClass(className)
        for _, child in pairs(self.children) do if child.ClassName == className then return child end end
    end
    function methods:GetAttribute(name) return self.attributes[name] end
    function methods:SetAttribute(name, value) self.attributes[name] = value end
    local function object(className)
        return setmetatable({ ClassName = className, children = {}, attributes = {} }, { __index = methods })
    end
    local players, workspace, city, marker = object("Players"), object("Workspace"), object("Model"), object("Part")
    workspace.children.Downtown = city
    city.Parent = workspace
    city.children.SnackShop = marker
    marker.Name, marker.Parent, marker.Position = "SnackShop", city, vector(72, 1, 10)
    local now = 100
    function workspace:GetServerTimeNow() return now end
    local game = { GetService = function(_, name)
        if name == "Players" then return players end
        if name == "Workspace" then return workspace end
        error("Unexpected service: " .. name)
    end }
    local env = { service = makeModule(game), marker = marker, city = city, workspace = workspace, object = object }
    function env.player()
        local player, character, root, humanoid = object("Player"), object("Model"), object("Part"), object("Humanoid")
        player.Parent, player.Character = players, character
        player.attributes = { Cash = 1500, Energy = 40, SnackCount = 0, DataReady = true, InsideHome = false }
        character.children.HumanoidRootPart, character.children.Humanoid = root, humanoid
        root.Position = marker.Position
        humanoid.Health, humanoid.Sit = 100, false
        return player, root, humanoid
    end
    function env.advance(seconds) now += seconds end
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

test("purchase debits exactly 60 and reserves one portable snack without energy gain", function()
    local env = setup()
    local player = env.player()
    expect(env.service.buySnack(player, env.marker), true)
    expect(player:GetAttribute("Cash"), 1440)
    expect(player:GetAttribute("SnackCount"), 1)
    expect(player:GetAttribute("Energy"), 40)
    expect(player:GetAttribute("SnacksPurchased"), 1)
end)

test("use consumes one snack and restores at most 25 energy without charging", function()
    local env = setup()
    local player = env.player()
    player:SetAttribute("SnackCount", 2)
    player:SetAttribute("SnacksPurchased", 7)
    expect(env.service.useSnack(player), true)
    expect(player:GetAttribute("Energy"), 65)
    expect(player:GetAttribute("SnackCount"), 1)
    expect(player:GetAttribute("Cash"), 1500)
    env.advance(2)
    player:SetAttribute("Energy", 92)
    expect(env.service.useSnack(player), true)
    expect(player:GetAttribute("Energy"), 100)
    expect(player:GetAttribute("SnackCount"), 0)
    expect(player:GetAttribute("SnacksPurchased"), 7)
end)

test("full energy and empty inventory do not consume or debit", function()
    local env = setup()
    local player = env.player()
    expect(env.service.useSnack(player), false)
    expect(player:GetAttribute("Energy"), 40)
    env.advance(2)
    player:SetAttribute("Energy", 100)
    player:SetAttribute("SnackCount", 3)
    expect(env.service.useSnack(player), false)
    expect(player:GetAttribute("SnackCount"), 3)
    expect(player:GetAttribute("Cash"), 1500)
end)

test("full inventory and insufficient wallet do not charge or create snacks", function()
    local env = setup()
    local player = env.player()
    player:SetAttribute("SnacksPurchased", 3)
    player:SetAttribute("SnackCount", 5)
    expect(env.service.buySnack(player, env.marker), false)
    expect(player:GetAttribute("Cash"), 1500)
    expect(player:GetAttribute("SnackCount"), 5)
    expect(player:GetAttribute("SnacksPurchased"), 3)
    env.advance(2)
    player:SetAttribute("SnackCount", 0)
    player:SetAttribute("Cash", 59)
    expect(env.service.buySnack(player, env.marker), false)
    expect(player:GetAttribute("Cash"), 59)
    expect(player:GetAttribute("SnackCount"), 0)
    expect(player:GetAttribute("SnacksPurchased"), 3)
    env.advance(2)
    player:SetAttribute("Cash", 60)
    expect(env.service.buySnack(player, env.marker), true)
    expect(player:GetAttribute("Cash"), 0)
    expect(player:GetAttribute("SnacksPurchased"), 4)
end)

test("buy and use share a two-second cooldown, including failed ready attempts", function()
    local env = setup()
    local player = env.player()
    expect(env.service.buySnack(player, env.marker), true)
    expect(env.service.useSnack(player), false)
    env.advance(1.99)
    expect(env.service.buySnack(player, env.marker), false)
    expect(player:GetAttribute("SnacksPurchased"), 1)
    env.advance(0.01)
    expect(env.service.useSnack(player), true)
    env.advance(2)
    expect(env.service.useSnack(player), false)
    expect(env.service.buySnack(player, env.marker), false)
    expect(player:GetAttribute("SnacksPurchased"), 1)
    env.advance(2)
    expect(env.service.buySnack(player, env.marker), true)
    expect(player:GetAttribute("SnacksPurchased"), 2)
end)

test("cooldowns and inventory are independent between players and remove clears state", function()
    local env = setup()
    local first, second = env.player(), env.player()
    expect(env.service.buySnack(first, env.marker), true)
    expect(env.service.buySnack(second, env.marker), true)
    expect(env.service.useSnack(first), false)
    env.service.remove(first)
    expect(env.service.useSnack(first), true)
    expect(env.service.useSnack(second), false)
    expect(first:GetAttribute("SnackCount"), 0)
    expect(second:GetAttribute("SnackCount"), 1)
end)

test("unready, dead, departed and incomplete characters cannot buy or consume", function()
    local invalid = {
        function(player) player:SetAttribute("DataReady", false) end,
        function(player) player.Parent = nil end,
        function(player) player.Character = nil end,
        function(player) player.Character.children.HumanoidRootPart = nil end,
        function(_, root) root.ClassName = "Folder" end,
        function(player) player.Character.children.Humanoid = nil end,
        function(_, _, humanoid) humanoid.Health = 0 end,
        function(_, _, humanoid) humanoid.Health = 0 / 0 end,
    }
    for _, mutate in ipairs(invalid) do
        local env = setup()
        local player, root, humanoid = env.player()
        player:SetAttribute("SnackCount", 1)
        mutate(player, root, humanoid)
        expect(env.service.buySnack(player, env.marker), false)
        expect(env.service.useSnack(player), false)
        expect(player:GetAttribute("Cash"), 1500)
        expect(player:GetAttribute("SnackCount"), 1)
        expect(player:GetAttribute("Energy"), 40)
    end
end)

test("buy rejects distant, invalid-position, home and seated players", function()
    local invalid = {
        function(_, root) root.Position = vector(1000, 1, 10) end,
        function(_, root) root.Position = vector(0 / 0, 1, 10) end,
        function(player) player:SetAttribute("InsideHome", true) end,
        function(_, _, humanoid) humanoid.Sit = true end,
        function(_, _, humanoid) humanoid.SeatPart = {} end,
    }
    for _, mutate in ipairs(invalid) do
        local env = setup()
        local player, root, humanoid = env.player()
        mutate(player, root, humanoid)
        expect(env.service.buySnack(player, env.marker), false)
        expect(player:GetAttribute("Cash"), 1500)
        expect(player:GetAttribute("SnackCount"), 0)
    end
end)

test("purchase requires the exact current shop BasePart in Downtown", function()
    local env = setup()
    local player = env.player()
    local fake = env.object("Part")
    fake.Name, fake.Position = "SnackShop", env.marker.Position
    expect(env.service.buySnack(player, fake), false)
    env.advance(2)
    env.city.children.SnackShop = nil
    expect(env.service.buySnack(player, env.marker), false)
    env.advance(2)
    env.city.children.SnackShop = env.marker
    env.marker.ClassName = "Folder"
    expect(env.service.buySnack(player, env.marker), false)
    env.advance(2)
    env.workspace.children.Downtown = nil
    expect(env.service.buySnack(player, env.marker), false)
    expect(player:GetAttribute("Cash"), 1500)
    expect(player:GetAttribute("SnackCount"), 0)
end)

test("portable snacks can be used seated and in the apartment", function()
    local env = setup()
    local player, root, humanoid = env.player()
    player:SetAttribute("SnackCount", 1)
    player:SetAttribute("InsideHome", true)
    root.Position = vector(600, 120, 0)
    humanoid.Sit, humanoid.SeatPart = true, {}
    expect(env.service.useSnack(player), true)
    expect(player:GetAttribute("Energy"), 65)
    expect(player:GetAttribute("SnackCount"), 0)
end)

test("invalid numeric attributes cannot create money or consume a snack for NaN energy", function()
    local env = setup()
    local player = env.player()
    player:SetAttribute("Cash", 0 / 0)
    expect(env.service.buySnack(player, env.marker), false)
    expect(player:GetAttribute("SnackCount"), 0)
    env.advance(2)
    player:SetAttribute("SnackCount", 1)
    player:SetAttribute("Energy", math.huge)
    expect(env.service.useSnack(player), false)
    expect(player:GetAttribute("SnackCount"), 1)
    for _, value in ipairs({ -10, 3.9, 99999999, math.huge, 0 / 0 }) do
        local purchaseEnv = setup()
        local buyer = purchaseEnv.player()
        buyer:SetAttribute("SnacksPurchased", value)
        expect(purchaseEnv.service.buySnack(buyer, purchaseEnv.marker), true)
        local expected = value == 3.9 and 4 or (value == 99999999 and 10000000 or 1)
        expect(buyer:GetAttribute("SnacksPurchased"), expected)
        expect(buyer:GetAttribute("Cash"), 1440)
    end
end)

print(string.format("Inventory checks: %d passed, %d failed", passed, failed))
assert(failed == 0, "Inventory checks failed")
