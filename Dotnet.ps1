$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock


function EnvsToDict() {
    $d=@{}
    ls Env: | where name -like '*__*' | % { 
$a = $_.Name -split "__";
$s=$d
foreach($v in  $a) {
 if(!$s[$v]) {
   $s[$v] = @{}
 }
 $p=$s
 $s=$s[$v]
}
$p[$a[$a.Length-1]]=$_.Value
}
return $d;
}