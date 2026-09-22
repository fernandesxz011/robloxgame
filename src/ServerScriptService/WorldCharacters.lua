local WorldCharacters = {}

local function part(parent, name, size, frame, color)
    local object = Instance.new("Part")
    object.Name, object.Size, object.CFrame, object.Color = name, size, frame, color
    object.Anchored = true
    object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
    object.Material = Enum.Material.SmoothPlastic
    object.Parent = parent
    return object
end

function WorldCharacters.build(city)
    local folder = Instance.new("Folder")
    folder.Name = "Residents"
    folder.Parent = city
    local residents = {
        { "Lia", "Central de entregas", "MainMission", Color3.fromRGB(233, 179, 79) },
        { "Ravi", "Retirada de pacotes", "PackagePickup", Color3.fromRGB(96, 168, 139) },
        { "Nina", "Recepção do clube", "PackageDropoff", Color3.fromRGB(178, 109, 157) },
        { "Bia", "Mercadinho · lanches $60", "SnackShop", Color3.fromRGB(202, 108, 136) },
    }
    for _, info in ipairs(residents) do
        local marker = city:FindFirstChild(info[3])
        if not marker then continue end
        local model = Instance.new("Model")
        model.Name = info[1]
        model.Parent = folder
        local origin = CFrame.new(marker.Position.X + 5, 0.85, marker.Position.Z + 3)
        local skin = Color3.fromRGB(193, 146, 112)
        local trousers = Color3.fromRGB(40, 52, 66)
        local head = part(model, "Head", Vector3.new(1.25, 1.25, 1.1), origin * CFrame.new(0, 4.9, 0), skin)
        part(model, "Hair", Vector3.new(1.32, 0.4, 1.2), origin * CFrame.new(0, 5.4, 0), Color3.fromRGB(43, 35, 32))
        part(model, "Torso", Vector3.new(2, 1.9, 0.95), origin * CFrame.new(0, 3.3, 0), info[4])
        for _, side in ipairs({ -1, 1 }) do
            part(model, "Arm", Vector3.new(0.65, 1.85, 0.75), origin * CFrame.new(side * 1.4, 3.2, 0), skin)
            part(model, "Leg", Vector3.new(0.85, 2.3, 0.9), origin * CFrame.new(side * 0.52, 1.15, 0), trousers)
            part(model, "Eye", Vector3.new(0.12, 0.14, 0.04), origin * CFrame.new(side * 0.25, 5, -0.56), trousers)
        end
        local sign = Instance.new("BillboardGui")
        sign.Size = UDim2.fromOffset(160, 38)
        sign.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
        sign.MaxDistance = 50
        sign.Parent = head
        local text = Instance.new("TextLabel")
        text.Size = UDim2.fromScale(1, 1)
        text.BackgroundTransparency = 1
        text.Font, text.TextSize = Enum.Font.GothamBold, 12
        text.TextColor3 = Color3.fromRGB(255, 245, 224)
        text.TextStrokeTransparency = 0.35
        text.Text = info[1] .. "\n" .. info[2]
        text.Parent = sign
    end
end

function WorldCharacters.trackPlayer(player)
    local parcel, character, childConnection, diedConnection, trackedHumanoid
    local alive = true
    local function removeParcel()
        if parcel then parcel:Destroy() parcel = nil end
    end
    local function refresh()
        if not alive then return end
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid ~= trackedHumanoid then
            if diedConnection then diedConnection:Disconnect() end
            trackedHumanoid = humanoid
            diedConnection = humanoid and humanoid.Died:Connect(removeParcel) or nil
        end
        if not character or character ~= player.Character or not humanoid or humanoid.Health <= 0
            or player:GetAttribute("MissionStage") ~= "Deliver" then removeParcel() return end
        if parcel then return end
        local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
        if not torso then return end
        parcel = Instance.new("Part")
        parcel.Name = "DeliveryParcel"
        parcel.Size = Vector3.new(1.5, 1.4, 0.8)
        parcel.Color = Color3.fromRGB(181, 134, 81)
        parcel.Material = Enum.Material.Wood
        parcel.CFrame = torso.CFrame * CFrame.new(0, 0, torso.Size.Z / 2 + 0.45)
        parcel.Massless = true
        parcel.CanCollide, parcel.CanTouch, parcel.CanQuery = false, false, false
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = torso, parcel, parcel
        parcel.Parent = character
    end
    local function bindCharacter(nextCharacter)
        if childConnection then childConnection:Disconnect() end
        if diedConnection then diedConnection:Disconnect() diedConnection = nil end
        trackedHumanoid = nil
        removeParcel()
        character = nextCharacter
        childConnection = character.ChildAdded:Connect(refresh)
        refresh()
    end
    local characterConnection = player.CharacterAdded:Connect(bindCharacter)
    local stageConnection = player:GetAttributeChangedSignal("MissionStage"):Connect(refresh)
    if player.Character then bindCharacter(player.Character) end
    return function()
        alive = false
        characterConnection:Disconnect()
        stageConnection:Disconnect()
        if childConnection then childConnection:Disconnect() end
        if diedConnection then diedConnection:Disconnect() end
        removeParcel()
    end
end

return WorldCharacters
