$ErrorActionPreference = 'Continue'
$logPath = Join-Path $PSScriptRoot 'every_30min_up_enter.log'

function Log($msg) {
    $line = ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg)
    Add-Content -Path $logPath -Value $line -Encoding UTF8
    Write-Host $line
}

try {
    Log "INIT pid=$PID interval=1800s (30 min)"
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Log "ASSEMBLY_LOADED"
} catch {
    Log ("FATAL_INIT " + $_.Exception.Message)
    Start-Sleep 30
    exit 1
}

Log "LOOP_START first tick in 30 min"
$tick = 0
while ($true) {
    Start-Sleep -Seconds 1800
    $tick++
    try {
        [System.Windows.Forms.SendKeys]::SendWait('{UP}')
        Start-Sleep -Milliseconds 100
        [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
        Log "TICK $tick sent UP+ENTER"
    } catch {
        Log ("TICK $tick ERROR " + $_.Exception.Message)
    }
}
