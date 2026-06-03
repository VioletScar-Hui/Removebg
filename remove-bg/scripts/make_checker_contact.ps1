param(
    [Parameter(Mandatory = $true)]
    [string]$InputDirectory,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [int]$Columns = 3,
    [int]$CellPadding = 12,
    [int]$CheckerSize = 16
)

Add-Type -AssemblyName System.Drawing

$files = @(Get-ChildItem -LiteralPath $InputDirectory -Filter '*_removebg.png' | Sort-Object Name)
if ($files.Count -eq 0) {
    throw "No *_removebg.png files found in $InputDirectory"
}

$sample = [System.Drawing.Bitmap]::FromFile($files[0].FullName)
$cellWidth = $sample.Width + ($CellPadding * 2)
$cellHeight = $sample.Height + ($CellPadding * 2)
$sample.Dispose()

$rows = [int][Math]::Ceiling($files.Count / $Columns)
$sheet = New-Object System.Drawing.Bitmap ($cellWidth * $Columns), ($cellHeight * $rows), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($sheet)
$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver

try {
    for ($row = 0; $row -lt $rows; $row++) {
        for ($col = 0; $col -lt $Columns; $col++) {
            $cellX = $col * $cellWidth
            $cellY = $row * $cellHeight
            for ($y = 0; $y -lt $cellHeight; $y += $CheckerSize) {
                for ($x = 0; $x -lt $cellWidth; $x += $CheckerSize) {
                    $isLight = (([int]($x / $CheckerSize) + [int]($y / $CheckerSize)) % 2) -eq 0
                    $brush = if ($isLight) {
                        [System.Drawing.Brushes]::White
                    } else {
                        [System.Drawing.Brushes]::LightGray
                    }
                    $graphics.FillRectangle($brush, $cellX + $x, $cellY + $y, $CheckerSize, $CheckerSize)
                }
            }
        }
    }

    for ($i = 0; $i -lt $files.Count; $i++) {
        $bitmap = [System.Drawing.Bitmap]::FromFile($files[$i].FullName)
        try {
            $col = $i % $Columns
            $row = [int][Math]::Floor($i / $Columns)
            $x = ($col * $cellWidth) + $CellPadding
            $y = ($row * $cellHeight) + $CellPadding
            $graphics.DrawImage($bitmap, $x, $y, $bitmap.Width, $bitmap.Height)
        } finally {
            $bitmap.Dispose()
        }
    }

    $parent = Split-Path -Parent $OutputPath
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $sheet.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $graphics.Dispose()
    $sheet.Dispose()
}

Get-Item -LiteralPath $OutputPath | Select-Object FullName,Length
