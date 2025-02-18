Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -MaximumHistoryCount 32767 
$global:ProfileHistory=(Get-PSReadlineOption).HistorySavePath
function View-PsHistory() {
	notepad (Get-PSReadlineOption).HistorySavePath
}
function Edit-PsHistory() {
	View-PsHistory
}
function View-PsProfile([switch]$File) {
	Edit-Profile -File:$File
}

function Edit-Profile([switch]$File) {
	if($File) {
		notepad $Profile
	} else {
		code (Split-Path $Profile -Resolve -Parent)
	}
}
