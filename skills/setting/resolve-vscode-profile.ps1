$ErrorActionPreference = "Stop"

function Select-FirstExisting {
  param([string[]]$Candidates)

  foreach ($candidate in $Candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  return $Candidates[0]
}

$stable = Join-Path $Env:AppData "Code\User"
$insiders = Join-Path $Env:AppData "Code - Insiders\User"
$cursor = Join-Path $Env:AppData "Cursor\User"

$hints = @(
  $Env:VSCODE_IPC_HOOK,
  $Env:VSCODE_GIT_ASKPASS_MAIN,
  $Env:TERM_PROGRAM,
  $Env:TERM_PROGRAM_VERSION
) -join "`n"

if ($hints -match "Code - Insiders") {
  $ordered = @($insiders, $stable, $cursor)
}
elseif ($hints -match "Cursor") {
  $ordered = @($cursor, $stable, $insiders)
}
else {
  $ordered = @($stable, $insiders, $cursor)
}

$resolved = Select-FirstExisting -Candidates $ordered
Write-Output $resolved