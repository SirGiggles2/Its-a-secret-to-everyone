# Auto-prompt Claude Code every 30 min. Press x + Enter to stop.

$sentence = "im not here. Just use the criteria mentioned in /primedirective for goals. use /chuckle and /systematic-debugging to fix things"

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
Add-Type -AssemblyName System.Windows.Forms

# Capture target window right now (should be Claude Code)
$targetHwnd = [Win32]::GetForegroundWindow()
Write-Host "Target window locked. Press x + Enter to stop. First fire in 30 min."

Write-Host "Fires every 30 min. Close this window to stop."

while ($true) {
    Start-Sleep -Seconds 1800
    [Win32]::ShowWindow($targetHwnd, 9)       | Out-Null
    [Win32]::SetForegroundWindow($targetHwnd) | Out-Null
    Start-Sleep -Milliseconds 600
    Set-Clipboard -Value $sentence
    [System.Windows.Forms.SendKeys]::SendWait("^v")
    Start-Sleep -Milliseconds 200
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    Write-Host ("$(Get-Date -Format 'HH:mm:ss') - fired")
}
