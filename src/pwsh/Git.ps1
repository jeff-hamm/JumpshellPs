function Push-All($Remote,
    $Branch,
    $SubtreeBranch="main") {
        if($Remote) {
            git push "$Remote" "$Branch"
        }
        else {
            git push
        }
        foreach($remote in $MipsSubtrees.keys) {
            $prefix=$MipsSubtrees["$remote"]
            git subtree push --prefix=$prefix $remote "$SubtreeBranch"
        }
}
function Pull-All($Remote,
    $Branch,
    $SubtreeBranch="main") {
        if($Remote) {
            git pull "$Remote" "$Branch"
        }
        else {
            git pull
        }
        foreach($remote in $MipsSubtrees.keys) {
            $prefix=$MipsSubtrees["$remote"]
            git subtree pull --prefix=$prefix $remote "$SubtreeBranch"
        }
}
function Clone-ShallowSubmodule($Repo,$Pattern, $Branch="main",$Subdir=".\submodules", $ModuleDir) {
    if(!$ModuleDir) {
        $ModuleName=Split-Path $Repo -LeafBase
        $ModuleDir="$Subdir\$ModuleName"
    }
    if($Repo) {
        if(!(Test-Path $ModuleDir)) {
            mkdir -Force "$Subdir"
            git clone --depth=1 --no-checkout $Repo "$ModuleDir"
        }
        if(!(Test-Path ".\.gitmodules") || !(cat .\.gitmodules | sls -SimpleMatch $Repo )) {
            if($Branch) {
                git submodule add -b "$Branch" $Repo "$ModuleDir"
            }
            else {
                git submodule add $Repo "$ModuleDir"
            }
            git submodule absorbgitdirs
        }
    }
    $CheckoutDir=".git/modules/$ModuleDir/info"
    if(!(Test-Path "$CheckoutDir")) {
        git -C "$ModuleDir" config core.sparseCheckout true 
        mkdir -Force "$CheckoutDir"
        echo "" > "$CheckoutDir/sparse-checkout"
    }
    if($Pattern && !(cat "$CheckoutDir/sparse-checkout" | sls -SimpleMatch $Pattern)) {
        echo "$Pattern"  >> ".git/modules/$ModuleDir/info/sparse-checkout"
        git submodule update --force --checkout $ModuleDir
    }
}