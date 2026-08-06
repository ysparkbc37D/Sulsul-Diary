# Sulsul Diary app icon generator.
#
# Renders tools-icon.html (an SVG) with headless Chrome and writes the six PNGs
# into ./icons. Replaces tools-make-icon.py, which drew the previous bottle icon
# and needs Python + Pillow; this machine has neither.
#
# ASCII-only literals on purpose: PowerShell 5.1 decodes a UTF-8-no-BOM script as
# ANSI, so Korean text in a .ps1 comes out as mojibake.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools-make-icon.ps1
#
# Notes that cost time to find:
# - Chrome has a minimum window width in headless, so every icon is laid out at
#   512 CSS px and scaled down with --force-device-scale-factor. That also gives
#   the downsampling antialiasing for free (px / 512 = the factor).
# - A fresh --user-data-dir per capture. Reusing one re-captures the old page
#   (app-showcase SKILL.md section 3).
# - The background is flat, not a full-canvas gradient. A gradient across every
#   pixel pushed icon-512.png from 39KB to 150KB; PNG cannot compress it.
# - The wordmark uses the app's own @font-face (Cormorant Garamond, base64,
#   latin subset), lifted out of index.html at build time so the icon and the
#   in-app wordmark can never drift apart.
$ErrorActionPreference = 'Stop'

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
if (-not (Test-Path $chrome)) { throw "Chrome not found: $chrome" }

$out = Join-Path $here 'icons'
$tmp = Join-Path $env:TEMP ('sulsul-icon-' + $PID)
New-Item -ItemType Directory -Force -Path $out, $tmp | Out-Null

$html = [System.IO.File]::ReadAllText((Join-Path $here 'index.html'), [System.Text.Encoding]::UTF8)
$m = [regex]::Match($html, '@font-face\s*\{[^}]*\}')
if (-not $m.Success) { throw 'could not find @font-face in index.html' }
$fontface = $m.Value

$tpl = [System.IO.File]::ReadAllText((Join-Path $here 'tools-icon.html'), [System.Text.Encoding]::UTF8)

# letter-spacing adds a trailing gap, so shift left by half of it to stay centred
$text = '<text x="251" y="454" text-anchor="middle" fill="#E4892C" ' +
        'font-family="Cormorant Garamond,Georgia,serif" font-size="62" font-weight="700" ' +
        'letter-spacing="11">SULSUL</text>'

# name, output px, corner radius (512-space), artwork scale, vertical centre, wordmark
# favicon-64 drops the wordmark (unreadable at 64px) and is nudged down so the
# ribbon does not graze the rounded corner.
$jobs = @(
  @{ n = 'icon-512.png';          px = 512; r = 112; s = 1.00; dy = 256; t = $true  },
  @{ n = 'icon-192.png';          px = 192; r = 112; s = 1.00; dy = 256; t = $true  },
  @{ n = 'icon-maskable-512.png'; px = 512; r = 0;   s = 0.72; dy = 256; t = $true  },
  @{ n = 'icon-maskable-192.png'; px = 192; r = 0;   s = 0.72; dy = 256; t = $true  },
  @{ n = 'apple-touch-icon.png';  px = 180; r = 0;   s = 1.00; dy = 256; t = $true  },
  @{ n = 'favicon-64.png';        px = 64;  r = 112; s = 1.05; dy = 274; t = $false }
)

$i = 0
foreach ($j in $jobs) {
  $i++
  $page = $tpl.Replace('/*FONTFACE*/', $fontface).
                Replace('__RADIUS__', [string]$j.r).
                Replace('__SCALE__',  [string]$j.s).
                Replace('__DY__',     [string]$j.dy).
                Replace('__TEXT__',   $(if ($j.t) { $text } else { '' }))

  $pf = Join-Path $tmp ('page-' + $j.n + '.html')
  [System.IO.File]::WriteAllText($pf, $page, (New-Object System.Text.UTF8Encoding($false)))

  $dsf = [math]::Round($j.px / 512.0, 6)
  $png = Join-Path $out $j.n
  $url = 'file:///' + ($pf -replace '\\', '/')

  & $chrome --headless=new --disable-gpu --no-sandbox --hide-scrollbars `
    --user-data-dir="$(Join-Path $tmp ('prof-' + $i))" --virtual-time-budget=6000 `
    --window-size=512,512 --force-device-scale-factor=$dsf `
    --default-background-color=00000000 --screenshot="$png" $url | Out-Null

  Write-Output ("  {0,-24} {1}px" -f $j.n, $j.px)
}

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Output 'icons done - now run tools-make-splash.ps1, the launch images embed this icon'
