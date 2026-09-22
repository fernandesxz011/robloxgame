-- Paste into the Studio command bar during Play, in client view, then Ctrl+Enter.
-- Run after changing orientation, opening each tab (including City), scrolling,
-- selecting or clearing a city destination, minimizing the HUD, or entering/
-- leaving a vehicle. Let the interface settle before running the check.
-- This check only reads the live UI; it does not change gameplay or native controls.
local player = game:GetService("Players").LocalPlayer
assert(player, "Use the client view during Play")
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("DowntownHUD")
local panel = hud:WaitForChild("Panel")

local function visible(object)
    local parent = object
    while parent and parent ~= playerGui do
        if parent:IsA("GuiObject") and not parent.Visible then return false end
        if parent:IsA("ScreenGui") and not parent.Enabled then return false end
        parent = parent.Parent
    end
    return parent == playerGui
end
local function bounds(object)
    local p, s = object.AbsolutePosition, object.AbsoluteSize
    return {p.X, p.Y, p.X + s.X, p.Y + s.Y}
end
local function intersects(a, b)
    return a[1] < b[3] and a[3] > b[1] and a[2] < b[4] and a[4] > b[2]
end
local function contained(inner, outer)
    return inner[1] >= outer[1] - 1 and inner[2] >= outer[2] - 1
        and inner[3] <= outer[3] + 1 and inner[4] <= outer[4] + 1
end

assert(contained(bounds(panel), bounds(hud)), "Panel leaves the device safe area")
assert(panel.AbsoluteSize.X >= 220, "Panel is too narrow to read")
local details = panel:WaitForChild("Details")
if visible(details) then
    assert(details.AbsoluteSize.Y >= 36, "Scroll area cannot show a complete button")
    assert(contained(bounds(details), bounds(panel)), "Scroll area leaves the panel")
end
local tabs = panel:WaitForChild("Tabs")
local speedometer = panel:WaitForChild("Speedometer")
local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
local seat = humanoid and humanoid.SeatPart
local vehicle = seat and seat.Parent
local chassis = vehicle and vehicle:FindFirstChild("Chassis")
local driving = humanoid ~= nil and humanoid.Health > 0 and seat ~= nil and seat:IsA("VehicleSeat")
    and seat.Name == "DriverSeat" and seat.Occupant == humanoid and vehicle ~= nil
    and vehicle:IsA("Model") and vehicle:GetAttribute("DowntownVehicle") == true
    and vehicle:IsDescendantOf(workspace) and chassis ~= nil and chassis:IsA("BasePart")
assert(visible(speedometer) == driving, "Speedometer visibility does not match the current driver")
local speedReading
if driving then
    assert(contained(bounds(speedometer), bounds(panel)), "Speedometer leaves the panel")
    assert(not intersects(bounds(speedometer), bounds(panel.Title)), "Speedometer covers the header")
    if visible(tabs) then assert(not intersects(bounds(speedometer), bounds(tabs)), "Speedometer covers tabs") end
    if visible(details) then assert(not intersects(bounds(speedometer), bounds(details)), "Speedometer covers scroll content") end
    local speed, direction, maximum = speedometer.Speed, speedometer.Direction, speedometer.Maximum
    assert(speed.Text:match("^%d+ km/h$"), "Speedometer must show a numeric km/h reading")
    assert(direction.Text == "R" or direction.Text == "N" or direction.Text == "D", "Invalid movement direction")
    assert(maximum.Text:match("^Máx%. "), "Vehicle maximum speed is missing")
    for _, item in ipairs({speedometer.VehicleName, speed, direction, maximum}) do
        assert(contained(bounds(item), bounds(speedometer)), item.Name .. " leaves the speedometer")
        assert(item.TextBounds.Y <= item.AbsoluteSize.Y + 1, item.Name .. " speedometer text is clipped")
    end
    assert(speed.TextBounds.X <= speed.AbsoluteSize.X + 1, "Speed reading is too wide")
    assert(not intersects(bounds(speed), bounds(direction)), "Speed reading covers direction")
    assert(not intersects(bounds(direction), bounds(maximum)), "Direction covers maximum speed")
    local units = require(game:GetService("ReplicatedStorage"):WaitForChild("VehicleUnits"))
    speedReading = {
        displayed = speed.Text, direction = direction.Text, maximum = maximum.Text,
        measuredKmh = units.studsPerSecondToKmh(chassis.AssemblyLinearVelocity.Magnitude),
    }
end
if visible(tabs) then
    local previous
    for _, name in ipairs({"Activity", "Objectives", "City"}) do
        local tab = tabs:WaitForChild(name)
        assert(visible(tab), "Missing visible tab: " .. name)
        assert(contained(bounds(tab), bounds(tabs)), name .. " tab leaves the tab bar")
        assert(tab.TextBounds.X <= tab.AbsoluteSize.X + 1, name .. " tab text is clipped")
        if previous then assert(not intersects(bounds(previous), bounds(tab)), "Tabs overlap") end
        previous = tab
    end
end
local city = details:WaitForChild("CityDetails")
local cityRows = 0
if visible(city) then
    local bottom = city.AbsolutePosition.Y + city.AbsoluteSize.Y
        - details.AbsolutePosition.Y + details.CanvasPosition.Y
    assert(bottom <= details.AbsoluteCanvasSize.Y + 1, "City destinations extend beyond the scroll canvas")
    local items = {}
    for _, item in ipairs(city:GetChildren()) do
        if item:IsA("GuiObject") and item.Visible then table.insert(items, item) end
    end
    table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    local previous
    for _, item in ipairs(items) do
        assert(contained(bounds(item), bounds(city)), item.Name .. " leaves CityDetails")
        if previous then assert(not intersects(bounds(previous), bounds(item)), "City content overlaps: " .. item.Name) end
        previous = item
        local mark = item:FindFirstChild("Mark")
        if mark then
            cityRows = cityRows + 1
            local caption = item:WaitForChild("Description")
            assert(contained(bounds(caption), bounds(item)), item.Name .. " description leaves its row")
            assert(contained(bounds(mark), bounds(item)), item.Name .. " button leaves its row")
            assert(not intersects(bounds(caption), bounds(mark)), item.Name .. " button covers its description")
            assert(mark.AbsoluteSize.Y <= details.AbsoluteSize.Y, "Scroll area cannot show a complete city button")
            assert(caption.TextBounds.Y <= caption.AbsoluteSize.Y + 1, item.Name .. " description is clipped")
        elseif item:IsA("TextLabel") then
            assert(item.TextBounds.Y <= item.AbsoluteSize.Y + 1, item.Name .. " city text is clipped")
        end
    end
    assert(cityRows == 5, "City guide should contain five destinations")
end
local obstacles = {}
local touchGui = playerGui:FindFirstChild("TouchGui")
if touchGui and touchGui.Enabled then
    for _, control in ipairs(touchGui:GetDescendants()) do
        if control:IsA("GuiObject") and visible(control)
            and (control.Name == "DynamicThumbstickFrame" or control.Name == "ThumbstickFrame" or control:IsA("GuiButton")) then
            obstacles[control.Name] = bounds(control)
            assert(not intersects(bounds(panel), bounds(control)), "Panel blocks " .. control.Name)
            local compass = hud:FindFirstChild("OffscreenDestination")
            if compass and visible(compass) then
                assert(not intersects(bounds(compass), bounds(control)), "Compass blocks " .. control.Name)
            end
        end
    end
end
local compass = hud:FindFirstChild("OffscreenDestination")
if compass and visible(compass) then
    assert(contained(bounds(compass), bounds(hud)), "Compass leaves the device safe area")
    assert(not intersects(bounds(compass), bounds(panel)), "Compass covers the panel")
end
print("STUDIO_HUD_CHECK_OK", game:GetService("HttpService"):JSONEncode({
    viewport = {workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y},
    panel = bounds(panel), scrollHeight = details.AbsoluteSize.Y,
    controls = obstacles, expanded = visible(details), cityVisible = visible(city), cityRows = cityRows,
    driving = driving, speedometer = speedReading,
}))
