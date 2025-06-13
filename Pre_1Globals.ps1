$global:UserName = $env:UserName
$Env:ProfilePath=$global:ProfilePath=(Split-Path $PROFILE)
$Env:JumpShellPath=$global:JumpShellPath="$PSscriptRoot"
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -MaximumHistoryCount 32767 
$global:ProfileHistory=(Get-PSReadlineOption).HistorySavePath

function Load-Secrets() {
    Ensure-Module pwsh-dotenv
    dotenv "$PSScriptRoot\secret.env"
}