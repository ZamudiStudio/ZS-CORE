# Packt zs_core und zs_character in recipe\dist\zamudi-core.zip (ohne LOCALHOST-Testserver und Geheimnisse).
# Aufruf:  powershell -ExecutionPolicy Bypass -File build-package.ps1

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$dist = Join-Path $here 'dist'
$stage = Join-Path $here '_stage'

if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $dist, $stage | Out-Null

foreach ($name in 'zs_core', 'zs_character') {
    Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path $stage $name) -Recurse -Force
}

$zip = Join-Path $dist 'zamudi-core.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
# tar schreibt Zip-Eintraege mit '/' (laeuft damit auch auf Linux-Hosts); Compress-Archive nutzt '\' und scheitert an [Tebex]
& "$env:SystemRoot\System32\tar.exe" -a -c -f $zip -C $stage zs_core zs_character
if ($LASTEXITCODE -ne 0) { throw 'Zip konnte nicht erstellt werden' }
Remove-Item -LiteralPath $stage -Recurse -Force

Copy-Item -LiteralPath (Join-Path $here 'recipe.yaml') -Destination (Join-Path $dist 'recipe.yaml') -Force
Write-Host "Fertig: $zip"
