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

    $failed = $false

    Write-Host "size: $($bitmap.Width)x$($bitmap.Height)"
    if ($bitmap.Width -ne 256 -or $bitmap.Height -ne 224) {
        Write-Host "size: expected H32 256x224"
        $failed = $true
    }

    $hudPixels = Count-NonBlackPixels $bitmap 0 0 256 56
    Write-Host "hud_area: non_black=$hudPixels"
    if ($hudPixels -lt 50) {
        Write-Host "hud_area: expected rendered HUD tiles"
        $failed = $true
    }

    $roomPixels = Count-NonBlackPixels $bitmap 0 56 256 224
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
