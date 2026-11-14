# Per-user logon task (no admin) that keeps WSL running with no window. See docs/wsl.md.
param(
    [string]$TaskName = 'WSL-Keepalive',
    [string]$Distro = '',     # empty = default distro
    [switch]$Start            # also start it now (harmless if WSL is already up)
)
$ErrorActionPreference = 'Stop'

$wslArgs = @('--exec', '/bin/sleep', 'infinity')
if ($Distro) { $wslArgs = @('-d', $Distro) + $wslArgs }

# conhost --headless gives wsl.exe a console without ever showing a window.
$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\conhost.exe" `
    -Argument ((@('--headless', "$env:SystemRoot\System32\wsl.exe") + $wslArgs) -join ' ')
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -Hidden

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force `
    -Description 'Keep WSL running (headless wsl.exe sleep infinity). From KaiNakamura/dotfiles wsl/keepalive.ps1' |
    Out-Null
Write-Output "registered $TaskName for $user"

if ($Start) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Output "started $TaskName"
}
