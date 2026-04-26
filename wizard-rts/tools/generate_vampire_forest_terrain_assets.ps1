$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$OutDir = Join-Path (Resolve-Path ".").Path "assets\tiles\voxel"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function ColorFromHex($hex, [int]$alpha = 255) {
    $c = [System.Drawing.ColorTranslator]::FromHtml($hex)
    return [System.Drawing.Color]::FromArgb($alpha, $c.R, $c.G, $c.B)
}

function Brush($hex, [int]$alpha = 255) {
    return [System.Drawing.SolidBrush]::new((ColorFromHex $hex $alpha))
}

function PenC($hex, [float]$width, [int]$alpha = 255) {
    return [System.Drawing.Pen]::new((ColorFromHex $hex $alpha), $width)
}

function NewTile() {
    $bmp = [System.Drawing.Bitmap]::new(111, 128, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bmp.SetResolution(96, 96)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    return @($bmp, $g)
}

function Poly($points) {
    $arr = New-Object System.Drawing.PointF[] $points.Count
    for ($i = 0; $i -lt $points.Count; $i++) {
        $arr[$i] = [System.Drawing.PointF]::new([float]$points[$i][0], [float]$points[$i][1])
    }
    return $arr
}

function DrawDiamond($g, $fill, $edge = $null) {
    $p = Poly @(@(55, 22), @(108, 56), @(55, 90), @(2, 56))
    $g.FillPolygon($fill, $p)
    if ($edge -ne $null) { $g.DrawPolygon($edge, $p) }
}

function DrawTileNoise($g, [int]$seed, $colors, [int]$count, [float]$alphaScale = 1.0) {
    $rng = [System.Random]::new($seed)
    for ($i = 0; $i -lt $count; $i++) {
        $x = $rng.Next(12, 99)
        $y = $rng.Next(34, 83)
        if ([math]::Abs($x - 55) / 53.0 + [math]::Abs($y - 56) / 34.0 - 0.18 - $rng.NextDouble() * 0.12 -gt 1.0) { continue }
        $col = $colors[$rng.Next(0, $colors.Count)]
        $a = [int](35 + $rng.Next(0, 65) * $alphaScale)
        $b = Brush $col $a
        $g.FillEllipse($b, [float]$x, [float]$y, [float]$rng.Next(2, 7), [float]$rng.Next(1, 4))
        $b.Dispose()
    }
}

function DrawRoots($g, [int]$seed, [string]$color, [int]$count) {
    $rng = [System.Random]::new($seed)
    $pen = PenC $color 2 120
    for ($i = 0; $i -lt $count; $i++) {
        $x = $rng.Next(12, 96)
        $y = $rng.Next(42, 76)
        $dx = $rng.Next(-18, 19)
        $dy = $rng.Next(-8, 9)
        $g.DrawBezier($pen, [float]$x, [float]$y, [float]($x + $dx * 0.35), [float]($y - 7), [float]($x + $dx * 0.65), [float]($y + 7), [float]($x + $dx), [float]($y + $dy))
    }
    $pen.Dispose()
}

function SaveTile($name, [scriptblock]$draw) {
    $tile = NewTile
    $bmp = $tile[0]
    $g = $tile[1]
    & $draw $g
    $path = Join-Path $OutDir $name
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

function BaseGround($g, $base, $edge, [int]$seed, [int]$level) {
    DrawDiamond $g (Brush $base 255) (PenC $edge 2 190)
    DrawTileNoise $g $seed @("#142420", "#1E3A2D", "#2D5A3E", "#332820") 60 1.0
    DrawRoots $g ($seed + 71) "#0A1612" 7
    if ($level -ge 1) {
        $lip = PenC "#8A7560" 2 140
        $g.DrawLine($lip, 5, 57, 55, 89)
        $g.DrawLine($lip, 106, 57, 55, 89)
        $lip.Dispose()
    }
    if ($level -ge 2) {
        $glow = PenC "#7BC47F" 1.5 90
        $g.DrawLine($glow, 9, 53, 55, 25)
        $g.DrawLine($glow, 102, 53, 55, 25)
        $glow.Dispose()
    }
}

for ($i = 1; $i -le 3; $i++) {
    $n = "{0:00}" -f $i
    SaveTile "low_ground_vm_$n.png" { param($g) BaseGround $g "#142420" "#24372F" (100 + $i) 0 }
    SaveTile "mid_ground_vm_$n.png" { param($g) BaseGround $g "#1E3A2D" "#4A8A5C" (200 + $i) 1 }
    SaveTile "high_ground_vm_$n.png" { param($g) BaseGround $g "#2D5A3E" "#8A7560" (300 + $i) 2 }
}

for ($i = 1; $i -le 3; $i++) {
    $n = "{0:00}" -f $i
    SaveTile "water_vm_$n.png" {
        param($g)
        DrawDiamond $g (Brush "#0E2C32" 235) (PenC "#1A4F5C" 2 190)
        DrawTileNoise $g (410 + $i) @("#1A4F5C", "#3FA8B5", "#7DDDE8") 28 0.8
        $p1 = PenC "#3FA8B5" 2 90
        $p2 = PenC "#7DDDE8" 1 95
        $g.DrawBezier($p1, 18, 56, 34, 49, 50, 66, 69, 55)
        $g.DrawBezier($p2, 38, 66, 51, 59, 64, 76, 88, 62)
        $p1.Dispose(); $p2.Dispose()
    }
}

for ($i = 1; $i -le 3; $i++) {
    $n = "{0:00}" -f $i
    SaveTile "cliff_vm_$n.png" {
        param($g)
        DrawDiamond $g (Brush "#0A1612" 255) (PenC "#332820" 2 200)
        $face = Poly @(@(2,56), @(55,90), @(108,56), @(108,84), @(55,120), @(2,84))
        $g.FillPolygon((Brush "#050807" 235), $face)
        DrawRoots $g (520 + $i) "#5C0F14" 12
        $edge = PenC "#8A7560" 3 145
        $g.DrawLine($edge, 4, 56, 55, 88)
        $g.DrawLine($edge, 106, 56, 55, 88)
        $edge.Dispose()
    }
}

for ($i = 1; $i -le 3; $i++) {
    $n = "{0:00}" -f $i
    SaveTile "path_slope_vm_$n.png" {
        param($g)
        BaseGround $g "#1A1410" "#8A7560" (620 + $i) 1
        $stone = Brush "#5C4838" 150
        $bone = Brush "#D6C7AE" 135
        for ($s = 0; $s -lt 7; $s++) {
            $y = 38 + $s * 6
            $g.FillRectangle($stone, 22 + ($s % 2) * 6, $y, 66, 3)
            if ($s % 3 -eq 0) { $g.FillEllipse($bone, 48, $y - 2, 7, 4) }
        }
        $stone.Dispose(); $bone.Dispose()
    }
    SaveTile "path_vm_$n.png" {
        param($g)
        DrawDiamond $g (Brush "#332820" 250) (PenC "#5C4838" 2 145)
        DrawTileNoise $g (720 + $i) @("#8A7560", "#5C4838", "#D6C7AE", "#1A1410") 70 0.9
    }
}

for ($i = 1; $i -le 3; $i++) {
    $n = "{0:00}" -f $i
    SaveTile "ruin_floor_vm_$n.png" {
        param($g)
        DrawDiamond $g (Brush "#332820" 255) (PenC "#8A7560" 2 160)
        $rng = [System.Random]::new(820 + $i)
        for ($s = 0; $s -lt 18; $s++) {
            $x = $rng.Next(16, 82); $y = $rng.Next(38, 78)
            $b = Brush $(if ($s % 4 -eq 0) { "#8A7560" } else { "#5C4838" }) 150
            $g.FillRectangle($b, $x, $y, $rng.Next(7, 17), $rng.Next(4, 10))
            $b.Dispose()
        }
    }
    SaveTile "wizard_tower_floor_vm_$n.png" { param($g) BaseGround $g "#332820" "#D6C7AE" (850 + $i) 1 }
    SaveTile "bandit_floor_vm_$n.png" { param($g) BaseGround $g "#1A1410" "#5C4838" (880 + $i) 0 }
}

for ($i = 1; $i -le 3; $i++) {
    $n = "{0:00}" -f $i
    SaveTile "wizard_tower_wall_vm_$n.png" {
        param($g)
        DrawDiamond $g (Brush "#0A1612" 120) $null
        $wall = Brush "#8A7560" 245
        $dark = Brush "#332820" 230
        $g.FillRectangle($dark, 28, 30, 55, 52)
        $g.FillRectangle($wall, 31, 25, 49, 22)
        $g.FillEllipse((Brush "#7DDDE8" 165), 48, 40, 14, 18)
        DrawRoots $g (910 + $i) "#5C0F14" 7
        $wall.Dispose(); $dark.Dispose()
    }
    SaveTile "bandit_wall_vm_$n.png" {
        param($g)
        DrawDiamond $g (Brush "#0A1612" 110) $null
        $bark = Brush "#332820" 245
        $bone = Brush "#8A7560" 210
        $g.FillRectangle($bark, 25, 38, 62, 32)
        for ($s = 0; $s -lt 6; $s++) { $g.FillRectangle($bone, 27 + $s * 10, 30 + ($s % 2) * 5, 5, 42) }
        $bark.Dispose(); $bone.Dispose()
    }
}

for ($i = 1; $i -le 3; $i++) {
    $n = "{0:00}" -f $i
    SaveTile "economy_plot_vm_$n.png" {
        param($g)
        BaseGround $g "#1E3A2D" "#7BC47F" (1010 + $i) 0
        $ring = PenC "#7DDDE8" 3 170
        $g.DrawEllipse($ring, 36, 43, 38, 24)
        $g.DrawEllipse((PenC "#8B1A1F" 2 170), 42, 47, 26, 16)
        $ring.Dispose()
    }
    SaveTile "foliage_vm_$n.png" {
        param($g)
        DrawDiamond $g (Brush "#0A1612" 95) $null
        $rng = [System.Random]::new(1110 + $i)
        for ($m = 0; $m -lt 9; $m++) {
            $x = $rng.Next(16, 94); $y = $rng.Next(42, 84)
            $g.FillEllipse((Brush "#8B1A1F" 230), $x, $y - 13, $rng.Next(10, 18), $rng.Next(6, 11))
            $g.DrawLine((PenC "#D6C7AE" 2 185), $x + 5, $y, $x + 5, $y - 9)
        }
    }
    SaveTile "giant_mushroom_vm_$n.png" {
        param($g)
        DrawDiamond $g (Brush "#0A1612" 60) $null
        $stem = PenC "#D6C7AE" 8 215
        $g.DrawLine($stem, 55, 84, 55, 32)
        $g.DrawLine((PenC "#5C4838" 3 190), 49, 84, 34, 103)
        $g.DrawLine((PenC "#5C4838" 3 190), 61, 84, 80, 103)
        $g.FillEllipse((Brush "#8B1A1F" 245), 24, 17, 62, 29)
        $g.FillEllipse((Brush "#E85A5A" 155), 37, 19, 34, 15)
        $g.FillEllipse((Brush "#D6C7AE" 185), 49, 25, 9, 5)
        $stem.Dispose()
    }
}

Write-Output "Generated Vampiric Mushroom Forest terrain assets in $OutDir"
