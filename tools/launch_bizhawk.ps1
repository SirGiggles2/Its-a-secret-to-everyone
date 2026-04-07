param(
    [string]$RomPath = "",
    [string]$LuaPath = "",
    [switch]$Wait
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Add-Type -Namespace Win32 -Name Native -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet=System.Runtime.InteropServices.CharSet.Auto)]
public static extern int GetShortPathName(string lpszLongPath, System.Text.StringBuilder lpszShortPath, int cchBuffer);
'@

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class BizhawkWindow {
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@

function Resolve-InputPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    $candidate = $PathValue
    if (-not [System.IO.Path]::IsPathRooted($candidate)) {
        $candidate = Join-Path $Root $candidate
    }

    return (Resolve-Path -LiteralPath $candidate).Path
}

function Get-ShortPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    $full = Resolve-InputPath $PathValue
    $sb = New-Object System.Text.StringBuilder 260
    [void][Win32.Native]::GetShortPathName($full, $sb, $sb.Capacity)
    $short = $sb.ToString()
    if ([string]::IsNullOrWhiteSpace($short)) {
        throw "Unable to compute short path for '$full'."
    }
    return $short
}

function Resolve-BizHawkExe {
    $candidates = @(
        (Join-Path $Root "BizHawk-2.11-win-x64\EmuHawk.exe"),
        (Join-Path (Split-Path $Root -Parent) "VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "EmuHawk.exe not found in known locations."
}

if ([string]::IsNullOrWhiteSpace($RomPath)) {
    $RomPath = "builds\whatif.md"
}

$emuLong = Resolve-BizHawkExe
$emuDirLong = Split-Path -Parent $emuLong
$romShort = Get-ShortPath $RomPath
$emuShort = Get-ShortPath $emuLong
$emuDirShort = Get-ShortPath $emuDirLong

$args = @()
if (-not [string]::IsNullOrWhiteSpace($LuaPath)) {
    $luaShort = Get-ShortPath $LuaPath
    $args += "--lua=$luaShort"
}
$args += $romShort

if ($Wait) {
    $p = Start-Process -FilePath $emuShort -ArgumentList $args -WorkingDirectory $emuDirShort -Wait -PassThru
    exit $p.ExitCode
}

$p = Start-Process -FilePath $emuShort -ArgumentList $args -WorkingDirectory $emuDirShort -PassThru
Start-Sleep -Seconds 2
$p.Refresh()
if ($p.HasExited) {
    throw "BizHawk exited immediately with code $($p.ExitCode)."
}

Start-Sleep -Seconds 1
$p = Get-Process -Id $p.Id -ErrorAction Stop
$ws = New-Object -ComObject WScript.Shell
[void]$ws.AppActivate($p.Id)
if ($p.MainWindowHandle -ne 0) {
    [void][BizhawkWindow]::ShowWindowAsync($p.MainWindowHandle, 9)
    [void][BizhawkWindow]::SetForegroundWindow($p.MainWindowHandle)
}
