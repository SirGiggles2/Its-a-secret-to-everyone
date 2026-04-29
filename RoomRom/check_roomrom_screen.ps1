param(
    [string]$PngPath = "$PSScriptRoot\out\roomrom_screen.png"
)

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path -LiteralPath $PngPath)) {
    Write-Error "Screenshot not found: $PngPath"
    exit 2
}

$bitmap = [System.Drawing.Bitmap]::FromFile($PngPath)
try {
    $blackLimit = 16

    function Test-IsBlack([System.Drawing.Color]$color) {
        return ($color.R -le $blackLimit -and $color.G -le $blackLimit -and $color.B -le $blackLimit)
    }

    function Count-NonBlackPixels([System.Drawing.Bitmap]$image, [int]$x0, [int]$y0, [int]$x1, [int]$y1) {
        $count = 0
        for ($y = $y0; $y -lt $y1; $y += 4) {
            for ($x = $x0; $x -lt $x1; $x += 4) {
                if (-not (Test-IsBlack $image.GetPixel($x, $y))) {
                    $count++
                }
            }
        }
        return $count
    }

    $zones = @(
        @{ Name = "hud_top"; X0 = 0;   Y0 = 0;   X1 = 320; Y1 = 16  },
        @{ Name = "right_border"; X0 = 256; Y0 = 16;  X1 = 320; Y1 = 192 },
        @{ Name = "bottom_border"; X0 = 0;   Y0 = 192; X1 = 320; Y1 = 224 }
    )

    $failed = $false
    foreach ($zone in $zones) {
        $nonBlack = Count-NonBlackPixels $bitmap $zone.X0 $zone.Y0 $zone.X1 $zone.Y1
        Write-Host "$($zone.Name): non_black=$nonBlack"
        if ($nonBlack -ne 0) {
            $failed = $true
        }
    }

    $roomPixels = Count-NonBlackPixels $bitmap 0 16 256 192
    Write-Host "room_content: non_black=$roomPixels"
    if ($roomPixels -lt 500) {
        Write-Host "room_content: expected rendered overworld tiles"
        $failed = $true
    }

    if ($failed) {
        exit 1
    }

    exit 0
}
finally {
    $bitmap.Dispose()
}
