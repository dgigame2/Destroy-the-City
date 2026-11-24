$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$root=Split-Path -Parent $PSScriptRoot
$manifest=Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'manifest.json') | ConvertFrom-Json
$bitmap=[Drawing.Bitmap]::new(1960,2360)
$graphics=[Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear([Drawing.Color]::FromArgb(24,30,41))
$graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit

function Brush([string]$hex) {
    [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($hex))
}
$white=Brush '#F0F4FB'
$muted=Brush '#A8B7CC'
$cyan=Brush '#8DDFFF'
$border=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#3A485C'),1)
$tile=Brush '#212A38'
$title=[Drawing.Font]::new('Segoe UI Semibold',49,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$section=[Drawing.Font]::new('Segoe UI Semibold',31,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$label=[Drawing.Font]::new('Segoe UI Semibold',25,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$meta=[Drawing.Font]::new('Segoe UI',19,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
$graphics.DrawString('DISASTER EVOLUTION',$title,$white,42,27)
$graphics.DrawString('TORNADO FORMS',$section,$cyan,42,115)
$graphics.DrawString('Q SKILLS',$section,$cyan,42,1242)

for ($i=0; $i -lt $manifest.Count; $i++) {
    $asset=$manifest[$i]
    $col=$i % 4
    $group=[Math]::Floor($i/8)
    $row=[Math]::Floor(($i%8)/4)
    $x=[int](50+$col*472)
    $y=[int](174+$group*1128+$row*512)
    $graphics.FillRectangle($tile,$x,$y,444,483)
    $graphics.DrawRectangle($border,$x,$y,444,483)
    $preview=[Drawing.Image]::FromFile((Join-Path $root ('Renders\'+$asset.name+'.png')))
    try { $graphics.DrawImage($preview,[Drawing.Rectangle]::new($x+15,$y+12,414,414)) }
    finally { $preview.Dispose() }
    $name=($asset.name -replace '_',' ').ToUpperInvariant()
    $graphics.DrawString($name,$label,$white,$x+15,$y+435)
    $level='LV '+$asset.level
    $width=$graphics.MeasureString($level,$meta).Width
    $graphics.DrawString($level,$meta,$muted,[single]($x+425-$width),[single]($y+440))
}
$bitmap.Save((Join-Path $root 'Prancha_DisasterEvolution.png'),[Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()
foreach ($resource in @($white,$muted,$cyan,$tile,$border,$title,$section,$label,$meta)) {
    $resource.Dispose()
}

