function LoadPowerHtml()
{
    if (-not (Get-Module -ErrorAction Ignore -ListAvailable PowerHTML))
    {
        Write-Host "Installing PowerHTML module"
        Install-Module PowerHTML -Scope CurrentUser -ErrorAction Stop -Confirm:$false
    }

    Import-Module -ErrorAction Stop PowerHTML
}