# ============================================================
#  Nyantivirus  (=^･ω･^=)  -  the cutest antivirus in the world
#  Microsoft Defender + ClamAV control panel. Auto-elevates.
#  https://github.com/  (open source, MIT)
# ============================================================

# ---- Auto-elevation (admin) ----
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $argList = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList $argList
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($true)

# ---- Portable paths ----
$AppDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$Assets = Join-Path $AppDir "assets"
$HistoryFile = Join-Path $AppDir "scan-history.log"

$ClamDir        = "C:\Program Files\ClamAV"
$ClamScan       = Join-Path $ClamDir "clamscan.exe"
$FreshClam      = Join-Path $ClamDir "freshclam.exe"
$ClamDb         = Join-Path $ClamDir "database"
$ClamConf       = Join-Path $ClamDir "freshclam.conf"
$ClamConfSample = Join-Path $ClamDir "conf_examples\freshclam.conf.sample"

$MpCmd = Get-ChildItem "$env:ProgramData\Microsoft\Windows Defender\Platform\*\MpCmdRun.exe" -ErrorAction SilentlyContinue |
         Sort-Object FullName | Select-Object -Last 1 -ExpandProperty FullName
if (-not $MpCmd) { $MpCmd = "C:\Program Files\Windows Defender\MpCmdRun.exe" }

# ============================================================
#  Kawaii palette
# ============================================================
$cTop    = [System.Drawing.Color]::FromArgb(255,224,240)
$cBot    = [System.Drawing.Color]::FromArgb(232,222,255)
$cCard   = [System.Drawing.Color]::FromArgb(255,255,255)
$cText   = [System.Drawing.Color]::FromArgb(120,60,100)
$cAccent = [System.Drawing.Color]::FromArgb(255,105,170)
$cGreen  = [System.Drawing.Color]::FromArgb(70,180,130)
$cAmber  = [System.Drawing.Color]::FromArgb(230,150,40)
$cRed    = [System.Drawing.Color]::FromArgb(235,90,120)
$cPink   = [System.Drawing.Color]::FromArgb(255,182,213)
$cPinkH  = [System.Drawing.Color]::FromArgb(255,160,200)
$cLav    = [System.Drawing.Color]::FromArgb(214,190,255)
$cLavH   = [System.Drawing.Color]::FromArgb(198,170,250)
$cMint   = [System.Drawing.Color]::FromArgb(186,240,214)
$cMintH  = [System.Drawing.Color]::FromArgb(165,230,198)

# ---- Kawaii font (Sniglet) ----
$script:kfam = $null
$script:kstyle = [System.Drawing.FontStyle]::Regular
try {
    $pfc = New-Object System.Drawing.Text.PrivateFontCollection
    $pfc.AddFontFile((Join-Path $Assets "Sniglet-Regular.ttf"))
    $script:kfam = $pfc.Families[0]
    if     ($script:kfam.IsStyleAvailable([System.Drawing.FontStyle]::Bold))    { $script:kstyle = [System.Drawing.FontStyle]::Bold }
    elseif ($script:kfam.IsStyleAvailable([System.Drawing.FontStyle]::Regular)) { $script:kstyle = [System.Drawing.FontStyle]::Regular }
    else   { $script:kstyle = [System.Drawing.FontStyle]::Italic }
} catch { $script:kfam = $null }
function KFont {
    param([single]$size)
    try { if ($script:kfam) { return (New-Object System.Drawing.Font($script:kfam,$size,$script:kstyle)) } else { throw } }
    catch { return (New-Object System.Drawing.Font("Comic Sans MS",$size,[System.Drawing.FontStyle]::Bold)) }
}
$fTitle = KFont 23
$fBtn   = KFont 10.5
$fMasc  = New-Object System.Drawing.Font("Comic Sans MS",15,[System.Drawing.FontStyle]::Bold)
$fSub   = New-Object System.Drawing.Font("Comic Sans MS",9.5)
$fMono  = New-Object System.Drawing.Font("Consolas",9)

# ---- Emoji loader ----
function Load-Emoji {
    param([string]$code, [int]$size = 24)
    $p = Join-Path $Assets "$code.png"
    if (-not (Test-Path $p)) { return $null }
    try {
        $img = [System.Drawing.Image]::FromFile($p)
        $bmp = New-Object System.Drawing.Bitmap($size,$size)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.DrawImage($img,0,0,$size,$size)
        $g.Dispose(); $img.Dispose()
        return $bmp
    } catch { return $null }
}

# ---- Rounded corners ----
function Set-Rounded {
    param($ctrl, [int]$radius)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = $radius; $w = $ctrl.Width; $h = $ctrl.Height
    $path.AddArc(0,0,$r,$r,180,90)
    $path.AddArc($w-$r,0,$r,$r,270,90)
    $path.AddArc($w-$r,$h-$r,$r,$r,0,90)
    $path.AddArc(0,$h-$r,$r,$r,90,90)
    $path.CloseAllFigures()
    $ctrl.Region = New-Object System.Drawing.Region($path)
}

# ---- Sounds ----
function Play-Sound {
    param([string]$notes)
    try {
        $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
        $ps = [powershell]::Create(); $ps.Runspace = $rs
        [void]$ps.AddScript("try{$notes}catch{}")
        [void]$ps.BeginInvoke()
    } catch {}
}
function Play-Blip { try { [System.Media.SystemSounds]::Asterisk.Play() } catch {} }
function Play-Nya { Play-Sound '[Console]::Beep(784,110);[Console]::Beep(988,110);[Console]::Beep(1318,150)' }
function Play-Win { Play-Sound '[Console]::Beep(659,90);[Console]::Beep(784,90);[Console]::Beep(988,90);[Console]::Beep(1318,200)' }

# ---- Animation / scan state ----
$script:frame = 0
$script:danceTicks = 0
$script:scanning = $false
$script:scanProc = $null
$script:scanTmp = $null
$script:scanLabel = ""
$script:moodFrames = 0
$script:catMood = "normal"
$script:catBaseY = 22
$script:catBaseX = 14
function Start-Dance { param([int]$ticks = 175) $script:danceTicks = $ticks }
function Set-CatMood { param([string]$m) $script:catMood = $m; $script:moodFrames = 95 }

# ============================================================
#  Main window
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Nyantivirus"
$form.Size = New-Object System.Drawing.Size(770,696)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = $cTop
$form.ForeColor = $cText
$form.Font = $fSub
$bf = [System.Reflection.BindingFlags]"Instance,NonPublic"
$form.GetType().GetProperty('DoubleBuffered',$bf).SetValue($form,$true,$null)
try { $ico = Join-Path $AppDir "nyantivirus.ico"; if (Test-Path $ico) { $form.Icon = New-Object System.Drawing.Icon($ico) } } catch {}

# ---- Drag ----
$script:dragging = $false; $script:dragStart = $null; $script:formStart = $null
function Wire-Drag {
    param($c)
    $c.Add_MouseDown({ param($s,$e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:dragging = $true; $script:dragStart = [System.Windows.Forms.Cursor]::Position; $script:formStart = $form.Location } })
    $c.Add_MouseMove({ param($s,$e) if ($script:dragging) {
        $cur = [System.Windows.Forms.Cursor]::Position
        $form.Location = New-Object System.Drawing.Point(($script:formStart.X + $cur.X - $script:dragStart.X),($script:formStart.Y + $cur.Y - $script:dragStart.Y)) } })
    $c.Add_MouseUp({ $script:dragging = $false })
}
Wire-Drag $form

# ---- Title / subtitle / cat mascot ----
$title = New-Object System.Windows.Forms.Label
$title.Text = "Nyantivirus"; $title.Font = $fTitle; $title.ForeColor = $cAccent
$title.Location = New-Object System.Drawing.Point(58,14); $title.Size = New-Object System.Drawing.Size(420,44)
$title.BackColor = [System.Drawing.Color]::Transparent; $form.Controls.Add($title); Wire-Drag $title

$titleCat = New-Object System.Windows.Forms.PictureBox
$titleCat.Image = Load-Emoji '1f431' 40
$titleCat.Size = New-Object System.Drawing.Size(40,40)
$titleCat.Location = New-Object System.Drawing.Point(14,16); $titleCat.SizeMode = "Zoom"
$titleCat.BackColor = [System.Drawing.Color]::Transparent; $form.Controls.Add($titleCat); Wire-Drag $titleCat

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "the cutest antivirus in the world  (｡•̀ᴗ-)✧"; $subtitle.Font = $fSub
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(170,110,150)
$subtitle.Location = New-Object System.Drawing.Point(60,56); $subtitle.Size = New-Object System.Drawing.Size(430,20)
$subtitle.BackColor = [System.Drawing.Color]::Transparent; $form.Controls.Add($subtitle); Wire-Drag $subtitle

$mascot = New-Object System.Windows.Forms.Label
$mascot.Text = "(=^･ω･^=)"; $mascot.Font = $fMasc; $mascot.ForeColor = $cAccent
$mascot.Location = New-Object System.Drawing.Point(500,22); $mascot.Size = New-Object System.Drawing.Size(180,34)
$mascot.TextAlign = "MiddleCenter"; $mascot.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($mascot); Wire-Drag $mascot

# ---- Close / minimize ----
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "x"; $btnClose.Location = New-Object System.Drawing.Point(726,12); $btnClose.Size = New-Object System.Drawing.Size(30,30)
$btnClose.FlatStyle = "Flat"; $btnClose.FlatAppearance.BorderSize = 0; $btnClose.FlatAppearance.MouseOverBackColor = $cRed
$btnClose.BackColor = $cPink; $btnClose.ForeColor = $cCard; $btnClose.Font = $fBtn; $btnClose.Cursor = "Hand"
$btnClose.Add_Click({ $form.Close() }); $form.Controls.Add($btnClose); Set-Rounded $btnClose 15

$btnMin = New-Object System.Windows.Forms.Button
$btnMin.Text = "-"; $btnMin.Location = New-Object System.Drawing.Point(690,12); $btnMin.Size = New-Object System.Drawing.Size(30,30)
$btnMin.FlatStyle = "Flat"; $btnMin.FlatAppearance.BorderSize = 0; $btnMin.FlatAppearance.MouseOverBackColor = $cLavH
$btnMin.BackColor = $cLav; $btnMin.ForeColor = $cCard; $btnMin.Font = $fBtn; $btnMin.Cursor = "Hand"
$btnMin.Add_Click({ Minimize-ToTray }); $form.Controls.Add($btnMin); Set-Rounded $btnMin 15

# ---- Status card ----
$statusBox = New-Object System.Windows.Forms.Label
$statusBox.Location = New-Object System.Drawing.Point(16,86); $statusBox.Size = New-Object System.Drawing.Size(738,74)
$statusBox.BackColor = $cCard; $statusBox.ForeColor = $cText
$statusBox.Padding = New-Object System.Windows.Forms.Padding(16,8,8,8); $statusBox.Font = $fMono
$statusBox.Text = "Status: click 'Refresh' (＾▽＾)"; $form.Controls.Add($statusBox); Set-Rounded $statusBox 22

# ---- Log ----
$log = New-Object System.Windows.Forms.RichTextBox
$log.Location = New-Object System.Drawing.Point(16,408); $log.Size = New-Object System.Drawing.Size(738,232)
$log.BackColor = [System.Drawing.Color]::FromArgb(255,245,250); $log.ForeColor = $cText
$log.Font = $fMono; $log.ReadOnly = $true; $log.BorderStyle = "None"; $form.Controls.Add($log)

function Write-Log {
    param([string]$msg, [System.Drawing.Color]$color = $cText)
    $stamp = (Get-Date -Format "HH:mm:ss")
    $log.SelectionStart = $log.TextLength
    $log.SelectionColor = [System.Drawing.Color]::FromArgb(200,150,180); $log.AppendText("[$stamp] ")
    $log.SelectionColor = $color; $log.AppendText("$msg`n")
    $log.SelectionStart = $log.TextLength; $log.ScrollToCaret()
}
function Add-History {
    param([string]$line)
    try { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $line" | Add-Content -Path $HistoryFile -Encoding UTF8 } catch {}
}

# ============================================================
#  Defender / ClamAV actions
# ============================================================
function Refresh-Status {
    try {
        $s = Get-MpComputerStatus
        $p = Get-MpPreference
        $rt   = if ($s.RealTimeProtectionEnabled) { "ON" } else { "OFF" }
        $mode = $s.AMRunningMode
        $sig  = $s.AntivirusSignatureVersion
        $sigD = $s.AntivirusSignatureLastUpdated
        $cbl  = switch ($p.CloudBlockLevel) { 0 {"Default"} 2 {"High"} 4 {"High+"} 6 {"Zero-Tol"} default {"$($p.CloudBlockLevel)"} }
        $clam = if (Test-Path $ClamScan) { "installed" } else { "absent" }
        $dbOk = if ((Test-Path $ClamDb) -and (Get-ChildItem $ClamDb -Filter *.c?d -ErrorAction SilentlyContinue)) { "db OK" } else { "db missing" }
        $face = if ($s.RealTimeProtectionEnabled) { "(=^‥^=) you're safe!" } else { "(>﹏<) watch out!" }
        $statusBox.Text = " Defender : real-time $rt | mode $mode | cloud $cbl`r`n" +
                          " Defs     : v$sig  (updated $sigD)`r`n" +
                          " ClamAV   : $clam ($dbOk)     $face"
        if ($s.RealTimeProtectionEnabled) { $statusBox.ForeColor = $cGreen } else { $statusBox.ForeColor = $cRed }
    } catch {
        $statusBox.Text = " Status read error: $($_.Exception.Message)"; $statusBox.ForeColor = $cRed
    }
}

function Start-DefenderScan {
    param([int]$type, [string]$label, [string]$path = $null)
    if ($script:scanning) { Write-Log "A scan is already running, let the kitty finish (=^･ｪ･^=)" $cAmber; return }
    $a = @("-Scan","-ScanType","$type")
    if ($path) { $a += @("-File",$path) }
    try {
        $script:scanTmp = [System.IO.Path]::GetTempFileName()
        $script:scanProc = Start-Process -FilePath $MpCmd -ArgumentList $a -NoNewWindow -PassThru -RedirectStandardOutput $script:scanTmp
        $script:scanning = $true
        $script:scanLabel = $label
        Write-Log "$label started - running in background, the kitty tells you when it's done (=^-ω-^=)" $cAccent
        Write-Log "♪ petals falling, kitty dancing while it scans ♪ ┌(･o･)┘" $cAccent
    } catch {
        Write-Log "Could not start scan: $($_.Exception.Message)" $cRed
        $script:scanning = $false
    }
}

function On-ScanDone {
    param([int]$code)
    $script:scanning = $false
    if ($code -eq 0) {
        Write-Log "$($script:scanLabel) finished: NO threats found! you're clean (=^▽^=)/" $cGreen
        Set-CatMood "happy"; Start-Confetti; Play-Win
    } else {
        Write-Log "$($script:scanLabel) finished: threat(s) detected! open 'Threats' to review (;ŏ﹏ŏ)" $cRed
        Set-CatMood "worried"
    }
    try {
        if ($script:tray) {
            if ($code -eq 0) { $script:tray.ShowBalloonTip(5000,"Nyantivirus","$($script:scanLabel) finished: no threats! you're clean (=^w^=)",[System.Windows.Forms.ToolTipIcon]::Info) }
            else { $script:tray.ShowBalloonTip(6000,"Nyantivirus","$($script:scanLabel): threat(s) detected! open Threats to review.",[System.Windows.Forms.ToolTipIcon]::Warning) }
        }
    } catch {}
    Add-History "$($script:scanLabel) | exit=$code"
    if ($script:scanTmp -and (Test-Path $script:scanTmp)) { Remove-Item $script:scanTmp -Force -ErrorAction SilentlyContinue }
    Refresh-Status
}

function Update-Defender {
    Write-Log "Updating Defender definitions..." $cAccent
    $form.Cursor = "WaitCursor"
    try {
        if (Get-Command Update-MpSignature -ErrorAction SilentlyContinue) { Update-MpSignature -ErrorAction Stop }
        else { & $MpCmd -SignatureUpdate | Out-Null }
        $v = (Get-MpComputerStatus).AntivirusSignatureVersion
        Write-Log "Definitions up to date (v$v)" $cGreen
    } catch { Write-Log "Update failed: $($_.Exception.Message)" $cRed }
    finally { $form.Cursor = "Default"; Refresh-Status }
}

function Harden-Soft {
    Write-Log "Applying Soft hardening... gently shielding you" $cAccent
    try {
        Set-MpPreference -CloudBlockLevel High -ErrorAction Stop
        Set-MpPreference -CloudExtendedTimeout 50 -ErrorAction Stop
        Set-MpPreference -PUAProtection Enabled -ErrorAction Stop
        Set-MpPreference -MAPSReporting Advanced -ErrorAction Stop
        Set-MpPreference -SubmitSamplesConsent SendSafeSamples -ErrorAction Stop
        Write-Log "Soft hardening applied (cloud High, PUA, MAPS) \(^o^)/" $cGreen
    } catch { Write-Log "Hardening failed: $($_.Exception.Message)" $cRed }
    finally { Refresh-Status }
}

function Ensure-ClamConf {
    if (-not (Test-Path $ClamDb)) { New-Item -ItemType Directory -Path $ClamDb -Force | Out-Null }
    if (-not (Test-Path $ClamConf)) {
        if (-not (Test-Path $ClamConfSample)) { throw "Config template not found: $ClamConfSample" }
        $out = foreach ($l in (Get-Content $ClamConfSample)) { if ($l -match '^\s*Example\s*$') { continue }; $l }
        $out += "DatabaseDirectory `"$ClamDb`""
        $out += 'DatabaseMirror database.clamav.net'
        Set-Content -Path $ClamConf -Value $out -Encoding ASCII
        Write-Log "ClamAV config created (freshclam.conf)" $cGreen
    }
}

function Update-Clam {
    if (-not (Test-Path $FreshClam)) { Write-Log "freshclam.exe not found." $cRed; return }
    try {
        Ensure-ClamConf
        Write-Log "Updating ClamAV virus db (separate window, ~150 MB first time)..." $cAccent
        Start-Dance
        Start-Process cmd.exe -ArgumentList "/k","`"$FreshClam`" --config-file=`"$ClamConf`" & echo. & echo === Done! you can close this (^_^) ==="
    } catch { Write-Log "ClamAV setup/update failed: $($_.Exception.Message)" $cRed }
}

function Scan-Clam {
    param([string]$path)
    if (-not (Test-Path $ClamScan)) { Write-Log "clamscan.exe not found." $cRed; return }
    $hasDb = (Test-Path $ClamDb) -and (Get-ChildItem $ClamDb -Filter *.c?d -ErrorAction SilentlyContinue)
    if (-not $hasDb) { Write-Log "Virus db missing -> click 'ClamAV: Setup + Update' first (・_・;)" $cAmber; return }
    Write-Log "ClamAV scanning '$path' (separate window)..." $cAccent
    Start-Dance
    $cmd = "`"$ClamScan`" -r -i --bell --database=`"$ClamDb`" `"$path`" & echo. & echo === Scan done! (b ᵔ▽ᵔ)b ==="
    Start-Process cmd.exe -ArgumentList "/k",$cmd
}

function Pick-Folder {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Pick a folder to scan"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
    return $null
}

# ---- Threats viewer ----
function Get-ThreatText {
    $sb = New-Object System.Text.StringBuilder
    try {
        $threats = @(Get-MpThreat -ErrorAction SilentlyContinue)
        $det = @(Get-MpThreatDetection -ErrorAction SilentlyContinue)
        if ($threats.Count -eq 0 -and $det.Count -eq 0) {
            [void]$sb.AppendLine("No threats on record - you're squeaky clean! (=^▽^=)/")
        } else {
            [void]$sb.AppendLine("=== Known threats ($($threats.Count)) ===")
            foreach ($t in $threats) { [void]$sb.AppendLine(" - $($t.ThreatName)  [severity $($t.SeverityID)]") }
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("=== Detections ($($det.Count)) ===")
            foreach ($d in ($det | Select-Object -First 30)) {
                $res = ($d.Resources -join ", ")
                [void]$sb.AppendLine(" - $($d.InitialDetectionTime)  $res")
            }
        }
    } catch { [void]$sb.AppendLine("Could not read threats: $($_.Exception.Message)") }
    return $sb.ToString()
}

function Show-Threats {
    $tf = New-Object System.Windows.Forms.Form
    $tf.Text = "Nyantivirus - Threats"; $tf.Size = New-Object System.Drawing.Size(580,460)
    $tf.StartPosition = "CenterParent"; $tf.BackColor = $cTop; $tf.ForeColor = $cText; $tf.Font = $fSub
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "(=^･ω･^=) Threats & detections"; $lbl.Font = (KFont 14); $lbl.ForeColor = $cAccent
    $lbl.Location = New-Object System.Drawing.Point(16,12); $lbl.Size = New-Object System.Drawing.Size(540,30); $tf.Controls.Add($lbl)
    $box = New-Object System.Windows.Forms.TextBox
    $box.Multiline = $true; $box.ReadOnly = $true; $box.ScrollBars = "Vertical"; $box.Font = $fMono
    $box.BackColor = $cCard; $box.BorderStyle = "FixedSingle"
    $box.Location = New-Object System.Drawing.Point(16,50); $box.Size = New-Object System.Drawing.Size(540,300)
    $box.Text = (Get-ThreatText); $tf.Controls.Add($box)
    $bRem = New-Object System.Windows.Forms.Button
    $bRem.Text = "Remove all threats"; $bRem.Location = New-Object System.Drawing.Point(16,366); $bRem.Size = New-Object System.Drawing.Size(180,40)
    $bRem.FlatStyle = "Flat"; $bRem.FlatAppearance.BorderSize = 0; $bRem.BackColor = $cPink; $bRem.ForeColor = $cText; $bRem.Font = $fBtn; $bRem.Cursor = "Hand"
    $bRem.Add_Click({ try { Remove-MpThreat -ErrorAction Stop; $box.Text = (Get-ThreatText); Write-Log "Removed all active threats (=^-^=)" $cGreen } catch { Write-Log "Remove failed: $($_.Exception.Message)" $cRed } })
    $tf.Controls.Add($bRem); Set-Rounded $bRem 18
    $bEicar = New-Object System.Windows.Forms.Button
    $bEicar.Text = "Drop EICAR test"; $bEicar.Location = New-Object System.Drawing.Point(206,366); $bEicar.Size = New-Object System.Drawing.Size(170,40)
    $bEicar.FlatStyle = "Flat"; $bEicar.FlatAppearance.BorderSize = 0; $bEicar.BackColor = $cMint; $bEicar.ForeColor = $cText; $bEicar.Font = $fBtn; $bEicar.Cursor = "Hand"
    $bEicar.Add_Click({ Drop-Eicar })
    $tf.Controls.Add($bEicar); Set-Rounded $bEicar 18
    $bClose = New-Object System.Windows.Forms.Button
    $bClose.Text = "Close"; $bClose.Location = New-Object System.Drawing.Point(456,366); $bClose.Size = New-Object System.Drawing.Size(100,40)
    $bClose.FlatStyle = "Flat"; $bClose.FlatAppearance.BorderSize = 0; $bClose.BackColor = $cLav; $bClose.ForeColor = $cText; $bClose.Font = $fBtn; $bClose.Cursor = "Hand"
    $bClose.Add_Click({ $tf.Close() })
    $tf.Controls.Add($bClose); Set-Rounded $bClose 18
    [void]$tf.ShowDialog($form)
}

# ---- EICAR test (built from fragments so this script itself isn't flagged) ----
function Drop-Eicar {
    $r = [System.Windows.Forms.MessageBox]::Show(
        "Drop the harmless EICAR test file? Defender should instantly catch & quarantine it - this proves real-time protection works. (=^･ｪ･^=)",
        "EICAR test", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($r -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $parts = @('X5O!P','%@AP[4\P','ZX54(P^)','7CC)7}','$EICAR-STANDARD-','ANTIVIRUS-TEST-FILE!','$H+H*')
    $eicar = -join $parts
    $f = Join-Path $env:TEMP 'nyan-eicar-test.txt'
    try {
        Set-Content -Path $f -Value $eicar -Encoding ASCII -ErrorAction Stop
        Write-Log "EICAR test dropped -> Defender should quarantine it in a few seconds (=^･ｪ･^=)" $cAccent
        Write-Log "If real-time protection works, the file vanishes. Click 'Threats' to confirm." $cAccent
    } catch {
        Write-Log "EICAR already blocked on write -> real-time protection is WORKING! (=^▽^=)/" $cGreen
    }
}

function Show-History {
    if (Test-Path $HistoryFile) { Start-Process notepad.exe $HistoryFile }
    else { Write-Log "No scan history yet - run a scan first (=^･ω･^=)" $cAccent }
}

# ============================================================
#  Buttons
# ============================================================
function New-Btn {
    param([string]$text, [int]$x, [int]$y, [int]$w, [string]$emoji, [scriptblock]$onClick,
          [System.Drawing.Color]$base = $cPink, [System.Drawing.Color]$hover = $cPinkH)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = "  $text"; $b.Location = New-Object System.Drawing.Point($x,$y); $b.Size = New-Object System.Drawing.Size($w,44)
    $b.FlatStyle = "Flat"; $b.FlatAppearance.BorderSize = 0; $b.FlatAppearance.MouseOverBackColor = $hover
    $b.BackColor = $base; $b.ForeColor = $cText; $b.Font = $fBtn; $b.Cursor = "Hand"; $b.TextAlign = "MiddleLeft"
    $b.Padding = New-Object System.Windows.Forms.Padding(6,0,2,0)
    if ($emoji) { $img = Load-Emoji $emoji 22; if ($img) { $b.Image = $img; $b.ImageAlign = "MiddleLeft"; $b.TextImageRelation = "ImageBeforeText" } }
    $b.Tag = @{ x = $x; y = $y; w = $w; h = 44 }
    $b.Add_MouseEnter({ param($s,$e) $t = $s.Tag
        $s.Location = New-Object System.Drawing.Point(($t.x-3),($t.y-3)); $s.Size = New-Object System.Drawing.Size(($t.w+6),($t.h+6)); Set-Rounded $s 22 })
    $b.Add_MouseLeave({ param($s,$e) $t = $s.Tag
        $s.Location = New-Object System.Drawing.Point($t.x,$t.y); $s.Size = New-Object System.Drawing.Size($t.w,$t.h); Set-Rounded $s 20 })
    $b.Add_Click({ Play-Blip })
    $b.Add_Click($onClick)
    $form.Controls.Add($b); Set-Rounded $b 20
    return $b
}

$y1 = 170; $y2 = 222; $y3 = 274; $y4 = 326

# Row 1 : status + Defender scans (pink)
New-Btn "Refresh"     16  $y1 176 '1f504' { Refresh-Status; Write-Log "Status refreshed (>'-')>" $cAccent } | Out-Null
New-Btn "Quick scan"  200 $y1 172 '26a1'  { Start-DefenderScan 1 "Quick scan" } | Out-Null
New-Btn "Full scan"   380 $y1 172 '1f50d' { Start-DefenderScan 2 "Full scan" } | Out-Null
New-Btn "Scan folder" 560 $y1 194 '1f4c1' { $p = Pick-Folder; if ($p) { Start-DefenderScan 3 "Folder scan" $p } } | Out-Null

# Row 2 : maintenance + hardening (lavender)
New-Btn "Update defs"      16  $y2 176 '2b07'  { Update-Defender } $cLav $cLavH | Out-Null
New-Btn "Harden (Soft)"    200 $y2 172 '1f6e1' { Harden-Soft } $cLav $cLavH | Out-Null
New-Btn "Windows Security" 380 $y2 374 '2699'  { Start-Process "windowsdefender:" } $cLav $cLavH | Out-Null

# Row 3 : ClamAV (mint)
New-Btn "ClamAV: Setup + Update" 16  $y3 368 '1f41b' { Update-Clam } $cMint $cMintH | Out-Null
New-Btn "ClamAV: Scan folder"    388 $y3 366 '1f9f9' { $p = Pick-Folder; if ($p) { Scan-Clam $p } } $cMint $cMintH | Out-Null

# Row 4 : threats / test / history (pink)
New-Btn "Threats"   16  $y4 176 '26a0'  { Show-Threats } | Out-Null
New-Btn "EICAR test" 200 $y4 172 '1f9ea' { Drop-Eicar } | Out-Null
New-Btn "History"   380 $y4 374 '1f4dc' { Show-History } | Out-Null

# ============================================================
#  Animation engine
# ============================================================
$pchars = @('♥','✿','❀','✦','✧','★','♡','✩')
$pcols  = @(
    [System.Drawing.Color]::FromArgb(120,255,150,200),
    [System.Drawing.Color]::FromArgb(110,255,255,255),
    [System.Drawing.Color]::FromArgb(120,210,180,255),
    [System.Drawing.Color]::FromArgb(120,255,200,150)
)
$petalCols = @(
    [System.Drawing.Color]::FromArgb(180,255,150,200),
    [System.Drawing.Color]::FromArgb(170,255,120,180),
    [System.Drawing.Color]::FromArgb(160,255,190,220)
)
$confCols = @(
    [System.Drawing.Color]::FromArgb(255,105,170),
    [System.Drawing.Color]::FromArgb(150,110,235),
    [System.Drawing.Color]::FromArgb(70,180,130),
    [System.Drawing.Color]::FromArgb(240,170,60),
    [System.Drawing.Color]::FromArgb(90,170,255)
)
$cats = @('(=^･ω･^=)','(=^‥^=)','(=^･ｪ･^=)','(＾• ω •＾)','( =ω= )','(=｀ω´=)','(=^-ω-^=)')
$danceCats = @('⊂(・▽・⊂)','ヽ(・▽・)ノ','⊃(・▽・)⊃','┌(･o･)┘♪','(づ｡◕‿‿◕｡)づ','└(･o･)┐♪','ヽ(>∀<☆)ノ','＼(^▽^)／')
$danceColors = @(
    [System.Drawing.Color]::FromArgb(255,105,170),
    [System.Drawing.Color]::FromArgb(150,110,235),
    [System.Drawing.Color]::FromArgb(70,180,130),
    [System.Drawing.Color]::FromArgb(240,150,60)
)

# ambient particles (float up)
$script:particles = @()
for ($i = 0; $i -lt 16; $i++) {
    $script:particles += [pscustomobject]@{
        X = Get-Random -Minimum 10 -Maximum 745; Y = Get-Random -Minimum 150 -Maximum 670
        Ch = $pchars[(Get-Random -Minimum 0 -Maximum $pchars.Count)]; Col = $pcols[(Get-Random -Minimum 0 -Maximum $pcols.Count)]
        Speed = (Get-Random -Minimum 3 -Maximum 11) / 10.0 + 0.3; Size = Get-Random -Minimum 10 -Maximum 18
        Sway = Get-Random -Minimum 0 -Maximum 100
    }
}
# petals (fall down, active while scanning/dancing)
$script:petals = @()
for ($i = 0; $i -lt 22; $i++) {
    $script:petals += [pscustomobject]@{
        X = Get-Random -Minimum 0 -Maximum 760; Y = Get-Random -Minimum -300 -Maximum 690
        Speed = (Get-Random -Minimum 9 -Maximum 24) / 10.0; Size = Get-Random -Minimum 12 -Maximum 22
        Sway = Get-Random -Minimum 0 -Maximum 100; Col = $petalCols[(Get-Random -Minimum 0 -Maximum $petalCols.Count)]
        Ch = @('✿','❀','✾')[(Get-Random -Minimum 0 -Maximum 3)]
    }
}
$script:confetti = @()
function Start-Confetti {
    $script:confetti = @()
    for ($i = 0; $i -lt 46; $i++) {
        $script:confetti += [pscustomobject]@{
            X = 385.0; Y = 320.0
            VX = (Get-Random -Minimum -55 -Maximum 55) / 10.0; VY = (Get-Random -Minimum -70 -Maximum -15) / 10.0
            Ch = $pchars[(Get-Random -Minimum 0 -Maximum $pchars.Count)]; Col = $confCols[(Get-Random -Minimum 0 -Maximum $confCols.Count)]
            Life = (Get-Random -Minimum 55 -Maximum 85); Size = Get-Random -Minimum 12 -Maximum 20
        }
    }
}

$form.Add_Paint({ param($s,$e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle(0,0,$form.ClientSize.Width,$form.ClientSize.Height)
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,$cTop,$cBot,[single]90)
    $g.FillRectangle($br,$rect); $br.Dispose()
    # ambient
    foreach ($p in $script:particles) {
        $f = New-Object System.Drawing.Font('Segoe UI Symbol',[single]$p.Size); $sb = New-Object System.Drawing.SolidBrush($p.Col)
        $sx = $p.X + [math]::Sin(($script:frame + $p.Sway) / 18.0) * 8
        $g.DrawString($p.Ch,$f,$sb,[single]$sx,[single]$p.Y); $f.Dispose(); $sb.Dispose()
    }
    # petals (falling) while scanning/dancing
    if ($script:scanning -or $script:danceTicks -gt 0) {
        foreach ($p in $script:petals) {
            $f = New-Object System.Drawing.Font('Segoe UI Symbol',[single]$p.Size); $sb = New-Object System.Drawing.SolidBrush($p.Col)
            $sx = $p.X + [math]::Sin(($script:frame + $p.Sway) / 12.0) * 14
            $g.DrawString($p.Ch,$f,$sb,[single]$sx,[single]$p.Y); $f.Dispose(); $sb.Dispose()
        }
    }
    # confetti burst
    foreach ($c in $script:confetti) {
        $f = New-Object System.Drawing.Font('Segoe UI Symbol',[single]$c.Size); $sb = New-Object System.Drawing.SolidBrush($c.Col)
        $g.DrawString($c.Ch,$f,$sb,[single]$c.X,[single]$c.Y); $f.Dispose(); $sb.Dispose()
    }
    $jf = New-Object System.Drawing.Font('Comic Sans MS',9.5); $jb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(170,110,150))
    $g.DrawString('Journal ♡',$jf,$jb,18,386)
    $g.DrawString('made with ♥ for bebe  (｡♥‿♥｡)',$jf,$jb,470,662)
    $jf.Dispose(); $jb.Dispose()
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 55
$timer.Add_Tick({
    $script:frame++
    # ambient up
    foreach ($p in $script:particles) {
        $p.Y -= $p.Speed
        if ($p.Y -lt 140) { $p.Y = $form.ClientSize.Height + (Get-Random -Minimum 0 -Maximum 40); $p.X = Get-Random -Minimum 10 -Maximum 745; $p.Ch = $pchars[(Get-Random -Minimum 0 -Maximum $pchars.Count)] }
    }
    # petals down while active
    if ($script:scanning -or $script:danceTicks -gt 0) {
        foreach ($p in $script:petals) {
            $p.Y += $p.Speed * 2.2
            if ($p.Y -gt ($form.ClientSize.Height + 10)) { $p.Y = Get-Random -Minimum -60 -Maximum -10; $p.X = Get-Random -Minimum 0 -Maximum 760 }
        }
    }
    # confetti physics
    if ($script:confetti.Count -gt 0) {
        foreach ($c in $script:confetti) { $c.VY += 0.22; $c.X += $c.VX; $c.Y += $c.VY; $c.Life-- }
        $script:confetti = @($script:confetti | Where-Object { $_.Life -gt 0 -and $_.Y -lt ($form.ClientSize.Height + 20) })
    }
    # scan completion
    if ($script:scanning -and $script:scanProc -and $script:scanProc.HasExited) {
        $code = 0; try { $code = $script:scanProc.ExitCode } catch {}
        On-ScanDone $code
    }
    if ($script:danceTicks -gt 0) { $script:danceTicks-- }
    # mascot
    if ($script:moodFrames -gt 0) {
        $script:moodFrames--
        if ($script:catMood -eq "happy") { $mascot.Text = "(=^▽^=)/ all clean!"; $mascot.ForeColor = $cGreen }
        else { $mascot.Text = "(;ŏ﹏ŏ) threat!"; $mascot.ForeColor = $cRed }
        if ($script:moodFrames -eq 0) { $script:catMood = "normal"; $mascot.ForeColor = $cAccent }
    } elseif ($script:scanning -or $script:danceTicks -gt 0) {
        if ($script:frame % 3 -eq 0) { $mascot.Text = $danceCats[([int]($script:frame / 3)) % $danceCats.Count] }
        $mascot.ForeColor = $danceColors[([int]($script:frame / 6)) % $danceColors.Count]
        $titleCat.Left = $script:catBaseX + [int]([math]::Sin($script:frame / 2.2) * 12)
        $titleCat.Top  = $script:catBaseY - [int]([math]::Abs([math]::Sin($script:frame / 3.0)) * 10)
    } else {
        if ($script:frame % 9 -eq 0) { $mascot.Text = $cats[([int]($script:frame / 9)) % $cats.Count]; $mascot.ForeColor = $cAccent }
        $titleCat.Left = $script:catBaseX
        $titleCat.Top  = $script:catBaseY + [int]([math]::Sin($script:frame / 6.0) * 5)
    }
    $form.Invalidate()
})

# ---- Minimize to system tray ----
function Minimize-ToTray { $form.Hide() }
function Restore-FromTray { $form.Show(); $form.WindowState = "Normal"; $form.Activate(); [void]$form.BringToFront() }
$script:tray = New-Object System.Windows.Forms.NotifyIcon
$script:tray.Text = "Nyantivirus (=^w^=)"
try { if ($form.Icon) { $script:tray.Icon = $form.Icon } else { $script:tray.Icon = [System.Drawing.SystemIcons]::Application } } catch { $script:tray.Icon = [System.Drawing.SystemIcons]::Application }
$script:tray.Visible = $true
$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$miOpen = $trayMenu.Items.Add("Open Nyantivirus  (=^w^=)")
$miQuit = $trayMenu.Items.Add("Quit")
$miOpen.Add_Click({ Restore-FromTray })
$miQuit.Add_Click({ $form.Close() })
$script:tray.ContextMenuStrip = $trayMenu
$script:tray.Add_DoubleClick({ Restore-FromTray })
$script:tray.Add_BalloonTipClicked({ Restore-FromTray })

# ---- Start ----
$form.Add_Shown({
    Set-Rounded $form 28
    Refresh-Status
    Write-Log "Nyantivirus ready! admin mode on. Welcome bebe (づ｡◕‿‿◕｡)づ" $cGreen
    Play-Nya
    $timer.Start()
})
$form.Add_FormClosing({ $timer.Stop(); try { $script:tray.Visible = $false; $script:tray.Dispose() } catch {} })
[void]$form.ShowDialog()
