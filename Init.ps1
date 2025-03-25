
ls  $PsScriptRoot/*.ps1 | select -Property BaseName,FullName,@{Name="Order";Expression={
if ($_.BaseName -match '^post_') { 2 }
        if ($_.BaseName -match '^(pre)?_') { 0 }
        else { 1 }}} | sort -Property Order,BaseName |
        % {
            try {
                if($_.FullName -ne $MyInvocation.MyCommand.Definition) {
                Write-Debug "Importing $($_.FullName)"
                . $_.FullName 
            }
            } catch {
                Write-Error $_
                echo $_.Exception.Message
            }

        }