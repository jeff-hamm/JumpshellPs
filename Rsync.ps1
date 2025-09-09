$ImageFilter='*.{jpeg,jpg,png,gif}'
function List-Size($Filter) {
    rclone size --ignore-case --include "$Filter" --json mikaelagoogle:/DROPBOX/Tacopa
}


function List-Dirs($Rdrive,$Root,$Output="dirlist.txt") {
    echo "" > "$Output.tmp"
    rclone lsf -R  --tpslimit 10 --fast-list --dirs-only $Rdrive`:$Root | Tee-Object -FilePath "$Output.tmp" -Append
    cat "$Output.tmp" | sort | Out-File "$Output"
    rm "$Output.tmp"
}

function List-MikaelaImage($OutDir="dirlist.txt") {
    List-Dirs -Rdrive 'mikaelagoogle' -Root "/DROPBOX" -OutDir "$OutDir"
    List-ImageDirSize -Rdrive 'mikaelagoogle' -Root "/DROPBOX" -InputFile "$OutDir" -OutFile "imagesizes.json"
}

function Rclone-Size($Include,$Rdrive,$Path) {
    return (rclone size --ignore-case   --tpslimit 10 --fast-list --include "$Include" --json $Rdrive`:$Path | ConvertFrom-Json | select bytes,count)
}

function ToTree($RDrive,$Root,$Path,$Ht,$OutPath) {
    $T=$Ht

    $Path -split '/' | %{ 
        if($_ -eq "") { return }
        $Root+="/$_"
        if($Ht["Children"] -eq $null) {
             $Ht["Children"]=@{} 
        }
        $Ht=$Ht["Children"]
        if($Ht[$_] -eq $null) { 
            $S=(Rclone-Size -Include "/$ImageFilter" -Rdrive "$RDrive" -Path "$Root")
            
            $Ht[$_]=@{
                "Size"=$S.Count
                "Bytes"=(Format-Size $($S.bytes))
            }
            echo "$Root" >> "$OutFile.dirs"
            echo "{""$Root"": $($S|ConvertTo-Json)}," | Tee-Object -FilePath "$OutPath.list" -Append
        }

        $Ht=$Ht[$_]
    }
}

function List-ImageDirSize($Rdrive,$Root,$InputFile="dirlist.txt",$OutFile="imagesizes") {
    echo "" > "$OutFile.json"
    echo "" > "$OutFile.dirs"
    echo "[" > "$OutFile.list.json"
    $RootTree=@{}
    cat $InputFile | % {
        ToTree -Path "$_" -RDrive "$RDrive" -Root "$Root" -Ht $RootTree
    }
    echo "]" >> "$OutFile.list.json"
    $RootTree | ConvertTo-Json -Depth 100 >> $OutFile

    #     $ht=@{}
    #     $ht[$_]=(rclone size --ignore-case   --tpslimit 10 --fast-list --include "/$ImageFilter" --json $Rdrive`:$Root/$_ | ConvertFrom-Json)
    #     echo "$_ =  $($ht[$_])"
    # { "a": 1, "b": 2 } | ConvertTo-Json -Depth 100
    #     echo "$_" >> "$OutFile.dirs"
    #     echo "," >> $OutFile
    # }
    # echo "]" >> $OutFile
}

