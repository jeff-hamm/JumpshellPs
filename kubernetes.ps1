if (!(Test-Path -Path "$PSScriptRoot\KubeCtl-Autocomplete.ps1" -PathType Leaf)) {
    kubectl completion powershell | Out-File "$PSScriptRoot\KubeCtl-Autocomplete.ps1"
    echo 'Register-ArgumentCompleter -CommandName ''k'' -ScriptBlock ' >> \KubeCtl-Autocomplete.ps1
}
& "$PSScriptRoot\KubeCtl-Autocomplete.ps1"
if (!(Test-Path -Path "$PSScriptRoot\KubeCtl-Enum.ps1" -PathType Leaf)) {
    $values = (kubectl api-resources | Select-String "^(?<Name>[\w\s]{0,34})(?<Short>[\w,]+)?" | select -ExpandProperty matches -Skip 1 | select -ExpandProperty groups | where Name -in "Name", "Short" | where Value -ne '' | select -ExpandProperty value | Sort-Object | Get-Unique)
    echo "enum KubeResources {" > "$PSScriptRoot\KubeCtl-Enum.ps1"
    $values | % {
        $_.Split(",") | % {
            echo $_.Trim() >> "$PSScriptRoot\KubeCtl-Enum.ps1"
        }
    }
    echo "}" >> "$PSScriptRoot\KubeCtl-Enum.ps1"
}
& "$PSScriptRoot\KubeCtl-Enum.ps1"

Set-Alias -Name k -Value kubectl