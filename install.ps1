# Nyantivirus installer - creates Desktop + Start Menu shortcuts with the cat icon.
# Double-click Setup.bat (recommended), or run:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1

$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$bat  = Join-Path $here "Nyantivirus.bat"
$ico  = Join-Path $here "nyantivirus.ico"

Add-Type -AssemblyName System.Windows.Forms

if (-not (Test-Path $bat)) {
    [System.Windows.Forms.MessageBox]::Show("Nyantivirus.bat was not found next to this installer. Please keep all files together in the same folder.","Nyantivirus Setup",'OK','Error') | Out-Null
    exit 1
}

function New-Shortcut {
    param([string]$linkPath)
    $ws  = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut($linkPath)
    $lnk.TargetPath       = $bat
    $lnk.WorkingDirectory = $here
    if (Test-Path $ico) { $lnk.IconLocation = $ico }
    $lnk.Description      = "Nyantivirus - the cutest antivirus in the world"
    $lnk.WindowStyle      = 7
    $lnk.Save()
}

$made = @()

# Desktop shortcut
try {
    $desktop = [Environment]::GetFolderPath("Desktop")
    New-Shortcut (Join-Path $desktop "Nyantivirus.lnk")
    $made += "Desktop"
} catch {}

# Start Menu shortcut
try {
    $startMenu = Join-Path ([Environment]::GetFolderPath("Programs")) "Nyantivirus.lnk"
    New-Shortcut $startMenu
    $made += "Start Menu"
} catch {}

$where = if ($made.Count) { $made -join " and " } else { "(no shortcut could be created)" }
[System.Windows.Forms.MessageBox]::Show("Nyantivirus is installed! (=^w^=)`r`n`r`nLook for the cat icon in: $where`r`n`r`nDouble-click it, accept the Windows admin prompt, and enjoy.","Nyantivirus Setup",'OK','Information') | Out-Null
