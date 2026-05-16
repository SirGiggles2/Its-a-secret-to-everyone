$ErrorActionPreference = 'Continue'
$logPath = Join-Path $PSScriptRoot 'test_up_enter_30s.log'

function Log($msg) {
    $line = ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $msg)
    Add-Content -Path $logPath -Value $line -Encoding UTF8
    Write-Host $line
}

try {
    Log "INIT pid=$PID host=$($Host.Name) ver=$($PSVersionTable.PSVersion)"
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Log "ASSEMBLY_LOADED System.Windows.Forms"
} catch {
    Log ("FATAL_INIT " + $_.Exception.Message)
    Start-Sleep 30
    exit 1
}

Log "LOOP_START interval=30s"
$tick = 0
while ($true) {
    Start-Sleep -Seconds 30
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
