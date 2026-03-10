function Get-PsHistoryFile {
    return (Get-PSReadlineOption).HistorySavePath
}

function View-PsHistory {
    notepad.exe (Get-PsHistoryFile)
}

function View-PsHistory {
    notepad.exe (Get-PsHistoryFile)
}