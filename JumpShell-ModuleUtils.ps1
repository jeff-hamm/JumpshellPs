
$script:JumpShellPath = $PSScriptRoot

function Edit-JumpShell {
    param(
        [Parameter(Position = 0, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet()] # Placeholder, will update below
        [string]$FnName
    )
    dynamicparam {
        # Use the global variable if available, otherwise fallback to module variable
        $fileMap = $FunctionFileMap
        if (-not $fileMap -and (Get-Variable -Name JumpShell_FunctionFileMap -Scope Global -ErrorAction SilentlyContinue)) {
            $fileMap = (Get-Variable -Name JumpShell_FunctionFileMap -Scope Global).Value
        }
        elseif (-not $fileMap -and (Get-Variable -Name JumpShell_FunctionFileMap -Scope Script -ErrorAction SilentlyContinue)) {
            $fileMap = (Get-Variable -Name JumpShell_FunctionFileMap -Scope Script).Value
        }
        elseif (-not $fileMap) {
            $fileMap = @{}
        }
        $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $validateSet = New-Object System.Management.Automation.ValidateSetAttribute($fileMap.Keys)
        $attributeCollection.Add($validateSet)
        $param = New-Object System.Management.Automation.RuntimeDefinedParameter('FnName', [string], $attributeCollection)
        $paramDictionary.Add('FnName', $param)
        return $paramDictionary
    }
    process {
        if (-not $FnName) {
            code $script:JumpShellPath
        }
        else {
            $fileMap = $FunctionFileMap
            if ($fileMap.ContainsKey($FnName)) {
                $targetFile = Join-Path $script:JumpShellPath ("$($fileMap[$FnName]).ps1")
                if (Test-Path $targetFile) {
                    code $targetFile
                }
                else {
                    Write-Warning "File for function '$FnName' not found: $targetFile"
                }
            }
            else {
                Write-Warning "Function '$FnName' not found in JumpShell Function Map."
            }
        }
    }
}

function Reload-JumpShell {
    $moduleName = 'JumpShellPs'
    $modulePath = Join-Path $script:JumpShellPath 'JumpShellPs.psd1'
    if (Get-Module -Name $moduleName) {
        Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
    }
    Import-Module $modulePath -Force -Global
    Write-Host "Reloaded module: $moduleName from $modulePath"
}
