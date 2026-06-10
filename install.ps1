# Nyantivirus installer - creates a desktop shortcut with the cat icon.
# Usage:  powershell -ExecutionPolicy Bypass -File .\install.ps1

$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$bat  = Join-Path $here "Nyantivirus.bat"
$ico  = Join-Path $here "nyantivirus.ico"

if (-not (Test-Path $bat)) { Write-Host "Nyantivirus.bat not found next to install.ps1" -ForegroundColor Red; exit 1 }

$desktop = [Environment]::GetFolderPath("Desktop")
$ws  = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path $desktop "Nyantivirus.lnk"))
$lnk.TargetPath       = $bat
$lnk.WorkingDirectory = $here
if (Test-Path $ico) { $lnk.IconLocation = $ico }
$lnk.Description      = "Nyantivirus - the cutest antivirus in the world"
$lnk.WindowStyle      = 7
$lnk.Save()

Write-Host "Done! Desktop shortcut created. Double-click 'Nyantivirus' to launch (=^w^=)" -ForegroundColor Magenta
