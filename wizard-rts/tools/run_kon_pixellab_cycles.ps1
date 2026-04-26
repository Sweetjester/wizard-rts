param(
    [int]$Cycles = 20,
    [int]$SleepSeconds = 35,
    [int]$MaxSubmit = 8
)

$ErrorActionPreference = "Stop"

for ($i = 0; $i -lt $Cycles; $i++) {
    Write-Host "=== PixelLab Kon 1.0 cycle $i ==="
    powershell.exe -ExecutionPolicy Bypass -File tools\run_pixellab_asset_generator.ps1 --manifest tools\pixellab_kon_1_0_manifest.json --jobs-dir tools\pixellab\kon_1_0_jobs poll
    powershell.exe -ExecutionPolicy Bypass -File tools\run_pixellab_asset_generator.ps1 --manifest tools\pixellab_kon_1_0_manifest.json --jobs-dir tools\pixellab\kon_1_0_jobs --max-submit $MaxSubmit submit
    if ($i -lt ($Cycles - 1)) {
        Start-Sleep -Seconds $SleepSeconds
    }
}
