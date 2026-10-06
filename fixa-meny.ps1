# ============================================================
#  Runriket - fixar undermenyerna sa de fungerar OFFLINE
#
#  PROBLEM: I app.bundle.js laddas undermenyerna ("Runrikets platser"
#  och "I fokus") dynamiskt fran servern via:
#      fetch("/navigation/loadnavigationfragment/?id=...&level=...")
#  Offline finns ingen server, sa undermenyn blir tom.
#
#  LOSNING: JS:en gor bara fetch OM det inte redan finns en <ul> i menyn.
#  Detta skript forinfogar darfor undermenyn som DOLD html (class="hidden")
#  i alla sidor som saknar den. Da visar JS:en bara den befintliga listan
#  nar man klickar - fetchen koras aldrig. Ingen JS behover andras.
#
#  KOR SA HAR: lagg denna fil i arkivets rot (dar index.html ligger) och kor:
#      powershell -ExecutionPolicy Bypass -File .\fixa-meny.ps1
#  Skriptet ar sakert att kora flera ganger (hoppar over redan fixade sidor).
# ============================================================

$ErrorActionPreference = "Stop"

$base = $PSScriptRoot
if (-not $base) { $base = (Get-Location).Path }
$old = Join-Path $base "www.vallentuna.se\runriket"
if (Test-Path $old) { $root = $old } else { $root = $base }

# Undermenyernas lankar (relativt runriket-roten) + titlar (svenska tecken som HTML-entiteter)
$platser = @(
  ,@('runrikets-platser/karta-over-runriket/index.html','Karta &#246;ver Runriket'),
  ,@('runrikets-platser/jarlabankes-bro/index.html','Jarlabankes bro'),
  ,@('runrikets-platser/broby-bro/index.html','Broby bro'),
  ,@('runrikets-platser/taby-kyrka/index.html','T&#228;by kyrka'),
  ,@('runrikets-platser/fallbro/index.html','F&#228;llbro'),
  ,@('runrikets-platser/risbyle/index.html','Risbyle'),
  ,@('runrikets-platser/gallsta/index.html','G&#228;llsta'),
  ,@('runrikets-platser/gullbron/index.html','Gullbron'),
  ,@('runrikets-platser/vallentuna-kyrka/index.html','Vallentuna kyrka'),
  ,@('runrikets-platser/arkils-tingstad/index.html','Arkils tingstad')
)
$ifokus = @(
  ,@('i-fokus/i-was-here---dansrunor/index.html','I was here - Dansrunor')
)

function Build-Ul($items, $prefix) {
  $li = ""
  foreach ($it in $items) {
    $li += '<li><div class="nav-tree__item"><a href="' + $prefix + $it[0] + '">' + $it[1] + '</a></div></li>'
  }
  return '<ul class="nav-tree nav-tree--level-1 hidden">' + $li + '</ul>'
}

function Inject($s, $dataId, $items, $prefix) {
  $idx = $s.IndexOf('data-id="' + $dataId + '"')
  if ($idx -lt 0) { return @{ s = $s; done = $false } }
  $anchor = '</button></div>'
  $j = $s.IndexOf($anchor, $idx)
  if ($j -lt 0) { return @{ s = $s; done = $false } }
  $after = $j + $anchor.Length
  $next = $s.Substring($after, [Math]::Min(4, $s.Length - $after))
  if ($next.StartsWith('<ul'))  { return @{ s = $s; done = $false } }   # redan expanderad
  if (-not $next.StartsWith('</li')) { return @{ s = $s; done = $false } }
  $ul = Build-Ul $items $prefix
  return @{ s = $s.Substring(0, $after) + $ul + $s.Substring($after); done = $true }
}

$utf8 = New-Object System.Text.UTF8Encoding $false   # UTF-8 utan BOM
$files = Get-ChildItem -Path $root -Recurse -Filter index.html
$n434 = 0; $n450 = 0

foreach ($f in $files) {
  $s = [System.IO.File]::ReadAllText($f.FullName)
  $rel = $f.FullName.Substring($root.Length).TrimStart('\').Replace('\','/')
  $depth = ($rel.Split('/').Length) - 1
  $prefix = '../' * $depth

  $r1 = Inject $s '43434' $platser $prefix; $s = $r1.s
  $r2 = Inject $s '43450' $ifokus  $prefix; $s = $r2.s

  if ($r1.done -or $r2.done) { [System.IO.File]::WriteAllText($f.FullName, $s, $utf8) }
  if ($r1.done) { $n434++ }
  if ($r2.done) { $n450++ }
  $p = if ($r1.done) { "INFOGAD" } else { "hoppar" }
  $i = if ($r2.done) { "INFOGAD" } else { "hoppar" }
  Write-Host ("{0,-48} platser:{1}  i-fokus:{2}" -f $rel, $p, $i)
}

Write-Host ""
Write-Host ("KLART. Platser infogad pa $n434 sidor, I fokus pa $n450 sidor.") -ForegroundColor Green
