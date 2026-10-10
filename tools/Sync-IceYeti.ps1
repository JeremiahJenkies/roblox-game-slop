# Safe helper for syncing and serving the Ice Yeti Rojo project.
# Run from the repository folder or invoke with -StartRojo.
[CmdletBinding()]
param(
    [switch]$StartRojo,
    [switch]$SkipPull
)

$ErrorActionPreference = "Stop"

function Invoke-Checked {
    param([Parameter(Mandatory=$true)][string]$File, [Parameter(Mandatory=$true)][string[]]$Arguments)
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$File failed with exit code $LASTEXITCODE"
    }
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $root
try {
    if (-not (Test-Path "default.project.json")) {
        throw "default.project.json was not found. Run this script from the cloned repository."
    }

    if (-not $SkipPull) {
        # --ff-only avoids silently rewriting local history or creating a surprise merge.
        Invoke-Checked -File "git" -Arguments @("pull", "--ff-only", "origin", "main")
    }

    Invoke-Checked -File "git" -Arguments @("status", "--short")
    Invoke-Checked -File "rojo" -Arguments @("--version")

    if ($StartRojo) {
        Write-Host "Starting Rojo. Leave this terminal open and connect Roblox Studio's Rojo plugin."
        Invoke-Checked -File "rojo" -Arguments @("serve", "default.project.json")
    } else {
        Write-Host "Sync check complete. To start Rojo, run: .\tools\Sync-IceYeti.ps1 -SkipPull -StartRojo"
    }
}
finally {
    Pop-Location
}
