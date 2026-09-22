local passed, failed = 0, 0
local function expect(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function near(actual, expected)
    assert(math.abs(actual - expected) < 1e-6, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, callback)
    local ok, message = pcall(callback)
    if ok then passed += 1 print("PASS " .. name)
    else failed += 1 print("FAIL " .. name .. ": " .. tostring(message)) end
end

test("metric conversion uses standard Roblox scale and preserves signed velocity", function()
    near(VehicleUnits.studsPerSecondToKmh(100), 100.8)
    near(VehicleUnits.kmhToStudsPerSecond(36), 10 / 0.28)
    near(VehicleUnits.studsPerSecondToKmh(VehicleUnits.kmhToStudsPerSecond(-72)), -72)
    near(VehicleUnits.studsPerSecondToKmh(0), 0)
end)

test("catalog has unique models and plates; every fleet placement builds a welded server-owned car", function()
    local ids, plates = {}, {}
    for _, spec in ipairs(Catalog.models) do
        expect(ids[spec.id], nil)
        ids[spec.id] = true
        assert(spec.speedKmh > spec.reverseSpeedKmh and spec.reverseSpeedKmh > 0
            and spec.accelerationKmhPerSecond > 0 and spec.brakeKmhPerSecond > 0 and spec.turnRate > 0)
    end
    for _, placement in ipairs(Catalog.fleet) do
        assert(ids[placement.id])
        expect(plates[placement.plate], nil)
        plates[placement.plate] = true
    end
    local e = setup(true)
    expect(#e.fleet:GetChildren(), #Catalog.fleet)
    for _, model in ipairs(e.fleet:GetChildren()) do
        local chassis = model.PrimaryPart
        local specification = Catalog.get(model:GetAttribute("VehicleId"))
        near(model:GetAttribute("MaxSpeedKmh"), specification.speedKmh)
        near(model:GetAttribute("ReverseSpeedKmh"), specification.reverseSpeedKmh)
        expect(chassis.ownerAssigned, true)
        expect(chassis.owner, nil)
        local tires = 0
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                expect(part.Anchored, false)
                if part ~= chassis then
                    expect(part.Massless, true)
                    local weld = assert(part:FindFirstChildOfClass("WeldConstraint"))
                    expect(weld.Part0, chassis)
                    expect(weld.Part1, part)
                end
                if part.Name == "Tire" then tires += 1 expect(part.CanCollide, true) end
            end
        end
        expect(tires, 4)
    end
    e.cleanup()
end)

test("entry rejects unready, disconnected, distant, nonfinite, dead, seated and detached characters", function()
    local invalid = {
        function(p) p:SetAttribute("DataReady", false) end,
        function(p) p.Parent = nil end,
        function(_, root) root.Position = vector(1000, 0, 0) end,
        function(_, root) root.Position = vector(0 / 0, 0, 0) end,
        function(_, root) root.Position = vector(math.huge, 0, 0) end,
        function(_, _, humanoid) humanoid.Health = 0 end,
        function(_, _, humanoid) humanoid.Sit = true end,
        function(_, _, humanoid) humanoid.SeatPart = {} end,
        function(p) p.Character.Parent = nil end,
    }
    for _, invalidate in ipairs(invalid) do
        local e = setup()
        local p, root, humanoid = e.player()
        invalidate(p, root, humanoid)
        e.enter(p)
        expect(e.seat.Occupant, nil)
        e.cleanup()
    end
end)

test("seat admits a nearby player, rejects a second driver and resets controls on exit", function()
    local e = setup()
    local p, _, humanoid = e.player()
    local second = e.player()
    e.enter(p)
    expect(e.seat.Occupant, humanoid)
    expect(e.prompt.Enabled, false)
    e.enter(second)
    expect(e.seat.Occupant, humanoid)
    e.input(p, 1, 1)
    e.step()
    assert(e.drive.PlaneVelocity.X > 0)
    local direction = e.align.CFrame.RightVector
    e.leave()
    expect(e.prompt.Enabled, true)
    e.enter(second)
    e.step()
    near(e.drive.PlaneVelocity.X, 0)
    near(e.align.CFrame.RightVector.Z, direction.Z)
    e.cleanup()
end)

test("input requires the actual live driver and ignores invalid numbers", function()
    local e = setup()
    local p = e.player()
    local stranger = e.player()
    e.enter(p)
    for _, value in ipairs({ "1", {}, math.huge, -math.huge, 0 / 0 }) do
        e.input(p, value, 0)
        e.input(p, 1, value)
    end
    e.input(stranger, 1, 1)
    e.step()
    near(e.drive.PlaneVelocity.X, 0)
    p:SetAttribute("DataReady", false)
    e.input(p, 1, 0)
    e.step()
    near(e.drive.PlaneVelocity.X, 0)
    p:SetAttribute("DataReady", true)
    e.input(p, 1, 0)
    e.step()
    near(VehicleUnits.studsPerSecondToKmh(e.drive.PlaneVelocity.X), e.specification.accelerationKmhPerSecond * 0.1)
    e.cleanup()
end)

test("input clamps speed, rate limits repeated packets and brakes on timeout", function()
    local e = setup()
    local p = e.player()
    e.enter(p)
    e.input(p, 100, 0)
    e.input(p, -1, 1)
    e.step()
    assert(e.drive.PlaneVelocity.X > 0)
    for _ = 1, 150 do e.input(p, 100, 0) e.step() end
    near(VehicleUnits.studsPerSecondToKmh(e.drive.PlaneVelocity.X), e.specification.speedKmh)
    for _ = 1, 60 do e.step() end
    near(e.drive.PlaneVelocity.X, 0)
    e.cleanup()
end)

test("metric acceleration, partial throttle and braking use the configured rates", function()
    local e = setup(false, { speedKmh = 100, accelerationKmhPerSecond = 20, brakeKmhPerSecond = 40 })
    local p = e.player()
    e.enter(p)
    for _ = 1, 10 do e.input(p, 1, 0) e.step() end
    near(VehicleUnits.studsPerSecondToKmh(e.drive.PlaneVelocity.X), 20)
    for _ = 1, 20 do e.input(p, 0.25, 0) e.step() end
    near(VehicleUnits.studsPerSecondToKmh(e.drive.PlaneVelocity.X), 25)
    e.input(p, 0.1, 0)
    e.step()
    near(VehicleUnits.studsPerSecondToKmh(e.drive.PlaneVelocity.X), 21)
    for _ = 1, 10 do e.input(p, 0.1, 0) e.step() end
    near(VehicleUnits.studsPerSecondToKmh(e.drive.PlaneVelocity.X), 10)
    e.input(p, 0, 0)
    e.step()
    near(VehicleUnits.studsPerSecondToKmh(e.drive.PlaneVelocity.X), 6)
    e.cleanup()
end)

test("changing direction brakes to zero before reverse acceleration and respects the reverse cap", function()
    local e = setup(false, { speedKmh = 100, reverseSpeedKmh = 18, accelerationKmhPerSecond = 20, brakeKmhPerSecond = 36 })
    local p = e.player()
    e.enter(p)
    for _ = 1, 10 do e.input(p, 1, 0) e.step() end
    local stopped = false
    for _ = 1, 20 do
        e.input(p, -1, 0)
        e.step()
        local speed = VehicleUnits.studsPerSecondToKmh(e.drive.PlaneVelocity.X)
        assert(speed >= 0, "reverse engaged before reaching a complete stop")
        if speed == 0 then stopped = true break end
    end
    expect(stopped, true)
    e.input(p, -1, 0)
    e.step()
    near(VehicleUnits.studsPerSecondToKmh(e.drive.PlaneVelocity.X), -2)
    for _ = 1, 40 do e.input(p, -1, 0) e.step() end
    near(VehicleUnits.studsPerSecondToKmh(e.drive.PlaneVelocity.X), -18)
    e.cleanup()
end)

test("steering is progressively gentler at highway speed", function()
    local function turnAt(throttle)
        local e = setup(false, { speedKmh = 100, accelerationKmhPerSecond = 50 })
        local p = e.player()
        e.enter(p)
        for _ = 1, 25 do e.input(p, throttle, 0) e.step() end
        near(VehicleUnits.studsPerSecondToKmh(e.drive.PlaneVelocity.X), throttle * 100)
        e.input(p, throttle, 1)
        e.step()
        local forward = e.align.CFrame.RightVector
        local angle = math.abs(math.atan2(forward.Z, forward.X))
        e.cleanup()
        return angle
    end
    local cityTurn, fastTurn = turnAt(0.2), turnAt(0.9)
    assert(fastTurn > 0 and fastTurn < cityTurn * 0.5, "fast steering must remain controllable")
end)

test("legacy configurations and invalid metric fields retain safe stud-based defaults", function()
    local e = setup(false, {
        speedKmh = false, reverseSpeedKmh = 0 / 0, accelerationKmhPerSecond = -1, brakeKmhPerSecond = math.huge,
        speed = 40, reverseSpeed = 12, acceleration = 10,
    })
    near(e.model:GetAttribute("MaxSpeedKmh"), 40.32)
    near(e.model:GetAttribute("ReverseSpeedKmh"), 12.096)
    local p = e.player()
    e.enter(p)
    for _ = 1, 10 do e.input(p, 1, 0) e.step() end
    near(e.drive.PlaneVelocity.X, 10)
    e.input(p, 0, 0)
    e.step()
    near(e.drive.PlaneVelocity.X, 7.2)
    e.cleanup()
end)

test("reverse steering changes direction and stationary vehicles cannot rotate", function()
    local e = setup()
    local p = e.player()
    e.enter(p)
    e.input(p, 0, 1)
    e.step()
    near(e.align.CFrame.RightVector.Z, 0)
    e.input(p, -1, 1)
    e.step()
    assert(e.drive.PlaneVelocity.X < 0 and e.align.CFrame.RightVector.Z < 0)
    e.cleanup()
end)

test("drive plane follows a ramp, remains orthonormal and excludes vehicles and characters", function()
    local e = setup()
    local p = e.player()
    e.enter(p)
    e.contactNormal = vector(-0.3, 1, 0.2).Unit
    for _ = 1, 15 do e.input(p, 1, 0) e.step() end
    local forward, right, up = e.drive.PrimaryTangentAxis, e.drive.SecondaryTangentAxis, e.align.CFrame.UpVector
    assert(forward.Y > 0.2)
    near(forward.Magnitude, 1)
    near(right.Magnitude, 1)
    near(up.Magnitude, 1)
    near(forward:Dot(right), 0)
    near(forward:Dot(up), 0)
    near(right:Dot(up), 0)
    assert(table.find(e.raycastFilter, e.fleet))
    assert(table.find(e.raycastFilter, p.Character))
    expect(e.drive.Enabled, true)
    e.cleanup()
end)

test("vehicles have no drive force before contact or in the air or on near-vertical walls", function()
    local e = setup()
    expect(e.drive.Enabled, false)
    expect(e.align.Enabled, false)
    e.contactCount = 1
    e.step()
    expect(e.drive.Enabled, false)
    expect(e.align.Enabled, false)
    e.contactCount, e.contactNormal = 4, vector(1, 0.1, 0).Unit
    e.step()
    expect(e.drive.Enabled, false)
    e.contactNormal = Y
    e.step()
    expect(e.drive.Enabled, true)
    e.cleanup()
end)

test("fallen vehicles reset to their spawn with zero residual velocity", function()
    local e = setup()
    local p = e.player()
    e.enter(p)
    e.input(p, 1, 1)
    e.step()
    e.chassis.Position = vector(400, -35, 500)
    e.step()
    local spawn = Catalog.fleet[1].position
    near(e.chassis.Position.X, spawn[1])
    near(e.chassis.Position.Y, spawn[2])
    near(e.chassis.Position.Z, spawn[3])
    near(e.chassis.AssemblyLinearVelocity.Magnitude, 0)
    near(e.chassis.AssemblyAngularVelocity.Magnitude, 0)
    near(e.drive.PlaneVelocity.X, 0)
    e.cleanup()
end)

test("removed vehicles reject entry and control before the next heartbeat", function()
    local e = setup()
    local p = e.player()
    e.model.Parent = e.workspace
    e.enter(p)
    expect(e.seat.Occupant, nil)
    e.step()
    expect(e.prompt.Triggered:count(), 0)
    expect(e.drive.Enabled, false)
    e.cleanup()
    e = setup()
    p = e.player()
    e.enter(p)
    e.model:Destroy()
    expect(e.prompt.Triggered:count(), 0)
    e.input(p, 1, 1)
    e.step()
    expect(e.drive.Enabled, false)
    e.cleanup()
end)

test("destroying the fleet or city disconnects all service callbacks immediately", function()
    for _, target in ipairs({ "fleet", "city" }) do
        local e = setup()
        e[target]:Destroy()
        expect(e.heartbeat:count(), 0)
        expect(e.remote.OnServerEvent:count(), 0)
        expect(e.prompt.Triggered:count(), 0)
        e.cleanup()
    end
end)

test("restarting the service replaces the old fleet and cleanup stays idempotent", function()
    local e = setup()
    local replacementCleanup = e.service.start(e.city, e.remote)
    expect(e.fleet.destroyed, true)
    expect(e.heartbeat:count(), 1)
    expect(e.remote.OnServerEvent:count(), 1)
    expect(#e.city:GetChildren(), 1)
    e.cleanup()
    expect(e.heartbeat:count(), 1)
    replacementCleanup()
    replacementCleanup()
    expect(e.heartbeat:count(), 0)
    expect(e.remote.OnServerEvent:count(), 0)
    expect(#e.city:GetChildren(), 0)
end)

print(string.format("Vehicle tests: %d passed, %d failed", passed, failed))
assert(failed == 0, "Vehicle tests failed")
