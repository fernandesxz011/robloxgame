"""Exercise vehicle authorization, controller geometry and lifecycle in Luau.

Object substitutes do not simulate engine physics, networking or seat input.
"""
from pathlib import Path

from luau_runner import run_luau


ROOT = Path(__file__).resolve().parents[1]


def main():
    units = (ROOT / "src/ReplicatedStorage/VehicleUnits.lua").read_text(encoding="utf-8")
    catalog = (ROOT / "src/ServerScriptService/VehicleCatalog.lua").read_text(encoding="utf-8")
    service = (ROOT / "src/ServerScriptService/VehicleService.lua").read_text(encoding="utf-8")
    mocks = (ROOT / "tests/vehicle_mocks.lua").read_text(encoding="utf-8")
    checks = (ROOT / "tests/vehicles.lua").read_text(encoding="utf-8")
    parameters = (
        "game, Instance, Vector3, CFrame, Color3, Vector2, UDim2, UDim, Enum, "
        "PhysicalProperties, RaycastParams, os, require, script"
    )
    source = (
        f"local VehicleUnits = (function()\n{units}\nend)()\n"
        f"local Catalog = (function()\n{catalog}\nend)()\n"
        f"local function makeModule({parameters})\n{service}\nend\n{mocks}\n{checks}"
    )
    return run_luau(source, "vehicles.lua")


if __name__ == "__main__":
    raise SystemExit(main())
