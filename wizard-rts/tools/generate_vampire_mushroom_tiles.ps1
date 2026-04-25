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

function Draw-MatteDiamond($g, [string]$base, [string]$rim, [int]$topY = 16, [int]$midY = 48, [int]$bottomY = 80, [int]$rimAlpha = 24) {
    $points = @((Pt 55 $topY), (Pt 108 $midY), (Pt 55 $bottomY), (Pt 2 $midY))
    Poly $g $base $points "" 1
    for ($i = 0; $i -lt 5; $i++) {
        $shrink = $i * 4
        $alpha = [Math]::Max(10, 42 - $i * 7)
        $brush = Brush-Hex $rim $alpha
        $inner = @((Pt 55 ($topY + $shrink)), (Pt (108 - $shrink) $midY), (Pt 55 ($bottomY - $shrink)), (Pt (2 + $shrink) $midY))
        $g.FillPolygon($brush, [System.Drawing.PointF[]]$inner)
        $brush.Dispose()
    }
    if ($rimAlpha -gt 0) {
        Line $g $rim 1.0 55 $topY 108 $midY $rimAlpha
        Line $g $rim 1.0 108 $midY 55 $bottomY $rimAlpha
        Line $g $rim 1.0 55 $bottomY 2 $midY $rimAlpha
        Line $g $rim 1.0 2 $midY 55 $topY $rimAlpha
    }
}

function Add-Soft-Blotches($g, [System.Random]$rng, [string[]]$colors, [int]$count, [int]$alpha = 44) {
    for ($i = 0; $i -lt $count; $i++) {
        $x = $rng.Next(-8, 88)
        $y = $rng.Next(16, 64)
        if ([Math]::Abs($x + 18 - 55) * 0.58 + [Math]::Abs($y + 8 - 48) -lt 42) {
            $color = $colors[$rng.Next(0, $colors.Count)]
            Ellipse $g $color $x $y $rng.Next(20, 54) $rng.Next(8, 24) $alpha
        }
    }
}

function Add-Matte-Grain($g, [System.Random]$rng, [string]$light, [string]$dark, [int]$count) {
    for ($i = 0; $i -lt $count; $i++) {
        $x = $rng.Next(9, 101)
        $y = $rng.Next(24, 72)
        if ([Math]::Abs($x - 55) * 0.62 + [Math]::Abs($y - 48) -lt 34) {
            if ($rng.NextDouble() -lt 0.70) {
                Ellipse $g $light $x $y $rng.Next(1, 4) $rng.Next(1, 3) $rng.Next(36, 84)
            } else {
                Line $g $dark 1.0 $x $y ($x + $rng.Next(-6, 7)) ($y + $rng.Next(-2, 3)) $rng.Next(34, 76)
            }
        }
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
    Draw-MatteDiamond $g "#132A22" "#4a8a5c" 17 49 81 18
    Add-Soft-Blotches $g $rng @("#0A1612", "#1E3A2D", "#2D5A3E") 14 36
    Add-Matte-Grain $g $rng "#7BC47F" "#0A1612" 68
    for ($i = 0; $i -lt 5; $i++) { Ellipse $g "#8b1a1f" ($rng.Next(22, 86)) ($rng.Next(34, 61)) $rng.Next(3, 6) $rng.Next(2, 4) 150 }
    Save-Image $bmp $g ("low_ground_vm_{0:D2}.png" -f $variant)
}

function Tile-Mid([int]$variant) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(200 + $variant)
    Draw-MatteDiamond $g "#2B4E39" "#8A7560" 12 45 78 24
    Add-Soft-Blotches $g $rng @("#1E3A2D", "#345F43", "#223C32") 15 34
    Add-Matte-Grain $g $rng "#D6C7AE" "#142420" 76
    Line $g "#D6C7AE" 1.0 13 47 55 74 42
    Line $g "#D6C7AE" 1.0 98 47 55 74 38
    Save-Image $bmp $g ("mid_ground_vm_{0:D2}.png" -f $variant)
}

function Tile-High([int]$variant) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(300 + $variant)
    Draw-MatteDiamond $g "#5E7154" "#D6C7AE" 7 41 75 46
    Add-Soft-Blotches $g $rng @("#4D6148", "#6B8061", "#394C3E") 16 35
    Add-Matte-Grain $g $rng "#F0E5CC" "#2D5A3E" 82
    Line $g "#F0E5CC" 1.6 9 41 55 9 90
    Line $g "#F0E5CC" 1.6 55 9 102 41 90
    Save-Image $bmp $g ("high_ground_vm_{0:D2}.png" -f $variant)
}

function Tile-Water([int]$variant) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(400 + $variant)
    Draw-MatteDiamond $g "#0E2C32" "#3FA8B5" 17 49 81 20
    Add-Soft-Blotches $g $rng @("#1A4F5C", "#0A1612", "#123A42") 10 36
    for ($i = 0; $i -lt 10; $i++) { Line $g "#7DDDE8" 1.2 ($rng.Next(14, 94)) ($rng.Next(34, 62)) ($rng.Next(14, 94)) ($rng.Next(35, 67)) 92 }
    for ($i = 0; $i -lt 7; $i++) { Ellipse $g "#3FA8B5" ($rng.Next(18, 88)) ($rng.Next(35, 61)) $rng.Next(8, 18) 3 92 }
    Save-Image $bmp $g ("water_vm_{0:D2}.png" -f $variant)
}

function Tile-Cliff([int]$variant) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(500 + $variant)
    Poly $g "#050807" @((Pt 6 22), (Pt 55 8), (Pt 105 22), (Pt 105 74), (Pt 55 118), (Pt 6 74)) "" 1
    Draw-MatteDiamond $g "#201A15" "#8A7560" 8 33 58 58
    Poly $g "#0A1612" @((Pt 6 33), (Pt 55 58), (Pt 55 118), (Pt 6 74)) "" 1
    Poly $g "#17110E" @((Pt 105 33), (Pt 55 58), (Pt 55 118), (Pt 105 74)) "" 1
    for ($i = 0; $i -lt 14; $i++) { Line $g "#5C4838" 1.6 ($rng.Next(12, 98)) ($rng.Next(42, 72)) ($rng.Next(10, 100)) ($rng.Next(78, 116)) 130 }
    for ($i = 0; $i -lt 5; $i++) { Line $g "#8B1A1F" 1.8 ($rng.Next(14, 96)) ($rng.Next(30, 54)) ($rng.Next(12, 98)) ($rng.Next(76, 112)) 150 }
    Save-Image $bmp $g ("cliff_vm_{0:D2}.png" -f $variant)
}

function Tile-Path([int]$variant, [bool]$slope) {
    $img = New-Image; $bmp = $img[0]; $g = $img[1]; $rng = [System.Random]::new(600 + $variant + ($(if ($slope) { 30 } else { 0 })))
    Draw-MatteDiamond $g "#332820" "#8A7560" 17 49 81 28
    $main = if ($slope) { "#8a7560" } else { "#5c4838" }
    Poly $g $main @((Pt 16 49), (Pt 55 26), (Pt 95 49), (Pt 55 72)) "" 1
    Add-Soft-Blotches $g $rng @("#8A7560", "#332820", "#D6C7AE") 8 32
    for ($i = 0; $i -lt 18; $i++) { Ellipse $g "#D6C7AE" ($rng.Next(22, 86)) ($rng.Next(34, 62)) $rng.Next(2, 5) $rng.Next(1, 3) 105 }
    if ($slope) {
        Line $g "#D6C7AE" 2.4 24 56 88 36 160
        Line $g "#3FA8B5" 1.5 32 61 80 44 110
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
