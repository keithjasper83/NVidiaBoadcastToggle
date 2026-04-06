# status-nvidia-broadcast.ps1

$proc = Get-Process -Name NVIDIA Broadcast -ErrorAction SilentlyContinue

[pscustomobject]@{
    state = if ($proc) { on } else { off }
    title = if ($proc) { Broadcast`nON } else { Broadcast`nOFF }
    running = [bool]$proc
}  ConvertTo-Json -Compress