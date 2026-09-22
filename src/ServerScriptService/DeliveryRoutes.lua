-- All route and reward decisions stay on the server.
local DeliveryRoutes = {}

local routes = {
    {
        id = "vip", title = "Entrega VIP", reward = 650, duration = 180,
        pickup = "PackagePickup", pickupLabel = "Retirar na garagem",
        dropoff = "PackageDropoff", dropoffLabel = "Entregar no clube",
    },
    {
        id = "medical", title = "Entrega hospitalar", reward = 700, duration = 150,
        pickup = "PackagePickup", pickupLabel = "Retirar na garagem",
        dropoff = "HospitalDropoff", dropoffLabel = "Entregar no hospital",
    },
    {
        id = "documents", title = "Documentos express", reward = 800, duration = 150,
        pickup = "PackagePickup", pickupLabel = "Retirar na garagem",
        dropoff = "BankDropoff", dropoffLabel = "Entregar no banco",
    },
}

function DeliveryRoutes.offer(completions)
    return routes[(math.max(0, math.floor(completions)) % #routes) + 1]
end

function DeliveryRoutes.find(id)
    for _, route in ipairs(routes) do
        if route.id == id then return route end
    end
    return nil
end

function DeliveryRoutes.rank(completions)
    if completions >= 15 then return "Especialista", 100 end
    if completions >= 5 then return "Profissional", 50 end
    return "Iniciante", 0
end

return DeliveryRoutes
