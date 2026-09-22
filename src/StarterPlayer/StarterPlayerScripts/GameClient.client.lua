local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local VehicleUnits = require(ReplicatedStorage:WaitForChild("VehicleUnits"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local colors = {
    panel = Color3.fromRGB(17, 24, 35), text = Color3.fromRGB(242, 246, 255),
    muted = Color3.fromRGB(176, 191, 211), accent = Color3.fromRGB(255, 218, 93),
    button = Color3.fromRGB(44, 60, 81), energy = Color3.fromRGB(108, 227, 174),
}
local function make(className, parent, properties)
    local object = Instance.new(className)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end
local function round(object, radius)
    make("UICorner", object, { CornerRadius = UDim.new(0, radius or 10) })
end
local function label(parent, name, position, size, textSize, color)
    return make("TextLabel", parent, {
        Name = name, Position = position, Size = size, BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = textSize or 13, TextColor3 = color or colors.text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        Text = "", TextWrapped = true,
    })
end
local function button(parent, name, position, size, text)
    local object = make("TextButton", parent, {
        Name = name, Position = position, Size = size, BackgroundColor3 = colors.button,
        BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = colors.text, Text = text, AutoButtonColor = true,
    })
    round(object, 8)
    return object
end
local function attr(name, fallback)
    local value = player:GetAttribute(name)
    if value == nil then return fallback end
    return value
end
local function number(value)
    local formatted = tostring(math.floor(value))
    local result = formatted:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return result
end

-- Viewport coordinates also drive the compass; HUD placement reserves the top bar inset.
local screenGui = make("ScreenGui", playerGui, {
    Name = "DowntownHUD", ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = make("Frame", screenGui, {
    Name = "Panel", BackgroundColor3 = colors.panel, BackgroundTransparency = 0.08,
    BorderSizePixel = 0, Size = UDim2.fromOffset(350, 420),
})
round(panel, 14)
local title = label(panel, "Title", UDim2.fromOffset(12, 8), UDim2.new(1, -124, 0, 36), 17)
title.Font = Enum.Font.GothamBold
title.Text = "Downtown Hustle"
make("UITextSizeConstraint", title, {MinTextSize = 9, MaxTextSize = 17})
local helpButton = button(panel, "Help", UDim2.new(1, -100, 0, 8), UDim2.fromOffset(50, 36), "Ajuda")
local minimizeButton = button(panel, "Minimize", UDim2.new(1, -44, 0, 8), UDim2.fromOffset(36, 36), "−")
local cash = label(panel, "Cash", UDim2.fromOffset(12, 47), UDim2.new(0.5, -18, 0, 35), 15)
local bank = label(panel, "Bank", UDim2.new(0.5, 0, 0, 47), UDim2.new(0.5, -12, 0, 35), 15)
local energy = label(panel, "Energy", UDim2.fromOffset(12, 82), UDim2.new(0.5, -12, 0, 22), 12, colors.energy)
local energyTrack = make("Frame", panel, {
    Position = UDim2.new(0.5, 0, 0, 91), Size = UDim2.new(0.5, -12, 0, 5),
    BorderSizePixel = 0, BackgroundColor3 = colors.button,
})
round(energyTrack, 3)
local energyFill = make("Frame", energyTrack, {
    Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = colors.energy,
})
round(energyFill, 3)
-- Driving occupies the existing header, so touch controls and the compass keep
-- the same reserved panel boundary. It remains visible when details are folded.
local speedometer = make("Frame", panel, {
    Name = "Speedometer", Position = UDim2.fromOffset(12, 47), Size = UDim2.new(1, -24, 0, 57),
    BackgroundTransparency = 1, Visible = false,
})
local vehicleName = label(speedometer, "VehicleName", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 18), 12, colors.muted)
vehicleName.TextWrapped = false
vehicleName.TextTruncate = Enum.TextTruncate.AtEnd
local speedValue = label(speedometer, "Speed", UDim2.fromOffset(0, 20), UDim2.new(0.5, -4, 0, 37), 26)
speedValue.Font, speedValue.TextScaled = Enum.Font.GothamBold, true
speedValue.TextWrapped = false
make("UITextSizeConstraint", speedValue, { MinTextSize = 14, MaxTextSize = 26 })
local driveDirection = label(speedometer, "Direction", UDim2.new(0.5, 0, 0, 22), UDim2.fromOffset(30, 32), 21, colors.accent)
driveDirection.Font, driveDirection.TextXAlignment = Enum.Font.GothamBold, Enum.TextXAlignment.Center
driveDirection.BackgroundColor3, driveDirection.BackgroundTransparency = colors.button, 0
round(driveDirection, 6)
local speedLimit = label(speedometer, "Maximum", UDim2.new(0.5, 38, 0, 20), UDim2.new(0.5, -38, 0, 37), 11, colors.muted)
speedLimit.TextXAlignment = Enum.TextXAlignment.Right
local drivingVehicle

local function updateSpeedometer()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    local vehicle = seat and seat.Parent
    if not humanoid or humanoid.Health <= 0 or not seat or not seat:IsA("VehicleSeat")
        or seat.Name ~= "DriverSeat" or seat.Occupant ~= humanoid or not vehicle
        or not vehicle:IsA("Model") or vehicle:GetAttribute("DowntownVehicle") ~= true
        or not vehicle:IsDescendantOf(Workspace) then vehicle = nil end
    local chassis = vehicle and vehicle:FindFirstChild("Chassis")
    if not chassis or not chassis:IsA("BasePart") then vehicle = nil end
    local changed = drivingVehicle ~= vehicle
    drivingVehicle = vehicle
    speedometer.Visible = vehicle ~= nil
    if not vehicle then return changed end

    local velocity = chassis.AssemblyLinearVelocity
    local kmh = VehicleUnits.studsPerSecondToKmh(velocity.Magnitude)
    local forwardKmh = VehicleUnits.studsPerSecondToKmh(chassis.CFrame:VectorToObjectSpace(velocity).X)
    -- N is the small stationary band; R/D describe actual motion, not throttle.
    driveDirection.Text = forwardKmh < -0.5 and "R" or (forwardKmh > 0.5 and "D" or "N")
    speedValue.Text = string.format("%d km/h", math.floor(kmh + 0.5))
    local displayName = vehicle:GetAttribute("DisplayName")
    vehicleName.Text = type(displayName) == "string" and displayName ~= "" and displayName or vehicle.Name
    local maximum = vehicle:GetAttribute("MaxSpeedKmh")
    speedLimit.Text = type(maximum) == "number" and maximum > 0 and maximum < math.huge
        and string.format("Máx. %d km/h", math.floor(maximum + 0.5)) or "Máx. — km/h"
    return changed
end
local tabs = make("Frame", panel, {
    Name = "Tabs", Position = UDim2.fromOffset(12, 112), Size = UDim2.new(1, -24, 0, 32),
    BackgroundTransparency = 1,
})
local activityTab = button(tabs, "Activity", UDim2.fromOffset(0, 0), UDim2.new(1 / 3, -4, 1, 0), "Atividade")
local objectivesTab = button(tabs, "Objectives", UDim2.new(1 / 3, 2, 0, 0), UDim2.new(1 / 3, -4, 1, 0), "Objetivos")
local cityTab = button(tabs, "City", UDim2.new(2 / 3, 4, 0, 0), UDim2.new(1 / 3, -4, 1, 0), "Cidade")
local body = make("ScrollingFrame", panel, {
    Name = "Details", Position = UDim2.fromOffset(12, 150), Size = UDim2.new(1, -24, 1, -162),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = colors.muted, CanvasSize = UDim2.fromOffset(0, 322),
    ScrollingDirection = Enum.ScrollingDirection.Y,
})
local content = make("Frame", body, {
    Size = UDim2.new(1, -5, 0, 322), BackgroundTransparency = 1,
})
local missionTitle = label(content, "Mission", UDim2.fromOffset(0, 0), UDim2.new(1, -70, 0, 22), 14, colors.accent)
missionTitle.Font = Enum.Font.GothamBold
local timer = label(content, "Timer", UDim2.new(1, -70, 0, 0), UDim2.fromOffset(70, 22), 13, colors.accent)
timer.TextXAlignment = Enum.TextXAlignment.Right
local missionText = label(content, "MissionText", UDim2.fromOffset(0, 25), UDim2.new(1, 0, 0, 36), 13)
local progress, progressCaptions = {}, {}
for index, text in ipairs({"Aceitar", "Retirar", "Entregar"}) do
    local segment = make("Frame", content, {
        Position = UDim2.new((index - 1) / 3, 0, 0, 66), Size = UDim2.new(1 / 3, -6, 0, 4),
        BorderSizePixel = 0, BackgroundColor3 = colors.button,
    })
    round(segment, 2)
    local caption = label(content, "Step" .. index, UDim2.new((index - 1) / 3, 0, 0, 73), UDim2.new(1 / 3, -6, 0, 18), 11, colors.muted)
    caption.Text = text
    progress[index] = segment
    progressCaptions[index] = caption
end
local workTrack = make("Frame", content, {
    Name = "WorkProgress", Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, -6, 0, 5),
    BorderSizePixel = 0, BackgroundColor3 = colors.button, Visible = false,
})
round(workTrack, 3)
local workFill = make("Frame", workTrack, {
    Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, BackgroundColor3 = colors.energy,
})
round(workFill, 3)
local workCaption = label(content, "WorkProgressText", UDim2.fromOffset(0, 73), UDim2.new(1, 0, 0, 18), 11, colors.energy)
workCaption.Visible = false
local destinationText = label(content, "Destination", UDim2.fromOffset(0, 96), UDim2.new(1, -94, 0, 34), 12, colors.accent)
local cancelButton = button(content, "CancelMission", UDim2.new(1, -88, 0, 96), UDim2.fromOffset(88, 36), "Cancelar")
local inventory = label(content, "Inventory", UDim2.fromOffset(0, 140), UDim2.new(1, -130, 0, 36), 12, colors.energy)
local eatButton = button(content, "EatSnack", UDim2.new(1, -124, 0, 140), UDim2.fromOffset(124, 36), "Comer (+25)")
local details = label(content, "Stats", UDim2.fromOffset(0, 182), UDim2.new(1, 0, 0, 48), 11, colors.muted)
local status = label(content, "Status", UDim2.fromOffset(0, 236), UDim2.new(1, 0, 0, 54), 12)
local saveStatus = label(content, "SaveStatus", UDim2.fromOffset(0, 292), UDim2.new(1, 0, 0, 30), 10, colors.muted)
for _, text in ipairs({missionTitle, missionText, workCaption, destinationText, inventory, details, status, saveStatus}) do
    text.AutomaticSize = Enum.AutomaticSize.Y
end
local objectiveContent = make("Frame", body, {
    Name = "ObjectiveDetails", Size = UDim2.new(1, -5, 0, 314), BackgroundTransparency = 1, Visible = false,
})
local objectiveHeading = label(objectiveContent, "Heading", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 22), 12, colors.muted)
local objectiveTitle = label(objectiveContent, "Title", UDim2.fromOffset(0, 26), UDim2.new(1, 0, 0, 34), 15, colors.accent)
objectiveTitle.Font = Enum.Font.GothamBold
objectiveTitle.AutomaticSize = Enum.AutomaticSize.Y
local objectiveText = label(objectiveContent, "Description", UDim2.fromOffset(0, 64), UDim2.new(1, 0, 0, 40), 13)
objectiveText.TextYAlignment = Enum.TextYAlignment.Top
objectiveText.AutomaticSize = Enum.AutomaticSize.Y
local objectiveProgress = label(objectiveContent, "ProgressText", UDim2.fromOffset(0, 108), UDim2.new(1, 0, 0, 20), 12, colors.energy)
local objectiveTrack = make("Frame", objectiveContent, {
    Name = "Progress", Position = UDim2.fromOffset(0, 134), Size = UDim2.new(1, 0, 0, 6),
    BorderSizePixel = 0, BackgroundColor3 = colors.button,
})
round(objectiveTrack, 3)
local objectiveFill = make("Frame", objectiveTrack, {
    Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, BackgroundColor3 = colors.energy,
})
round(objectiveFill, 3)
local objectiveReward = label(objectiveContent, "Reward", UDim2.fromOffset(0, 144), UDim2.new(1, 0, 0, 22), 13, colors.accent)
local claimObjectiveButton = button(objectiveContent, "Claim", UDim2.fromOffset(0, 172), UDim2.new(1, 0, 0, 36), "Complete o objetivo")
local trackObjectiveButton = button(objectiveContent, "Track", UDim2.fromOffset(0, 216), UDim2.new(1, 0, 0, 36), "Marcar destino")
local objectiveStatus = label(objectiveContent, "Status", UDim2.fromOffset(0, 260), UDim2.new(1, 0, 0, 54), 12, colors.muted)
objectiveStatus.AutomaticSize = Enum.AutomaticSize.Y
local cityDestinations = {
    { marker = "GarageDestination", title = "Garagem Brasileira", description = "Escolha um veículo para explorar." },
    { marker = "BelaVistaDestination", title = "Bela Vista", description = "Comércio de bairro e ruas em subida." },
    { marker = "IpesDestination", title = "Vila dos Ipês", description = "Casas coloridas pelos morros." },
    { marker = "FeiraDestination", title = "Feira da Estação", description = "Encontre a feira e passeie pela praça." },
    { marker = "MiranteDestination", title = "Mirante da Serra", description = "Suba para ver a cidade do alto." },
}
local cityContent = make("Frame", body, {
    Name = "CityDetails", Size = UDim2.new(1, -5, 0, 0), BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y, Visible = false,
})
make("UIListLayout", cityContent, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
local function cityLabel(name, text, size, color, order)
    local object = label(cityContent, name, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, size + 6), size, color)
    object.Text, object.LayoutOrder = text, order
    object.TextYAlignment = Enum.TextYAlignment.Top
    object.AutomaticSize = Enum.AutomaticSize.Y
    return object
end
local cityHeading = cityLabel("Heading", "Pelos morros do Sudeste", 15, colors.accent, 1)
cityHeading.Font = Enum.Font.GothamBold
cityLabel("Introduction", "Explore bairros, comércio, feira e mirante. Marque um lugar para seguir a direção e a distância no seu indicador.", 12, colors.text, 2)
local garageHeading = cityLabel("GarageHeading", "Garagem gratuita", 13, colors.energy, 3)
garageHeading.Font = Enum.Font.GothamBold
local vehicleLibrary = cityLabel("VehicleLibrary", "Modelos brasileiros da comunidade.", 12, colors.text, 4)
cityLabel("DrivingHelp", "Use Dirigir perto do veículo. No computador: WASD para dirigir e espaço para sair. No celular: controles de movimento e pulo. O painel mostra km/h e o sentido do movimento: R ré, N parado, D frente. Explore as subidas com cuidado.", 11, colors.muted, 5)
local cityStatus = cityLabel("SelectedDestination", "Escolha um destino abaixo.", 12, colors.accent, 6)
local clearCityButton = button(cityContent, "ClearDestination", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 36), "Limpar destino")
clearCityButton.LayoutOrder, clearCityButton.Visible = 7, false
local cityButtons = {}
for index, destination in ipairs(cityDestinations) do
    local row = make("Frame", cityContent, {
        Name = destination.marker, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 7 + index,
    })
    local caption = label(row, "Description", UDim2.fromOffset(0, 0), UDim2.new(1, -84, 0, 48), 12)
    caption.Text = destination.title .. "\n" .. destination.description
    caption.TextYAlignment = Enum.TextYAlignment.Top
    caption.AutomaticSize = Enum.AutomaticSize.Y
    cityButtons[index] = button(row, "Mark", UDim2.new(1, -76, 0, 0), UDim2.fromOffset(76, 40), "Marcar")
end
local help = label(body, "HelpText", UDim2.fromOffset(0, 0), UDim2.new(1, -5, 0, 214), 13)
help.TextYAlignment = Enum.TextYAlignment.Top
help.Visible = false
help.Text = "COMO JOGAR\n\nObjetivos: siga os primeiros passos e toque em Receber ao concluir cada um. Marcar destino mostra o caminho enquanto você estiver livre na cidade.\nE ou toque: interagir com os pontos da cidade.\nAmarelo: aceite a entrega, retire na garagem e leve ao destino indicado antes do prazo. Siga seu marcador.\nTrabalhos: a energia é gasta ao iniciar. Fique a até 18 studs do ponto até completar o turno para receber. Cancelar, sair da área, dirigir ou morrer encerra o turno sem devolver energia. Conclua ou cancele antes de aceitar uma entrega ou entrar em casa.\nMercadinho: compre lanches por $60 e guarde até 5. Use Comer ou B para recuperar até 25 de energia. Azul: descanse no hospital.\nBanco: deposite ou saque.\nLaranja: compre seu apartamento por $850 para receber renda e entrar em casa. Use a cama para descansar e a porta para voltar à cidade. O prazo das entregas continua em casa.\n\nCarros: use Dirigir e os controles de movimento. Sem motorista, carros tombados voltam à vaga.\nH: ajuda. −: recolher painel. Role os detalhes para ver o inventário e seu progresso."
help.AutomaticSize = Enum.AutomaticSize.Y
help.Text = help.Text .. "\n\nCidade: conheça os veículos gratuitos da Garagem Brasileira, os bairros nos morros, a feira e o mirante. Marcar orienta seu passeio; use Limpar destino para voltar à central. Trabalhos e entregas têm prioridade no indicador; seu passeio retoma ao terminar.\n\nAo dirigir, o velocímetro mostra o veículo, a velocidade em km/h e a máxima do modelo. R/N/D indica movimento de ré, parado ou para frente. Recolher o painel mantém o velocímetro visível."

local helpVisible, minimized, selectedTab = false, false, "Activity"
local touchObstacles = {}
local compassRegions = {}
local function guiRect(object)
    local position = object.AbsolutePosition - screenGui.AbsolutePosition
    return Rect.new(position, position + object.AbsoluteSize)
end
local function effectivelyVisible(object)
    local ancestor = object
    while ancestor and ancestor ~= playerGui do
        if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
        if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return false end
        ancestor = ancestor.Parent
    end
    return ancestor == playerGui and object.AbsoluteSize.X > 0 and object.AbsoluteSize.Y > 0
end
local function readTouchObstacles()
    touchObstacles = {}
    local touchGui = playerGui:FindFirstChild("TouchGui")
    if not touchGui or not touchGui:IsA("ScreenGui") or not touchGui.Enabled then return false end
    for _, object in ipairs(touchGui:GetDescendants()) do
        if object:IsA("GuiObject") and effectivelyVisible(object)
            and (object.Name == "DynamicThumbstickFrame" or object.Name == "ThumbstickFrame" or object:IsA("GuiButton")) then
            table.insert(touchObstacles, guiRect(object))
        end
    end
    return #touchObstacles > 0
end
local function overlaps(first, second)
    return first.Min.X < second.Max.X and first.Max.X > second.Min.X
        and first.Min.Y < second.Max.Y and first.Max.Y > second.Min.Y
end
local function padded(rectangle, padding)
    local offset = Vector2.new(padding, padding)
    return Rect.new(rectangle.Min - offset, rectangle.Max + offset)
end
-- Split the safe area around actual input regions, including the invisible area
-- where a dynamic thumbstick gesture can begin. Native controls remain untouched.
local function freeRegions(bounds, obstacles)
    local regions = {bounds}
    for _, obstacle in ipairs(obstacles) do
        local blocked, nextRegions = padded(obstacle, 8), {}
        for _, region in ipairs(regions) do
            if not overlaps(region, blocked) then
                table.insert(nextRegions, region)
            else
                local left, top, right, bottom = region.Min.X, region.Min.Y, region.Max.X, region.Max.Y
                if blocked.Min.X > left then table.insert(nextRegions, Rect.new(left, top, blocked.Min.X, bottom)) end
                if blocked.Max.X < right then table.insert(nextRegions, Rect.new(blocked.Max.X, top, right, bottom)) end
                if blocked.Min.Y > top then table.insert(nextRegions, Rect.new(left, top, right, blocked.Min.Y)) end
                if blocked.Max.Y < bottom then table.insert(nextRegions, Rect.new(left, blocked.Max.Y, right, bottom)) end
            end
        end
        regions = nextRegions
    end
    return regions
end
local function resize()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local inset, bottomInset = GuiService:GetGuiInset()
    local viewport = camera.ViewportSize
    local touch = readTouchObstacles()
    local compact = touch and viewport.X > viewport.Y
    local driving = drivingVehicle ~= nil
    local shortHeader = compact and not driving
    local tabsY, bodyY = shortHeader and 70 or 112, shortHeader and 108 or 150
    local bounds = Rect.new(inset.X + 12, inset.Y + 12, viewport.X - bottomInset.X - 12, viewport.Y - bottomInset.Y - 12)
    local area = bounds
    if touch then
        local bestScore = -math.huge
        for _, region in ipairs(freeRegions(bounds, touchObstacles)) do
            local width, height = math.min(350, region.Width), math.min(420, region.Height)
            -- Prefer readable columns with enough room for a complete tap target.
            local requiredHeight = bodyY + 52
            local score = width * height * (height >= requiredHeight and 1 or 0.01) * (width >= 220 and 1 or 0.75)
            if score > bestScore then area, bestScore = region, score end
        end
    end
    local width = math.min(350, math.max(1, area.Width))
    local height = math.min(minimized and (shortHeader and 70 or 110) or 420, math.max(1, area.Height))
    panel.Position = UDim2.fromOffset(area.Min.X, area.Min.Y)
    panel.Size = UDim2.fromOffset(width, height)
    local walletTitle = compact or driving
    title.Text = walletTitle and ("Carteira $" .. number(attr("Cash", 0)) .. "\nBanco $" .. number(attr("BankBalance", 0))) or "Downtown Hustle"
    title.TextSize = walletTitle and 12 or 17
    title.TextScaled = walletTitle
    cash.Visible, bank.Visible = not walletTitle, not walletTitle
    energy.Visible, energyTrack.Visible = not driving, not driving
    energy.Position = UDim2.fromOffset(12, compact and 45 or 82)
    energyTrack.Position = UDim2.new(0.5, 0, 0, compact and 54 or 91)
    tabs.Position = UDim2.fromOffset(12, tabsY)
    body.Position, body.Size = UDim2.fromOffset(12, bodyY), UDim2.new(1, -24, 0, math.max(1, height - bodyY - 12))
    body.Visible = not minimized
    tabs.Visible = not minimized
    help.Visible = helpVisible
    content.Visible = not helpVisible and selectedTab == "Activity"
    objectiveContent.Visible = not helpVisible and selectedTab == "Objectives"
    cityContent.Visible = not helpVisible and selectedTab == "City"
    activityTab.TextColor3 = selectedTab == "Activity" and colors.accent or colors.muted
    objectivesTab.TextColor3 = selectedTab == "Objectives" and colors.accent or colors.muted
    cityTab.TextColor3 = selectedTab == "City" and colors.accent or colors.muted
    -- Keep all activity text readable when a touch-safe column is narrower.
    local narrow = width < 300
    local tabTextSize = width < 240 and 10 or (narrow and 11 or 12)
    activityTab.TextSize, objectivesTab.TextSize, cityTab.TextSize = tabTextSize, tabTextSize, tabTextSize
    local missionExtra = math.max(0, missionTitle.AbsoluteSize.Y - 22)
    missionText.Position = UDim2.fromOffset(0, 25 + missionExtra)
    local activityExtra = missionExtra + math.max(0, missionText.AbsoluteSize.Y - 36)
    for index, segment in ipairs(progress) do
        segment.Position = UDim2.new((index - 1) / 3, 0, 0, 66 + activityExtra)
        progressCaptions[index].Position = UDim2.new((index - 1) / 3, 0, 0, 73 + activityExtra)
    end
    workTrack.Position = UDim2.fromOffset(0, 66 + activityExtra)
    workCaption.Position = UDim2.fromOffset(0, 73 + activityExtra)
    if workCaption.Visible then activityExtra = activityExtra + math.max(0, workCaption.AbsoluteSize.Y - 18) end
    destinationText.Size = UDim2.new(1, not narrow and cancelButton.Visible and -94 or 0, 0, 34)
    destinationText.Position = UDim2.fromOffset(0, 96 + activityExtra)
    local destinationHeight = math.max(36, destinationText.AbsoluteSize.Y)
    cancelButton.Position = narrow and UDim2.fromOffset(0, 100 + activityExtra + destinationHeight)
        or UDim2.new(1, -88, 0, 96 + activityExtra)
    cancelButton.Size = narrow and UDim2.new(1, 0, 0, 36) or UDim2.fromOffset(88, 36)
    local inventoryY = 104 + activityExtra + destinationHeight + (narrow and cancelButton.Visible and 40 or 0)
    inventory.Position, inventory.Size = UDim2.fromOffset(0, inventoryY), UDim2.new(1, narrow and 0 or -130, 0, 36)
    eatButton.Position = narrow and UDim2.fromOffset(0, inventoryY + math.max(36, inventory.AbsoluteSize.Y) + 4)
        or UDim2.new(1, -124, 0, inventoryY)
    eatButton.Size = narrow and UDim2.new(1, 0, 0, 36) or UDim2.fromOffset(124, 36)
    local statsY = inventoryY + math.max(36, inventory.AbsoluteSize.Y) + 6 + (narrow and 40 or 0)
    details.Position = UDim2.fromOffset(0, statsY)
    local statusY = statsY + math.max(48, details.AbsoluteSize.Y) + 6
    status.Position = UDim2.fromOffset(0, statusY)
    local saveY = statusY + math.max(54, status.AbsoluteSize.Y) + 2
    saveStatus.Position = UDim2.fromOffset(0, saveY)
    local activityHeight = saveY + math.max(30, saveStatus.AbsoluteSize.Y)
    content.Size = UDim2.new(1, -5, 0, activityHeight)
    -- Long text expands downwards on narrow screens; both actions fit at the normal panel width.
    local titleExtra = math.max(0, objectiveTitle.AbsoluteSize.Y - 34)
    local textExtra = titleExtra + math.max(0, objectiveText.AbsoluteSize.Y - 40)
    objectiveText.Position = UDim2.fromOffset(0, 64 + titleExtra)
    objectiveProgress.Position = UDim2.fromOffset(0, 108 + textExtra)
    objectiveTrack.Position = UDim2.fromOffset(0, 134 + textExtra)
    objectiveReward.Position = UDim2.fromOffset(0, 144 + textExtra)
    claimObjectiveButton.Position = UDim2.fromOffset(0, 172 + textExtra)
    trackObjectiveButton.Position = UDim2.fromOffset(0, 216 + textExtra)
    objectiveStatus.Position = UDim2.fromOffset(0, 260 + textExtra)
    local objectiveHeight = 260 + textExtra + math.max(54, objectiveStatus.AbsoluteSize.Y)
    objectiveContent.Size = UDim2.new(1, -5, 0, objectiveHeight)
    local cityHeight = math.max(322, cityContent.AbsoluteSize.Y + 4)
    local selectedHeight = selectedTab == "Objectives" and objectiveHeight or (selectedTab == "City" and cityHeight or activityHeight)
    body.CanvasSize = UDim2.fromOffset(0, helpVisible and math.max(322, help.AbsoluteSize.Y) or selectedHeight)
    minimizeButton.Text = minimized and "+" or "−"
    local occupied = table.clone(touchObstacles)
    table.insert(occupied, Rect.new(area.Min, area.Min + Vector2.new(width, height)))
    compassRegions = freeRegions(bounds, occupied)
end
local function toggleHelp()
    helpVisible = not helpVisible
    if helpVisible then minimized = false end
    helpButton.Text = helpVisible and "Voltar" or "Ajuda"
    body.CanvasPosition = Vector2.zero
    resize()
end
helpButton.Activated:Connect(toggleHelp)
minimizeButton.Activated:Connect(function() minimized = not minimized resize() end)
local function selectTab(name)
    selectedTab, helpVisible, minimized = name, false, false
    helpButton.Text = "Ajuda"
    body.CanvasPosition = Vector2.zero
    resize()
end
activityTab.Activated:Connect(function() selectTab("Activity") end)
objectivesTab.Activated:Connect(function() selectTab("Objectives") end)
cityTab.Activated:Connect(function() selectTab("City") end)

local stages = {
    None = { marker = "MainMission", title = "Central de entregas", step = 0 },
    Pickup = { marker = "PackagePickup", title = "Retirar na garagem", step = 1 },
    Deliver = { marker = "PackageDropoff", title = "Entregar no clube", step = 2 },
}
local function currentStage() return stages[attr("MissionStage", "None")] or stages.None end
local trackedObjectiveId
local selectedCityDestination
local lastObjectiveClaim = -math.huge
local function canTrackObjective()
    return attr("DataReady", false) and not attr("ObjectivesFinished", false) and not attr("ObjectiveReady", false)
        and not attr("InsideHome", false) and not attr("WorkActive", false) and currentStage().step == 0
        and attr("ObjectiveId", "") ~= "" and attr("ObjectiveMarkerName", "") ~= ""
end
local function trackingObjective()
    if trackedObjectiveId and (trackedObjectiveId ~= attr("ObjectiveId", "") or not canTrackObjective()) then
        trackedObjectiveId = nil
    end
    return trackedObjectiveId ~= nil
end
local target
local highlight = make("Highlight", Workspace, {
    Name = "LocalMissionHighlight", FillColor = colors.accent, OutlineColor = colors.accent,
    FillTransparency = 0.7, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
    Enabled = false,
})
local beacon = make("BillboardGui", playerGui, {
    Name = "LocalMissionBeacon", Size = UDim2.fromOffset(190, 48), AlwaysOnTop = true,
    StudsOffsetWorldSpace = Vector3.new(0, 5, 0), Enabled = false,
    ResetOnSpawn = false,
})
local beaconText = label(beacon, "Destination", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 13, colors.accent)
beaconText.TextXAlignment = Enum.TextXAlignment.Center
beaconText.Font = Enum.Font.GothamBold
beaconText.BackgroundColor3 = colors.panel
beaconText.BackgroundTransparency = 0.2
round(beaconText, 8)
local compass = make("Frame", screenGui, {
    Name = "OffscreenDestination", Size = UDim2.fromOffset(154, 58), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = colors.panel, BackgroundTransparency = 0.16, BorderSizePixel = 0,
    Visible = false, ZIndex = 5,
})
round(compass, 9)
local arrow = label(compass, "Arrow", UDim2.fromOffset(61, 0), UDim2.fromOffset(32, 26), 23, colors.accent)
arrow.Text, arrow.TextXAlignment, arrow.ZIndex = "▲", Enum.TextXAlignment.Center, 6
local compassText = label(compass, "Destination", UDim2.fromOffset(3, 25), UDim2.new(1, -6, 0, 31), 11, colors.accent)
compassText.TextXAlignment, compassText.ZIndex = Enum.TextXAlignment.Center, 6

local function syncTarget()
    local stage = currentStage()
    local city = Workspace:FindFirstChild("Downtown")
    local ready = attr("DataReady", false)
    local insideHome = attr("InsideHome", false)
    local working = attr("WorkActive", false)
    local objectiveTracked = trackingObjective()
    local markerName = working and attr("WorkMarkerName", "")
        or (stage.step > 0 and attr("MissionTargetName", stage.marker))
        or (objectiveTracked and attr("ObjectiveMarkerName", ""))
        or (selectedCityDestination and selectedCityDestination.marker) or "MainMission"
    local candidate = ready and city and city:FindFirstChild(markerName) or nil
    target = not insideHome and candidate and candidate:IsA("BasePart") and candidate or nil
    highlight.Adornee, beacon.Adornee = target, target
    highlight.Enabled, beacon.Enabled = target ~= nil, target ~= nil
    if insideHome then
        compass.Visible = false
        destinationText.Text = "Em casa · use a porta para voltar"
    end
    -- These are local prompt choices; the server still validates every interaction.
    if city then
        for _, marker in ipairs(city:GetChildren()) do
            local prompt = marker and marker:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                if marker.Name == "MainMission" then
                    prompt.Enabled = ready and not insideHome and not working and stage.step == 0
                elseif marker:GetAttribute("MissionCheckpoint") then
                    prompt.Enabled = ready and not insideHome and not working and stage.step > 0 and marker == candidate
                elseif marker.Name == "HouseOffer" then
                    local owned = attr("OwnedProperties", 0) > 0
                    prompt.Enabled = ready and not insideHome and not working
                    prompt.ActionText = owned and "Entrar" or "Comprar"
                    prompt.ObjectText = owned and "Meu apartamento" or "Apartamento — $850"
                    local activityLabel = marker:FindFirstChild("ActivityLabel")
                    local activityText = activityLabel and activityLabel:FindFirstChildOfClass("TextLabel")
                    if activityText then activityText.Text = prompt.ObjectText end
                elseif marker:GetAttribute("JobMarker") then
                    prompt.Enabled = ready and not insideHome and not working and stage.step == 0
                else
                    prompt.Enabled = ready and not insideHome
                end
            end
        end
    end
end
local function updateCityGuide()
    local ready = attr("DataReady", false)
    local city = Workspace:FindFirstChild("Downtown")
    local fleet = city and city:FindFirstChild("Vehicles")
    local modelNames, knownNames = {}, {}
    if fleet then
        for _, vehicle in ipairs(fleet:GetChildren()) do
            local name = vehicle:GetAttribute("DisplayName")
            if vehicle:GetAttribute("DowntownVehicle") == true and type(name) == "string" and name ~= "" and not knownNames[name] then
                knownNames[name] = true
                table.insert(modelNames, name)
            end
        end
    end
    table.sort(modelNames)
    garageHeading.Text = #modelNames > 0 and string.format("Garagem gratuita · %d %s", #modelNames, #modelNames == 1 and "modelo" or "modelos")
        or "Garagem gratuita"
    vehicleLibrary.Text = #modelNames > 0 and ("Modelos brasileiros da comunidade:\n" .. table.concat(modelNames, " · "))
        or "Modelos brasileiros da comunidade."
    clearCityButton.Visible = selectedCityDestination ~= nil
    for index, destination in ipairs(cityDestinations) do
        local markButton = cityButtons[index]
        local candidate = city and city:FindFirstChild(destination.marker)
        local available = ready and candidate ~= nil and candidate:IsA("BasePart")
        local selected = selectedCityDestination == destination
        markButton.Active, markButton.Selectable, markButton.AutoButtonColor = available, available, available
        markButton.Text = not available and "Aguarde" or (selected and "Marcado" or "Marcar")
        markButton.TextColor3 = selected and colors.accent or (available and colors.text or colors.muted)
    end
    if not ready then
        cityStatus.Text = "Carregando a cidade..."
    elseif selectedCityDestination then
        local message = "Destino: " .. selectedCityDestination.title
        if attr("InsideHome", false) then
            message = message .. "\nSaia de casa para seguir o indicador."
        elseif attr("WorkActive", false) or currentStage().step > 0 then
            message = message .. "\nSua atividade tem prioridade; o passeio retoma ao terminar."
        else
            message = message .. "\nSiga seu indicador para explorar."
        end
        cityStatus.Text = message
    else
        cityStatus.Text = "Escolha um destino abaixo."
    end
end
local function updateObjectives()
    local ready = attr("DataReady", false)
    local finished = attr("ObjectivesFinished", false)
    local total = math.max(1, attr("ObjectiveTotal", 7))
    local claimed = math.clamp(attr("ObjectiveClaims", 0), 0, total)
    local goal = math.max(1, attr("ObjectiveTarget", 1))
    local achieved = math.clamp(attr("ObjectiveProgress", 0), 0, goal)
    local reward = number(attr("ObjectiveReward", 0))
    local completed = attr("ObjectiveReady", false)
    local coolingDown = os.clock() - lastObjectiveClaim < 1
    local canClaim = ready and completed and not finished and not coolingDown and attr("ObjectiveId", "") ~= ""
    local isTracking = trackingObjective()
    local canTrack = canTrackObjective()
    objectiveHeading.Text = string.format("Primeiros passos · %d/%d", claimed, total)
    objectiveTitle.Text = not ready and "Carregando objetivos..."
        or (finished and "Primeiros passos concluídos!") or attr("ObjectiveTitle", "Explore a cidade")
    objectiveText.Text = not ready and "Aguarde seu progresso carregar."
        or (finished and "Você conheceu a cidade! Continue trabalhando, complete novas entregas e aproveite seu apartamento.")
        or attr("ObjectiveText", "Siga os objetivos para aprender e receber recompensas.")
    objectiveProgress.Text = finished and "Todos os objetivos concluídos"
        or string.format("Progresso: %s / %s%s", number(achieved), number(goal), completed and " · Pronto!" or "")
    objectiveFill.Size = UDim2.fromScale(finished and 1 or (ready and achieved / goal or 0), 1)
    objectiveReward.Text = finished and "Recompensas recebidas" or ("Recompensa: $" .. reward)
    claimObjectiveButton.Active, claimObjectiveButton.Selectable, claimObjectiveButton.AutoButtonColor = canClaim, canClaim, canClaim
    claimObjectiveButton.TextColor3 = canClaim and colors.accent or colors.muted
    claimObjectiveButton.Text = not ready and "Carregando..." or (finished and "Tudo recebido")
        or (coolingDown and "Aguarde...") or (completed and ("Receber $" .. reward)) or "Complete o objetivo"
    trackObjectiveButton.Active, trackObjectiveButton.Selectable, trackObjectiveButton.AutoButtonColor = canTrack, canTrack, canTrack
    trackObjectiveButton.TextColor3 = canTrack and colors.text or colors.muted
    trackObjectiveButton.Text = isTracking and "Ocultar destino" or "Marcar destino"
    objectivesTab.Text = ready and completed and not finished and "Objetivos •" or "Objetivos"
    objectiveStatus.Text = attr("StatusText", "Siga os primeiros passos e receba suas recompensas.")
end
local lastSnack = -math.huge
local function updateSnackButton()
    local count = attr("SnackCount", 0)
    local coolingDown = os.clock() - lastSnack < 2
    local canEat = attr("DataReady", false) and count > 0 and attr("Energy", 100) < 100 and not coolingDown
    inventory.Text = string.format("Lanches  %d / 5", count)
    eatButton.Active, eatButton.Selectable, eatButton.AutoButtonColor = canEat, canEat, canEat
    eatButton.TextColor3 = canEat and colors.text or colors.muted
    eatButton.Text = coolingDown and "Aguarde..." or "Comer (+25)"
end
local previousWorking, previousMissionStep = attr("WorkActive", false), currentStage().step
local function refreshFromAttributes()
    cash.Text = "Carteira  $" .. number(attr("Cash", 0))
    bank.Text = "Banco  $" .. number(attr("BankBalance", 0))
    local amount = math.clamp(attr("Energy", 100), 0, 100)
    energy.Text = "Energia  " .. math.floor(amount) .. " / 100"
    energyFill.Size = UDim2.fromScale(amount / 100, 1)
    energyFill.BackgroundColor3 = amount < 25 and colors.accent or colors.energy
    local stage = currentStage()
    local ready = attr("DataReady", false)
    local working = attr("WorkActive", false)
    local startedActivity = (working and not previousWorking) or (stage.step > 0 and previousMissionStep == 0)
    previousWorking, previousMissionStep = working, stage.step
    if startedActivity then selectTab("Activity") end
    if not ready then
        missionTitle.Text = "Carregando progresso..."
        missionText.Text = "Aguarde o carregamento para começar a jogar."
    elseif working then
        missionTitle.Text = attr("WorkTitle", "Trabalho em andamento")
        missionText.Text = string.format("%s\nAo concluir: $%s", attr("WorkMessage", "Fique perto do ponto até terminar."), number(attr("WorkReward", 0)))
    else
        missionTitle.Text = stage.step == 0 and attr("OfferedMissionName", "Entregas") or attr("CurrentMission", "Entrega")
        local reward = stage.step == 0 and attr("OfferedMissionReward", 0) or attr("MissionReward", 0)
        missionText.Text = stage.step == 0 and string.format("Oferta: $%s · %d segundos\nAceite esta rota na central.", number(reward), attr("OfferedMissionDuration", 180)) or attr("MissionText", "Siga seu indicador.")
    end
    local canCancel = ready and (working or stage.step > 0)
    cancelButton.Visible = canCancel
    for index, segment in ipairs(progress) do
        segment.BackgroundColor3 = index <= stage.step and colors.accent or colors.button
        segment.Visible, progressCaptions[index].Visible = not working, not working
    end
    workTrack.Visible, workCaption.Visible = ready and working, ready and working
    details.Text = string.format("Reputação %d · Procurado %d/5\nEntregas %d · Turnos %d\nImóveis %d · Renda $%s/min · %s",
        attr("Reputation", 0), attr("Wanted", 0), attr("MissionCompletions", 0), attr("WorkCompletions", 0),
        attr("OwnedProperties", 0), number(attr("PassiveIncome", 0)), attr("CourierRank", "Iniciante"))
    status.Text = attr("StatusText", "Bem-vindo a Downtown Hustle")
    saveStatus.Text = attr("SaveMessage", "Carregando seu progresso...")
    saveStatus.TextColor3 = attr("SaveState", "Loading") == "Saved" and colors.energy or colors.muted
    updateSnackButton()
    updateObjectives()
    updateCityGuide()
    syncTarget()
end
for _, name in ipairs({"Cash", "BankBalance", "Energy", "Reputation", "Wanted", "CurrentJob",
    "OwnedProperties", "InsideHome", "PassiveIncome", "CurrentMission", "MissionStage", "MissionText",
    "StatusText", "MissionExpiresAt", "MissionCompletions", "MissionReward", "MissionTargetName", "MissionTargetLabel",
    "OfferedMissionName", "OfferedMissionReward", "OfferedMissionDuration", "CourierRank", "DataReady", "SaveState", "SaveMessage",
    "WorkActive", "WorkTitle", "WorkMarkerName", "WorkStartedAt", "WorkEndsAt", "WorkReward", "WorkMessage", "WorkCompletions", "SnackCount",
    "ObjectiveId", "ObjectiveTitle", "ObjectiveText", "ObjectiveProgress", "ObjectiveTarget", "ObjectiveReward", "ObjectiveMarkerName",
    "ObjectiveReady", "ObjectivesFinished", "ObjectiveNumber", "ObjectiveTotal", "ObjectiveClaims"}) do
    player:GetAttributeChangedSignal(name):Connect(refreshFromAttributes)
end
local lastCancel = -math.huge
cancelButton.Activated:Connect(function()
    local working = attr("WorkActive", false)
    if not attr("DataReady", false) or (not working and currentStage().step == 0) or os.clock() - lastCancel < 1 then return end
    local remotes = ReplicatedStorage:FindFirstChild("LifeSimRemotes")
    local action = remotes and remotes:FindFirstChild(working and "JobAction" or "MissionAction")
    if action and action:IsA("RemoteEvent") then
        lastCancel = os.clock()
        action:FireServer("Cancel")
    end
end)
claimObjectiveButton.Activated:Connect(function()
    local objectiveId = attr("ObjectiveId", "")
    if not attr("DataReady", false) or not attr("ObjectiveReady", false) or attr("ObjectivesFinished", false)
        or objectiveId == "" or os.clock() - lastObjectiveClaim < 1 then return end
    local remotes = ReplicatedStorage:FindFirstChild("LifeSimRemotes")
    local action = remotes and remotes:FindFirstChild("ObjectiveAction")
    if action and action:IsA("RemoteEvent") then
        lastObjectiveClaim = os.clock()
        updateObjectives()
        action:FireServer("Claim", objectiveId)
    end
end)
trackObjectiveButton.Activated:Connect(function()
    if not canTrackObjective() then return end
    if trackingObjective() then
        trackedObjectiveId = nil
    else
        trackedObjectiveId = attr("ObjectiveId", "")
        selectedCityDestination = nil
    end
    updateObjectives()
    updateCityGuide()
    syncTarget()
end)
for index, destination in ipairs(cityDestinations) do
    cityButtons[index].Activated:Connect(function()
        local city = Workspace:FindFirstChild("Downtown")
        local candidate = city and city:FindFirstChild(destination.marker)
        if not attr("DataReady", false) or not candidate or not candidate:IsA("BasePart") then return end
        selectedCityDestination, trackedObjectiveId = destination, nil
        updateObjectives()
        updateCityGuide()
        syncTarget()
    end)
end
clearCityButton.Activated:Connect(function()
    selectedCityDestination = nil
    updateCityGuide()
    syncTarget()
end)
local function useSnack()
    if not attr("DataReady", false) or attr("SnackCount", 0) <= 0 or attr("Energy", 100) >= 100 or os.clock() - lastSnack < 2 then return end
    local remotes = ReplicatedStorage:FindFirstChild("LifeSimRemotes")
    local action = remotes and remotes:FindFirstChild("InventoryAction")
    if action and action:IsA("RemoteEvent") then
        lastSnack = os.clock()
        updateSnackButton()
        action:FireServer("UseSnack")
    end
end
eatButton.Activated:Connect(useSnack)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.H then toggleHelp()
    elseif input.KeyCode == Enum.KeyCode.B then useSnack() end
end)

local function updateDestination()
    syncTarget()
    resize()
    updateSnackButton()
    updateObjectives()
    updateCityGuide()
    local working = attr("WorkActive", false)
    local now = Workspace:GetServerTimeNow()
    local deadline = working and attr("WorkEndsAt", 0) or attr("MissionExpiresAt", 0)
    local remaining = math.max(0, math.ceil(deadline - now))
    timer.Text = attr("DataReady", false) and (working or currentStage().step > 0) and string.format("%d:%02d", math.floor(remaining / 60), remaining % 60) or ""
    timer.TextColor3 = working and colors.energy or (remaining <= 30 and Color3.fromRGB(255, 145, 125) or colors.accent)
    if working then
        local started = attr("WorkStartedAt", now)
        local fraction = math.clamp((now - started) / math.max(0.001, deadline - started), 0, 1)
        workFill.Size = UDim2.fromScale(fraction, 1)
        workCaption.Text = string.format("%d%% concluído · permaneça na área", math.floor(fraction * 100))
    end
    if attr("InsideHome", false) then
        destinationText.Text = "Em casa · use a porta para voltar"
        return
    end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local distance = target and root and math.floor((root.Position - target.Position).Magnitude + 0.5)
    local targetLabel = working and attr("WorkTitle", "Local do trabalho")
        or (currentStage().step > 0 and attr("MissionTargetLabel", "Destino da entrega"))
        or (trackingObjective() and attr("ObjectiveTitle", "Objetivo"))
        or (selectedCityDestination and selectedCityDestination.title) or "Central de entregas"
    local text = targetLabel .. (distance and " · " .. distance .. " studs" or "")
    destinationText.Text = target and text or "Localizando destino..."
    beaconText.Text, compassText.Text = text, text
end
RunService.RenderStepped:Connect(function()
    if updateSpeedometer() then resize() end
    local camera = Workspace.CurrentCamera
    if attr("InsideHome", false) or not camera or not target or not target.Parent then compass.Visible = false return end
    local worldPoint = target.Position + Vector3.new(0, 5, 0)
    local point, onScreen = camera:WorldToViewportPoint(worldPoint)
    compass.Visible = not (onScreen and point.Z > 0)
    if not compass.Visible then return end
    local viewport = camera.ViewportSize
    local relative = camera.CFrame:PointToObjectSpace(worldPoint)
    local direction = Vector2.new(relative.X, -relative.Y)
    if direction.Magnitude < 0.001 then direction = Vector2.new(0, 1) end
    direction = direction.Unit
    local inset, bottomInset = GuiService:GetGuiInset()
    local minX, maxX = inset.X + 86, viewport.X - bottomInset.X - 86
    local minY, maxY = inset.Y + 40, viewport.Y - bottomInset.Y - 42
    local center = Vector2.new((minX + maxX) / 2, (minY + maxY) / 2)
    local extent = Vector2.new(math.max(1, (maxX - minX) / 2), math.max(1, (maxY - minY) / 2))
    local scale = math.min(extent.X / math.max(math.abs(direction.X), 0.001), extent.Y / math.max(math.abs(direction.Y), 0.001))
    local desired = center + direction * scale
    local function findPosition(size)
        local bestPosition, bestDistance
        local half = size / 2
        for _, region in ipairs(compassRegions) do
            if region.Width >= size.X and region.Height >= size.Y then
                local candidate = Vector2.new(math.clamp(desired.X, region.Min.X + half.X, region.Max.X - half.X),
                    math.clamp(desired.Y, region.Min.Y + half.Y, region.Max.Y - half.Y))
                local distance = (candidate - desired).Magnitude
                if not bestDistance or distance < bestDistance then bestPosition, bestDistance = candidate, distance end
            end
        end
        return bestPosition
    end
    local position = findPosition(Vector2.new(154, 58))
    local arrowOnly = position == nil
    if arrowOnly then position = findPosition(Vector2.new(36, 32)) end
    if not position then compass.Visible = false return end
    compass.Size = arrowOnly and UDim2.fromOffset(36, 32) or UDim2.fromOffset(154, 58)
    compassText.Visible = not arrowOnly
    arrow.Position = arrowOnly and UDim2.fromOffset(2, 3) or UDim2.fromOffset(61, 0)
    compass.Position = UDim2.fromOffset(position.X, position.Y)
    arrow.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
end)

-- VehicleSeat input stays at 10 Hz and is validated again by the server.
local vehicleElapsed, uiElapsed = 0, 0
RunService.Heartbeat:Connect(function(deltaTime)
    uiElapsed = uiElapsed + deltaTime
    if uiElapsed >= 0.2 then uiElapsed = 0 updateDestination() end
    vehicleElapsed = vehicleElapsed + deltaTime
    if vehicleElapsed < 0.1 then return end
    vehicleElapsed = 0
    if not attr("DataReady", false) then return end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    if not seat or not seat:IsA("VehicleSeat") or not seat.Parent or humanoid.Health <= 0
        or seat.Occupant ~= humanoid or not seat.Parent:GetAttribute("DowntownVehicle") then return end
    local remotes = ReplicatedStorage:FindFirstChild("LifeSimRemotes")
    local vehicleInput = remotes and remotes:FindFirstChild("VehicleInput")
    if vehicleInput and vehicleInput:IsA("RemoteEvent") then
        vehicleInput:FireServer(seat.ThrottleFloat, seat.SteerFloat)
    end
end)
refreshFromAttributes()
updateDestination()
