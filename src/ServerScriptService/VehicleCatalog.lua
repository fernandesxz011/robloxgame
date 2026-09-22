-- Editable, original low-poly interpretations of cars familiar on Brazilian streets.
-- Inspiration describes the silhouette; these are not licensed manufacturer assets.
local VehicleCatalog = {}

-- Gameplay tuning in km/h, not manufacturer performance specifications.
VehicleCatalog.models = {
    {
        id = "quadrado", displayName = "Quadrado 88", inspiration = "Gol quadrado",
        style = "hatch", length = 9.4, width = 4.5, roofHeight = 2.5,
        wheelRadius = 1.02, color = { 177, 48, 38 }, accent = { 33, 37, 40 },
        speed = 38, reverseSpeed = 15, acceleration = 15, turnRate = 1.35,
        speedKmh = 100, reverseSpeedKmh = 22, accelerationKmhPerSecond = 18, brakeKmhPerSecond = 36,
    },
    {
        id = "mille", displayName = "Mille Urbano", inspiration = "Uno brasileiro",
        style = "compact", length = 8.6, width = 4.3, roofHeight = 2.7,
        wheelRadius = 0.98, color = { 229, 231, 215 }, accent = { 40, 43, 40 },
        speed = 34, reverseSpeed = 14, acceleration = 16, turnRate = 1.5,
        speedKmh = 95, reverseSpeedKmh = 20, accelerationKmhPerSecond = 17, brakeKmhPerSecond = 36,
    },
    {
        id = "besouro", displayName = "Besouro 72", inspiration = "Fusca brasileiro",
        style = "beetle", length = 9.4, width = 4.5, roofHeight = 2.8,
        wheelRadius = 1.05, color = { 91, 167, 175 }, accent = { 223, 224, 211 },
        speed = 32, reverseSpeed = 13, acceleration = 12, turnRate = 1.3,
        speedKmh = 85, reverseSpeedKmh = 18, accelerationKmhPerSecond = 14, brakeKmhPerSecond = 32,
    },
    {
        id = "kombosa", displayName = "Kombosa da Feira", inspiration = "Kombi brasileira",
        style = "van", length = 12.1, width = 5.2, roofHeight = 3.6,
        wheelRadius = 1.12, color = { 226, 173, 52 }, accent = { 245, 235, 211 },
        speed = 30, reverseSpeed = 12, acceleration = 10, turnRate = 1.05,
        speedKmh = 80, reverseSpeedKmh = 18, accelerationKmhPerSecond = 11, brakeKmhPerSecond = 30,
    },
    {
        id = "diplomata", displayName = "Diplomata 79", inspiration = "Opala brasileiro",
        style = "sedan", length = 11.8, width = 4.9, roofHeight = 2.45,
        wheelRadius = 1.09, color = { 60, 98, 66 }, accent = { 220, 217, 201 },
        speed = 42, reverseSpeed = 15, acceleration = 14, turnRate = 1.12,
        speedKmh = 120, reverseSpeedKmh = 24, accelerationKmhPerSecond = 20, brakeKmhPerSecond = 38,
    },
    {
        id = "sertaneja", displayName = "Sertaneja CS", inspiration = "Picapes compactas brasileiras",
        style = "pickup", length = 11.2, width = 4.7, roofHeight = 2.65,
        wheelRadius = 1.12, color = { 198, 126, 55 }, accent = { 43, 44, 41 },
        speed = 36, reverseSpeed = 14, acceleration = 13, turnRate = 1.2,
        speedKmh = 105, reverseSpeedKmh = 22, accelerationKmhPerSecond = 17, brakeKmhPerSecond = 35,
    },
    {
        id = "circular", displayName = "Circular da Serra", inspiration = "Micro-ônibus urbanos do Sudeste",
        style = "bus", length = 16.8, width = 6.1, roofHeight = 4.45,
        wheelRadius = 1.35, color = { 39, 122, 111 }, accent = { 241, 230, 200 },
        speed = 29, reverseSpeed = 11, acceleration = 9, turnRate = 0.8,
        speedKmh = 70, reverseSpeedKmh = 16, accelerationKmhPerSecond = 9, brakeKmhPerSecond = 28,
    },
}

-- Position is the chassis center. Vehicles face +X, with yaw in degrees.
-- The eastern yard is level at y=0.7, with access from the avenue at z=104.
VehicleCatalog.fleet = {
    { id = "quadrado", position = { -18, 2.5, 36 }, plate = "BRZ1A88" },
    { id = "mille", position = { 18, 2.5, -36 }, plate = "BRZ2B90", taxi = true },
    { id = "besouro", position = { 52, 2.5, 34 }, plate = "BRZ3C72" },
    { id = "quadrado", position = { 205, 2.5, 52 }, plate = "BRZ4D88" },
    { id = "mille", position = { 230, 2.5, 52 }, plate = "BRZ5E91" },
    { id = "besouro", position = { 255, 2.5, 52 }, plate = "BRZ6F72" },
    { id = "kombosa", position = { 280, 2.65, 52 }, plate = "BRZ7G75" },
    { id = "diplomata", position = { 205, 2.65, 78 }, plate = "BRZ8H79" },
    { id = "sertaneja", position = { 230, 2.65, 78 }, plate = "BRZ9J04" },
    { id = "circular", position = { 255, 2.9, 78 }, plate = "BRZ0K26" },
}

function VehicleCatalog.get(id)
    for _, specification in ipairs(VehicleCatalog.models) do
        if specification.id == id then return specification end
    end
    return nil
end

return VehicleCatalog
