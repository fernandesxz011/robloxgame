-- These substitutes test persistence decisions and races, not Roblox networking.
local count = 0
local function expect(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
local function clone(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = clone(item) end
    return copy
end
local function test(name, callback)
    callback()
    count += 1
    print("PASS " .. name)
end

local function environment(studio)
    local env = { now = 1000, records = {}, writes = 0, calls = 0, fail = 0, delay = 0, loseReply = 0 }
    local queue, guid = {}, 0
    local function resume(thread)
        local ok, duration = coroutine.resume(thread)
        assert(ok, duration)
        if coroutine.status(thread) ~= "dead" then
            table.insert(queue, { thread = thread, at = env.now + (duration or 0.01) })
        end
    end
    local function step()
        table.sort(queue, function(a, b) return a.at < b.at end)
        local event = table.remove(queue, 1)
        assert(event, "scheduler stalled")
        env.now = math.max(env.now, event.at)
        resume(event.thread)
    end
    env.task = {
        spawn = function(fn, ...) local args = table.pack(...) local thread = coroutine.create(function() fn(table.unpack(args, 1, args.n)) end) resume(thread) return thread end,
        wait = function(duration) return coroutine.yield(duration or 0.01) end,
    }
    env.os = { clock = function() return env.now end, time = function() return math.floor(env.now) end }
    function env.run(fn)
        local result
        env.task.spawn(function() result = table.pack(fn()) end)
        local steps = 0
        while not result do steps += 1 assert(steps < 20000, "scheduler timeout") step() end
        return table.unpack(result, 1, result.n)
    end
    function env.advance(duration)
        local untilTime = env.now + duration
        while #queue > 0 do
            table.sort(queue, function(a, b) return a.at < b.at end)
            if queue[1].at > untilTime then break end
            step()
        end
        env.now = untilTime
    end
    local dataService = {}
    function dataService:GetDataStore(name)
        env.storeName = name
        local store = {}
        function store:UpdateAsync(key, transform)
            env.calls += 1
            if env.delay > 0 then env.task.wait(env.delay) end
            if env.fail > 0 then env.fail -= 1 error("API unavailable") end
            local fullKey = name .. "/" .. key
            local result = transform(clone(env.records[fullKey]))
            if result ~= nil then
                env.records[fullKey] = clone(result)
                env.writes += 1
                if env.loseReply > 0 then env.loseReply -= 1 error("Reply lost after commit") end
            end
            return clone(result)
        end
        return store
    end
    local services = {
        DataStoreService = dataService,
        HttpService = { GenerateGUID = function() guid += 1 return "session-" .. guid end },
        RunService = { IsStudio = function() return studio end },
    }
    env.game = { GetService = function(_, name) return services[name] end }
    function env.module() return makeModule(env.game, env.task, env.os) end
    function env.player(id)
        local p = { UserId = id or 1, Parent = {}, attrs = {} }
        function p:GetAttribute(name) return self.attrs[name] end
        function p:SetAttribute(name, value) self.attrs[name] = value end
        return p
    end
    function env.key(id) return (studio and "DowntownHustle_PlayerData_Studio_v1" or "DowntownHustle_PlayerData_v1") .. "/Player_" .. (id or 1) end
    return env
end

test("defaults and finite bounded normalization", function()
    local module = environment(false).module()
    local clean = module.sanitize({ Cash = -50, BankBalance = math.huge, Reputation = 8.9, OwnedProperties = 7, MissionCompletions = 0 / 0, Extra = 50 })
    expect(clean.Cash, 0) expect(clean.BankBalance, 0) expect(clean.Reputation, 8)
    expect(clean.OwnedProperties, 1) expect(clean.MissionCompletions, 0) expect(clean.Extra, nil)
    expect(module.sanitize(nil).Cash, 1500)
    expect(module.sanitize(nil).SnackCount, 0) expect(module.sanitize(nil).WorkCompletions, 0)
    local added = module.sanitize({ SnackCount = 99, WorkCompletions = math.huge })
    expect(added.SnackCount, 5) expect(added.WorkCompletions, 0)
    expect(added.SnacksPurchased, 5)
    expect(module.sanitize({ SnackCount = 3, SnacksPurchased = 0 }).SnacksPurchased, 0)
    expect(module.sanitize({ SnackCount = -1, WorkCompletions = 9.7 }).SnackCount, 0)
    expect(module.sanitize({ WorkCompletions = 9.7 }).WorkCompletions, 9)
    expect(module.sanitize(nil).ObjectiveClaims, 0) expect(module.sanitize(nil).SnacksPurchased, 0)
    local objectives = module.sanitize({ ObjectiveClaims = 99, SnacksPurchased = 99999999 })
    expect(objectives.ObjectiveClaims, 7) expect(objectives.SnacksPurchased, 10000000)
    objectives = module.sanitize({ ObjectiveClaims = -1, SnacksPurchased = 4.9 })
    expect(objectives.ObjectiveClaims, 0) expect(objectives.SnacksPurchased, 4)
    objectives = module.sanitize({ ObjectiveClaims = 3.7, SnacksPurchased = -20 })
    expect(objectives.ObjectiveClaims, 3) expect(objectives.SnacksPurchased, 0)
    objectives = module.sanitize({ ObjectiveClaims = 0 / 0, SnacksPurchased = math.huge })
    expect(objectives.ObjectiveClaims, 0) expect(objectives.SnacksPurchased, 0)
end)

test("load save release and rejoin restore only persistent attributes", function()
    local env = environment(false)
    local module, player = env.module(), env.player()
    expect(env.run(function() return module.load(player) end), true)
    expect(player:GetAttribute("DataReady"), true) expect(player:GetAttribute("Cash"), 1500)
    player:SetAttribute("Cash", 4321) player:SetAttribute("BankBalance", 800)
    player:SetAttribute("OwnedProperties", 1) player:SetAttribute("MissionCompletions", 6)
    player:SetAttribute("MissionStage", "Deliver") player:SetAttribute("Wanted", 5)
    player:SetAttribute("SnackCount", 3) player:SetAttribute("WorkCompletions", 12)
    player:SetAttribute("ObjectiveClaims", 4) player:SetAttribute("SnacksPurchased", 9)
    player:SetAttribute("WorkActive", true) player:SetAttribute("WorkEndsAt", 9999)
    expect(env.run(function() return module.save(player, true) end), true)
    expect(env.records[env.key()].session, nil)
    expect(env.records[env.key()].data.MissionStage, nil) expect(env.records[env.key()].data.Wanted, nil)
    expect(env.records[env.key()].data.WorkActive, nil) expect(env.records[env.key()].data.WorkEndsAt, nil)
    local again = env.player()
    expect(env.run(function() return module.load(again) end), true)
    expect(again:GetAttribute("Cash"), 4321) expect(again:GetAttribute("BankBalance"), 800)
    expect(again:GetAttribute("PassiveIncome"), 75) expect(again:GetAttribute("MissionCompletions"), 6)
    expect(again:GetAttribute("SnackCount"), 3) expect(again:GetAttribute("WorkCompletions"), 12)
    expect(again:GetAttribute("ObjectiveClaims"), 4) expect(again:GetAttribute("SnacksPurchased"), 9)
end)

test("existing schema one profiles gain inventory, work and objective defaults without losing progress", function()
    local env = environment(false)
    env.records[env.key()] = { schema = 1, data = {
        Cash = 7654, BankBalance = 987, Reputation = 31, OwnedProperties = 1, MissionCompletions = 8,
    } }
    local module, player = env.module(), env.player()
    expect(env.run(function() return module.load(player) end), true)
    expect(player:GetAttribute("Cash"), 7654) expect(player:GetAttribute("BankBalance"), 987)
    expect(player:GetAttribute("SnackCount"), 0) expect(player:GetAttribute("WorkCompletions"), 0)
    expect(player:GetAttribute("ObjectiveClaims"), 0) expect(player:GetAttribute("SnacksPurchased"), 0)
    expect(player:GetAttribute("OwnedProperties"), 1) expect(player:GetAttribute("MissionCompletions"), 8)
    expect(env.run(function() return module.save(player, true) end), true)
    expect(env.records[env.key()].data.Cash, 7654)
    expect(env.records[env.key()].data.SnackCount, 0)
    expect(env.records[env.key()].data.ObjectiveClaims, 0) expect(env.records[env.key()].data.SnacksPurchased, 0)
    env.records[env.key(2)] = { schema = 1, data = { Cash = 2468, SnackCount = 3 } }
    local snackOwner = env.player(2)
    expect(env.run(function() return module.load(snackOwner) end), true)
    expect(snackOwner:GetAttribute("SnackCount"), 3) expect(snackOwner:GetAttribute("SnacksPurchased"), 3)
    snackOwner:SetAttribute("SnackCount", 0) -- Consumption must not erase migrated purchase history.
    expect(env.run(function() return module.save(snackOwner, true) end), true)
    local returningOwner = env.player(2)
    expect(env.run(function() return module.load(returningOwner) end), true)
    expect(returningOwner:GetAttribute("SnackCount"), 0) expect(returningOwner:GetAttribute("SnacksPurchased"), 3)
    expect(returningOwner:GetAttribute("Cash"), 2468)
end)

test("production failed load never writes defaults later", function()
    local env = environment(false)
    local module, player = env.module(), env.player()
    env.fail = 3
    expect(env.run(function() return module.load(player) end), false)
    expect(player:GetAttribute("DataReady"), false)
    env.fail = 0
    expect(env.run(function() return module.save(player, true) end), false)
    expect(env.writes, 0)
end)

test("Studio fallback remains session-only after API recovery", function()
    local env = environment(true)
    local module, player = env.module(), env.player()
    env.fail = 3
    expect(env.run(function() return module.load(player) end), true)
    expect(player:GetAttribute("SaveState"), "SessionOnly")
    expect(env.storeName, "DowntownHustle_PlayerData_Studio_v1")
    local requests = env.calls
    env.fail = 0 player:SetAttribute("Cash", 9999)
    expect(env.run(function() return module.save(player, false) end), true)
    expect(env.run(function() return module.save(player, true) end), true)
    expect(env.calls, requests) expect(env.writes, 0)
end)

test("live foreign session and incompatible schema stay untouched", function()
    for _, studio in ipairs({ false, true }) do
        local env = environment(studio)
        local module, owner = env.module(), env.player()
        expect(env.run(function() return module.load(owner) end), true)
        local writes = env.writes
        local other = env.module()
        expect(env.run(function() return other.load(env.player()) end), false)
        expect(env.writes, writes)
        env.records[env.key(2)] = { schema = 99, data = { Cash = 555 } }
        expect(env.run(function() return other.load(env.player(2)) end), false)
        expect(env.records[env.key(2)].data.Cash, 555) expect(env.writes, writes)
    end
end)

test("expired lease can be acquired and former owner cannot overwrite it", function()
    local env = environment(false)
    local old, player = env.module(), env.player()
    expect(env.run(function() return old.load(player) end), true)
    env.advance(181)
    local newer, nextPlayer = env.module(), env.player()
    expect(env.run(function() return newer.load(nextPlayer) end), true)
    local writes = env.writes
    player:SetAttribute("Cash", 99999)
    expect(env.run(function() return old.save(player, false) end), false)
    expect(player:GetAttribute("DataReady"), false) expect(env.writes, writes)
    expect(env.records[env.key()].data.Cash, 1500)
end)

test("lease renewal and periodic check stop expired gameplay", function()
    local env = environment(false)
    local module, player = env.module(), env.player()
    env.run(function() return module.load(player) end)
    env.advance(60)
    expect(env.run(function() return module.save(player, false) end), true)
    expect(env.records[env.key()].session.expiresAt, 1240)
    env.advance(179) expect(module.check(player), true)
    env.advance(1) expect(module.check(player), false)
end)

test("temporary save failure preserves lease and retries current snapshot", function()
    local env = environment(false)
    local module, player = env.module(), env.player()
    env.run(function() return module.load(player) end)
    env.fail = 3 player:SetAttribute("Cash", 1700)
    expect(env.run(function() return module.save(player, false) end), false)
    expect(player:GetAttribute("SaveState"), "Retrying") expect(player:GetAttribute("DataReady"), true)
    player:SetAttribute("Cash", 1900)
    expect(env.run(function() return module.save(player, false) end), true)
    expect(env.records[env.key()].data.Cash, 1900)
end)

test("release after committed response loss is idempotent", function()
    local env = environment(false)
    local module, player = env.module(), env.player()
    env.run(function() return module.load(player) end)
    player:SetAttribute("Cash", 2300) env.loseReply = 1
    expect(env.run(function() return module.save(player, true) end), true)
    expect(env.records[env.key()].session, nil) expect(env.records[env.key()].data.Cash, 2300)
    expect(env.writes, 2)
end)

test("leaving during load never applies or saves starting money", function()
    local env = environment(false)
    local module, player = env.module(), env.player()
    env.delay = 2
    local loaded = env.run(function()
        env.task.spawn(function()
            env.task.wait(0.1) player.Parent = nil module.save(player, true)
        end)
        return module.load(player)
    end)
    expect(loaded, false) expect(env.writes, 0) expect(player:GetAttribute("DataReady"), false)
    env.advance(3)
    expect(env.writes, 0)
end)

test("release waits for ongoing save and snapshots the latest balance", function()
    local env = environment(false)
    local module, player = env.module(), env.player()
    env.run(function() return module.load(player) end)
    env.delay = 2 player:SetAttribute("Cash", 1700)
    local released = env.run(function()
        env.task.spawn(function() module.save(player, false) end)
        env.task.wait(0.1) player:SetAttribute("Cash", 2100)
        return module.save(player, true)
    end)
    expect(released, true) expect(env.records[env.key()].data.Cash, 2100)
    expect(env.records[env.key()].session, nil)
end)

test("closing refuses new loads and releases existing owner", function()
    local env = environment(false)
    local module, player = env.module(), env.player()
    env.run(function() return module.load(player) end)
    module.close()
    expect(env.run(function() return module.load(env.player(2)) end), false)
    expect(env.run(function() return module.save(player, true) end), true)
    expect(env.records[env.key()].session, nil)
end)

test("pending renewal pauses at lease expiry and resumes after confirmation", function()
    local env = environment(false)
    local module, player = env.module(), env.player()
    env.run(function() return module.load(player) end)
    env.advance(178)
    env.delay, env.loseReply = 0.75, 1
    player:SetAttribute("Cash", 1700)
    local checked = false
    expect(env.run(function()
        env.task.spawn(function()
            env.task.wait(0.25)
            player:SetAttribute("Cash", 2100)
            env.task.wait(1.75)
            expect(module.check(player), false)
            expect(player:GetAttribute("DataReady"), false)
            expect(player:GetAttribute("SaveState"), "Retrying")
            checked = true
        end)
        return module.save(player, false)
    end), true)
    expect(checked, true)
    expect(player:GetAttribute("DataReady"), true)
    expect(player:GetAttribute("SaveState"), "Saved")
    expect(module.check(player), true)
    expect(env.run(function() return module.save(player, true) end), true)
    expect(env.records[env.key()].data.Cash, 2100)
    expect(env.records[env.key()].session, nil)
end)

test("shutdown final write keeps its budget after waiting for slow autosave", function()
    local env = environment(false)
    local module, player = env.module(), env.player()
    env.run(function() return module.load(player) end)
    env.delay = 15
    player:SetAttribute("Cash", 1700)
    expect(env.run(function()
        env.task.spawn(function() module.save(player, false) end)
        env.task.wait(0.1)
        player:SetAttribute("Cash", 2100)
        env.delay = 7
        module.close()
        return module.save(player, true)
    end), true)
    expect(env.now < 1024.1, true)
    expect(env.records[env.key()].data.Cash, 2100)
    expect(env.records[env.key()].session, nil)
end)

test("unconfirmed renewal keeps gameplay blocked when the request fails", function()
    local env = environment(false)
    local module, player = env.module(), env.player()
    env.run(function() return module.load(player) end)
    env.advance(178)
    env.delay, env.fail = 1, 3
    expect(env.run(function()
        env.task.spawn(function()
            env.task.wait(2)
            expect(module.check(player), false)
            expect(player:GetAttribute("DataReady"), false)
        end)
        return module.save(player, false)
    end), false)
    expect(player:GetAttribute("SaveState"), "Unavailable")
    expect(player:GetAttribute("DataReady"), false)
end)

test("PlayerRemoving and shutdown share a single final save without cancelling it", function()
    local env = environment(false)
    local module, player = env.module(), env.player()
    env.run(function() return module.load(player) end)
    env.delay = 15
    player:SetAttribute("Cash", 1700)
    local firstRelease
    local shutdownRelease = env.run(function()
        env.task.spawn(function() module.save(player, false) end)
        env.task.wait(0.1)
        player:SetAttribute("Cash", 2100)
        env.delay = 7
        env.task.spawn(function() firstRelease = module.save(player, true) end)
        env.task.wait(0.1)
        module.close()
        return module.save(player, true)
    end)
    expect(firstRelease, true)
    expect(shutdownRelease, true)
    expect(env.now < 1024.2, true)
    expect(env.records[env.key()].data.Cash, 2100)
    expect(env.records[env.key()].session, nil)
    expect(env.writes, 3) -- initial load, autosave, one final save
end)

print(string.format("%d/%d persistence checks passed (mock DataStore and scheduler).", count, count))
