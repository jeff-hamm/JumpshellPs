$global:Installed

function Get-AvailableDriveLetter() {
    $used = Get-PSDrive -PSProvider filesystem -InformationAction Ignore | where Name -like '?' | sort
    return 'D'..'Z' | diff  $used -PassThru | select -first 1
}
function Get-SshPort($Server, $Port) {
    return Get-SshProperty "port" $Server $Port
}
function Get-SshProperty($Property, $Server, $Port) {
    if ($Port) {
        $Args ??= @()
        $Args += @("-p", $Port)
    }
    return (ssh -G $Server @Args | Select-String "$Property (?<name>.*)").Matches[0].Groups["name"].Value
}
function Get-SshUserName($Server, $Port) {
    return Get-SshProperty "user" $Server $Port
}

function Find-Drive($DriveName) {
    return (Get-PSDrive -PSProvider filesystem -InformationAction Ignore | where Name -eq $DriveName | select -First 1)
}

function Find-PsDrives($RootPath, $DriveName, $Provider) {
    $GetDriveArgs = @{}
    if ($Provider) {
        $GetDriveArgs["PsProvider"] = $Provider
    }
    if ($DriveName) {
        $DriveName = $DriveName.TrimEnd(':')
        $GetDriveArgs["Name"] = $DriveName
    }
    return Get-PsDrive @GetDriveArgs | where { -not $RootPath -or $_.DisplayRoot -eq $RootPath -or $_.Root -eq $RootPath }
}

function New-SshDrive($Destination, $Port, $DriveName, $DstPath, $UserName, [PSCredential]$Credential, [switch]$PasswordLogin, [switch]$Persist) {
    SshValidate
    #\\sshfs[.r?k?]\[LOCUSER=]REMUSER@HOST[!PORT][\PATH]
    if (!$Port) {
        $Port = Get-SshPort $Destination $Port
        if ($Port) {
            Write-Information "Port not specified, using configured port $Port"
        }
    }
    if (!$UserName) {
        $UserName = Get-SshUserName $Destination $Port
        if ($UserName) {
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
    $Drive = Get-DriveOrCreate -RootPath $UncPath -DriveName $DriveName -Credential $Credential -Persist:$Persist
    return $Drive
}

function Get-DriveOrCreate {
    param (
        [string]$RootPath,
        [string]$DriveName,
        [PSCredential]$Credential,
        $PSProvider = "FileSystem",
        [switch]$Persist
    )

    if (!$DriveName) {
        $Drive = Get-PsDrive -PSProvider "$PSProvider" -InformationAction Ignore | where { $_.DisplayRoot -eq $RootPath -or $_.Root -eq $RootPath } | Select -first 1
        if (!$Drive) {
            $DriveName = Get-AvailableDriveLetter
            Write-Information "DriveName not specified, using default $DriveName"
        }
    }
    else {
        $Drive = (Get-PSDrive | where Name -eq $DriveName | select -First 1)
    }
    if ($Drive) {
        if ($Drive.DisplayRoot -eq $RootPath -or $_.Root -eq $RootPath) {
            Write-Information "$($Drive.Name):$($Drive.Root):$($Drive.DisplayRoot) already exists, returning"
            return $global:CurrentPSDrive = $Drive
        }
        else {
            throw "Drive $($Drive.Name) exists, however, it is mapped to $($Drive.DisplayRoot) not $RootPath"
        }
    }
    $AddArgs = @{
        "Scope" = "Global"
    }
    if ($Credential) {
        $AddArgs["Credential"] = $Credential
    }
    echo "New-PSDrive -PSProvider FileSystem -Name '$DriveName' -Root '$RootPath' -Persist:$Persist $(ToSplatString($AddArgs))"
    $global:CurrentPSDrive = New-PSDrive -PSProvider FileSystem -Name "$DriveName" -Root "$RootPath" -Persist:$Persist @AddArgs
    return $global:CurrentPSDrive
}



function New-RemoteDrive($Destination, $DriveName, $DstPath, $UserName, [PSCredential]$Credential, [switch]$Persist) {
    #
    $Drive = Get-DriveOrCreate -RootPath $UncPath -DriveName $DriveName -Credential $Credential -Persist:$Persist
    return $Drive
}


function NfsValidate() {
    # Ensure NFS client is installed (Windows feature)
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "ServicesForNFS-ClientOnly"
    if ($feature.State -ne "Enabled") {
        Write-Information "Enabling NFS Client feature..."
        Enable-WindowsOptionalFeature -Online -FeatureName "ServicesForNFS-ClientOnly" -NoRestart
    }
}

function New-NfsDrive(
    [string]$Server,
    [string]$Share,
    [string]$DriveName,
    [switch]$Persist
) {
    #    NfsValidate
    if (-not $Server) { throw "Server is required." }
    if (-not $Share) { throw "Share is required." }
    # NFS UNC path format for Windows: \\server\share
    $RootPath = "\\$Server\$Share"
    $Drive = Find-PsDrives -RootPath $RootPath -DriveName $DriveName -Provider "FileSystem" | select -First 1
    if ($Drive) {
        Write-Information "Drive with root $RootPath already exists, returning existing drive"
        return $Drive
    }
    if (!$DriveName) {
        $DriveName = Get-AvailableDriveLetter + ":"
        Write-Information "DriveName not specified, using default $DriveName"
    }
    else {
        $DriveName = $DriveName.TrimEnd(':') + ":"
    }
    mount.exe -o anon $RootPath $DriveName
    #    $Drive = Get-DriveOrCreate -RootPath $RootPath -DriveName $DriveName -Credential $Credential -Persist:$Persist
    return $Drive
}
