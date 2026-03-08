function Get-SkillsHash {
    param([string]$ModuleRoot)
    $skillsPath = Join-Path $ModuleRoot 'skills'
    if (-not (Test-Path $skillsPath)) { return $null }
    $lines = Get-ChildItem -LiteralPath $skillsPath -Directory | Sort-Object Name | ForEach-Object {
        $parts = Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Sort-Object FullName |
            ForEach-Object { "$($_.Name)|$($_.LastWriteTime.Ticks)|$($_.Length)" }
        "$($_.Name)|$($parts -join ';')"
    }
    if (-not $lines) { return 'empty' }
    $str = $lines -join "`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($str)
    $stream = [System.IO.MemoryStream]::new($bytes)
    try { (Get-FileHash -Algorithm SHA256 -InputStream $stream).Hash } finally { $stream.Dispose() }
}

function Get-ModulesManifestHash {
    param([string]$ModuleRoot)
    $manifestPath = Join-Path $ModuleRoot 'JumpshellPs.psd1'
    if (-not (Test-Path $manifestPath)) { return $null }
    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $names = @($manifest.RequiredModules | ForEach-Object {
        if ($_ -is [string]) { $_ } else { $_.ModuleName }
    } | Sort-Object)
    if ($names.Count -eq 0) { return 'empty' }
    $str = $names -join ','
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($str)
    $stream = [System.IO.MemoryStream]::new($bytes)
    try { (Get-FileHash -Algorithm SHA256 -InputStream $stream).Hash } finally { $stream.Dispose() }
}
