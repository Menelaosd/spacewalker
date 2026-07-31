param([string]$Repo, [string]$Godot, [string]$Out)
# One asset sheet per family. Cell sizes differ because the art does: a 32px element icon
# and a 655px station cannot share a grid without one of them being a smudge.
$jobs = @(
  @{n="01_elements";        src="assets\sprites\elements";        cols=12; cell=110; t="ELEMENTS - in-world vein icons"; bg="grid"; max=0},
  @{n="02_element_art";     src="assets\sprites\element_art";     cols=12; cell=110; t="ELEMENT ART - inventory / trivia cards"; bg="grid"; max=0},
  @{n="03_stations";        src="assets\sprites\stations_v2";     cols=5;  cell=320; t="SURVIVOR STATIONS"; bg="dark"; max=0},
  @{n="04_crew";            src="assets\sprites\crew";            cols=6;  cell=260; t="THE CREW - portraits, wrecks, tokens"; bg="dark"; max=0},
  @{n="05_breach_cards";    src="assets\sprites\breach\duel";     cols=11; cell=150; t="THE BREACH - card art"; bg="grid"; max=0},
  @{n="06_breach_map";      src="assets\sprites\breach\map3d";    cols=11; cell=150; t="THE BREACH - corridor tiles + node art"; bg="grid"; max=0},
  @{n="07_breach_props";    src="assets\sprites\breach\props";    cols=8;  cell=180; t="THE BREACH - deck props"; bg="grid"; max=0},
  @{n="08_breach_icons";    src="assets\sprites\breach\hd";       cols=8;  cell=180; t="THE BREACH - node icons"; bg="grid"; max=0},
  @{n="09_salvage";         src="assets\sprites\trash";           cols=14; cell=120; t="SALVAGE + DERELICT PARTS"; bg="grid"; max=0},
  @{n="10_devices";         src="assets\sprites\device_anim";     cols=15; cell=110; t="SHIP DEVICES - animation frames"; bg="grid"; max=0},
  @{n="11_walk";            src="assets\sprites\walk";            cols=9;  cell=170; t="WALK CYCLES"; bg="grid"; max=0},
  @{n="12_astro_gear";      src="assets\sprites\astro;assets\sprites\gear;assets\sprites\gameover"; cols=8; cell=200; t="ASTRONAUT + SUIT GEAR"; bg="grid"; max=0},
  @{n="13_comets";          src="assets\sprites\comets";          cols=8;  cell=180; t="COMETS + SHOOTING STARS"; bg="grid"; max=0},
  @{n="14_breach_themes";   src="assets\sprites\breach\themes";   cols=6;  cell=240; t="BREACH - station themes"; bg="dark"; max=0},
  @{n="15_title_cards";     src="trailer\cards";                  cols=4;  cell=420; t="TRAILER TITLE CARDS"; bg="dark"; max=0}
)
foreach ($j in $jobs) {
  $srcs = ($j.src -split ";" | ForEach-Object { Join-Path $Repo $_ }) -join ";"
  $env:SW_SHEET_SRC = $srcs
  $env:SW_SHEET_OUT = "$Out/$($j.n).png"
  $env:SW_SHEET_COLS = "$($j.cols)"; $env:SW_SHEET_CELL = "$($j.cell)"
  $env:SW_SHEET_TITLE = $j.t; $env:SW_SHEET_BG = $j.bg; $env:SW_SHEET_MAX = "$($j.max)"
  & $Godot --path $Repo --resolution 320x200 "tools/sheet.tscn" 2>&1 | Select-String "SHEET\]" | Select-Object -First 1
}
Get-ChildItem Env:SW_SHEET_* | ForEach-Object { Remove-Item ("Env:" + $_.Name) }
Write-Host "SHEETS DONE"
