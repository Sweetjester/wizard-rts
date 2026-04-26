param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GeneratorArgs
)

$ErrorActionPreference = "Stop"

function Find-Python {
    if ($env:PYTHON -and (Test-Path $env:PYTHON)) {
        return @($env:PYTHON)
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) { return @($python.Source) }

    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) { return @($py.Source, "-3") }

    $codexPython = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
    if (Test-Path $codexPython) { return @($codexPython) }

    throw "Python was not found. Install Python 3 or run the generator with a known Python executable."
}

$pythonCommand = @(Find-Python)
$script = Join-Path $PSScriptRoot "pixellab_asset_generator.py"
$pythonExe = $pythonCommand[0]
$pythonArgs = @()
if ($pythonCommand.Count -gt 1) {
    $pythonArgs = $pythonCommand[1..($pythonCommand.Count - 1)]
}
if ($GeneratorArgs.Count -gt 0 -and $GeneratorArgs[0] -eq "ui") {
    $script = Join-Path $PSScriptRoot "pixellab_asset_ui.py"
    if ($GeneratorArgs.Count -gt 1) {
        $GeneratorArgs = $GeneratorArgs[1..($GeneratorArgs.Count - 1)]
    } else {
        $GeneratorArgs = @()
    }
}
& $pythonExe @pythonArgs $script @GeneratorArgs
