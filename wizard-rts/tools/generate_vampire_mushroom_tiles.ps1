Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"
$OutDir = Join-Path (Get-Location) "assets\tiles\voxel"

function New-Image {
    $bmp = New-Object System.Drawing.Bitmap 111, 128, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    return @($bmp, $g)
}

function Color-Hex([string]$hex, [int]$alpha = 255) {
    $hex = $hex.TrimStart("#")
    return [System.Drawing.Color]::FromArgb($alpha,
        [Convert]::ToInt32($hex.Substring(0, 2), 16),
        [Convert]::ToInt32($hex.Substring(2, 2), 16),
        [Convert]::ToInt32($hex.Substring(4, 2), 16))
}

function Brush-Hex([string]$hex, [int]$alpha = 255) {
    return New-Object System.Drawing.SolidBrush (Color-Hex $hex $alpha)
}

function Pen-Hex([string]$hex, [float]$width = 1.0, [int]$alpha = 255) {
    return New-Object System.Drawing.Pen (Color-Hex $hex $alpha), $width
}

function Pt([float]$x, [float]$y) {
    return New-Object System.Drawing.PointF $x, $y
}

function Poly($g, [string]$fill, [array]$points, [string]$stroke = "", [float]$strokeWidth = 1.0, [int]$strokeAlpha = 90) {
    $brush = Brush-Hex $fill
    $g.FillPolygon($brush, [System.Drawing.PointF[]]$points)
    $brush.Dispose()
    if ($stroke -ne "") {
        $pen = Pen-Hex $stroke $strokeWidth $strokeAlpha
        $g.DrawPolygon($pen, [System.Drawing.PointF[]]$points)
        $pen.Dispose()
    }
}

function Line($g, [string]$color, [float]$width, [float]$x1, [float]$y1, [float]$x2, [float]$y2, [int]$alpha = 255) {
    $pen = Pen-Hex $color $width $alpha
    $g.DrawLine($pen, $x1, $y1, $x2, $y2)
    $pen.Dispose()
}

function Ellipse($g, [string]$color, [float]$x, [float]$y, [float]$w, [float]$h, [int]$alpha = 255) {
    $brush = Brush-Hex $color $alpha
    $g.FillEllipse($brush, $x, $y, $w, $h)
    $brush.Dispose()
}

function Save-Image($bmp, $g, [string]$name) {
    $path = Join-Path $OutDir $name
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function Draw-Diamond($g, [string]$fill, [string]$edge, [int]$topY = 16, [int]$midY = 48, [int]$bottomY = 80, [int]$edgeAlpha = 42) {
    $points = @((Pt 55 $topY), (Pt 108 $midY), (Pt 55 $bottomY), (Pt 2 $midY))
    Poly $g $fill $points "" 1
    if ($edge -ne "" -and $edgeAlpha -gt 0) {
        Line $g $edge 1.0 55 $topY 108 $midY $edgeAlpha
        Line $g $edge 1.0 108 $midY 55 $bottomY $edgeAlpha
        Line $g $edge 1.0 55 $bottomY 2 $midY $edgeAlpha
        Line $g $edge 1.0 2 $midY 55 $topY $edgeAlpha
    }
}

function Add-Ground-Texture($g, [System.Random]$rng, [string]$dot, [string]$line, [int]$count) {
    for ($i = 0; $i -lt $count; $i++) {
        $x = $rng.Next(12, 98)
        $y = $rng.Next(28, 68)
        if ([Math]::Abs($x - 55) * 0.62 + [Math]::Abs($y - 48) -lt 33) {
            if ($rng.NextDouble() -lt 0.55) {
                Ellipse $g $dot $x $y $rng.Next(2, 5) $rng.Next(1, 4) 180
            } else {
                Line $g $line 1.3 $x $y ($x + $rng.Next(-8, 9)) ($y + $rng.Next(-3, 4)) 150
            }
        }
    }
}

function Tile-Low([int]$variant) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(100 + $variant)
    Draw-Diamond $g "#10261f" "#4a8a5c" 17 49 81 18
    Poly $g "#0a1612" @((Pt 2 49), (Pt 55 81), (Pt 108 49), (Pt 55 88)) "" 1
    Draw-Diamond $g "#163326" "#7bc47f" 17 49 78 20
    for ($i = 0; $i -lt 8; $i++) { Ellipse $g "#1e3a2d" ($rng.Next(2, 88)) ($rng.Next(22, 62)) $rng.Next(22, 42) $rng.Next(8, 20) 55 }
    Add-Ground-Texture $g $rng "#7bc47f" "#2d5a3e" 46
    for ($i = 0; $i -lt 5; $i++) { Ellipse $g "#8b1a1f" ($rng.Next(20, 90)) ($rng.Next(32, 62)) 4 3 210 }
    Save-Image $bmp $g ("low_ground_vm_{0:D2}.png" -f $variant)
}

function Tile-Mid([int]$variant) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(200 + $variant)
    Draw-Diamond $g "#254332" "#8a7560" 12 45 78 20
    for ($i = 0; $i -lt 11; $i++) { Ellipse $g "#2d5a3e" ($rng.Next(-6, 88)) ($rng.Next(18, 60)) $rng.Next(28, 54) $rng.Next(8, 22) 58 }
    for ($i = 0; $i -lt 5; $i++) { Ellipse $g "#142420" ($rng.Next(8, 86)) ($rng.Next(30, 66)) $rng.Next(20, 40) $rng.Next(7, 16) 46 }
    Add-Ground-Texture $g $rng "#d6c7ae" "#4a8a5c" 55
    Line $g "#d6c7ae" 1.0 10 49 55 76 38
    Line $g "#d6c7ae" 1.0 101 49 55 76 34
    Save-Image $bmp $g ("mid_ground_vm_{0:D2}.png" -f $variant)
}

function Tile-High([int]$variant) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(300 + $variant)
    Draw-Diamond $g "#52684e" "#d6c7ae" 7 41 75 50
    for ($i = 0; $i -lt 12; $i++) { Ellipse $g "#5e7453" ($rng.Next(-6, 88)) ($rng.Next(14, 56)) $rng.Next(26, 54) $rng.Next(8, 22) 62 }
    for ($i = 0; $i -lt 7; $i++) { Ellipse $g "#3f503f" ($rng.Next(8, 86)) ($rng.Next(26, 63)) $rng.Next(20, 42) $rng.Next(7, 16) 46 }
    Add-Ground-Texture $g $rng "#d6c7ae" "#7bc47f" 58
    Line $g "#f0e5cc" 1.8 8 41 55 9 96
    Line $g "#f0e5cc" 1.8 55 9 103 41 96
    Save-Image $bmp $g ("high_ground_vm_{0:D2}.png" -f $variant)
}

function Tile-Water([int]$variant) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(400 + $variant)
    Draw-Diamond $g "#0e2c32" "#3fa8b5" 17 49 81 20
    for ($i = 0; $i -lt 8; $i++) { Line $g "#7ddde8" 1.5 ($rng.Next(14, 94)) ($rng.Next(34, 62)) ($rng.Next(14, 94)) ($rng.Next(35, 67)) 120 }
    for ($i = 0; $i -lt 6; $i++) { Ellipse $g "#1a4f5c" ($rng.Next(18, 88)) ($rng.Next(35, 61)) 9 3 180 }
    Save-Image $bmp $g ("water_vm_{0:D2}.png" -f $variant)
}

function Tile-Cliff([int]$variant) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(500 + $variant)
    Poly $g "#060908" @((Pt 6 22), (Pt 55 8), (Pt 105 22), (Pt 105 74), (Pt 55 118), (Pt 6 74)) "" 1
    Draw-Diamond $g "#1a1410" "#5c4838" 8 33 58 70
    Poly $g "#0a1612" @((Pt 6 33), (Pt 55 58), (Pt 55 118), (Pt 6 74)) "#050807" 1
    Poly $g "#1a1410" @((Pt 105 33), (Pt 55 58), (Pt 55 118), (Pt 105 74)) "#050807" 1
    for ($i = 0; $i -lt 10; $i++) { Line $g "#5c4838" 2 ($rng.Next(12, 98)) ($rng.Next(42, 72)) ($rng.Next(10, 100)) ($rng.Next(78, 116)) 190 }
    for ($i = 0; $i -lt 4; $i++) { Line $g "#8b1a1f" 2 ($rng.Next(14, 96)) ($rng.Next(30, 54)) ($rng.Next(12, 98)) ($rng.Next(76, 112)) 210 }
    Save-Image $bmp $g ("cliff_vm_{0:D2}.png" -f $variant)
}

function Tile-Path([int]$variant, [bool]$slope) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(600 + $variant + ($(if ($slope) { 30 } else { 0 })))
    Draw-Diamond $g "#332820" "#8a7560" 17 49 81 28
    $main = if ($slope) { "#8a7560" } else { "#5c4838" }
    Poly $g $main @((Pt 16 49), (Pt 55 26), (Pt 95 49), (Pt 55 72)) "#d6c7ae" 1.2 72
    for ($i = 0; $i -lt 16; $i++) { Ellipse $g "#d6c7ae" ($rng.Next(22, 86)) ($rng.Next(34, 62)) $rng.Next(2, 6) $rng.Next(1, 4) 170 }
    if ($slope) {
        Line $g "#d6c7ae" 3 24 56 88 36 200
        Line $g "#3fa8b5" 2 32 61 80 44 160
    }
    Save-Image $bmp $g ($(if ($slope) { "path_slope_vm_{0:D2}.png" } else { "path_vm_{0:D2}.png" }) -f $variant)
}

function Tile-Economy([int]$variant) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(700 + $variant)
    Draw-Diamond $g "#1e3a2d" "#d6c7ae" 17 49 81 58
    for ($i = 0; $i -lt 10; $i++) { Ellipse $g "#d6c7ae" ($rng.Next(18, 86)) ($rng.Next(31, 61)) $rng.Next(6, 13) $rng.Next(4, 8) 230 }
    Ellipse $g "#7ddde8" 47 39 16 10 170
    Line $g "#7ddde8" 2 55 33 55 66 160
    Save-Image $bmp $g ("economy_plot_vm_{0:D2}.png" -f $variant)
}

function Tile-Foliage([int]$variant, [bool]$giant = $false) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(800 + $variant + ($(if ($giant) { 50 } else { 0 })))
    Draw-Diamond $g "#0a1612" "#2d5a3e" 17 49 81 10
    for ($i = 0; $i -lt 14; $i++) { Line $g "#1a1410" $rng.Next(2, 5) ($rng.Next(8, 104)) ($rng.Next(34, 72)) ($rng.Next(8, 104)) ($rng.Next(0, 44)) 230 }
    for ($i = 0; $i -lt 8; $i++) { Ellipse $g "#8b1a1f" ($rng.Next(10, 88)) ($rng.Next(12, 54)) $rng.Next(12, 24) $rng.Next(7, 13) 235 }
    for ($i = 0; $i -lt 16; $i++) { Ellipse $g "#7ddde8" ($rng.Next(12, 96)) ($rng.Next(30, 70)) 3 3 160 }
    if ($giant) {
        Line $g "#332820" 12 55 34 55 91 255
        Ellipse $g "#8b1a1f" 17 6 76 36 255
        for ($i = 0; $i -lt 14; $i++) { Ellipse $g "#d6c7ae" ($rng.Next(24, 84)) ($rng.Next(12, 34)) 3 3 230 }
    }
    Save-Image $bmp $g ($(if ($giant) { "giant_mushroom_vm_{0:D2}.png" } else { "foliage_vm_{0:D2}.png" }) -f $variant)
}

function Tile-Ruin([int]$variant, [string]$name) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(900 + $variant + $name.Length)
    Draw-Diamond $g "#332820" "#8a7560" 17 49 81 28
    for ($i = 0; $i -lt 9; $i++) {
        $x = $rng.Next(16, 78); $y = $rng.Next(31, 58)
        Poly $g "#8a7560" @((Pt $x $y), (Pt ($x+18) ($y+6)), (Pt ($x+8) ($y+13)), (Pt ($x-9) ($y+6))) "#d6c7ae" 1 80
    }
    if ($name -like "*wall*") {
        Poly $g "#1a1410" @((Pt 18 25), (Pt 55 8), (Pt 94 25), (Pt 94 47), (Pt 55 66), (Pt 18 47)) "#d6c7ae" 1.4 110
        Line $g "#7ddde8" 2 55 14 55 58 180
    }
    Save-Image $bmp $g ("{0}_vm_{1:D2}.png" -f $name, $variant)
}

for ($i = 1; $i -le 3; $i++) {
    Tile-Low $i
    Tile-Mid $i
    Tile-High $i
    Tile-Water $i
    Tile-Cliff $i
    Tile-Path $i $false
    Tile-Path $i $true
    Tile-Economy $i
    Tile-Foliage $i $false
    Tile-Foliage $i $true
    Tile-Ruin $i "ruin_floor"
    Tile-Ruin $i "wizard_tower_floor"
    Tile-Ruin $i "wizard_tower_wall"
    Tile-Ruin $i "bandit_floor"
    Tile-Ruin $i "bandit_wall"
}
