param(
    [Parameter(Mandatory = $true)]
    [string[]]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [int]$Threshold = 8,
    [int]$MinBackgroundComponent = 500
)

Add-Type -AssemblyName System.Drawing

function Test-BackgroundPixel {
    param(
        [System.Drawing.Color]$Color,
        [int]$Threshold
    )

    return $Color.A -gt 0 -and $Color.R -le $Threshold -and $Color.G -le $Threshold -and $Color.B -le $Threshold
}

function Remove-BlackBackground {
    param(
        [string]$Source,
        [string]$Destination,
        [int]$Threshold,
        [int]$MinBackgroundComponent
    )

    $bitmap = [System.Drawing.Bitmap]::FromFile($Source)
    try {
        $width = $bitmap.Width
        $height = $bitmap.Height
        $total = $width * $height
        $visited = New-Object bool[] $total
        $remove = New-Object bool[] $total
        $queue = New-Object int[] $total
        $removedCount = 0

        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $idx = ($y * $width) + $x
                if ($visited[$idx]) { continue }

                $color = $bitmap.GetPixel($x, $y)
                if (-not (Test-BackgroundPixel -Color $color -Threshold $Threshold)) {
                    $visited[$idx] = $true
                    continue
                }

                $head = 0
                $tail = 0
                $component = New-Object System.Collections.Generic.List[int]
                $visited[$idx] = $true
                $queue[$tail] = $idx
                $tail++

                while ($head -lt $tail) {
                    $current = $queue[$head]
                    $head++
                    $component.Add($current)
                    $cx = $current % $width
                    $cy = [int][Math]::Floor($current / $width)

                    $neighbors = @()
                    if ($cx -gt 0) { $neighbors += ($current - 1) }
                    if ($cx -lt ($width - 1)) { $neighbors += ($current + 1) }
                    if ($cy -gt 0) { $neighbors += ($current - $width) }
                    if ($cy -lt ($height - 1)) { $neighbors += ($current + $width) }

                    foreach ($next in $neighbors) {
                        if ($visited[$next]) { continue }
                        $nx = $next % $width
                        $ny = [int][Math]::Floor($next / $width)
                        $nextColor = $bitmap.GetPixel($nx, $ny)
                        if (Test-BackgroundPixel -Color $nextColor -Threshold $Threshold) {
                            $visited[$next] = $true
                            $queue[$tail] = $next
                            $tail++
                        }
                    }
                }

                if ($component.Count -ge $MinBackgroundComponent) {
                    foreach ($pixel in $component) {
                        $remove[$pixel] = $true
                    }
                    $removedCount += $component.Count
                }
            }
        }

        $output = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            for ($y = 0; $y -lt $height; $y++) {
                for ($x = 0; $x -lt $width; $x++) {
                    $idx = ($y * $width) + $x
                    if ($remove[$idx]) {
                        $output.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
                    } else {
                        $output.SetPixel($x, $y, $bitmap.GetPixel($x, $y))
                    }
                }
            }

            $parent = Split-Path -Parent $Destination
            if ($parent) {
                New-Item -ItemType Directory -Force -Path $parent | Out-Null
            }
            $output.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $output.Dispose()
        }

        return [pscustomobject]@{
            Source = $Source
            Destination = $Destination
            RemovedPixels = $removedCount
        }
    } finally {
        $bitmap.Dispose()
    }
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

foreach ($path in $InputPath) {
    $item = Get-Item -LiteralPath $path
    $destination = Join-Path $OutputDirectory ($item.BaseName + "_removebg.png")
    Remove-BlackBackground -Source $item.FullName -Destination $destination -Threshold $Threshold -MinBackgroundComponent $MinBackgroundComponent
}
