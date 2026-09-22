$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$compilerPath = Join-Path $projectRoot '.tools\luau\luau-compile.exe'
$rojoPath = Join-Path $projectRoot '.tools\rojo\rojo.exe'

foreach ($toolPath in @($compilerPath, $rojoPath)) {
    if (-not (Test-Path -LiteralPath $toolPath)) {
        throw "Ferramenta ausente: $toolPath. Consulte o README."
    }
}

Push-Location -LiteralPath $projectRoot
try {
    # Relative source paths also work with Luau CLI in accented Windows folders.
    $luaFiles = @(Get-ChildItem -LiteralPath 'src' -Recurse -File | Where-Object { $_.Extension -in @('.lua', '.luau') } | ForEach-Object { $_.FullName.Substring($projectRoot.TrimEnd('\').Length + 1) })
    & $compilerPath @luaFiles --null
    if ($LASTEXITCODE -ne 0) { throw 'Falha na compilacao Luau.' }

    python tests/run.py
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes de logica.' }

    python tests/run_player_data.py
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes de persistencia.' }

    python tests/run_housing.py
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes de apartamento.' }

    python tests/run_jobs.py
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes de turnos.' }

    python tests/run_inventory.py
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes de inventario.' }

    python tests/run_objectives.py
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes de objetivos.' }

    python tests/run_vehicles.py
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes de veiculos.' }

    New-Item -ItemType Directory -Path 'build' -Force | Out-Null
    & $rojoPath build default.project.json -o build/DowntownHustle.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Falha no build do Rojo.' }

    Write-Output 'Pronto: build/DowntownHustle.rbxlx'
}
finally {
    Pop-Location
}
