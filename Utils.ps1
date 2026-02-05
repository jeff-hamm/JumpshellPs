
# Copilot
# Create a PowerShell function named Set-LogLevel that takes a parameter $Level with valid values "Verbose", "Debug", "Information", "Warning", and "Error". The function should set the appropriate log preference variables ($VerbosePreference, $DebugPreference, $InformationPreference, $WarningPreference, and $ErrorActionPreference) based on the specified log level. Ensure that the specified log level and all higher levels are visible by only overwriting the current value if it is set to SilentlyContinue or Ignore. Use the ActionPreference enum values instead of strings.

function From-Shell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$InputString,
        [switch]$Exec
    )
    
    process {
        # Replace backslash continuation with backtick continuation
        $newline = "`r`n"
        $result = $InputString -replace '\\\s*\r?\n', " ``$newline"
        if ($Exec) {
            Write-Information "Executing: $result" -InformationAction Continue
            Invoke-Expression $result
        } else {
            $result
        }
    }
}

function To-Shell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$InputString,
        [switch]$Exec
    )
    
    process {
        $result = $InputString -replace '`\s+', " `\r`n"
        if ($Exec) {
            Write-Information "Executing: $result" -InformationAction Continue
            Invoke-Expression $result
        } else {
            $result
        }
    }
}

function Convert-Multiline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$InputString,
        [switch]$Exec
    )
    
    process {
        $result = $null
        # Check if the string contains shell-style continuation (backslash followed by newline)
        if ($InputString -match '\\[\s]*[\r]?[\n]') {
            # Convert from shell to PowerShell
            $result = From-Shell -InputString $InputString
        }
        # Check if the string contains PowerShell-style continuation (backtick followed by whitespace)
        elseif ($InputString -match '`[\s]+') {
            # Convert from PowerShell to shell
            $result = To-Shell -InputString $InputString
        }
        else {
            # No continuation characters found, return as-is
            $result = $InputString
        }
        
        if ($Exec) {
            Write-Information "Executing: $result" -InformationAction Continue
            Invoke-Expression $result
        } else {
            $result
        }
    }
}

function Exec-Multiline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$InputString
    )
    
    process {
        Convert-Multiline -InputString $InputString -Exec
    }
}

function Set-LogLevel {
    param (
        [ValidateSet("Verbose", "Debug", "Information", "Warning", "Error")]
        [string]$Level
    )

    $prefs = @{
        VerbosePreference = $global:VerbosePreference
        DebugPreference = $global:DebugPreference
        InformationPreference = $global:InformationPreference
        WarningPreference = $global:WarningPreference
        ErrorActionPreference = $global:ErrorActionPreference
    }

    $levels = @("Verbose", "Debug", "Information", "Warning", "Error")
    $index = $levels.IndexOf($Level)

    for ($i = $index; $i -lt $levels.Count; $i++) {
        $key = "$($levels[$i])Preference"
        Write-Debug "Checking $key and index $i"
        if ($prefs[$key] -eq "SilentlyContinue" -or $prefs[$key] -eq "Ignore") {
            Set-Variable -Name $key -Value "Continue" -Scope Global
            Write-Debug "Setting $key to Continue"
        }
    }
    for ($i = 0; $i -lt $index; $i++) {
        $key = "$($levels[$i])Preference"
        Write-Debug "Checking $key and index $i"
        if ($prefs[$key] -ne "SilentlyContinue" -and $prefs[$key] -ne "Ignore") {
            Write-Debug "Setting $key to SilentlyContinue"
            Set-Variable -Name $key -Value "Continue" -Scope Global
        }
    }
}



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
    ni -Path $link -ItemType "$Operation"	-Value $target

}

function Make-Ln($Target, $Link, [Alias("s")][switch]$Symbolic, [Alias("f")][switch]$Force) {
    if ($Symbolic) {
        Make-Link -Operation "SymbolicLink" -link $Link -target $Target
    }
    else {
        Make-Link -Operation "HardLink" -link $Link -target $Target
    }   
}

New-Alias -Name "mklink" -Value "Make-Link" -ErrorAction SilentlyContinue

New-Alias -Name "ln" -Value "Make-Ln" -ErrorAction SilentlyContinue

New-Alias -Name "multiline" -Value "Convert-Multiline" -ErrorAction SilentlyContinue
New-Alias -Name "multiline-exec" -Value "Exec-Multiline" -ErrorAction SilentlyContinue

# Export functions and aliases (only when used as a module)
# Export-ModuleMember -Function From-Shell, To-Shell, Convert-Multiline, Exec-Multiline, Set-LogLevel, Format-Size, ToSplatString, Make-Link, Make-Ln
# Export-ModuleMember -Alias mklink, ln, multiline



function ConvertTo-HtmlTable {
    <#
    .SYNOPSIS
        Converts delimited text to HTML table and copies to clipboard
    .DESCRIPTION
        Auto-detects delimiter (tab, pipe, comma, or space) and converts to HTML table format
    .PARAMETER InputData
        The table data to convert. If not provided, reads from clipboard.
    .EXAMPLE
        ConvertTo-HtmlTable
        # Converts clipboard content to HTML table
    .EXAMPLE
        Get-Clipboard | ConvertTo-HtmlTable
        # Converts clipboard via pipeline
    .EXAMPLE
        ConvertTo-HtmlTable -InputData $myData
        # Converts specific data
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]$InputData
    )
    
    begin {
        $lines = @()
    }
    
    process {
        if ($InputData) {
            $lines += $InputData
        }
    }
    
    end {
        # If no input provided, get from clipboard
        if ($lines.Count -eq 0) {
            $clipboardContent = Get-Clipboard | Out-String
            if ([string]::IsNullOrWhiteSpace($clipboardContent)) {
                Write-Error "No data provided and clipboard is empty"
                return
            }
            $lines = $clipboardContent -split "`r?`n" | Where-Object { $_.Trim() -ne '' }
        }
        
        if ($lines.Count -eq 0) {
            Write-Error "No data to convert"
            return
        }
        
        # Detect delimiter
        $firstLine = $lines[0]
        $delimiter = "`t"  # Default to tab
        
        if ($firstLine -match "`t") {
            $delimiter = "`t"
            Write-Verbose "Detected tab delimiter"
        }
        elseif ($firstLine -match '\|') {
            $delimiter = '|'
            Write-Verbose "Detected pipe delimiter"
        }
        elseif ($firstLine -match ',') {
            $delimiter = ','
            Write-Verbose "Detected comma delimiter"
        }
        elseif ($firstLine -match '\s{2,}') {
            # Multiple spaces (space-delimited)
            $delimiter = '\s+'
            Write-Verbose "Detected space delimiter"
        }
        
        # Parse rows
        $rows = @()
        foreach ($line in $lines) {
            if ($delimiter -eq '\s+') {
                # For space-delimited, split on multiple spaces
                $cells = $line -split '\s{2,}' | ForEach-Object { $_.Trim() }
            }
            else {
                $cells = $line -split [regex]::Escape($delimiter) | ForEach-Object { $_.Trim() }
            }
            $rows += ,@($cells)
        }
        # Handle markdown tables: trim leading/trailing empty cells
        if ($rows.Count -gt 0) {
            $firstRow = $rows[0]
            $trimStart = ($firstRow[0] -eq '' -or [string]::IsNullOrWhiteSpace($firstRow[0]))
            $trimEnd = ($firstRow[$firstRow.Count - 1] -eq '' -or [string]::IsNullOrWhiteSpace($firstRow[$firstRow.Count - 1]))
            
            if ($trimStart -or $trimEnd) {
                Write-Verbose "Trimming markdown table delimiters"
                $rows = $rows | ForEach-Object {
                    $row = $_
                    if ($trimStart -and $row.Count -gt 0) { $row = $row[1..($row.Count - 1)] }
                    if ($trimEnd -and $row.Count -gt 0) { $row = $row[0..($row.Count - 2)] }
                    , $row
                }
            }
        }
        
        # Filter out markdown separator rows (all dashes)
        $rows = $rows | Where-Object {
            $row = $_
            $allDashes = $true
            foreach ($cell in $row) {
                if ($cell -notmatch '^[-\s]+$') {
                    $allDashes = $false
                    break
                }
            }
            -not $allDashes
        }
        # Build HTML table
        $html = @"
<table border="1" style="border-collapse: collapse;">

"@
        
        # Header row (first row)
        $html += "<tr>"
        foreach ($cell in $rows[0]) {
            $escapedCell = [System.Web.HttpUtility]::HtmlEncode($cell)
            $html += "<th>$escapedCell</th>"
        }
        $html += "</tr>`n"
        
        # Data rows
        for ($i = 1; $i -lt $rows.Count; $i++) {
            $html += "<tr>"
            foreach ($cell in $rows[$i]) {
                $escapedCell = [System.Web.HttpUtility]::HtmlEncode($cell)
                $html += "<td>$escapedCell</td>"
            }
            $html += "</tr>`n"
        }
        
        $html += "</table>"
        
        # Copy to clipboard as HTML
        Set-Clipboard -Html $html
        Write-Host "HTML table copied to clipboard! ($($rows.Count) rows, $($rows[0].Count) columns)" -ForegroundColor Green
    }
}

