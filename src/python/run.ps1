param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$PassThrough
)
<#
.SYNOPSIS
    ai-backends CLI wrapper with tab completion.
.DESCRIPTION
    Run directly to invoke ai-backends:
        .\run.ps1 -p "Describe this" photo.jpg

    Or dot-source to register tab completion for the current session:
        . .\run.ps1

    To persist completion across all sessions, add a dot-source line to your $PROFILE:
        ". $HOME\projects\ai-backends\run.ps1" | Add-Content $PROFILE
#>

# ── Tab completion ─────────────────────────────────────────────────────────────
Register-ArgumentCompleter -Native -CommandName 'ai-cli' -ScriptBlock {
    param([string]$word, $ast, [int]$cursor)

    $tokens = @($ast.CommandElements | Select-Object -ExpandProperty Value)
    $prev = if ($tokens.Count -ge 2) { $tokens[-2] } else { '' }

    switch ($prev) {
        { $_ -in '-b', '--backend' } {
            'gemini', 'openai', 'anthropic', 'github-api', 'copilot-cli', 'cursor' |
            Where-Object { $_ -like "$word*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
            return
        }
        { $_ -in '-q', '--quality' } {
            'low', 'fast', 'normal', 'default', 'high', 'slow' |
            Where-Object { $_ -like "$word*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
            return
        }
    }

    if ($word.StartsWith('-')) {
        '--prompt', '-p', '--backend', '-b', '--model', '-m',
        '--quality', '--tier', '-q', '--vision',
        '--list-models', '--refresh-models', '--regenerate-available-models', '--verbose', '-v' |
        Where-Object { $_ -like "$word*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}

# ── Forward to ai-backends if invoked directly (not dot-sourced) ──────────────
if ($MyInvocation.InvocationName -ne '.') {
    ai-cli @PassThrough
}
