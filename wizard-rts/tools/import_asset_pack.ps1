param(
	[string]$Pack = "tiny-swords",
	[ValidateSet("analyze", "apply", "all")]
	[string]$Mode = "all",
	[string]$PackRoot = "Tiny Swords\Tiny Swords (Free Pack)",
	[string]$OutputRoot = "assets\imported\tiny_swords",
	[switch]$NoBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$Workspace = (Resolve-Path ".").Path

function Resolve-InWorkspace([string]$Path) {
	$resolved = Join-Path $Workspace $Path
	return [System.IO.Path]::GetFullPath($resolved)
}

function Ensure-Directory([string]$Path) {
	if (-not (Test-Path $Path)) {
		New-Item -ItemType Directory -Path $Path | Out-Null
	}
}

function New-Color([int]$A, [int]$R, [int]$G, [int]$B) {
	return [System.Drawing.Color]::FromArgb($A, $R, $G, $B)
}

function Get-ImageInfo([string]$Path) {
	$image = [System.Drawing.Image]::FromFile($Path)
	try {
		return [ordered]@{
			path = $Path.Substring($Workspace.Length + 1)
			width = $image.Width
			height = $image.Height
		}
	}
	finally {
		$image.Dispose()
	}
}

function Save-Json($Value, [string]$Path) {
	Ensure-Directory ([System.IO.Path]::GetDirectoryName($Path))
	$Value | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
}

function Backup-File([string]$Path, [string]$BackupRoot) {
	if ($NoBackup -or -not (Test-Path $Path)) {
		return
	}
	$relative = $Path.Substring($Workspace.Length + 1)
	$target = Join-Path $BackupRoot $relative
	Ensure-Directory ([System.IO.Path]::GetDirectoryName($target))
	Copy-Item -LiteralPath $Path -Destination $target -Force
}

function New-Bitmap([int]$Width, [int]$Height) {
	return New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function New-Graphics([System.Drawing.Bitmap]$Bitmap) {
	$graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
	$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
	$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed
	$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
	$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
	$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
	return $graphics
}

function Fill-Rect($Graphics, [int]$X, [int]$Y, [int]$W, [int]$H, [System.Drawing.Color]$Color) {
	$brush = New-Object System.Drawing.SolidBrush($Color)
	try {
		$Graphics.FillRectangle($brush, $X, $Y, $W, $H)
	}
	finally {
		$brush.Dispose()
	}
}

function Draw-Line($Graphics, [int]$X1, [int]$Y1, [int]$X2, [int]$Y2, [System.Drawing.Color]$Color, [float]$Width = 1.0) {
	$pen = New-Object System.Drawing.Pen($Color, $Width)
	try {
		$Graphics.DrawLine($pen, $X1, $Y1, $X2, $Y2)
	}
	finally {
		$pen.Dispose()
	}
}

function Draw-Source($Graphics, [string]$SourcePath, [System.Drawing.Rectangle]$SourceRect, [System.Drawing.Rectangle]$DestRect) {
	if (-not (Test-Path $SourcePath)) {
		return
	}
	$image = [System.Drawing.Image]::FromFile($SourcePath)
	try {
		$crop = New-Object System.Drawing.Rectangle(
			[Math]::Max(0, $SourceRect.X),
			[Math]::Max(0, $SourceRect.Y),
			[Math]::Min($SourceRect.Width, $image.Width - [Math]::Max(0, $SourceRect.X)),
			[Math]::Min($SourceRect.Height, $image.Height - [Math]::Max(0, $SourceRect.Y))
		)
		if ($crop.Width -gt 0 -and $crop.Height -gt 0) {
			$Graphics.DrawImage($image, $DestRect, $crop, [System.Drawing.GraphicsUnit]::Pixel)
		}
	}
	finally {
		$image.Dispose()
	}
}

function Draw-SourceCover($Graphics, [string]$SourcePath, [System.Drawing.Rectangle]$SourceRect, [System.Drawing.Rectangle]$DestRect) {
	if (-not (Test-Path $SourcePath)) {
		return
	}
	$image = [System.Drawing.Image]::FromFile($SourcePath)
	try {
		$crop = New-Object System.Drawing.Rectangle(
			[Math]::Max(0, $SourceRect.X),
			[Math]::Max(0, $SourceRect.Y),
			[Math]::Min($SourceRect.Width, $image.Width - [Math]::Max(0, $SourceRect.X)),
			[Math]::Min($SourceRect.Height, $image.Height - [Math]::Max(0, $SourceRect.Y))
		)
		if ($crop.Width -le 0 -or $crop.Height -le 0) {
			return
		}
		$scale = [Math]::Max($DestRect.Width / $crop.Width, $DestRect.Height / $crop.Height)
		$drawW = [int][Math]::Ceiling($crop.Width * $scale)
		$drawH = [int][Math]::Ceiling($crop.Height * $scale)
		$drawX = $DestRect.X + [int][Math]::Floor(($DestRect.Width - $drawW) / 2)
		$drawY = $DestRect.Y + [int][Math]::Floor(($DestRect.Height - $drawH) / 2)
		$Graphics.DrawImage($image, (New-Object System.Drawing.Rectangle($drawX, $drawY, $drawW, $drawH)), $crop, [System.Drawing.GraphicsUnit]::Pixel)
	}
	finally {
		$image.Dispose()
	}
}

function Draw-TileGrain($Graphics, [int]$Variant, [System.Drawing.Color]$DotColor, [System.Drawing.Color]$LineColor) {
	for ($i = 0; $i -lt 18; $i++) {
		$x = (13 + ($i * 29) + ($Variant * 7)) % 111
		$y = (17 + ($i * 19) + ($Variant * 11)) % 128
		Fill-Rect $Graphics $x $y 1 1 $DotColor
	}
}

function Draw-RampStripes($Graphics) {
	$pen = New-Object System.Drawing.Pen((New-Color 180 232 158 74), 3)
	try {
		for ($y = 18; $y -lt 116; $y += 14) {
			$Graphics.DrawLine($pen, 16, $y, 95, $y + 7)
		}
	}
	finally {
		$pen.Dispose()
	}
}

function Draw-Token($Graphics, [string]$Kind, [int]$Variant) {
	switch ($Kind) {
		"economy" {
			for ($i = 0; $i -lt 6; $i++) {
				$x = 31 + (($i * 13 + $Variant * 5) % 44)
				$y = 38 + (($i * 9 + $Variant * 7) % 34)
				Fill-Rect $Graphics $x $y 9 7 (New-Color 230 218 178 73)
				Fill-Rect $Graphics ($x + 2) ($y + 2) 4 3 (New-Color 230 255 224 107)
			}
		}
		"forest" {
			for ($i = 0; $i -lt 5; $i++) {
				$x = 20 + (($i * 17 + $Variant * 9) % 64)
				$y = 24 + (($i * 11 + $Variant * 4) % 72)
				Fill-Rect $Graphics ($x + 7) ($y + 18) 6 18 (New-Color 255 54 43 32)
				Fill-Rect $Graphics $x $y 24 24 (New-Color 230 29 87 55)
				Fill-Rect $Graphics ($x + 5) ($y + 5) 14 14 (New-Color 190 50 135 76)
			}
		}
		"wall" {
			Fill-Rect $Graphics 8 12 95 88 (New-Color 235 85 80 68)
			Fill-Rect $Graphics 8 12 95 12 (New-Color 255 140 132 110)
			for ($x = 13; $x -lt 98; $x += 18) {
				Draw-Line $Graphics $x 15 $x 95 (New-Color 120 42 38 34) 2
			}
			Draw-Line $Graphics 8 99 103 99 (New-Color 180 36 32 29) 4
		}
		"mushroom" {
			Fill-Rect $Graphics 52 54 9 42 (New-Color 255 202 188 155)
			Fill-Rect $Graphics 32 35 47 25 (New-Color 245 169 44 51)
			Fill-Rect $Graphics 43 42 7 6 (New-Color 245 239 207 174)
			Fill-Rect $Graphics 60 39 6 5 (New-Color 245 239 207 174)
			Fill-Rect $Graphics 23 75 20 12 (New-Color 230 170 44 51)
			Fill-Rect $Graphics 75 70 14 10 (New-Color 230 170 44 51)
		}
	}
}

function New-Tile(
	[string]$Destination,
	[string]$SourcePath,
	[System.Drawing.Rectangle]$SourceRect,
	[System.Drawing.Color]$Base,
	[System.Drawing.Color]$Tint,
	[string]$Kind,
	[int]$Variant,
	[string]$BackupRoot
) {
	Backup-File $Destination $BackupRoot
	$bitmap = New-Bitmap 111 128
	$graphics = New-Graphics $bitmap
	try {
		Fill-Rect $graphics 0 0 111 128 $Base
		if ($Kind -eq "cliff") {
			Draw-Source $graphics $SourcePath $SourceRect (New-Object System.Drawing.Rectangle(0, 0, 111, 128))
		}
		else {
			Draw-SourceCover $graphics $SourcePath $SourceRect (New-Object System.Drawing.Rectangle(0, 0, 111, 128))
		}
		Fill-Rect $graphics 0 0 111 128 $Tint
		if ($Kind -eq "path") {
			Fill-Rect $graphics 0 0 111 128 (New-Color 215 128 91 62)
			Draw-Line $graphics 0 26 111 22 (New-Color 150 207 178 133) 2
			Draw-Line $graphics 0 101 111 106 (New-Color 130 68 46 33) 2
		}
		elseif ($Kind -eq "ramp") {
			Draw-Source $graphics $SourcePath $SourceRect (New-Object System.Drawing.Rectangle(0, 0, 111, 128))
			Fill-Rect $graphics 0 0 111 128 (New-Color 120 190 130 64)
			Draw-RampStripes $graphics
		}
		elseif ($Kind -eq "water") {
			Fill-Rect $graphics 0 0 111 128 (New-Color 215 28 91 104)
			Draw-Line $graphics 4 43 107 37 (New-Color 120 75 183 198) 2
			Draw-Line $graphics 3 76 106 84 (New-Color 90 116 223 230) 1
		}
		Draw-TileGrain $graphics $Variant (New-Color 80 226 216 176) (New-Color 45 218 234 221)
		Draw-Token $graphics $Kind $Variant
		Ensure-Directory ([System.IO.Path]::GetDirectoryName($Destination))
		$bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
	}
	finally {
		$graphics.Dispose()
		$bitmap.Dispose()
	}
}

function New-BuildingSprite([string]$Destination, [string]$SourcePath, [int]$Width, [int]$Height, [string]$BackupRoot) {
	if (-not (Test-Path $SourcePath)) {
		return
	}
	Backup-File $Destination $BackupRoot
	$bitmap = New-Bitmap $Width $Height
	$graphics = New-Graphics $bitmap
	try {
		$image = [System.Drawing.Image]::FromFile($SourcePath)
		try {
			$scale = [Math]::Min(($Width - 8) / $image.Width, ($Height - 8) / $image.Height)
			$drawW = [int]($image.Width * $scale)
			$drawH = [int]($image.Height * $scale)
			$dest = New-Object System.Drawing.Rectangle([int](($Width - $drawW) / 2), [int]($Height - $drawH - 4), $drawW, $drawH)
			$graphics.DrawImage($image, $dest, 0, 0, $image.Width, $image.Height, [System.Drawing.GraphicsUnit]::Pixel)
		}
		finally {
			$image.Dispose()
		}
		Ensure-Directory ([System.IO.Path]::GetDirectoryName($Destination))
		$bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
	}
	finally {
		$graphics.Dispose()
		$bitmap.Dispose()
	}
}

function Analyze-TinySwords([string]$Root, [string]$OutputDir) {
	$pngs = Get-ChildItem -Path $Root -Recurse -File -Filter *.png | Where-Object { $_.FullName -notmatch "\\__MACOSX\\" }
	$manifest = [ordered]@{
		pack = "tiny-swords"
		source_root = $Root.Substring($Workspace.Length + 1)
		generated_at = (Get-Date).ToString("s")
		png_count = $pngs.Count
		terrain = @($pngs | Where-Object { $_.FullName -match "\\Terrain\\" } | ForEach-Object { Get-ImageInfo $_.FullName })
		buildings = @($pngs | Where-Object { $_.FullName -match "\\Buildings\\" } | ForEach-Object { Get-ImageInfo $_.FullName })
		units = @($pngs | Where-Object { $_.FullName -match "\\Units\\" } | Select-Object -First 80 | ForEach-Object { Get-ImageInfo $_.FullName })
	}
	Save-Json $manifest (Join-Path $OutputDir "manifest.json")
	return $manifest
}

function Apply-TinySwords([string]$Root, [string]$OutputDir) {
	$backupRoot = Join-Path $OutputDir ("backups\" + (Get-Date).ToString("yyyyMMdd_HHmmss"))
	$tileRoot = Resolve-InWorkspace "assets\tiles\voxel"
	$buildingRoot = Resolve-InWorkspace "assets\buildings\kon"
	$terrain1 = Join-Path $Root "Terrain\Tileset\Tilemap_color1.png"
	$terrain3 = Join-Path $Root "Terrain\Tileset\Tilemap_color3.png"
	$terrain4 = Join-Path $Root "Terrain\Tileset\Tilemap_color4.png"
	$terrain5 = Join-Path $Root "Terrain\Tileset\Tilemap_color5.png"
	$water = Join-Path $Root "Terrain\Tileset\Water Background color.png"
	$grassCrop = New-Object System.Drawing.Rectangle(10, 10, 170, 104)
	$highGrassCrop = New-Object System.Drawing.Rectangle(332, 10, 170, 104)
	$cliffCrop = New-Object System.Drawing.Rectangle(322, 128, 190, 252)
	$rampCrop = New-Object System.Drawing.Rectangle(0, 254, 190, 128)
	$waterCrop = New-Object System.Drawing.Rectangle(0, 0, 64, 64)

	$tileSpecs = @(
		@{ prefix = "low_ground_vm"; source = $terrain3; crop = $grassCrop; base = @(43,99,60); tint = @(20,16,45,27); kind = "ground" },
		@{ prefix = "mid_ground_vm"; source = $terrain4; crop = $grassCrop; base = @(64,110,68); tint = @(20,52,76,38); kind = "ground" },
		@{ prefix = "high_ground_vm"; source = $terrain1; crop = $highGrassCrop; base = @(105,138,63); tint = @(15,82,95,32); kind = "ground" },
		@{ prefix = "path_vm"; source = $terrain4; crop = $grassCrop; base = @(118,86,57); tint = @(20,84,55,35); kind = "path" },
		@{ prefix = "path_slope_vm"; source = $terrain1; crop = $rampCrop; base = @(142,98,55); tint = @(10,90,60,34); kind = "ramp" },
		@{ prefix = "water_vm"; source = $water; crop = $waterCrop; base = @(41,134,142); tint = @(15,20,76,88); kind = "water" },
		@{ prefix = "cliff_vm"; source = $terrain5; crop = $cliffCrop; base = @(59,78,74); tint = @(25,12,23,22); kind = "cliff" },
		@{ prefix = "foliage_vm"; source = $terrain3; crop = $grassCrop; base = @(33,82,47); tint = @(45,13,37,22); kind = "forest" },
		@{ prefix = "giant_mushroom_vm"; source = $terrain3; crop = $grassCrop; base = @(33,82,47); tint = @(35,24,42,28); kind = "mushroom" },
		@{ prefix = "economy_plot_vm"; source = $terrain1; crop = $grassCrop; base = @(76,109,55); tint = @(25,54,76,35); kind = "economy" },
		@{ prefix = "ruin_floor_vm"; source = $terrain4; crop = $grassCrop; base = @(81,78,66); tint = @(55,74,68,57); kind = "ground" },
		@{ prefix = "bandit_floor_vm"; source = $terrain4; crop = $grassCrop; base = @(82,65,51); tint = @(65,95,70,50); kind = "ground" },
		@{ prefix = "bandit_wall_vm"; source = $terrain4; crop = $cliffCrop; base = @(70,61,52); tint = @(75,68,56,43); kind = "cliff" },
		@{ prefix = "wizard_tower_floor_vm"; source = $terrain1; crop = $grassCrop; base = @(67,77,75); tint = @(55,60,72,79); kind = "ground" },
		@{ prefix = "wizard_tower_wall_vm"; source = $terrain1; crop = $cliffCrop; base = @(62,68,72); tint = @(65,62,72,82); kind = "cliff" }
	)

	$outputs = New-Object System.Collections.Generic.List[object]
	foreach ($spec in $tileSpecs) {
		for ($i = 1; $i -le 3; $i++) {
			$name = "{0}_{1:D2}.png" -f $spec.prefix, $i
			$dest = Join-Path $tileRoot $name
			$base = New-Color 255 $spec.base[0] $spec.base[1] $spec.base[2]
			$tint = New-Color $spec.tint[0] $spec.tint[1] $spec.tint[2] $spec.tint[3]
			New-Tile $dest $spec.source $spec.crop $base $tint $spec.kind $i $backupRoot
			$outputs.Add([ordered]@{ path = $dest.Substring($Workspace.Length + 1); source = $spec.source.Substring($Workspace.Length + 1); role = $spec.prefix }) | Out-Null
		}
	}

	$buildingSpecs = @(
		@{ target = "wizard_tower.png"; source = "Buildings\Blue Buildings\Tower.png"; w = 192; h = 256 },
		@{ target = "barracks.png"; source = "Buildings\Blue Buildings\Barracks.png"; w = 192; h = 256 },
		@{ target = "terrible_vault.png"; source = "Buildings\Blue Buildings\Monastery.png"; w = 192; h = 320 },
		@{ target = "bio_absorber.png"; source = "Buildings\Blue Buildings\House2.png"; w = 160; h = 192 },
		@{ target = "bio_launcher_rooted.png"; source = "Buildings\Blue Buildings\Archery.png"; w = 192; h = 256 }
	)
	foreach ($spec in $buildingSpecs) {
		$source = Join-Path $Root $spec.source
		$dest = Join-Path $buildingRoot $spec.target
		New-BuildingSprite $dest $source $spec.w $spec.h $backupRoot
		$outputs.Add([ordered]@{ path = $dest.Substring($Workspace.Length + 1); source = $source.Substring($Workspace.Length + 1); role = "kon_building" }) | Out-Null
	}

	$summary = [ordered]@{
		pack = "tiny-swords"
		applied_at = (Get-Date).ToString("s")
		backup_root = if ($NoBackup) { $null } else { $backupRoot.Substring($Workspace.Length + 1) }
		output_count = $outputs.Count
		outputs = $outputs
	}
	Save-Json $summary (Join-Path $OutputDir "last_apply.json")
	return $summary
}

if ($Pack -ne "tiny-swords") {
	throw "Only the tiny-swords importer is implemented. Add a pack adapter before using '$Pack'."
}

$packPath = Resolve-InWorkspace $PackRoot
if (-not (Test-Path $packPath)) {
	throw "Pack root not found: $packPath"
}

$outputDir = Resolve-InWorkspace $OutputRoot
Ensure-Directory $outputDir

if ($Mode -eq "analyze" -or $Mode -eq "all") {
	$manifest = Analyze-TinySwords $packPath $outputDir
	Write-Host ("[AssetImporter] analyzed {0} PNGs from {1}" -f $manifest.png_count, $manifest.source_root)
}

if ($Mode -eq "apply" -or $Mode -eq "all") {
	$summary = Apply-TinySwords $packPath $outputDir
	Write-Host ("[AssetImporter] generated {0} assets; backup={1}" -f $summary.output_count, $summary.backup_root)
}
