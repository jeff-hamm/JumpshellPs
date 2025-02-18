# Set environment variables\

function Backup-Directory($Src,$Dst,$BucketName=$Env:DefaultStorageBucket) {
	$data = @()
	if(!(Split-Path -IsAbsolute $Src)) {
		$Src = Resolve-Path $Src
	}
	$Src = Resolve-Path $Src
	$RelativePath = Resolve-Path -Path $Src -RelativeBasePath "$BasePath" -Relative
	echo "$RelativePath"
	$ix=$RelativePath.indexOf('\')
	if($ix -gt -1) {
		$RelativePath=$RelativePath.Substring($ix+1)
	}
	echo "$RelativePath"
	if(!$Dst) {
		$Dst = $RelativePath
	}
	$BackupLog="$Src/backup.log"
	echo "Backing up $Src to $Dst in $BucketName"
	$Drive=New-GoogleCloudDrive -BucketName $BucketName -Path $Dst
	echo "Drive is $($Drive.Root)"
	pushd "$($Drive.Name):"
	try {
	Get-ChildItem $Src -Recurse  -File| % {
		$file = $_
		$objectPath = $file | Resolve-Path -Relative -RelativeBasePath $Src
		echo "Backing up $($file) to $($objectPath)"
		Write-Host "`t${$objectPath}"
		Get-FileHash $file -ErrorAction Continue | % {
			echo $_.Algorithm
			$hashFileName=$objectPath + "." + $_.Algorithm.toString()
			echo $hashFileName
			$Hash=$_.Hash
			New-Item $hashFileName -Value $_.Hash  -ErrorAction Continue
		}
		New-Item $objectPath -File $file -ErrorAction Continue
		echo "$objectPath,$hash,$($file.Length)" | Out-File -Append -FilePath $BackupLog
	}
	
	}
	finally {
		popd
	}

}


function Run-Backup() {
	bash -c "duply jumper backup --s3-endpoint-url=https://storage.googleapis.com  --log-file /mnt/d/OneDrive/Backup/duplicity.log --archive-dir /mnt/d/OneDrive/Backup/duplicity"
	# if(!$SecretKey) {
		# $SecretKey=$Env:DefaultSecretKey
	# }
	# $env:GS_ACCESS_KEY_ID = "$AccessKeyId"
	# $env:GS_SECRET_ACCESS_KEY = "$SecretKey"
	# if(!(Split-Path -IsAbsolute $Src)) {
		# $Src = Resolve-Path $Src
	# }
	# $Src = Resolve-Path $Src
	# $RelativePath = Resolve-Path -Path $Src -RelativeBasePath "$BasePath" -Relative
	# echo "$RelativePath"
	# $ix=$RelativePath.indexOf('\')
	# if($ix -gt -1) {
		# $RelativePath=$RelativePath.Substring($ix+1)
	# }
	# echo "$RelativePath"
	# if(!$Dst) {
		# $Dst = $RelativePath
	# }
	# $DstPath = "gs://$StorageBucket/$Dst"


	# # $env:KEY = "<your GPG key fingerprint (8 characters)>"
	# # $env:PASSPHRASE = "<your GPG passphrase>"

	# # Kill any existing duplicity processes
	# Get-Process duplicity -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id -Force }
	
	# # Remove lock files
	# echo "Scanning for lock files"
	# if(Test-Path "$BasePath\.cache\duplicity") {
		# Get-ChildItem -Path "$BasePath\.cache\duplicity" -Recurse -Filter "lockfile.lock" | Remove-Item -Force
	# }
	# echo "Running duplicity"

	# # Check if the write directory is mounted

	# pushd (Split-Path $Src -Parent)
	# try {
		# $Relative=Split-Path $Src -Leaf
		# echo "duplicity --log-file $BasePath\duplicity.log --archive-dir $BasePath\.cache\duplicity $Relative $DstPath"
		# bash -c "duplicity --log-file $BasePath\duplicity.log --archive-dir $BasePath\.cache\duplicity $Relative $DstPath"
	# }
	# finally {
		# popd 
	# }
	# # Run duplicity backup

}
