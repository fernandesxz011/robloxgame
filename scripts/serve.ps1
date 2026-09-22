param([ValidateRange(1, 65535)][int]$Port = 34872)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$rojoExecutable = Join-Path $projectRoot '.tools\rojo\rojo.exe'
if (-not (Test-Path -LiteralPath $rojoExecutable)) {
    throw 'Rojo ausente em .tools\rojo. Consulte o README.'
}

Push-Location -LiteralPath $projectRoot
try {
    & $rojoExecutable serve default.project.json --address 127.0.0.1 --port $Port
    if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel iniciar o Rojo. Verifique se a porta ja esta em uso.' }
}
finally {
    Pop-Location
}
