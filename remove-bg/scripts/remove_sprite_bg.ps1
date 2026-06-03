param(
    [Parameter(Mandatory = $true)]
    [string[]]$InputPath,

    [string]$OutputDirectory,

    [int]$Threshold = 8,
    [int]$MinBackgroundComponent = 500,
    [int]$KeepDistance = 48,
    [switch]$SkipCleanup,
    [switch]$SkipContactSheet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $OutputDirectory) {
    $first = Get-Item -LiteralPath $InputPath[0]
    $OutputDirectory = if ($first.PSIsContainer) { $first.FullName } else { $first.DirectoryName }
}

$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("remove-bg-stage-" + [guid]::NewGuid().ToString("N"))
$stageRaw = Join-Path $stageRoot "raw"
$stageClean = Join-Path $stageRoot "clean"
New-Item -ItemType Directory -Force -Path $stageRaw, $stageClean | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

try {
    & (Join-Path $scriptRoot "pixel_black_bg_remove.ps1") `
        -InputPath $InputPath `
        -OutputDirectory $stageRaw `
        -Threshold $Threshold `
        -MinBackgroundComponent $MinBackgroundComponent | Out-Null

    if ($SkipCleanup) {
        Get-ChildItem -LiteralPath $stageRaw -Filter "*_removebg.png" | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $stageClean -Force
        }
    } else {
        & (Join-Path $scriptRoot "cleanup_isolated_components.ps1") `
            -InputDirectory $stageRaw `
            -OutputDirectory $stageClean `
            -KeepDistance $KeepDistance | Out-Null
    }

    if (-not $SkipContactSheet) {
        & (Join-Path $scriptRoot "make_checker_contact.ps1") `
            -InputDirectory $stageClean `
            -OutputPath (Join-Path $stageClean "remove-bg-checker-contact.png") | Out-Null
    }

    $resultFiles = @(Get-ChildItem -LiteralPath $stageClean -Filter "*_removebg.png" | Sort-Object Name)
    if ($resultFiles.Count -eq 0) {
        throw "No remove-bg outputs were produced."
    }

    $resultFiles | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $OutputDirectory -Force
    }

    if (-not $SkipContactSheet) {
        Copy-Item -LiteralPath (Join-Path $stageClean "remove-bg-checker-contact.png") -Destination $OutputDirectory -Force
    }

    Add-Type -AssemblyName System.Drawing
    $resultFiles | ForEach-Object {
        $bitmap = [System.Drawing.Bitmap]::FromFile($_.FullName)
        try {
            $transparent = 0
            $opaque = 0
            for ($y = 0; $y -lt $bitmap.Height; $y++) {
                for ($x = 0; $x -lt $bitmap.Width; $x++) {
                    if ($bitmap.GetPixel($x, $y).A -eq 0) {
                        $transparent++
                    } else {
                        $opaque++
                    }
                }
            }

            [pscustomobject]@{
                File = Join-Path $OutputDirectory $_.Name
                TransparentPixels = $transparent
                OpaquePixels = $opaque
            }
        } finally {
            $bitmap.Dispose()
        }
    }
} finally {
    if (Test-Path -LiteralPath $stageRoot) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }
}
