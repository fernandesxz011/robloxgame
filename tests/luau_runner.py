"""Run generated Luau suites using temporary files inside the project."""

import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def run_luau(source: str, filename: str) -> int:
    executable = ROOT / ".tools" / "luau" / ("luau.exe" if os.name == "nt" else "luau")
    if not executable.is_file():
        raise SystemExit(f"Luau executable not found: {executable}")

    # Keep generated files within the writable project, outside the source tree.
    temporary_root = ROOT / "build" / "tests"
    temporary_root.mkdir(parents=True, exist_ok=True)
    # Use a temporary file: Python 3.13 creates temporary directories with a
    # Windows ACL that can prevent a sandboxed process from accessing them.
    script = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", prefix=Path(filename).stem + "-",
            suffix=".lua", dir=temporary_root, delete=False,
        ) as generated:
            script = Path(generated.name)
            generated.write(source)
        # Luau's Windows CLI requires a relative path when the project has accents.
        return subprocess.run(
            [str(executable), script.name], cwd=temporary_root, check=False
        ).returncode
    finally:
        if script is not None:
            script.unlink()
