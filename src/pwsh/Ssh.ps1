$global:Installed

$SshDrivePackage = "SSHFS-Win.SSHFS-Win"

function SshValidate() {
    Use-Package "$SshDrivePackage"
}
function Get-SshPort($Server,$Port) {
    return Get-SshProperty "port" $Server $Port
}
function Get-SshProperty($Property, $Server,$Port) {
    if($Port) {
        $Args ??= @()
        $Args += @("-p", $Port)
    }
    return (ssh -G $Server @Args | Select-String "$Property (?<name>.*)").Matches[0].Groups["name"].Value
}
function Get-SshUserName($Server,$Port) {
    return Get-SshProperty "user" $Server $Port
}

function Next-AvailableDriveLetter() {
	
    $used=Get-PSDrive -PSProvider filesystem -InformationAction Ignore | where Name -like '?' | sort
	return 'D'..'Z' | diff  $used -PassThru | select -first 1
}

function New-SshDrive($Destination, $Port, $DriveName, $DstPath, $UserName, [PSCredential]$Credential, [switch]$PasswordLogin, [switch]$Persist) {
    SshValidate
    #\\sshfs[.r?k?]\[LOCUSER=]REMUSER@HOST[!PORT][\PATH]
    if(!$Port) {
        $Port = Get-SshPort $Destination $Port
        if($Port) {
            Write-Information "Port not specified, using configured port $Port"
        }
    }
    if (!$UserName) {
        $UserName = Get-SshUserName $Destination $Port
        if($UserName) {
            Write-Information "UserName not specified, using default $UserName"
        }
    }
    if (!$PasswordLogin) {
        $FsSuffix = ".k"
    }
    #
    $UncPath = "\\sshfs$FsSuffix\$UserName@$Destination";
    if ($Port) {
        $UncPath += "!$Port"
    }
    if ($DstPath) {
        $UncPath += "\$DstPath"
    }
    if (!$DriveName) {
		$Drive=Get-PsDrive -PSProvider filesystem -InformationAction Ignore | where Root -eq $UncPath
		if(!$Drive) {
			$DriveName = Next-AvailableDriveLetter
			Write-Information "DriveName not specified, using default $DriveName"
		}
    }
	else {
		$Drive=(Get-PSDrive | where Name -eq $DriveName | select -First 1)
	}
	if($Drive) {
		if($Drive.Root -eq $UncPath) {
			Write-Information "$DriveName already exists, returning"
			return $global:CurrentPSDrive=$Drive
		}
		else {
			Write-Error "Drive $Drivename exists, however, it is mapped to ${Drive.Root}"
			return $Drive
		}
	}
    $AddArgs = $Args || @()
    if ($Credential) {
        $AddArgs += @("-Credential", "$Credential")
    }
    echo "New-PSDrive -PSProvider FileSystem -Name "$DriveName" -Root "$UncPath" -Scope Global -Persist:$Persist $AddArgs"
    $global:CurrentPSDrive = New-PSDrive -PSProvider FileSystem -Name "$DriveName" -Root "$UncPath" -Scope Global -Persist:$Persist
    return $CurrentPSDrive
}