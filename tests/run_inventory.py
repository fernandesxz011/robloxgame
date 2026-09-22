"""Run the actual inventory module with isolated Roblox object substitutes."""
from pathlib import Path

from luau_runner import run_luau

ROOT = Path(__file__).resolve().parents[1]


def main():
    module = (ROOT / "src/ServerScriptService/InventoryService.lua").read_text(encoding="utf-8")
    checks = (ROOT / "tests/inventory.lua").read_text(encoding="utf-8")
    return run_luau(f"local function makeModule(game)\n{module}\nend\n{checks}", "inventory.lua")


if __name__ == "__main__":
    raise SystemExit(main())
