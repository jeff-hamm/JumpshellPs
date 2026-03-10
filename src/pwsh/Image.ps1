function New-Gif($Input="*.png",$Output,$Loop=0,$Delay=18,[switch]$Resize,$Width=1080) {
    $CmdArgs=@(
        "-delay","$Delay","-loop","$Loop"
    )
    $CmdArgs += $Input
    if($Resize) {
        $CmdArgs += "-resize"
        $CmdArgs += "${Width}x"
    }
    magick @CmdArgs "$Output"
}