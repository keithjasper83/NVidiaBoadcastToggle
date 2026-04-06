[CmdletBinding()]
param(
    [string]$InstallDir = $(if ($env:OneDrive -and (Test-Path $env:OneDrive)) {
        Join-Path $env:OneDrive "StreamDeck\Scripts\NVidia Broadcast"
    } else {
        Join-Path $env:USERPROFILE "StreamDeck\Scripts\NVidia Broadcast"
    }),

    [string]$BroadcastExePath = "C:\Program Files\NVIDIA Corporation\NVIDIA Broadcast\NVIDIA Broadcast.exe",
    [string]$GitHubRawBase = "https://github.com/keithjasper83/NVidiaBoadcastToggle/",
    [string]$TaskName = "Close NVIDIA Broadcast On Lock"
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) {
    Write-Host "[INFO] $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) {
    Write-Host "[OK]   $msg" -ForegroundColor Green
}

function Write-WarnMsg($msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}

function Ensure-Admin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        throw "Run this installer as Administrator. Scheduled task creation for the machine is more reliable that way."
    }
}

function Ensure-InstallDir {
    if (-not (Test-Path -LiteralPath $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        Write-Ok "Created install directory: $InstallDir"
    } else {
        Write-Info "Using install directory: $InstallDir"
    }
}

function Test-BroadcastExe {
    if (-not (Test-Path -LiteralPath $BroadcastExePath)) {
        throw "NVIDIA Broadcast executable not found at: $BroadcastExePath"
    }
    Write-Ok "Found NVIDIA Broadcast executable."
}

function Get-EmbeddedToggleScript {
@'
param(
    [string]$BroadcastExePath = "C:\Program Files\NVIDIA Corporation\NVIDIA Broadcast\NVIDIA Broadcast.exe",
    [string]$ProcessName = "NVIDIA Broadcast"
)

$ErrorActionPreference = "Stop"

function Get-StateObject([bool]$Running, [string]$Title) {
    [pscustomobject]@{
        state   = if ($Running) { "on" } else { "off" }
        title   = $Title
        running = $Running
    }
}

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue

if ($proc) {
    Stop-Process -Name $ProcessName -Force -ErrorAction Stop
    Start-Sleep -Milliseconds 400

    $stillRunning = [bool](Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
    if ($stillRunning) {
        Get-StateObject -Running $true -Title "Broadcast`nERR" | ConvertTo-Json -Compress
        exit 1
    }

    Get-StateObject -Running $false -Title "Broadcast`nOFF" | ConvertTo-Json -Compress
    exit 0
}

if (-not (Test-Path -LiteralPath $BroadcastExePath)) {
    Get-StateObject -Running $false -Title "Broadcast`nNOEXE" | ConvertTo-Json -Compress
    exit 1
}

Start-Process -FilePath $BroadcastExePath | Out-Null
Start-Sleep -Milliseconds 1500

$running = [bool](Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
if ($running) {
    Get-StateObject -Running $true -Title "Broadcast`nON" | ConvertTo-Json -Compress
    exit 0
}

Get-StateObject -Running $false -Title "Broadcast`nERR" | ConvertTo-Json -Compress
exit 1
'@
}

function Get-EmbeddedStatusScript {
@'
param(
    [string]$ProcessName = "NVIDIA Broadcast"
)

$ErrorActionPreference = "Stop"

$running = [bool](Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)

[pscustomobject]@{
    state   = if ($running) { "on" } else { "off" }
    title   = if ($running) { "Broadcast`nON" } else { "Broadcast`nOFF" }
    running = $running
} | ConvertTo-Json -Compress
'@
}

function Write-EmbeddedScripts {
    $togglePath = Join-Path $InstallDir "toggle-nvidia-broadcast.ps1"
    $statusPath = Join-Path $InstallDir "status-nvidia-broadcast.ps1"

    Set-Content -LiteralPath $togglePath -Value (Get-EmbeddedToggleScript) -Encoding UTF8
    Set-Content -LiteralPath $statusPath -Value (Get-EmbeddedStatusScript) -Encoding UTF8

    Write-Ok "Wrote embedded scripts."
    return @{
        Toggle = $togglePath
        Status = $statusPath
    }
}

function Download-GitHubScripts {
    $toggleUrl = "$GitHubRawBase/toggle-nvidia-broadcast.ps1"
    $statusUrl = "$GitHubRawBase/status-nvidia-broadcast.ps1"

    $togglePath = Join-Path $InstallDir "toggle-nvidia-broadcast.ps1"
    $statusPath = Join-Path $InstallDir "status-nvidia-broadcast.ps1"

    Write-Info "Downloading scripts from GitHub raw URLs..."
    Invoke-WebRequest -Uri $toggleUrl -OutFile $togglePath -UseBasicParsing
    Invoke-WebRequest -Uri $statusUrl -OutFile $statusPath -UseBasicParsing

    Write-Ok "Downloaded scripts from GitHub."
    return @{
        Toggle = $togglePath
        Status = $statusPath
    }
}

function Write-UpdateScript {
    if ([string]::IsNullOrWhiteSpace($GitHubRawBase)) {
        return $null
    }

    $updatePath = Join-Path $InstallDir "update-broadcast-tools.ps1"

$updateContent = @"
param(
    [string]\$GitHubRawBase = "$GitHubRawBase",
    [string]\$InstallDir = "$InstallDir"
)

`$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath `$InstallDir)) {
    New-Item -ItemType Directory -Path `$InstallDir -Force | Out-Null
}

Invoke-WebRequest -Uri "`$GitHubRawBase/toggle-nvidia-broadcast.ps1" -OutFile (Join-Path `$InstallDir "toggle-nvidia-broadcast.ps1") -UseBasicParsing
Invoke-WebRequest -Uri "`$GitHubRawBase/status-nvidia-broadcast.ps1" -OutFile (Join-Path `$InstallDir "status-nvidia-broadcast.ps1") -UseBasicParsing
"@

    Set-Content -LiteralPath $updatePath -Value $updateContent -Encoding UTF8
    Write-Ok "Wrote update script."
    return $updatePath
}

function Install-LockTask {
    $taskScriptPath = Join-Path $InstallDir "close-broadcast-on-lock.ps1"
    $taskScript = @'
$ErrorActionPreference = "SilentlyContinue"
Stop-Process -Name "NVIDIA Broadcast" -Force
'@
    Set-Content -LiteralPath $taskScriptPath -Value $taskScript -Encoding UTF8

    $service = New-Object -ComObject "Schedule.Service"
    $service.Connect()

    $rootFolder = $service.GetFolder("\")
    try {
        $null = $rootFolder.DeleteTask($TaskName, 0)
        Write-Info "Existing scheduled task removed: $TaskName"
    } catch {
    }

    $taskDef = $service.NewTask(0)
    $taskDef.RegistrationInfo.Description = "Closes NVIDIA Broadcast when the workstation is locked."

    $taskDef.Settings.Enabled = $true
    $taskDef.Settings.StartWhenAvailable = $true
    $taskDef.Settings.Hidden = $false
    $taskDef.Settings.AllowDemandStart = $true
    $taskDef.Settings.DisallowStartIfOnBatteries = $false
    $taskDef.Settings.StopIfGoingOnBatteries = $false

    # Session lock event: Event ID 4800 in Security log
    $trigger = $taskDef.Triggers.Create(0)
    $trigger.Subscription = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">
      *[System[EventID=4800]]
    </Select>
  </Query>
</QueryList>
"@

    $action = $taskDef.Actions.Create(0)
    $action.Path = "powershell.exe"
    $action.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$taskScriptPath`""

    # TASK_LOGON_INTERACTIVE_TOKEN = 3
    # TASK_CREATE_OR_UPDATE = 6
    $rootFolder.RegisterTaskDefinition(
        $TaskName,
        $taskDef,
        6,
        $null,
        $null,
        3
    ) | Out-Null

    Write-Ok "Installed scheduled task: $TaskName"
}

function Write-Readme {
    $readmePath = Join-Path $InstallDir "README.txt"

$readme = @"
Installed files:
- toggle-nvidia-broadcast.ps1
- status-nvidia-broadcast.ps1
- close-broadcast-on-lock.ps1

Stream Deck examples:

Toggle command:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$InstallDir\toggle-nvidia-broadcast.ps1" -BroadcastExePath "$BroadcastExePath"

Status command:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$InstallDir\status-nvidia-broadcast.ps1"

"@

    if (-not [string]::IsNullOrWhiteSpace($GitHubRawBase)) {
        $readme += @"

Update command:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$InstallDir\update-broadcast-tools.ps1"
"@
    }

    Set-Content -LiteralPath $readmePath -Value $readme -Encoding UTF8
    Write-Ok "Wrote README."
}

try {
    Ensure-Admin
    Ensure-InstallDir
    Test-BroadcastExe

    if ($GitHubRawBase) {
        Download-GitHubScripts | Out-Null
        Write-UpdateScript | Out-Null
    } else {
        Write-EmbeddedScripts | Out-Null
    }

    Install-LockTask
    Write-Readme

    Write-Host ""
    Write-Ok "Installation complete."
    Write-Host "Install directory: $InstallDir"
}
catch {
    Write-Error $_
    exit 1
}
