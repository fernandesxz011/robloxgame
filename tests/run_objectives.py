"""Exercise the actual ObjectiveService with isolated Roblox substitutes."""
from pathlib import Path

from luau_runner import run_luau

ROOT = Path(__file__).resolve().parents[1]


def main():
    module = (ROOT / "src/ServerScriptService/ObjectiveService.lua").read_text(encoding="utf-8")
    checks = (ROOT / "tests/objectives.lua").read_text(encoding="utf-8")
    return run_luau(f"local function makeModule(game, typeof)\n{module}\nend\n{checks}", "objectives.lua")


if __name__ == "__main__":
    raise SystemExit(main())
