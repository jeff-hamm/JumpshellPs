
function Format-Size() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [double]$SizeInBytes
    )
    switch ([math]::Max($SizeInBytes, 0)) {
        { $_ -ge 1PB } { "{0:N2}PB" -f ($SizeInBytes / 1PB); break }
        { $_ -ge 1TB } { "{0:N2}TB" -f ($SizeInBytes / 1TB); break }
        { $_ -ge 1GB } { "{0:N2}GB" -f ($SizeInBytes / 1GB); break }
        { $_ -ge 1MB } { "{0:N2}MB" -f ($SizeInBytes / 1MB); break }
        { $_ -ge 1KB } { "{0:N2}KB" -f ($SizeInBytes / 1KB); break }
        default { "$SizeInBytes" }
    }
}


function ToSplatString([hashtable]$SplatArgs) {
    $SplatArgs.GetEnumerator() | Select -Property @{ expr={"-" + $_.Name + " " + $_.Value}; name="splatted" }  | select -ExpandProperty splatted
}

function Make-Link(
    [string]$Operation = "SymbolicLink",
    [Parameter(Position = 0, Mandatory = $true)]
    $link, 
    [Parameter(Position = 1, Mandatory = $true)]$target) {
    if ($Operation -eq "/D") {
        $Operation = "SymbolicLink"
    }
    elseif ($Operation -eq "/H") {
        $Operation = "HardLink"
    }
    elseif ($Operation -eq "/J") {
        $Operation = "Junction"
    }
    New-Item -Path $link -ItemType "$Operation"	-Value $target

}

New-Alias -Name "mklink" -Value "Make-Link"
