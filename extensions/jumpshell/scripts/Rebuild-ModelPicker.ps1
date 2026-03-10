param(
    [switch]$Verbose,
    [string]$Backend = 'copilot-cli',
    [string]$Quality = 'high'
)
<#
.SYNOPSIS
    Validates and patches modelPicker.ts against the current VS Code / Copilot Chat version.
.DESCRIPTION
    Uses ai-cli to prompt an LLM agent with the current modelPicker.ts source and
    the installed Copilot Chat extension's package.json. The agent checks whether
    the internal commands and UI automation assumptions are still valid and
    produces a unified diff of any fixes needed.

    Prerequisites:  ai-cli (from ai-backends) must be on PATH.
                    Run: pip install -e src/python/ai-backends
.EXAMPLE
    .\scripts\Rebuild-ModelPicker.ps1
    .\scripts\Rebuild-ModelPicker.ps1 -Backend gemini -Quality high -Verbose
#>

$ErrorActionPreference = 'Stop'

# ── Resolve paths ──────────────────────────────────────────────────────────────
$repoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)  # extensions/jumpshell -> repo root
$extSrcRoot = Join-Path $repoRoot 'extensions' 'jumpshell'
$pickerTs   = Join-Path $extSrcRoot 'src' 'modelPicker.ts'

if (-not (Test-Path $pickerTs)) {
    throw "modelPicker.ts not found at: $pickerTs"
}

# ── Locate the latest Copilot Chat extension package.json ──────────────────────
$extRoot = if ($env:USERPROFILE) {
    $insiders = Join-Path $env:USERPROFILE '.vscode-insiders' 'extensions'
    $stable   = Join-Path $env:USERPROFILE '.vscode' 'extensions'
    if (Test-Path $insiders) { $insiders } elseif (Test-Path $stable) { $stable } else { $null }
} else {
    $null
}

$copilotPkg = $null
if ($extRoot) {
    $copilotPkg = Get-ChildItem $extRoot -Directory |
        Where-Object { $_.Name -like 'github.copilot-chat*' } |
        Sort-Object Name -Descending |
        Select-Object -First 1 |
        ForEach-Object { Join-Path $_.FullName 'package.json' }
}

# ── Gather context snippets ────────────────────────────────────────────────────
$pickerSource = Get-Content -LiteralPath $pickerTs -Raw

$copilotCommandsJson = ''
if ($copilotPkg -and (Test-Path $copilotPkg)) {
    # Extract only the contributes.commands section to keep the prompt small
    $copilotCommandsJson = & rg -A2 '"command"\s*:\s*"' $copilotPkg 2>$null |
        Out-String
    if (-not $copilotCommandsJson) {
        $copilotCommandsJson = '(could not extract commands from Copilot Chat package.json)'
    }
} else {
    $copilotCommandsJson = '(Copilot Chat extension package.json not found — validate manually)'
}

$vscodeVersion = ''
try {
    $codeBin = if (Get-Command 'code-insiders' -ErrorAction SilentlyContinue) { 'code-insiders' } else { 'code' }
    $vscodeVersion = & $codeBin --version 2>$null | Select-Object -First 1
} catch {
    $vscodeVersion = '(unknown)'
}

# ── Build the prompt ───────────────────────────────────────────────────────────
$prompt = @"
You are a VS Code extension maintainer. Your task is to validate and fix the
file modelPicker.ts which uses internal/brittle VS Code and Copilot Chat commands.

## Current VS Code version
$vscodeVersion

## modelPicker.ts (current source)
``````typescript
$pickerSource
``````

## Copilot Chat extension — registered commands (from package.json)
``````
$copilotCommandsJson
``````

## Your task
1. Check whether the internal command 'github.copilot.chat.openModelPicker' still
   exists in the Copilot Chat extension commands list above. If it has been
   renamed or removed, find the replacement command.

2. Check whether 'workbench.action.acceptSelectedQuickOpenItem' is still a valid
   VS Code workbench command for confirming a QuickPick selection. If not,
   identify the current equivalent.

3. Check whether the 'type' command is still the correct way to inject text
   into a focused QuickPick input.

4. Review the MODEL_PICKER_OPEN_DELAY_MS value (currently 350ms). Flag if
   you know of a better approach (e.g. an event-based wait).

5. If everything is correct, respond with: LGTM — no changes needed.

6. If changes are needed, respond with a unified diff that can be applied to
   modelPicker.ts with 'git apply'. Include clear comments explaining each fix.
   Only output the diff, no other text.
"@

# ── Invoke ai-cli ──────────────────────────────────────────────────────────────
$cliArgs = @('--prompt', $prompt, '--backend', $Backend, '--quality', $Quality)
if ($Verbose) { $cliArgs += '--verbose' }

Write-Host '  Validating modelPicker.ts against current VS Code...' -ForegroundColor Cyan
$result = ai-cli @cliArgs 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Warning "ai-cli exited with code $LASTEXITCODE"
}

# ── Output result ──────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '── Agent response ──' -ForegroundColor Yellow
Write-Host $result
Write-Host ''

# If the response looks like a diff, offer to apply it
if ($result -match '^---|\bdiff\b|^@@') {
    $diffPath = Join-Path $env:TEMP 'jumpshell-modelpicker.patch'
    $result | Set-Content -LiteralPath $diffPath -Encoding utf8NoBOM
    Write-Host "Diff saved to: $diffPath" -ForegroundColor Green
    Write-Host 'To apply:  git apply ' -NoNewline
    Write-Host $diffPath -ForegroundColor Cyan
}
