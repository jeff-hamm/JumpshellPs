function Blur-Image($Path,$OutputPath,$Blur=0x07, $Level="50,90%") {
	$Ext = Split-Path -Path "$Path" -Extension
	if(!$OutputPath) {
		$OutputPath="$(Join-Path (Split-Path -Path "$Path" -Parent) (Split-Path -Path "$Path" -LeafBase))_blur$Ext"
	}
	if($Ext -ne ".png") {
		$MoreArgs=@('-format','png')
	}
	Write-Host "Edge blur for $Path to $OutputPath"
	magick "$Path" -alpha set -virtual-pixel transparent -channel A -blur $Blur -level "$Level" +channel -background transparent -layers flatten @MoreArgs "$OutputPath.png"
}
function Blur-Images($Path) {
	gci -Path "$Path" -Filter "*.png" | % { Blur-Image "$_" }

	echo $_.Name; magick "$_" -alpha set -virtual-pixel -format png  -channel A -morphology Distance Euclidean:1,20\! +channel "${_}.png"
}

