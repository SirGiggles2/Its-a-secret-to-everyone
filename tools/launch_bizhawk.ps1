param(
    [string]$RomPath = "",
    [string]$LuaPath = "",
    [switch]$Wait
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-InputPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        throw "Path cannot be empty."
    }

    $candidate = $PathValue
    if (-not [System.IO.Path]::IsPathRooted($candidate)) {
        $candidate = Join-Path $script:Root $candidate
    }

    return (Resolve-Path -LiteralPath $candidate).Path
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$EmuPath = Resolve-InputPath "BizHawk-2.11-win-x64\EmuHawk.exe"

if ([string]::IsNullOrWhiteSpace($RomPath)) {
    $RomPath = "builds\whatif.md"
}

$ResolvedRom = Resolve-InputPath $RomPath
$ResolvedLua = $null
if (-not [string]::IsNullOrWhiteSpace($LuaPath)) {
    $ResolvedLua = Resolve-InputPath $LuaPath
}

$BizHawkDir = Split-Path -Parent $EmuPath
$CmdPath = Join-Path $env:TEMP ("whatif_bizhawk_{0}.cmd" -f [guid]::NewGuid().ToString("N"))
$StartFlags = ""
if ($Wait) {
    $StartFlags = "/wait "
}

$LaunchLine = 'start "" {0}"{1}"' -f $StartFlags, $EmuPath
if ($ResolvedLua) {
    $LaunchLine += ' "--lua={0}"' -f $ResolvedLua
}
$LaunchLine += ' "{0}"' -f $ResolvedRom

$CmdLines = @(
    "@echo off"
    ('pushd "{0}" >nul' -f $BizHawkDir)
    $LaunchLine
    'set "EXITCODE=%ERRORLEVEL%"'
    'popd >nul'
    'exit /b %EXITCODE%'
)

Set-Content -LiteralPath $CmdPath -Value $CmdLines -Encoding Ascii

try {
    & $env:ComSpec "/c" ('"' + $CmdPath + '"')
    exit $LASTEXITCODE
}
finally {
    Remove-Item -LiteralPath $CmdPath -ErrorAction SilentlyContinue
}
