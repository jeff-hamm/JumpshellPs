$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock


function EnvsToDict() {
    $d=@{}
    ls Env: | where name -like '*__*' | % { 
$a = $_.Name -split "__";
$s=$d
foreach($v in  $a) {
 if(!$s[$v]) {
   $s[$v] = @{}
 }
 $p=$s
 $s=$s[$v]
}
$p[$a[$a.Length-1]]=$_.Value
}
return $d;
}

function Publish-Dotnet {
    <#
    .SYNOPSIS
        Publishes a .NET application for Linux with common settings.
    
    .DESCRIPTION
        Runs dotnet publish in bash with optimized settings for Linux deployment.
        Defaults to self-contained, trimmed, single-file release build.
    
    .PARAMETER NoSelfContained
        Disables self-contained deployment (framework-dependent instead).
    
    .PARAMETER Debug
        Builds in Debug configuration instead of Release.
    
    .PARAMETER NoTrim
        Disables trimming (PublishTrimmed=false).
    
    .PARAMETER NoSingleFile
        Disables single-file publishing.
    
    .PARAMETER NoContainer
        Disables container publishing target.
    
    .PARAMETER PublishAot
        Enables ahead-of-time (AOT) compilation.
    
    .PARAMETER Runtime
        Target runtime identifier. Defaults to linux-x64.
    
    .EXAMPLE
        Publish-DotnetLinux
        Publishes the current project with default settings.
    
    .EXAMPLE
        Publish-DotnetLinux -Debug -NoTrim
        Publishes in Debug mode without trimming.
    #>
    [CmdletBinding()]
    param(
        [switch]$NoSelfContained,
        [Alias("Config")]
        [string]$Configuration = "Release",
        [switch]$NoTrim,
        [switch]$NoSingleFile,
        [switch]$NoContainer,
        [switch]$Aot,
        [string]$Runtime
    )
    
    # Set default runtime if not specified and container publishing is enabled
    if (!$Runtime -and -not $NoContainer) {
        $Runtime = "linux-x64"
    }
    
    # Build the command
    $Configuration
    $selfContained = if ($NoSelfContained) { "false" } else { "true" }
    $trimmed = if ($NoTrim) { "false" } else { "true" }
    $singleFile = if ($NoSingleFile) { "false" } else { "true" }
    
    # Check for single .cs file in current directory
    $csFiles = Get-ChildItem -Path . -Filter "*.cs" -File
    $target = ""
    if ($csFiles.Count -eq 1) {
        $target = $csFiles[0].Name
        Write-Host "Found single .cs file: $target" -ForegroundColor Cyan
    }
    
    # Build command parts
    $cmdParts = @(
        "export NUGET_FALLBACK_PACKAGES=`$HOME/shared",
        "mkdir -p `$HOME/shared",
        "dotnet publish --self-contained $selfContained -c $Configuration",
        "-p:PublishTrimmed=$trimmed",
        "-p:PublishSelfContained=$selfContained",
        "-p:PublishSingleFile=$singleFile"
    )
    
    if (-not $NoContainer) {
        $cmdParts += "/t:PublishContainer"
    }
    
    $cmdParts += @(
        "-r $Runtime",
        "-p:RestoreFallbackFolders=`"`$HOME/shared`""
    )
    
    if ($Aot) {
        $cmdParts += "-p:PublishAot=true"
    }
    
    if ($target) {
        $cmdParts += $target
    }
    
    $command = $cmdParts -join " && "
    
    Write-Host "Running in bash:" -ForegroundColor Green
    Write-Host $command -ForegroundColor Yellow
    
    # Execute in bash
    bash -c $command
}