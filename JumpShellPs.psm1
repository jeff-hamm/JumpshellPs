# JumpShellPs.psm1
# Auto-generated module file to load all scripts in correct order and export public functions

# Set import flag to prevent circular imports
$global:JumpshellPs_ImportInProgress = $true

# Check for required modules

# Helper: Get all .ps1 files in Init.ps1 order
$files = Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' | 
    Select-Object BaseName, FullName, @{Name = 'Order'; Expression = {
        if($_.BaseName -eq "Install") { -1 }
        elseif ($_.BaseName -match '^(pre)?_') { 0 }
        elseif ($_.BaseName -match '^post_') { 2 }
        else { 1 }
    }
} | Sort-Object Order, BaseName

foreach ($file in $files) {
    if ($file.FullName -ne $MyInvocation.MyCommand.Definition) {
        Write-Debug "Loading script: $($file.FullName)"
        . $file.FullName
    }
}

# Build a mapping of function name to file name
$script:FunctionFileMap = @{}
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    if (!$content) {
        Write-Verbose "Skipping empty file: $($file.FullName)"
        continue
    }
    # Match function definitions: function Name { ... } or function Name() { ... }
    $matches = [regex]::Matches($content, '(?m)^\s*function\s+([a-zA-Z0-9_-]+)')
    foreach ($match in $matches) {
        $funcName = $match.Groups[1].Value
        if ($funcName -notmatch '^_') {
            $script:FunctionFileMap[$funcName] = $file.BaseName
        }
    }
}

# Export all non-private functions (not starting with _ or __)
$publicFunctions = $script:FunctionFileMap.Keys | sort
Write-Debug "Exporting public functions: $($publicFunctions -join ', ')"
Export-ModuleMember -Function $publicFunctions
# Optionally, export the map as a variable for user inspection
Set-Variable -Name 'JumpShell_FunctionFileMap' -Value $script:FunctionFileMap -Scope Global

# Clear import flag - module loading complete
$global:JumpshellPs_ImportInProgress = $false
