param(
    [switch]$Build,

    [string]$VsixPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-HintText {
    $hints = @(
        $Env:VSCODE_IPC_HOOK,
        $Env:VSCODE_GIT_ASKPASS_MAIN,
        $Env:TERM_PROGRAM,
        $Env:TERM_PROGRAM_VERSION,
        $Env:CLAUDECODE,
        $Env:CLAUDE_CONFIG_DIR
    )

    if ($Env:VSCODE_PID -and ($Env:VSCODE_PID -as [int])) {
        try {
            $hostProcess = Get-Process -Id ([int]$Env:VSCODE_PID) -ErrorAction Stop
            $hints += $hostProcess.ProcessName
            if ($hostProcess.Path) {
                $hints += $hostProcess.Path
            }
        }
        catch {
            # Ignore process lookup errors.
        }
    }

    return ($hints | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n"
}

function Get-EditorOrder {
    $hintText = Get-HintText

    if ($hintText -match 'Code - Insiders|code-insiders') {
        return @('Code - Insiders', 'Code', 'Cursor', 'Claude')
    }

    if ($hintText -match 'Cursor') {
        return @('Cursor', 'Code', 'Code - Insiders', 'Claude')
    }

    if ($hintText -match 'Claude|claude') {
        return @('Claude', 'Code', 'Code - Insiders', 'Cursor')
    }

    return @('Code', 'Code - Insiders', 'Cursor', 'Claude')
}

function Get-ProfileCandidatesForEditor {
    param([string]$Editor)

    if ($IsWindows) {
        $appData = if ($Env:APPDATA) { $Env:APPDATA } else { $Env:AppData }
        if (-not $appData) {
            return @()
        }

        switch ($Editor) {
            'Code' { return @(Join-Path $appData 'Code\User') }
            'Code - Insiders' { return @(Join-Path $appData 'Code - Insiders\User') }
            'Cursor' { return @(Join-Path $appData 'Cursor\User') }
            'Claude' { return @((Join-Path $appData 'Claude\User'), (Join-Path $appData 'Claude')) }
            default { return @() }
        }
    }

    if ($IsMacOS) {
        switch ($Editor) {
            'Code' { return @("$HOME/Library/Application Support/Code/User") }
            'Code - Insiders' { return @("$HOME/Library/Application Support/Code - Insiders/User") }
            'Cursor' { return @("$HOME/Library/Application Support/Cursor/User") }
            'Claude' { return @("$HOME/Library/Application Support/Claude/User", "$HOME/Library/Application Support/Claude") }
            default { return @() }
        }
    }

    switch ($Editor) {
        'Code' { return @("$HOME/.config/Code/User") }
        'Code - Insiders' { return @("$HOME/.config/Code - Insiders/User") }
        'Cursor' { return @("$HOME/.config/Cursor/User") }
        'Claude' { return @("$HOME/.config/Claude/User", "$HOME/.config/Claude") }
        default { return @() }
    }
}

function Resolve-EditorName {
    $ordered = Get-EditorOrder

    foreach ($editor in $ordered) {
        $candidates = Get-ProfileCandidatesForEditor -Editor $editor
        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath $candidate) {
                return $editor
            }
        }
    }

    return $ordered[0]
}

function Resolve-EditorCli {
    param([string]$Editor)

    $candidates = @()

    if ($IsWindows) {
        $localAppData = $Env:LOCALAPPDATA
        switch ($Editor) {
            'Code' {
                $candidates = @(
                    'code',
                    (Join-Path $localAppData 'Programs\Microsoft VS Code\bin\code.cmd')
                )
            }
            'Code - Insiders' {
                $candidates = @(
                    'code-insiders',
                    (Join-Path $localAppData 'Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd')
                )
            }
            'Cursor' {
                $candidates = @(
                    'cursor',
                    (Join-Path $localAppData 'Programs\Cursor\resources\app\bin\cursor.cmd')
                )
            }
            default {
                throw "Editor '$Editor' does not support VSIX installation."
            }
        }
    }
    elseif ($IsMacOS) {
        switch ($Editor) {
            'Code' { $candidates = @('code', '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code') }
            'Code - Insiders' { $candidates = @('code-insiders', '/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code-insiders') }
            'Cursor' { $candidates = @('cursor', '/Applications/Cursor.app/Contents/Resources/app/bin/cursor') }
            default { throw "Editor '$Editor' does not support VSIX installation." }
        }
    }
    else {
        switch ($Editor) {
            'Code' { $candidates = @('code') }
            'Code - Insiders' { $candidates = @('code-insiders') }
            'Cursor' { $candidates = @('cursor') }
            default { throw "Editor '$Editor' does not support VSIX installation." }
        }
    }

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        $resolved = Get-Command -Name $candidate -ErrorAction SilentlyContinue
        if ($resolved) {
            return $candidate
        }

        if (($candidate.Contains('\\') -or $candidate.Contains('/')) -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw "Unable to locate CLI command for editor '$Editor'. Checked: $($candidates -join ', ')"
}

function Get-LatestExtensionInputTime {
    param([string]$ExtensionRoot)

    $inputEntries = @(
        'package.json',
        'tsconfig.json',
        '.vscodeignore',
        'README.md',
        'src',
        'assets',
        'scripts'
    )

    $latest = [DateTime]::MinValue
    foreach ($entry in $inputEntries) {
        $path = Join-Path $ExtensionRoot $entry
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        $item = Get-Item -LiteralPath $path
        if (-not $item.PSIsContainer) {
            if ($item.LastWriteTimeUtc -gt $latest) {
                $latest = $item.LastWriteTimeUtc
            }
            continue
        }

        $files = Get-ChildItem -LiteralPath $path -File -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            if ($file.LastWriteTimeUtc -gt $latest) {
                $latest = $file.LastWriteTimeUtc
            }
        }
    }

    return $latest
}

function Test-VsixStale {
    param(
        [string]$VsixPath,
        [string]$ExtensionRoot
    )

    if (-not (Test-Path -LiteralPath $VsixPath -PathType Leaf)) {
        return $true
    }

    $vsixWriteTime = (Get-Item -LiteralPath $VsixPath).LastWriteTimeUtc
    $latestInput = Get-LatestExtensionInputTime -ExtensionRoot $ExtensionRoot

    return $latestInput -gt $vsixWriteTime
}

$extensionsRoot = $PSScriptRoot
$extensionRoot = Join-Path $extensionsRoot 'jumpshell'
$packageJsonPath = Join-Path $extensionRoot 'package.json'

if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) {
    throw "Could not find extension package file: $packageJsonPath"
}

$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
$extensionName = [string]$packageJson.name
if ([string]::IsNullOrWhiteSpace($extensionName)) {
    throw "Extension name is missing from $packageJsonPath"
}

if ($PSBoundParameters.ContainsKey('VsixPath') -and -not [string]::IsNullOrWhiteSpace($VsixPath)) {
    $VsixPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($VsixPath)
}
else {
    $VsixPath = Join-Path $extensionsRoot ("{0}.vsix" -f $extensionName)
}

if ($Build) {
    if (Test-VsixStale -VsixPath $VsixPath -ExtensionRoot $extensionRoot) {
        Write-Host "VSIX is stale or missing. Building..." -ForegroundColor Cyan

        $buildScript = Join-Path $extensionsRoot 'Build.ps1'
        if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
            throw "Build script not found: $buildScript"
        }

        $builtVsixPath = & $buildScript
        if ($LASTEXITCODE -ne 0) {
            throw "Build script failed with exit code $LASTEXITCODE"
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$builtVsixPath)) {
            $VsixPath = [string]$builtVsixPath
        }
    }
    else {
        Write-Host "VSIX is up to date. Skipping build." -ForegroundColor DarkCyan
    }
}

if (-not (Test-Path -LiteralPath $VsixPath -PathType Leaf)) {
    throw "VSIX not found: $VsixPath. Run .\\extensions\\Build.ps1 or use -Build."
}

$editor = Resolve-EditorName
$editorCli = Resolve-EditorCli -Editor $editor

Write-Host "Installing VSIX into $editor..." -ForegroundColor Cyan
& $editorCli '--install-extension' $VsixPath '--force'
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install VSIX using '$editorCli' (exit code $LASTEXITCODE)"
}

Write-Host "Installed VSIX in $editor." -ForegroundColor Green
Write-Output $VsixPath