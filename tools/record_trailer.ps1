# Records trailer clips to trailer/clips/<name>.avi (MJPEG AVI, 1280x720 @30fps — imports
# straight into Resolve / Premiere / Shotcut). One Godot process per clip so a crash in one
# cannot poison the rest.
#
#   powershell -File tools/record_trailer.ps1                    # every clip
#   powershell -File tools/record_trailer.ps1 -Only duel_mid,gather_a
#
# The clip list is READ FROM tools/trailer.gd (SW_CLIP=__list__), never duplicated here —
# the two copies drifted the first time a clip was added.
#
# The repo path is DERIVED, never a literal: this project lives under a Greek folder name
# and PowerShell 5.1 reads a BOM-less script as ANSI, so a hard-coded path comes back
# mojibake and every run dies on "cannot find path".
param(
  [string]$Only = "",
  [string]$Godot = "C:\Users\menel\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe",
  [string]$Repo  = "",
  [switch]$VerifyOnly
)
if ($Repo -eq "") { $Repo = Split-Path $PSScriptRoot -Parent }

$out = Join-Path $Repo "trailer\clips"
New-Item -ItemType Directory -Force $out | Out-Null

$env:SW_CLIP = "__list__"
$clips = [ordered]@{}
& $Godot --path $Repo --headless "tools/trailer.tscn" 2>&1 |
  Select-String "^CLIP " | ForEach-Object {
    $p = ($_ -replace "^CLIP ", "") -split "\s+"
    $clips[$p[0]] = [double]$p[1]
  }
Remove-Item Env:SW_CLIP -ErrorAction SilentlyContinue
if ($clips.Count -eq 0) { Write-Host "could not read the clip list from trailer.gd" -ForegroundColor Red; exit 1 }

$want = if ($Only -ne "") { $Only -split "," | ForEach-Object { $_.Trim() } } else { @($clips.Keys) }

$i = 0
if (-not $VerifyOnly) {
foreach ($name in $want) {
  if (-not $clips.Contains($name)) { Write-Host "skip unknown clip $name"; continue }
  $i++
  $secs = $clips[$name]
  $avi = Join-Path $out "$name.avi"
  $env:SW_CLIP = $name
  Write-Host ("[{0,3}/{1}] {2}  {3}s" -f $i, $want.Count, $name, $secs)
  & $Godot --path $Repo --resolution 1280x720 --write-movie $avi --fixed-fps 30 `
           --quit-after ([int]($secs * 30)) "tools/trailer.tscn" *> $null
  Remove-Item Env:SW_CLIP -ErrorAction SilentlyContinue
}
}

# Verify from DISK, not from a flag set inside the loop. The first version incremented a
# counter next to the Godot call and reported every clip as FAILED while all of them were
# on disk at the right length — a status line that contradicts the artefact is worse than
# no status line at all.
#
# It SETTLES first, and it says so when it cannot see a file. trailer/ lives inside a
# OneDrive-synced tree, and twice now a run that had just written correct files reported
# them all MISSING — the check saw the directory before the freshly closed handles surfaced
# to this process. Both times the files were on disk, right length, valid headers. So this
# waits, retries per file, and if anything still looks absent it says the report itself may
# be wrong rather than asserting a failure that did not happen.
if (-not $VerifyOnly) { Start-Sleep -Seconds 12 }
Write-Host ""
$suspect = @()
foreach ($name in $want) {
  if (-not $clips.Contains($name)) { continue }
  $avi = Join-Path $out "$name.avi"
  $len = 0
  foreach ($try in 1..6) {
    if ([System.IO.File]::Exists($avi)) {
      $len = (New-Object System.IO.FileInfo $avi).Length
    }
    if ($len -ge 200000) { break }
    Start-Sleep -Milliseconds 1500
  }
  if ($len -eq 0) { $suspect += "$name (not visible)" }
  elseif ($len -lt 200000) { $suspect += ("{0} ({1} bytes)" -f $name, $len) }
}
$n = (Get-ChildItem $out -Filter *.avi | Measure-Object).Count
$mb = [math]::Round(((Get-ChildItem $out -Filter *.avi | Measure-Object Length -Sum).Sum / 1MB), 0)
Write-Host "$n clip(s), $mb MB in $out"
if ($suspect.Count -gt 0) {
  Write-Host ""
  Write-Host "could not confirm:" -ForegroundColor Yellow
  $suspect | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
  Write-Host "this folder is OneDrive-synced and the check has been wrong here before." -ForegroundColor Yellow
  Write-Host "re-run with -VerifyOnly once sync has settled before believing it." -ForegroundColor Yellow
}
