function Ensure-SecretManager() {
	Ensure-Module "Microsoft.PowerShell.SecretManagement"
	if (!(Get-SecretVault -Name "CredMan")) {
		Register-SecretVault -Name "CredMan" -ModuleName "Microsoft.PowerShell.CredManStore" -DefaultVault
	}
}

function Get-SecretString([string]$Name,[switch]$NoPrompt,[switch]$New, [switch]$AsPlainText) {
	$Secret=(Get-SecretCredential -Name $Name -NoPrompt:$NoPrompt -New:$New)
	if($Secret -is [SecureString]) {
		return ConvertFrom-SecureString -SecureString $Secret -AsPlainText:$AsPlainText

	}
	return $Secret
}

function Get-SecretCredential([string]$Name,[string]$UserName,[string]$PromptMessage, [switch]$NoPrompt,[switch]$New) {
    Ensure-SecretManager
    $Target=$Name
    $credentials = (Get-Secret -Name "$Target" -ErrorAction SilentlyContinue)
	if(!$credentials -and $UserName) {
		$credentials=(Get-Secret -Name "${UserName}@${Target}" -ErrorAction SilentlyContinue)
	}
	if($credentials) {
		if(!$New -and (!$UserName -or (-not ($credentials -is [array])))) {
			return $credentials
		}
		$r=$credentials | ? { ($_.UserName -eq $UserName)};
		if($r.length -gt 0) {
			return $r;
		}
		else {
			Write-Debug "$Found credentials, but username did not match"
		}
	}
	if($NoPrompt) {
		return
	}
	$GetArgs=@()
	if($UserName) {
		$GetArgs+=@("-UserName",$UserName)
	}
	if(!$PromptMessage) {
		$PromptMessage = "Enter Credentials for "
		if($UserName) {
			$PromptMessage += "$UserName@"
		}
		$PromptMessage += "$Target"
	}
	if($UserName) {
		$credentials =@(Get-Credential -Message "$PromptMessage" -UserName $UserName)
		New-StoredCredential -Target $Target -UserName $credentials[0].UserName -SecurePassword $credentials[0].Password -Persist LocalMachine
#		Write-Information "Wrote credential for $UserName @ $Target"
	} else {
		$credentials = Read-Host -AsSecureString -Message "$PromptMessage"
		Set-Secret -Name "$Target" -SecureStringSecret $credentials
#		Write-Information "Wrote secret for $Target"
	}
    if (!$credentials) {
        throw "Could not get credentials"
	}
    return $credentials
}