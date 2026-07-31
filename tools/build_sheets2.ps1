# Second wave of asset sheets — everything build_sheets.ps1 missed. Paths are parameters,
# never literals (PS 5.1 reads a BOM-less script as ANSI and this repo's path is Greek).
param([string]$Repo, [string]$Godot, [string]$Out)

$jobs = @(
  @{n="16_craftables";     src="assets\craft";                        cols=12; cell=165; t="CRAFTABLES - the full fabricator catalogue"; bg="grid"},
  @{n="17_ship_tileset";   src="assets\props";                        cols=8;  cell=240; t="SHIP INTERIOR TILESET - floors, walls, corners"; bg="grid"},
  @{n="18_wrecks";         src="assets\wrecks";                       cols=5;  cell=320; t="DERELICT WRECKS - the recipe drops"; bg="grid"},
  @{n="19_crew_dialog";    src="assets\sprites\crew\dialog";          cols=10; cell=300; t="CREW - dialog portraits, every expression"; bg="dark"},
  @{n="20_crew_idle";      src="assets\sprites\crew\idle";            cols=6;  cell=130; t="CREW - idle animation frames (6 per loop, one loop per row)"; bg="grid"},
  @{n="21_crew_roster";    src="assets\sprites\crew\roster";          cols=10; cell=150; t="CREW - roster + radar avatars"; bg="grid"},
  @{n="22_breach_anims";   src="assets\sprites\breach\hd\anim";       cols=6;  cell=150; t="THE BREACH - node icon animations (6 per loop, one loop per row)"; bg="grid"},
  @{n="23_breach_legacy";  src="assets\sprites\breach\scifi;assets\sprites\breach\map3d\fx;assets\sprites\breach"; cols=10; cell=150; t="THE BREACH - fallback icons, FX and the legacy set"; bg="grid"},
  @{n="24_astro_anim";     src="assets\sprites\astro\anim";           cols=8;  cell=140; t="ASTRONAUT - EVA animation frames"; bg="grid"},
  @{n="25_particles";      src="assets\particles";                    cols=7;  cell=190; t="PARTICLE TEXTURES"; bg="grid"},
  @{n="26_intro";          src="assets\sprites\intro";                cols=2;  cell=620; t="INTRO CUTSCENE PANELS"; bg="dark"},
  @{n="27_logo_anim";      src="assets\sprites\logo_anim";            cols=3;  cell=420; t="LOGO - animation frames"; bg="dark"},
  @{n="28_loose";          src="assets\sprites";                      cols=5;  cell=340; t="LOOSE ART - logo, title plate, ship, suit, pickups"; bg="grid"},
  @{n="29_originals";      src="assets\_originals";                   cols=3;  cell=420; t="PRE-PIXELATION SOURCE ART (vault, reference only)"; bg="grid"}
)
foreach ($j in $jobs) {
  $srcs = ($j.src -split ";" | ForEach-Object { Join-Path $Repo $_ }) -join ";"
  $env:SW_SHEET_SRC = $srcs
  $env:SW_SHEET_OUT = "$Out/$($j.n).png"
  $env:SW_SHEET_COLS = "$($j.cols)"; $env:SW_SHEET_CELL = "$($j.cell)"
  $env:SW_SHEET_TITLE = $j.t; $env:SW_SHEET_BG = $j.bg; $env:SW_SHEET_MAX = "0"
  & $Godot --path $Repo --resolution 320x200 "tools/sheet.tscn" 2>&1 | Select-String "SHEET\]" | Select-Object -First 1
}
Get-ChildItem Env:SW_SHEET_* | ForEach-Object { Remove-Item ("Env:" + $_.Name) }
Write-Host "SHEETS2 DONE"
