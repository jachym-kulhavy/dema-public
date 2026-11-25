# Marty: one-paste installer for Windows. In PowerShell:
#   irm https://jachym-kulhavy.github.io/dema-public/marty/install.ps1 | iex
# Installs what is missing (Git, Python 3.12, Claude Code, optionally the free Microsoft VC++ runtime),
# then downloads Marty and starts its setup. Skips anything already installed. Changes nothing else.
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Say([string]$t) { Write-Host $t -ForegroundColor Cyan }
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path", "User") + ";$env:USERPROFILE\.local\bin"
}
function Has([string]$cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Has-Python {
  # "python" can be the Microsoft Store stub that only opens the Store; ask for a real version.
  try { return ((& python -c "import sys; print(sys.version_info[:2] >= (3, 10))" 2>$null) -eq "True") } catch { return $false }
}
function Winget([string]$id) {
  if (-not (Has winget)) { return $false }
  & winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements | Out-Host
  return ($LASTEXITCODE -eq 0)
}
function Download([string]$url) {
  $f = Join-Path $env:TEMP ([IO.Path]::GetFileName(([Uri]$url).AbsolutePath))
  Invoke-WebRequest -Uri $url -OutFile $f -UseBasicParsing
  return $f
}

Write-Host ""
Write-Host "Marty: instalace" -ForegroundColor Yellow
Write-Host "Doinstaluji jen to, co chybi. Muze to trvat 5-15 minut, okno nezavirejte."
Write-Host ""

if (-not (Has git)) {
  Say "1/4 Instaluji Git..."
  if (-not (Winget "Git.Git")) {
    $rel = Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest" -UseBasicParsing
    $exe = ($rel.assets | Where-Object { $_.name -match '^Git-[\d.]+-64-bit\.exe$' } | Select-Object -First 1).browser_download_url
    Start-Process (Download $exe) -ArgumentList "/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES" -Wait
  }
  Refresh-Path
} else { Say "1/4 Git uz mate." }

if (-not (Has-Python)) {
  Say "2/4 Instaluji Python 3.12..."
  if (-not (Winget "Python.Python.3.12")) {
    $exe = Download "https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe"
    Start-Process $exe -ArgumentList "/quiet", "InstallAllUsers=0", "PrependPath=1", "Include_launcher=1" -Wait
  }
  Refresh-Path
} else { Say "2/4 Python uz mate." }

if (-not (Has claude)) {
  Say "3/4 Instaluji Claude Code..."
  Invoke-RestMethod "https://claude.ai/install.ps1" -UseBasicParsing | Invoke-Expression
  Refresh-Path
} else { Say "3/4 Claude Code uz mate." }

# Needed only to turn speech in videos into text; Windows may ask for permission (it is from Microsoft).
if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64")) {
  Say "    Doinstaluji Microsoft Visual C++ (prepis reci z videi)..."
  try {
    if (-not (Winget "Microsoft.VCRedist.2015+.x64")) {
      Start-Process (Download "https://aka.ms/vs/17/release/vc_redist.x64.exe") -ArgumentList "/install", "/quiet", "/norestart" -Wait
    }
  } catch { Write-Host "    Nepovedlo se, Marty funguje i bez nej (jen neprepise rec z videi)." }
}

foreach ($c in "git", "claude") {
  if (-not (Has $c)) { Write-Host "Chybi $c. Zavrete PowerShell, otevrete novy a vlozte prikaz znovu." -ForegroundColor Red; return }
}
if (-not (Has-Python)) { Write-Host "Python se nepodarilo nainstalovat. Zavrete PowerShell, otevrete novy a vlozte prikaz znovu." -ForegroundColor Red; return }

Say "4/4 Stahuji Martyho..."
# The release repo is private: the access code from the purchase e-mail is a read-only GitHub token for it.
# It is kept only in the Marty source URL on this PC (Claude Code uses it for updates); never typed into a prompt
# window of Git, so it does not replace the user's own GitHub login.
$env:GIT_TERMINAL_PROMPT = "0"
$url = "https://github.com/jachym-kulhavy/marty.git"
function Can-Read([string]$u) { & git -c credential.helper= ls-remote $u 2>$null | Out-Null; return ($LASTEXITCODE -eq 0) }
if (-not (Can-Read $url)) {
  for ($i = 0; $i -lt 3; $i++) {
    $code = (Read-Host "Zadejte pristupovy kod (dostali jste ho po zaplaceni)").Trim()
    $try = "https://x-access-token:$code@github.com/jachym-kulhavy/marty.git"
    if ($code -and (Can-Read $try)) { $url = $try; break }
    Write-Host "Kod nefunguje. Zkontrolujte ho (bez mezer) a zkuste znovu." -ForegroundColor Red
  }
  if ($url -notmatch "x-access-token") { Write-Host "Bez platneho kodu Martyho stahnout nejde." -ForegroundColor Red; return }
}
$src = Join-Path $env:LOCALAPPDATA "Marty\instalator"
if (Test-Path $src) { Remove-Item $src -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Split-Path $src) | Out-Null
git -c credential.helper= clone --quiet --depth 1 $url $src
if (-not (Test-Path "$src\instalace.bat")) { Write-Host "Martyho se nepodarilo stahnout. Mate internet?" -ForegroundColor Red; return }
$env:MARTY_SOURCE = $url
& cmd /c "`"$src\instalace.bat`""
