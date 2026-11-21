# Installs the duo farm watchdog (and optionally the Discord bot) as tasks that start at Windows sign-in and
# come back if they crash. Run from this folder:  powershell -ExecutionPolicy Bypass -File install.ps1 [-BotDir <folder>]
# Undo:  Unregister-ScheduledTask "Catn Farm Watchdog","Catn Yapper Bot" -Confirm:$false
param([string]$BotDir = "")
$ErrorActionPreference = "Stop"
$dest = Join-Path $env:LOCALAPPDATA "CatnFarm"
New-Item -ItemType Directory -Force $dest | Out-Null
foreach ($f in "watchdog.js", "hold_roblox_mutex.ps1", "run_forever.ps1") { Copy-Item (Join-Path $PSScriptRoot $f) $dest -Force }

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
function Install-Runner($name, $dir, $script, $log) {
    $runner = Join-Path $dest "run_forever.ps1"
    $arg = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runner`" -Dir `"$dir`" -Script `"$script`" -Log `"$log`""
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arg
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName $name
    "installed and started: $name"
}
Install-Runner "Catn Farm Watchdog" $dest "watchdog.js" "watchdog.out.log"
if ($BotDir) { Install-Runner "Catn Yapper Bot" (Resolve-Path $BotDir) "index.js" "catn-yapper.log" }
