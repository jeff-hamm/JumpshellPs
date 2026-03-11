param(
    [string]$VsixPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $IsWindows) {
    throw "This script is Windows-only. On Linux/macOS, use Install.sh instead."
}

# Load Resolve-Vs* editor functions from the Jumpshell module, falling back to the source file.
if (-not (Get-Command -Name 'Resolve-VsEditorName' -ErrorAction SilentlyContinue)) {
    $moduleLoaded = $false
    try {
        Import-Module Jumpshell -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        $moduleLoaded = $true
    }
    catch { }

    if (-not $moduleLoaded) {
        $resolveScript = Join-Path $PSScriptRoot '../src/pwsh/vscode/Resolve-VsEditor.ps1'
        if (Test-Path -LiteralPath $resolveScript) {
            . $resolveScript
        }
        else {
            throw "Could not load editor resolver: Jumpshell module unavailable and Resolve-VsEditor.ps1 not found at '$resolveScript'."
        }
    }
}

function Resolve-EditorCli {
    param([string]$Editor)

    $cli = switch ($Editor) {
        'Code'            { 'code' }
        'Code - Insiders' { 'code-insiders' }
        'Cursor'          { 'cursor' }
        'Windsurf'        { 'windsurf' }
        'VSCodium'        { 'codium' }
        default           { throw "Editor '$Editor' does not support VSIX installation." }
    }

    if (-not (Get-Command -Name $cli -ErrorAction SilentlyContinue)) {
        throw "'$cli' not found in PATH. Ensure $Editor is installed and its CLI is on PATH."
    }

    return $cli
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
$extensionId = "{0}.{1}" -f [string]$packageJson.publisher, $extensionName

if ($PSBoundParameters.ContainsKey('VsixPath') -and -not [string]::IsNullOrWhiteSpace($VsixPath)) {
    $VsixPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($VsixPath)
}
else {
    $VsixPath = Join-Path $extensionsRoot ("{0}.vsix" -f $extensionName)
}

$editor = Resolve-VsEditorName
$editorCli = Resolve-EditorCli -Editor $editor

# Try to download VSIX from the GitHub release matching package.json version.
function Get-GitHubVsixUrl {
    param([string]$ExtensionName, [string]$PackageJsonPath, [string]$ScriptRoot)

    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) { return $null }

    try {
        $origin = (& git -C $ScriptRoot remote get-url origin 2>$null).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($origin)) { return $null }
    }
    catch { return $null }

    # Normalise SSH → HTTPS and strip .git suffix
    $origin = $origin -replace '^git@github\.com:', 'https://github.com/'
    $origin = $origin -replace '\.git$', ''
    if ($origin -notmatch 'github\.com') { return $null }

    $pkg     = Get-Content -LiteralPath $PackageJsonPath -Raw | ConvertFrom-Json
    $version = [string]$pkg.version
    if ([string]::IsNullOrWhiteSpace($version)) { return $null }

    return "${origin}/releases/download/v${version}/${ExtensionName}-${version}.vsix"
}

# Build a VS Code Marketplace direct-download URL for the version in package.json.
# Template: https://marketplace.visualstudio.com/_apis/public/gallery/publishers/{publisher}/vsextensions/{name}/{version}/vspackage
function Get-MarketplaceVsixUrl {
    param([string]$Publisher, [string]$ExtensionName, [string]$PackageJsonPath)

    $pkg     = Get-Content -LiteralPath $PackageJsonPath -Raw | ConvertFrom-Json
    $version = [string]$pkg.version
    if ([string]::IsNullOrWhiteSpace($version)) { return $null }

    return "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${Publisher}/vsextensions/${ExtensionName}/${version}/vspackage"
}

if (Test-Path -LiteralPath $VsixPath -PathType Leaf) {
    Write-Host "Installing VSIX into $editor from $VsixPath..." -ForegroundColor Cyan
    & $editorCli '--install-extension' $VsixPath '--force'
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install VSIX using '$editorCli' (exit code $LASTEXITCODE)"
    }
}
else {
    $downloaded = $false
    $githubUrl  = Get-GitHubVsixUrl -ExtensionName $extensionName -PackageJsonPath $packageJsonPath -ScriptRoot $PSScriptRoot
    if ($githubUrl) {
        try {
            Write-Host "Downloading VSIX from GitHub release: $githubUrl" -ForegroundColor DarkCyan
            Invoke-WebRequest -Uri $githubUrl -OutFile $VsixPath -UseBasicParsing
            $downloaded = $true
        }
        catch {
            Write-Host "GitHub release download failed: $_" -ForegroundColor DarkYellow
        }
    }

    if (-not $downloaded) {
        $marketplaceUrl = Get-MarketplaceVsixUrl -Publisher $packageJson.publisher -ExtensionName $extensionName -PackageJsonPath $packageJsonPath
        if ($marketplaceUrl) {
            try {
                Write-Host "Downloading VSIX from VS Code Marketplace: $marketplaceUrl" -ForegroundColor DarkCyan
                Invoke-WebRequest -Uri $marketplaceUrl -OutFile $VsixPath -UseBasicParsing
                $downloaded = $true
            }
            catch {
                Write-Host "Marketplace download failed: $_" -ForegroundColor DarkYellow
            }
        }
    }

    if ($downloaded -and (Test-Path -LiteralPath $VsixPath -PathType Leaf)) {
        Write-Host "Installing downloaded VSIX into $editor..." -ForegroundColor Cyan
        & $editorCli '--install-extension' $VsixPath '--force'
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install VSIX using '$editorCli' (exit code $LASTEXITCODE)"
        }
    }
    else {
        Write-Host "All download attempts failed. Installing $extensionId via marketplace CLI..." -ForegroundColor Cyan
        & $editorCli '--install-extension' $extensionId '--force'
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install '$extensionId' from marketplace using '$editorCli' (exit code $LASTEXITCODE)"
        }
    }
}

Write-Host "Installed $extensionId in $editor." -ForegroundColor Green
Write-Output $VsixPath