Ensure-Module pwsh-dotenv
$global:UserName = $env:UserName
$Env:ProfilePath=$global:ProfilePath=(Split-Path $PROFILE)
$Env:JumpShellPath=$global:JumpShellPath="$PSscriptRoot"
dotenv secret.env
$Env:FullHomeAddress="$Env:MyName
$Env:HomeAddress"
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -MaximumHistoryCount 32767 
$global:ProfileHistory=(Get-PSReadlineOption).HistorySavePath
