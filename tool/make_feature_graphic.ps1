param(
  [string]$AppIconPath = (Join-Path $PSScriptRoot "..\store\app_icon_512.png"),
  [string]$OutPath = (Join-Path $PSScriptRoot "..\store\feature_graphic.png")
)

Add-Type -AssemblyName System.Drawing

$Width = 1024
$Height = 500

function New-RoundedPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $path.AddArc($x, $y, $d, $d, 180, 90)
  $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}

$bmp = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# Background gradient (teal, matches app seed #0f766e)
$bgRect = New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)
$gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  $bgRect,
  [System.Drawing.Color]::FromArgb(38, 176, 165),   # #26B0A5 top
  [System.Drawing.Color]::FromArgb(10, 92, 88),     # #0A5C58 bottom
  90.0
)
$g.FillRectangle($gradient, $bgRect)

# Decorative translucent circles
$circleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(26, 255, 255, 255))
$g.FillEllipse($circleBrush, -140, -120, 420, 420)
$g.FillEllipse($circleBrush, 780, 330, 260, 260)
$g.FillEllipse($circleBrush, 680, -110, 180, 180)

$white = [System.Drawing.Color]::White
$tealDeep = [System.Drawing.Color]::FromArgb(15, 118, 110)   # #0F766E
$tealSoft = [System.Drawing.Color]::FromArgb(204, 251, 241)  # #CCFBF1

# App icon
$icon = [System.Drawing.Image]::FromFile($AppIconPath)
$iconBoxSize = 196
$g.DrawImage($icon, 92, 152, $iconBoxSize, $iconBoxSize)

# App name (auto-shrink to fit)
function Draw-AppName {
  $nameFormat = New-Object System.Drawing.StringFormat
  $startX = 322
  $maxWidth = 660
  $brushWhite = New-Object System.Drawing.SolidBrush($white)
  foreach ($size in 64, 58, 52, 46, 40) {
    $font = New-Object System.Drawing.Font("Segoe UI", $size, [System.Drawing.FontStyle]::Bold)
    $measured = $g.MeasureString("Pocket Interpreter", $font)
    if ($measured.Width -le $maxWidth) {
      $g.DrawString("Pocket Interpreter", $font, $brushWhite, $startX, 158, $nameFormat)
      $font.Dispose()
      $brushWhite.Dispose()
      $nameFormat.Dispose()
      return
    }
    $font.Dispose()
  }
}
Draw-AppName

# Tagline
$tagBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(232, 255, 255, 255))
$tagFont = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Regular)
$tagFormat = New-Object System.Drawing.StringFormat
$g.DrawString("Real-time EN ↔ VI  •  Fully offline", $tagFont, $tagBrush, 322, 250, $tagFormat)

# Small separator underline
$lineBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 255, 255, 255))
$g.FillRectangle($lineBrush, 324, 296, 240, 4)

# Chat panel (white rounded)
$panelX = 628; $panelY = 90; $panelW = 330; $panelH = 320
$panelPath = New-RoundedPath $panelX $panelY $panelW $panelH 24
$panelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 255, 255, 255))
$g.FillPath($panelBrush, $panelPath)

# Chat header "ONLINE • EN → VI"
$headerFont = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$headerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(122, 130, 128))
$g.DrawString("OFFLINE CONVERSATION", $headerFont, $headerBrush, $panelX + 20, $panelY + 16)

function Draw-Bubble([float]$x, [float]$y, [string]$text, [bool]$fromUser, [float]$maxW) {
  $innerFont = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Regular)
  $innerFormat = New-Object System.Drawing.StringFormat
  $measured = $g.MeasureString($text, $innerFont)
  $bubbleW = [Math]::Min($measured.Width + 34, $maxW)
  $bubbleH = [Math]::Max(44, $measured.Height + 14)
  $fx = if ($fromUser) { $panelX + $panelW - 20 - $bubbleW } else { $panelX + 20 }
  $path = New-RoundedPath $fx $y $bubbleW $bubbleH 20
  if ($fromUser) {
    $brush = New-Object System.Drawing.SolidBrush($tealDeep)
    $g.FillPath($brush, $path)
    $textBrush = New-Object System.Drawing.SolidBrush($white)
  } else {
    $brush = New-Object System.Drawing.SolidBrush($tealSoft)
    $g.FillPath($brush, $path)
    $textBrush = New-Object System.Drawing.SolidBrush($tealDeep)
  }
  $g.DrawString($text, $innerFont, $textBrush, $fx, $y + (($bubbleH - $measured.Height) / 2) - 1, $innerFormat)
  $brush.Dispose(); $textBrush.Dispose(); $innerFont.Dispose(); $innerFormat.Dispose()
  return $bubbleH
}

$rowY = $panelY + 56
$rowY += 4 + (Draw-Bubble 0 $rowY "Hello!" $false 260)
$rowY += 8 + (Draw-Bubble 0 $rowY "Xin chào!" $true 260)
$rowY += 8 + (Draw-Bubble 0 $rowY "Where is the station?" $false 260)
$rowY += 8 + (Draw-Bubble 0 $rowY "Ga ở đâu?" $true 260)

# Save 24bpp PNG (no alpha, Play-compliant)
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose(); $bmp.Dispose(); $icon.Dispose()
Write-Output "Wrote $OutPath"