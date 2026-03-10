<#
.SYNOPSIS
    Run ocr_scan.py — OCR handwritten scanned notes to Markdown
.EXAMPLE
    .\run.ps1 scan.jpg
    .\run.ps1 -q high scans\
    .\run.ps1 --refresh-models
#>
param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Args
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'ocr_scan.py'

if (-not (Test-Path $script)) {
    Write-Error "Script not found: $script"; exit 1
}

python $script @Args
