-- The caller owns PlayerAdded/Removing, a 60-second autosave and BindToClose.
-- UpdateAsync callbacks never yield and always re-check the session owner.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local PlayerData = {}
local profiles = {}
local studio = RunService:IsStudio()
local storeName = studio and "DowntownHustle_PlayerData_Studio_v1" or "DowntownHustle_PlayerData_v1"
local store
local closing = false
local shutdownDeadline = math.huge
local LEASE_SECONDS = 180
local REQUEST_SECONDS = 20
local DEFAULTS = {
    Cash = 1500, BankBalance = 0, Reputation = 0, OwnedProperties = 0,
    MissionCompletions = 0, WorkCompletions = 0, SnackCount = 0,
    ObjectiveClaims = 0, SnacksPurchased = 0,
}
local LIMITS = {
    Cash = 2000000000, BankBalance = 2000000000, Reputation = 1000000, OwnedProperties = 1,
    MissionCompletions = 10000000, WorkCompletions = 10000000, SnackCount = 5,
    ObjectiveClaims = 7, SnacksPurchased = 10000000,
}

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function PlayerData.sanitize(raw)
    raw = type(raw) == "table" and raw or {}
    local data = {}
    for key, default in pairs(DEFAULTS) do
        local value = raw[key]
        data[key] = finite(value) and math.clamp(math.floor(value), 0, LIMITS[key]) or default
    end
    -- Older profiles already holding snacks must retain that purchase progress
    -- after consuming them, even before reaching the snack objective.
    if raw.SnacksPurchased == nil then data.SnacksPurchased = data.SnackCount end
    return data
end

local function status(player, state, message)
    player:SetAttribute("SaveState", state)
    player:SetAttribute("SaveMessage", message)
end

local function validEnvelope(raw)
    if type(raw) ~= "table" or raw.schema ~= 1 or type(raw.data) ~= "table" then return false end
    local session = raw.session
    return session == nil or (type(session) == "table" and type(session.token) == "string" and finite(session.expiresAt))
end

local function deadlineReached(deadline)
    return os.clock() >= math.min(deadline, shutdownDeadline)
end

-- A delayed engine request may outlive our deadline. Its callback is then
-- cancelled; an already committed lease expires without a defaults overwrite.
local function update(profile, transform, deadline)
    for attempt = 1, 3 do
        if profile.ended or deadlineReached(deadline) then return false, nil end
        local finished, cancelled, success, result = false, false, false, nil
        task.spawn(function()
            success, result = pcall(function()
                if not store then store = DataStoreService:GetDataStore(storeName) end
                return store:UpdateAsync(profile.key, function(raw)
                    if cancelled or profile.ended or deadlineReached(deadline) then return nil end
                    return transform(raw)
                end)
            end)
            finished = true
        end)
        while not finished and not profile.ended and not deadlineReached(deadline) do task.wait(0.05) end
        if not finished or profile.ended then
            cancelled = true
            return false, nil
        end
        if success then return true, result end
        if attempt < 3 then
            local retryAt = os.clock() + attempt
            while os.clock() < retryAt and not profile.ended and not deadlineReached(deadline) do task.wait(0.05) end
        end
    end
    return false, nil
end

local function finishRelease(player, profile)
    profile.ended = true
    profile.busy = false
    player:SetAttribute("DataReady", false)
    if profiles[player] == profile then profiles[player] = nil end
end

local function apply(player, profile, data)
    for key, value in pairs(data) do player:SetAttribute(key, value) end
    player:SetAttribute("PassiveIncome", data.OwnedProperties == 1 and 75 or 0)
    profile.applied = true
    player:SetAttribute("DataReady", true)
end

function PlayerData.load(player)
    if profiles[player] then return player:GetAttribute("DataReady") == true end
    player:SetAttribute("DataReady", false)
    if closing then
        status(player, "Unavailable", "O servidor está encerrando. Entre novamente.")
        return false
    end
    status(player, "Loading", "Carregando seu progresso...")
    local profile = {
        key = "Player_" .. tostring(player.UserId),
        token = HttpService:GenerateGUID(false),
        phase = "Loading", busy = true, applied = false, ended = false,
        releaseRequested = false,
    }
    profiles[player] = profile
    local rejection
    local success, result = update(profile, function(raw)
        rejection = nil -- Roblox can rerun this callback after a conflict.
        if closing or profile.releaseRequested or player.Parent == nil then
            rejection = "Cancelled"
            return nil
        end
        if raw ~= nil and not validEnvelope(raw) then
            rejection = "Invalid"
            return nil
        end
        local session = raw and raw.session
        if session and session.token ~= profile.token and session.expiresAt > os.time() then
            rejection = "Locked"
            return nil
        end
        return {
            schema = 1, data = PlayerData.sanitize(raw and raw.data),
            session = { token = profile.token, expiresAt = os.time() + LEASE_SECONDS },
            savedAt = raw and raw.savedAt, writeId = raw and raw.writeId,
        }
    end, os.clock() + REQUEST_SECONDS)

    if profile.ended then return false end
    if success and validEnvelope(result) and result.session and result.session.token == profile.token then
        profile.phase = "Ready"
        profile.loaded = PlayerData.sanitize(result.data)
        profile.leaseUntil = result.session.expiresAt
        profile.busy = false
        if closing or profile.releaseRequested or player.Parent == nil then
            PlayerData.save(player, true)
            return false
        end
        apply(player, profile, profile.loaded)
        status(player, "Saved", "Progresso carregado. Salvamento automático ativo.")
        return true
    end

    profile.busy = false
    if not success and studio and not closing and not profile.releaseRequested and player.Parent ~= nil then
        -- This profile can never acquire persistence later in the same session.
        profile.phase = "SessionOnly"
        apply(player, profile, PlayerData.sanitize(nil))
        status(player, "SessionOnly", "Teste no Studio: progresso apenas nesta sessão; DataStore indisponível.")
        return true
    end
    profile.phase = "Unavailable"
    if rejection == "Locked" then
        status(player, "Unavailable", "Seu progresso está aberto em outro servidor. Aguarde e entre novamente.")
    elseif rejection == "Invalid" then
        status(player, "Unavailable", "Não foi possível ler esta versão do progresso. Seus dados foram preservados.")
    else
        status(player, "Unavailable", "Não foi possível carregar seu progresso. Tente entrar novamente.")
    end
    if profile.releaseRequested or player.Parent == nil then finishRelease(player, profile) end
    return false
end

function PlayerData.save(player, release)
    local profile = profiles[player]
    if not profile or profile.ended then return false end
    local deadline = os.clock() + REQUEST_SECONDS
    if release then
        if profile.releaseRequested then
            -- PlayerRemoving and BindToClose can request the same release.
            -- Only the first caller may finalize it; observers wait through
            -- both its queue wait and its write, bounded by server shutdown.
            local observerDeadline = os.clock() + REQUEST_SECONDS * 2
            while not profile.ended and not deadlineReached(observerDeadline) do task.wait(0.05) end
            return profile.releaseSucceeded == true
        end
        profile.releaseRequested = true
        player:SetAttribute("DataReady", false)
    elseif profile.releaseRequested then
        return false
    end
    while profile.busy and not profile.ended and not deadlineReached(deadline) do task.wait(0.05) end
    if profile.ended then return profile.releaseSucceeded == true end
    if profile.busy or deadlineReached(deadline) then
        if release then finishRelease(player, profile) end
        return false
    end
    if not release and profile.releaseRequested then return false end
    if profile.phase == "SessionOnly" then
        if release then
            profile.releaseSucceeded = true
            finishRelease(player, profile)
        end
        return true
    end
    if profile.phase ~= "Ready" then
        if release then finishRelease(player, profile) end
        return false
    end

    profile.busy = true
    -- Waiting for an earlier request must not consume this write's budget.
    -- update() still caps the entire operation at the shared shutdown deadline.
    deadline = os.clock() + REQUEST_SECONDS
    -- Take this snapshot AFTER the previous save finishes, including on exit.
    local attributes = {}
    for key in pairs(DEFAULTS) do attributes[key] = player:GetAttribute(key) end
    local snapshot = profile.applied and PlayerData.sanitize(attributes) or profile.loaded
    local writeId = HttpService:GenerateGUID(false)
    local lostOwnership, alreadyReleased = false, false
    status(player, "Saving", release and "Salvando progresso ao sair..." or "Salvando progresso...")
    local success, result = update(profile, function(raw)
        lostOwnership, alreadyReleased = false, false
        if release and validEnvelope(raw) and raw.writeId == writeId then
            alreadyReleased = true -- A prior release committed but its reply was lost.
            return nil
        end
        local session = validEnvelope(raw) and raw.session
        if not session or session.token ~= profile.token or session.expiresAt <= os.time() then
            lostOwnership = true
            return nil
        end
        return {
            schema = 1, data = snapshot, savedAt = os.time(), writeId = writeId,
            session = not release and { token = profile.token, expiresAt = os.time() + LEASE_SECONDS } or nil,
        }
    end, deadline)

    if profile.ended then return false end
    profile.busy = false
    local saved = success and (alreadyReleased or (validEnvelope(result) and result.writeId == writeId))
    if saved then
        if not release then
            profile.leaseUntil = result.session.expiresAt
            profile.phase = "Ready"
            if not profile.releaseRequested and not closing then
                player:SetAttribute("DataReady", true)
            end
        end
        status(player, "Saved", "Progresso salvo.")
    elseif (success and lostOwnership) or os.time() >= profile.leaseUntil then
        profile.phase = "Unavailable"
        player:SetAttribute("DataReady", false)
        status(player, "Unavailable", "A sessão de salvamento expirou. Entre novamente para proteger seu progresso.")
    else
        status(player, "Retrying", "Falha temporária ao salvar. Nova tentativa no próximo salvamento automático.")
    end
    if release then
        profile.releaseSucceeded = saved
        finishRelease(player, profile)
    end
    return saved
end

function PlayerData.check(player)
    local profile = profiles[player]
    if not profile or profile.ended then return false end
    if profile.releaseRequested then return false end
    if profile.phase == "Ready" and os.time() >= profile.leaseUntil then
        player:SetAttribute("DataReady", false)
        if profile.busy then
            -- A renewal may have committed while its response is still pending.
            -- Pause gameplay until that request confirms or fails.
            status(player, "Retrying", "Confirmando o salvamento. Aguarde um instante...")
        else
            profile.phase = "Unavailable"
            status(player, "Unavailable", "A sessão de salvamento expirou. Entre novamente para proteger seu progresso.")
        end
    end
    return player:GetAttribute("DataReady") == true
end

function PlayerData.close()
    closing = true
    shutdownDeadline = math.min(shutdownDeadline, os.clock() + 24)
end

return PlayerData
