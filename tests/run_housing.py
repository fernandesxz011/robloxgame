"""Exercise the actual Housing module with isolated Roblox object substitutes."""
from pathlib import Path

from luau_runner import run_luau

ROOT = Path(__file__).resolve().parents[1]


def main():
    module = (ROOT / "src/ServerScriptService/Housing.lua").read_text(encoding="utf-8")
    checks = (ROOT / "tests/housing.lua").read_text(encoding="utf-8")
    parameters = "game, Instance, Vector3, CFrame, Color3, Vector2, UDim2, Enum, os"
    return run_luau(f"local function makeModule({parameters})\n{module}\nend\n{checks}", "housing.lua")


if __name__ == "__main__":
    raise SystemExit(main())
