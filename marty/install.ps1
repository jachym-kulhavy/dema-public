# Marty: one-paste installer for Windows. In PowerShell:
#   irm https://jachym-kulhavy.github.io/dema-public/marty/install.ps1 | iex
# Installs what is missing (Git, Python 3.12, Claude Code) without admin rights,
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
function Install-Winget([string]$id) {
  # Named apart from winget.exe: a function called "Winget" finds itself in Has and calls itself forever.
  if (-not (Has winget.exe)) { return $false }
  & winget.exe install --id $id -e --silent --accept-package-agreements --accept-source-agreements | Out-Host
  return ($LASTEXITCODE -eq 0)
}
function Add-UserPath([string]$dir) {
  $p = [Environment]::GetEnvironmentVariable("Path", "User")
  if ((($p -split ";") | ForEach-Object { $_.TrimEnd("\") }) -notcontains $dir.TrimEnd("\")) {
    [Environment]::SetEnvironmentVariable("Path", "$dir;$p", "User")
  }
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
  if (-not (Install-Winget "Git.Git")) {
    # Portable MinGit, no installer and no admin: the full Git installer hangs on a fresh Windows (Sandbox 25. and 27. 11.).
    $rel = Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest" -UseBasicParsing
    $url = ($rel.assets | Where-Object { $_.name -match '^MinGit-[\d.]+-64-bit\.zip$' } | Select-Object -First 1).browser_download_url
    $dir = Join-Path $env:LOCALAPPDATA "Programs\Git"
    Expand-Archive (Download $url) -DestinationPath $dir -Force
    Add-UserPath "$dir\cmd"
  }
  Refresh-Path
} else { Say "1/4 Git uz mate." }

if (-not (Has-Python)) {
  Say "2/4 Instaluji Python 3.12..."
  if (-not (Install-Winget "Python.Python.3.12")) {
    # Official Python build from nuget.org: no installer, no admin (the .exe installer hangs on some PCs).
    $pkg = Join-Path $env:TEMP "python.3.12.10.zip"
    Invoke-WebRequest -Uri "https://api.nuget.org/v3-flatcontainer/python/3.12.10/python.3.12.10.nupkg" -OutFile $pkg -UseBasicParsing
    $tmp = Join-Path $env:TEMP "marty-python"; Expand-Archive $pkg -DestinationPath $tmp -Force
    $dir = Join-Path $env:LOCALAPPDATA "Programs\Python312"
    Copy-Item (Join-Path $tmp "tools") $dir -Recurse -Force
    Add-UserPath "$dir\Scripts"; Add-UserPath $dir
  }
  Refresh-Path
} else { Say "2/4 Python uz mate." }

if (-not (Has claude)) {
  Say "3/4 Instaluji Claude Code..."
  # Own process: the official script may end with "exit", which would end this one too.
  Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://claude.ai/install.ps1 | iex`"" -NoNewWindow -Wait
  Refresh-Path
} else { Say "3/4 Claude Code uz mate." }

foreach ($c in "git", "claude") {
  if (-not (Has $c)) { Write-Host "Chybi $c. Zavrete PowerShell, otevrete novy a vlozte prikaz znovu." -ForegroundColor Red; return }
}
if (-not (Has-Python)) { Write-Host "Python se nepodarilo nainstalovat. Zavrete PowerShell, otevrete novy a vlozte prikaz znovu." -ForegroundColor Red; return }
# Found is not enough: Windows Smart App Control can block git.exe, which then exits silently (seen in Sandbox 27. 11.).
$ErrorActionPreference = "Continue"; $gv = & git --version 2>$null; $gitOk = ($LASTEXITCODE -eq 0); $ErrorActionPreference = "Stop"
if (-not $gitOk) {
  Write-Host "Windows zablokoval Git (asi Smart App Control). Nainstalujte Git z https://git-scm.com/download/win, pak vlozte prikaz znovu." -ForegroundColor Red; return
}

Say "4/4 Stahuji Martyho..."
# The release repo is private: the access code from the purchase e-mail is a read-only GitHub token for it.
# It is kept only in the Marty source URL on this PC (Claude Code uses it for updates); never typed into a prompt
# window of Git, so it does not replace the user's own GitHub login.
$env:GIT_TERMINAL_PROMPT = "0"
$url = "https://github.com/jachym-kulhavy/marty.git"
function Can-Read([string]$u) {
  # PowerShell 5.1: with "Stop", redirected stderr of git ends the whole script before the code prompt.
  $ErrorActionPreference = "Continue"
  & git -c credential.helper= ls-remote $u 2>$null | Out-Null; return ($LASTEXITCODE -eq 0)
}
if (-not (Can-Read $url)) {
  for ($i = 0; $i -lt 3; $i++) {
    $code = "$(Read-Host "Zadejte pristupovy kod (dostali jste ho po zaplaceni)")".Trim()
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
