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

function DiamondPoints() {
    return Poly @(@(55, 22), @(108, 56), @(55, 90), @(2, 56))
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

function DrawMatteFloor($g, [string]$base, [string]$edge, [string]$fleck, [int]$seed, [int]$level) {
    $diamond = DiamondPoints
    $g.FillPolygon((Brush $base 255), $diamond)
    $g.DrawPolygon((PenC $edge 1.0 34), $diamond)

    $rng = [System.Random]::new($seed)
    for ($i = 0; $i -lt 34; $i++) {
        $x = $rng.Next(12, 99)
        $y = $rng.Next(34, 82)
        if ([math]::Abs($x - 55) / 54.0 + [math]::Abs($y - 56) / 34.0 -gt 1.0) { continue }
        $w = $rng.Next(2, 6)
        $h = $rng.Next(1, 3)
        $g.FillEllipse((Brush $fleck $rng.Next(28, 58)), $x, $y, $w, $h)
    }

    for ($i = 0; $i -lt 4; $i++) {
        $x = $rng.Next(18, 88)
        $y = $rng.Next(44, 72)
        $pen = PenC "#0A1612" 1.2 75
        $g.DrawBezier($pen, $x, $y, $x + $rng.Next(-12, 12), $y - 5, $x + $rng.Next(-12, 12), $y + 5, $x + $rng.Next(-16, 16), $y + $rng.Next(-5, 6))
        $pen.Dispose()
    }

    if ($level -eq 1) {
        $g.DrawLine((PenC "#7BC47F" 1.4 34), 8, 56, 55, 86)
        $g.DrawLine((PenC "#7BC47F" 1.4 34), 103, 56, 55, 86)
    } elseif ($level -eq 2) {
        $g.DrawLine((PenC "#D6C7AE" 1.8 46), 7, 56, 55, 87)
        $g.DrawLine((PenC "#D6C7AE" 1.8 46), 104, 56, 55, 87)
    }
}

function DrawCliffFace($g, [int]$seed) {
    $top = DiamondPoints
    $g.FillPolygon((Brush "#142420" 230), $top)
    $g.DrawPolygon((PenC "#8A7560" 2.6 180), $top)
    $face = Poly @(@(2,56), @(55,90), @(108,56), @(108,104), @(55,124), @(2,104))
    $g.FillPolygon((Brush "#030605" 245), $face)
    $rng = [System.Random]::new($seed)
    for ($i = 0; $i -lt 9; $i++) {
        $x = $rng.Next(12, 98)
        $pen = PenC $(if ($i % 3 -eq 0) { "#8B1A1F" } else { "#332820" }) 2.2 150
        $g.DrawBezier($pen, $x, 62, $x + $rng.Next(-8, 8), 78, $x + $rng.Next(-12, 12), 94, $x + $rng.Next(-10, 10), 120)
        $pen.Dispose()
    }
}

function DrawRamp($g, [int]$seed) {
    DrawMatteFloor $g "#1A1410" "#8A7560" "#D6C7AE" $seed 1
    $edge = PenC "#D6C7AE" 2.8 185
    $shadow = PenC "#050807" 4.5 110
    for ($s = 0; $s -lt 7; $s++) {
        $y = 35 + $s * 7
        $g.DrawLine($shadow, 22, $y + 2, 89, $y + 2)
        $g.DrawLine($edge, 22, $y, 89, $y)
    }
    $edge.Dispose()
    $shadow.Dispose()
}

function DrawFoliage($g, [int]$seed) {
    $rng = [System.Random]::new($seed)
    $g.FillPolygon((Brush "#0A1612" 150), (DiamondPoints))
    for ($i = 0; $i -lt 4; $i++) {
        $x = $rng.Next(20, 82)
        $y = $rng.Next(48, 80)
        $g.FillEllipse((Brush "#8B1A1F" 220), $x, $y - 16, $rng.Next(12, 22), $rng.Next(8, 13))
        $stem = PenC "#8A7560" 2 150
        $g.DrawLine($stem, $x + 6, $y, $x + 6, $y - 11)
        $stem.Dispose()
    }
}

for ($i = 1; $i -le 3; $i++) {
    $n = "{0:00}" -f $i
    SaveTile "low_ground_vm_$n.png" { param($g) DrawMatteFloor $g "#142420" "#24372F" "#4A8A5C" (100 + $i) 0 }
    SaveTile "mid_ground_vm_$n.png" { param($g) DrawMatteFloor $g "#1E3A2D" "#4A8A5C" "#7BC47F" (200 + $i) 1 }
    SaveTile "high_ground_vm_$n.png" { param($g) DrawMatteFloor $g "#2D5A3E" "#8A7560" "#D6C7AE" (300 + $i) 2 }
    SaveTile "cliff_vm_$n.png" { param($g) DrawCliffFace $g (400 + $i) }
    SaveTile "path_slope_vm_$n.png" { param($g) DrawRamp $g (500 + $i) }
    SaveTile "foliage_vm_$n.png" { param($g) DrawFoliage $g (600 + $i) }
}

Write-Output "Generated readable Vampiric Mushroom Forest terrain tiles in $OutDir"
