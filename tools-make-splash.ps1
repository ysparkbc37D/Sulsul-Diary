# Sulsul Diary iOS launch images (apple-touch-startup-image).
#
# Writes ./splash/*.png. The launch image has the app icon baked into it, so this
# must be re-run after tools-make-icon.ps1 -- otherwise the launch screen shows the
# old icon while the home screen shows the new one.
#
# ASCII-only literals (PowerShell 5.1 reads UTF-8-no-BOM as ANSI).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools-make-splash.ps1
#
# The sizes must match the media queries in index.html exactly -- iOS applies a
# launch image only on an exact device-width/height/dpr match. Adding a device
# means adding a <link> there and a row here.
$ErrorActionPreference = 'Stop'

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
if (-not (Test-Path $chrome)) { throw "Chrome not found: $chrome" }

$out = Join-Path $here 'splash'
$tmp = Join-Path $env:TEMP ('sulsul-splash-' + $PID)
New-Item -ItemType Directory -Force -Path $out, $tmp | Out-Null

# Embed the rendered icon as a data URI: headless + file:// will not fetch a
# sibling image reliably, and this keeps the page self-contained.
$src = Join-Path $here 'icons\icon-512.png'
if (-not (Test-Path $src)) { throw 'icons/icon-512.png missing - run tools-make-icon.ps1 first' }
$b64 = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($src))

# name, css width, css height, dpr  (output px = css * dpr)
$jobs = @(
  @{ n = 'iphone-13-14.png';  w = 390; h = 844;  dsf = 3 },
  @{ n = 'iphone-15-16.png';  w = 393; h = 852;  dsf = 3 },
  @{ n = 'iphone-16-pro.png'; w = 402; h = 874;  dsf = 3 },
  @{ n = 'iphone-max.png';    w = 430; h = 932;  dsf = 3 },
  @{ n = 'ipad.png';          w = 768; h = 1024; dsf = 2 }
)

$i = 0
foreach ($j in $jobs) {
  $i++
  # Proportions taken off the previous launch images: tile 22.4% of width, centred
  # at 40% of height, hairline rule and dot below. Background is the light theme.
  $page = @"
<meta charset="utf-8">
<style>
  html,body{margin:0;padding:0;width:100%;height:100%;background:#faf8f5;overflow:hidden}
  .s{position:absolute;inset:0}
  .tile{position:absolute;top:40%;left:50%;transform:translate(-50%,-50%);
        width:22.4%;aspect-ratio:1;border-radius:22.5%;overflow:hidden;
        box-shadow:0 10px 30px rgba(60,44,24,.14)}
  .tile img{width:100%;height:100%;display:block}
  .bar{position:absolute;top:49.5%;left:50%;transform:translateX(-50%);
       width:32%;height:1px;background:#e2dbd0}
  .dot{position:absolute;top:49.5%;left:50%;transform:translate(-50%,-50%);
       width:7px;height:7px;border-radius:50%;background:#a2601b}
</style>
<div class="s">
  <div class="tile"><img src="data:image/png;base64,$b64" alt=""></div>
  <div class="bar"></div><div class="dot"></div>
</div>
"@

  $pf = Join-Path $tmp ('splash-' + $j.n + '.html')
  [System.IO.File]::WriteAllText($pf, $page, (New-Object System.Text.UTF8Encoding($false)))

  & $chrome --headless=new --disable-gpu --no-sandbox --hide-scrollbars `
    --user-data-dir="$(Join-Path $tmp ('prof-' + $i))" --virtual-time-budget=6000 `
    --window-size="$($j.w),$($j.h)" --force-device-scale-factor=$($j.dsf) `
    --screenshot="$(Join-Path $out $j.n)" ('file:///' + ($pf -replace '\\', '/')) | Out-Null

  Write-Output ("  {0,-20} {1}x{2}" -f $j.n, ($j.w * $j.dsf), ($j.h * $j.dsf))
}

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Output 'splash done'
