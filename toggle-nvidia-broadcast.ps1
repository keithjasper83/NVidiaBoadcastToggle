# toggle-nvidia-broadcast.ps1

$exePath = CProgram FilesNVIDIA CorporationNVIDIA BroadcastNVIDIA Broadcast.exe
$procName = NVIDIA Broadcast

$proc = Get-Process -Name $procName -ErrorAction SilentlyContinue

if ($proc) {
    Stop-Process -Name $procName -Force
    [pscustomobject]@{
        state = off
        title = Broadcast`nOFF
        running = $false
    }  ConvertTo-Json -Compress
}
else {
    Start-Process -FilePath $exePath
    Start-Sleep -Milliseconds 1200

    $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
    [pscustomobject]@{
        state = if ($proc) { on } else { off }
        title = if ($proc) { Broadcast`nON } else { Broadcast`nERR }
        running = [bool]$proc
    }  ConvertTo-Json -Compress
}