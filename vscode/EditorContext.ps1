function Get-VSCodeVariant {
    <#
    .SYNOPSIS
    Detects the current VS Code fork/channel.

    .DESCRIPTION
    Returns one of: Code, Code - Insiders, Cursor, Claude, VSCodium, or $null when no
    VS Code-compatible host can be detected.
    #>

    [CmdletBinding()]
    param()

    $hints = @(
        $env:VSCODE_GIT_ASKPASS_MAIN,
        $env:VSCODE_IPC_HOOK,
        $env:TERM_PROGRAM,
        $env:TERM_PROGRAM_VERSION,
        $env:CLAUDECODE,
        $env:CLAUDE_CONFIG_DIR
    )

    if ($env:VSCODE_PID -and ($env:VSCODE_PID -as [int])) {
        try {
            $hostProcess = Get-Process -Id ([int]$env:VSCODE_PID) -ErrorAction Stop
            $hints += $hostProcess.ProcessName
            if ($hostProcess.Path) {
                $hints += $hostProcess.Path
            }
        }
        catch {
            # Ignore process lookup failures.
        }
    }

    $hintText = ($hints | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n"
    if ([string]::IsNullOrWhiteSpace($hintText)) {
        return $null
    }

    if ($hintText -match 'Cursor') {
        return 'Cursor'
    }

    if ($hintText -match 'Claude|claude') {
        return 'Claude'
    }

    if ($hintText -match 'Code - Insiders') {
        return 'Code - Insiders'
    }

    if ($hintText -match 'VSCodium|Codium') {
        return 'VSCodium'
    }

    if ($hintText -match 'Microsoft VS Code|Code\\|/Code/|Code\.exe|Code\.app|vscode') {
        return 'Code'
    }

    return $null
}

function Is-VsCode {
    <#
    .SYNOPSIS
    Returns $true when running under any VS Code-compatible editor host.
    #>

    [CmdletBinding()]
    param()

    $variant = Get-VSCodeVariant
    if ($variant -in @('Code', 'Code - Insiders', 'Cursor', 'VSCodium')) {
        return $true
    }

    return [bool]($env:VSCODE_PID -or $env:VSCODE_IPC_HOOK -or $env:VSCODE_GIT_ASKPASS_MAIN)
}

function Resolve-VscodeProfile {
    <#
    .SYNOPSIS
    Resolves the active VS Code/Cursor/Claude user profile path.

    .PARAMETER ProfileName
    Optional profile name to resolve under the detected editor installation.
    #>

    [CmdletBinding()]
    param(
        [string]$ProfileName
    )

    function Get-ActiveProfileId {
        param([string]$BasePath)

        $globalStoragePath = Join-Path $BasePath 'User\globalStorage\storage.json'
        if (-not (Test-Path $globalStoragePath)) {
            return $null
        }

        try {
            $storage = Get-Content -LiteralPath $globalStoragePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            return $storage.'userDataProfiles.profile'
        }
        catch {
            return $null
        }
    }

    function Get-ProfilePathByName {
        param(
            [string]$BasePath,
            [string]$RequestedName
        )

        $profilesPath = Join-Path $BasePath 'User\profiles'
        if (-not (Test-Path $profilesPath)) {
            return $null
        }

        Get-ChildItem -LiteralPath $profilesPath -Directory | ForEach-Object {
            $settingsPath = Join-Path $_.FullName 'settings.json'
            if (-not (Test-Path $settingsPath)) {
                return
            }

            try {
                $settings = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                if ($settings.'workbench.cloudChanges.profile' -eq $RequestedName -or $_.Name -eq $RequestedName) {
                    return $_.FullName
                }
            }
            catch {
                if ($_.Name -like "*$RequestedName*") {
                    return $_.FullName
                }
            }
        }

        return $null
    }

    $variant = Get-VSCodeVariant
    $variantOrderedBases = switch ($variant) {
        'Code - Insiders' { @('Code - Insiders', 'Code', 'Cursor', 'Claude', 'VSCodium') }
        'Cursor' { @('Cursor', 'Code', 'Code - Insiders', 'Claude', 'VSCodium') }
        'Claude' { @('Claude', 'Code', 'Code - Insiders', 'Cursor', 'VSCodium') }
        'VSCodium' { @('VSCodium', 'Code', 'Code - Insiders', 'Cursor', 'Claude') }
        default { @('Code', 'Code - Insiders', 'Cursor', 'Claude', 'VSCodium') }
    }

    $baseCandidates = @()

    if ($env:VSCODE_APPDATA) {
        $baseCandidates += $env:VSCODE_APPDATA
    }

    if ($env:VSCODE_PORTABLE) {
        $baseCandidates += (Join-Path $env:VSCODE_PORTABLE 'user-data')
    }

    if ($env:APPDATA) {
        foreach ($baseName in $variantOrderedBases) {
            $baseCandidates += (Join-Path $env:APPDATA $baseName)
        }
    }

    $baseCandidates = @($baseCandidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

    foreach ($basePath in $baseCandidates) {
        $userPath = Join-Path $basePath 'User'
        if (-not (Test-Path $userPath)) {
            continue
        }

        if ($ProfileName) {
            $profilePath = Get-ProfilePathByName -BasePath $basePath -RequestedName $ProfileName
            if ($profilePath) {
                return $profilePath
            }
        }

        $activeProfileId = Get-ActiveProfileId -BasePath $basePath
        if ($activeProfileId) {
            $activeProfilePath = Join-Path $basePath "User\profiles\$activeProfileId"
            if (Test-Path $activeProfilePath) {
                return $activeProfilePath
            }
        }

        return $userPath
    }

    if ($ProfileName) {
        Write-Warning "Profile '$ProfileName' not found, falling back to default profile path"
    }

    $fallbackCandidates = @()
    if ($env:APPDATA) {
        $fallbackCandidates += @(
            (Join-Path $env:APPDATA 'Code\User'),
            (Join-Path $env:APPDATA 'Code - Insiders\User'),
            (Join-Path $env:APPDATA 'Cursor\User'),
            (Join-Path $env:APPDATA 'Claude\User'),
            (Join-Path $env:APPDATA 'VSCodium\User')
        )
    }

    foreach ($path in $fallbackCandidates) {
        if (Test-Path (Join-Path $path 'settings.json')) {
            return $path
        }
    }

    if ($fallbackCandidates.Count -gt 0) {
        return $fallbackCandidates[0]
    }

    return $null
}

function _Select-FirstExistingPath {
    param([string[]]$Candidates)

    foreach ($candidate in $Candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    return ($Candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
}

function _Get-EditorNameFromProfilePath {
    param([string]$ProfilePath)

    if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
        return $null
    }

    $normalized = $ProfilePath -replace '/', '\\'
    if ($normalized -match '\\Code - Insiders\\') { return 'Code - Insiders' }
    if ($normalized -match '\\Cursor\\') { return 'Cursor' }
    if ($normalized -match '\\Claude\\') { return 'Claude' }
    if ($normalized -match '\\VSCodium\\') { return 'VSCodium' }
    if ($normalized -match '\\Code\\') { return 'Code' }

    return $null
}

function _Resolve-WorkspaceRootForEditor {
    [CmdletBinding()]
    param(
        [string]$StartPath = $PWD.Path
    )

    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($null -ne $git) {
        try {
            $gitRoot = (& git -C $StartPath rev-parse --show-toplevel 2>$null)
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                $trimmedRoot = $gitRoot.Trim()
                if (Test-Path -LiteralPath $trimmedRoot) {
                    return $trimmedRoot
                }
            }
        }
        catch {
            # Ignore git lookup errors.
        }
    }

    $current = $StartPath
    while (-not [string]::IsNullOrWhiteSpace($current)) {
        $hasWorkspaceFile = @(Get-ChildItem -LiteralPath $current -File -Filter '*.code-workspace' -ErrorAction SilentlyContinue | Select-Object -First 1).Count -gt 0
        $hasMarker =
            (Test-Path -LiteralPath (Join-Path $current '.git')) -or
            (Test-Path -LiteralPath (Join-Path $current '.vscode')) -or
            (Test-Path -LiteralPath (Join-Path $current '.cursor')) -or
            (Test-Path -LiteralPath (Join-Path $current '.agents')) -or
            (Test-Path -LiteralPath (Join-Path $current '.claude')) -or
            $hasWorkspaceFile

        if ($hasMarker) {
            return $current
        }

        $parent = Split-Path -Path $current -Parent
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
            break
        }

        $current = $parent
    }

    return $StartPath
}

function Resolve-EditorPath {
    <#
    .SYNOPSIS
    Resolves editor identity and common profile/user/rules/workspace paths.

    .PARAMETER Mode
    One of Name, Profile, User, Rules, Workspace.

    .PARAMETER ProfileName
    Optional editor profile name for profile resolution.
    #>

    [CmdletBinding()]
    param(
        [ValidateSet('Name', 'Profile', 'User', 'Rules', 'Workspace')]
        [string]$Mode = 'Name',
        [string]$ProfileName
    )

    $profilePath = Resolve-VscodeProfile -ProfileName $ProfileName
    $editor = _Get-EditorNameFromProfilePath -ProfilePath $profilePath

    if (-not $editor) {
        $editor = Get-VSCodeVariant
    }

    if (-not $editor) {
        $editor = 'Code'
    }

    switch ($Mode) {
        'Name' {
            return $editor
        }
        'Profile' {
            if ($profilePath) {
                return $profilePath
            }

            if ($env:APPDATA) {
                $fallbackProfile = switch ($editor) {
                    'Code - Insiders' { Join-Path $env:APPDATA 'Code - Insiders\User' }
                    'Cursor' { Join-Path $env:APPDATA 'Cursor\User' }
                    'Claude' { Join-Path $env:APPDATA 'Claude\User' }
                    'VSCodium' { Join-Path $env:APPDATA 'VSCodium\User' }
                    default { Join-Path $env:APPDATA 'Code\User' }
                }

                if ($fallbackProfile) {
                    return $fallbackProfile
                }
            }

            return $null
        }
        'User' {
            switch ($editor) {
                'Cursor' { return (Join-Path $HOME '.cursor') }
                'Claude' { return (Join-Path $HOME '.claude') }
                default { return (Join-Path $HOME '.agents') }
            }
        }
        'Rules' {
            $userPath = Resolve-EditorPath -Mode User -ProfileName $ProfileName
            switch ($editor) {
                'Cursor' { return (Join-Path $userPath 'rules') }
                'Claude' {
                    $claudeCandidates = @(
                        (Join-Path $userPath 'commands'),
                        (Join-Path $userPath 'rules'),
                        $userPath
                    )

                    return (_Select-FirstExistingPath -Candidates $claudeCandidates)
                }
                default { return (Join-Path $userPath 'instructions') }
            }
        }
        'Workspace' {
            $workspaceRoot = _Resolve-WorkspaceRootForEditor
            switch ($editor) {
                'Cursor' { return (Join-Path $workspaceRoot '.cursor') }
                'Claude' { return (Join-Path $workspaceRoot '.claude') }
                default { return (Join-Path $workspaceRoot '.agents') }
            }
        }
    }
}

function Get-VSCodeUserPath {
    <#
    .SYNOPSIS
    Gets the VS Code user settings directory path.

    .DESCRIPTION
    Wrapper around Resolve-VscodeProfile for compatibility with existing callers.

    .PARAMETER ProfileName
    Optional profile name.
    #>

    param(
        [string]$ProfileName
    )

    return Resolve-VscodeProfile -ProfileName $ProfileName
}

