"""Run isolated Luau checks against current server interactions and timers.

These checks mock Roblox objects; they do not replace a Studio playtest.
Run from any directory: python tests/run.py
"""

from pathlib import Path
import re

from luau_runner import run_luau


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src" / "ServerScriptService" / "GameServer.server.lua"


def main():
    source = SOURCE.read_text(encoding="utf-8-sig")
    functions = []
    for name in ("updateMissionOffer", "resetMission", "cancelMission", "cancelJob", "useInventory", "claimObjective", "updatePlayerTimers", "createMissionMarker"):
        matches = re.findall(
            rf"^local function {name}\b.*?^end[ \t]*$",
            source,
            flags=re.MULTILINE | re.DOTALL,
        )
        if len(matches) != 1:
            raise SystemExit(f"Expected exactly one top-level {name} function")
        functions.append(matches[0])
    bindings = re.findall(
        r"^(?:missionAction\.OnServerEvent:Connect\(cancelMission\)|jobAction\.OnServerEvent:Connect\(cancelJob\)|inventoryAction\.OnServerEvent:Connect\(useInventory\)|objectiveAction\.OnServerEvent:Connect\(claimObjective\))[ \t]*$",
        source,
        flags=re.MULTILINE,
    )
    if len(bindings) != 4:
        raise SystemExit("Expected mission, job, inventory and objective action bindings")
    mocks = (ROOT / "tests" / "mocks.lua").read_text(encoding="utf-8")
    modules = []
    for name in ("DeliveryRoutes", "JobService", "InventoryService", "ObjectiveService"):
        modules.append("local " + name + " = (function()\n" + (ROOT / "src/ServerScriptService" / (name + ".lua")).read_text(encoding="utf-8") + "\nend)()")
    checks = (ROOT / "tests" / "interactions.lua").read_text(encoding="utf-8")
    return run_luau("\n\n".join((mocks, *modules, *functions, *bindings, checks)), "interactions.lua")


if __name__ == "__main__":
    raise SystemExit(main())
