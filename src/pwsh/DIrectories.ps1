$PrettySizeColumn = @{name="Size";expression={
    $size = $_.Size ?? 0
    if ( $size -lt 1KB ) { $sizeOutput = "$("{0:N2}" -f $size) B" }
    ElseIf ( $size -lt 1MB ) { $sizeOutput = "$("{0:N2}" -f ($size / 1KB)) KB" }
    ElseIf ( $size -lt 1GB ) { $sizeOutput = "$("{0:N2}" -f ($size / 1MB)) MB" }
    ElseIf ( $size -lt 1TB ) { $sizeOutput = "$("{0:N2}" -f ($size / 1GB)) GB" }
    ElseIf ( $size -lt 1PB ) { $sizeOutput = "$("{0:N2}" -f ($size / 1TB)) TB" }
    ElseIf ( $size -ge 1PB ) { $sizeOutput = "$("{0:N2}" -f ($size / 1PB)) PB" } 
    $sizeOutput
}}

function Get-BySize($path=".",$Filter="*", [switch]$Descending) {
    Get-ChildItem -Path $Path | where Name -NotIn DevDrive.vhdx,mips,.cache,Downloads,dwhelper,.chocolatey,OneDrive | ForEach-Object { 
        if($_.PSIsContainer) {
            $size = ( Get-ChildItem -Path $_.FullName -Recurse -Force | where {!$_.PSIsContainer} | Measure-Object -Sum Length).Sum 
        } else {
            $size = $_.Length
        }
        $obj = new-object -TypeName psobject -Property @{
        Path = $_.FullName
        Time = $_.LastWriteTime
        Size = $size
    }
    $obj  
} | Sort-Object -Property Size -Descending:$Descending | Select-Object Path, Time, $PrettySizeColumn
}

function CopyHomeDir($Destination) {
    Get-BySize | tee -FilePath "./copy_log.txt" |  Copy-Item -Destination "$Destination" -Recurse -Force -ErrorAction "Continue"
}

Update-TypeData -TypeName System.IO.DirectoryInfo -MemberType ScriptProperty -MemberName Size -Value {
    Format-Size( $(Get-ChildItem $this -Recurse -File |
            Measure-Object -Property Length -Sum |
            Select-Object -ExpandProperty Sum))
} -Force -ErrorAction SilentlyContinue
Update-TypeData -TypeName System.IO.FileInfo -MemberType ScriptProperty -MemberName Size -Value { Format-Size($this.Length) } -ErrorAction SilentlyContinue

#Update-TypeData -TypeName System.IO.FileInfo -MemberType AliasProperty -MemberName Size -SecondValue "System.String" -Value "LengthString"
function Get-ChildItemSize($Item) {
    Update-TypeData -TypeName System.IO.DirectoryInfo -MemberType AliasProperty -MemberName LengthString -SecondValue "System.String" -Value "Size" -Force
    Update-TypeData -TypeName System.IO.FileInfo -MemberType AliasProperty -MemberName LengthString -SecondValue "System.String" -Value "Size" -Force
    # Update-TypeData -TypeName System.IO.DirectoryInfo -MemberType ScriptProperty -MemberName Size -Value {
    # Format-Size( $(Get-ChildItem $this -Recurse -File |
    # Measure-Object -Property Length -Sum |
    # Select-Object -ExpandProperty Sum))
    # } -Force
    #    Update-FormatData -PrependPath "$((Get-Item $Profile).DirectoryName)\Custom.format.ps1xml"
    return $(ls $Item @args)
    #     $items=@()
    #     $sum=0
    #     Get-ChildItem "$Item" | ForEach-Object { 
    #         $dirName=$_.Name
    #         $isDirectory = ($_ -is [System.IO.DirectoryInfo]) 
    #         $mode = $_.Mode
    #         $writeTime = $_.LastWriteTime
    #         if($isDirectory) {
    #             $objects = Get-ChildItem $_ -Recurse -File
    #         }else {
    #             $objects = @($_)
    #         }
    #         $length =  ($objects | Measure-Object -Sum Length).Sum
    #         # | Select-Object `
    #         # @{Name="Mode"; Expression={$mode}},
    #         # @{Name="LastWriteTime"; Expression={$writeTime}},
    #         # @{Name="Length"; Expression={$(Format-Size $_.Sum)}},
    #         # @{Name="Name"; Expression={$dirname}},
    #         # @{Name="Children"; Expression={$_.Count}}
    # #        $_.SizeString = Format-Size $length
    #         $sum += $nextItems.Length
    #         $items += $_
    #     }

    #     echo "Total: $(Format-Size $sum)"
    #     Write-Output $items 
}
Set-Alias -Name lsl -Value Get-ChildItemSize