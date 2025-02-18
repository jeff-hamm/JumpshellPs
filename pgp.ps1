function Pgp-Install() {
	winget install -e --id GnuPG.GnuPG
	mkdir -Force "~/.gnupg"
	[Environment]::SetEnvironmentVariable("GNUPGHOME", (Resolve-Path "~/.gnupg"), [System.EnvironmentVariableTarget]::User)
}
if(!(Test-Path "~/.gnupg")) {
	Pgp-Install
}
$global:PgpKeyPath=$(Resolve-Path "~/.gnupg")
$global:PgpFriendlyNamesFile="$PgpKeyPath\key-maps.json"
$global:PgpFriendlyNames=@{}
if(Test-Path $PgpFriendlyNamesFile -PathType Leaf) {
	$PgpFriendlyNames=(cat $PgpFriendlyNamesFile | ConvertFrom-Json -AsHashtable -ErrorAction Ignore ) || @{}
}
function Write-FriendlyNamesFile() {
	echo $PgpFriendlyNames | ConvertTo-Json
	$PgpFriendlyNames | ConvertTo-Json |  set-content "$PgpFriendlyNamesFile"
}
function Pgp([Parameter(mandatory=$true)]$Name,$String) {
	return Pgp-Encrypt $Name $String
}
function Pgp-Encrypt([Parameter(mandatory=$true)]$Name,$String) {
	# $Extension = ".asc"
	# if(!$Private) {
		# $Extension = ".pub$Extension"
	# }

	# if(!(Test-Path $key -PathType Leaf)) {
		# if(!(Split-Path -Extension $key)) {
			# $key += "$Extension"
		# }
		# if(!(Test-Path $key -PathType Leaf)) {
			# $key="$PgpKeyPath\$key"
		# }
	# }
	# if(!(Test-Path $key -PathType Leaf)) {
		# Write-Error "$key not found"
		# ls $global:PgpKeyPath
		# return
	# }
	if($PgpFriendlyNames["$Name"]) {
		$Name=$PgpFriendlyNames["$Name"]
	}
	Write-Debug "Encrypting $String with $Name"
	echo "$String" | gpg --encrypt -r "$Name" --armor
#	Protect-PGP -FilePathPublic $key -String "$String"
}

function Pgp-Decrypt($ProtectedString, $Name="$global:UserName",$Password="") {
	# $keyArgs=@();
	# if($Name) {
		# $keyArgs += @('-UserName',$Name)
		# $Name = "_$Name"
	# }
	# if($Password) {
		# $keyArgs += @('-Password',$Password)
	# }
	# $PrivKeyPath="$PgpKeyPath\id_pgp${Username}.asc"
	# if($PgpFriendlyNames["$Name"]) {
		# $Name=$PgpFriendlyNames["$Name"]
	# }
	echo $ProtectedString | gpg --decrypt -r "$Name"
}

function Pgp-New($Name=$global:UserName,$Password="") {
	# $keyArgs=@();
	# if($Name) {
		# $keyArgs += @('-UserName',$Name)
		# $Name = "_$Name"
	# }
	# if($Password) {
		# $keyArgs += @('-Password',$Password)
	# }
	# $PrivKeyPath="$PgpKeyPath\id_pgp${Username}.asc"
	# $PubKeyPath="$PgpKeyPath\id_pgp${Username}.pub.asc"
	# if(Test-Path $PrivKeyPath -PathType Leaf) {
		# Write-Warning "$PrivKeyPath exists, overwrite?" -WarningAction Inquire
		
	# }
	$global:PgpFriendlyNames["$Name"] = "$Name"
	Write-FriendlyNamesFile
	gpg --batch --passphrase $Password --quick-gen-key $Name rsa4096 "sign,auth,encr"
#	New-PGPKey -FilePathPublic $PubKeyPath -FilePathPrivate $PrivKeyPath @keyArgs
#	Echo "Created private key $PrivKeyPath and public key $PubKeyPath. Public Key:"
#	cat $PubKeyPath
	$InputString="New Key Test"
	echo "Testing String $InputString"
	$ProtectedString = Pgp -Username $Name -String $InputString
	echo "Protected $ProtectedString"
	$Decrypted = Pgp-Decrypt -ProtectedString $ProtectedString -Username $Name -Password $Password
	if($Decrypted -ne $InputString) {
		Write-Error "Error decrypting!"
	}
	else {
		echo "Success!"
	}
	
}

function Pgp-List([switch]$Internal) {
#	ls $PgpKeyPath
	if($Internal) {
		gpg --list-keys
	}
	else {
		echo $PgpFriendlyNames
	}
}

function Pgp-Address([Parameter(mandatory=$true)]$Name) {
	return Pgp -Name "$name" -String "$global:FullHomeAddress"
}

function Pgp-Key-Delete([Parameter(mandatory=$true)]$Name) {
	if($PgpFriendlyNames["$name"]) {
		$name=$PgpFriendlyNames["$name"]
	}

	gpg --delete-secret-keys $name
	gpg --delete-keys $name
	$PgpFriendlyNames["$name"]="";
	Write-FriendlyNamesFile
}
function Pgp-Get-Key([Parameter(mandatory=$true)]$Name, [switch]$Private) {
	if($PgpFriendlyNames["$name"]) {
		$name=$PgpFriendlyNames["$name"]
	}	
	if($Private) {
		gpg -a --export-secret-key $name
	}
	else {
		gpg  -a --export $name
	}
}
function Pgp-Key([Parameter(mandatory=$true)]$Name, [Parameter(mandatory=$true)]$key) {
	return Pgp-Add $Name $Key
}
function Pgp-Add([Parameter(mandatory=$true)]$Name, [Parameter(mandatory=$true)]$key) {
	# $Extension = ".asc"
	# if(!$Private) {
		# $Extension = ".pub$Extension"
	# }
	# if(!(Split-Path -Extension $name)) {
		# $name +="${Extension}"
	# }
	# if(!(Split-Path $name)) {
		# $name="$global:PgpKeyPath\$name"
	# }
	$response = echo $key | gpg --import --import-options "import-show"
	$realName=(echo $response | Select-String "^uid\s+(.*)$").matches.groups[1].value
    $PgpFriendlyNames["$name"]=$realName
	Write-FriendlyNamesFile
	
#	echo $key > $name
}