param(
    [Parameter(Mandatory = $true)]
    [string]$InputDirectory,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [int]$KeepDistance = 48,
    [int]$NearBlackThreshold = 12
)

Add-Type -AssemblyName System.Drawing

function Get-BoxDistance {
    param(
        [hashtable]$A,
        [hashtable]$B
    )

    $dx = 0
    if ($A.MaxX -lt $B.MinX) {
        $dx = $B.MinX - $A.MaxX
    } elseif ($B.MaxX -lt $A.MinX) {
        $dx = $A.MinX - $B.MaxX
    }

    $dy = 0
    if ($A.MaxY -lt $B.MinY) {
        $dy = $B.MinY - $A.MaxY
    } elseif ($B.MaxY -lt $A.MinY) {
        $dy = $A.MinY - $B.MaxY
    }

    return [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
}

function Find-Components {
    param([System.Drawing.Bitmap]$Bitmap)

    $width = $Bitmap.Width
    $height = $Bitmap.Height
    $total = $width * $height
    $visited = New-Object bool[] $total
    $queue = New-Object int[] $total
    $components = New-Object System.Collections.Generic.List[hashtable]

    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $idx = ($y * $width) + $x
            if ($visited[$idx]) { continue }

            $color = $Bitmap.GetPixel($x, $y)
            if ($color.A -eq 0) {
                $visited[$idx] = $true
                continue
            }

            $head = 0
            $tail = 0
            $pixels = New-Object System.Collections.Generic.List[int]
            $visited[$idx] = $true
            $queue[$tail] = $idx
            $tail++
            $minX = $x
            $maxX = $x
            $minY = $y
            $maxY = $y
            $nearBlack = 0

            while ($head -lt $tail) {
                $current = $queue[$head]
                $head++
                $pixels.Add($current)
                $cx = $current % $width
                $cy = [int][Math]::Floor($current / $width)
                if ($cx -lt $minX) { $minX = $cx }
                if ($cx -gt $maxX) { $maxX = $cx }
                if ($cy -lt $minY) { $minY = $cy }
                if ($cy -gt $maxY) { $maxY = $cy }

                $c = $Bitmap.GetPixel($cx, $cy)
                if ($c.R -le $NearBlackThreshold -and $c.G -le $NearBlackThreshold -and $c.B -le $NearBlackThreshold) {
                    $nearBlack++
                }

                for ($oy = -1; $oy -le 1; $oy++) {
                    for ($ox = -1; $ox -le 1; $ox++) {
                        if ($ox -eq 0 -and $oy -eq 0) { continue }
                        $nx = $cx + $ox
                        $ny = $cy + $oy
                        if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $width -or $ny -ge $height) { continue }
                        $next = ($ny * $width) + $nx
                        if ($visited[$next]) { continue }
                        $nextColor = $Bitmap.GetPixel($nx, $ny)
                        if ($nextColor.A -gt 0) {
                            $visited[$next] = $true
                            $queue[$tail] = $next
                            $tail++
                        }
                    }
                }
            }

            $components.Add(@{
                Pixels = $pixels
                Count = $pixels.Count
                MinX = $minX
                MaxX = $maxX
                MinY = $minY
                MaxY = $maxY
                NearBlackRatio = if ($pixels.Count -gt 0) { $nearBlack / $pixels.Count } else { 0 }
            })
        }
    }

    return $components
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$files = Get-ChildItem -LiteralPath $InputDirectory -Filter '*_removebg.png' | Sort-Object Name
foreach ($file in $files) {
    $bitmap = [System.Drawing.Bitmap]::FromFile($file.FullName)
    try {
        $components = Find-Components -Bitmap $bitmap
        $main = $components | Sort-Object { $_["Count"] } -Descending | Select-Object -First 1
        $output = New-Object System.Drawing.Bitmap $bitmap.Width, $bitmap.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            for ($y = 0; $y -lt $bitmap.Height; $y++) {
                for ($x = 0; $x -lt $bitmap.Width; $x++) {
                    $output.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
                }
            }

            $removed = 0
            foreach ($component in $components) {
                $distance = Get-BoxDistance -A $component -B $main
                $keep = $component -eq $main -or ($distance -le $KeepDistance -and $component["NearBlackRatio"] -lt 0.95)
                if ($component["Count"] -le 8 -and $distance -le ($KeepDistance + 20)) {
                    $keep = $true
                }

                if ($keep) {
                    foreach ($idx in $component.Pixels) {
                        $x = $idx % $bitmap.Width
                        $y = [int][Math]::Floor($idx / $bitmap.Width)
                        $output.SetPixel($x, $y, $bitmap.GetPixel($x, $y))
                    }
                } else {
                    $removed += $component["Count"]
                }
            }

            $destination = Join-Path $OutputDirectory $file.Name
            $output.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
            [pscustomobject]@{
                Name = $file.Name
                Components = $components.Count
                RemovedPixels = $removed
                Destination = $destination
            }
        } finally {
            $output.Dispose()
        }
    } finally {
        $bitmap.Dispose()
    }
}
