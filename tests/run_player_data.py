"""Exercise the actual PlayerData module with a deterministic DataStore scheduler."""
from pathlib import Path

from luau_runner import run_luau

ROOT = Path(__file__).resolve().parents[1]


def main():
    module = (ROOT / 'src/ServerScriptService/PlayerData.lua').read_text(encoding='utf-8')
    checks = (ROOT / 'tests/player_data.lua').read_text(encoding='utf-8')
    return run_luau('local function makeModule(game, task, os)\n' + module + '\nend\n' + checks, 'data.lua')


if __name__ == '__main__':
    raise SystemExit(main())
